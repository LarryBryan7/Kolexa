// ============================================================
// Tests unitarios — ScheduleImportService (horario desde foto)
// ============================================================
// Gemini va SIEMPRE mockeado: estos tests no deben gastar cuota de la API
// real ni depender de la red. Lo que se valida acá es la lógica de KOLEXA
// (resolución contra el colegio, validaciones, aislamiento multi-tenant),
// que es justamente la capa que impide que una alucinación del modelo
// termine escrita en la base de datos.
// ============================================================

import { BadRequestException, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { ScheduleImportService } from '../../src/modules/schedule-import/schedule-import.service';
import { RawSchedule } from '../../src/modules/schedule-import/gemini-schedule.service';

const SCHOOL_A = 1n;
const SCHOOL_B = 2n;
const CLASSROOM_A = 10n;

// Colegio de prueba: 6.º A con Matemática y Comunicación, docente Ana Pérez.
const SCHOOL_FIXTURE = {
  classrooms: [{ id: CLASSROOM_A, name: 'SEXTO A', grade: '6', section: 'A' }],
  courses: [
    { id: 100n, name: 'Matemática', code: 'MAT' },
    { id: 101n, name: 'Comunicación', code: 'COM' },
  ],
  teachers: [{ id: 200n, firstName: 'Ana', lastName: 'Pérez' }],
};

function makeService(prismaOverrides: Record<string, any> = {}, gemini: any = {}) {
  const prisma = {
    classroom: {
      findMany: jest.fn().mockResolvedValue(SCHOOL_FIXTURE.classrooms),
      findFirst: jest.fn().mockResolvedValue({ id: CLASSROOM_A }),
    },
    course: {
      findMany: jest.fn().mockResolvedValue(SCHOOL_FIXTURE.courses),
    },
    user: {
      findMany: jest.fn().mockResolvedValue(SCHOOL_FIXTURE.teachers),
    },
    classroomCourse: {
      upsert: jest.fn().mockResolvedValue({ id: 900n }),
    },
    scheduleBlock: {
      deleteMany: jest.fn(),
      createMany: jest.fn(),
    },
    $transaction: jest.fn().mockResolvedValue([]),
    ...prismaOverrides,
  };
  const geminiService = {
    readSchedule: jest.fn(),
    isEnabled: true,
    ...gemini,
  };
  const service = new ScheduleImportService(prisma as any, geminiService as any);
  return { service, prisma, geminiService };
}

function rawSchedule(overrides: Partial<RawSchedule> = {}): RawSchedule {
  return {
    classroom: 'SEXTO A',
    days: [
      {
        day: 'monday',
        periods: [
          { start: '08:00', end: '08:45', subject: 'Matemática', teacher: 'Ana Pérez', type: 'class' },
        ],
      },
    ],
    ...overrides,
  };
}

describe('ScheduleImportService.resolveAndValidate (la IA propone, KOLEXA valida)', () => {
  it('resuelve aula, curso y docente cuando todo coincide con el colegio', () => {
    const { service } = makeService();
    const result = service.resolveAndValidate(rawSchedule(), SCHOOL_FIXTURE);

    expect(result.classroom).toEqual({ id: '10', name: 'SEXTO A' });
    expect(result.blocks).toHaveLength(1);
    expect(result.blocks[0]).toMatchObject({
      dayOfWeek: 1,
      courseId: '100',
      courseName: 'Matemática',
      teacherId: '200',
      issues: [],
    });
    expect(result.summary.needsReview).toBe(0);
  });

  it('resuelve el curso por su código abreviado ("MAT" → Matemática)', () => {
    const { service } = makeService();
    const result = service.resolveAndValidate(
      rawSchedule({
        days: [
          {
            day: 'tuesday',
            periods: [{ start: '09:00', end: '09:45', subject: 'MAT', teacher: null, type: 'class' }],
          },
        ],
      }),
      SCHOOL_FIXTURE,
    );

    expect(result.blocks[0].courseId).toBe('100');
    expect(result.blocks[0].issues).toEqual([]);
  });

  it('marca para revisión un curso que NO existe en el colegio (no lo inventa)', () => {
    const { service } = makeService();
    const result = service.resolveAndValidate(
      rawSchedule({
        days: [
          {
            day: 'monday',
            periods: [{ start: '08:00', end: '08:45', subject: 'Robótica', teacher: null, type: 'class' }],
          },
        ],
      }),
      SCHOOL_FIXTURE,
    );

    expect(result.blocks[0].courseId).toBeNull();
    expect(result.blocks[0].issues[0]).toContain('Robótica');
    expect(result.summary.unmatchedCourses).toEqual(['Robótica']);
    expect(result.summary.needsReview).toBe(1);
  });

  it('marca para revisión un docente inexistente (no lo crea)', () => {
    const { service } = makeService();
    const result = service.resolveAndValidate(
      rawSchedule({
        days: [
          {
            day: 'monday',
            periods: [
              { start: '08:00', end: '08:45', subject: 'Matemática', teacher: 'Juan Nadie', type: 'class' },
            ],
          },
        ],
      }),
      SCHOOL_FIXTURE,
    );

    expect(result.blocks[0].teacherId).toBeNull();
    expect(result.summary.unmatchedTeachers).toEqual(['Juan Nadie']);
  });

  it('acepta un bloque de clase sin docente (no todos los horarios lo indican)', () => {
    const { service } = makeService();
    const result = service.resolveAndValidate(
      rawSchedule({
        days: [
          {
            day: 'monday',
            periods: [{ start: '08:00', end: '08:45', subject: 'Matemática', teacher: null, type: 'class' }],
          },
        ],
      }),
      SCHOOL_FIXTURE,
    );

    expect(result.blocks[0].issues).toEqual([]);
  });

  it('reporta el aula sin resolver cuando no coincide con ninguna del colegio', () => {
    const { service } = makeService();
    const result = service.resolveAndValidate(rawSchedule({ classroom: 'QUINTO Z' }), SCHOOL_FIXTURE);

    expect(result.classroom).toBeNull();
    expect(result.detectedClassroom).toBe('QUINTO Z');
  });

  it('guarda bloques no académicos (RECREO, TUTORÍA) con su etiqueta y sin curso', () => {
    const { service } = makeService();
    const result = service.resolveAndValidate(
      rawSchedule({
        days: [
          {
            day: 'monday',
            periods: [
              { start: '10:00', end: '10:20', subject: 'RECREO', teacher: null, type: 'recess' },
              { start: '10:20', end: '11:00', subject: 'TUTORÍA', teacher: null, type: 'activity' },
            ],
          },
        ],
      }),
      SCHOOL_FIXTURE,
    );

    expect(result.blocks[0]).toMatchObject({ type: 'recess', label: 'RECREO', courseId: null, issues: [] });
    expect(result.blocks[1]).toMatchObject({ type: 'activity', label: 'TUTORÍA', issues: [] });
  });

  it('detecta horas con formato inválido', () => {
    const { service } = makeService();
    const result = service.resolveAndValidate(
      rawSchedule({
        days: [
          {
            day: 'monday',
            periods: [{ start: '25:99', end: 'ocho', subject: 'Matemática', teacher: null, type: 'class' }],
          },
        ],
      }),
      SCHOOL_FIXTURE,
    );

    expect(result.blocks[0].issues).toContain('Horario ilegible: revisa la hora de inicio y fin.');
  });

  it('detecta inicio posterior al fin', () => {
    const { service } = makeService();
    const result = service.resolveAndValidate(
      rawSchedule({
        days: [
          {
            day: 'monday',
            periods: [{ start: '10:00', end: '09:00', subject: 'Matemática', teacher: null, type: 'class' }],
          },
        ],
      }),
      SCHOOL_FIXTURE,
    );

    expect(result.blocks[0].issues).toContain('La hora de inicio debe ser anterior a la de fin.');
  });

  it('marca solapamientos en AMBOS bloques del mismo día', () => {
    const { service } = makeService();
    const result = service.resolveAndValidate(
      rawSchedule({
        days: [
          {
            day: 'monday',
            periods: [
              { start: '08:00', end: '09:00', subject: 'Matemática', teacher: null, type: 'class' },
              { start: '08:30', end: '09:30', subject: 'Comunicación', teacher: null, type: 'class' },
            ],
          },
        ],
      }),
      SCHOOL_FIXTURE,
    );

    const msg = 'Este bloque se cruza con otro del mismo día.';
    expect(result.blocks[0].issues).toContain(msg);
    expect(result.blocks[1].issues).toContain(msg);
  });

  it('NO marca solapamiento entre bloques contiguos ni entre días distintos', () => {
    const { service } = makeService();
    const result = service.resolveAndValidate(
      rawSchedule({
        days: [
          {
            day: 'monday',
            periods: [
              { start: '08:00', end: '09:00', subject: 'Matemática', teacher: null, type: 'class' },
              { start: '09:00', end: '10:00', subject: 'Comunicación', teacher: null, type: 'class' },
            ],
          },
          {
            day: 'tuesday',
            periods: [{ start: '08:00', end: '09:00', subject: 'Matemática', teacher: null, type: 'class' }],
          },
        ],
      }),
      SCHOOL_FIXTURE,
    );

    expect(result.summary.needsReview).toBe(0);
  });

  it('tolera una respuesta parcialmente válida: descarta días inválidos y conserva el resto', () => {
    const { service } = makeService();
    const result = service.resolveAndValidate(
      {
        classroom: 'SEXTO A',
        days: [
          // 'saturday' no es un día lectivo válido: se descarta entero.
          { day: 'saturday' as any, periods: [{ start: '08:00', end: '09:00', subject: 'X', teacher: null, type: 'class' }] },
          {
            day: 'monday',
            periods: [{ start: '08:00', end: '08:45', subject: 'Matemática', teacher: null, type: 'class' }],
          },
        ],
      },
      SCHOOL_FIXTURE,
    );

    expect(result.blocks).toHaveLength(1);
    expect(result.blocks[0].dayOfWeek).toBe(1);
  });

  it('no revienta si la IA devuelve un horario vacío', () => {
    const { service } = makeService();
    const result = service.resolveAndValidate({ classroom: null, days: [] }, SCHOOL_FIXTURE);

    expect(result.blocks).toEqual([]);
    expect(result.summary.total).toBe(0);
  });
});

describe('ScheduleImportService.analyze (contexto + errores de Gemini)', () => {
  it('nunca escribe en la base de datos al analizar', async () => {
    const { service, prisma, geminiService } = makeService();
    geminiService.readSchedule.mockResolvedValue(rawSchedule());

    await service.analyze(SCHOOL_A, 'base64', 'image/jpeg');

    expect(prisma.scheduleBlock.createMany).not.toHaveBeenCalled();
    expect(prisma.scheduleBlock.deleteMany).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('pasa a Gemini el contexto del colegio (cursos y docentes) para desambiguar', async () => {
    const { service, geminiService } = makeService();
    geminiService.readSchedule.mockResolvedValue(rawSchedule());

    await service.analyze(SCHOOL_A, 'base64', 'image/jpeg');

    const context = geminiService.readSchedule.mock.calls[0][2];
    expect(context.courses).toEqual(['Matemática', 'Comunicación']);
    expect(context.teachers).toEqual(['Ana Pérez']);
  });

  it('propaga el error cuando Gemini falla (no devuelve un horario a medias)', async () => {
    const { service, geminiService } = makeService();
    geminiService.readSchedule.mockRejectedValue(
      new ServiceUnavailableException('No se pudo analizar la imagen en este momento.'),
    );

    await expect(service.analyze(SCHOOL_A, 'base64', 'image/jpeg')).rejects.toThrow(
      ServiceUnavailableException,
    );
  });

  it('propaga el timeout de Gemini como error, sin persistir nada', async () => {
    const { service, prisma, geminiService } = makeService();
    geminiService.readSchedule.mockRejectedValue(new Error('ETIMEDOUT'));

    await expect(service.analyze(SCHOOL_A, 'base64', 'image/jpeg')).rejects.toThrow();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
});

describe('ScheduleImportService.confirm (persistencia + aislamiento multi-tenant)', () => {
  const validBlock = {
    dayOfWeek: 1,
    startTime: '08:00',
    endTime: '08:45',
    type: 'class' as const,
    courseId: '100',
    teacherId: '200',
  };

  function makeConfirmService(overrides: Record<string, any> = {}) {
    return makeService({
      course: { findMany: jest.fn().mockResolvedValue([{ id: 100n }]) },
      user: { findMany: jest.fn().mockResolvedValue([{ id: 200n }]) },
      ...overrides,
    });
  }

  it('guarda el horario reemplazando el anterior del aula, en una transacción', async () => {
    const { service, prisma } = makeConfirmService();

    const result = await service.confirm(SCHOOL_A, CLASSROOM_A, [validBlock]);

    expect(result).toEqual({ saved: 1, classroomId: '10' });
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(prisma.scheduleBlock.deleteMany).toHaveBeenCalledWith({
      where: { classroomId: CLASSROOM_A },
    });
    const created = prisma.scheduleBlock.createMany.mock.calls[0][0].data[0];
    expect(created).toMatchObject({
      classroomId: CLASSROOM_A,
      classroomCourseId: 900n,
      type: 'class',
      dayOfWeek: 1,
    });
    // Las horas se guardan como Time (epoch 1970) — convención ya usada por
    // el horario del docente.
    expect(created.startTime.toISOString()).toBe('1970-01-01T08:00:00.000Z');
  });

  it('RECHAZA un aula de OTRO colegio (aislamiento multi-tenant)', async () => {
    const { service, prisma } = makeConfirmService({
      // El aula existe, pero no bajo el schoolId del JWT → findFirst no la halla
      classroom: { findFirst: jest.fn().mockResolvedValue(null), findMany: jest.fn() },
    });

    await expect(service.confirm(SCHOOL_B, CLASSROOM_A, [validBlock])).rejects.toThrow(
      NotFoundException,
    );
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('RECHAZA cursos que no pertenecen al colegio, aunque el id venga en el body', async () => {
    const { service, prisma } = makeConfirmService({
      course: { findMany: jest.fn().mockResolvedValue([]) }, // ninguno es de este colegio
    });

    await expect(service.confirm(SCHOOL_A, CLASSROOM_A, [validBlock])).rejects.toThrow(
      /cursos que no pertenecen/i,
    );
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('RECHAZA docentes que no pertenecen al colegio', async () => {
    const { service, prisma } = makeConfirmService({
      user: { findMany: jest.fn().mockResolvedValue([]) },
    });

    await expect(service.confirm(SCHOOL_A, CLASSROOM_A, [validBlock])).rejects.toThrow(
      /docentes que no pertenecen/i,
    );
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('RECHAZA un bloque de clase sin curso', async () => {
    const { service } = makeConfirmService();

    await expect(
      service.confirm(SCHOOL_A, CLASSROOM_A, [{ ...validBlock, courseId: null }]),
    ).rejects.toThrow(/necesita un curso/i);
  });

  it('RECHAZA horas con formato inválido aunque hayan pasado el analyze', async () => {
    const { service } = makeConfirmService();

    await expect(
      service.confirm(SCHOOL_A, CLASSROOM_A, [{ ...validBlock, startTime: '8am' }]),
    ).rejects.toThrow(/formato HH:mm/i);
  });

  it('RECHAZA inicio posterior al fin', async () => {
    const { service } = makeConfirmService();

    await expect(
      service.confirm(SCHOOL_A, CLASSROOM_A, [{ ...validBlock, startTime: '10:00', endTime: '09:00' }]),
    ).rejects.toThrow(/anterior a la de fin/i);
  });

  it('RECHAZA un día fuera de lunes-viernes', async () => {
    const { service } = makeConfirmService();

    await expect(
      service.confirm(SCHOOL_A, CLASSROOM_A, [{ ...validBlock, dayOfWeek: 6 }]),
    ).rejects.toThrow(/día inválido/i);
  });

  it('RECHAZA solapamientos entre bloques enviados', async () => {
    const { service } = makeConfirmService();

    await expect(
      service.confirm(SCHOOL_A, CLASSROOM_A, [
        validBlock,
        { ...validBlock, startTime: '08:30', endTime: '09:15' },
      ]),
    ).rejects.toThrow(/se cruza con otro bloque/i);
  });

  it('RECHAZA una lista vacía de bloques', async () => {
    const { service } = makeConfirmService();

    await expect(service.confirm(SCHOOL_A, CLASSROOM_A, [])).rejects.toThrow(BadRequestException);
  });

  it('guarda bloques no académicos con su etiqueta y sin curso', async () => {
    const { service, prisma } = makeConfirmService({
      course: { findMany: jest.fn().mockResolvedValue([]) },
      user: { findMany: jest.fn().mockResolvedValue([]) },
    });

    await service.confirm(SCHOOL_A, CLASSROOM_A, [
      { dayOfWeek: 1, startTime: '10:00', endTime: '10:20', type: 'recess', label: 'RECREO' },
    ]);

    const created = prisma.scheduleBlock.createMany.mock.calls[0][0].data[0];
    expect(created).toMatchObject({ type: 'recess', label: 'RECREO', classroomCourseId: null });
  });

  it('vincula el curso al aula (ClassroomCourse) sin crear cursos ni docentes nuevos', async () => {
    const { service, prisma } = makeConfirmService();

    await service.confirm(SCHOOL_A, CLASSROOM_A, [validBlock]);

    expect(prisma.classroomCourse.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { classroomId_courseId: { classroomId: CLASSROOM_A, courseId: 100n } },
      }),
    );
  });
});
