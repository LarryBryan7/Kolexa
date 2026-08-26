import { Controller, Get, Post, Delete, Body, Param, ParseIntPipe } from '@nestjs/common';
import { IsString, IsInt, IsPositive, IsOptional, IsBoolean } from 'class-validator';
import { AnecdotesService } from './anecdotes.service';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';

class CreateAnecdoteDto {
  @IsInt() @IsPositive() studentId: number;
  @IsString() title: string;
  @IsString() description: string;
  @IsOptional() @IsString() category?: string;
  @IsOptional() @IsBoolean() isPrivate?: boolean;
  @IsOptional() @IsString() date?: string;
}

@Controller('anecdotes')
export class AnecdotesController {
  constructor(private readonly service: AnecdotesService) {}

  @Post()
  create(@Body() dto: CreateAnecdoteDto, @CurrentUser() user: UserPayload) {
    return this.service.create(dto, user.sub);
  }

  // Hallazgo BL-2 de la auditoría: `role` venía de un query param
  // controlado por el cliente y decidía si se saltaba el ownership check
  // y si se mostraban anécdotas PRIVADAS — cualquier padre podía llamar
  // ?role=teacher y ver anécdotas privadas de un alumno ajeno, de
  // cualquier colegio. Ahora `isTeacher` se deriva de los roles reales
  // del JWT, nunca de la query string.
  @Get('student/:studentId')
  getForStudent(
    @Param('studentId', ParseIntPipe) studentId: number,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.getForStudent(studentId, user, user.roles.includes('teacher'));
  }

  @Delete(':id')
  delete(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: UserPayload) {
    return this.service.delete(id, user.sub);
  }
}
