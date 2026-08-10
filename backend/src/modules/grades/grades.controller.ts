import { Controller, Get, Post, Body, Param, Query, ParseIntPipe } from '@nestjs/common';
import { IsInt, IsPositive, IsString, IsOptional, IsNumber, Min, Max } from 'class-validator';
import { GradesService } from './grades.service';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';

class CreatePeriodDto {
  @IsString() name: string;
  @IsString() startDate: string;
  @IsString() endDate: string;
}

class SetGradeDto {
  @IsInt() @IsPositive() studentId: number;
  @IsInt() @IsPositive() courseId: number;
  @IsInt() @IsPositive() periodId: number;
  @IsNumber() @Min(0) @Max(20) grade: number;
  @IsOptional() @IsString() observations?: string;
}

@Controller('grades')
export class GradesController {
  constructor(private readonly service: GradesService) {}

  // POST /grades/periods
  @Post('periods')
  createPeriod(@Body() dto: CreatePeriodDto, @CurrentUser() user: UserPayload) {
    return this.service.createPeriod(
      { ...dto, schoolId: user.schoolId ?? BigInt(0) },
      user.sub,
    );
  }

  // GET /grades/periods
  @Get('periods')
  getPeriods(@CurrentUser() user: UserPayload) {
    return this.service.getPeriods(user.schoolId ?? BigInt(0));
  }

  // POST /grades
  @Post()
  setGrade(@Body() dto: SetGradeDto, @CurrentUser() user: UserPayload) {
    return this.service.setGrade(dto, user.sub);
  }

  // GET /grades/student/:studentId
  @Get('student/:studentId')
  getStudentReport(
    @Param('studentId', ParseIntPipe) studentId: number,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.getStudentReport(studentId, user.sub);
  }

  // GET /grades/classroom/:classroomId/period/:periodId
  @Get('classroom/:classroomId/period/:periodId')
  getClassroomGrades(
    @Param('classroomId', ParseIntPipe) classroomId: number,
    @Param('periodId', ParseIntPipe) periodId: number,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.getClassroomGrades(classroomId, periodId, user.sub);
  }
}
