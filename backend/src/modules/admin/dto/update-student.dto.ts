import { IsString, IsOptional, IsBoolean, IsDateString, MaxLength } from 'class-validator';

// PATCH /admin/students/:id — actualiza un alumno del colegio del admin
export class UpdateStudentDto {
  @IsOptional()
  @IsString()
  @MaxLength(255)
  firstName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  lastName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  dni?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  code?: string;

  @IsOptional()
  @IsDateString()
  birthday?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1)
  sex?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
