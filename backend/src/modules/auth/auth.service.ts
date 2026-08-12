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
    // 1. Buscar el usuario por email en la BD
    const user = await this.prisma.user.findFirst({
      where: {
        email: dto.email,
        isActive: true,
        deletedAt: null,
      },
      include: {
        userRoles: {
          include: {
            role: true,
            school: true,
          },
        },
        // Cargamos los hijos (si es padre) en la MISMA consulta para
        // evitar un round-trip adicional a la BD (el pooler de Supabase
        // es lento, ~900ms por consulta).
        userStudents: {
          include: {
            student: {
              select: {
                id: true, firstName: true, lastName: true, code: true, birthday: true, avatar: true,
                enrollments: {
                  select: { classroom: { select: { name: true } } },
                  orderBy: { academicYear: 'desc' },
                  take: 1,
                },
              },
            },
          },
          orderBy: { isPrimary: 'desc' },
        },
      },
    });

    // Si el usuario no existe → 401 (no decimos "email no encontrado"
    // por seguridad — no queremos revelar qué emails están registrados)
    if (!user) {
      throw new UnauthorizedException('Credenciales incorrectas');
    }

    // 2. Verificar la contraseña contra el hash guardado en BD
    // bcrypt.compare compara el texto plano con el hash de forma segura
    const isPasswordValid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Credenciales incorrectas');
    }

    // 3. Guardar el token de Firebase para push notifications
    if (dto.firebaseToken) {
      await this.savePushToken(user.id, dto.firebaseToken);
    }

    // 4. Generar los tokens JWT
    const tokens = await this.generateTokens(user);

    // 5. Cargar hijos si es padre de familia (ya vienen en la consulta principal)
    const isParent = user.userRoles.some((ur) => ur.role.name === 'parent');
    let children: {
      id: string; firstName: string; lastName: string; code: string;
      birthday: string | null; section: string | null; avatarUrl: string | null;
    }[] = [];
    if (isParent) {
      children = user.userStudents.map((l) => ({
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
        roles: user.userRoles.map((ur) => ({
          role: ur.role.name,
          schoolId: ur.schoolId?.toString(),
          schoolName: ur.school?.name,
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
    if (existing) throw new ConflictException('Este email ya tiene una cuenta registrada');

    const passwordHash = await bcrypt.hash(dto.password, 10);

    const newUser = await this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
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

    const tokens = await this.generateTokens(userWithRoles!);

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

  // Genera el access token (corta duración) y refresh token (larga duración)
  private async generateTokens(user: any) {
    const roles = user.userRoles.map((ur: any) => ur.role.name);

    // schoolId del primer rol del usuario (mismo comportamiento que la consulta
    // original con joins en JwtStrategy). Se incluye en el payload para que
    // JwtStrategy.validate() NO necesite hacer joins a la BD en cada request
    // (el pooler de Supabase agrega ~1.9s por consulta con joins).
    const schoolId = user.userRoles[0]?.schoolId ?? null;

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
