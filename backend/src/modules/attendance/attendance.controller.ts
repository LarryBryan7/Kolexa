// ============================================================
// attendance.controller.ts — Controlador de Asistencia
// ============================================================
// El Controller es el punto de entrada HTTP para el módulo de asistencia.
// Solo se encarga de:
//   1. Recibir la petición HTTP
//   2. Extraer los datos (params, query, body, usuario actual)
//   3. Llamar al Service con esos datos
//   4. Retornar la respuesta
//
// Rutas definidas en este controlador:
//   POST   /attendance                       → crear sesión
//   GET    /attendance/:id                   → obtener sesión por ID
//   GET    /attendance/classroom/:id?date=   → sesión de aula en fecha
//   PUT    /attendance/:id/records           → actualizar registros
//   GET    /attendance/student/:id/history   → historial de un alumno
//
// Todos los endpoints requieren JWT (el JwtAuthGuard es global).
// Ninguno tiene @Public() — solo usuarios autenticados pueden acceder.
// ============================================================

import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Param,
  Query,
  ParseIntPipe,
} from '@nestjs/common';
import { AttendanceService } from './attendance.service';
import { CreateAttendanceDto } from './dto/create-attendance.dto';
import { UpdateAttendanceRecordsDto } from './dto/update-records.dto';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';

// @Controller('attendance') define el prefijo de ruta para todos los métodos.
// Combinado con el prefijo global '/api/v1' de main.ts:
//   → todas las rutas quedan como /api/v1/attendance/...
@Controller('attendance')
export class AttendanceController {
  // El Service se inyecta en el constructor (DI de NestJS)
  constructor(private readonly attendanceService: AttendanceService) {}

  // ── POST /attendance ──────────────────────────────────────
  // El profesor crea una nueva sesión de asistencia.
  // Body: CreateAttendanceDto { classroomId, date, courseId?, notes? }
  //
  // @CurrentUser() extrae los datos del JWT del request
  // (ver current-user.decorator.ts — lo definimos en la fase anterior)
  @Post()
  async createSession(
    @Body() dto: CreateAttendanceDto,
    @CurrentUser() user: UserPayload,
  ) {
    // user.sub es el ID del usuario en la DB (viene del JWT)
    return this.attendanceService.createSession(dto, user.sub);
  }

  // ── GET /attendance/classroom/:classroomId ─────────────────
  // Obtiene la sesión de un aula en una fecha.
  // Query param 'date' en formato YYYY-MM-DD (ej: ?date=2024-03-15)
  //
  // IMPORTANTE: esta ruta debe ir ANTES de /attendance/:id
  // porque NestJS lee las rutas en orden — si /:id va primero,
  // intentaría parsear "classroom" como un ID numérico y fallaría.
  @Get('classroom/:classroomId')
  async getByClassroom(
    @Param('classroomId', ParseIntPipe) classroomId: number,
    // ParseIntPipe convierte el string del parámetro a número
    // y lanza 400 automáticamente si no es un número válido
    @Query('date') date: string,
  ) {
    // Si no se provee fecha, usar hoy
    const targetDate = date ?? new Date().toISOString().split('T')[0];
    return this.attendanceService.getByClassroom(classroomId, targetDate);
  }

  // ── GET /attendance/student/:studentId/history ─────────────
  // Historial de asistencia de un alumno (lo ve el padre).
  // Query params opcionales: ?limit=30&offset=0 (paginación)
  @Get('student/:studentId/history')
  async getStudentHistory(
    @Param('studentId', ParseIntPipe) studentId: number,
    @CurrentUser() user: UserPayload,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.attendanceService.getStudentHistory(
      studentId,
      user.sub,
      limit ? parseInt(limit, 10) : 30,
      offset ? parseInt(offset, 10) : 0,
    );
  }

  // ── GET /attendance/:id ────────────────────────────────────
  // Obtiene una sesión de asistencia por su ID, con todos los registros.
  // ParseIntPipe lanza 400 si :id no es un número.
  @Get(':id')
  async getSession(@Param('id', ParseIntPipe) id: number) {
    return this.attendanceService.getSession(BigInt(id));
  }

  // ── PUT /attendance/:id/records ────────────────────────────
  // El profesor actualiza el estado de asistencia de los alumnos.
  // Body: UpdateAttendanceRecordsDto { records: [...] }
  @Put(':id/records')
  async updateRecords(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateAttendanceRecordsDto,
    @CurrentUser() user: UserPayload,
  ) {
    return this.attendanceService.updateRecords(BigInt(id), dto, user.sub);
  }
}
