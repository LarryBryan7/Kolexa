import { IsString, IsOptional, IsInt, IsBoolean, MaxLength, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

// PATCH /admin/classrooms/:id — actualiza un aula del colegio del admin
export class UpdateClassroomDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  grade?: string;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  section?: string;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  @Min(2000)
  @Max(2100)
  academicYear?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
