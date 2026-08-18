import { IsEmail, IsOptional, IsString, MaxLength } from 'class-validator';

// POST /admin/parents — crea la información INSTITUCIONAL de un padre/apoderado.
// NO crea cuenta de usuario ni contraseña: el padre crea/activa su cuenta desde
// la app móvil. El vínculo institucional puede existir antes de que el padre
// tenga cuenta (userId queda null hasta que se vincule desde la app).
export class CreateParentDto {
  @IsString()
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

  @IsOptional()
  @IsEmail()
  @MaxLength(128)
  email?: string;
}
