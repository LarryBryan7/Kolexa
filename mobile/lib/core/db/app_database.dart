// ============================================================
// app_database.dart — Base de datos SQLite local del dispositivo
// ============================================================
// Hoy solo la usa la pestaña de mensajes (ver threads_local_store.dart):
// bandeja, mensajes por hilo y contactos. La idea es la misma que usa
// WhatsApp — la UI lee de acá primero (disco, instantáneo, sobrevive a
// reinicios de la app) y el backend se consulta en paralelo solo para
// traer lo nuevo.
// ============================================================

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'kolexa.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE inbox_threads (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            subject TEXT,
            studentId TEXT,
            studentName TEXT,
            priority TEXT NOT NULL,
            lastMessageAt INTEGER NOT NULL,
            unread INTEGER NOT NULL,
            unreadCount INTEGER NOT NULL,
            muted INTEGER NOT NULL,
            otherId TEXT,
            otherName TEXT,
            otherAvatar TEXT,
            otherOnline INTEGER,
            lastMsgBody TEXT,
            lastMsgSenderId TEXT,
            lastMsgSentAt INTEGER,
            lastMsgDelivered INTEGER,
            sortIndex INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE thread_messages (
            id TEXT PRIMARY KEY,
            threadId TEXT NOT NULL,
            senderId TEXT NOT NULL,
            senderName TEXT NOT NULL,
            body TEXT NOT NULL,
            sentAt INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_thread_messages_threadId ON thread_messages(threadId)');
        await db.execute('''
          CREATE TABLE thread_meta (
            threadId TEXT PRIMARY KEY,
            otherLastReadAt INTEGER,
            otherLastActiveAt INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE contacts (
            userId TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            avatar TEXT,
            role TEXT NOT NULL,
            studentsJson TEXT NOT NULL,
            sortIndex INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }
}
