// ============================================================
// jwt.strategy.ts — Estrategia de validación JWT
// ============================================================
// En NestJS/Passport, una "Strategy" define CÓMO se valida
// la autenticación. Esta estrategia JWT hace lo siguiente:
//
//   1. Extrae el token del header: Authorization: Bearer <token>
//   2. Verifica la firma del token con JWT_SECRET
//   3. Verifica que el token no haya expirado
//   4. Llama a validate() con el payload del token
//   5. Lo que devuelve validate() queda en request.user
//
// Si el token es inválido → Passport lanza 401 automáticamente
// ============================================================

import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../../prisma/prisma.service';
import { UserPayload } from '../../../common/decorators/current-user.decorator';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    private configService: ConfigService,
    private prisma: PrismaService,
  ) {
    super({
      // fromAuthHeaderAsBearerToken() extrae el token del header:
      // Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),

      // ignoreExpiration: false → rechaza tokens expirados (seguridad)
      ignoreExpiration: false,

      // La misma clave secreta usada para firmar el token en AuthService
      secretOrKey: configService.get<string>('JWT_SECRET'),
    });
  }

  // validate() se llama con el PAYLOAD del JWT (datos que pusimos al crear el token).
  // Lo que devuelve este método queda disponible como request.user
  // y puede accederse con el decorador @CurrentUser().
  async validate(payload: any): Promise<UserPayload> {
    // Verificar que el usuario sigue existiendo y está activo.
    // Un usuario podría haber sido desactivado después de obtener el token.
    // Optimización: NO hacemos los joins de userRoles/role porque esos datos ya
    // vienen en el payload del JWT. Esto reduce la consulta a un findFirst simple
    // (más rápido, sobre todo con el pooler de Supabase que agrega ~1.9s por
    // consulta con joins).
    const user = await this.prisma.user.findFirst({
      where: {
        id: BigInt(payload.sub),
        isActive: true,
        deletedAt: null, // no está eliminado
      },
      select: {
        id: true,
        email: true,
      },
    });

    if (!user) {
      throw new UnauthorizedException('Usuario no encontrado o inactivo');
    }

    // schoolId desde el payload del JWT (rápido, sin joins).
    // Los tokens emitidos ANTES de este cambio no traen schoolId en el payload,
    // así que hacemos un fallback con una consulta ligera solo en ese caso.
    let schoolId: bigint | undefined;
    if (payload.schoolId) {
      schoolId = BigInt(payload.schoolId);
    } else {
      const role = await this.prisma.userRole.findFirst({
        where: { userId: user.id },
        select: { schoolId: true },
      });
      schoolId = role?.schoolId ?? undefined;
    }

    // Retornamos el objeto que quedará en request.user.
    // Los roles y schoolId se toman del payload del JWT (ya firmados y válidos),
    // no de la BD, para evitar la consulta con joins en cada request.
    return {
      sub: user.id,
      email: user.email,
      roles: payload.roles ?? [],
      schoolId,
    };
  }
}
