// ============================================================
// admin.controller.ts — Controlador de la Web Admin
// ============================================================
// Rutas (prefijo global /api/v1):
//   GET    /api/v1/admin/school
//   PATCH  /api/v1/admin/school
//   GET    /api/v1/admin/classrooms
//   POST   /api/v1/admin/classrooms
//   PATCH  /api/v1/admin/classrooms/:id
//   DELETE /api/v1/admin/classrooms/:id
//   GET    /api/v1/admin/courses
//   POST   /api/v1/admin/courses
//   PATCH  /api/v1/admin/courses/:id
//   DELETE /api/v1/admin/courses/:id
//   GET    /api/v1/admin/users
//   POST   /api/v1/admin/users
//   PATCH  /api/v1/admin/users/:id
//   GET    /api/v1/admin/students
//   POST   /api/v1/admin/students
//   PATCH  /api/v1/admin/students/:id
//   POST   /api/v1/admin/enrollments
//   DELETE /api/v1/admin/enrollments/:id
//   POST   /api/v1/admin/parent-links
//   DELETE /api/v1/admin/parent-links/:id
//   POST   /api/v1/admin/assignments
//   DELETE /api/v1/admin/assignments/:id
//
// Acceso: solo usuarios con rol 'school_admin'.
// El schoolId se obtiene del JWT (NUNCA del body/query del cliente).
// ============================================================

import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  ParseIntPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { AdminService } from './admin.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';
import { UpdateSchoolDto } from './dto/update-school.dto';
import { CreateClassroomDto } from './dto/create-classroom.dto';
import { UpdateClassroomDto } from './dto/update-classroom.dto';
import { CreateCourseDto } from './dto/create-course.dto';
import { UpdateCourseDto } from './dto/update-course.dto';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { CreateStudentDto } from './dto/create-student.dto';
import { UpdateStudentDto } from './dto/update-student.dto';
import { CreateEnrollmentDto } from './dto/create-enrollment.dto';
import { CreateParentLinkDto } from './dto/create-parent-link.dto';
import { CreateAssignmentDto } from './dto/create-assignment.dto';

@Roles('school_admin')
@Controller('admin')
export class AdminController {
  constructor(private readonly service: AdminService) {}

  // ── Institución ──────────────────────────────────────────
  @Get('school')
  getSchool(@CurrentUser() user: UserPayload) {
    return this.service.getSchool(user.schoolId!);
  }

  @Patch('school')
  updateSchool(@CurrentUser() user: UserPayload, @Body() dto: UpdateSchoolDto) {
    return this.service.updateSchool(user.schoolId!, dto);
  }

  // ── Aulas ────────────────────────────────────────────────
  @Get('classrooms')
  listClassrooms(@CurrentUser() user: UserPayload) {
    return this.service.listClassrooms(user.schoolId!);
  }

  @Post('classrooms')
  @HttpCode(HttpStatus.CREATED)
  createClassroom(@CurrentUser() user: UserPayload, @Body() dto: CreateClassroomDto) {
    return this.service.createClassroom(user.schoolId!, dto);
  }

  @Patch('classrooms/:id')
  updateClassroom(
    @CurrentUser() user: UserPayload,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateClassroomDto,
  ) {
    return this.service.updateClassroom(user.schoolId!, BigInt(id), dto);
  }

  @Delete('classrooms/:id')
  deleteClassroom(
    @CurrentUser() user: UserPayload,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.service.deleteClassroom(user.schoolId!, BigInt(id));
  }

  // ── Cursos ───────────────────────────────────────────────
  @Get('courses')
  listCourses(@CurrentUser() user: UserPayload) {
    return this.service.listCourses(user.schoolId!);
  }

  @Post('courses')
  @HttpCode(HttpStatus.CREATED)
  createCourse(@CurrentUser() user: UserPayload, @Body() dto: CreateCourseDto) {
    return this.service.createCourse(user.schoolId!, dto);
  }

  @Patch('courses/:id')
  updateCourse(
    @CurrentUser() user: UserPayload,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateCourseDto,
  ) {
    return this.service.updateCourse(user.schoolId!, BigInt(id), dto);
  }

  @Delete('courses/:id')
  deleteCourse(
    @CurrentUser() user: UserPayload,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.service.deleteCourse(user.schoolId!, BigInt(id));
  }

  // ── Usuarios ─────────────────────────────────────────────
  @Get('users')
  listUsers(@CurrentUser() user: UserPayload, @Query('search') search?: string) {
    return this.service.listUsers(user.schoolId!, search);
  }

  @Post('users')
  @HttpCode(HttpStatus.CREATED)
  createUser(@CurrentUser() user: UserPayload, @Body() dto: CreateUserDto) {
    return this.service.createUser(user.schoolId!, dto);
  }

  @Patch('users/:id')
  updateUser(
    @CurrentUser() user: UserPayload,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateUserDto,
  ) {
    return this.service.updateUser(user.schoolId!, BigInt(id), dto);
  }

  // ── Alumnos ──────────────────────────────────────────────
  @Get('students')
  listStudents(@CurrentUser() user: UserPayload, @Query('search') search?: string) {
    return this.service.listStudents(user.schoolId!, search);
  }

  @Post('students')
  @HttpCode(HttpStatus.CREATED)
  createStudent(@CurrentUser() user: UserPayload, @Body() dto: CreateStudentDto) {
    return this.service.createStudent(user.schoolId!, dto);
  }

  @Patch('students/:id')
  updateStudent(
    @CurrentUser() user: UserPayload,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateStudentDto,
  ) {
    return this.service.updateStudent(user.schoolId!, BigInt(id), dto);
  }

  // ── Matrículas ───────────────────────────────────────────
  @Post('enrollments')
  @HttpCode(HttpStatus.CREATED)
  createEnrollment(@CurrentUser() user: UserPayload, @Body() dto: CreateEnrollmentDto) {
    return this.service.createEnrollment(user.schoolId!, dto);
  }

  @Delete('enrollments/:id')
  deleteEnrollment(
    @CurrentUser() user: UserPayload,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.service.deleteEnrollment(user.schoolId!, BigInt(id));
  }

  // ── Vínculo padre ↔ alumno ───────────────────────────────
  @Post('parent-links')
  @HttpCode(HttpStatus.CREATED)
  createParentLink(@CurrentUser() user: UserPayload, @Body() dto: CreateParentLinkDto) {
    return this.service.createParentLink(user.schoolId!, dto);
  }

  @Delete('parent-links/:id')
  deleteParentLink(
    @CurrentUser() user: UserPayload,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.service.deleteParentLink(user.schoolId!, BigInt(id));
  }

  // ── Asignación docente–curso–aula ────────────────────────
  @Post('assignments')
  @HttpCode(HttpStatus.CREATED)
  createAssignment(@CurrentUser() user: UserPayload, @Body() dto: CreateAssignmentDto) {
    return this.service.createAssignment(user.schoolId!, dto);
  }

  @Delete('assignments/:id')
  deleteAssignment(
    @CurrentUser() user: UserPayload,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.service.deleteAssignment(user.schoolId!, BigInt(id));
  }
}
