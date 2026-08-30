// ============================================================
// api_client.dart — Cliente HTTP centralizado con Dio
// ============================================================
// ApiClient es el único punto de comunicación con el backend.
// Todas las peticiones HTTP pasan por aquí.
//
// Equivalente a: Retrofit en Android / Alamofire en iOS
//
// Características:
//   - Base URL configurada en un solo lugar
//   - Timeout global para todas las peticiones
//   - Interceptor de autenticación (agrega el JWT automáticamente)
//   - Interceptor de logging (muestra las peticiones en consola)
//   - Manejo centralizado de errores de red
// ============================================================

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'interceptors/auth_interceptor.dart';

class ApiClient {
  // Release → producción. Debug → IP local WiFi (sin cable USB).
  // Actualizar _devHost si cambia la IP del Mac en la red.
  //
  // En release, por defecto apuntamos a producción. Pero durante el desarrollo
  // podemos forzar el backend local en un build release (AOT = arranque rápido
  // en gama baja) pasando --dart-define=KOLEXA_DEV_HOST=192.168.18.43.
  // Esto permite probar en dispositivos de gama baja (ej. Samsung A10) en modo
  // release (rápido) pero conectados al backend local.
  static const String _devHost = String.fromEnvironment(
    'KOLEXA_DEV_HOST',
    defaultValue: '192.168.18.43',
  );
  // Flag explícito: solo se activa si el desarrollador pasa KOLEXA_DEV_HOST
  // en el build. En producción (sin el flag) siempre usamos api.kolexa.pe.
  //
  // Se compara el String contra vacío en vez de usar bool.fromEnvironment con
  // la misma clave: bool.fromEnvironment solo devuelve true si el valor es
  // literalmente "true", así que pasar --dart-define=KOLEXA_DEV_HOST=10.0.2.2
  // dejaba el flag en false y la app en release se iba a Railway sin avisar,
  // aunque el host de desarrollo estuviera bien configurado.
  static const bool _useDevHost =
      String.fromEnvironment('KOLEXA_DEV_HOST') != '';
  // En debug, permite forzar el backend de producción (Railway) pasando
  // --dart-define=KOLEXA_USE_RAILWAY=true. Útil para probar con hot reload
  // contra Railway sin necesidad de levantar el backend local.
  static const bool _useRailway = bool.fromEnvironment('KOLEXA_USE_RAILWAY');
  static final String _baseUrl = kReleaseMode
      ? (_useDevHost
          ? 'http://$_devHost:3000/api/v1/'
          : 'https://kolexa-production.up.railway.app/api/v1/')
      : (_useRailway
          ? 'https://kolexa-production.up.railway.app/api/v1/'
          : 'http://$_devHost:3000/api/v1/');

  // La instancia de Dio que usamos para hacer peticiones
  late final Dio _dio;

  // Exponemos el Dio para que los datasources puedan usarlo
  Dio get dio => _dio;

  ApiClient() {
    // Opciones base que se aplican a TODAS las peticiones
    final options = BaseOptions(
      baseUrl: _baseUrl,

      // Timeout de conexión: cuánto esperamos para conectar al servidor
      connectTimeout: const Duration(seconds: 10),

      // Timeout de recepción: cuánto esperamos para recibir la respuesta
      receiveTimeout: const Duration(seconds: 30),

      // Headers por defecto en todas las peticiones
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    _dio = Dio(options);

    _dio.interceptors.add(AuthInterceptor());

    // Interceptor de timing: mide la duración de TODOS los requests HTTP.
    // Solo en debug/profile — nunca en producción.
    if (!kReleaseMode) {
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          options.extra['t0'] = DateTime.now().millisecondsSinceEpoch;
          handler.next(options);
        },
        onResponse: (response, handler) {
          final t0 = response.requestOptions.extra['t0'] as int?;
          if (t0 != null) {
            final ms = DateTime.now().millisecondsSinceEpoch - t0;
            print('[HTTP-TIMING] ${response.requestOptions.method} '
                '${response.requestOptions.path} = $ms ms');
          }
          handler.next(response);
        },
        onError: (e, handler) {
          final t0 = e.requestOptions.extra['t0'] as int?;
          if (t0 != null) {
            final ms = DateTime.now().millisecondsSinceEpoch - t0;
            print('[HTTP-TIMING] ${e.requestOptions.method} '
                '${e.requestOptions.path} = $ms ms (error)');
          }
          handler.next(e);
        },
      ));
    }

    // LogInterceptor solo en debug/profile — nunca en producción
    if (!kReleaseMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print('[API] $obj'),
      ));
    }
  }

  // ── Métodos de conveniencia ─────────────────────────────
  // Estos métodos encapsulan el manejo de errores común

  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) async {
    try {
      return await _dio.get(path, queryParameters: queryParams);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> patch(String path, {dynamic data}) async {
    try {
      return await _dio.patch(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Convierte los errores de Dio en excepciones con mensajes claros
  Exception _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Tiempo de espera agotado. Verifica tu conexión a internet.');

      case DioExceptionType.connectionError:
        return Exception('Sin conexión. Verifica tu internet e intenta de nuevo.');

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        final message = (data is Map ? data['message'] : null) ?? 'Error del servidor';
        final messageStr = message is List ? message.join(', ') : message.toString();
        if (statusCode == 401) {
          // Clasificación por `code` estructurado, NUNCA por substring de
          // `message` (hallazgo H-01: message.contains('token') confundía
          // el GOOGLE_TOKEN_EXPIRED de la sync de Classroom —que no tiene
          // nada que ver con la sesión KOLEXA— con una sesión vencida).
          // Cuando el 401 SÍ es de sesión KOLEXA (code SESSION_TOKEN_EXPIRED),
          // el AuthInterceptor ya intentó el refresh antes de que este catch
          // se ejecute — si llegamos aquí es porque el refresh también
          // falló, así que el mensaje sigue siendo el correcto.
          final code = data is Map ? data['code'] as String? : null;
          if (code == 'SESSION_TOKEN_EXPIRED') {
            return Exception('Sesión expirada. Por favor inicia sesión de nuevo.');
          }
          if (code == 'GOOGLE_TOKEN_EXPIRED') {
            return Exception(
              'La conexión con Google Classroom expiró. Vuelve a conectarla desde el colegio.',
            );
          }
          return Exception(messageStr);
        }
        return Exception(messageStr);

      default:
        return Exception('Error inesperado. Intenta de nuevo.');
    }
  }
}
