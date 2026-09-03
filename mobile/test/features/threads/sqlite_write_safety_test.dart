// ============================================================
// sqlite_write_safety_test.dart — Fase 2: errores de SQLite (B2) +
// confirmación de que la deduplicación por id no se rompió
// ============================================================
// B2: las 5 escrituras SQLite fire-and-forget (InboxPage._refresh,
// InboxPage._openThread, ThreadPage._load, ThreadPage._sendBody,
// NewMessagePage._refresh) ahora capturan su error con `.catchError` y lo
// registran vía `debugPrint` — antes quedaban como errores no manejados,
// silenciosos, sin log.
//
// Este archivo prueba el MECANISMO (el patrón `.catchError((e, st) {
// debugPrint(...); })` aplicado a un Future de ThreadsLocalStore que
// genuinamente falla) directamente, sin widgets: mounting InboxPage en un
// testWidgets choca con un hueco preexistente del proyecto (Firebase no
// está mockeado — el mismo motivo por el que test/widget_test.dart ya
// fallaba antes de esta sesión), y `_refresh()`/`_load()` son métodos
// privados de las pantallas, no invocables desde afuera de todos modos.
//
// Que los 5 sitios reales usan exactamente este patrón se verifica por
// inspección del diff (cada uno envuelve su llamada a
// ThreadsLocalStore.saveX con el mismo `.catchError`) — lo que este
// archivo demuestra en runtime es que el patrón en sí funciona: contiene
// una excepción real (no un mock) y la deja registrada, en vez de
// convertirse en un error no manejado.
//
// Para forzar un error real de escritura sin corromper SQLite a mano, se
// deja la sesión CERRADA (sin `openForUser`): ThreadsLocalStore.saveX()
// internamente llama a AppDatabase.instance.database, que lanza
// StateError si no hay sesión activa — el mismo tipo de excepción real
// que protege el aislamiento entre cuentas (ver
// app_database_isolation_test.dart), acá usado como gatillo
// determinístico para una escritura que sí falla.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kolexa/core/db/app_database.dart';
import 'package:kolexa/features/threads/data/threads_local_store.dart';
import 'package:kolexa/features/threads/data/threads_repository.dart';

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

  group('B2 — el patrón .catchError contiene un error real de SQLite', () {
    late DebugPrintCallback originalDebugPrint;
    final logs = <String>[];

    setUp(() async {
      await AppDatabase.instance.close(); // a propósito: sin sesión activa
      logs.clear();
      originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
    });

    tearDown(() {
      debugPrint = originalDebugPrint;
    });

    test(
        '6) saveInbox sin sesión activa lanza un StateError real — el mismo patrón '
        '.catchError de los 5 sitios lo contiene y lo registra, sin dejar un error sin manejar',
        () async {
      // Mismo patrón EXACTO que en inbox_page.dart/_refresh(),
      // thread_page.dart/_load()/_sendBody() y new_message_page.dart/_refresh().
      await ThreadsLocalStore.saveInbox([
        ThreadSummary(
          id: 't1',
          kind: 'direct',
          priority: 'normal',
          lastMessageAt: DateTime(2026, 1, 1),
          unread: false,
          unreadCount: 0,
          muted: false,
        ),
      ]).catchError((e, st) {
        debugPrint('[InboxPage] saveInbox falló: $e\n$st');
      });

      // Si el error no hubiese quedado capturado, la excepción se habría
      // propagado sin manejar fuera de este `test()` y flutter_test lo
      // habría marcado fallido — llegar acá ya es la primera prueba de
      // que quedó contenido.
      expect(logs.any((l) => l.contains('[InboxPage] saveInbox falló')), isTrue,
          reason: 'el fallo de la escritura debe quedar registrado para debugging');
      // StateError.toString() imprime "Bad state: <mensaje>", no la
      // palabra "StateError" — se verifica el mensaje real que lanza
      // AppDatabase, no un texto genérico.
      expect(logs.any((l) => l.contains('sin sesión activa')), isTrue,
          reason: 'el registro debe incluir la causa real del fallo, no un mensaje genérico');
    });

    test('el mismo patrón aplicado a saveThread/saveMessage/saveContacts también contiene el error',
        () async {
      await ThreadsLocalStore.saveThread(
        't1',
        const ThreadMessagesPage(messages: [], otherLastReadAt: null, otherLastActiveAt: null),
      ).catchError((e, st) => debugPrint('[ThreadPage] saveThread falló: $e'));

      await ThreadsLocalStore.saveMessage('t1', _message('m1', 'hola'))
          .catchError((e, st) => debugPrint('[ThreadPage] saveMessage falló: $e'));

      await ThreadsLocalStore.saveContacts([_contact('X')])
          .catchError((e, st) => debugPrint('[NewMessagePage] saveContacts falló: $e'));

      expect(logs.where((l) => l.contains('falló')).length, 3);
    });
  });

  group('deduplicación por id (requisito 7 — confirmar que sigue intacta)', () {
    setUp(() async {
      await AppDatabase.instance.close();
      // El archivo de este usuario de prueba queda en disco entre
      // corridas de `flutter test` (AppDatabase.close() nunca lo borra a
      // propósito) — se borra acá para que una corrida anterior no deje
      // filas residuales que hagan parecer "duplicado" algo que no lo es.
      final path = join(await databaseFactory.getDatabasesPath(), 'kolexa_777.db');
      try {
        await databaseFactory.deleteDatabase(path);
      } catch (_) {}
      await AppDatabase.instance.openForUser(777);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
    });

    test('guardar el mismo id dos veces reemplaza la fila, nunca la duplica', () async {
      await ThreadsLocalStore.saveThread(
        't1',
        ThreadMessagesPage(
          messages: [_message('m1', 'versión vieja')],
          otherLastReadAt: null,
          otherLastActiveAt: null,
        ),
      );
      await ThreadsLocalStore.saveThread(
        't1',
        ThreadMessagesPage(
          messages: [_message('m1', 'versión nueva')],
          otherLastReadAt: null,
          otherLastActiveAt: null,
        ),
      );

      final page = await ThreadsLocalStore.loadThread('t1');
      expect(page!.messages.length, 1);
      expect(page.messages.single.body, 'versión nueva');
    });

    test('un mensaje que llega dos veces (misma id) desde dos saves distintos no produce fila duplicada',
        () async {
      final page = ThreadMessagesPage(
        messages: [_message('m1', 'hola'), _message('m2', 'chau')],
        otherLastReadAt: null,
        otherLastActiveAt: null,
      );
      // Simula el mismo `_load()` corriendo dos veces con la MISMA
      // respuesta (ej. push + resume casi simultáneos, ambos con datos
      // idénticos porque no hubo mensajes nuevos entre medio).
      await ThreadsLocalStore.saveThread('t1', page);
      await ThreadsLocalStore.saveThread('t1', page);

      final loaded = await ThreadsLocalStore.loadThread('t1');
      expect(loaded!.messages.length, 2);
    });
  });
}
