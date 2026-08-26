// ============================================================
// homework.controller.ts — Controlador de Tareas
// ============================================================
// Rutas:
//   POST   /homework                             → crear tarea
//   GET    /homework/classroom/:id               → tareas de un aula
//   GET    /homework/student/:id                 → tareas de un alumno (padre)
//   GET    /homework/:id                         → detalle de una tarea
//   PATCH  /homework/:id                         → editar tarea
//   PATCH  /homework/:id/students/:studentId     → revisar entrega
//   DELETE /homework/:id                         → eliminar (soft delete)
// ============================================================

import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  ParseIntPipe,
} from '@nestjs/common';
import { HomeworkService } from './homework.service';
import {
  CreateHomeworkDto,
  UpdateHomeworkDto,
  UpdateStudentHomeworkDto,
} from './dto/homework.dto';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';

@Controller('homework')
export class HomeworkController {
  constructor(private readonly homeworkService: HomeworkService) {}

  @Post()
  create(@Body() dto: CreateHomeworkDto, @CurrentUser() user: UserPayload) {
    return this.homeworkService.createHomework(dto, user.sub);
  }

  // GET /homework/classroom/:classroomId
  @Get('classroom/:classroomId')
  getByClassroom(
    @Param('classroomId', ParseIntPipe) classroomId: number,
    @CurrentUser() user: UserPayload,
  ) {
    return this.homeworkService.getClassroomHomework(classroomId, user);
  }

  // GET /homework/student/:studentId
  @Get('student/:studentId')
  getByStudent(
    @Param('studentId', ParseIntPipe) studentId: number,
    @CurrentUser() user: UserPayload,
  ) {
    return this.homeworkService.getStudentHomework(studentId, user);
  }

  // GET /homework/:id
  @Get(':id')
  getOne(@Param('id', ParseIntPipe) id: number) {
    return this.homeworkService.getHomeworkById(BigInt(id));
  }

  // PATCH /homework/:id
  @Patch(':id')
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateHomeworkDto,
    @CurrentUser() user: UserPayload,
  ) {
    return this.homeworkService.updateHomework(BigInt(id), dto, user.sub);
  }

  // PATCH /homework/:id/students/:studentId
  @Patch(':id/students/:studentId')
  updateSubmission(
    @Param('id', ParseIntPipe) id: number,
    @Param('studentId', ParseIntPipe) studentId: number,
    @Body() dto: UpdateStudentHomeworkDto,
    @CurrentUser() user: UserPayload,
  ) {
    return this.homeworkService.updateStudentSubmission(
      BigInt(id),
      studentId,
      dto,
      user.sub,
    );
  }

  // DELETE /homework/:id
  @Delete(':id')
  remove(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: UserPayload,
  ) {
    return this.homeworkService.deleteHomework(BigInt(id), user.sub);
  }
}
