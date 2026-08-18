import { IsInt, IsOptional, IsString, MaxLength } from 'class-validator';
import { Type } from 'class-transformer';

// POST /admin/parent-student-links — vincula un Parent institucional a un alumno.
// Soporta: un padre con varios hijos y un alumno con varios padres.
export class CreateParentStudentLinkDto {
  @IsInt()
  @Type(() => Number)
  parentId: number;

  @IsInt()
  @Type(() => Number)
  studentId: number;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  relationship?: string;

  @IsOptional()
  isPrimary?: boolean;
}
