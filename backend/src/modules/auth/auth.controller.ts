// ============================================================
// auth.controller.ts — Controlador de autenticación
// ============================================================
// El Controller es la PUERTA DE ENTRADA de las peticiones HTTP.
// Su única responsabilidad es:
//   1. Recibir la petición y extraer los datos (Body, Params, etc.)
//   2. Delegar el trabajo al Service
//   3. Devolver la respuesta HTTP
//
// NO debe contener lógica de negocio — eso va en el Service.
//
// Rutas que expone este controlador (prefijo: /api/v1/auth):
//   POST /auth/login           → iniciar sesión
//   POST /auth/logout          → cerrar sesión
//   POST /auth/change-password → cambiar contraseña
// ============================================================

import {
  Controller,
  Post,
  Body,
  HttpCode,
  HttpStatus,
  BadRequestException,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { RegisterWithTokenDto } from './dto/register.dto';
import { GoogleLoginDto } from './dto/google-login.dto';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';

// @Controller('auth') → todas las rutas tienen el prefijo /auth
// Combinado con el prefijo global /api/v1 → /api/v1/auth/...
@Controller('auth')
export class AuthController {
  // NestJS inyecta AuthService automáticamente (Dependency Injection)
  constructor(private readonly authService: AuthService) {}

  // ── POST /api/v1/auth/login ────────────────────────────
  // @Public() → no requiere JWT (es el endpoint para obtenerlo)
  // @HttpCode(200) → el status por defecto en POST es 201, pero
  //                  login devuelve 200 (no crea un recurso nuevo)
  // Hallazgo IM-4: 5 intentos/min por IP. Es el límite estándar de la
  // industria para login por contraseña (ej. GitHub/AWS Cognito usan
  // rangos similares) — suficiente para que un usuario real que se
  // equivoca 2-3 veces no quede bloqueado, pero corta la fuerza bruta
  // automatizada (miles de intentos/min).
  @Public()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@Body() dto: LoginDto) {
    // @Body() extrae el body del request y lo valida con LoginDto
    // Si la validación falla, ValidationPipe lanza 400 automáticamente
    return this.authService.login(dto);
  }

  // ── POST /api/v1/auth/refresh ──────────────────────────
  // Hallazgo IM-4: 20/min por IP. Más generoso que login/google porque un
  // hogar con varios dispositivos/hijos en la misma red puede refrescar
  // varias sesiones cerca en el tiempo (tokens de ~1h, expiran en
  // ventanas similares) — la deduplicación de refresh concurrente del
  // cliente (TokenStore, Flutter) ya evita ráfagas artificiales del mismo
  // dispositivo; este límite es una defensa adicional, no la primera línea.
  @Public()
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Body('refreshToken') refreshToken: string) {
    if (!refreshToken) throw new BadRequestException('refreshToken requerido');
    return this.authService.refresh(refreshToken);
  }

  // ── POST /api/v1/auth/register ────────────────────────
  // Registro con token de invitación — no requiere JWT
  @Public()
  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  register(@Body() dto: RegisterWithTokenDto) {
    return this.authService.registerWithToken(dto);
  }

  // ── POST /api/v1/auth/google ───────────────────────────
  // Login/registro con Google Sign-In (Fase 1).
  // Recibe ÚNICAMENTE el ID Token de Google; el backend lo valida
  // criptográficamente y crea/asigna el rol parent si es una cuenta nueva.
  // Hallazgo IM-4: 10/min por IP. Más generoso que login (5) porque la
  // verificación criptográfica del ID Token de Google hace la fuerza
  // bruta directa inviable (necesitaría tokens firmados por Google) — el
  // límite aquí es sobre todo defensa contra DoS/costo (cada intento
  // dispara una verificación contra la API de Google) y contra tanteo del
  // flujo de invitación (INVITATION_REQUIRED/EMAIL_MISMATCH).
  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('google')
  @HttpCode(HttpStatus.OK)
  googleLogin(@Body() dto: GoogleLoginDto) {
    return this.authService.loginWithGoogle(dto);
  }

  // ── POST /api/v1/auth/logout ───────────────────────────
  // refreshToken (hallazgo IM-1): si el cliente lo envía, se revoca
  // ESPECÍFICAMENTE esa sesión (no las de otros dispositivos). Si no lo
  // envía, se revocan todos los refresh tokens del usuario — más seguro
  // que no revocar nada, que era el comportamiento anterior.
  @Post('logout')
  @HttpCode(HttpStatus.OK)
  logout(
    @CurrentUser() user: UserPayload,
    @Body('firebaseToken') firebaseToken?: string,
    @Body('refreshToken') refreshToken?: string,
  ) {
    return this.authService.logout(BigInt(user.sub), firebaseToken, refreshToken);
  }

  // ── POST /api/v1/auth/change-password ─────────────────
  @Post('change-password')
  @HttpCode(HttpStatus.OK)
  changePassword(
    @CurrentUser() user: UserPayload,
    @Body() dto: ChangePasswordDto,
  ) {
    return this.authService.changePassword(user.sub, dto);
  }
}
