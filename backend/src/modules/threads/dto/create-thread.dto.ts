import { IsInt, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateThreadDto {
  @IsInt()
  recipientId!: number;

  // Obligatorio salvo que uno de los dos lados sea director/admin: una
  // conversación padre↔docente siempre es sobre un alumno concreto — es la
  // llave que evita mezclar hijos distintos en un mismo hilo.
  @IsOptional()
  @IsInt()
  studentId?: number;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  subject?: string;

  @IsString()
  @MinLength(1)
  @MaxLength(5000)
  firstMessageBody!: string;
}
