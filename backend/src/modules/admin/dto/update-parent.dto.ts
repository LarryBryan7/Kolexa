import { IsEmail, IsOptional, IsString, MaxLength } from 'class-validator';
import { NormalizeEmail } from '../../../common/decorators/normalize-email.decorator';

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
  @NormalizeEmail()
  @IsEmail()
  @MaxLength(128)
  email?: string;

  @IsOptional()
  isActive?: boolean;
}
