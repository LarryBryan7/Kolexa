import { IsEmail, IsInt, IsString, IsNotEmpty } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateInvitationDto {
  @IsEmail({}, { message: 'Email inválido' })
  email: string;

  @IsString()
  @IsNotEmpty()
  schoolId: string;

  @IsInt()
  @Type(() => Number)
  roleId: number;
}
