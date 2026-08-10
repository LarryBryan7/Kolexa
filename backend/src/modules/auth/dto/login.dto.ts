// ============================================================
// login.dto.ts — Data Transfer Object para el login
// ============================================================
// Un DTO (Data Transfer Object) define la FORMA de los datos
// que esperamos recibir en el body de una petición HTTP.
//
// class-validator lee los decoradores (@IsEmail, @IsString...)
// y ValidationPipe (registrado en main.ts) los valida
// automáticamente antes de que lleguen al controlador.
//
// Si el body no cumple las reglas → 400 Bad Request automático
// sin escribir ninguna validación manual.
// ============================================================

import { IsEmail, IsString, MinLength, IsOptional } from 'class-validator';

export class LoginDto {
  // @IsEmail() verifica que sea un email válido con formato correcto
  @IsEmail({}, { message: 'El email no tiene un formato válido' })
  email: string;

  // @MinLength(6) requiere mínimo 6 caracteres
  @IsString({ message: 'La contraseña debe ser texto' })
  @MinLength(6, { message: 'La contraseña debe tener al menos 6 caracteres' })
  password: string;

  // Token de Firebase para push notifications (FCM/APNS).
  // Es opcional porque el usuario puede hacer login desde
  // la web donde no hay push notifications.
  @IsOptional()
  @IsString()
  firebaseToken?: string;
}
