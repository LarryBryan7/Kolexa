import {
  Controller, Get, Post, Param, Query, Res, UseGuards, Request, Header,
  UnauthorizedException, UseInterceptors, UploadedFile, BadRequestException,
} from '@nestjs/common';
import { Response } from 'express';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { ClassroomService } from './classroom.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';
import { ParseBigIntPipe } from '../../common/pipes/parse-bigint.pipe';

const AVATAR_MAX_BYTES = 5 * 1024 * 1024; // 5MB

// code: 'GOOGLE_TOKEN_EXPIRED' (hallazgo H-01) — distingue explícitamente
// "el token OAuth de Google Classroom expiró" de "la sesión KOLEXA expiró"
// (JwtAuthGuard usa code: 'SESSION_TOKEN_EXPIRED' para ese otro caso).
// Antes ambos casos devolvían un 401 cuyo `message` contenía la palabra
// "token", y Flutter clasificaba por substring — confundía un problema de
// Classroom con una sesión KOLEXA vencida, disparando un refresh de sesión
// innecesario y, si el reintento repetía el mismo 401 de Classroom (como es
// de esperar), terminaba forzando un logout completo sin motivo real.
function googleTokenExpiredException(): UnauthorizedException {
  return new UnauthorizedException({
    statusCode: 401,
    code: 'GOOGLE_TOKEN_EXPIRED',
    message: 'TOKEN_EXPIRED',
    error: 'Unauthorized',
  });
}

@Controller('classroom')
export class ClassroomController {
  constructor(private readonly classroomService: ClassroomService) {}

  // ── GET /classroom/student/:studentId/auth-url ────────────
  // El padre obtiene la URL para que el alumno autorice Classroom
  @UseGuards(JwtAuthGuard)
  @Get('student/:studentId/auth-url')
  async getAuthUrl(@Param('studentId', ParseBigIntPipe) studentId: bigint, @CurrentUser() user: UserPayload) {
    await this.classroomService.assertStudentOwnedByParent(user.sub, studentId);
    const url = this.classroomService.getAuthUrl(studentId.toString());
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
        throw googleTokenExpiredException();
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
  // studentId obligatorio (hallazgo BL-1): sin él, este endpoint buscaba
  // "la sesión de asistencia más reciente de toda la base de datos" y
  // devolvía datos de cualquier colegio a cualquier padre autenticado.
  @UseGuards(JwtAuthGuard)
  @Get('parent/today-summary')
  async getParentTodaySummary(
    @Query('studentId', ParseBigIntPipe) studentId: bigint,
    @CurrentUser() user: UserPayload,
  ) {
    await this.classroomService.assertStudentReadAccess(user, studentId);
    return this.classroomService.getParentTodaySummary(studentId);
  }

  // ── GET /classroom/parent/home?studentId=X ───────────────
  // Vista combinada del home del padre: todaySummary + upcomingStatus en
  // UNA sola petición. Ejecuta todas las queries en 1-2 conexiones al
  // pooler, evitando que los cards "Novedades" y "Esta semana" compitan por
  // la única conexión (connection_limit=1) y se serialicen.
  @UseGuards(JwtAuthGuard)
  @Get('parent/home')
  async getParentHome(@Query('studentId', ParseBigIntPipe) studentId: bigint, @CurrentUser() user: UserPayload) {
    await this.classroomService.assertStudentReadAccess(user, studentId);
    return this.classroomService.getParentHome(studentId);
  }

  // ── POST /classroom/student/:studentId/avatar ─────────────
  // El padre sube/reemplaza la foto de perfil de un hijo suyo. Límite de
  // 5MB y solo imágenes — igual que el resto de subidas de este módulo,
  // guarda el storagePath (bucket privado 'avatars') y devuelve una URL
  // firmada de corta duración para mostrarla de inmediato.
  @UseGuards(JwtAuthGuard)
  @Post('student/:studentId/avatar')
  @UseInterceptors(
    FileInterceptor('photo', {
      storage: memoryStorage(),
      limits: { fileSize: AVATAR_MAX_BYTES },
      fileFilter: (_req, file, cb) => {
        if (!file.mimetype.startsWith('image/')) {
          cb(new BadRequestException('El archivo debe ser una imagen'), false);
          return;
        }
        cb(null, true);
      },
    }),
  )
  async uploadAvatar(
    @Param('studentId', ParseBigIntPipe) studentId: bigint,
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: UserPayload,
  ) {
    await this.classroomService.assertStudentOwnedByParent(user.sub, studentId);
    if (!file) {
      throw new BadRequestException('Falta el archivo de la foto');
    }
    return this.classroomService.uploadStudentAvatar(studentId, file);
  }

  // ── GET /classroom/student/:studentId/status ──────────────
  @UseGuards(JwtAuthGuard)
  @Get('student/:studentId/status')
  async getStatus(@Param('studentId', ParseBigIntPipe) studentId: bigint, @CurrentUser() user: UserPayload) {
    await this.classroomService.assertStudentReadAccess(user, studentId);
    const connected = await this.classroomService.isConnected(studentId);
    return { connected };
  }

  // ── POST /classroom/student/:studentId/sync ───────────────
  // Sincroniza datos desde Google Classroom hacia la BD de Kolexa.
  // ?force=true salta la caché de 15 min (lo usa el pull-to-refresh manual).
  @UseGuards(JwtAuthGuard)
  @Post('student/:studentId/sync')
  async sync(
    @Param('studentId', ParseBigIntPipe) studentId: bigint,
    @CurrentUser() user: UserPayload,
    @Query('force') force?: string,
  ) {
    await this.classroomService.assertStudentOwnedByParent(user.sub, studentId);
    try {
      return await this.classroomService.syncStudent(studentId, force === 'true');
    } catch (e: any) {
      const msg: string = e?.response?.data?.error ?? e?.message ?? '';
      if (msg.includes('invalid_grant') || msg.includes('invalid_token')) {
        throw googleTokenExpiredException();
      }
      throw e;
    }
  }

  // ── GET /classroom/student/:studentId/courses ─────────────
  @UseGuards(JwtAuthGuard)
  @Get('student/:studentId/courses')
  async getCourses(@Param('studentId', ParseBigIntPipe) studentId: bigint, @CurrentUser() user: UserPayload) {
    await this.classroomService.assertStudentReadAccess(user, studentId);
    return this.classroomService.getCourses(studentId);
  }

  // ── GET /classroom/student/:studentId/upcoming ────────────
  // Próximas tareas con fecha de entrega (todos los cursos)
  @UseGuards(JwtAuthGuard)
  @Get('student/:studentId/upcoming')
  async getUpcoming(@Param('studentId', ParseBigIntPipe) studentId: bigint, @CurrentUser() user: UserPayload) {
    await this.classroomService.assertStudentReadAccess(user, studentId);
    return this.classroomService.getUpcomingCoursework(studentId);
  }

  // ── GET /classroom/student/:studentId/overview ────────────
  // Vista combinada: connected + sync (con caché) + courses + upcoming
  // en UNA sola respuesta. Reduce de 4 requests HTTP a 1.
  @UseGuards(JwtAuthGuard)
  @Get('student/:studentId/overview')
  async getOverview(@Param('studentId', ParseBigIntPipe) studentId: bigint, @CurrentUser() user: UserPayload) {
    await this.classroomService.assertStudentReadAccess(user, studentId);
    try {
      return await this.classroomService.getOverview(studentId);
    } catch (e: any) {
      const msg: string = e?.response?.data?.error ?? e?.message ?? '';
      if (msg.includes('invalid_grant') || msg.includes('invalid_token')) {
        throw googleTokenExpiredException();
      }
      throw e;
    }
  }

  // ── GET /classroom/student/:studentId/upcoming-status ─────
  // Vista ligera para el card "Esta semana" del home del padre:
  // connected + upcoming en UNA sola petición (sin courses ni sync).
  @UseGuards(JwtAuthGuard)
  @Get('student/:studentId/upcoming-status')
  async getUpcomingStatus(@Param('studentId', ParseBigIntPipe) studentId: bigint, @CurrentUser() user: UserPayload) {
    await this.classroomService.assertStudentReadAccess(user, studentId);
    return this.classroomService.getUpcomingStatus(studentId);
  }
}
