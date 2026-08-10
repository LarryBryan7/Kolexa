import { IsString, MinLength, IsNotEmpty, IsOptional } from 'class-validator';

export class RegisterWithTokenDto {
  @IsString()
  @IsNotEmpty({ message: 'El token de invitación es requerido' })
  token: string;

  @IsString()
  @IsNotEmpty({ message: 'El nombre es requerido' })
  firstName: string;

  @IsString()
  @IsNotEmpty({ message: 'El apellido es requerido' })
  lastName: string;

  @IsString()
  @MinLength(6, { message: 'La contraseña debe tener al menos 6 caracteres' })
  password: string;

  @IsOptional()
  @IsString()
  firebaseToken?: string;
}
