// ============================================================
// auth.module.ts — Módulo de autenticación
// ============================================================
// Este módulo agrupa todo lo relacionado con autenticación:
//   - AuthController: maneja las rutas HTTP
//   - AuthService: contiene la lógica de negocio
//   - JwtStrategy: valida los tokens JWT en cada petición
//   - JwtModule: firma y verifica los tokens JWT
//   - PassportModule: framework de autenticación base
//
// Al importar JwtAuthGuard globalmente en app.module.ts,
// TODAS las rutas requieren JWT por defecto. Solo las
// marcadas con @Public() son accesibles sin token.
// ============================================================

import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@Module({
  imports: [
    // PassportModule: habilita el sistema de estrategias de Passport
    // defaultStrategy: 'jwt' → usa JWT por defecto en todos los guards
    PassportModule.register({ defaultStrategy: 'jwt' }),

    // JwtModule: configura la firma y verificación de tokens JWT
    // Usamos registerAsync para leer JWT_SECRET del .env de forma segura
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        // La clave secreta con la que firmamos y verificamos tokens
        secret: configService.get<string>('JWT_SECRET'),
        signOptions: {
          expiresIn: configService.get<string>('JWT_EXPIRES_IN') ?? '1h',
        },
      }),
    }),
  ],

  controllers: [AuthController],

  providers: [
    AuthService,

    // JwtStrategy: define cómo extraer y validar el JWT de cada petición
    JwtStrategy,

    // APP_GUARD con JwtAuthGuard → aplica el guard a TODA la aplicación.
    // Todas las rutas requieren JWT excepto las marcadas con @Public().
    // Esto es más seguro que recordar agregar @UseGuards() en cada endpoint.
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
  ],

  // Exportamos JwtModule y PassportModule para que otros módulos
  // puedan usar JwtService si necesitan generar tokens
  exports: [JwtModule, PassportModule],
})
export class AuthModule {}
