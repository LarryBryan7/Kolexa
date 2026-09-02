// ============================================================
// threads.service.ts — Mensajería 1:1 (padre ↔ docente ↔ director)
// ============================================================
// Reemplaza los módulos `messages` y `chat`, que coexistían sin conocerse y
// sin validar el colegio del destinatario. Ver auditoría de mensajería del
// 30-08-2026. Un solo modelo: Thread + ThreadParticipant + ThreadMessage.
//
// La regla de permisos, en una frase: una conversación entre un padre y un
// docente solo existe si comparten un alumno. El alumno es la llave, no el
// usuario — por eso `studentId` es obligatorio salvo que uno de los dos
// lados sea director/admin del colegio.
//
// El no-leído en sí (mostrar el punto) sigue siendo una comparación de
// fechas: `thread.lastMessageAt` contra `participant.lastReadAt`, una fila
// por participante, no una por mensaje. El CONTADOR (cuántos, para el
// badge "1"/"2"/"9+") sí cuenta mensajes de verdad — ver getInbox — pero
// solo at-vuelo sobre `sentAt`, sin ninguna tabla nueva de "leído por
// mensaje".
// ============================================================

import {
  Injectable,
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

export interface ThreadSummary {
  id: string;
  kind: string;
  subject: string | null;
  studentId: string | null;
  studentName: string | null;
  priority: string;
  lastMessageAt: Date;
  unread: boolean;
  unreadCount: number;
  muted: boolean;
  otherParticipant: { id: string; name: string; avatar: string | null; online: boolean } | null;
  lastMessage: { body: string; senderId: string; sentAt: Date } | null;
}

export interface ThreadMessageView {
  id: string;
  senderId: string;
  senderName: string;
  body: string;
  sentAt: Date;
  editedAt: Date | null;
}

export interface Contact {
  userId: string;
  name: string;
  avatar: string | null;
  role: string;
  // Alumno(s) que hacen válida esta conversación. Vacío para hilos con el
  // director, donde no hace falta indicar uno.
  students: { id: string; name: string }[];
}

const ADMIN_ROLES = ['school_admin', 'director'];
const isAdmin = (roles: string[]) => roles.some((r) => ADMIN_ROLES.includes(r));

// Punto verde/gris de "en línea": sin WebSocket ni tabla de sesiones, se
// aproxima con `User.lastActiveAt` (actualizado con throttle en cada
// request autenticado, ver JwtStrategy). 3 minutos es margen suficiente
// para que no parpadee entre requests normales, sin quedar "en línea"
// mucho después de cerrar la app.
const ONLINE_THRESHOLD_MS = 3 * 60 * 1000;
const isOnline = (lastActiveAt: Date | null) =>
  !!lastActiveAt && Date.now() - lastActiveAt.getTime() < ONLINE_THRESHOLD_MS;

@Injectable()
export class ThreadsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  // ── Bandeja ───────────────────────────────────────────────
  async getInbox(userId: bigint, schoolId: bigint): Promise<ThreadSummary[]> {
    const parts = await this.prisma.threadParticipant.findMany({
      where: { userId, thread: { schoolId } },
      select: {
        lastReadAt: true,
        mutedAt: true,
        thread: {
          select: {
            id: true,
            kind: true,
            subject: true,
            studentId: true,
            priority: true,
            lastMessageAt: true,
            student: { select: { firstName: true, lastName: true } },
            participants: {
              where: { userId: { not: userId } },
              select: {
                user: {
                  select: { id: true, firstName: true, lastName: true, avatar: true, lastActiveAt: true },
                },
              },
            },
          },
        },
      },
      orderBy: { thread: { lastMessageAt: 'desc' } },
    });

    if (parts.length === 0) return [];

    // Un query aparte para el último mensaje de cada hilo, en vez de un N+1
    // por hilo: se traen todos y se agrupa en memoria (la bandeja de un
    // usuario nunca tiene miles de hilos).
    const threadIds = parts.map((p) => p.thread.id);
    const lastMessages = await this.prisma.threadMessage.findMany({
      where: { threadId: { in: threadIds }, deletedAt: null },
      orderBy: { sentAt: 'desc' },
      select: { threadId: true, body: true, senderId: true, sentAt: true },
    });
    const lastByThread = new Map<string, (typeof lastMessages)[number]>();
    for (const m of lastMessages) {
      const key = m.threadId.toString();
      if (!lastByThread.has(key)) lastByThread.set(key, m);
    }

    // Para el badge numérico: mensajes de LA OTRA persona (nunca los
    // propios) por hilo, livianos (solo threadId+sentAt) — se comparan en
    // memoria contra el `lastReadAt` de ESE hilo, que ya varía por hilo y
    // no se puede expresar en un solo WHERE de groupBy.
    const otherMessages = await this.prisma.threadMessage.findMany({
      where: { threadId: { in: threadIds }, deletedAt: null, senderId: { not: userId } },
      select: { threadId: true, sentAt: true },
    });
    const sentAtsByThread = new Map<string, Date[]>();
    for (const m of otherMessages) {
      const key = m.threadId.toString();
      const arr = sentAtsByThread.get(key);
      if (arr) arr.push(m.sentAt);
      else sentAtsByThread.set(key, [m.sentAt]);
    }

    return parts
      .map((p) => {
        const t = p.thread;
        const other = t.participants[0]?.user ?? null;
        const last = lastByThread.get(t.id.toString()) ?? null;
        return {
          id: t.id.toString(),
          kind: t.kind,
          subject: t.subject,
          studentId: t.studentId?.toString() ?? null,
          studentName: t.student
            ? `${t.student.firstName} ${t.student.lastName ?? ''}`.trim()
            : null,
          priority: t.priority,
          lastMessageAt: t.lastMessageAt,
          unread: !p.lastReadAt || p.lastReadAt < t.lastMessageAt,
          unreadCount: (sentAtsByThread.get(t.id.toString()) ?? []).filter(
            (sentAt) => !p.lastReadAt || sentAt > p.lastReadAt,
          ).length,
          muted: !!p.mutedAt,
          otherParticipant: other
            ? {
                id: other.id.toString(),
                name: `${other.firstName} ${other.lastName ?? ''}`.trim(),
                avatar: other.avatar,
                online: isOnline(other.lastActiveAt),
              }
            : null,
          lastMessage: last
            ? { body: this.stripMentions(last.body), senderId: last.senderId.toString(), sentAt: last.sentAt }
            : null,
        };
      })
      .sort((a, b) => b.lastMessageAt.getTime() - a.lastMessageAt.getTime());
  }

  async getUnreadCount(userId: bigint, schoolId: bigint): Promise<number> {
    const parts = await this.prisma.threadParticipant.findMany({
      where: { userId, thread: { schoolId } },
      select: { lastReadAt: true, thread: { select: { lastMessageAt: true } } },
    });
    return parts.filter((p) => !p.lastReadAt || p.lastReadAt < p.thread.lastMessageAt)
      .length;
  }

  // ── Contactos válidos para empezar una conversación ──────────
  // Refleja exactamente la regla de `assertCanMessage`, en el sentido
  // contrario: en vez de validar un destinatario propuesto, enumera a quién
  // se le puede escribir. Así el compositor nunca muestra a nadie que
  // `openThread` fuera a rechazar después.
  async getContacts(schoolId: bigint, user: { id: bigint; roles: string[] }): Promise<Contact[]> {
    // `admins` no depende de ninguna otra consulta de este método (ni al
    // revés), así que corre en paralelo con la primera consulta específica
    // de cada rama de rol en vez de esperarla primero — la base está lejos
    // (~150ms por viaje), así que cada ida y vuelta que se paraleliza cuenta.
    const adminsPromise = this.prisma.user.findMany({
      where: {
        id: { not: user.id },
        deletedAt: null,
        userRoles: { some: { schoolId, role: { name: { in: ADMIN_ROLES } } } },
      },
      select: { id: true, firstName: true, lastName: true, avatar: true },
    });
    const toAdminContacts = (admins: Awaited<typeof adminsPromise>): Contact[] =>
      admins.map((a) => ({
        userId: a.id.toString(),
        name: `${a.firstName} ${a.lastName ?? ''}`.trim(),
        avatar: a.avatar,
        role: 'school_admin',
        students: [],
      }));

    if (isAdmin(user.roles)) {
      // El director puede escribirle a cualquier docente del colegio (y a
      // otros admins). No enumera padres: son demasiados para una lista sin
      // buscador, que queda fuera de esta primera versión.
      const [admins, staff] = await Promise.all([
        adminsPromise,
        this.prisma.user.findMany({
          where: {
            id: { not: user.id },
            deletedAt: null,
            userRoles: { some: { schoolId, role: { name: 'teacher' } } },
          },
          select: { id: true, firstName: true, lastName: true, avatar: true },
        }),
      ]);
      const adminContacts = toAdminContacts(admins);
      const staffContacts: Contact[] = staff.map((t) => ({
        userId: t.id.toString(),
        name: `${t.firstName} ${t.lastName ?? ''}`.trim(),
        avatar: t.avatar,
        role: 'teacher',
        students: [],
      }));
      return [...staffContacts, ...adminContacts];
    }

    if (user.roles.includes('parent')) {
      const [admins, myStudents] = await Promise.all([
        adminsPromise,
        this.prisma.userStudent.findMany({
          where: { userId: user.id },
          select: { studentId: true, student: { select: { firstName: true, lastName: true } } },
        }),
      ]);
      const adminContacts = toAdminContacts(admins);
      if (myStudents.length === 0) return adminContacts;
      const studentIds = myStudents.map((s) => s.studentId);
      const studentName = new Map(
        myStudents.map((s) => [
          s.studentId.toString(),
          `${s.student.firstName} ${s.student.lastName ?? ''}`.trim(),
        ]),
      );

      const links = await this.prisma.classroomCourse.findMany({
        where: {
          teacherId: { not: null },
          classroom: { enrollments: { some: { studentId: { in: studentIds }, isActive: true } } },
        },
        select: {
          teacherId: true,
          teacher: { select: { firstName: true, lastName: true, avatar: true } },
          classroom: {
            select: {
              enrollments: {
                where: { studentId: { in: studentIds }, isActive: true },
                select: { studentId: true },
              },
            },
          },
        },
      });

      const byTeacher = new Map<
        string,
        { name: string; avatar: string | null; studentIds: Set<string> }
      >();
      for (const link of links) {
        if (!link.teacherId || !link.teacher) continue;
        const key = link.teacherId.toString();
        if (!byTeacher.has(key)) {
          byTeacher.set(key, {
            name: `${link.teacher.firstName} ${link.teacher.lastName ?? ''}`.trim(),
            avatar: link.teacher.avatar,
            studentIds: new Set(),
          });
        }
        for (const e of link.classroom.enrollments) {
          byTeacher.get(key)!.studentIds.add(e.studentId.toString());
        }
      }

      const teacherContacts: Contact[] = [...byTeacher.entries()].map(([id, v]) => ({
        userId: id,
        name: v.name,
        avatar: v.avatar,
        role: 'teacher',
        students: [...v.studentIds].map((sid) => ({ id: sid, name: studentName.get(sid) ?? '' })),
      }));
      return [...teacherContacts, ...adminContacts];
    }

    if (user.roles.includes('teacher')) {
      const [admins, myClassrooms] = await Promise.all([
        adminsPromise,
        this.prisma.classroomCourse.findMany({
          where: { teacherId: user.id },
          select: { classroomId: true },
          distinct: ['classroomId'],
        }),
      ]);
      const adminContacts = toAdminContacts(admins);
      if (myClassrooms.length === 0) return adminContacts;
      const classroomIds = myClassrooms.map((c) => c.classroomId);

      const enrollments = await this.prisma.studentEnrollment.findMany({
        where: { classroomId: { in: classroomIds }, isActive: true },
        select: { studentId: true, student: { select: { firstName: true, lastName: true } } },
      });
      const studentName = new Map(
        enrollments.map((e) => [
          e.studentId.toString(),
          `${e.student.firstName} ${e.student.lastName ?? ''}`.trim(),
        ]),
      );
      const studentIds = enrollments.map((e) => e.studentId);
      if (studentIds.length === 0) return adminContacts;

      const parentLinks = await this.prisma.userStudent.findMany({
        where: { studentId: { in: studentIds } },
        select: {
          userId: true,
          studentId: true,
          user: { select: { firstName: true, lastName: true, avatar: true } },
        },
      });

      const byParent = new Map<
        string,
        { name: string; avatar: string | null; studentIds: Set<string> }
      >();
      for (const link of parentLinks) {
        const key = link.userId.toString();
        if (!byParent.has(key)) {
          byParent.set(key, {
            name: `${link.user.firstName} ${link.user.lastName ?? ''}`.trim(),
            avatar: link.user.avatar,
            studentIds: new Set(),
          });
        }
        byParent.get(key)!.studentIds.add(link.studentId.toString());
      }

      const parentContacts: Contact[] = [...byParent.entries()].map(([id, v]) => ({
        userId: id,
        name: v.name,
        avatar: v.avatar,
        role: 'parent',
        students: [...v.studentIds].map((sid) => ({ id: sid, name: studentName.get(sid) ?? '' })),
      }));
      return [...parentContacts, ...adminContacts];
    }

    return toAdminContacts(await adminsPromise);
  }

  // ── Abrir / reutilizar hilo ───────────────────────────────
  async openThread(
    schoolId: bigint,
    sender: { id: bigint; roles: string[] },
    dto: { recipientId: bigint; studentId?: bigint; subject?: string; firstMessageBody: string },
  ) {
    const recipientId = dto.recipientId;
    if (recipientId === sender.id) {
      throw new BadRequestException('No puedes iniciar una conversación contigo mismo');
    }

    const recipient = await this.prisma.user.findFirst({
      where: { id: recipientId, deletedAt: null, userRoles: { some: { schoolId } } },
      select: {
        id: true,
        userRoles: { where: { schoolId }, select: { role: { select: { name: true } } } },
      },
    });
    // NotFoundException, no Forbidden: no se revela si el usuario existe en
    // otro colegio. Mismo criterio que el resto de endpoints multi-tenant.
    if (!recipient) throw new NotFoundException('Destinatario no encontrado');
    const recipientRoles = recipient.userRoles.map((r) => r.role.name);

    const studentId = dto.studentId ?? null;
    await this.assertCanMessage(sender, { id: recipient.id, roles: recipientRoles }, studentId);

    // Reutiliza el hilo si ya existe uno igual (mismo par de personas, mismo
    // alumno) en vez de crear uno nuevo cada vez que el padre escribe.
    const existing = await this.prisma.thread.findFirst({
      where: {
        schoolId,
        kind: 'direct',
        studentId: studentId ?? undefined,
        AND: [
          { participants: { some: { userId: sender.id } } },
          { participants: { some: { userId: recipientId } } },
        ],
      },
      select: { id: true },
    });

    const threadId = existing
      ? existing.id
      : await this.prisma.$transaction(async (tx) => {
          const t = await tx.thread.create({
            data: {
              schoolId,
              kind: 'direct',
              subject: dto.subject,
              studentId: studentId ?? undefined,
              lastMessageAt: new Date(),
            },
            select: { id: true },
          });
          await tx.threadParticipant.createMany({
            data: [
              { threadId: t.id, userId: sender.id, lastReadAt: new Date() },
              { threadId: t.id, userId: recipientId },
            ],
          });
          return t.id;
        });

    await this.sendMessage(threadId, sender.id, dto.firstMessageBody);
    return { threadId: threadId.toString() };
  }

  // ── Mensajes de un hilo ───────────────────────────────────
  async getMessages(
    threadId: bigint,
    userId: bigint,
    before?: bigint,
    limit = 30,
  ): Promise<{ messages: ThreadMessageView[]; otherLastReadAt: Date | null }> {
    await this.assertParticipant(threadId, userId);

    // El "doble check" de leído se arma en el cliente comparando el
    // `sentAt` de cada mensaje propio contra esto — no hay una tabla de
    // "leído por mensaje", el hilo ya guarda un solo `lastReadAt` por
    // participante (ver auditoría de mensajería: no-leído nunca se
    // cuenta por fila, se compara). Ambas consultas son independientes.
    const [rows, otherParticipant] = await Promise.all([
      this.prisma.threadMessage.findMany({
        where: {
          threadId,
          deletedAt: null,
          ...(before ? { id: { lt: before } } : {}),
        },
        orderBy: { id: 'desc' },
        take: limit,
        select: {
          id: true,
          senderId: true,
          body: true,
          sentAt: true,
          editedAt: true,
          sender: { select: { firstName: true, lastName: true } },
        },
      }),
      this.prisma.threadParticipant.findFirst({
        where: { threadId, userId: { not: userId } },
        select: { lastReadAt: true },
      }),
    ]);

    // Se pidieron descendente (para el cursor "antes de X"), se devuelven en
    // orden cronológico para pintarlas directo en la pantalla.
    const messages = rows.reverse().map((m) => ({
      id: m.id.toString(),
      senderId: m.senderId.toString(),
      senderName: `${m.sender.firstName} ${m.sender.lastName ?? ''}`.trim(),
      body: m.body,
      sentAt: m.sentAt,
      editedAt: m.editedAt,
    }));

    return { messages, otherLastReadAt: otherParticipant?.lastReadAt ?? null };
  }

  // Formato de mención: "@[Título de la tarea](homework:123)" para tareas
  // del modelo institucional, o "@[Título](gc-coursework:456)" para tareas
  // sincronizadas de Google Classroom — hoy en la práctica casi toda la
  // data real de tareas viene de Classroom, no del módulo institucional
  // (los docentes crean poco a mano en KOLEXA), así que el buscador de "@"
  // tiene que cubrir ambas fuentes o no encuentra casi nada. Es texto
  // plano dentro de `body`, no una tabla aparte — el título queda congelado
  // tal como se vio al escribir, pero el enlace navega por id, así que si la
  // tarea cambia después (nueva fecha, entregada) el destino sigue siendo
  // el actual. Ver auditoría de mensajería: se prefirió esto a una tabla de
  // referencias por ser mucho más simple para el mismo resultado.
  private static readonly MENTION_RE = /@\[(.*?)\]\((homework|gc-coursework):(\d+)\)/g;

  private stripMentions(body: string): string {
    return body.replace(ThreadsService.MENTION_RE, '📋 $1');
  }

  // Busca tareas mencionables para el autocompletado de "@" en el
  // compositor: combina las del modelo institucional (por aula) y las
  // sincronizadas de Google Classroom (por alumno — `gc_courses` guarda una
  // copia por cada alumno matriculado, no por aula). Solo tiene sentido en
  // hilos directos con un alumno de por medio — en un hilo con el director
  // no hay alumno del que buscar tareas.
  async searchMentions(threadId: bigint, userId: bigint, query: string) {
    const thread = await this.assertParticipant(threadId, userId);
    const q = query.trim();

    const [institutional, classroom] = await Promise.all([
      this.searchInstitutionalHomework(thread.studentId, q),
      this.searchClassroomCoursework(thread.studentId, q),
    ]);

    return [...institutional, ...classroom]
      .sort((a, b) => (a.dueDate?.getTime() ?? Infinity) - (b.dueDate?.getTime() ?? Infinity))
      .slice(0, 8);
  }

  private async searchInstitutionalHomework(studentId: bigint | null, q: string) {
    const classroomId = await this.classroomOfThread(studentId);
    if (!classroomId) return [];

    const homeworks = await this.prisma.homework.findMany({
      where: {
        classroomId,
        deletedAt: null,
        ...(q ? { title: { contains: q, mode: 'insensitive' } } : {}),
      },
      orderBy: { dueDate: 'asc' },
      take: 8,
      select: { id: true, title: true, dueDate: true, course: { select: { name: true } } },
    });

    return homeworks.map((h) => ({
      id: h.id.toString(),
      type: 'homework' as const,
      title: h.title,
      dueDate: h.dueDate,
      courseName: h.course.name,
    }));
  }

  private async searchClassroomCoursework(studentId: bigint | null, q: string) {
    if (!studentId) return [];

    const courseworks = await this.prisma.gcCoursework.findMany({
      where: {
        course: { studentId },
        state: 'PUBLISHED',
        workType: { not: 'MATERIAL' },
        ...(q ? { title: { contains: q, mode: 'insensitive' } } : {}),
      },
      orderBy: { dueDate: 'asc' },
      take: 8,
      select: { id: true, title: true, dueDate: true, course: { select: { name: true } } },
    });

    return courseworks.map((cw) => ({
      id: cw.id.toString(),
      type: 'gc-coursework' as const,
      title: cw.title,
      dueDate: cw.dueDate,
      courseName: cw.course.name,
    }));
  }

  // El mensaje solo guarda id + título (frozen) de la tarea mencionada — el
  // enlace externo de Classroom se resuelve al tocarla, validado por
  // participación en el hilo, nunca por el id de la tarea a secas.
  async getClassroomTaskLink(threadId: bigint, userId: bigint, refId: bigint) {
    const thread = await this.assertParticipant(threadId, userId);
    if (!thread.studentId) throw new NotFoundException('Tarea no encontrada');

    const coursework = await this.prisma.gcCoursework.findFirst({
      where: { id: refId, course: { studentId: thread.studentId } },
      select: { alternateLink: true },
    });
    if (!coursework) throw new NotFoundException('Tarea no encontrada');
    return { alternateLink: coursework.alternateLink };
  }

  async sendMessage(threadId: bigint, userId: bigint, body: string) {
    const thread = await this.assertParticipant(threadId, userId);
    if (thread.closedAt) {
      throw new BadRequestException('Esta conversación está cerrada');
    }

    // Si el mensaje menciona tareas, cada una debe pertenecer al aula/alumno
    // de este hilo — un cliente alterado no puede colar la referencia a una
    // tarea ajena. `assertCanMessage` ya validó que el alumno del hilo es
    // compartido; esto extiende esa misma garantía a lo que se menciona.
    // Las dos fuentes (institucional y Classroom) se validan por separado
    // porque viven en tablas y ámbitos distintos (aula vs. alumno).
    const mentions = [...body.matchAll(ThreadsService.MENTION_RE)];
    const homeworkIds = mentions.filter((m) => m[2] === 'homework').map((m) => BigInt(m[3]));
    const classroomTaskIds = mentions
      .filter((m) => m[2] === 'gc-coursework')
      .map((m) => BigInt(m[3]));

    if (homeworkIds.length > 0) {
      const classroomId = await this.classroomOfThread(thread.studentId);
      const validCount = classroomId
        ? await this.prisma.homework.count({
            where: { id: { in: homeworkIds }, classroomId, deletedAt: null },
          })
        : 0;
      if (validCount !== new Set(homeworkIds.map((id) => id.toString())).size) {
        throw new BadRequestException('Una tarea mencionada no pertenece a esta conversación');
      }
    }
    if (classroomTaskIds.length > 0) {
      const validCount = thread.studentId
        ? await this.prisma.gcCoursework.count({
            where: { id: { in: classroomTaskIds }, course: { studentId: thread.studentId } },
          })
        : 0;
      if (validCount !== new Set(classroomTaskIds.map((id) => id.toString())).size) {
        throw new BadRequestException('Una tarea mencionada no pertenece a esta conversación');
      }
    }

    const [message] = await this.prisma.$transaction([
      this.prisma.threadMessage.create({
        data: { threadId, senderId: userId, body },
        select: { id: true, sentAt: true },
      }),
      this.prisma.thread.update({
        where: { id: threadId },
        data: { lastMessageAt: new Date() },
      }),
      // Quien escribe da por leído su propio mensaje: sin esto, el hilo le
      // aparecería a él mismo como "sin leer" justo después de enviarlo.
      this.prisma.threadParticipant.update({
        where: { threadId_userId: { threadId, userId } },
        data: { lastReadAt: new Date() },
      }),
    ]);

    // Push a los demás participantes, salvo que hayan silenciado el hilo.
    // Fire-and-forget de verdad: quien envía no debe esperar a que se
    // resuelvan estas dos consultas (~150ms cada una, la base está lejos)
    // para recibir la confirmación de que su mensaje ya se guardó. Antes
    // este bloque estaba `await`eado y agregaba dos viajes de red enteros
    // a la respuesta, aunque el push en sí ya era fire-and-forget.
    this.notifyOthers(threadId, userId, body).catch(() => {});

    return { id: message.id.toString(), sentAt: message.sentAt };
  }

  private async notifyOthers(threadId: bigint, senderId: bigint, body: string) {
    const others = await this.prisma.threadParticipant.findMany({
      where: { threadId, userId: { not: senderId }, mutedAt: null },
      select: { userId: true },
    });
    if (others.length === 0) return;

    const sender = await this.prisma.user.findUnique({
      where: { id: senderId },
      select: { firstName: true, lastName: true },
    });
    const title = `${sender?.firstName ?? 'Alguien'} te escribió`;
    const cleanBody = this.stripMentions(body);
    const preview = cleanBody.length > 120 ? `${cleanBody.slice(0, 117)}…` : cleanBody;
    for (const p of others) {
      this.notifications
        .sendToUser(p.userId, title, preview, {
          screen: 'thread',
          threadId: threadId.toString(),
          // Señal para refrescar la conversación/bandeja sola si la
          // pantalla ya está abierta — mismo patrón que asistencia/fotos,
          // no trae el mensaje en sí, solo avisa "volvé a pedir".
          refresh: 'true',
        })
        .catch(() => {});
    }
  }

  async markRead(threadId: bigint, userId: bigint) {
    await this.assertParticipant(threadId, userId);
    await this.prisma.threadParticipant.update({
      where: { threadId_userId: { threadId, userId } },
      data: { lastReadAt: new Date() },
    });
    return { ok: true };
  }

  async setMuted(threadId: bigint, userId: bigint, muted: boolean) {
    await this.assertParticipant(threadId, userId);
    await this.prisma.threadParticipant.update({
      where: { threadId_userId: { threadId, userId } },
      data: { mutedAt: muted ? new Date() : null },
    });
    return { ok: true };
  }

  // ── Helpers de autorización ───────────────────────────────

  // Cualquier consulta de un hilo pasa por acá primero. No existe ningún
  // endpoint que devuelva hilos a partir de un studentId: se entra por
  // participación, nunca por alumno — así un padre nunca puede alcanzar la
  // conversación de otro padre sobre el mismo hijo.
  private async assertParticipant(threadId: bigint, userId: bigint) {
    const participant = await this.prisma.threadParticipant.findUnique({
      where: { threadId_userId: { threadId, userId } },
      select: { thread: { select: { closedAt: true, studentId: true } } },
    });
    if (!participant) {
      throw new NotFoundException('Conversación no encontrada');
    }
    return participant.thread;
  }

  // El aula del alumno del hilo: es el alcance de qué tareas se pueden
  // mencionar en la conversación. Devuelve null si el alumno no tiene
  // matrícula activa (no hay dónde buscar tareas).
  private async classroomOfThread(studentId: bigint | null): Promise<bigint | null> {
    if (!studentId) return null;
    const enrollment = await this.prisma.studentEnrollment.findFirst({
      where: { studentId, isActive: true },
      select: { classroomId: true },
    });
    return enrollment?.classroomId ?? null;
  }

  private async assertCanMessage(
    sender: { id: bigint; roles: string[] },
    recipient: { id: bigint; roles: string[] },
    studentId: bigint | null,
  ) {
    if (isAdmin(sender.roles) || isAdmin(recipient.roles)) {
      // El director puede escribir a cualquiera de su colegio, y cualquiera
      // puede escribirle al director. Ya se validó el mismo colegio en
      // openThread al buscar al destinatario con `userRoles.some({schoolId})`.
      return;
    }

    if (!studentId) {
      throw new BadRequestException(
        'Indica de qué alumno se trata esta conversación',
      );
    }

    const senderIsParent = sender.roles.includes('parent');
    const senderIsTeacher = sender.roles.includes('teacher');
    const recipientIsParent = recipient.roles.includes('parent');
    const recipientIsTeacher = recipient.roles.includes('teacher');

    let parentId: bigint;
    let teacherId: bigint;
    if (senderIsParent && recipientIsTeacher) {
      parentId = sender.id;
      teacherId = recipient.id;
    } else if (senderIsTeacher && recipientIsParent) {
      parentId = recipient.id;
      teacherId = sender.id;
    } else {
      throw new ForbiddenException('No puedes iniciar esta conversación');
    }

    // Ninguna de las dos depende del resultado de la otra — corren en
    // paralelo en vez de una tras otra.
    const [ownsStudent, teaches] = await Promise.all([
      this.prisma.userStudent.findFirst({
        where: { userId: parentId, studentId },
        select: { id: true },
      }),
      // El docente debe dictar en un aula donde el alumno esté matriculado.
      this.prisma.classroomCourse.findFirst({
        where: {
          teacherId,
          classroom: {
            enrollments: { some: { studentId, isActive: true } },
          },
        },
        select: { id: true },
      }),
    ]);
    if (!ownsStudent) {
      throw new ForbiddenException('No tienes acceso a este alumno');
    }
    if (!teaches) {
      throw new ForbiddenException('Ese docente no enseña a este alumno');
    }
  }
}
