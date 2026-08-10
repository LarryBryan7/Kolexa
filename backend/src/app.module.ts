// ============================================================
// app.module.ts — Módulo raíz de la aplicación
// ============================================================
// Todos los módulos de Kolexa están registrados aquí.
// NestJS los instancia en orden y los conecta automáticamente.
//
// Módulos por fase:
//   Base:   Auth, Prisma, Config
//   Fase 2: Attendance, Homework, Announcements, Messages, Chat
//   Fase 3: Grades, Appointments, Pickup, Payments
//   Fase 4: Anecdotes, Suggestions, Coupons
// ============================================================

import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

// ── Infraestructura ───────────────────────────────────────
import { PrismaModule } from './prisma/prisma.module';

// ── Auth ──────────────────────────────────────────────────
import { AuthModule } from './modules/auth/auth.module';

// ── Fase 2 ────────────────────────────────────────────────
import { AttendanceModule } from './modules/attendance/attendance.module';
import { HomeworkModule } from './modules/homework/homework.module';
import { AnnouncementsModule } from './modules/announcements/announcements.module';
import { MessagesModule } from './modules/messages/messages.module';
import { ChatModule } from './modules/chat/chat.module';

// ── Fase 3 ────────────────────────────────────────────────
import { GradesModule } from './modules/grades/grades.module';
import { AppointmentsModule } from './modules/appointments/appointments.module';
import { PickupModule } from './modules/pickup/pickup.module';
import { PaymentsModule } from './modules/payments/payments.module';

// ── Fase 4 ────────────────────────────────────────────────
import { AnecdotesModule } from './modules/anecdotes/anecdotes.module';
import { SuggestionsModule } from './modules/suggestions/suggestions.module';
import { CouponsModule } from './modules/coupons/coupons.module';

// ── Integraciones externas ────────────────────────────────
import { ClassroomModule } from './modules/classroom/classroom.module';
import { TeachersModule } from './modules/teachers/teachers.module';

// ── Onboarding ────────────────────────────────────────────
import { InvitationsModule } from './modules/invitations/invitations.module';

// ── Notificaciones push ───────────────────────────────────
import { NotificationsModule } from './modules/notifications/notifications.module';

@Module({
  imports: [
    // Variables de entorno disponibles en toda la app
    ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),

    // Conexión global a PostgreSQL via Prisma
    PrismaModule,

    // ── Auth ──────────────────────────────────────────────
    AuthModule,            // JWT + login + refresh + change-password

    // ── Fase 2: Comunicación diaria ───────────────────────
    AttendanceModule,      // Asistencia (P/A/T/J por alumno)
    HomeworkModule,        // Tareas y seguimiento de entregas
    AnnouncementsModule,   // Comunicados del colegio/aula (broadcast)
    MessagesModule,        // Mensajes directos padre ↔ profesor
    ChatModule,            // Chat en tiempo real (Supabase Realtime)

    // ── Fase 3: Gestión académica y seguridad ─────────────
    GradesModule,          // Notas por periodo (boleta)
    AppointmentsModule,    // Citas padre-profesor con slots
    PickupModule,          // Recojo autorizado y control de salida
    PaymentsModule,        // Pagos escolares (matrícula, pensiones)

    // ── Fase 4: Funciones complementarias ─────────────────
    AnecdotesModule,       // Observaciones del profesor sobre el alumno
    SuggestionsModule,     // Buzón de sugerencias con respuesta admin
    CouponsModule,         // Cuponera de descuentos con socios

    // ── Integraciones externas ─────────────────────────────
    ClassroomModule,       // Google Classroom — cursos, tareas, anuncios
    TeachersModule,        // Home del docente — salones, horario

    // ── Onboarding ────────────────────────────────────────
    InvitationsModule,     // Invitaciones por token para docentes y padres

    // ── Push notifications (global) ───────────────────────────
    NotificationsModule,   // Firebase Admin SDK — envío a padres
  ],
})
export class AppModule {}
