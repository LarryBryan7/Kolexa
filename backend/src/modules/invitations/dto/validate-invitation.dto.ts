import { IsString, IsNotEmpty } from 'class-validator';

// Hallazgo IM-6: el token viaja en el body (POST), no en el path de un
// GET — evita que quede expuesto por defecto en access logs de
// proxy/CDN/Railway. Ver invitations.controller.ts.
export class ValidateInvitationDto {
  @IsString()
  @IsNotEmpty({ message: 'El token es requerido' })
  token: string;
}
