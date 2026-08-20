// ============================================================
// auth_interceptor_test.dart — flujo real de refresh (I-3) + H-01
// ============================================================
// Estos tests NO mockean AuthInterceptor — usan un Dio real con un
// HttpClientAdapter falso (FakeAdapter, definido abajo) que simula el
// backend a nivel de transporte HTTP. Esto ejercita el código de
// producción real: onRequest agrega el header, onError detecta el 401,
// dispara el refresh a través de TokenStore, reintenta la petición
// original con el token nuevo, y decide cuándo forzar logout — nada de
// esto es un mock trivial de "se llamó tal método".
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kolexa/core/api/token_store.dart';
import 'package:kolexa/core/api/interceptors/auth_interceptor.dart';

// Adaptador HTTP falso: intercepta a nivel de transporte, no de Dio. Cada
// test configura `responder` para simular las respuestas del backend según
// el path/headers de la petición. Registra cada request recibida para
// poder aserciones sobre reintentos y sobre cuántas veces se llamó a
// /auth/refresh (deduplicación de refresh concurrente).
class FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  late Future<ResponseBody> Function(RequestOptions options) responder;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}

  int callsTo(String pathFragment) =>
      requests.where((r) => r.path.contains(pathFragment)).length;
}

ResponseBody jsonBody(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      'content-type': ['application/json'],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAdapter adapter;
  late Dio dio;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TokenStore.clear();
    AuthInterceptor.resetSessionExpiredFlag();

    adapter = FakeAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://kolexa.test/api/v1/'))
      ..httpClientAdapter = adapter
      ..interceptors.add(AuthInterceptor(bareDioFactory: () => Dio()..httpClientAdapter = adapter));
  });

  test('2) el interceptor lee exactamente el mismo access token que guardó el login (TokenStore compartido)', () async {
    await TokenStore.save(accessToken: 'login-access-token', refreshToken: 'refresh-1');

    String? seenAuthHeader;
    adapter.responder = (options) async {
      seenAuthHeader = options.headers['Authorization'] as String?;
      return jsonBody(200, {'ok': true});
    };

    final response = await dio.get('protected');

    expect(response.data, {'ok': true});
    expect(seenAuthHeader, 'Bearer login-access-token');
  });

  test('3+4) access token expirado (SESSION_TOKEN_EXPIRED) → refresh → reintenta con el token nuevo → éxito', () async {
    await TokenStore.save(accessToken: 'expired-access', refreshToken: 'valid-refresh');

    adapter.responder = (options) async {
      if (options.path.contains('auth/refresh')) {
        return jsonBody(200, {'accessToken': 'fresh-access'});
      }
      final auth = options.headers['Authorization'];
      if (auth == 'Bearer expired-access') {
        return jsonBody(401, {
          'statusCode': 401,
          'code': 'SESSION_TOKEN_EXPIRED',
          'message': 'Token inválido o expirado.',
        });
      }
      return jsonBody(200, {'data': 'contenido protegido'});
    };

    final response = await dio.get('protected');

    // La request ORIGINAL se reintentó y tuvo éxito — el caller nunca vio
    // el 401 ni tuvo que reaccionar a él.
    expect(response.statusCode, 200);
    expect(response.data, {'data': 'contenido protegido'});
    // El nuevo access token quedó guardado — futuras requests ya no
    // necesitan refrescar de nuevo.
    expect(await TokenStore.readAccessToken(), 'fresh-access');
    expect(adapter.callsTo('auth/refresh'), 1);
  });

  test('5) refresh token inválido/ausente en el backend → logout controlado, sin retry infinito', () async {
    await TokenStore.save(accessToken: 'expired-access', refreshToken: 'revoked-refresh');

    var sessionExpiredCalls = 0;
    AuthInterceptor.onSessionExpired = () => sessionExpiredCalls++;
    addTearDown(() => AuthInterceptor.onSessionExpired = null);

    adapter.responder = (options) async {
      if (options.path.contains('auth/refresh')) {
        return jsonBody(401, {'statusCode': 401, 'message': 'Refresh token inválido o expirado'});
      }
      return jsonBody(401, {
        'statusCode': 401,
        'code': 'SESSION_TOKEN_EXPIRED',
        'message': 'Token inválido o expirado.',
      });
    };

    await expectLater(dio.get('protected'), throwsA(isA<DioException>()));

    expect(sessionExpiredCalls, 1); // logout se dispara UNA vez, no en bucle
    expect(await TokenStore.readAccessToken(), isNull); // la sesión quedó limpia
    expect(await TokenStore.readRefreshToken(), isNull);
  });

  test('6) dos requests con 401 simultáneo disparan UN solo refresh, ambas se reintentan con el token nuevo', () async {
    await TokenStore.save(accessToken: 'expired-access', refreshToken: 'valid-refresh');

    adapter.responder = (options) async {
      if (options.path.contains('auth/refresh')) {
        // Simula latencia real — si hubiera dos refresh concurrentes
        // independientes, el segundo entraría aquí antes de que el
        // primero terminara.
        await Future.delayed(const Duration(milliseconds: 40));
        return jsonBody(200, {'accessToken': 'fresh-access'});
      }
      final auth = options.headers['Authorization'];
      if (auth == 'Bearer expired-access') {
        return jsonBody(401, {'statusCode': 401, 'code': 'SESSION_TOKEN_EXPIRED', 'message': 'x'});
      }
      return jsonBody(200, {'ok': options.path});
    };

    final results = await Future.wait([
      dio.get('protected-a'),
      dio.get('protected-b'),
    ]);

    expect(results[0].statusCode, 200);
    expect(results[1].statusCode, 200);
    expect(adapter.callsTo('auth/refresh'), 1); // NUNCA dos refresh en paralelo
  });

  test('un 401 genérico sin code SESSION_TOKEN_EXPIRED (ej. credenciales inválidas) NO dispara refresh', () async {
    await TokenStore.save(accessToken: 'some-access', refreshToken: 'some-refresh');

    adapter.responder = (options) async {
      return jsonBody(401, {'statusCode': 401, 'message': 'Credenciales incorrectas'});
    };

    await expectLater(dio.post('auth/login'), throwsA(isA<DioException>()));
    expect(adapter.callsTo('auth/refresh'), 0);
  });

  test('H-01 — GOOGLE_TOKEN_EXPIRED (Classroom) NO dispara refresh de sesión ni logout', () async {
    await TokenStore.save(accessToken: 'kolexa-access', refreshToken: 'kolexa-refresh');

    var sessionExpiredCalls = 0;
    AuthInterceptor.onSessionExpired = () => sessionExpiredCalls++;
    addTearDown(() => AuthInterceptor.onSessionExpired = null);

    adapter.responder = (options) async {
      return jsonBody(401, {
        'statusCode': 401,
        'code': 'GOOGLE_TOKEN_EXPIRED',
        'message': 'TOKEN_EXPIRED',
      });
    };

    await expectLater(dio.post('classroom/teacher/sync'), throwsA(isA<DioException>()));

    expect(adapter.callsTo('auth/refresh'), 0);
    expect(sessionExpiredCalls, 0); // sin logout — la sesión KOLEXA sigue viva
    // El access/refresh de KOLEXA no se tocaron para nada.
    expect(await TokenStore.readAccessToken(), 'kolexa-access');
    expect(await TokenStore.readRefreshToken(), 'kolexa-refresh');
  });
}
