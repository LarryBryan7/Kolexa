import { Controller, Get, Post, Body, Param, ParseIntPipe } from '@nestjs/common';
import { IsString, IsInt, IsPositive, IsOptional, IsArray, IsNumber } from 'class-validator';
import { PaymentsService } from './payments.service';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';

class CreateConceptDto {
  @IsString() name: string;
  @IsOptional() @IsString() description?: string;
  @IsNumber() amount: number;
  @IsString() currency: string;
  @IsOptional() @IsString() dueDate?: string;
}

class AssignObligationsDto {
  @IsInt() @IsPositive() conceptId: number;
  @IsArray() @IsInt({ each: true }) studentIds: number[];
  @IsOptional() @IsString() dueDate?: string;
}

class RecordPaymentDto {
  @IsInt() @IsPositive() obligationId: number;
  @IsNumber() amountPaid: number;
  @IsString() paymentMethod: string;
  @IsOptional() @IsString() reference?: string;
  @IsOptional() @IsString() notes?: string;
}

@Controller('payments')
export class PaymentsController {
  constructor(private readonly service: PaymentsService) {}

  @Get('concepts')
  getConcepts(@CurrentUser() user: UserPayload) {
    return this.service.getConcepts(user.schoolId ?? BigInt(0));
  }

  @Post('concepts')
  createConcept(@Body() dto: CreateConceptDto, @CurrentUser() user: UserPayload) {
    return this.service.createConcept(
      { ...dto, schoolId: user.schoolId ?? BigInt(0) },
      user.sub,
    );
  }

  @Post('obligations')
  assignObligations(@Body() dto: AssignObligationsDto, @CurrentUser() user: UserPayload) {
    return this.service.assignObligations(dto, user.sub);
  }

  @Post('record')
  recordPayment(@Body() dto: RecordPaymentDto, @CurrentUser() user: UserPayload) {
    return this.service.recordPayment(dto, user.sub);
  }

  @Get('student/:studentId')
  getStudentObligations(
    @Param('studentId', ParseIntPipe) studentId: number,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.getStudentObligations(studentId, user.sub);
  }
}
