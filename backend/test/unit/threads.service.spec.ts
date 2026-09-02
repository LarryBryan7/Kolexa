// ============================================================
// Tests unitarios — ThreadsService (mensajería 1:1)
// ============================================================
// El foco está en la regla de seguridad que motivó el rediseño (ver
// auditoría de mensajería del 30-08-2026): ninguna conversación cruza de
// colegio, y una conversación padre↔docente solo existe si comparten un
// alumno. Se prueba con un prisma falso hecho a mano, sin tocar la base.
// ============================================================

import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { ThreadsService } from '../../src/modules/threads/threads.service';

const SCHOOL_A = 1n;
const SCHOOL_B = 2n;

const PARENT = { id: 10n, roles: ['parent'] };
const TEACHER = { id: 20n, roles: ['teacher'] };
const OTHER_TEACHER = { id: 21n, roles: ['teacher'] };
const ADMIN = { id: 30n, roles: ['school_admin'] };
const STUDENT = 100n;
const OTHER_STUDENT = 101n;

function makePrisma(overrides: Record<string, any> = {}) {
  const prisma = {
    user: { findFirst: jest.fn(), findUnique: jest.fn() },
    userStudent: { findFirst: jest.fn() },
    classroomCourse: { findFirst: jest.fn() },
    thread: { findFirst: jest.fn(), create: jest.fn(), update: jest.fn() },
    threadParticipant: {
      createMany: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn().mockResolvedValue([]),
      findFirst: jest.fn(),
      update: jest.fn(),
    },
    threadMessage: { create: jest.fn(), findMany: jest.fn().mockResolvedValue([]) },
    $transaction: jest.fn(async (arg: any) => {
      if (typeof arg === 'function') return arg(prisma);
      return Promise.all(arg);
    }),
    ...overrides,
  };
  return prisma;
}

function makeService(prismaOverrides: Record<string, any> = {}) {
  const prisma = makePrisma(prismaOverrides);
  const notifications = { sendToUser: jest.fn().mockResolvedValue(undefined) };
  const service = new ThreadsService(prisma as any, notifications as any);
  return { service, prisma, notifications };
}

describe('ThreadsService.openThread — aislamiento y permisos', () => {
  it('rechaza al destinatario de otro colegio (404, no 403 — no revela si existe)', async () => {
    const { service, prisma } = makeService({
      user: { findFirst: jest.fn().mockResolvedValue(null) }, // filtrado por schoolId ya excluye a SCHOOL_B
    });
    await expect(
      service.openThread(SCHOOL_A, PARENT, {
        recipientId: TEACHER.id,
        studentId: STUDENT,
        firstMessageBody: 'hola',
      }),
    ).rejects.toThrow(NotFoundException);
    expect(prisma.user.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ userRoles: { some: { schoolId: SCHOOL_A } } }),
      }),
    );
  });

  it('rechaza abrir un hilo consigo mismo', async () => {
    const { service } = makeService();
    await expect(
      service.openThread(SCHOOL_A, PARENT, {
        recipientId: PARENT.id,
        studentId: STUDENT,
        firstMessageBody: 'hola',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('padre → docente sin studentId: pide indicar el alumno', async () => {
    const { service } = makeService({
      user: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ id: TEACHER.id, userRoles: [{ role: { name: 'teacher' } }] }),
      },
    });
    await expect(
      service.openThread(SCHOOL_A, PARENT, { recipientId: TEACHER.id, firstMessageBody: 'hola' }),
    ).rejects.toThrow(BadRequestException);
  });

  it('padre → docente que NO enseña a ese alumno: rechazado', async () => {
    const { service, prisma } = makeService({
      user: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ id: TEACHER.id, userRoles: [{ role: { name: 'teacher' } }] }),
      },
      userStudent: { findFirst: jest.fn().mockResolvedValue({ id: 1n }) }, // el padre sí es dueño del alumno
      classroomCourse: { findFirst: jest.fn().mockResolvedValue(null) }, // pero el docente no le enseña
    });
    await expect(
      service.openThread(SCHOOL_A, PARENT, {
        recipientId: TEACHER.id,
        studentId: STUDENT,
        firstMessageBody: 'hola',
      }),
    ).rejects.toThrow(ForbiddenException);
    expect(prisma.classroomCourse.findFirst).toHaveBeenCalled();
  });

  it('padre → docente de OTRO alumno propio: rechazado aunque el padre sea dueño de otro hijo', async () => {
    const { service } = makeService({
      user: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ id: TEACHER.id, userRoles: [{ role: { name: 'teacher' } }] }),
      },
      // El padre es dueño de OTHER_STUDENT, no del STUDENT que se está pasando.
      userStudent: { findFirst: jest.fn().mockResolvedValue(null) },
    });
    await expect(
      service.openThread(SCHOOL_A, PARENT, {
        recipientId: TEACHER.id,
        studentId: OTHER_STUDENT,
        firstMessageBody: 'hola',
      }),
    ).rejects.toThrow(ForbiddenException);
  });

  it('padre → docente que SÍ enseña al alumno: permitido, crea el hilo', async () => {
    const { service, prisma } = makeService({
      user: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ id: TEACHER.id, userRoles: [{ role: { name: 'teacher' } }] }),
        findUnique: jest.fn().mockResolvedValue({ firstName: 'Rosa', lastName: 'Quispe' }),
      },
      userStudent: { findFirst: jest.fn().mockResolvedValue({ id: 1n }) },
      classroomCourse: { findFirst: jest.fn().mockResolvedValue({ id: 900n }) },
      thread: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 500n }),
        update: jest.fn(),
      },
      threadParticipant: {
        createMany: jest.fn(),
        findUnique: jest.fn().mockResolvedValue({ thread: { closedAt: null } }),
        findMany: jest.fn().mockResolvedValue([{ userId: TEACHER.id }]),
        update: jest.fn(),
      },
      threadMessage: { create: jest.fn().mockResolvedValue({ id: 1n, sentAt: new Date() }), findMany: jest.fn() },
    });

    const res = await service.openThread(SCHOOL_A, PARENT, {
      recipientId: TEACHER.id,
      studentId: STUDENT,
      firstMessageBody: 'Hola profe, una consulta',
    });

    expect(res.threadId).toBe('500');
    expect(prisma.thread.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ schoolId: SCHOOL_A, studentId: STUDENT }),
      }),
    );
    expect(prisma.threadParticipant.createMany).toHaveBeenCalled();
    expect(prisma.threadMessage.create).toHaveBeenCalled();
  });

  it('reutiliza un hilo existente en vez de crear uno nuevo', async () => {
    const { service, prisma } = makeService({
      user: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ id: TEACHER.id, userRoles: [{ role: { name: 'teacher' } }] }),
        findUnique: jest.fn().mockResolvedValue({ firstName: 'Rosa', lastName: null }),
      },
      userStudent: { findFirst: jest.fn().mockResolvedValue({ id: 1n }) },
      classroomCourse: { findFirst: jest.fn().mockResolvedValue({ id: 900n }) },
      thread: { findFirst: jest.fn().mockResolvedValue({ id: 777n }), create: jest.fn(), update: jest.fn() },
      threadParticipant: {
        createMany: jest.fn(),
        findUnique: jest.fn().mockResolvedValue({ thread: { closedAt: null } }),
        findMany: jest.fn().mockResolvedValue([]),
        update: jest.fn(),
      },
      threadMessage: { create: jest.fn().mockResolvedValue({ id: 2n, sentAt: new Date() }), findMany: jest.fn() },
    });

    const res = await service.openThread(SCHOOL_A, PARENT, {
      recipientId: TEACHER.id,
      studentId: STUDENT,
      firstMessageBody: 'segundo mensaje',
    });

    expect(res.threadId).toBe('777');
    expect(prisma.thread.create).not.toHaveBeenCalled();
  });

  it('docente → padre (sentido inverso): valida al padre como dueño y al docente como su profesor', async () => {
    const { service, prisma } = makeService({
      user: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ id: PARENT.id, userRoles: [{ role: { name: 'parent' } }] }),
        findUnique: jest.fn().mockResolvedValue({ firstName: 'Ana', lastName: 'Pérez' }),
      },
      userStudent: { findFirst: jest.fn().mockResolvedValue({ id: 1n }) },
      classroomCourse: { findFirst: jest.fn().mockResolvedValue({ id: 900n }) },
      thread: { findFirst: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue({ id: 600n }), update: jest.fn() },
      threadParticipant: {
        createMany: jest.fn(),
        findUnique: jest.fn().mockResolvedValue({ thread: { closedAt: null } }),
        findMany: jest.fn().mockResolvedValue([]),
        update: jest.fn(),
      },
      threadMessage: { create: jest.fn().mockResolvedValue({ id: 3n, sentAt: new Date() }), findMany: jest.fn() },
    });

    const res = await service.openThread(SCHOOL_A, TEACHER, {
      recipientId: PARENT.id,
      studentId: STUDENT,
      firstMessageBody: 'Aviso sobre la tarea',
    });
    expect(res.threadId).toBe('600');
    // parentId=PARENT.id, teacherId=TEACHER.id en el orden correcto
    expect(prisma.userStudent.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({ where: { userId: PARENT.id, studentId: STUDENT } }),
    );
    expect(prisma.classroomCourse.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ teacherId: TEACHER.id }) }),
    );
  });

  it('docente → docente: rechazado (no hay alumno compartido posible en ese par)', async () => {
    const { service } = makeService({
      user: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ id: OTHER_TEACHER.id, userRoles: [{ role: { name: 'teacher' } }] }),
      },
    });
    await expect(
      service.openThread(SCHOOL_A, TEACHER, {
        recipientId: OTHER_TEACHER.id,
        studentId: STUDENT,
        firstMessageBody: 'hola colega',
      }),
    ).rejects.toThrow(ForbiddenException);
  });

  it('padre → director: permitido sin studentId', async () => {
    const { service, prisma } = makeService({
      user: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ id: ADMIN.id, userRoles: [{ role: { name: 'school_admin' } }] }),
        findUnique: jest.fn().mockResolvedValue({ firstName: 'Rosa', lastName: null }),
      },
      thread: { findFirst: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue({ id: 800n }), update: jest.fn() },
      threadParticipant: {
        createMany: jest.fn(),
        findUnique: jest.fn().mockResolvedValue({ thread: { closedAt: null } }),
        findMany: jest.fn().mockResolvedValue([]),
        update: jest.fn(),
      },
      threadMessage: { create: jest.fn().mockResolvedValue({ id: 4n, sentAt: new Date() }), findMany: jest.fn() },
    });

    const res = await service.openThread(SCHOOL_A, PARENT, {
      recipientId: ADMIN.id,
      firstMessageBody: 'Consulta administrativa',
    });
    expect(res.threadId).toBe('800');
    expect(prisma.thread.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ studentId: undefined }) }),
    );
  });

  it('director → docente de OTRO colegio del propio director: rechazado (cross-school)', async () => {
    // Mismo caso que el primero, pero disparado desde el lado admin — el
    // filtro de colegio ocurre antes de mirar los roles.
    const { service } = makeService({ user: { findFirst: jest.fn().mockResolvedValue(null) } });
    await expect(
      service.openThread(SCHOOL_A, ADMIN, {
        recipientId: TEACHER.id,
        firstMessageBody: 'hola',
      }),
    ).rejects.toThrow(NotFoundException);
  });
});

describe('ThreadsService — bandeja y no-leído', () => {
  it('marca sin leer cuando lastReadAt es null o es anterior al último mensaje', async () => {
    const now = new Date('2026-08-30T10:00:00Z');
    const earlier = new Date('2026-08-30T09:00:00Z');
    const { service } = makeService({
      threadParticipant: {
        findMany: jest.fn().mockResolvedValue([
          {
            lastReadAt: null,
            mutedAt: null,
            thread: {
              id: 1n,
              kind: 'direct',
              subject: null,
              studentId: STUDENT,
              priority: 'normal',
              lastMessageAt: now,
              student: { firstName: 'Juan', lastName: 'Quispe' },
              participants: [{ user: { id: TEACHER.id, firstName: 'Ana', lastName: 'Pérez', avatar: null } }],
            },
          },
          {
            lastReadAt: earlier,
            mutedAt: null,
            thread: {
              id: 2n,
              kind: 'direct',
              subject: null,
              studentId: null,
              priority: 'normal',
              lastMessageAt: now,
              student: null,
              participants: [{ user: { id: ADMIN.id, firstName: 'Director', lastName: null, avatar: null } }],
            },
          },
          {
            lastReadAt: now,
            mutedAt: null,
            thread: {
              id: 3n,
              kind: 'direct',
              subject: null,
              studentId: null,
              priority: 'normal',
              lastMessageAt: earlier, // ya leído: el mensaje es más viejo que la lectura
              student: null,
              participants: [{ user: { id: TEACHER.id, firstName: 'Ana', lastName: null, avatar: null } }],
            },
          },
        ]),
        createMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      threadMessage: { findMany: jest.fn().mockResolvedValue([]), create: jest.fn() },
    });

    const inbox = await service.getInbox(PARENT.id, SCHOOL_A);
    expect(inbox.find((t) => t.id === '1')?.unread).toBe(true);
    expect(inbox.find((t) => t.id === '2')?.unread).toBe(true);
    expect(inbox.find((t) => t.id === '3')?.unread).toBe(false);
  });

  it('unread-count cuenta solo los hilos sin leer del colegio del usuario', async () => {
    const now = new Date('2026-08-30T10:00:00Z');
    const earlier = new Date('2026-08-30T09:00:00Z');
    const { service } = makeService({
      threadParticipant: {
        findMany: jest.fn().mockResolvedValue([
          { lastReadAt: null, thread: { lastMessageAt: now } },
          { lastReadAt: earlier, thread: { lastMessageAt: now } },
          { lastReadAt: now, thread: { lastMessageAt: earlier } },
        ]),
        createMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
    });
    await expect(service.getUnreadCount(PARENT.id, SCHOOL_A)).resolves.toBe(2);
  });

  it('unreadCount cuenta mensajes reales de la otra persona posteriores a lastReadAt, nunca los propios', async () => {
    const now = new Date('2026-08-30T10:00:00Z');
    const earlier = new Date('2026-08-30T09:00:00Z');
    const { service } = makeService({
      threadParticipant: {
        findMany: jest.fn().mockResolvedValue([
          {
            lastReadAt: earlier,
            mutedAt: null,
            thread: {
              id: 1n,
              kind: 'direct',
              subject: null,
              studentId: null,
              priority: 'normal',
              lastMessageAt: now,
              student: null,
              participants: [{ user: { id: TEACHER.id, firstName: 'Ana', lastName: null, avatar: null } }],
            },
          },
        ]),
        createMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      threadMessage: {
        // Una sola query trae TODOS los mensajes del hilo (propios y
        // ajenos); el conteo filtra en memoria por senderId !== userId,
        // no en el WHERE (ver comentario en getInbox).
        findMany: jest.fn().mockResolvedValue([
          { threadId: 1n, body: 'primero', senderId: PARENT.id, sentAt: new Date('2026-08-30T09:15:00Z') },
          { threadId: 1n, body: 'segundo', senderId: TEACHER.id, sentAt: new Date('2026-08-30T09:30:00Z') },
          { threadId: 1n, body: 'hola', senderId: TEACHER.id, sentAt: now },
        ]),
        create: jest.fn(),
      },
    });

    const inbox = await service.getInbox(PARENT.id, SCHOOL_A);
    // De los 3 mensajes, 2 son de la otra persona (TEACHER) y posteriores
    // a `earlier` (el lastReadAt) — el propio (PARENT) nunca cuenta.
    expect(inbox.find((t) => t.id === '1')?.unreadCount).toBe(2);
  });

  it('otherParticipant.online: true si lastActiveAt es reciente (<3min), false si es viejo o null', async () => {
    const recent = new Date(Date.now() - 60_000); // hace 1 minuto
    const stale = new Date(Date.now() - 10 * 60_000); // hace 10 minutos
    const { service } = makeService({
      threadParticipant: {
        findMany: jest.fn().mockResolvedValue([
          {
            lastReadAt: null,
            mutedAt: null,
            thread: {
              id: 1n,
              kind: 'direct',
              subject: null,
              studentId: null,
              priority: 'normal',
              lastMessageAt: new Date(),
              student: null,
              participants: [
                { user: { id: TEACHER.id, firstName: 'Ana', lastName: null, avatar: null, lastActiveAt: recent } },
              ],
            },
          },
          {
            lastReadAt: null,
            mutedAt: null,
            thread: {
              id: 2n,
              kind: 'direct',
              subject: null,
              studentId: null,
              priority: 'normal',
              lastMessageAt: new Date(),
              student: null,
              participants: [
                { user: { id: OTHER_TEACHER.id, firstName: 'Luis', lastName: null, avatar: null, lastActiveAt: stale } },
              ],
            },
          },
          {
            lastReadAt: null,
            mutedAt: null,
            thread: {
              id: 3n,
              kind: 'direct',
              subject: null,
              studentId: null,
              priority: 'normal',
              lastMessageAt: new Date(),
              student: null,
              participants: [
                { user: { id: ADMIN.id, firstName: 'Director', lastName: null, avatar: null, lastActiveAt: null } },
              ],
            },
          },
        ]),
        createMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      threadMessage: { findMany: jest.fn().mockResolvedValue([]), create: jest.fn() },
    });

    const inbox = await service.getInbox(PARENT.id, SCHOOL_A);
    expect(inbox.find((t) => t.id === '1')?.otherParticipant?.online).toBe(true);
    expect(inbox.find((t) => t.id === '2')?.otherParticipant?.online).toBe(false);
    expect(inbox.find((t) => t.id === '3')?.otherParticipant?.online).toBe(false);
  });

  it('lastMessage.delivered: true si el otro leyó el hilo O estuvo activo después del envío, false si ninguna', async () => {
    const sentAt = new Date('2026-08-30T10:00:00Z');
    const before = new Date('2026-08-30T09:00:00Z');
    const after = new Date('2026-08-30T10:30:00Z');
    const { service } = makeService({
      threadParticipant: {
        findMany: jest.fn().mockResolvedValue([
          // Hilo 1: la otra persona leyó el hilo después del envío -> delivered.
          {
            lastReadAt: null,
            mutedAt: null,
            thread: {
              id: 1n, kind: 'direct', subject: null, studentId: null, priority: 'normal',
              lastMessageAt: sentAt, student: null,
              participants: [{ lastReadAt: after, user: { id: TEACHER.id, firstName: 'Ana', lastName: null, avatar: null, lastActiveAt: null } }],
            },
          },
          // Hilo 2: no leyó, pero estuvo activa/online después del envío -> delivered.
          {
            lastReadAt: null,
            mutedAt: null,
            thread: {
              id: 2n, kind: 'direct', subject: null, studentId: null, priority: 'normal',
              lastMessageAt: sentAt, student: null,
              participants: [{ lastReadAt: null, user: { id: OTHER_TEACHER.id, firstName: 'Luis', lastName: null, avatar: null, lastActiveAt: after } }],
            },
          },
          // Hilo 3: ni leyó ni estuvo activa después del envío -> NO delivered.
          {
            lastReadAt: null,
            mutedAt: null,
            thread: {
              id: 3n, kind: 'direct', subject: null, studentId: null, priority: 'normal',
              lastMessageAt: sentAt, student: null,
              participants: [{ lastReadAt: before, user: { id: ADMIN.id, firstName: 'Director', lastName: null, avatar: null, lastActiveAt: before } }],
            },
          },
        ]),
        createMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      threadMessage: {
        findMany: jest.fn().mockResolvedValue([
          { threadId: 1n, body: 'hola', senderId: PARENT.id, sentAt },
          { threadId: 2n, body: 'hola', senderId: PARENT.id, sentAt },
          { threadId: 3n, body: 'hola', senderId: PARENT.id, sentAt },
        ]),
        create: jest.fn(),
      },
    });

    const inbox = await service.getInbox(PARENT.id, SCHOOL_A);
    expect(inbox.find((t) => t.id === '1')?.lastMessage?.delivered).toBe(true);
    expect(inbox.find((t) => t.id === '2')?.lastMessage?.delivered).toBe(true);
    expect(inbox.find((t) => t.id === '3')?.lastMessage?.delivered).toBe(false);
  });
});

describe('ThreadsService — acceso a un hilo por participación', () => {
  it('quien no participa no puede leer ni enviar mensajes (404, no 403 — no confirma que el hilo existe)', async () => {
    const { service } = makeService({
      threadParticipant: {
        findUnique: jest.fn().mockResolvedValue(null),
        findMany: jest.fn(),
        // getMessages ahora dispara assertParticipant EN PARALELO con estas
        // otras dos consultas (ver comentario en threads.service.ts) — se
        // llaman igual aunque assertParticipant termine rechazando, así
        // que el mock necesita existir como función.
        findFirst: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
      },
    });
    await expect(service.getMessages(1n, 999n)).rejects.toThrow(NotFoundException);
    await expect(service.sendMessage(1n, 999n, 'hola')).rejects.toThrow(NotFoundException);
    await expect(service.markRead(1n, 999n)).rejects.toThrow(NotFoundException);
  });

  it('no se puede enviar a un hilo cerrado', async () => {
    const { service } = makeService({
      threadParticipant: {
        findUnique: jest.fn().mockResolvedValue({ thread: { closedAt: new Date() } }),
        findMany: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
      },
    });
    await expect(service.sendMessage(1n, PARENT.id, 'hola')).rejects.toThrow(BadRequestException);
  });

  it('sendMessage marca como leído el propio mensaje del remitente y notifica a los demás sin silenciar', async () => {
    const { service, prisma, notifications } = makeService({
      threadParticipant: {
        findUnique: jest.fn().mockResolvedValue({ thread: { closedAt: null } }),
        findMany: jest.fn().mockResolvedValue([{ userId: TEACHER.id }]), // el otro participante, no muteado
        createMany: jest.fn(),
        update: jest.fn(),
      },
      threadMessage: {
        create: jest.fn().mockResolvedValue({ id: 9n, sentAt: new Date() }),
        findMany: jest.fn(),
      },
      thread: { update: jest.fn(), findFirst: jest.fn(), create: jest.fn() },
      user: { findUnique: jest.fn().mockResolvedValue({ firstName: 'Rosa', lastName: 'Quispe' }) },
    });

    await service.sendMessage(1n, PARENT.id, 'hola profe');
    // El push a los demás participantes es fire-and-forget (no bloquea la
    // respuesta al remitente): `setImmediate` deja drenar toda la cola de
    // microtasks pendientes (los dos `await` internos de `notifyOthers`)
    // antes de verificar que se llamó.
    await new Promise((resolve) => setImmediate(resolve));

    expect(prisma.threadParticipant.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { threadId_userId: { threadId: 1n, userId: PARENT.id } },
      }),
    );
    expect(notifications.sendToUser).toHaveBeenCalledWith(
      TEACHER.id,
      expect.any(String),
      expect.any(String),
      expect.objectContaining({ screen: 'thread', threadId: '1' }),
    );
  });

  it('no notifica al participante que silenció el hilo', async () => {
    const { service, notifications } = makeService({
      threadParticipant: {
        findUnique: jest.fn().mockResolvedValue({ thread: { closedAt: null } }),
        // El filtro mutedAt: null ya lo aplica la query; en la prueba se
        // simula que no queda nadie a quien avisar.
        findMany: jest.fn().mockResolvedValue([]),
        createMany: jest.fn(),
        update: jest.fn(),
      },
      threadMessage: { create: jest.fn().mockResolvedValue({ id: 9n, sentAt: new Date() }), findMany: jest.fn() },
      thread: { update: jest.fn(), findFirst: jest.fn(), create: jest.fn() },
    });
    await service.sendMessage(1n, PARENT.id, 'hola');
    expect(notifications.sendToUser).not.toHaveBeenCalled();
  });
});

describe('ThreadsService.getMessages — paginación', () => {
  it('pide una página anterior con el cursor `before` y devuelve en orden cronológico', async () => {
    const { service, prisma } = makeService({
      threadParticipant: {
        findUnique: jest.fn().mockResolvedValue({ thread: { closedAt: null } }),
        findMany: jest.fn(),
        findFirst: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
      },
      threadMessage: {
        findMany: jest.fn().mockResolvedValue([
          { id: 5n, senderId: PARENT.id, body: 'b', sentAt: new Date(), editedAt: null, sender: { firstName: 'Rosa', lastName: null } },
          { id: 4n, senderId: TEACHER.id, body: 'a', sentAt: new Date(), editedAt: null, sender: { firstName: 'Ana', lastName: null } },
        ]),
        create: jest.fn(),
      },
    });

    const result = await service.getMessages(1n, PARENT.id, 10n, 30);
    expect(prisma.threadMessage.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ id: { lt: 10n } }) }),
    );
    // Se pidió desc (id 5, luego 4) y se devuelve invertido: 4 antes que 5.
    expect(result.messages.map((m) => m.id)).toEqual(['4', '5']);
  });

  it('incluye el lastReadAt del OTRO participante, para el doble check de leído', async () => {
    const readAt = new Date('2026-08-31T10:00:00.000Z');
    const { service, prisma } = makeService({
      threadParticipant: {
        findUnique: jest.fn().mockResolvedValue({ thread: { closedAt: null } }),
        findMany: jest.fn(),
        findFirst: jest.fn().mockResolvedValue({ lastReadAt: readAt, user: { lastActiveAt: null } }),
        createMany: jest.fn(),
        update: jest.fn(),
      },
      threadMessage: { findMany: jest.fn().mockResolvedValue([]), create: jest.fn() },
    });

    const result = await service.getMessages(1n, PARENT.id);
    expect(result.otherLastReadAt).toEqual(readAt);
    expect(prisma.threadParticipant.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({ where: { threadId: 1n, userId: { not: PARENT.id } } }),
    );
  });

  it('otherLastReadAt es null si el otro participante nunca leyó', async () => {
    const { service } = makeService({
      threadParticipant: {
        findUnique: jest.fn().mockResolvedValue({ thread: { closedAt: null } }),
        findMany: jest.fn(),
        findFirst: jest.fn().mockResolvedValue({ lastReadAt: null, user: { lastActiveAt: null } }),
        createMany: jest.fn(),
        update: jest.fn(),
      },
      threadMessage: { findMany: jest.fn().mockResolvedValue([]), create: jest.fn() },
    });

    const result = await service.getMessages(1n, PARENT.id);
    expect(result.otherLastReadAt).toBeNull();
  });

  it('incluye el lastActiveAt del otro participante, para el doble check por "le llegó" sin haber leído el hilo', async () => {
    const activeAt = new Date('2026-08-31T10:05:00.000Z');
    const { service } = makeService({
      threadParticipant: {
        findUnique: jest.fn().mockResolvedValue({ thread: { closedAt: null } }),
        findMany: jest.fn(),
        findFirst: jest.fn().mockResolvedValue({ lastReadAt: null, user: { lastActiveAt: activeAt } }),
        createMany: jest.fn(),
        update: jest.fn(),
      },
      threadMessage: { findMany: jest.fn().mockResolvedValue([]), create: jest.fn() },
    });

    const result = await service.getMessages(1n, PARENT.id);
    expect(result.otherLastReadAt).toBeNull();
    expect(result.otherLastActiveAt).toEqual(activeAt);
  });

  it('assertParticipant corre en paralelo con las otras dos consultas, no antes (perf: 1 sola etapa, no 2)', async () => {
    const order: string[] = [];
    const findUnique = jest.fn().mockImplementation(async () => {
      order.push('assertParticipant:start');
      return { thread: { closedAt: null } };
    });
    const findManyMessages = jest.fn().mockImplementation(async () => {
      order.push('messages:start');
      return [];
    });
    const findFirstParticipant = jest.fn().mockImplementation(async () => {
      order.push('otherParticipant:start');
      return { lastReadAt: null, user: { lastActiveAt: null } };
    });
    const { service } = makeService({
      threadParticipant: {
        findUnique,
        findFirst: findFirstParticipant,
        findMany: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
      },
      threadMessage: { findMany: findManyMessages, create: jest.fn() },
    });

    await service.getMessages(1n, PARENT.id);

    // Las 3 arrancan ANTES de que cualquiera termine — si `assertParticipant`
    // se esperara primero (como antes), las otras dos ni se habrían llamado
    // todavía en este punto.
    expect(order).toEqual(['assertParticipant:start', 'messages:start', 'otherParticipant:start']);
    expect(findUnique).toHaveBeenCalledTimes(1);
    expect(findManyMessages).toHaveBeenCalledTimes(1);
    expect(findFirstParticipant).toHaveBeenCalledTimes(1);
  });

  it('si no soy participante, sigue lanzando 404 aunque las otras dos consultas ya se hayan disparado en paralelo', async () => {
    const findManyMessages = jest.fn().mockResolvedValue([]);
    const findFirstParticipant = jest.fn().mockResolvedValue(null);
    const { service } = makeService({
      threadParticipant: {
        findUnique: jest.fn().mockResolvedValue(null), // no participa
        findFirst: findFirstParticipant,
        findMany: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
      },
      threadMessage: { findMany: findManyMessages, create: jest.fn() },
    });

    await expect(service.getMessages(1n, 999n)).rejects.toThrow(NotFoundException);
    // Se dispararon igual (se corrieron en paralelo) — el punto es que el
    // resultado nunca llega a usarse para construir una respuesta.
    expect(findManyMessages).toHaveBeenCalledTimes(1);
    expect(findFirstParticipant).toHaveBeenCalledTimes(1);
  });
});

describe('ThreadsService.getContacts — a quién se le puede escribir', () => {
  it('un padre ve a los docentes de sus hijos (con los alumnos en común) y al director', async () => {
    const { service, prisma } = makeService({
      user: {
        findMany: jest.fn().mockResolvedValue([
          { id: ADMIN.id, firstName: 'Directora', lastName: null, avatar: null },
        ]),
      },
      userStudent: {
        findFirst: jest.fn(),
        findMany: jest.fn().mockResolvedValue([
          { studentId: STUDENT, student: { firstName: 'Juan', lastName: 'Quispe' } },
        ]),
      },
      classroomCourse: {
        findFirst: jest.fn(),
        findMany: jest.fn().mockResolvedValue([
          {
            teacherId: TEACHER.id,
            teacher: { firstName: 'Ana', lastName: 'Pérez', avatar: null },
            classroom: { enrollments: [{ studentId: STUDENT }] },
          },
        ]),
      },
    });

    const contacts = await service.getContacts(SCHOOL_A, PARENT);
    expect(contacts).toHaveLength(2);
    const teacher = contacts.find((c) => c.role === 'teacher')!;
    expect(teacher.userId).toBe(TEACHER.id.toString());
    expect(teacher.students).toEqual([{ id: STUDENT.toString(), name: 'Juan Quispe' }]);
    expect(contacts.some((c) => c.role === 'school_admin')).toBe(true);
  });

  it('un padre sin hijos registrados solo ve al director', async () => {
    const { service } = makeService({
      user: {
        findMany: jest
          .fn()
          .mockResolvedValue([{ id: ADMIN.id, firstName: 'Directora', lastName: null, avatar: null }]),
      },
      userStudent: { findFirst: jest.fn(), findMany: jest.fn().mockResolvedValue([]) },
    });
    const contacts = await service.getContacts(SCHOOL_A, PARENT);
    expect(contacts).toEqual([
      { userId: ADMIN.id.toString(), name: 'Directora', avatar: null, role: 'school_admin', students: [] },
    ]);
  });

  it('un docente ve a los padres de sus alumnos, agrupados por padre', async () => {
    const { service } = makeService({
      user: {
        findMany: jest.fn().mockResolvedValue([]), // sin director configurado en este colegio de prueba
      },
      classroomCourse: {
        findFirst: jest.fn(),
        findMany: jest.fn().mockResolvedValue([{ classroomId: 900n }]),
      },
      studentEnrollment: {
        findMany: jest.fn().mockResolvedValue([
          { studentId: STUDENT, student: { firstName: 'Juan', lastName: 'Quispe' } },
          { studentId: OTHER_STUDENT, student: { firstName: 'Ana', lastName: 'García' } },
        ]),
      },
      userStudent: {
        findFirst: jest.fn(),
        findMany: jest.fn().mockResolvedValue([
          { userId: PARENT.id, studentId: STUDENT, user: { firstName: 'Rosa', lastName: 'Quispe', avatar: null } },
          {
            userId: PARENT.id,
            studentId: OTHER_STUDENT,
            user: { firstName: 'Rosa', lastName: 'Quispe', avatar: null },
          },
        ]),
      },
    });

    const contacts = await service.getContacts(SCHOOL_A, TEACHER);
    expect(contacts).toHaveLength(1);
    expect(contacts[0].userId).toBe(PARENT.id.toString());
    // Un mismo padre con dos hijos en el aula del docente: se agrupan en un
    // solo contacto con ambos alumnos listados, no en dos filas repetidas.
    expect(contacts[0].students.map((s) => s.id).sort()).toEqual(
      [STUDENT.toString(), OTHER_STUDENT.toString()].sort(),
    );
  });

  it('el director ve a los docentes del colegio, no a los padres', async () => {
    const { service, prisma } = makeService({
      user: {
        findMany: jest
          .fn()
          .mockResolvedValueOnce([]) // admins (excluyéndose a sí mismo)
          .mockResolvedValueOnce([
            { id: TEACHER.id, firstName: 'Ana', lastName: 'Pérez', avatar: null },
          ]),
      },
    });
    const contacts = await service.getContacts(SCHOOL_A, ADMIN);
    expect(contacts).toEqual([
      { userId: TEACHER.id.toString(), name: 'Ana Pérez', avatar: null, role: 'teacher', students: [] },
    ]);
    expect(prisma.user.findMany).toHaveBeenCalledTimes(2);
  });
});

describe('ThreadsService — menciones de tareas (@)', () => {
  it('busca tareas del aula del alumno del hilo', async () => {
    const { service, prisma } = makeService({
      threadParticipant: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ thread: { closedAt: null, studentId: STUDENT } }),
        findMany: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
      },
      studentEnrollment: {
        findFirst: jest.fn().mockResolvedValue({ classroomId: 900n }),
      },
      homework: {
        findMany: jest.fn().mockResolvedValue([
          { id: 1n, title: 'Tarea de matemática', dueDate: new Date('2026-09-01'), course: { name: 'Matemática' } },
        ]),
        count: jest.fn(),
      },
      gcCoursework: { findMany: jest.fn().mockResolvedValue([]) },
    });

    const results = await service.searchMentions(1n, PARENT.id, 'mate');
    expect(results).toEqual([
      {
        id: '1',
        type: 'homework',
        title: 'Tarea de matemática',
        dueDate: new Date('2026-09-01'),
        courseName: 'Matemática',
      },
    ]);
    expect(prisma.homework.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          classroomId: 900n,
          title: { contains: 'mate', mode: 'insensitive' },
        }),
      }),
    );
  });

  it('busca tareas de Google Classroom del alumno del hilo', async () => {
    const { service, prisma } = makeService({
      threadParticipant: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ thread: { closedAt: null, studentId: STUDENT } }),
        findMany: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
      },
      studentEnrollment: { findFirst: jest.fn().mockResolvedValue(null) },
      homework: { findMany: jest.fn().mockResolvedValue([]), count: jest.fn() },
      gcCoursework: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 7n,
            title: 'Ensayo de comprensión lectora',
            dueDate: new Date('2026-09-05'),
            course: { name: 'Comunicación' },
          },
        ]),
      },
    });

    const results = await service.searchMentions(1n, PARENT.id, 'ensayo');
    expect(results).toEqual([
      {
        id: '7',
        type: 'gc-coursework',
        title: 'Ensayo de comprensión lectora',
        dueDate: new Date('2026-09-05'),
        courseName: 'Comunicación',
      },
    ]);
    expect(prisma.gcCoursework.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          course: { studentId: STUDENT },
          state: 'PUBLISHED',
          title: { contains: 'ensayo', mode: 'insensitive' },
        }),
      }),
    );
  });

  it('combina tareas institucionales y de Classroom, ordenadas por fecha de vencimiento', async () => {
    const { service } = makeService({
      threadParticipant: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ thread: { closedAt: null, studentId: STUDENT } }),
        findMany: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
      },
      studentEnrollment: { findFirst: jest.fn().mockResolvedValue({ classroomId: 900n }) },
      homework: {
        findMany: jest.fn().mockResolvedValue([
          { id: 1n, title: 'Tarea institucional', dueDate: new Date('2026-09-10'), course: { name: 'Matemática' } },
        ]),
        count: jest.fn(),
      },
      gcCoursework: {
        findMany: jest.fn().mockResolvedValue([
          { id: 7n, title: 'Tarea de Classroom', dueDate: new Date('2026-09-02'), course: { name: 'Comunicación' } },
        ]),
      },
    });

    const results = await service.searchMentions(1n, PARENT.id, '');
    expect(results.map((r) => r.id)).toEqual(['7', '1']); // la de Classroom vence antes
  });

  it('un hilo sin alumno (ej. con el director) no tiene tareas que mencionar', async () => {
    const { service } = makeService({
      threadParticipant: {
        findUnique: jest.fn().mockResolvedValue({ thread: { closedAt: null, studentId: null } }),
        findMany: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
      },
    });
    await expect(service.searchMentions(1n, ADMIN.id, '')).resolves.toEqual([]);
  });

  it('quien no participa no puede buscar tareas del hilo', async () => {
    const { service } = makeService({
      threadParticipant: { findUnique: jest.fn().mockResolvedValue(null), findMany: jest.fn(), createMany: jest.fn(), update: jest.fn() },
    });
    await expect(service.searchMentions(1n, 999n, '')).rejects.toThrow(NotFoundException);
  });

  it('permite enviar un mensaje que menciona una tarea del aula del alumno del hilo', async () => {
    const { service, prisma } = makeService({
      threadParticipant: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ thread: { closedAt: null, studentId: STUDENT } }),
        findMany: jest.fn().mockResolvedValue([]),
        createMany: jest.fn(),
        update: jest.fn(),
      },
      studentEnrollment: { findFirst: jest.fn().mockResolvedValue({ classroomId: 900n }) },
      homework: { findMany: jest.fn(), count: jest.fn().mockResolvedValue(1) },
      threadMessage: { create: jest.fn().mockResolvedValue({ id: 1n, sentAt: new Date() }), findMany: jest.fn() },
      thread: { update: jest.fn(), findFirst: jest.fn(), create: jest.fn() },
    });

    await service.sendMessage(1n, PARENT.id, 'Revisa esto: @[Tarea de mañana](homework:42)');
    expect(prisma.homework.count).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ id: { in: [42n] }, classroomId: 900n }) }),
    );
    expect(prisma.threadMessage.create).toHaveBeenCalled();
  });

  it('rechaza mencionar una tarea que no pertenece al aula del alumno del hilo', async () => {
    const { service } = makeService({
      threadParticipant: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ thread: { closedAt: null, studentId: STUDENT } }),
        findMany: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
      },
      studentEnrollment: { findFirst: jest.fn().mockResolvedValue({ classroomId: 900n }) },
      // El count no coincide con la cantidad mencionada: la tarea 42 no es de este aula.
      homework: { findMany: jest.fn(), count: jest.fn().mockResolvedValue(0) },
    });

    await expect(
      service.sendMessage(1n, PARENT.id, '@[Tarea ajena](homework:42)'),
    ).rejects.toThrow(BadRequestException);
  });

  it('un hilo sin alumno no puede mencionar tareas aunque el texto tenga el formato', async () => {
    const { service } = makeService({
      threadParticipant: {
        findUnique: jest.fn().mockResolvedValue({ thread: { closedAt: null, studentId: null } }),
        findMany: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
      },
    });
    await expect(
      service.sendMessage(1n, ADMIN.id, '@[Algo](homework:1)'),
    ).rejects.toThrow(BadRequestException);
  });

  it('permite enviar un mensaje que menciona una tarea de Classroom del alumno del hilo', async () => {
    const { service, prisma } = makeService({
      threadParticipant: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ thread: { closedAt: null, studentId: STUDENT } }),
        findMany: jest.fn().mockResolvedValue([]),
        createMany: jest.fn(),
        update: jest.fn(),
      },
      gcCoursework: { findMany: jest.fn(), count: jest.fn().mockResolvedValue(1) },
      threadMessage: { create: jest.fn().mockResolvedValue({ id: 1n, sentAt: new Date() }), findMany: jest.fn() },
      thread: { update: jest.fn(), findFirst: jest.fn(), create: jest.fn() },
    });

    await service.sendMessage(1n, PARENT.id, 'Revisa esto: @[Ensayo](gc-coursework:7)');
    expect(prisma.gcCoursework.count).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ id: { in: [7n] }, course: { studentId: STUDENT } }),
      }),
    );
    expect(prisma.threadMessage.create).toHaveBeenCalled();
  });

  it('rechaza mencionar una tarea de Classroom que no pertenece al alumno del hilo', async () => {
    const { service } = makeService({
      threadParticipant: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ thread: { closedAt: null, studentId: STUDENT } }),
        findMany: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
      },
      // El count no coincide con la cantidad mencionada: la tarea 7 no es de este alumno.
      gcCoursework: { findMany: jest.fn(), count: jest.fn().mockResolvedValue(0) },
    });

    await expect(
      service.sendMessage(1n, PARENT.id, '@[Tarea ajena](gc-coursework:7)'),
    ).rejects.toThrow(BadRequestException);
  });

  it('un hilo sin alumno no puede mencionar tareas de Classroom aunque el texto tenga el formato', async () => {
    const { service } = makeService({
      threadParticipant: {
        findUnique: jest.fn().mockResolvedValue({ thread: { closedAt: null, studentId: null } }),
        findMany: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
      },
    });
    await expect(
      service.sendMessage(1n, ADMIN.id, '@[Algo](gc-coursework:1)'),
    ).rejects.toThrow(BadRequestException);
  });

  it('resuelve el link externo de una tarea de Classroom mencionada', async () => {
    const { service, prisma } = makeService({
      threadParticipant: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ thread: { closedAt: null, studentId: STUDENT } }),
        findMany: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
      },
      gcCoursework: {
        findFirst: jest.fn().mockResolvedValue({ alternateLink: 'https://classroom.google.com/c/x' }),
      },
    });

    await expect(service.getClassroomTaskLink(1n, PARENT.id, 7n)).resolves.toEqual({
      alternateLink: 'https://classroom.google.com/c/x',
    });
    expect(prisma.gcCoursework.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: 7n, course: { studentId: STUDENT } } }),
    );
  });

  it('un hilo sin alumno nunca resuelve un link de Classroom', async () => {
    const { service } = makeService({
      threadParticipant: {
        findUnique: jest.fn().mockResolvedValue({ thread: { closedAt: null, studentId: null } }),
        findMany: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
      },
    });
    await expect(service.getClassroomTaskLink(1n, ADMIN.id, 7n)).rejects.toThrow(NotFoundException);
  });

  it('no resuelve el link de una tarea de Classroom que no es del alumno del hilo', async () => {
    const { service } = makeService({
      threadParticipant: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ thread: { closedAt: null, studentId: STUDENT } }),
        findMany: jest.fn(),
        createMany: jest.fn(),
        update: jest.fn(),
      },
      gcCoursework: { findFirst: jest.fn().mockResolvedValue(null) },
    });
    await expect(service.getClassroomTaskLink(1n, PARENT.id, 999n)).rejects.toThrow(NotFoundException);
  });
});
