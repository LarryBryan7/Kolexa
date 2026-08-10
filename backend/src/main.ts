// ============================================================
// main.ts — Punto de entrada del servidor NestJS
// ============================================================
// Este es el primer archivo que se ejecuta cuando arranca el
// servidor. Aquí configuramos:
//   1. La app NestJS con sus middlewares globales
//   2. La validación automática de datos entrantes
//   3. El prefijo global de la API (/api/v1/...)
//   4. El puerto en el que escucha el servidor
// ============================================================

import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { ValidationPipe } from '@nestjs/common';
import { join } from 'path';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';

// BigInt no es serializable por JSON.stringify por defecto.
// Prisma devuelve BigInt para todas las columnas BIGINT de PostgreSQL.
// Este patch global convierte BigInt a String antes de serializar,
// así todos los endpoints devuelven JSON válido sin cambios adicionales.
(BigInt.prototype as unknown as { toJSON: () => string }).toJSON = function () {
  return this.toString();
};

async function bootstrap() {
  // Crea la aplicación NestJS usando el módulo raíz (AppModule)
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Sirve archivos subidos desde la carpeta uploads/ en la ruta /uploads/
  app.useStaticAssets(join(process.cwd(), 'uploads'), { prefix: '/uploads' });

  // ── Prefijo global ──────────────────────────────────────
  // Todas las rutas tendrán el prefijo /api/v1/
  // Ejemplo: /api/v1/auth/login, /api/v1/attendance
  app.setGlobalPrefix('api/v1');

  // ── Validación global ───────────────────────────────────
  // ValidationPipe revisa automáticamente todos los datos
  // que llegan al servidor (body, params, query).
  // Si los datos no cumplen las reglas del DTO, rechaza la
  // petición con un error 400 antes de entrar al controlador.
  app.useGlobalPipes(
    new ValidationPipe({
      // whitelist: true → elimina campos que no están en el DTO
      // Evita que lleguen campos maliciosos al backend
      whitelist: true,

      // forbidNonWhitelisted: true → lanza error si llegan
      // campos que no están en el DTO (más estricto que whitelist)
      forbidNonWhitelisted: true,

      // transform: true → convierte automáticamente los tipos.
      // Por ejemplo, si el DTO espera un número y llega un string
      // "123", lo convierte a número 123.
      transform: true,
    }),
  );

  // ── Filtro global de excepciones ────────────────────────
  // Captura TODOS los errores del servidor y los convierte
  // en respuestas JSON consistentes con el formato de Kolexa.
  // Sin esto, NestJS devuelve errores con formatos variables.
  app.useGlobalFilters(new HttpExceptionFilter());

  // ── CORS ────────────────────────────────────────────────
  // En producción se leen los dominios de CORS_ORIGINS en .env
  // (ej: "https://kolexa.pe,https://admin.kolexa.pe").
  // En desarrollo se permite cualquier origen.
  const corsOrigin = process.env.NODE_ENV === 'production'
    ? (process.env.CORS_ORIGINS ?? 'https://kolexa.pe').split(',').map(s => s.trim())
    : '*';

  app.enableCors({
    origin: corsOrigin,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });

  // Lee el puerto del archivo .env, o usa 3000 por defecto
  const port = process.env.PORT ?? 3000;

  // Inicia el servidor y comienza a escuchar peticiones
  await app.listen(port);

  console.log(`🚀 Kolexa Backend corriendo en: http://localhost:${port}/api/v1`);
}

// Ejecuta la función bootstrap para arrancar el servidor
bootstrap();
