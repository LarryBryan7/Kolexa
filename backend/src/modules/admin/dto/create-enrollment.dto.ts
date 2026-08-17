import { IsInt, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

// POST /admin/enrollments — matricula a un alumno en un aula para un año académico.
// Se valida que tanto el alumno como el aula pertenezcan al colegio del admin.
export class CreateEnrollmentDto {
  @IsInt()
  @Type(() => Number)
  studentId: number;

  @IsInt()
  @Type(() => Number)
  classroomId: number;

  @IsInt()
  @Type(() => Number)
  @Min(2000)
  @Max(2100)
  academicYear: number;
}
