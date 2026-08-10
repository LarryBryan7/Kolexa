// ============================================================
// http-exception.filter.ts — Filtro global de errores HTTP
// ============================================================
// Sin este filtro, cuando ocurre un error en el servidor,
// NestJS devuelve respuestas con formatos inconsistentes.
// Este filtro CAPTURA todos los errores y los convierte
// en un formato JSON uniforme para toda la API de Kolexa:
//
// {
//   "success": false,
//   "statusCode": 400,
//   "message": "El email ya está registrado",
//   "timestamp": "2025-01-15T10:30:00.000Z",
//   "path": "/api/v1/auth/login"
// }
//
// Se registra en main.ts con: app.useGlobalFilters(...)
// ============================================================

import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

// @Catch() sin argumentos captura TODOS los errores,
// tanto HttpException como errores inesperados de Node.js
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    // ArgumentsHost nos da acceso al contexto HTTP (request, response)
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    // Determinar el código de estado HTTP
    // Si es un HttpException de NestJS → usamos su código
    // Si es otro error (TypeError, etc.) → 500 Internal Server Error
    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    // Extraer el mensaje de error
    let message: string | string[];
    if (exception instanceof HttpException) {
      const exceptionResponse = exception.getResponse();
      // NestJS puede devolver { message: string[] } (validación)
      // o simplemente { message: string }
      if (typeof exceptionResponse === 'object' && exceptionResponse !== null) {
        message = (exceptionResponse as any).message ?? exception.message;
      } else {
        message = exception.message;
      }
    } else if (exception instanceof Error) {
      message = exception.message;
      // Loggear errores inesperados con el stack trace completo
      this.logger.error(`Error inesperado: ${exception.message}`, exception.stack);
    } else {
      message = 'Error interno del servidor';
    }

    // Construir la respuesta JSON uniforme
    response.status(status).json({
      success: false,
      statusCode: status,
      message,
      timestamp: new Date().toISOString(),
      path: request.url,
    });
  }
}
