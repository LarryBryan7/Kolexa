// ============================================================
// threads_drift_db.dart — base de datos Drift para la pestaña de mensajes
// ============================================================
// Se llama `ThreadsDriftDb` (no `AppDatabase`) a propósito: `AppDatabase`
// sigue siendo la clase pública que ya conocen main.dart y los tests —
// esta es el motor interno que envuelve, generado por Drift.
//
// schemaVersion = 1 coincide con el `version: 1` que ya usaba
// `openDatabase(...)` en la implementación anterior con sqflite — los
// archivos creados antes de esta migración ya tienen
// `PRAGMA user_version = 1`, así que Drift nunca corre `onCreate` sobre
// ellos: simplemente empieza a leer/escribir las tablas tal como están
// (por eso threads_tables.dart tiene que coincidir columna por columna
// con lo que esos archivos ya tienen).
// ============================================================

import 'package:drift/drift.dart';

import 'threads_tables.dart';

part 'threads_drift_db.g.dart';

@DriftDatabase(tables: [InboxThreads, ThreadMessages, ThreadMeta, Contacts])
class ThreadsDriftDb extends _$ThreadsDriftDb {
  ThreadsDriftDb(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Mismo índice que creaba AppDatabase._onCreate a mano — solo
          // corre para un archivo nuevo (un usuario que nunca inició
          // sesión antes en este dispositivo); uno preexistente ya lo
          // tiene desde antes de esta migración.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_thread_messages_threadId ON thread_messages (threadId)',
          );
        },
      );
}
