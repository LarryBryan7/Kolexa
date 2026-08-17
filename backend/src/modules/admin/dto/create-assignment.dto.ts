import { IsInt, IsOptional } from 'class-validator';
import { Type } from 'class-transformer';

// POST /admin/assignments — asigna un curso a un aula (y opcionalmente a un docente).
// Se valida que el aula y el curso pertenezcan al colegio del admin.
export class CreateAssignmentDto {
  @IsInt()
  @Type(() => Number)
  classroomId: number;

  @IsInt()
  @Type(() => Number)
  courseId: number;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  teacherId?: number;
}
