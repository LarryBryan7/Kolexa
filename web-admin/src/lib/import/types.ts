// ============================================================
// Tipos y configuración del módulo de importación masiva.
// Las columnas reflejan EXACTAMENTE el contrato del backend
// (backend/src/modules/import/import.service.ts). El backend lee
// las cabeceras en español; no cambiar estos nombres.
// ============================================================

export type ImportType = 'classrooms' | 'courses' | 'teachers' | 'students';

export type ImportSource = 'excel' | 'csv';

/** Estados de la UI del flujo de importación. */
export type ImportUiState =
  | 'idle'
  | 'dragging'
  | 'selected'
  | 'reading'
  | 'processing'
  | 'preview'
  | 'error'
  | 'confirming'
  | 'success';

export interface ImportColumn {
  /** Nombre exacto de la cabecera que espera el backend. */
  header: string;
  /** ¿Es obligatoria? */
  required?: boolean;
  /** Alternativa aceptada por el backend (p. ej. año/anio). */
  alias?: string;
  /** Descripción para la plantilla / ayuda. */
  hint?: string;
}

export interface ImportTypeConfig {
  label: string;
  description: string;
  /** Columnas en el orden de la plantilla. */
  columns: ImportColumn[];
  /** Tamaño máximo de archivo en bytes. */
  maxFileSize: number;
  /** Máximo de filas de datos (sin cabecera). */
  maxRows: number;
}

/** Límites globales (configurables aquí). */
export const LIMITS = {
  /** 5 MB por defecto. */
  defaultMaxFileSize: 5 * 1024 * 1024,
  /** 5.000 filas de datos por defecto. */
  defaultMaxRows: 5000,
};

export const IMPORT_CONFIG: Record<ImportType, ImportTypeConfig> = {
  classrooms: {
    label: 'Aulas',
    description:
      'Importa aulas. Obligatorias: nombre, año, sede. Opcionales: grado, sección.',
    columns: [
      { header: 'nombre', required: true, hint: 'Nombre del aula (p. ej. 1° A)' },
      { header: 'grado', hint: 'Grado (p. ej. 1)' },
      { header: 'seccion', hint: 'Sección (p. ej. A)' },
      { header: 'año', required: true, alias: 'anio', hint: 'Año académico (p. ej. 2026)' },
      { header: 'sede', required: true, hint: 'Nombre de la sede' },
    ],
    maxFileSize: LIMITS.defaultMaxFileSize,
    maxRows: LIMITS.defaultMaxRows,
  },
  courses: {
    label: 'Cursos',
    description: 'Importa cursos. Obligatoria: nombre. Opcional: código.',
    columns: [
      { header: 'nombre', required: true, hint: 'Nombre del curso' },
      { header: 'codigo', hint: 'Código (p. ej. MAT-101)' },
    ],
    maxFileSize: LIMITS.defaultMaxFileSize,
    maxRows: LIMITS.defaultMaxRows,
  },
  teachers: {
    label: 'Docentes',
    description:
      'Importa docentes. Obligatorias: email, nombre. Opcionales: apellido, dni, teléfono.',
    columns: [
      { header: 'email', required: true, hint: 'Correo del docente' },
      { header: 'nombre', required: true, hint: 'Nombres' },
      { header: 'apellido', hint: 'Apellidos' },
      { header: 'dni', hint: 'DNI' },
      { header: 'telefono', hint: 'Teléfono' },
    ],
    maxFileSize: LIMITS.defaultMaxFileSize,
    maxRows: LIMITS.defaultMaxRows,
  },
  students: {
    label: 'Alumnos',
    description:
      'Importa alumnos. Obligatoria: nombre y (dni o codigo). Opcionales: apellido, aula, año, emailpadre.',
    columns: [
      { header: 'nombre', required: true, hint: 'Nombres' },
      { header: 'apellido', hint: 'Apellidos' },
      { header: 'dni', hint: 'DNI (obligatorio si no hay código)' },
      { header: 'codigo', hint: 'Código (obligatorio si no hay DNI)' },
      { header: 'aula', hint: 'Nombre del aula' },
      { header: 'año', alias: 'anio', hint: 'Año académico' },
      { header: 'emailpadre', alias: 'email_padre', hint: 'Correo del padre/madre' },
    ],
    maxFileSize: LIMITS.defaultMaxFileSize,
    maxRows: LIMITS.defaultMaxRows,
  },
};

/** Extensiones aceptadas por cada fuente. */
export const ACCEPTED_EXTENSIONS = {
  excel: ['.xlsx', '.xls'],
  csv: ['.csv'],
};

/** Errores locales tipados (validación de archivo/formato). */
export class ImportFileError extends Error {
  code: string;
  constructor(code: string, message: string) {
    super(message);
    this.name = 'ImportFileError';
    this.code = code;
  }
}

/** Fila normalizada tras parsear un archivo. */
export interface ParsedRow {
  /** Número de fila original (1 = primera fila de datos). */
  row: number;
  /** Valores por cabecera (claves = cabeceras normalizadas). */
  values: Record<string, string>;
}

/** Resultado del parseo local de un archivo. */
export interface ParseResult {
  source: ImportSource;
  fileName: string;
  /** Cabeceras detectadas (normalizadas a minúsculas). */
  headers: string[];
  rows: ParsedRow[];
  /** Cabeceras obligatorias que faltan en el archivo. */
  missingRequired: string[];
  /** Cabeceras desconocidas (no esperadas por el contrato). */
  unknownHeaders: string[];
}
