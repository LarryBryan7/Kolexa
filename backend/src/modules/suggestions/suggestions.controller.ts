import { Controller, Get, Post, Body, Param, Query, ParseIntPipe } from '@nestjs/common';
import { IsString, IsBoolean, IsOptional } from 'class-validator';
import { SuggestionsService } from './suggestions.service';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';

class SubmitSuggestionDto {
  @IsString() category: string;
  @IsString() title: string;
  @IsString() description: string;
  @IsOptional() @IsBoolean() isAnonymous?: boolean;
}

class RespondDto {
  @IsString() response: string;
  @IsString() status: string;
}

@Controller('suggestions')
export class SuggestionsController {
  constructor(private readonly service: SuggestionsService) {}

  @Post()
  submit(@Body() dto: SubmitSuggestionDto, @CurrentUser() user: UserPayload) {
    return this.service.submit({ ...dto, schoolId: user.schoolId ?? BigInt(0) }, user.sub);
  }

  @Get('my')
  getMy(@CurrentUser() user: UserPayload) {
    return this.service.getMySuggestions(user.sub);
  }

  @Get('school')
  getAll(
    @CurrentUser() user: UserPayload,
    @Query('status') status?: string,
  ) {
    return this.service.getAllForSchool(user.schoolId ?? BigInt(0), status);
  }

  @Post(':id/respond')
  respond(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RespondDto,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.respond(id, dto, user.sub);
  }
}
