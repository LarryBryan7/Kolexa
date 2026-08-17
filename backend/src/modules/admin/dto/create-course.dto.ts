import { IsString, IsNotEmpty, IsOptional, MaxLength } from 'class-validator';

// POST /admin/courses — crea un curso dentro del colegio del admin
export class CreateCourseDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  code?: string;
}
