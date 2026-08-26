import { Controller, Get, Post, Body, Param, ParseIntPipe } from '@nestjs/common';
import { IsString, IsInt, IsPositive, IsOptional, IsArray, IsNumber } from 'class-validator';
import { PaymentsService } from './payments.service';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';

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

  // Hallazgo BL-3 de la auditoría: las 3 escrituras de este controller
  // (crear concepto, asignar obligaciones, registrar pago) no tenían
  // ningún @Roles() — el propio comentario del service dice "La
  // administración del colegio crea..."/"La tesorería del colegio
  // registra...", y el sistema solo define 3 roles (school_admin, teacher,
  // parent), así que school_admin es el único que corresponde a esa
  // descripción. Antes, cualquier padre autenticado podía crear
  // obligaciones de pago falsas o marcar deudas ajenas como pagadas.
  @Post('concepts')
  @Roles('school_admin')
  createConcept(@Body() dto: CreateConceptDto, @CurrentUser() user: UserPayload) {
    return this.service.createConcept(
      { ...dto, schoolId: user.schoolId ?? BigInt(0) },
      user.sub,
    );
  }

  @Post('obligations')
  @Roles('school_admin')
  assignObligations(@Body() dto: AssignObligationsDto, @CurrentUser() user: UserPayload) {
    return this.service.assignObligations(dto, user.schoolId ?? BigInt(0), user.sub);
  }

  @Post('record')
  @Roles('school_admin')
  recordPayment(@Body() dto: RecordPaymentDto, @CurrentUser() user: UserPayload) {
    return this.service.recordPayment(dto, user.schoolId ?? BigInt(0), user.sub);
  }

  @Get('student/:studentId')
  getStudentObligations(
    @Param('studentId', ParseIntPipe) studentId: number,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.getStudentObligations(studentId, user);
  }
}
