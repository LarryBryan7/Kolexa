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
import { SupabaseStorageService } from '../storage/supabase-storage.service';

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
  otherParticipant: {
    id: string;
    name: string;
    avatar: string | null;
    online: boolean;
    // 'teacher' | 'parent' | 'school_admin' — mismo valor que Contact.role,
    // para que ThreadPage pueda mostrar "Docente"/"Apoderado"/"Dirección
    // del colegio" arriba del nombre en el header.
    role: string;
  } | null;
  lastMessage: { body: string; senderId: string; sentAt: Date; delivered: boolean } | null;
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
  // Punto verde/gris — mismo criterio que ThreadSummary.otherParticipant
  // (ver isOnline más abajo).
  online: boolean;
  // Alumno(s) que hacen válida esta conversación. Vacío para hilos con el
  // director, donde no hace falta indicar uno.
  students: { id: string; name: string; avatar: string | null }[];
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

// Mismo criterio que toAdminContacts/getContacts: un usuario puede tener
// varios roles en el colegio (ej. admin y docente a la vez), pero acá solo
// hace falta UNO para mostrar en el header de ThreadPage — se prioriza
// admin/director (habla "como" dirección del colegio) sobre docente sobre
// padre.
const primaryRole = (roles: string[]): string => {
  if (isAdmin(roles)) return 'school_admin';
  if (roles.includes('teacher')) return 'teacher';
  return 'parent';
};

@Injectable()
export class ThreadsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly storage: SupabaseStorageService,
  ) {}

  // students[].avatar sale de student.avatar_url, que es un PATH del bucket
  // privado 'avatars' (no una URL servible) — hay que firmarlo, igual que ya
  // hace getParentHome/login con el avatar del propio hijo. El avatar de
  // adultos (Contact.avatar) NO pasa por acá: viene de Google (payload.picture),
  // ya es una URL completa y servible tal cual.
  private async _signStudentAvatars(paths: (string | null)[]): Promise<Map<string, string>> {
    const unique = [...new Set(paths.filter((p): p is string => p != null))];
    if (unique.length === 0) return new Map();
    const signed = await this.storage.getSignedUrls(unique, 3600, 'avatars');
    return new Map(unique.map((p, i) => [p, signed[i]]));
  }

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
                lastReadAt: true,
                user: {
                  select: {
                    id: true,
                    firstName: true,
                    lastName: true,
                    avatar: true,
                    lastActiveAt: true,
                    userRoles: { where: { schoolId }, select: { role: { select: { name: true } } } },
                  },
                },
              },
            },
          },
        },
      },
      orderBy: { thread: { lastMessageAt: 'desc' } },
    });

    if (parts.length === 0) return [];

    // Un solo query para TODOS los mensajes de estos hilos, en vez de un
    // N+1 por hilo: se agrupa en memoria (la bandeja de un usuario nunca
    // tiene miles de hilos). Sirve para dos cosas a la vez — el último
    // mensaje de cada hilo, Y el badge numérico de no-leídos (mensajes de
    // la OTRA persona posteriores a `lastReadAt`, que varía por hilo y no
    // se puede expresar en un WHERE de groupBy) — antes eran dos queries
    // separadas y secuenciales pidiendo prácticamente lo mismo; contra un
    // pooler cross-región (Railway US East ↔ Supabase São Paulo) cada
    // round-trip de más se siente (~350-400ms).
    const threadIds = parts.map((p) => p.thread.id);
    const allMessages = await this.prisma.threadMessage.findMany({
      where: { threadId: { in: threadIds }, deletedAt: null },
      orderBy: { sentAt: 'desc' },
      select: { threadId: true, body: true, senderId: true, sentAt: true },
    });
    const lastByThread = new Map<string, (typeof allMessages)[number]>();
    const sentAtsByThread = new Map<string, Date[]>();
    for (const m of allMessages) {
      const key = m.threadId.toString();
      if (!lastByThread.has(key)) lastByThread.set(key, m);
      if (m.senderId !== userId) {
        const arr = sentAtsByThread.get(key);
        if (arr) arr.push(m.sentAt);
        else sentAtsByThread.set(key, [m.sentAt]);
      }
    }

    return parts
      .map((p) => {
        const t = p.thread;
        const otherPart = t.participants[0] ?? null;
        const other = otherPart?.user ?? null;
        const last = lastByThread.get(t.id.toString()) ?? null;
        // Doble check del último mensaje (solo tiene sentido si lo mandé
        // yo): la otra persona lo leyó, o estuvo activa/online después de
        // que se envió — mismas dos señales que getMessages, ver ahí.
        const delivered =
          !!last &&
          ((!!otherPart?.lastReadAt && otherPart.lastReadAt >= last.sentAt) ||
            (!!other?.lastActiveAt && other.lastActiveAt >= last.sentAt));
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
                role: primaryRole(other.userRoles.map((r) => r.role.name)),
              }
            : null,
          lastMessage: last
            ? {
                body: this.stripMentions(last.body),
                senderId: last.senderId.toString(),
                sentAt: last.sentAt,
                delivered,
              }
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
      select: { id: true, firstName: true, lastName: true, avatar: true, lastActiveAt: true },
    });
    const toAdminContacts = (admins: Awaited<typeof adminsPromise>): Contact[] =>
      admins.map((a) => ({
        userId: a.id.toString(),
        name: `${a.firstName} ${a.lastName ?? ''}`.trim(),
        avatar: a.avatar,
        online: isOnline(a.lastActiveAt),
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
          select: { id: true, firstName: true, lastName: true, avatar: true, lastActiveAt: true },
        }),
      ]);
      const adminContacts = toAdminContacts(admins);
      const staffContacts: Contact[] = staff.map((t) => ({
        userId: t.id.toString(),
        name: `${t.firstName} ${t.lastName ?? ''}`.trim(),
        avatar: t.avatar,
        online: isOnline(t.lastActiveAt),
        role: 'teacher',
        students: [],
      }));
      return [...staffContacts, ...adminContacts];
    }

    if (user.roles.includes('parent')) {
      // Antes: 2 round trips secuenciales encadenados (mis hijos → aulas
      // de esos hijos con docente) — medido en producción junto con la
      // rama docente de abajo: 0.88-2s. Se fusiona en una sola consulta
      // con JOINs; corre en paralelo con `adminsPromise`.
      const [admins, rows] = await Promise.all([
        adminsPromise,
        this.prisma.$queryRaw<
          {
            teacher_id: bigint;
            teacher_first_name: string;
            teacher_last_name: string | null;
            teacher_avatar: string | null;
            teacher_last_active: Date | null;
            student_id: bigint;
            student_first_name: string;
            student_last_name: string | null;
            student_avatar: string | null;
          }[]
        >`
          SELECT DISTINCT
            cc.teacher_id AS teacher_id,
            tu.first_name AS teacher_first_name,
            tu.last_name AS teacher_last_name,
            tu.avatar_url AS teacher_avatar,
            tu.last_active_at AS teacher_last_active,
            s.id AS student_id,
            s.first_name AS student_first_name,
            s.last_name AS student_last_name,
            s.avatar_url AS student_avatar
          FROM user_students us
          JOIN students s ON s.id = us.student_id
          JOIN student_enrollments se ON se.student_id = us.student_id AND se.is_active = true
          JOIN classroom_courses cc ON cc.classroom_id = se.classroom_id AND cc.teacher_id IS NOT NULL
          JOIN users tu ON tu.id = cc.teacher_id
          WHERE us.user_id = ${user.id}
        `,
      ]);
      const adminContacts = toAdminContacts(admins);
      const signedStudentAvatars = await this._signStudentAvatars(rows.map((r) => r.student_avatar));

      const byTeacher = new Map<
        string,
        {
          name: string;
          avatar: string | null;
          online: boolean;
          students: Map<string, { name: string; avatar: string | null }>;
        }
      >();
      for (const row of rows) {
        const key = row.teacher_id.toString();
        if (!byTeacher.has(key)) {
          byTeacher.set(key, {
            name: `${row.teacher_first_name} ${row.teacher_last_name ?? ''}`.trim(),
            avatar: row.teacher_avatar,
            online: isOnline(row.teacher_last_active),
            students: new Map(),
          });
        }
        byTeacher.get(key)!.students.set(row.student_id.toString(), {
          name: `${row.student_first_name} ${row.student_last_name ?? ''}`.trim(),
          avatar: row.student_avatar ? signedStudentAvatars.get(row.student_avatar) ?? null : null,
        });
      }

      const teacherContacts: Contact[] = [...byTeacher.entries()].map(([id, v]) => ({
        userId: id,
        name: v.name,
        avatar: v.avatar,
        online: v.online,
        role: 'teacher',
        students: [...v.students.entries()].map(([sid, s]) => ({
          id: sid,
          name: s.name,
          avatar: s.avatar,
        })),
      }));
      return [...teacherContacts, ...adminContacts];
    }

    if (user.roles.includes('teacher')) {
      // Mismo fix que la rama de arriba: 3 round trips secuenciales (mis
      // aulas → alumnos matriculados → padres de esos alumnos) fusionados
      // en 1 sola consulta con JOINs.
      const [admins, rows] = await Promise.all([
        adminsPromise,
        this.prisma.$queryRaw<
          {
            parent_id: bigint;
            parent_first_name: string;
            parent_last_name: string | null;
            parent_avatar: string | null;
            parent_last_active: Date | null;
            student_id: bigint;
            student_first_name: string;
            student_last_name: string | null;
            student_avatar: string | null;
          }[]
        >`
          SELECT DISTINCT
            us.user_id AS parent_id,
            u.first_name AS parent_first_name,
            u.last_name AS parent_last_name,
            u.avatar_url AS parent_avatar,
            u.last_active_at AS parent_last_active,
            s.id AS student_id,
            s.first_name AS student_first_name,
            s.last_name AS student_last_name,
            s.avatar_url AS student_avatar
          FROM classroom_courses cc
          JOIN student_enrollments se ON se.classroom_id = cc.classroom_id AND se.is_active = true
          JOIN students s ON s.id = se.student_id
          JOIN user_students us ON us.student_id = se.student_id
          JOIN users u ON u.id = us.user_id
          WHERE cc.teacher_id = ${user.id}
        `,
      ]);
      const adminContacts = toAdminContacts(admins);
      const signedStudentAvatars = await this._signStudentAvatars(rows.map((r) => r.student_avatar));

      const byParent = new Map<
        string,
        {
          name: string;
          avatar: string | null;
          online: boolean;
          students: Map<string, { name: string; avatar: string | null }>;
        }
      >();
      for (const row of rows) {
        const key = row.parent_id.toString();
        if (!byParent.has(key)) {
          byParent.set(key, {
            name: `${row.parent_first_name} ${row.parent_last_name ?? ''}`.trim(),
            avatar: row.parent_avatar,
            online: isOnline(row.parent_last_active),
            students: new Map(),
          });
        }
        byParent.get(key)!.students.set(row.student_id.toString(), {
          name: `${row.student_first_name} ${row.student_last_name ?? ''}`.trim(),
          avatar: row.student_avatar ? signedStudentAvatars.get(row.student_avatar) ?? null : null,
        });
      }

      const parentContacts: Contact[] = [...byParent.entries()].map(([id, v]) => ({
        userId: id,
        name: v.name,
        avatar: v.avatar,
        online: v.online,
        role: 'parent',
        students: [...v.students.entries()].map(([sid, s]) => ({
          id: sid,
          name: s.name,
          avatar: s.avatar,
        })),
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
  ): Promise<{
    messages: ThreadMessageView[];
    otherLastReadAt: Date | null;
    otherLastActiveAt: Date | null;
  }> {
    // El doble check se arma en el cliente comparando el `sentAt` de cada
    // mensaje propio contra DOS señales de la otra persona — no hay tabla
    // de "leído/entregado por mensaje":
    //   - lastReadAt: abrió ESTE hilo después de que se envió (leído de
    //     verdad).
    //   - lastActiveAt: hizo cualquier request autenticado después de que
    //     se envió (su app está online/con conexión — "le llegó" aunque no
    //     haya abierto este hilo puntual). Mismo dato que usa el punto
    //     verde/gris de presencia (ver JwtStrategy).
    // Cualquiera de las dos alcanza para el doble check.
    //
    // `assertParticipant` va DENTRO de este mismo Promise.all (no antes):
    // es solo un chequeo de autorización, su resultado no se usa para nada
    // más, y ninguna de las otras dos consultas depende de él (ambas solo
    // necesitan `threadId`). Antes era una etapa secuencial de más — contra
    // el pooler cross-región (Railway ↔ Supabase São Paulo) eso son
    // ~350-400ms pagados en cada apertura de conversación. Si no soy
    // participante, `assertParticipant` rechaza y el `Promise.all` entero
    // rechaza con ese mismo NotFoundException, aunque las otras dos ya se
    // hayan disparado en paralelo — no importa, nunca se llega a construir
    // la respuesta con esos datos.
    const [, rows, otherParticipant] = await Promise.all([
      this.assertParticipant(threadId, userId),
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
        select: { lastReadAt: true, user: { select: { lastActiveAt: true } } },
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

    return {
      messages,
      otherLastReadAt: otherParticipant?.lastReadAt ?? null,
      otherLastActiveAt: otherParticipant?.user?.lastActiveAt ?? null,
    };
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

    // Antes: this.prisma.$transaction([create, update, update]). Prisma manda
    // cada paso de un $transaction en array como un round-trip DE RED
    // separado (BEGIN, INSERT, UPDATE, UPDATE, COMMIT ≈ 5 viajes) — contra
    // el pooler cross-región (Railway ↔ Supabase São Paulo, ~150-200ms cada
    // uno) eso solo ya sumaba 1-2s, medido en vivo (markRead, que es 1 sola
    // escritura, tarda ~0.3s; sendMessage con 3 tardaba 1.1-3.6s). Una sola
    // sentencia SQL con CTEs hace el INSERT + los 2 UPDATE en un solo viaje.
    const [result] = await this.prisma.$queryRaw<{ id: string; sent_at: Date }[]>`
      WITH new_message AS (
        INSERT INTO thread_messages (thread_id, sender_id, body, sent_at)
        VALUES (${threadId}, ${userId}, ${body}, now())
        RETURNING id, sent_at
      ),
      thread_update AS (
        UPDATE threads SET last_message_at = now() WHERE id = ${threadId}
      )
      -- Quien escribe da por leído su propio mensaje: sin esto, el hilo le
      -- aparecería a él mismo como "sin leer" justo después de enviarlo.
      UPDATE thread_participants
      SET last_read_at = now()
      WHERE thread_id = ${threadId} AND user_id = ${userId}
      RETURNING
        (SELECT id::text FROM new_message) AS id,
        (SELECT sent_at FROM new_message) AS sent_at
    `;
    const message = { id: result.id, sentAt: result.sent_at };

    // Push a los demás participantes, salvo que hayan silenciado el hilo.
    // Fire-and-forget de verdad: quien envía no debe esperar a que se
    // resuelvan estas dos consultas (~150ms cada una, la base está lejos)
    // para recibir la confirmación de que su mensaje ya se guardó. Antes
    // este bloque estaba `await`eado y agregaba dos viajes de red enteros
    // a la respuesta, aunque el push en sí ya era fire-and-forget.
    this.notifyOthers(threadId, userId, body).catch(() => {});

    return { id: message.id, sentAt: message.sentAt };
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
    // Avisa al OTRO participante (push silencioso, sin banner) para que si
    // tiene este chat abierto, el segundo check pase de "enviado" a
    // "leído" solo, sin esperar a que otra cosa dispare un refresh. Fire-
    // and-forget: quien marca como leído no debe esperar a que esto se
    // resuelva.
    this.notifyReadReceipt(threadId, userId).catch(() => {});
    return { ok: true };
  }

  private async notifyReadReceipt(threadId: bigint, readerId: bigint) {
    const others = await this.prisma.threadParticipant.findMany({
      where: { threadId, userId: { not: readerId } },
      select: { userId: true },
    });
    await Promise.all(
      others.map((p) =>
        this.notifications.sendSilentRefresh(p.userId, {
          screen: 'thread',
          threadId: threadId.toString(),
          refresh: 'true',
        }),
      ),
    );
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
