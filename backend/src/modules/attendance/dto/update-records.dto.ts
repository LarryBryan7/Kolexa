// ============================================================
// update-records.dto.ts — DTO para actualizar registros de asistencia
// ============================================================
// El profesor puede marcar la asistencia de TODOS los alumnos
// de un aula en una sola petición (batch update).
//
// Body esperado en PUT /attendance/:id/records:
// {
//   "records": [
//     { "studentId": 1, "status": "present" },
//     { "studentId": 2, "status": "absent" },
//     { "studentId": 3, "status": "late", "lateMinutes": 10 },
//     { "studentId": 4, "status": "excused", "justification": "Cita médica" }
//   ]
// }
// ============================================================

import { Type } from 'class-transformer';
import { IsArray, ValidateNested, ArrayMinSize } from 'class-validator';
import { UpdateAttendanceRecordDto } from './create-attendance.dto';

export class UpdateAttendanceRecordsDto {
  // Array de registros de asistencia (uno por alumno).
  // @IsArray valida que sea un array.
  // @ValidateNested({ each: true }) valida CADA elemento del array
  //   usando las reglas del DTO interno (UpdateAttendanceRecordDto).
  // @Type(() => UpdateAttendanceRecordDto) es necesario para que
  //   class-transformer instancie los objetos correctamente.
  @IsArray({ message: 'records debe ser un array' })
  @ArrayMinSize(1, { message: 'Debe incluir al menos un registro' })
  @ValidateNested({ each: true })
  @Type(() => UpdateAttendanceRecordDto)
  records: UpdateAttendanceRecordDto[];
}
