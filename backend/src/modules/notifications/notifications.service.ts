import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class NotificationsService implements OnModuleInit {
  private readonly logger = new Logger(NotificationsService.name);
  private enabled = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  onModuleInit() {
    if (admin.apps.length > 0) {
      this.enabled = true;
      return;
    }

    const projectId   = this.config.get<string>('FIREBASE_PROJECT_ID');
    const clientEmail = this.config.get<string>('FIREBASE_CLIENT_EMAIL');
    const privateKey  = this.config.get<string>('FIREBASE_PRIVATE_KEY');

    if (!projectId || !clientEmail || !privateKey) {
      this.logger.warn('Firebase no configurado — push notifications desactivadas. Agrega FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL y FIREBASE_PRIVATE_KEY al .env');
      return;
    }

    try {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          // Las private keys en .env tienen \n escapados — los convertimos a saltos reales
          privateKey: privateKey.replace(/\\n/g, '\n'),
        }),
      });
      this.enabled = true;
      this.logger.log('Firebase Admin SDK inicializado correctamente');
    } catch (err) {
      this.logger.error('Error al inicializar Firebase Admin SDK:', err);
    }
  }

  // ── sendToUser ─────────────────────────────────────────────
  // Envía una notificación push a todos los dispositivos de un usuario.
  async sendToUser(
    userId: bigint,
    title: string,
    body: string,
    data?: Record<string, string>,
  ) {
    if (!this.enabled) return;

    const tokens = await this.prisma.pushToken.findMany({
      where: { userId },
      select: { token: true },
    });

    if (tokens.length === 0) return;
    await this._sendBatch(tokens.map((t) => t.token), title, body, data);
  }

  // ── sendAttendanceToParent ─────────────────────────────────
  // Notificación personalizada por alumno: "Miguel está presente ✅"
  // Usa el vínculo GcCourseStudent.studentId → UserStudent → parent push tokens.
  // Si el alumno no está vinculado (studentId = null), omite silenciosamente.
  async sendAttendanceToParent(
    gcCourseStudentId: bigint,
    studentName: string,
    status: string,
  ) {
    if (!this.enabled) return;

    const gcStudent = await this.prisma.gcCourseStudent.findUnique({
      where: { id: gcCourseStudentId },
      select: { studentId: true },
    });
    if (!gcStudent?.studentId) return;

    const links = await this.prisma.userStudent.findMany({
      where: { studentId: gcStudent.studentId },
      select: { userId: true },
    });
    if (links.length === 0) return;

    const parentUserIds = links.map((l) => l.userId);
    const tokens = await this.prisma.pushToken.findMany({
      where: { userId: { in: parentUserIds } },
      select: { token: true },
    });
    if (tokens.length === 0) return;

    const firstName = studentName.split(' ')[0];
    const statusLabel =
      status === 'present' ? `${firstName} llegó al colegio ✅` :
      status === 'late'    ? `${firstName} llegó tarde ⏰` :
      status === 'absent'  ? `${firstName} está ausente hoy ❌` :
      `Asistencia de ${firstName} actualizada`;

    await this._sendBatch(
      tokens.map((t) => t.token),
      '📋 Asistencia registrada',
      statusLabel,
      {
        screen: 'novedades',
        studentName,
        // Agrupamiento estilo WhatsApp: todas las notificaciones de
        // asistencia se apilan en una sola entrada expandible.
        groupKey: 'kolexa_attendance',
        groupSummary: 'Novedades de asistencia',
        // Flag para que la app refresque el home en tiempo real.
        refresh: 'true',
      },
      { collapseKey: `attendance_${gcStudent.studentId}`, ttlSeconds: 14400 },
    );
  }

  // ── sendToSchoolParents ────────────────────────────────────
  // Envía una notificación a todos los padres de un colegio,
  // identificado por el userId del docente que dispara el evento.
  async sendToSchoolParents(
    teacherUserId: bigint,
    title: string,
    body: string,
    data?: Record<string, string>,
  ) {
    if (!this.enabled) return;

    // 1. Obtener el schoolId del docente
    const role = await this.prisma.userRole.findFirst({
      where: { userId: teacherUserId },
      select: { schoolId: true },
    });
    if (!role?.schoolId) {
      this.logger.warn(`Docente ${teacherUserId} no tiene escuela asignada — notificación omitida`);
      return;
    }

    // 2. Todos los students activos de esa escuela
    const students = await this.prisma.student.findMany({
      where: { schoolId: role.schoolId, isActive: true, deletedAt: null },
      select: { id: true },
    });
    if (students.length === 0) return;

    const studentIds = students.map((s) => s.id);

    // 3. Padres vinculados a esos students
    const links = await this.prisma.userStudent.findMany({
      where: { studentId: { in: studentIds } },
      select: { userId: true },
    });
    if (links.length === 0) return;

    const parentUserIds = [...new Set(links.map((l) => l.userId))];

    // 4. Push tokens de esos padres
    const tokens = await this.prisma.pushToken.findMany({
      where: { userId: { in: parentUserIds } },
      select: { token: true },
    });
    if (tokens.length === 0) return;

    // Agrupamiento estilo WhatsApp para las notificaciones de fotos:
    // todas las fotos del salón se apilan en una sola entrada expandible.
    const groupData = {
      ...(data ?? {}),
      groupKey: `kolexa_photos_${role.schoolId}`,
      groupSummary: 'Novedades de fotos del salón',
      // Flag para que la app refresque el home en tiempo real.
      refresh: 'true',
    };

    await this._sendBatch(tokens.map((t) => t.token), title, body, groupData, {
      collapseKey: `school_${role.schoolId}_photos`,
      ttlSeconds: 28800,
    });
    this.logger.log(`Notificación enviada a ${tokens.length} dispositivos en escuela ${role.schoolId}`);
  }

  // ── _sendBatch ─────────────────────────────────────────────
  // Envía en lotes de 500 (límite de FCM sendEachForMulticast).
  // Limpia tokens inválidos automáticamente.
  // Reintenta envíos fallidos con backoff exponencial (nivel WhatsApp).
  private async _sendBatch(
    tokens: string[],
    title: string,
    body: string,
    data?: Record<string, string>,
    options?: { collapseKey?: string; ttlSeconds?: number },
  ) {
    const CHUNK = 500;
    const MAX_RETRIES = 3; // reintentos con backoff exponencial
    const ttlMs = (options?.ttlSeconds ?? 14400) * 1000; // 4h default
    const expiresAt = Math.floor(Date.now() / 1000) + (options?.ttlSeconds ?? 14400);
    const invalidTokens: string[] = [];

    for (let i = 0; i < tokens.length; i += CHUNK) {
      const chunk = tokens.slice(i, i + CHUNK);

      // Reintentos con backoff exponencial: 1s, 2s, 4s
      let attempt = 0;
      let response: admin.messaging.BatchResponse | null = null;
      while (attempt < MAX_RETRIES) {
        try {
          response = await admin.messaging().sendEachForMulticast({
            tokens: chunk,
            notification: { title, body },
            data: data ?? {},
            android: {
              priority: 'high',
              ttl: ttlMs,
              collapseKey: options?.collapseKey,
              notification: {
                channelId: 'kolexa_default',
                priority: 'high',
                sound: 'default',
                defaultVibrateTimings: true,
                defaultLightSettings: true,
                notificationCount: 1,
              },
            },
            apns: {
              headers: {
                'apns-priority': '10',
                'apns-push-type': 'alert',
                ...(options?.collapseKey ? { 'apns-collapse-id': options.collapseKey } : {}),
                'apns-expiration': String(expiresAt),
              },
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                  'interruption-level': 'time-sensitive', // atraviesa el Focus Mode de iOS 15+
                },
              },
            },
          });
          break; // éxito — salir del bucle de reintentos
        } catch (err) {
          attempt++;
          if (attempt >= MAX_RETRIES) {
            this.logger.error(
              `Error enviando lote FCM tras ${MAX_RETRIES} intentos:`,
              err,
            );
            break;
          }
          // Backoff exponencial: 1s, 2s, 4s
          const delayMs = 1000 * Math.pow(2, attempt - 1);
          this.logger.warn(
            `FCM falló (intento ${attempt}/${MAX_RETRIES}), reintentando en ${delayMs}ms`,
          );
          await this._sleep(delayMs);
        }
      }

      // Recopilar tokens que fallaron por registro inválido
      if (response) {
        response.responses.forEach((r, idx) => {
          if (!r.success && this._isInvalidTokenError(r.error?.code)) {
            invalidTokens.push(chunk[idx]);
          }
        });
      }
    }

    // Limpiar tokens inválidos de la BD para no acumular basura
    if (invalidTokens.length > 0) {
      await this.prisma.pushToken.deleteMany({
        where: { token: { in: invalidTokens } },
      });
      this.logger.log(`${invalidTokens.length} tokens inválidos eliminados`);
    }
  }

  private _sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  private _isInvalidTokenError(code?: string): boolean {
    return [
      'messaging/invalid-registration-token',
      'messaging/registration-token-not-registered',
    ].includes(code ?? '');
  }
}
