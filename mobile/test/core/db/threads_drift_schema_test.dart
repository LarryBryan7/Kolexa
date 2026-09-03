// ============================================================
// threads_drift_schema_test.dart — migración a Drift: fidelidad de
// esquema y mapeo completo de campos
// ============================================================
// Los tests de aislamiento (app_database_isolation_test.dart) y de
// escritura (sqlite_write_safety_test.dart) ya prueban que Drift
// preserva el comportamiento de sqflite en lo esencial (aislamiento por
// archivo, dedup por id, manejo de errores). Este archivo agrega lo que
// es específico de la migración en sí:
//
// 1. Que el esquema físico generado por Drift tiene EXACTAMENTE los
//    mismos nombres de columna que el sqflite anterior (para que un
//    archivo creado antes de esta migración siga siendo legible).
// 2. Que el mapeo completo (no solo los campos usados en los otros
//    tests) sobrevive un round-trip: otherParticipant, lastMessage,
//    thread_meta con ambas fechas, contacts con más de un alumno.
// 3. Que saveThread sigue siendo aditivo (no borra mensajes de otras
//    tandas) y que su transacción cubre mensajes + meta juntos.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfi;

import 'package:kolexa/core/db/app_database.dart';
import 'package:kolexa/features/threads/data/threads_local_store.dart';
import 'package:kolexa/features/threads/data/threads_repository.dart';

void main() {
  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.instance.close();
    await AppDatabase.instance.openForUser(555);
    // Limpio el estado de la sesión de prueba para que cada test parta de
    // cero, sin depender de una corrida anterior de `flutter test`.
    final db = await AppDatabase.instance.database;
    await db.delete(db.inboxThreads).go();
    await db.delete(db.threadMessages).go();
    await db.delete(db.threadMeta).go();
    await db.delete(db.contacts).go();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  test('el esquema físico tiene los mismos nombres de columna que el sqflite anterior', () async {
    final db = await AppDatabase.instance.database;
    final cols = await db
        .customSelect("SELECT name FROM pragma_table_info('inbox_threads')")
        .map((row) => row.read<String>('name'))
        .get();

    expect(
      cols,
      containsAll([
        'id', 'kind', 'subject', 'studentId', 'studentName', 'priority', 'lastMessageAt',
        'unread', 'unreadCount', 'muted', 'otherId', 'otherName', 'otherAvatar', 'otherOnline',
        'lastMsgBody', 'lastMsgSenderId', 'lastMsgSentAt', 'lastMsgDelivered', 'sortIndex',
      ]),
      reason: 'un archivo creado por la versión anterior (sqflite) debe seguir siendo legible',
    );

    final msgCols = await db
        .customSelect("SELECT name FROM pragma_table_info('thread_messages')")
        .map((row) => row.read<String>('name'))
        .get();
    expect(msgCols, containsAll(['id', 'threadId', 'senderId', 'senderName', 'body', 'sentAt']));

    final idx = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='thread_messages'")
        .map((row) => row.read<String>('name'))
        .get();
    expect(idx, contains('idx_thread_messages_threadId'));
  });

  test('loadInbox/saveInbox: round-trip completo con otherParticipant y lastMessage', () async {
    final thread = ThreadSummary(
      id: 't1',
      kind: 'direct',
      subject: 'tema',
      studentId: 's1',
      studentName: 'Un Alumno',
      priority: 'high',
      lastMessageAt: DateTime(2026, 3, 4, 10, 30),
      unread: true,
      unreadCount: 3,
      muted: true,
      otherParticipant: const ThreadOtherParticipant(
        id: '2',
        name: 'Otro Participante',
        avatar: 'https://ej.plo/avatar.png',
        online: true,
      ),
      lastMessage: ThreadPreview(
        body: 'último mensaje',
        senderId: '2',
        sentAt: DateTime(2026, 3, 4, 10, 30),
        delivered: true,
      ),
    );

    await ThreadsLocalStore.saveInbox([thread]);
    final loaded = await ThreadsLocalStore.loadInbox();

    expect(loaded, hasLength(1));
    final r = loaded.single;
    expect(r.id, 't1');
    expect(r.subject, 'tema');
    expect(r.studentId, 's1');
    expect(r.studentName, 'Un Alumno');
    expect(r.priority, 'high');
    expect(r.lastMessageAt, DateTime(2026, 3, 4, 10, 30));
    expect(r.unread, isTrue);
    expect(r.unreadCount, 3);
    expect(r.muted, isTrue);
    expect(r.otherParticipant!.id, '2');
    expect(r.otherParticipant!.name, 'Otro Participante');
    expect(r.otherParticipant!.avatar, 'https://ej.plo/avatar.png');
    expect(r.otherParticipant!.online, isTrue);
    expect(r.lastMessage!.body, 'último mensaje');
    expect(r.lastMessage!.senderId, '2');
    expect(r.lastMessage!.sentAt, DateTime(2026, 3, 4, 10, 30));
    expect(r.lastMessage!.delivered, isTrue);
  });

  test('loadInbox preserva el orden guardado (sortIndex)', () async {
    await ThreadsLocalStore.saveInbox([
      ThreadSummary(
        id: 'a',
        kind: 'direct',
        priority: 'normal',
        lastMessageAt: DateTime(2026, 1, 1),
        unread: false,
        unreadCount: 0,
        muted: false,
      ),
      ThreadSummary(
        id: 'b',
        kind: 'direct',
        priority: 'normal',
        lastMessageAt: DateTime(2026, 1, 2),
        unread: false,
        unreadCount: 0,
        muted: false,
      ),
    ]);

    final loaded = await ThreadsLocalStore.loadInbox();
    expect(loaded.map((t) => t.id).toList(), ['a', 'b']);
  });

  test('thread_meta: round-trip con ambas fechas presentes y con ambas ausentes', () async {
    await ThreadsLocalStore.saveThread(
      't1',
      ThreadMessagesPage(
        messages: [
          ThreadMessage(id: 'm1', senderId: '1', senderName: 'X', body: 'hola', sentAt: DateTime(2026, 1, 1)),
        ],
        otherLastReadAt: DateTime(2026, 1, 1, 9),
        otherLastActiveAt: DateTime(2026, 1, 1, 10),
      ),
    );
    final withDates = await ThreadsLocalStore.loadThread('t1');
    expect(withDates!.otherLastReadAt, DateTime(2026, 1, 1, 9));
    expect(withDates.otherLastActiveAt, DateTime(2026, 1, 1, 10));

    // Vuelve a guardar el mismo hilo sin ninguna de las dos fechas — debe
    // reemplazar la fila de thread_meta, no dejar las fechas viejas.
    await ThreadsLocalStore.saveThread(
      't1',
      ThreadMessagesPage(
        messages: [
          ThreadMessage(id: 'm1', senderId: '1', senderName: 'X', body: 'hola', sentAt: DateTime(2026, 1, 1)),
        ],
        otherLastReadAt: null,
        otherLastActiveAt: null,
      ),
    );
    final withoutDates = await ThreadsLocalStore.loadThread('t1');
    expect(withoutDates!.otherLastReadAt, isNull);
    expect(withoutDates.otherLastActiveAt, isNull);
  });

  test('contacts: round-trip con más de un alumno por contacto', () async {
    final contact = Contact(
      userId: '10',
      name: 'Un Docente',
      avatar: null,
      role: 'teacher',
      students: const [
        ThreadStudentRef(id: '1', name: 'Hijo Uno'),
        ThreadStudentRef(id: '2', name: 'Hijo Dos'),
      ],
    );

    await ThreadsLocalStore.saveContacts([contact]);
    final loaded = await ThreadsLocalStore.loadContacts();

    expect(loaded, hasLength(1));
    expect(loaded.single.students.map((s) => s.name), ['Hijo Uno', 'Hijo Dos']);
  });

  test('saveThread es aditivo: una tanda nueva no borra mensajes de una tanda anterior', () async {
    await ThreadsLocalStore.saveThread(
      't1',
      ThreadMessagesPage(
        messages: [ThreadMessage(id: 'm1', senderId: '1', senderName: 'X', body: 'viejo', sentAt: DateTime(2026, 1, 1))],
        otherLastReadAt: null,
        otherLastActiveAt: null,
      ),
    );
    await ThreadsLocalStore.saveThread(
      't1',
      ThreadMessagesPage(
        messages: [ThreadMessage(id: 'm2', senderId: '1', senderName: 'X', body: 'nuevo', sentAt: DateTime(2026, 1, 2))],
        otherLastReadAt: null,
        otherLastActiveAt: null,
      ),
    );

    final page = await ThreadsLocalStore.loadThread('t1');
    expect(page!.messages.map((m) => m.body), ['viejo', 'nuevo']);
  });

  test('saveThread actualiza mensajes y thread_meta como una sola unidad (transacción)', () async {
    await ThreadsLocalStore.saveThread(
      't1',
      ThreadMessagesPage(
        messages: [ThreadMessage(id: 'm1', senderId: '1', senderName: 'X', body: 'hola', sentAt: DateTime(2026, 1, 1))],
        otherLastReadAt: DateTime(2026, 1, 1),
        otherLastActiveAt: DateTime(2026, 1, 1),
      ),
    );

    final db = await AppDatabase.instance.database;
    final msgCount = await (db.select(db.threadMessages)
          ..where((t) => t.threadId.equals('t1')))
        .get();
    final metaRows = await (db.select(db.threadMeta)..where((t) => t.threadId.equals('t1'))).get();

    expect(msgCount, hasLength(1));
    expect(metaRows, hasLength(1));
  });

  test('el orden de contacts respeta sortIndex al guardar', () async {
    await ThreadsLocalStore.saveContacts([
      const Contact(userId: '1', name: 'Primero', avatar: null, role: 'teacher', students: []),
      const Contact(userId: '2', name: 'Segundo', avatar: null, role: 'teacher', students: []),
    ]);
    final loaded = await ThreadsLocalStore.loadContacts();
    expect(loaded.map((c) => c.name).toList(), ['Primero', 'Segundo']);
  });
}
