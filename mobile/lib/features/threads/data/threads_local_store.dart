// ============================================================
// threads_local_store.dart — Persistencia local (Drift/SQLite) de mensajes
// ============================================================
// La bandeja, cada conversación y los contactos se guardan en disco acá.
// El patrón es "leer de disco primero, refrescar en segundo plano" (igual
// que WhatsApp): las páginas de UI (InboxPage/ThreadPage/NewMessagePage)
// siguen teniendo su propio cache en memoria a nivel de clase para la
// reapertura instantánea dentro de la misma sesión — esto cubre el caso
// que ese cache no cubre: un arranque nuevo del proceso, donde antes no
// había nada que mostrar salvo esperar al backend (que además cruza a
// São Paulo).
//
// Los mensajes "pendientes"/"fallidos" (ver ThreadPage._pendingMessages)
// nunca llegan hasta acá — solo se persiste lo que el backend ya confirmó.
//
// Migrado de sqflite a Drift: los 7 métodos públicos y su comportamiento
// (upsert por id, saveThread aditivo, delete-all+insert para
// bandeja/contactos, transacciones donde ya existían) se mantienen
// exactamente iguales — solo cambió la implementación interna, de SQL
// crudo a queries type-safe de Drift. `InsertMode.insertOrReplace` es
// intencional: es la misma sentencia `INSERT OR REPLACE` que ya se usaba
// con `ConflictAlgorithm.replace` en sqflite, no una semántica nueva.
// ============================================================

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/drift/threads_drift_db.dart';
import 'threads_repository.dart';

class ThreadsLocalStore {
  static Future<List<ThreadSummary>> loadInbox() async {
    final db = await AppDatabase.instance.database;
    final rows = await (db.select(db.inboxThreads)
          ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
        .get();
    return rows.map(_threadFromRow).toList();
  }

  // Reemplaza toda la tabla: la bandeja es chica (decenas de hilos) y así
  // un hilo que ya no debería aparecer (ej. bloqueado del lado del
  // servidor) no queda pegado en el cache local para siempre.
  static Future<void> saveInbox(List<ThreadSummary> threads) async {
    final db = await AppDatabase.instance.database;
    await db.transaction(() async {
      await db.delete(db.inboxThreads).go();
      for (var i = 0; i < threads.length; i++) {
        await db.into(db.inboxThreads).insert(
              _threadToRow(threads[i], i),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  static Future<ThreadMessagesPage?> loadThread(String threadId) async {
    final db = await AppDatabase.instance.database;
    final msgRows = await (db.select(db.threadMessages)
          ..where((t) => t.threadId.equals(threadId))
          ..orderBy([(t) => OrderingTerm.asc(t.sentAt)]))
        .get();
    if (msgRows.isEmpty) return null;
    final metaRows =
        await (db.select(db.threadMeta)..where((t) => t.threadId.equals(threadId))).get();
    final meta = metaRows.isNotEmpty ? metaRows.first : null;
    return ThreadMessagesPage(
      messages: msgRows.map(_messageFromRow).toList(),
      otherLastReadAt: meta?.otherLastReadAt != null
          ? DateTime.fromMillisecondsSinceEpoch(meta!.otherLastReadAt!)
          : null,
      otherLastActiveAt: meta?.otherLastActiveAt != null
          ? DateTime.fromMillisecondsSinceEpoch(meta!.otherLastActiveAt!)
          : null,
    );
  }

  // Se usa tal cual (upsert por id), sin borrar mensajes previos del hilo:
  // getMessages() de hoy solo trae la última página, así que borrar todo
  // antes de insertar perdería el historial más viejo que ya estaba en
  // disco de una sesión anterior.
  static Future<void> saveThread(String threadId, ThreadMessagesPage page) async {
    final db = await AppDatabase.instance.database;
    await db.transaction(() async {
      for (final m in page.messages) {
        await db.into(db.threadMessages).insert(
              _messageToRow(threadId, m),
              mode: InsertMode.insertOrReplace,
            );
      }
      await db.into(db.threadMeta).insert(
            _metaToRow(threadId, page),
            mode: InsertMode.insertOrReplace,
          );
    });
  }

  // Un mensaje recién confirmado por el backend (ver ThreadPage._sendBody)
  // se agrega sin esperar al próximo saveThread() completo, así sobrevive
  // un reinicio de la app aunque todavía no haya corrido otro getMessages().
  static Future<void> saveMessage(String threadId, ThreadMessage message) async {
    final db = await AppDatabase.instance.database;
    await db.into(db.threadMessages).insert(
          _messageToRow(threadId, message),
          mode: InsertMode.insertOrReplace,
        );
  }

  static Future<List<Contact>> loadContacts() async {
    final db = await AppDatabase.instance.database;
    final rows =
        await (db.select(db.contacts)..orderBy([(t) => OrderingTerm.asc(t.sortIndex)])).get();
    return rows.map(_contactFromRow).toList();
  }

  static Future<void> saveContacts(List<Contact> contacts) async {
    final db = await AppDatabase.instance.database;
    await db.transaction(() async {
      await db.delete(db.contacts).go();
      for (var i = 0; i < contacts.length; i++) {
        await db.into(db.contacts).insert(
              _contactToRow(contacts[i], i),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  // ── mapeo fila (Drift) ↔ modelo (threads_repository.dart) ──

  static InboxThreadsCompanion _threadToRow(ThreadSummary t, int index) => InboxThreadsCompanion.insert(
        id: t.id,
        kind: t.kind,
        subject: Value(t.subject),
        studentId: Value(t.studentId),
        studentName: Value(t.studentName),
        priority: t.priority,
        lastMessageAt: t.lastMessageAt.millisecondsSinceEpoch,
        unread: t.unread,
        unreadCount: t.unreadCount,
        muted: t.muted,
        otherId: Value(t.otherParticipant?.id),
        otherName: Value(t.otherParticipant?.name),
        otherAvatar: Value(t.otherParticipant?.avatar),
        otherOnline: Value(t.otherParticipant?.online),
        lastMsgBody: Value(t.lastMessage?.body),
        lastMsgSenderId: Value(t.lastMessage?.senderId),
        lastMsgSentAt: Value(t.lastMessage?.sentAt.millisecondsSinceEpoch),
        lastMsgDelivered: Value(t.lastMessage?.delivered),
        sortIndex: index,
      );

  static ThreadSummary _threadFromRow(InboxThread row) => ThreadSummary(
        id: row.id,
        kind: row.kind,
        subject: row.subject,
        studentId: row.studentId,
        studentName: row.studentName,
        priority: row.priority,
        lastMessageAt: DateTime.fromMillisecondsSinceEpoch(row.lastMessageAt),
        unread: row.unread,
        unreadCount: row.unreadCount,
        muted: row.muted,
        otherParticipant: row.otherId != null
            ? ThreadOtherParticipant(
                id: row.otherId!,
                name: row.otherName ?? '',
                avatar: row.otherAvatar,
                online: row.otherOnline ?? false,
              )
            : null,
        lastMessage: row.lastMsgBody != null
            ? ThreadPreview(
                body: row.lastMsgBody!,
                senderId: row.lastMsgSenderId!,
                sentAt: DateTime.fromMillisecondsSinceEpoch(row.lastMsgSentAt!),
                delivered: row.lastMsgDelivered ?? false,
              )
            : null,
      );

  static ThreadMessagesCompanion _messageToRow(String threadId, ThreadMessage m) =>
      ThreadMessagesCompanion.insert(
        id: m.id,
        threadId: threadId,
        senderId: m.senderId,
        senderName: m.senderName,
        body: m.body,
        sentAt: m.sentAt.millisecondsSinceEpoch,
      );

  static ThreadMessage _messageFromRow(ThreadMessageRow row) => ThreadMessage(
        id: row.id,
        senderId: row.senderId,
        senderName: row.senderName,
        body: row.body,
        sentAt: DateTime.fromMillisecondsSinceEpoch(row.sentAt),
      );

  static ThreadMetaCompanion _metaToRow(String threadId, ThreadMessagesPage page) =>
      ThreadMetaCompanion.insert(
        threadId: threadId,
        otherLastReadAt: Value(page.otherLastReadAt?.millisecondsSinceEpoch),
        otherLastActiveAt: Value(page.otherLastActiveAt?.millisecondsSinceEpoch),
      );

  static ContactsCompanion _contactToRow(Contact c, int index) => ContactsCompanion.insert(
        userId: c.userId,
        name: c.name,
        avatar: Value(c.avatar),
        role: c.role,
        studentsJson: jsonEncode(c.students.map((s) => {'id': s.id, 'name': s.name}).toList()),
        sortIndex: index,
      );

  static Contact _contactFromRow(ContactRow row) => Contact(
        userId: row.userId,
        name: row.name,
        avatar: row.avatar,
        role: row.role,
        students: (jsonDecode(row.studentsJson) as List<dynamic>)
            .map((s) => ThreadStudentRef(
                id: (s as Map<String, dynamic>)['id'] as String, name: s['name'] as String))
            .toList(),
      );
}
