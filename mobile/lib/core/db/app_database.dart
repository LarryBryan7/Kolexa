// ============================================================
// app_database.dart — Base de datos SQLite local del dispositivo
// ============================================================
// Hoy solo la usa la pestaña de mensajes (ver threads_local_store.dart):
// bandeja, mensajes por hilo y contactos. La idea es la misma que usa
// WhatsApp — la UI lee de acá primero (disco, instantáneo, sobrevive a
// reinicios de la app) y el backend se consulta en paralelo solo para
// traer lo nuevo.
//
// AISLAMIENTO ENTRE CUENTAS: cada usuario tiene su propio archivo
// (`kolexa_<userId>.db`), no una tabla compartida con un filtro
// `WHERE userId = ?`. Es aislamiento "correcto por construcción": una
// query nueva que alguien agregue en el futuro no puede filtrar mal ni
// olvidar un filtro, porque no hay forma de leer otra cuenta sin cambiar
// explícitamente qué archivo está abierto. `main.dart` llama a
// `openForUser()`/`close()` en reacción a cada cambio de `AuthState`
// (login, restauración de sesión en frío, logout manual o forzado por
// token expirado — los tres convergen en los mismos estados).
// ============================================================

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  int? _currentUserId;

  // Future en vuelo de la apertura actual — permite que `database` espere
  // a que termine en vez de fallar si se la consulta justo después de
  // `openForUser()` (ej. la primera pantalla de mensajería puede montarse
  // antes de que el archivo termine de abrirse).
  Future<void>? _pendingOpen;

  // Se incrementa en cada `openForUser`/`close`: si una apertura vieja
  // termina DESPUÉS de que ya se pidió cerrar sesión o abrir otra cuenta,
  // se descarta (cierra la conexión que acaba de abrir) en vez de dejar
  // una base de una cuenta abandonada activa.
  int _generation = 0;

  /// Abre el archivo exclusivo de `userId` — lo crea si es la primera vez
  /// que esta cuenta inicia sesión en este dispositivo. Si había otra
  /// cuenta abierta, la cierra primero. Si ya es la misma cuenta que está
  /// abierta, no hace nada (evita reabrir el archivo en cada refresh).
  Future<void> openForUser(int userId) {
    if (_currentUserId == userId && _db != null) return Future.value();
    final myGeneration = ++_generation;
    final future = _openForUser(userId, myGeneration);
    _pendingOpen = future;
    return future;
  }

  Future<void> _openForUser(int userId, int myGeneration) async {
    final previous = _db;
    _db = null;
    await previous?.close();
    final path = join(await getDatabasesPath(), 'kolexa_$userId.db');
    final opened = await openDatabase(path, version: 1, onCreate: _onCreate);
    if (myGeneration != _generation) {
      // Se cerró sesión (o se abrió otra cuenta) mientras esto corría.
      await opened.close();
      return;
    }
    _db = opened;
    _currentUserId = userId;
  }

  /// Cierra la conexión activa (si hay) — se llama al cerrar sesión. NO
  /// borra el archivo del disco: si la misma cuenta vuelve a iniciar
  /// sesión en este dispositivo, `openForUser` reabre su propio archivo
  /// tal como lo dejó.
  Future<void> close() {
    _generation++; // invalida cualquier openForUser en vuelo
    _pendingOpen = null;
    final db = _db;
    _db = null;
    _currentUserId = null;
    return db?.close() ?? Future.value();
  }

  /// Solo debe usarse con una sesión activa (después de `openForUser`).
  /// Si se llama sin sesión, es un error de programación — mejor fallar
  /// fuerte acá que compartir silenciosamente datos entre cuentas.
  Future<Database> get database async {
    if (_db == null && _pendingOpen != null) await _pendingOpen;
    final db = _db;
    if (db == null) {
      throw StateError(
          'AppDatabase usado sin sesión activa — hay que llamar a openForUser() primero.');
    }
    return db;
  }

  static Future<void> _onCreate(Database db, int version) async {
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
  }
}
