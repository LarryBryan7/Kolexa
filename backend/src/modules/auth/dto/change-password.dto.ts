// ============================================================
// change-password.dto.ts — DTO para cambio de contraseña
// ============================================================

import { IsString, MinLength, Matches } from 'class-validator';

export class ChangePasswordDto {
  @IsString()
  currentPassword: string;

  @IsString()
  @MinLength(8, { message: 'La nueva contraseña debe tener al menos 8 caracteres' })
  // @Matches obliga a que la contraseña tenga al menos:
  // una mayúscula, una minúscula y un número
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$/, {
    message: 'La contraseña debe tener al menos una mayúscula, una minúscula y un número',
  })
  newPassword: string;
}
