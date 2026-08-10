// ============================================================
// attendance_repository.dart — Repositorio de Asistencia
// ============================================================
// El Repository coordina el DataSource remoto y la caché local.
// El BLoC solo habla con el Repository — nunca con el DataSource.
//
// Decisiones de diseño en este Repository:
//   1. Caché en memoria: guardamos la última sesión cargada.
//      Si el profesor sale y vuelve a entrar, no hace otra petición.
//      La caché se invalida al guardar cambios.
//   2. Lógica de "obtener o crear":
//      Si no hay sesión para hoy, la crea automáticamente.
//      Esto simplifica el BLoC — él solo pide la sesión.
// ============================================================

import '../datasources/attendance_remote_datasource.dart';
import '../models/attendance_model.dart';

class AttendanceRepository {
  final AttendanceRemoteDataSource _remote;

  // Caché en memoria — se pierde al cerrar la app (es intencional)
  // La clave es "classroomId-date" para identificar cada sesión
  final Map<String, AttendanceSessionModel> _cache = {};

  AttendanceRepository(this._remote);

  // ── getTodaySession ───────────────────────────────────────
  // Obtiene (o crea) la sesión de hoy para un aula.
  // Este es el método principal que llama el BLoC al abrir la pantalla.
  //
  // Flujo:
  //   1. Calcular la fecha de hoy
  //   2. Revisar caché en memoria
  //   3. Si no hay caché → pedir al backend
  //   4. Si el backend dice que no hay sesión → crear una nueva
  //   5. Guardar en caché y retornar
  Future<AttendanceSessionModel> getTodaySession(int classroomId) async {
    // Formato de fecha ISO: "2024-03-15"
    final today = _todayDate();
    final cacheKey = '$classroomId-$today';

    // Revisar caché primero (evita petición HTTP innecesaria)
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Pedir al backend la sesión de hoy
    var session = await _remote.getByClassroom(
      classroomId: classroomId,
      date: today,
    );

    // Si no existe, crearla automáticamente
    session ??= await _remote.createSession(
      classroomId: classroomId,
      date: today,
    );

    // Guardar en caché
    _cache[cacheKey] = session;
    return session;
  }

  // ── getSessionByDate ──────────────────────────────────────
  // Obtiene la sesión de un aula en una fecha específica (histórico).
  // A diferencia de getTodaySession, NO crea la sesión si no existe.
  Future<AttendanceSessionModel?> getSessionByDate({
    required int classroomId,
    required String date,
  }) async {
    final cacheKey = '$classroomId-$date';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    final session = await _remote.getByClassroom(
      classroomId: classroomId,
      date: date,
    );

    if (session != null) {
      _cache[cacheKey] = session;
    }

    return session;
  }

  // ── saveAttendance ────────────────────────────────────────
  // Guarda los cambios de asistencia al backend.
  // Solo envía los registros que fueron modificados por el profesor.
  Future<AttendanceSessionModel> saveAttendance({
    required int sessionId,
    required List<AttendanceRecordModel> allRecords,
  }) async {
    // Filtrar solo los registros que el profesor modificó
    final modifiedRecords = allRecords.where((r) => r.isModified).toList();

    if (modifiedRecords.isEmpty) {
      // Nada cambió — retornar la sesión sin hacer petición HTTP
      final session = await _remote.getSession(sessionId);
      return session;
    }

    // Enviar los cambios al backend
    final updatedSession = await _remote.updateRecords(
      sessionId: sessionId,
      records: modifiedRecords,
    );

    // Actualizar la caché con la versión nueva
    final today = _todayDate();
    final cacheKey = '${updatedSession.classroomId}-$today';
    _cache[cacheKey] = updatedSession;

    return updatedSession;
  }

  // ── getStudentHistory ──────────────────────────────────────
  // Historial de asistencia de un alumno (para el padre de familia).
  Future<Map<String, dynamic>> getStudentHistory({
    required int studentId,
    int limit = 30,
    int offset = 0,
  }) async {
    return _remote.getStudentHistory(
      studentId: studentId,
      limit: limit,
      offset: offset,
    );
  }

  // ── invalidateCache ───────────────────────────────────────
  // Limpia la caché para forzar una nueva carga desde el backend.
  // Útil cuando sabemos que los datos cambiaron externamente.
  void invalidateCache() => _cache.clear();

  // ── Utilidades privadas ────────────────────────────────────

  // Retorna la fecha de hoy en formato "2024-03-15"
  String _todayDate() {
    final now = DateTime.now();
    // padLeft(2, '0') agrega un cero adelante si el número tiene 1 dígito
    // Ej: mes 3 → "03", día 5 → "05"
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}
