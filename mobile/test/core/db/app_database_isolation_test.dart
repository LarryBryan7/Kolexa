// ============================================================
// app_database_isolation_test.dart — Aislamiento de datos entre cuentas
// ============================================================
// AppDatabase usaba UN SOLO archivo compartido por todas las cuentas que
// alguna vez iniciaron sesión en el dispositivo, sin ninguna columna de
// usuario y sin limpieza al cerrar sesión — un padre/docente distinto que
// iniciara sesión en el mismo dispositivo podía ver, aunque sea por un
// instante, los hilos/mensajes/contactos de la cuenta anterior.
//
// El fix: cada usuario vive en su propio archivo (`kolexa_<userId>.db`),
// abierto/cerrado explícitamente vía openForUser()/close() en reacción al
// AuthState (ver main.dart). Estos tests corren contra SQLite real (no un
// mock) usando sqflite_common_ffi, que implementa el mismo API de sqflite
// sobre el motor SQLite del host — así se prueba el comportamiento real
// de archivos, no una simulación.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kolexa/core/db/app_database.dart';
import 'package:kolexa/features/threads/data/threads_local_store.dart';
import 'package:kolexa/features/threads/data/threads_repository.dart';

// Todos los userId que usan los tests de este archivo — se borran del
// disco antes de CADA test (no solo se cierra la conexión) para que una
// corrida anterior de `flutter test` (los archivos .db quedan en disco
// entre invocaciones, `AppDatabase.close()` nunca los borra a propósito,
// ver comentario en app_database.dart) no contamine esta corrida con
// datos de una ejecución previa.
const _testUserIds = [9001, 9002, 9003, 9004, 9005, 9006, 9007];

Future<void> _wipeTestDatabases() async {
  for (final id in _testUserIds) {
    final path = join(await databaseFactory.getDatabasesPath(), 'kolexa_$id.db');
    try {
      await databaseFactory.deleteDatabase(path);
    } catch (_) {
      // No existía todavía — nada que borrar.
    }
  }
}

Contact _contact(String name) =>
    Contact(userId: '1', name: name, avatar: null, role: 'teacher', students: const []);

ThreadMessage _message(String id, String body) => ThreadMessage(
      id: id,
      senderId: '1',
      senderName: 'X',
      body: body,
      sentAt: DateTime(2026, 1, 1),
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Estado limpio ANTES de cada test: cierra cualquier conexión que haya
  // quedado abierta (necesario para poder borrar el archivo en algunos
  // engines) y borra los archivos de prueba — así cada test parte de cero
  // sin importar qué corrió antes, en esta corrida o en una anterior.
  setUp(() async {
    await AppDatabase.instance.close();
    await _wipeTestDatabases();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  group('aislamiento por archivo entre cuentas', () {
    test('contactos guardados por la cuenta A no aparecen al abrir la cuenta B', () async {
      await AppDatabase.instance.openForUser(9001);
      await ThreadsLocalStore.saveContacts([_contact('Contacto de A')]);

      await AppDatabase.instance.close();
      await AppDatabase.instance.openForUser(9002);

      expect(await ThreadsLocalStore.loadContacts(), isEmpty);
    });

    test('mensajes de un hilo guardados bajo la cuenta A no se filtran a la cuenta B', () async {
      await AppDatabase.instance.openForUser(9001);
      await ThreadsLocalStore.saveThread(
        'thread-1',
        ThreadMessagesPage(
          messages: [_message('m1', 'secreto de A')],
          otherLastReadAt: null,
          otherLastActiveAt: null,
        ),
      );

      await AppDatabase.instance.close();
      await AppDatabase.instance.openForUser(9002);

      // Ni el hilo ni ninguna fila con ese id existen en el archivo de B.
      expect(await ThreadsLocalStore.loadThread('thread-1'), isNull);
    });

    test('la bandeja guardada por la cuenta A no aparece al abrir la cuenta B', () async {
      await AppDatabase.instance.openForUser(9001);
      await ThreadsLocalStore.saveInbox([
        ThreadSummary(
          id: 'thread-a',
          kind: 'direct',
          priority: 'normal',
          lastMessageAt: DateTime(2026, 1, 1),
          unread: true,
          unreadCount: 1,
          muted: false,
        ),
      ]);

      await AppDatabase.instance.close();
      await AppDatabase.instance.openForUser(9002);

      expect(await ThreadsLocalStore.loadInbox(), isEmpty);
    });

    test('la cuenta A conserva sus propios datos intactos al volver a iniciar sesión después de B', () async {
      await AppDatabase.instance.openForUser(9001);
      await ThreadsLocalStore.saveContacts([_contact('Contacto de A')]);
      await AppDatabase.instance.close();

      await AppDatabase.instance.openForUser(9002);
      await ThreadsLocalStore.saveContacts([_contact('Contacto de B')]);
      await AppDatabase.instance.close();

      // A vuelve a iniciar sesión en el mismo dispositivo: debe recuperar
      // EXACTAMENTE lo suyo, ni de más (nada de B) ni de menos (lo propio
      // no se borró al abrir la sesión de B).
      await AppDatabase.instance.openForUser(9001);
      final contactsForA = await ThreadsLocalStore.loadContacts();

      expect(contactsForA.map((c) => c.name), ['Contacto de A']);
    });
  });

  group('database sin sesión activa', () {
    test('lanza StateError si se consulta sin haber llamado a openForUser', () async {
      await expectLater(AppDatabase.instance.database, throwsA(isA<StateError>()));
    });

    test('close() deja a la app sin sesión activa — el próximo acceso vuelve a fallar', () async {
      await AppDatabase.instance.openForUser(9003);
      await AppDatabase.instance.close();

      await expectLater(AppDatabase.instance.database, throwsA(isA<StateError>()));
    });
  });

  group('openForUser — reutilización y condiciones de carrera', () {
    test('llamar dos veces con el mismo userId no reabre la conexión ni pierde datos ya escritos', () async {
      await AppDatabase.instance.openForUser(9004);
      await ThreadsLocalStore.saveContacts([_contact('Persistente')]);

      await AppDatabase.instance.openForUser(9004); // mismo id: debe ser no-op

      final contacts = await ThreadsLocalStore.loadContacts();
      expect(contacts.map((c) => c.name), ['Persistente']);
    });

    test('abrir dos cuentas casi al mismo tiempo deja activa la ÚLTIMA solicitada, nunca ambas', () async {
      // Simula el caso límite: un cambio de cuenta muy rápido (ej. logout
      // seguido de login inmediato) donde una apertura vieja podría
      // resolver después de la nueva.
      final openFirst = AppDatabase.instance.openForUser(9005);
      final openSecond = AppDatabase.instance.openForUser(9006);
      await Future.wait([openFirst, openSecond]);

      final db = await AppDatabase.instance.database;
      expect(db.path, contains('kolexa_9006'));

      // Y la cuenta que "perdió la carrera" no queda con datos mezclados:
      // escribir ahora debe ir al archivo de 9006, no al de 9005.
      await ThreadsLocalStore.saveContacts([_contact('De la cuenta activa')]);
      await AppDatabase.instance.close();
      await AppDatabase.instance.openForUser(9005);
      expect(await ThreadsLocalStore.loadContacts(), isEmpty);
    });

    test('un close() que llega mientras openForUser todavía está abriendo no deja la conexión activa', () async {
      final opening = AppDatabase.instance.openForUser(9007);
      await AppDatabase.instance.close(); // logout casi inmediato
      await opening; // deja que la apertura, si sigue en vuelo, termine

      await expectLater(AppDatabase.instance.database, throwsA(isA<StateError>()));
    });
  });
}
