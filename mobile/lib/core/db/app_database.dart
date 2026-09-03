// ============================================================
// app_database.dart — Base de datos local del dispositivo (Drift)
// ============================================================
// Hoy solo la usa la pestaña de mensajes (ver threads_local_store.dart):
// bandeja, mensajes por hilo y contactos. La idea es la misma que usa
// WhatsApp — la UI lee de acá primero (disco, instantáneo, sobrevive a
// reinicios de la app) y el backend se consulta en paralelo solo para
// traer lo nuevo.
//
// Migrado de sqflite a Drift (motor type-safe sobre SQLite) — esta clase
// sigue siendo el punto público estable que usan main.dart y
// ThreadsLocalStore; solo cambió qué hay adentro. El archivo físico de
// cada cuenta sigue en el MISMO lugar de siempre
// (`<getDatabasesPath()>/kolexa_<userId>.db`) para que el cache ya
// guardado de los usuarios existentes no se pierda con el cambio de
// motor — por eso `sqflite` se mantiene como dependencia, únicamente por
// su utilidad `getDatabasesPath()`.
//
// AISLAMIENTO ENTRE CUENTAS: cada usuario tiene su propio archivo, no una
// tabla compartida con un filtro `WHERE userId = ?`. Es aislamiento
// "correcto por construcción": una query nueva que alguien agregue en el
// futuro no puede filtrar mal ni olvidar un filtro, porque no hay forma
// de leer otra cuenta sin cambiar explícitamente qué archivo está
// abierto. `main.dart` llama a `openForUser()`/`close()` en reacción a
// cada cambio de `AuthState` (login, restauración de sesión en frío,
// logout manual o forzado por token expirado — los tres convergen en los
// mismos estados).
// ============================================================

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import 'drift/threads_drift_db.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  ThreadsDriftDb? _db;
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
    // Drift (a diferencia de sqflite) no crea el directorio contenedor
    // por sí solo si faltara.
    await Directory(dirname(path)).create(recursive: true);
    final opened = ThreadsDriftDb(NativeDatabase(File(path)));
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
  Future<ThreadsDriftDb> get database async {
    if (_db == null && _pendingOpen != null) await _pendingOpen;
    final db = _db;
    if (db == null) {
      throw StateError(
          'AppDatabase usado sin sesión activa — hay que llamar a openForUser() primero.');
    }
    return db;
  }

  /// El id de la cuenta actualmente abierta (o null) — expuesto solo para
  /// que los tests puedan verificar cuál cuenta "ganó" tras una condición
  /// de carrera, sin depender de detalles del motor de persistencia
  /// (antes se verificaba inspeccionando `Database.path` de sqflite; con
  /// Drift el executor no expone necesariamente esa propiedad).
  @visibleForTesting
  int? get debugCurrentUserId => _currentUserId;
}
