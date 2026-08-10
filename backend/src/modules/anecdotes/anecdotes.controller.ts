import { Controller, Get, Post, Delete, Body, Param, Query, ParseIntPipe } from '@nestjs/common';
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

  @Get('student/:studentId')
  getForStudent(
    @Param('studentId', ParseIntPipe) studentId: number,
    @CurrentUser() user: UserPayload,
    @Query('role') role: 'teacher' | 'parent' = 'parent',
  ) {
    return this.service.getForStudent(studentId, user.sub, role === 'teacher');
  }

  @Delete(':id')
  delete(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: UserPayload) {
    return this.service.delete(id, user.sub);
  }
}
