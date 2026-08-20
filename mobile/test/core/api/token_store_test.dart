// ============================================================
// token_store_test.dart — TokenStore como única fuente de verdad (I-3)
// ============================================================
// Antes del fix, AuthInterceptor (FlutterSecureStorage) y AuthRepository
// (SharedPreferences) mantenían cada uno su propia copia de los mismos
// tokens con las mismas claves — el refreshToken nunca llegaba al almacén
// que el interceptor leía, así que el refresh siempre fallaba. Estos tests
// prueban TokenStore de forma aislada: guardado, lectura, actualización
// parcial (solo access token, tras un refresh), limpieza y deduplicación
// de refresh concurrente.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kolexa/core/api/token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TokenStore.clear();
  });

  group('save / read', () {
    test('1) login guarda accessToken + refreshToken, ambos legibles después', () async {
      await TokenStore.save(accessToken: 'access-1', refreshToken: 'refresh-1');

      expect(await TokenStore.readAccessToken(), 'access-1');
      expect(await TokenStore.readRefreshToken(), 'refresh-1');
    });

    test('los tokens persisten más allá de la cache en memoria (proceso frío)', () async {
      await TokenStore.save(accessToken: 'access-1', refreshToken: 'refresh-1');

      // Simula un arranque en frío: SharedPreferences.getInstance() sigue
      // devolviendo el mismo almacén (no se limpia), pero forzamos una
      // lectura como si la cache en memoria nunca se hubiera llenado en
      // este proceso, releyendo directo desde SharedPreferences.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), 'access-1');
      expect(prefs.getString('refresh_token'), 'refresh-1');
    });
  });

  group('refresh', () {
    test('3) refreshAccessToken actualiza SOLO el access token, conserva el refresh token', () async {
      await TokenStore.save(accessToken: 'old-access', refreshToken: 'refresh-1');

      final result = await TokenStore.refreshAccessToken((refreshToken) async {
        expect(refreshToken, 'refresh-1');
        return 'new-access';
      });

      expect(result, 'new-access');
      expect(await TokenStore.readAccessToken(), 'new-access');
      expect(await TokenStore.readRefreshToken(), 'refresh-1'); // sin cambios
    });

    test('5) refresh fallido (doRefresh devuelve null) no actualiza nada, deja la sesión intacta para el logout controlado', () async {
      await TokenStore.save(accessToken: 'old-access', refreshToken: 'refresh-1');

      final result = await TokenStore.refreshAccessToken((_) async => null);

      expect(result, isNull);
      // El caller (AuthInterceptor) es quien decide limpiar tras un null —
      // TokenStore por sí mismo no borra nada solo por un refresh fallido.
      expect(await TokenStore.readAccessToken(), 'old-access');
    });

    test('6) dos refresh "simultáneos" comparten el mismo resultado — doRefresh se invoca UNA sola vez', () async {
      await TokenStore.save(accessToken: 'old-access', refreshToken: 'refresh-1');

      var callCount = 0;
      Future<String?> doRefresh(String refreshToken) async {
        callCount++;
        // Simula latencia real de red — si hubiera dos llamadas concurrentes
        // independientes, ambas entrarían aquí antes de que ninguna termine.
        await Future.delayed(const Duration(milliseconds: 30));
        return 'new-access-$callCount';
      }

      final futureA = TokenStore.refreshAccessToken(doRefresh);
      final futureB = TokenStore.refreshAccessToken(doRefresh);

      final results = await Future.wait([futureA, futureB]);

      expect(callCount, 1); // doRefresh NUNCA se llamó dos veces
      expect(results[0], results[1]); // ambas llamadas ven el MISMO resultado
      expect(await TokenStore.readAccessToken(), results[0]);
    });

    test('tras completar un refresh, uno nuevo posterior sí puede volver a invocar doRefresh (no queda bloqueado para siempre)', () async {
      await TokenStore.save(accessToken: 'old-access', refreshToken: 'refresh-1');

      var callCount = 0;
      Future<String?> doRefresh(String _) async {
        callCount++;
        return 'access-$callCount';
      }

      await TokenStore.refreshAccessToken(doRefresh);
      await TokenStore.refreshAccessToken(doRefresh);

      expect(callCount, 2);
    });

    test('8) refreshAccessToken no requiere ni pasa un invitationToken en ningún punto', () async {
      await TokenStore.save(accessToken: 'old-access', refreshToken: 'refresh-1');

      // La firma de doRefresh solo recibe el refreshToken — no hay forma de
      // que el invitationToken participe en este flujo, ni de que el
      // padre/docente tenga que volver a introducirlo tras un refresh.
      final result = await TokenStore.refreshAccessToken((refreshToken) async {
        expect(refreshToken, isNot(contains('invitation')));
        return 'new-access';
      });

      expect(result, 'new-access');
    });

    test('sin refreshToken guardado, refreshAccessToken devuelve null sin invocar doRefresh', () async {
      // Nunca hubo login en este proceso — TokenStore.clear() ya corrió en setUp.
      var called = false;
      final result = await TokenStore.refreshAccessToken((_) async {
        called = true;
        return 'x';
      });

      expect(result, isNull);
      expect(called, isFalse);
    });
  });

  group('clear (logout)', () {
    test('7) clear() elimina accessToken Y refreshToken, tanto de memoria como del almacén persistente', () async {
      await TokenStore.save(accessToken: 'access-1', refreshToken: 'refresh-1');

      await TokenStore.clear();

      expect(await TokenStore.readAccessToken(), isNull);
      expect(await TokenStore.readRefreshToken(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
      expect(prefs.getString('refresh_token'), isNull);
    });

    test('hasAccessToken() refleja el estado real de la sesión', () async {
      expect(await TokenStore.hasAccessToken(), isFalse);
      await TokenStore.save(accessToken: 'access-1', refreshToken: 'refresh-1');
      expect(await TokenStore.hasAccessToken(), isTrue);
      await TokenStore.clear();
      expect(await TokenStore.hasAccessToken(), isFalse);
    });
  });
}
