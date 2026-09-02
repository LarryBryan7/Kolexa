// ============================================================
// threads_local_store.dart — Persistencia local (SQLite) de mensajes
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
// ============================================================

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import 'threads_repository.dart';

class ThreadsLocalStore {
  static Future<List<ThreadSummary>> loadInbox() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('inbox_threads', orderBy: 'sortIndex ASC');
    return rows.map(_threadFromRow).toList();
  }

  // Reemplaza toda la tabla: la bandeja es chica (decenas de hilos) y así
  // un hilo que ya no debería aparecer (ej. bloqueado del lado del
  // servidor) no queda pegado en el cache local para siempre.
  static Future<void> saveInbox(List<ThreadSummary> threads) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('inbox_threads');
      for (var i = 0; i < threads.length; i++) {
        await txn.insert('inbox_threads', _threadToRow(threads[i], i),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<ThreadMessagesPage?> loadThread(String threadId) async {
    final db = await AppDatabase.instance.database;
    final msgRows = await db.query('thread_messages',
        where: 'threadId = ?', whereArgs: [threadId], orderBy: 'sentAt ASC');
    if (msgRows.isEmpty) return null;
    final metaRows =
        await db.query('thread_meta', where: 'threadId = ?', whereArgs: [threadId]);
    final meta = metaRows.isNotEmpty ? metaRows.first : null;
    return ThreadMessagesPage(
      messages: msgRows.map(_messageFromRow).toList(),
      otherLastReadAt: meta?['otherLastReadAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(meta!['otherLastReadAt'] as int)
          : null,
      otherLastActiveAt: meta?['otherLastActiveAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(meta!['otherLastActiveAt'] as int)
          : null,
    );
  }

  // Se usa tal cual (upsert por id), sin borrar mensajes previos del hilo:
  // getMessages() de hoy solo trae la última página, así que borrar todo
  // antes de insertar perdería el historial más viejo que ya estaba en
  // disco de una sesión anterior.
  static Future<void> saveThread(String threadId, ThreadMessagesPage page) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      for (final m in page.messages) {
        await txn.insert('thread_messages', _messageToRow(threadId, m),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.insert(
        'thread_meta',
        {
          'threadId': threadId,
          'otherLastReadAt': page.otherLastReadAt?.millisecondsSinceEpoch,
          'otherLastActiveAt': page.otherLastActiveAt?.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // Un mensaje recién confirmado por el backend (ver ThreadPage._sendBody)
  // se agrega sin esperar al próximo saveThread() completo, así sobrevive
  // un reinicio de la app aunque todavía no haya corrido otro getMessages().
  static Future<void> saveMessage(String threadId, ThreadMessage message) async {
    final db = await AppDatabase.instance.database;
    await db.insert('thread_messages', _messageToRow(threadId, message),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Contact>> loadContacts() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('contacts', orderBy: 'sortIndex ASC');
    return rows.map(_contactFromRow).toList();
  }

  static Future<void> saveContacts(List<Contact> contacts) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('contacts');
      for (var i = 0; i < contacts.length; i++) {
        await txn.insert('contacts', _contactToRow(contacts[i], i),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ── mapeo fila (SQLite) ↔ modelo (threads_repository.dart) ──

  static Map<String, dynamic> _threadToRow(ThreadSummary t, int index) => {
        'id': t.id,
        'kind': t.kind,
        'subject': t.subject,
        'studentId': t.studentId,
        'studentName': t.studentName,
        'priority': t.priority,
        'lastMessageAt': t.lastMessageAt.millisecondsSinceEpoch,
        'unread': t.unread ? 1 : 0,
        'unreadCount': t.unreadCount,
        'muted': t.muted ? 1 : 0,
        'otherId': t.otherParticipant?.id,
        'otherName': t.otherParticipant?.name,
        'otherAvatar': t.otherParticipant?.avatar,
        'otherOnline': t.otherParticipant != null ? (t.otherParticipant!.online ? 1 : 0) : null,
        'lastMsgBody': t.lastMessage?.body,
        'lastMsgSenderId': t.lastMessage?.senderId,
        'lastMsgSentAt': t.lastMessage?.sentAt.millisecondsSinceEpoch,
        'lastMsgDelivered': t.lastMessage != null ? (t.lastMessage!.delivered ? 1 : 0) : null,
        'sortIndex': index,
      };

  static ThreadSummary _threadFromRow(Map<String, dynamic> row) => ThreadSummary(
        id: row['id'] as String,
        kind: row['kind'] as String,
        subject: row['subject'] as String?,
        studentId: row['studentId'] as String?,
        studentName: row['studentName'] as String?,
        priority: row['priority'] as String,
        lastMessageAt: DateTime.fromMillisecondsSinceEpoch(row['lastMessageAt'] as int),
        unread: (row['unread'] as int) == 1,
        unreadCount: row['unreadCount'] as int,
        muted: (row['muted'] as int) == 1,
        otherParticipant: row['otherId'] != null
            ? ThreadOtherParticipant(
                id: row['otherId'] as String,
                name: row['otherName'] as String? ?? '',
                avatar: row['otherAvatar'] as String?,
                online: (row['otherOnline'] as int? ?? 0) == 1,
              )
            : null,
        lastMessage: row['lastMsgBody'] != null
            ? ThreadPreview(
                body: row['lastMsgBody'] as String,
                senderId: row['lastMsgSenderId'] as String,
                sentAt: DateTime.fromMillisecondsSinceEpoch(row['lastMsgSentAt'] as int),
                delivered: (row['lastMsgDelivered'] as int? ?? 0) == 1,
              )
            : null,
      );

  static Map<String, dynamic> _messageToRow(String threadId, ThreadMessage m) => {
        'id': m.id,
        'threadId': threadId,
        'senderId': m.senderId,
        'senderName': m.senderName,
        'body': m.body,
        'sentAt': m.sentAt.millisecondsSinceEpoch,
      };

  static ThreadMessage _messageFromRow(Map<String, dynamic> row) => ThreadMessage(
        id: row['id'] as String,
        senderId: row['senderId'] as String,
        senderName: row['senderName'] as String,
        body: row['body'] as String,
        sentAt: DateTime.fromMillisecondsSinceEpoch(row['sentAt'] as int),
      );

  static Map<String, dynamic> _contactToRow(Contact c, int index) => {
        'userId': c.userId,
        'name': c.name,
        'avatar': c.avatar,
        'role': c.role,
        'studentsJson': jsonEncode(c.students.map((s) => {'id': s.id, 'name': s.name}).toList()),
        'sortIndex': index,
      };

  static Contact _contactFromRow(Map<String, dynamic> row) => Contact(
        userId: row['userId'] as String,
        name: row['name'] as String,
        avatar: row['avatar'] as String?,
        role: row['role'] as String,
        students: (jsonDecode(row['studentsJson'] as String) as List<dynamic>)
            .map((s) => ThreadStudentRef(
                id: (s as Map<String, dynamic>)['id'] as String, name: s['name'] as String))
            .toList(),
      );
}
