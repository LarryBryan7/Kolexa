// ============================================================
// create-attendance.dto.ts — DTO para crear una sesión de asistencia
// ============================================================
// DTO = Data Transfer Object: define la forma del JSON que el cliente
// debe enviar en el body de la petición POST /attendance.
//
// NestJS valida automáticamente cada campo gracias a:
//   - class-validator: los decoradores @IsString, @IsDateString, etc.
//   - ValidationPipe global en main.ts (whitelist: true)
//
// 'whitelist: true' significa que cualquier campo extra que el cliente
// envíe (que no esté definido aquí) es ELIMINADO antes de llegar
// al servicio. Esto previene ataques de mass-assignment.
//
// Flujo al recibir una petición:
//   JSON del cliente → ValidationPipe valida con class-validator
//     ├── Válido → pasa al controlador como instancia de este DTO
//     └── Inválido → 400 Bad Request con detalle de cada error
// ============================================================

import {
  IsInt,
  IsPositive,
  IsDateString,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

// ── CreateAttendanceDto ───────────────────────────────────
// Body para POST /attendance
// El profesor crea una sesión de asistencia para un aula en una fecha.
export class CreateAttendanceDto {
  // ID del aula (classroom) — debe existir en la tabla classrooms
  @IsInt({ message: 'classroomId debe ser un número entero' })
  @IsPositive({ message: 'classroomId debe ser mayor que 0' })
  classroomId: number;

  // ID del curso/materia (course) — opcional
  // Una sesión puede ser general (recreo, formación) o de una materia específica
  @IsOptional()
  @IsInt()
  @IsPositive()
  courseId?: number;

  // Fecha de la sesión en formato ISO 8601: "2024-03-15"
  // @IsDateString acepta: "2024-03-15", "2024-03-15T08:00:00Z", etc.
  @IsDateString({}, { message: 'date debe ser una fecha válida (ej: 2024-03-15)' })
  date: string;

  // Notas opcionales del profesor sobre la sesión
  // (ej: "Salida de campo - no hay clases regulares")
  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}

// ── UpdateAttendanceRecordDto ─────────────────────────────
// Representa el estado de asistencia de UN alumno dentro de una sesión.
// Se usa dentro de UpdateAttendanceRecordsDto (ver abajo).
export class UpdateAttendanceRecordDto {
  // ID del alumno (student)
  @IsInt()
  @IsPositive()
  studentId: number;

  // Estado de asistencia:
  //   'present'  → asistió
  //   'absent'   → faltó sin justificación
  //   'late'     → llegó tarde
  //   'excused'  → falta justificada (con permiso)
  @IsString()
  status: 'present' | 'absent' | 'late' | 'excused';

  // Minutos de retraso (solo cuando status = 'late')
  @IsOptional()
  @IsInt()
  @IsPositive()
  lateMinutes?: number;

  // Justificación del profesor
  @IsOptional()
  @IsString()
  @MaxLength(255)
  justification?: string;
}
