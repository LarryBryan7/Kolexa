import { IsEmail, IsOptional, IsString, MaxLength } from 'class-validator';

// PATCH /admin/parents/:id — actualiza la información institucional del padre.
// No gestiona contraseñas ni cuentas (eso es de la app móvil).
export class UpdateParentDto {
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
  phone?: string;

  @IsOptional()
  @IsEmail()
  @MaxLength(128)
  email?: string;

  @IsOptional()
  isActive?: boolean;
}
