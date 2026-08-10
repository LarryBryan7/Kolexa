// ============================================================
// current-user.decorator.ts — Decorador @CurrentUser()
// ============================================================
// Un decorador de parámetro que extrae el usuario autenticado
// del request de Express y lo inyecta directamente en el
// parámetro del método del controlador.
//
// Sin este decorador tendrías que escribir:
//   @Get('profile')
//   getProfile(@Req() request: Request) {
//     const user = request.user; // feo y verbose
//   }
//
// Con este decorador:
//   @Get('profile')
//   getProfile(@CurrentUser() user: UserPayload) { ... }
//
// Mucho más limpio y explícito.
// El usuario viene del JwtStrategy.validate() → JwtAuthGuard
// ============================================================

import { createParamDecorator, ExecutionContext } from '@nestjs/common';

// UserPayload: el objeto que JwtStrategy.validate() devuelve
// y que queda guardado en request.user
export interface UserPayload {
  sub: bigint;     // ID del usuario (sub = "subject" en JWT)
  email: string;
  roles: string[]; // ['teacher', 'parent'] etc.
  schoolId?: bigint;
}

// createParamDecorator crea un decorador personalizado de parámetro.
// El segundo argumento 'ctx' nos da acceso al request HTTP.
export const CurrentUser = createParamDecorator(
  (data: keyof UserPayload | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const user = request.user as UserPayload;

    // Si se pasa una propiedad específica: @CurrentUser('email')
    // devuelve solo esa propiedad en lugar del objeto completo
    return data ? user?.[data] : user;
  },
);
