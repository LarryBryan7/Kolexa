// ============================================================
// roles.decorator.ts — Decorador @Roles()
// ============================================================
// Marca un controlador o endpoint con los roles permitidos.
// Lo usa RolesGuard para verificar que el usuario autenticado
// tenga al menos uno de los roles requeridos.
//
// Uso:
//   @Roles('school_admin')
//   @Controller('admin')
//   export class AdminController { ... }
//
//   @Roles('school_admin', 'teacher')
//   @Get('x')
//   getX() {}
// ============================================================

import { SetMetadata } from '@nestjs/common';

// Clave usada por RolesGuard para leer este metadato
export const ROLES_KEY = 'roles';

// @Roles(...roles) es un alias de @SetMetadata('roles', roles)
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);
