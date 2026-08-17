import { IsString, IsOptional, MaxLength } from 'class-validator';

// PATCH /admin/courses/:id — actualiza un curso del colegio del admin
export class UpdateCourseDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  code?: string;
}
