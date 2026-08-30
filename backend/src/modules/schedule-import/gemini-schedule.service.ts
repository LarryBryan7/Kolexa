// ============================================================
// gemini-schedule.service.ts — Lectura de horarios desde imagen (Gemini)
// ============================================================
// ÚNICA responsabilidad: imagen → JSON estructurado. No toca la base de
// datos, no resuelve cursos/docentes contra el colegio y no persiste nada.
// Esa separación es deliberada: permite mockear esta clase entera en los
// tests sin llamar a la API real, y deja toda la validación de negocio en
// ScheduleImportService (la IA propone, KOLEXA valida, el admin confirma).
//
// La API key se lee de GEMINI_API_KEY (variable de entorno, nunca hardcode).
// Si no está configurada, el servicio queda deshabilitado y el endpoint
// responde 503 en vez de romper el arranque de la app.
// ============================================================

import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { GoogleGenAI } from '@google/genai';

// Estructura que devuelve Gemini. Es intencionalmente "cruda": nombres de
// curso/docente son el TEXTO tal como aparece en la foto ("MAT (JM)"), sin
// resolver todavía contra los registros del colegio.
export interface RawPeriod {
  start: string;
  end: string;
  subject: string | null;
  teacher: string | null;
  type: 'class' | 'recess' | 'break' | 'lunch' | 'activity';
}

export interface RawDay {
  day: 'monday' | 'tuesday' | 'wednesday' | 'thursday' | 'friday';
  periods: RawPeriod[];
}

export interface RawSchedule {
  classroom: string | null;
  days: RawDay[];
}

// Schema estricto: Gemini no puede devolver texto explicativo ni campos
// extra. `required` en todos los campos evita que omita claves y obligue a
// desambiguar (un valor ausente y uno nulo significan cosas distintas aquí:
// null = "no aparece en la foto", que es información útil para el admin).
const SCHEDULE_JSON_SCHEMA = {
  type: 'object',
  properties: {
    classroom: {
      type: ['string', 'null'],
      description: 'Nombre del aula/sección tal como aparece en la imagen, ej. "SEXTO A". null si no aparece.',
    },
    days: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          day: {
            type: 'string',
            enum: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
          },
          periods: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                start: { type: 'string', description: 'Hora de inicio en formato HH:mm (24h), ej. "07:55".' },
                end: { type: 'string', description: 'Hora de fin en formato HH:mm (24h), ej. "08:40".' },
                subject: {
                  type: ['string', 'null'],
                  description:
                    'Nombre del curso/materia tal como aparece, sin expandir abreviaturas. Para bloques no académicos, su nombre (ej. "RECREO", "TUTORÍA"). null si la celda está vacía.',
                },
                teacher: {
                  type: ['string', 'null'],
                  description:
                    'Docente tal como aparece (nombre, iniciales o código, ej. "JM"). null si no aparece.',
                },
                type: {
                  type: 'string',
                  enum: ['class', 'recess', 'break', 'lunch', 'activity'],
                  description:
                    'class = clase académica normal. recess = recreo. break = descanso. lunch = almuerzo/refrigerio. activity = otro bloque no académico con nombre propio (TUTORÍA, SALIDA, FORMACIÓN, etc.).',
                },
              },
              required: ['start', 'end', 'subject', 'teacher', 'type'],
              additionalProperties: false,
            },
          },
        },
        required: ['day', 'periods'],
        additionalProperties: false,
      },
    },
  },
  required: ['classroom', 'days'],
  additionalProperties: false,
};

// Contexto opcional del colegio (Fase 3): reduce ambigüedad al leer
// abreviaturas. Se le da a Gemini como pista, NO como restricción: si
// detecta algo que no está en la lista, igual debe reportarlo tal cual para
// que el administrador lo resuelva (nunca inventamos cursos ni docentes).
export interface SchoolContext {
  classrooms: string[];
  courses: string[];
  teachers: string[];
}

// Códigos que valen la pena reintentar: la API devuelve 503 de forma
// intermitente cuando el modelo está saturado ("experiencing high demand"),
// y el mismo modelo que falla vuelve a responder segundos después. 429 es
// cuota por minuto y 500 es un fallo interno pasajero. Cualquier otro código
// (400 imagen inválida, 403 key sin permisos) no mejora reintentando.
const RETRYABLE_CODES = [429, 500, 503];

// Se prueban en orden. Si el primero está saturado se pasa al siguiente en vez
// de hacer esperar al administrador: en las pruebas los 503 no golpean a todos
// los modelos a la vez, así que rotar suele resolver más rápido que esperar.
const DEFAULT_MODEL_CHAIN = [
  'gemini-3-flash-preview',
  'gemini-flash-latest',
  'gemini-flash-lite-latest',
];

// Tope total. Medido contra la API real con un horario denso (14 filas × 5
// días): cada intento tarda entre 10 y 46 segundos, y en el tier actual de la
// key alrededor de la mitad devuelve 503 de forma aleatoria — no depende del
// modelo ni del esquema. Con ~50% de éxito por intento, cuatro intentos dan
// ~94% de probabilidad de leer el horario, y a 45s cada uno eso exige 180s.
// Si se migra a una key de pago esto se puede bajar bastante.
const TOTAL_BUDGET_MS = 180_000;

@Injectable()
export class GeminiScheduleService {
  private readonly logger = new Logger(GeminiScheduleService.name);
  private readonly client: GoogleGenAI | null;
  private readonly models: string[];

  constructor() {
    const apiKey = process.env.GEMINI_API_KEY;
    // GEMINI_MODEL sigue funcionando para forzar uno solo; si no está, se usa
    // la cadena completa con respaldo.
    const override = process.env.GEMINI_MODEL?.trim();
    this.models = override ? [override] : DEFAULT_MODEL_CHAIN;

    if (apiKey) {
      this.client = new GoogleGenAI({ apiKey });
      this.logger.log(`Gemini inicializado (modelos: ${this.models.join(' → ')})`);
    } else {
      this.client = null;
      this.logger.warn(
        'GEMINI_API_KEY no configurada. La importación de horarios desde foto quedará deshabilitada.',
      );
    }
  }

  get isEnabled(): boolean {
    return this.client !== null;
  }

  private buildPrompt(context?: SchoolContext): string {
    const lines = [
      'Analiza esta imagen de un horario escolar y devuelve su contenido estructurado.',
      '',
      'Reglas:',
      '- Extrae TODOS los bloques horarios visibles, incluidos recreos, descansos y actividades.',
      '- Clasifica cada bloque en "type": "recess" para recreo; "break" para descanso;',
      '  "lunch" para almuerzo o refrigerio; "activity" para todo lo que no es una',
      '  materia (tutoría, asamblea, formación, saludo a la bandera, salida, talleres,',
      '  asesorías, danza…); "class" solo para materias académicas.',
      '- En los bloques que NO son "class", pon el nombre visible en "subject" igual',
      '  (ej. "SALUDO A LA BANDERA") y deja "teacher" en null si no aparece.',
      '- Si un bloque ocupa toda la fila y aplica a los cinco días (recreo, formación),',
      '  repítelo en cada día con el mismo horario.',
      '- Las horas van SIEMPRE en formato HH:mm de 24 horas (ej. "07:55", "13:40").',
      '- Copia los nombres de cursos y docentes TAL COMO aparecen, sin expandir abreviaturas ni corregir.',
      '- Si una celda está vacía o es ilegible, usa null en vez de inventar un valor.',
      '- No incluyas sábado ni domingo.',
    ];

    // El contexto es una PISTA para desambiguar abreviaturas, nunca una
    // lista cerrada: si la foto tiene algo que no está acá, Gemini debe
    // reportarlo igual (el admin decidirá después qué hacer con eso).
    if (context && (context.courses.length > 0 || context.teachers.length > 0)) {
      lines.push(
        '',
        'Contexto del colegio (úsalo solo para interpretar abreviaturas; si ves algo que no está en estas listas, repórtalo igual tal como aparece):',
      );
      if (context.classrooms.length > 0) {
        lines.push(`- Aulas: ${context.classrooms.join(', ')}`);
      }
      if (context.courses.length > 0) {
        lines.push(`- Cursos: ${context.courses.join(', ')}`);
      }
      if (context.teachers.length > 0) {
        lines.push(`- Docentes: ${context.teachers.join(', ')}`);
      }
    }

    return lines.join('\n');
  }

  // Lanza ServiceUnavailableException si Gemini no está configurado o falla.
  // El error que sube NUNCA incluye la respuesta cruda del modelo ni la
  // imagen: solo un mensaje genérico (ver FASE 10 — no filtrar datos).
  async readSchedule(
    imageBase64: string,
    mimeType: string,
    context?: SchoolContext,
  ): Promise<RawSchedule> {
    if (!this.client) {
      throw new ServiceUnavailableException(
        'La lectura de horarios por imagen no está disponible (falta configurar GEMINI_API_KEY).',
      );
    }

    const request = {
      contents: [
        {
          role: 'user',
          parts: [
            { text: this.buildPrompt(context) },
            { inlineData: { mimeType, data: imageBase64 } },
          ],
        },
      ],
      config: {
        responseMimeType: 'application/json',
        responseJsonSchema: SCHEDULE_JSON_SCHEMA,
        // temperature 0: extracción de datos, no generación creativa —
        // queremos la lectura más literal y reproducible posible.
        temperature: 0,
      },
    };

    const startedAt = Date.now();
    let text: string | undefined;
    let sawTransientFailure = false;
    let attempt = 0;

    // Tres vueltas a la cadena. Lo que corta de verdad no es este número sino
    // TOTAL_BUDGET_MS; las vueltas solo garantizan que, si los intentos salen
    // rápidos, se aprovechen todos los que caben en el presupuesto.
    outer: for (let round = 0; round < 3; round++) {
      for (const model of this.models) {
        if (Date.now() - startedAt > TOTAL_BUDGET_MS) break outer;
        attempt++;

        try {
          const response = await this.client.models.generateContent({ model, ...request });
          text = response.text;
          if (attempt > 1) {
            this.logger.log(`Horario leído con ${model} en el intento ${attempt}.`);
          }
          break outer;
        } catch (err) {
          // Solo el mensaje, sin el payload: el error de la librería puede
          // arrastrar fragmentos del prompt/imagen.
          const message = err instanceof Error ? err.message : 'error desconocido';
          const code = Number(/"code":\s*(\d+)/.exec(message)?.[1]);

          if (!RETRYABLE_CODES.includes(code)) {
            this.logger.error(`Gemini falló al analizar el horario (${model}): ${message}`);
            throw new ServiceUnavailableException(
              'No se pudo analizar la imagen en este momento. Intenta de nuevo en unos segundos.',
            );
          }

          sawTransientFailure = true;
          this.logger.warn(
            `Gemini saturado (${model}, código ${code}) tras ${((Date.now() - startedAt) / 1000).toFixed(1)}s acumulados. Reintentando…`,
          );
        }
      }

      // Espera creciente entre vueltas: dentro de una vuelta ya se está
      // cambiando de modelo, que es en sí una forma de reintento.
      if (!text && round < 2) {
        await new Promise((resolve) => setTimeout(resolve, 2_000 * (round + 1)));
      }
    }

    if (!text && sawTransientFailure) {
      this.logger.error(`Gemini saturado tras ${attempt} intentos; se agotó el presupuesto.`);
      throw new ServiceUnavailableException(
        'El servicio de lectura está saturado en este momento. Espera un minuto y vuelve a intentarlo; la foto no se perdió.',
      );
    }

    if (!text) {
      throw new ServiceUnavailableException(
        'El análisis no devolvió resultados. Prueba con una foto más nítida.',
      );
    }

    try {
      return JSON.parse(text) as RawSchedule;
    } catch {
      // No logueamos `text` completo: puede contener datos del horario.
      this.logger.error('Gemini devolvió una respuesta que no es JSON válido.');
      throw new ServiceUnavailableException(
        'No se pudo interpretar el horario detectado. Intenta de nuevo.',
      );
    }
  }
}
