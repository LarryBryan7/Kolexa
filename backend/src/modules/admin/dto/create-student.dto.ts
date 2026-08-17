import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsDateString,
  MaxLength,
} from 'class-validator';

// POST /admin/students — crea un alumno dentro del colegio del admin.
// Se exige un identificador fuerte: dni o code (al menos uno).
export class CreateStudentDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  firstName: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  lastName?: string;

  // Identificador fuerte: se exige al menos uno de dni o code.
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
}
