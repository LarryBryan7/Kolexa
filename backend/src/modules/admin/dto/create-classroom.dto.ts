import { IsString, IsOptional, IsInt, IsNotEmpty, MaxLength, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

// POST /admin/classrooms — crea un aula dentro del colegio del admin
export class CreateClassroomDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  grade?: string;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  section?: string;

  @IsInt()
  @Type(() => Number)
  @Min(2000)
  @Max(2100)
  academicYear: number;

  // schoolLocationId: la sede del colegio donde se crea el aula.
  // Se valida que pertenezca al schoolId del admin autenticado.
  @IsInt()
  @Type(() => Number)
  schoolLocationId: number;
}
