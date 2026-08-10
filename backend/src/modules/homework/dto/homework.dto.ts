// ============================================================
// homework.dto.ts — DTOs del módulo de Tareas
// ============================================================
// Tres DTOs para las tres operaciones principales:
//   CreateHomeworkDto     → profesor crea una tarea
//   UpdateHomeworkDto     → profesor edita una tarea existente
//   SubmitHomeworkDto     → alumno entrega su tarea
// ============================================================

import {
  IsString,
  IsInt,
  IsPositive,
  IsDateString,
  IsOptional,
  IsBoolean,
  MaxLength,
  MinLength,
  IsEnum,
} from 'class-validator';

// ── CreateHomeworkDto ────────────────────────────────────
// Body para POST /homework
export class CreateHomeworkDto {
  // Aula a la que va dirigida la tarea
  @IsInt()
  @IsPositive()
  classroomId: number;

  // Curso/materia (Matemática, Comunicación, etc.)
  @IsInt()
  @IsPositive()
  courseId: number;

  // Título de la tarea (ej: "Ejercicios pág. 45-48")
  @IsString()
  @MinLength(3)
  @MaxLength(200)
  title: string;

  // Descripción completa de lo que se pide
  @IsString()
  @MaxLength(2000)
  description: string;

  // Fecha límite de entrega: "2024-03-20"
  @IsDateString()
  dueDate: string;

  // ¿Los padres pueden ver la tarea?
  // true → comunicado público a los padres
  // false → solo el alumno la ve en su sección
  @IsOptional()
  @IsBoolean()
  notifyParents?: boolean = true;
}

// ── UpdateHomeworkDto ────────────────────────────────────
// Body para PATCH /homework/:id
// Todos los campos son opcionales (solo se actualiza lo que se envía).
// IsOptional + el mismo validador del campo original.
export class UpdateHomeworkDto {
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(200)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsOptional()
  @IsDateString()
  dueDate?: string;

  @IsOptional()
  @IsBoolean()
  notifyParents?: boolean;
}

// ── SubmitStatusEnum ─────────────────────────────────────
// Estados posibles de la entrega de un alumno.
// El profesor puede marcarla como revisada o con observaciones.
export enum SubmitStatus {
  PENDING = 'pending',      // sin entregar todavía
  SUBMITTED = 'submitted',  // entregado, pendiente de revisión
  REVIEWED = 'reviewed',    // el profesor la revisó
  LATE = 'late',            // entregado pero tarde
}

// ── UpdateStudentHomeworkDto ─────────────────────────────
// Body para PATCH /homework/:id/students/:studentId
// El profesor actualiza el estado de la entrega de UN alumno.
export class UpdateStudentHomeworkDto {
  @IsEnum(SubmitStatus)
  status: SubmitStatus;

  // Nota del profesor sobre esa entrega específica
  @IsOptional()
  @IsString()
  @MaxLength(500)
  teacherNote?: string;

  // Calificación opcional (0-20 en el sistema peruano)
  @IsOptional()
  @IsInt()
  @IsPositive()
  grade?: number;
}
