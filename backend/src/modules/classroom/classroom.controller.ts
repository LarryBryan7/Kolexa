import {
  Controller, Get, Post, Param, Query, Res, UseGuards, Request, Header,
  UnauthorizedException,
} from '@nestjs/common';
import { Response } from 'express';
import { ClassroomService } from './classroom.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Public } from '../../common/decorators/public.decorator';

@Controller('classroom')
export class ClassroomController {
  constructor(private readonly classroomService: ClassroomService) {}

  // ── GET /classroom/student/:studentId/auth-url ────────────
  // El padre obtiene la URL para que el alumno autorice Classroom
  @UseGuards(JwtAuthGuard)
  @Get('student/:studentId/auth-url')
  getAuthUrl(@Param('studentId') studentId: string) {
    const url = this.classroomService.getAuthUrl(studentId);
    return { url };
  }

  // ── GET /classroom/callback ───────────────────────────────
  // Google redirige aquí tras la autorización (alumno o docente)
  @Public()
  @Get('callback')
  async handleCallback(
    @Query('code') code: string,
    @Query('state') state: string,
    @Res() res: Response,
  ) {
    const result = await this.classroomService.handleCallback(code, state);
    if (result.type === 'teacher') {
      res.redirect(`/api/v1/classroom/success?type=teacher`);
    } else {
      res.redirect(`/api/v1/classroom/success?type=student`);
    }
  }

  // ── GET /classroom/success ───────────────────────────────
  @Public()
  @Header('Content-Type', 'text/html')
  @Get('success')
  successPage(@Res() res: Response) {
    res.send(`<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Kolexa</title>
  <style>
    *{margin:0;padding:0;box-sizing:border-box}
    body{font-family:-apple-system,sans-serif;background:#F7F6F3;display:flex;align-items:center;justify-content:center;min-height:100vh}
    .card{background:#fff;border-radius:20px;padding:40px 32px;text-align:center;max-width:320px;width:90%}
    .icon{width:72px;height:72px;background:#EDE8FA;border-radius:50%;display:flex;align-items:center;justify-content:center;margin:0 auto 20px;font-size:32px}
    h2{color:#1E1B29;font-size:20px;margin-bottom:8px}
    p{color:#666;font-size:14px;line-height:1.5}
    .hint{margin-top:24px;font-size:12px;color:#aaa}
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">✅</div>
    <h2>¡Conexión exitosa!</h2>
    <p>Google Classroom está conectado a Kolexa.</p>
    <p class="hint">Puedes cerrar esta pestaña y regresar a la app.</p>
  </div>
  <script>
    setTimeout(function(){
      window.location.href = 'kolexa://classroom/connected';
    }, 400);
  </script>
</body>
</html>`);
  }

  // ── GET /classroom/teacher/auth-url ──────────────────────
  @UseGuards(JwtAuthGuard)
  @Get('teacher/auth-url')
  getTeacherAuthUrl(@Request() req: any) {
    const url = this.classroomService.getAuthUrl(String(req.user.sub), 'teacher');
    return { url };
  }

  // ── GET /classroom/teacher/status ────────────────────────
  @UseGuards(JwtAuthGuard)
  @Get('teacher/status')
  async getTeacherStatus(@Request() req: any) {
    const connected = await this.classroomService.isTeacherConnected(BigInt(req.user.sub));
    return { connected };
  }

  // ── POST /classroom/teacher/sync ─────────────────────────
  // Traduce invalid_grant/invalid_token a 401 TOKEN_EXPIRED (igual que el sync
  // del alumno) para que el móvil ofrezca "reconectar" cuando el token caduca.
  @UseGuards(JwtAuthGuard)
  @Post('teacher/sync')
  async syncTeacher(@Request() req: any) {
    try {
      return await this.classroomService.syncTeacher(BigInt(req.user.sub));
    } catch (e: any) {
      const msg: string = e?.response?.data?.error ?? e?.message ?? '';
      if (msg.includes('invalid_grant') || msg.includes('invalid_token')) {
        throw new UnauthorizedException('TOKEN_EXPIRED');
      }
      throw e;
    }
  }

  // ── GET /classroom/teacher/courses ───────────────────────
  @UseGuards(JwtAuthGuard)
  @Get('teacher/courses')
  async getTeacherCourses(@Request() req: any) {
    return this.classroomService.getTeacherCourses(BigInt(req.user.sub));
  }

  // ── GET /classroom/teacher/roster?courseId=X ─────────────
  // courseId es opcional (P1-6): si se pasa, devuelve el roster de ese curso.
  @UseGuards(JwtAuthGuard)
  @Get('teacher/roster')
  async getTeacherRoster(@Request() req: any, @Query('courseId') courseId?: string) {
    return this.classroomService.getTeacherRoster(
      BigInt(req.user.sub),
      courseId ? BigInt(courseId) : undefined,
    );
  }

  // ── GET /classroom/teacher/pending ───────────────────────
  @UseGuards(JwtAuthGuard)
  @Get('teacher/pending')
  async getTeacherPending(@Request() req: any) {
    const count = await this.classroomService.getTeacherPending(BigInt(req.user.sub));
    return { count };
  }

  // ── GET /classroom/parent/today-summary ──────────────────
  @UseGuards(JwtAuthGuard)
  @Get('parent/today-summary')
  async getParentTodaySummary() {
    return this.classroomService.getParentTodaySummary();
  }

  // ── GET /classroom/parent/home?studentId=X ───────────────
  // Vista combinada del home del padre: todaySummary + upcomingStatus en
  // UNA sola petición. Ejecuta todas las queries en 1-2 conexiones al
  // pooler, evitando que los cards "Novedades" y "Esta semana" compitan por
  // la única conexión (connection_limit=1) y se serialicen.
  @UseGuards(JwtAuthGuard)
  @Get('parent/home')
  async getParentHome(@Query('studentId') studentId: string) {
    return this.classroomService.getParentHome(BigInt(studentId));
  }

  // ── GET /classroom/student/:studentId/status ──────────────
  @UseGuards(JwtAuthGuard)
  @Get('student/:studentId/status')
  async getStatus(@Param('studentId') studentId: string) {
    const connected = await this.classroomService.isConnected(BigInt(studentId));
    return { connected };
  }

  // ── POST /classroom/student/:studentId/sync ───────────────
  // Sincroniza datos desde Google Classroom hacia la BD de Kolexa
  @UseGuards(JwtAuthGuard)
  @Post('student/:studentId/sync')
  async sync(@Param('studentId') studentId: string) {
    try {
      return await this.classroomService.syncStudent(BigInt(studentId));
    } catch (e: any) {
      const msg: string = e?.response?.data?.error ?? e?.message ?? '';
      if (msg.includes('invalid_grant') || msg.includes('invalid_token')) {
        throw new UnauthorizedException('TOKEN_EXPIRED');
      }
      throw e;
    }
  }

  // ── GET /classroom/student/:studentId/courses ─────────────
  @UseGuards(JwtAuthGuard)
  @Get('student/:studentId/courses')
  async getCourses(@Param('studentId') studentId: string) {
    return this.classroomService.getCourses(BigInt(studentId));
  }

  // ── GET /classroom/student/:studentId/upcoming ────────────
  // Próximas tareas con fecha de entrega (todos los cursos)
  @UseGuards(JwtAuthGuard)
  @Get('student/:studentId/upcoming')
  async getUpcoming(@Param('studentId') studentId: string) {
    return this.classroomService.getUpcomingCoursework(BigInt(studentId));
  }

  // ── GET /classroom/student/:studentId/overview ────────────
  // Vista combinada: connected + sync (con caché) + courses + upcoming
  // en UNA sola respuesta. Reduce de 4 requests HTTP a 1.
  @UseGuards(JwtAuthGuard)
  @Get('student/:studentId/overview')
  async getOverview(@Param('studentId') studentId: string) {
    try {
      return await this.classroomService.getOverview(BigInt(studentId));
    } catch (e: any) {
      const msg: string = e?.response?.data?.error ?? e?.message ?? '';
      if (msg.includes('invalid_grant') || msg.includes('invalid_token')) {
        throw new UnauthorizedException('TOKEN_EXPIRED');
      }
      throw e;
    }
  }

  // ── GET /classroom/student/:studentId/upcoming-status ─────
  // Vista ligera para el card "Esta semana" del home del padre:
  // connected + upcoming en UNA sola petición (sin courses ni sync).
  @UseGuards(JwtAuthGuard)
  @Get('student/:studentId/upcoming-status')
  async getUpcomingStatus(@Param('studentId') studentId: string) {
    return this.classroomService.getUpcomingStatus(BigInt(studentId));
  }
}
