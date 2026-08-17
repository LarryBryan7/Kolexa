import { IsInt, IsOptional, IsString, MaxLength } from 'class-validator';
import { Type } from 'class-transformer';

// POST /admin/parent-links — vincula un usuario padre/madre a un alumno.
// Se valida que el alumno pertenezca al colegio del admin y que el usuario
// tenga rol 'parent' en ese colegio.
export class CreateParentLinkDto {
  @IsInt()
  @Type(() => Number)
  userId: number;

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
