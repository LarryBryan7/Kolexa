import { IsEmail, IsIn, IsString, IsOptional } from 'class-validator';
import { IsBigIntString } from '../../../common/validators/is-bigint-string.validator';
import { NormalizeEmail } from '../../../common/decorators/normalize-email.decorator';

// email: obligatorio de facto tanto para invitaciones de Parent como
// genéricas (validado en el service, no aquí) — el login con Google exige
// que coincida exacto con el email de la cuenta que se vincula.
// parentId: presente únicamente cuando la invitación es para un Parent
// institucional concreto — el service deriva schoolId/rol a partir de ahí,
// nunca confía en lo que mande el cliente para decidir la vinculación.
// role: obligatorio cuando NO hay parentId (invitación genérica de
// docente/director). Se valida contra una lista blanca y se resuelve al
// roleId real DENTRO del service — el cliente nunca manda un id numérico
// de rol directamente (mismo principio que ya aplicaba a "parent": Web
// Admin no necesita conocer ids internos de la tabla Role).
// schoolId: el controller SIEMPRE usa el schoolId del JWT del admin
// autenticado (user.schoolId), nunca este campo — se deja opcional para
// no pedirle al cliente un dato que de todas formas se ignora.
export class CreateInvitationDto {
  // @NormalizeEmail() (hallazgo IM-7): antes se guardaba tal cual llegaba
  // del admin (con mayúsculas/espacios si los tuviera), y el chequeo de
  // "invitación duplicada" (invitations.service.ts) comparaba exacto —
  // "Test@x.com" y " test@x.com " se trataban como emails DISTINTOS.
  @IsOptional()
  @NormalizeEmail()
  @IsEmail({}, { message: 'Email inválido' })
  email?: string;

  @IsOptional()
  @IsString()
  schoolId?: string;

  @IsOptional()
  @IsIn(['teacher', 'school_admin'], { message: 'role debe ser teacher o school_admin' })
  role?: 'teacher' | 'school_admin';

  // Hallazgo IM-3 de la auditoría (y su residual, cerrado en la Ronda 4):
  // antes era @IsString() sin más — un parentId no numérico (ej. "abc")
  // pasaba el ValidationPipe y reventaba en BigInt(dto.parentId) del
  // controller con un SyntaxError sin capturar (500). El primer fix
  // (@IsInt() + @Type(Number)) cerró ESE caso, pero introdujo uno nuevo:
  // Number() pierde precisión en strings de muchos dígitos (ej.
  // "9".repeat(40)) — Number.isInteger() los sigue aceptando, y el valor
  // reventaba más abajo en Postgres ("value out of range for bigint").
  // @IsBigIntString() nunca pasa por Number: valida el string contra un
  // regex de solo dígitos y lo convierte a BigInt directamente para
  // comprobar el rango real de un BIGINT de Postgres. El campo se queda
  // como string — BigInt(dto.parentId) en el controller sigue funcionando
  // igual, ahora con la garantía de que nunca falla ni pierde precisión.
  @IsOptional()
  @IsBigIntString()
  parentId?: string;
}
