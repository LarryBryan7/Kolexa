// ============================================================
// roles.guard.ts — Guard de autorización por roles
// ============================================================
// Un Guard en NestJS decide si una petición puede continuar.
// Este guard verifica que el usuario autenticado tenga al menos
// uno de los roles requeridos por el decorador @Roles().
//
// Flujo:
//   Request → JwtAuthGuard (autenticación) → RolesGuard (autorización) → Controller
//
// - Si el endpoint NO tiene @Roles() → se permite (sin restricción de rol).
// - Si el endpoint SÍ tiene @Roles('school_admin') → el usuario debe tener
//   el rol 'school_admin' en request.user.roles.
//
// Se aplica de forma global (APP_GUARD) pero solo actúa cuando hay
// metadatos de roles definidos, por lo que no afecta al resto de la app.
// ============================================================

import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { UserPayload } from '../decorators/current-user.decorator';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    // Leer los roles requeridos del decorador @Roles() (método o clase)
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    // Si no hay roles requeridos, se permite el acceso
    if (!requiredRoles || requiredRoles.length === 0) {
      return true;
    }

    // El usuario autenticado (inyectado por JwtAuthGuard → JwtStrategy.validate())
    const user = context.switchToHttp().getRequest().user as UserPayload;

    // Si no hay usuario o no tiene roles → 403
    if (!user || !Array.isArray(user.roles) || user.roles.length === 0) {
      throw new ForbiddenException('No tienes permisos para acceder a este recurso');
    }

    // Verificar que el usuario tenga al menos uno de los roles requeridos
    const hasRole = requiredRoles.some((role) => user.roles.includes(role));
    if (!hasRole) {
      throw new ForbiddenException('No tienes permisos para acceder a este recurso');
    }

    return true;
  }
}
