import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsEmail,
  IsIn,
  MaxLength,
} from 'class-validator';
import { NormalizeEmail } from '../../../common/decorators/normalize-email.decorator';

// POST /admin/users — crea un usuario (docente o padre) dentro del colegio del admin.
// El usuario se crea SIN contraseña (needsPasswordChange=true) y se activa mediante
// el flujo de invitación/activación de KOLEXA (el propio usuario define su contraseña).
export class CreateUserDto {
  @NormalizeEmail()
  @IsEmail({}, { message: 'Email inválido' })
  email: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  firstName: string;

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

  // Rol del usuario dentro del colegio: 'teacher' (docente), 'parent' (padre)
  // o 'school_admin' (director). Los tres se activan por el mismo flujo de
  // invitación (Google + código) — ninguno recibe contraseña.
  @IsIn(['teacher', 'parent', 'school_admin'], {
    message: 'Rol inválido. Debe ser teacher, parent o school_admin',
  })
  role: 'teacher' | 'parent' | 'school_admin';
}
