// ============================================================
// google-login.dto.ts — DTO para el login con Google
// ============================================================
// Este DTO recibe ÚNICAMENTE el ID Token emitido por Google.
//
// IMPORTANTE (seguridad):
//   - El backend NO confía en email, firstName, lastName ni googleSub
//     enviados por el cliente como campos independientes.
//   - La fuente de verdad es el ID Token, que el backend valida
//     criptográficamente con Google (firma, issuer, audience, expiración).
//   - El único dato que aceptamos del cliente es el ID Token en sí.
// ============================================================

import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

export class GoogleLoginDto {
  // ID Token de Google (JWT firmado por Google).
  // El backend lo valida con google-auth-library.
  @IsString()
  @IsNotEmpty({ message: 'El ID Token de Google es requerido' })
  idToken: string;

  // Token de Firebase para push notifications (opcional, igual que login).
  @IsOptional()
  @IsString()
  firebaseToken?: string;
}
