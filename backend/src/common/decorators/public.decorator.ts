// ============================================================
// public.decorator.ts — Decorador @Public()
// ============================================================
// Marca un endpoint como público (sin autenticación requerida).
// Lo usa JwtAuthGuard para saber si debe omitir la verificación
// del token JWT.
//
// Uso:
//   @Public()
//   @Post('login')         ← no requiere JWT
//   login(@Body() dto) {}
//
//   @Get('profile')        ← sí requiere JWT (por defecto)
//   getProfile() {}
// ============================================================

import { SetMetadata } from '@nestjs/common';

// Clave usada por JwtAuthGuard para leer este metadato
export const IS_PUBLIC_KEY = 'isPublic';

// @Public() es un alias de @SetMetadata('isPublic', true)
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
