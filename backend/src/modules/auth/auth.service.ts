// ============================================================
// auth.service.ts — Lógica de negocio de autenticación
// ============================================================
// El Service contiene TODA la lógica de negocio. El Controller
// solo recibe la petición HTTP y delega al Service.
// Esta separación permite:
//   - Testear la lógica sin levantar el servidor HTTP
//   - Reutilizar la lógica desde otros servicios
//
// Responsabilidades de AuthService:
//   - login: verificar email/password y generar JWT
//   - refreshToken: renovar el access token con el refresh token
//   - changePassword: cambiar contraseña con validación
//   - forgotPassword: enviar email de recuperación
//   - logout: invalidar el token de Firebase (push notifications)
// ============================================================

import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { RegisterWithTokenDto } from './dto/register.dto';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private configService: ConfigService,
  ) {}

  // ── LOGIN ──────────────────────────────────────────────
  // Verifica credenciales y devuelve accessToken + refreshToken
  async login(dto: LoginDto) {
    // 1. Buscar el usuario por email en la BD (solo campos directos, sin joins)
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
      select: {
        id: true, email: true, passwordHash: true, firstName: true, lastName: true,
        avatar: true, needsPasswordChange: true, isActive: true, deletedAt: true,
      },
    });

    // Si el usuario no existe, está inactivo o eliminado → 401
    // (no decimos "email no encontrado" por seguridad — no queremos
    // revelar qué emails están registrados)
    if (!user || !user.isActive || user.deletedAt) {
      throw new UnauthorizedException('Credenciales incorrectas');
    }

    // 2. Verificar la contraseña + cargar roles/school y students/enrollments
    //    EN PARALELO (A1 + A2). bcrypt es CPU local; las dos ramas de BD son
    //    independientes entre sí y aprovechan connection_limit=5.
    const [isPasswordValid, rolesData, studentsData] = await Promise.all([
      bcrypt.compare(dto.password, user.passwordHash),
      this._loadRolesForLogin(user.id),
      this._loadStudentsForLogin(user.id),
    ]);

    if (!isPasswordValid) {
      throw new UnauthorizedException('Credenciales incorrectas');
    }

    // 3+4. Guardar el token de Firebase (push) y generar los tokens JWT EN PARALELO.
    // savePushToken NO es crítico para la respuesta del login: corre en paralelo
    // con generateTokens (que persiste el refresh token en BD y SÍ es awaited).
    // Cualquier error de savePushToken se captura y registra sin romper el login.
    const roles = rolesData
      .map((r) => r.roleName)
      .filter((n): n is string => n !== null && n !== undefined);
    const schoolId = rolesData[0]?.schoolId ?? null;

    const [tokens] = await Promise.all([
      this.generateTokens(user, roles, schoolId),
      (async () => {
        if (dto.firebaseToken) {
          try {
            await this.savePushToken(user.id, dto.firebaseToken);
          } catch (err) {
            // savePushToken no debe bloquear ni romper el login.
            console.error('[AUTH-LOGIN] Error al guardar push token:', err);
          }
        }
      })(),
    ]);

    // 5. Cargar hijos si es padre de familia
    const isParent = rolesData.some((r) => r.roleName === 'parent');
    let children: {
      id: string; firstName: string; lastName: string; code: string;
      birthday: string | null; section: string | null; avatarUrl: string | null;
    }[] = [];
    if (isParent) {
      children = studentsData.map((l) => ({
        id: l.student.id.toString(),
        firstName: l.student.firstName,
        lastName: l.student.lastName,
        code: l.student.code ?? '',
        birthday: l.student.birthday ? l.student.birthday.toISOString().split('T')[0] : null,
        section: l.student.enrollments[0]?.classroom?.name ?? null,
        avatarUrl: l.student.avatar ?? null,
      }));
    }

    // 6. Devolver los tokens y la información del usuario
    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      needsPasswordChange: user.needsPasswordChange,
      user: {
        id: user.id.toString(), // BigInt no se serializa en JSON → convertir a string
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        avatar: user.avatar,
        roles: rolesData.map((ur) => ({
          role: ur.roleName,
          schoolId: ur.schoolId?.toString(),
          schoolName: ur.schoolName,
        })),
        children,
      },
    };
  }

  // ── CAMBIO DE CONTRASEÑA ───────────────────────────────
  async changePassword(userId: bigint, dto: ChangePasswordDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) throw new NotFoundException('Usuario no encontrado');

    // Verificar que la contraseña actual es correcta
    const isValid = await bcrypt.compare(dto.currentPassword, user.passwordHash);
    if (!isValid) {
      throw new BadRequestException('La contraseña actual es incorrecta');
    }

    // Hashear la nueva contraseña (10 rondas de salt = balance seguridad/velocidad)
    const newHash = await bcrypt.hash(dto.newPassword, 10);

    // Actualizar la contraseña y marcar que ya no necesita cambiarla
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        passwordHash: newHash,
        needsPasswordChange: false,
      },
    });

    return { message: 'Contraseña actualizada correctamente' };
  }

  // ── LOGOUT ─────────────────────────────────────────────
  async logout(userId: bigint, firebaseToken?: string) {
    if (firebaseToken) {
      await this.prisma.pushToken.deleteMany({ where: { userId, token: firebaseToken } });
    }
    return { message: 'Sesión cerrada correctamente' };
  }

  // ── REGISTRO CON TOKEN DE INVITACIÓN ──────────────────
  async registerWithToken(dto: RegisterWithTokenDto) {
    const inv = await this.prisma.schoolInvitation.findUnique({
      where: { token: dto.token },
      include: { school: true, role: true },
    });

    if (!inv) throw new NotFoundException('Invitación no encontrada');
    if (inv.usedAt) throw new ConflictException('Esta invitación ya fue utilizada');
    if (inv.expiresAt < new Date()) throw new BadRequestException('Esta invitación ha expirado');

    const existing = await this.prisma.user.findFirst({
      where: { email: inv.email, deletedAt: null },
    });

    // Un usuario ya activado (con contraseña real) NUNCA puede ser sobrescrito
    // por este flujo. Solo se permite activar cuentas pendientes (passwordHash
    // vacío, creadas por importación masiva) o crear una cuenta nueva.
    if (existing && existing.passwordHash) {
      throw new ConflictException('Este email ya tiene una cuenta registrada');
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);

    const newUser = await this.prisma.$transaction(async (tx) => {
      let user;
      if (existing) {
        // Cuenta pendiente de activación (creada por importación masiva con
        // passwordHash vacío). Se establece la contraseña y se activa la cuenta.
        // El UserRole ya fue creado por la importación; no se duplica.
        user = await tx.user.update({
          where: { id: existing.id },
          data: {
            passwordHash,
            firstName: dto.firstName,
            lastName: dto.lastName,
            needsPasswordChange: false,
            isActive: true,
          },
        });
      } else {
        // Cuenta nueva: se crea el usuario y su rol.
        user = await tx.user.create({
          data: {
            email: inv.email,
            passwordHash,
            firstName: dto.firstName,
            lastName: dto.lastName,
            isActive: true,
          },
        });

        await tx.userRole.create({
          data: { userId: user.id, roleId: inv.roleId, schoolId: inv.schoolId },
        });
      }

      await tx.schoolInvitation.update({
        where: { id: inv.id },
        data: { usedAt: new Date() },
      });

      return user;
    });

    const userWithRoles = await this.prisma.user.findUnique({
      where: { id: newUser.id },
      include: { userRoles: { include: { role: true, school: true } } },
    });

    if (dto.firebaseToken) {
      await this.savePushToken(newUser.id, dto.firebaseToken);
    }

    const roles = userWithRoles!.userRoles.map((ur) => ur.role.name);
    const schoolId = userWithRoles!.userRoles[0]?.schoolId ?? null;
    const tokens = await this.generateTokens(userWithRoles!, roles, schoolId);

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      needsPasswordChange: false,
      user: {
        id: newUser.id.toString(),
        email: newUser.email,
        firstName: newUser.firstName,
        lastName: newUser.lastName,
        avatar: null,
        roles: userWithRoles!.userRoles.map((ur) => ({
          role: ur.role.name,
          schoolId: ur.schoolId?.toString(),
          schoolName: ur.school?.name,
        })),
        children: [],
      },
    };
  }

  async refresh(refreshToken: string) {
    // Verificar que el refresh token sea un JWT válido
    let payload: any;
    try {
      payload = this.jwtService.verify(refreshToken, {
        secret: this.configService.get('JWT_REFRESH_SECRET') ?? this.configService.get('JWT_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Refresh token inválido o expirado');
    }

    // Verificar que no haya sido revocado (logout)
    const stored = await this.prisma.userToken.findFirst({
      where: { token: refreshToken, tokenType: 'refresh' },
    });
    if (!stored) throw new UnauthorizedException('Sesión cerrada. Inicia sesión nuevamente');

    // Generar nuevo access token
    // Se propaga el schoolId del refresh token (si existe) para que el access
    // token renovado no necesite la consulta con joins en JwtStrategy.
    const newAccessToken = this.jwtService.sign(
      {
        sub: payload.sub,
        email: payload.email,
        roles: payload.roles,
        schoolId: payload.schoolId,
      },
      { expiresIn: this.configService.get('JWT_EXPIRES_IN') ?? '7d' },
    );

    return { accessToken: newAccessToken };
  }

  // ── HELPERS PRIVADOS ───────────────────────────────────

  // Carga roles + school del usuario en paralelo (A1 + A2).
  // A1: separa la rama roles de la rama students (corren en Promise.all).
  // A2: dentro de la rama roles, paraleliza roles y schools.
  private async _loadRolesForLogin(userId: bigint) {
    // 1 query: user_roles (solo los IDs necesarios)
    const userRoles = await this.prisma.userRole.findMany({
      where: { userId },
      select: { roleId: true, schoolId: true },
    });

    const roleIds = [...new Set(userRoles.map((r) => r.roleId))];
    const schoolIds = [
      ...new Set(userRoles.map((r) => r.schoolId).filter((s): s is bigint => s !== null)),
    ];

    // A2: roles y schools en paralelo (independientes entre sí)
    const [roles, schools] = await Promise.all([
      this.prisma.role.findMany({ where: { id: { in: roleIds } } }),
      schoolIds.length > 0
        ? this.prisma.school.findMany({ where: { id: { in: schoolIds } } })
        : Promise.resolve([]),
    ]);

    const roleMap = new Map(roles.map((r) => [r.id, r.name]));
    const schoolMap = new Map(schools.map((s) => [s.id, s.name]));

    return userRoles.map((ur) => ({
      roleId: ur.roleId,
      schoolId: ur.schoolId,
      // El role siempre existe (dato de referencia); se asume igual que el
      // findFirst original que accedía a ur.role.name directamente.
      roleName: roleMap.get(ur.roleId)!,
      schoolName: ur.schoolId !== null ? schoolMap.get(ur.schoolId) ?? null : null,
    }));
  }

  // Carga students + enrollments + classroom del usuario (A1).
  // Corre en paralelo con la rama roles.
  // Alternativa C: se paralelizan las queries que son independientes entre sí
  // (aprovechan connection_limit=5):
  //   - Fase 1: user_students (depende solo de userId).
  //   - Fase 2: students y enrollments en paralelo (ambas dependen de studentIds).
  //   - Fase 3: classrooms (depende de los classroomIds de enrollments).
  // El resultado reconstruido es idéntico al include original.
  private async _loadStudentsForLogin(userId: bigint) {
    // Fase 1: user_students (ordenados por isPrimary desc, igual que el include original)
    const userStudents = await this.prisma.userStudent.findMany({
      where: { userId },
      orderBy: { isPrimary: 'desc' },
      select: { studentId: true },
    });

    const studentIds = userStudents.map((us) => us.studentId);

    // Fase 2 (paralela): students (campos directos) y student_enrollments (todos,
    // ordenados por academicYear desc para tomar el más reciente).
    const [students, enrollments] = await Promise.all([
      this.prisma.student.findMany({
        where: { id: { in: studentIds } },
        select: {
          id: true, firstName: true, lastName: true, code: true, birthday: true, avatar: true,
        },
      }),
      this.prisma.studentEnrollment.findMany({
        where: { studentId: { in: studentIds } },
        orderBy: { academicYear: 'desc' },
        select: { studentId: true, classroomId: true },
      }),
    ]);

    // Fase 3: classrooms (depende de los classroomIds de enrollments).
    const classroomIds = [...new Set(enrollments.map((e) => e.classroomId))];
    const classrooms = classroomIds.length > 0
      ? await this.prisma.classroom.findMany({
          where: { id: { in: classroomIds } },
          select: { id: true, name: true },
        })
      : [];

    // Reconstruir la estructura equivalente al include original:
    // userStudents[].student.{...campos, enrollments:[{classroom:{name}}]}
    const studentMap = new Map(students.map((s) => [s.id, s]));
    const classroomNameMap = new Map(classrooms.map((c) => [c.id, c.name]));
    // Primer enrollment por student (el más reciente, por el orderBy desc)
    const enrollmentByStudent = new Map<bigint, { classroomId: bigint }>();
    for (const e of enrollments) {
      if (!enrollmentByStudent.has(e.studentId)) {
        enrollmentByStudent.set(e.studentId, { classroomId: e.classroomId });
      }
    }

    return userStudents.map((us) => {
      const student = studentMap.get(us.studentId)!;
      const enrollment = enrollmentByStudent.get(us.studentId);
      return {
        student: {
          id: student.id,
          firstName: student.firstName,
          lastName: student.lastName,
          code: student.code,
          birthday: student.birthday,
          avatar: student.avatar,
          enrollments: enrollment
            ? [{ classroom: { name: classroomNameMap.get(enrollment.classroomId) ?? null } }]
            : [],
        },
      };
    });
  }

  // Genera el access token (corta duración) y refresh token (larga duración)
  private async generateTokens(
    user: { id: bigint; email: string },
    roles: string[],
    schoolId: bigint | null,
  ) {
    // schoolId del primer rol del usuario (mismo comportamiento que la consulta
    // original con joins en JwtStrategy). Se incluye en el payload para que
    // JwtStrategy.validate() NO necesite hacer joins a la BD en cada request
    // (el pooler de Supabase agrega ~1.9s por consulta con joins).

    // Payload del JWT: datos que viajan dentro del token
    // NO incluir datos sensibles (contraseña, etc.)
    const payload = {
      sub: user.id.toString(), // "subject" = identificador del usuario
      email: user.email,
      roles,
      schoolId: schoolId ? schoolId.toString() : undefined,
    };

    // Access token: vida corta (1 hora), se usa en cada petición
    const accessToken = this.jwtService.sign(payload, {
      expiresIn: this.configService.get('JWT_EXPIRES_IN') ?? '1h',
    });

    // Refresh token: vida larga (7 días), solo se usa para obtener
    // un nuevo access token cuando el anterior expira.
    // Se firma con JWT_REFRESH_SECRET (secreto separado del access token)
    // para que la verificación en refresh() sea consistente.
    const refreshToken = this.jwtService.sign(payload, {
      secret: this.configService.get('JWT_REFRESH_SECRET') ?? this.configService.get('JWT_SECRET'),
      expiresIn: this.configService.get('JWT_REFRESH_EXPIRES_IN') ?? '7d',
    });

    // Guardar el refresh token en BD para poder invalidarlo en logout
    await this.prisma.userToken.create({
      data: {
        userId: user.id,
        tokenType: 'refresh',
        token: refreshToken,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 días
      },
    });

    return { accessToken, refreshToken };
  }

  private async savePushToken(userId: bigint, token: string) {
    await this.prisma.pushToken.upsert({
      where: { token },
      create: { userId, token, platform: 'android' },
      // Si el mismo dispositivo hace login con otra cuenta, lo reasignamos
      update: { userId },
    });
  }
}
