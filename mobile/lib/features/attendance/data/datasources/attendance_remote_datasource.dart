// ============================================================
// attendance_remote_datasource.dart — Fuente de datos remota de Asistencia
// ============================================================
// Hace las llamadas HTTP al backend de asistencia.
// El Repository usa este DataSource — nunca la UI directamente.
//
// Endpoints que consume:
//   POST /attendance                         → crear sesión
//   GET  /attendance/:id                     → obtener sesión
//   GET  /attendance/classroom/:id?date=     → sesión de aula en fecha
//   PUT  /attendance/:id/records             → actualizar registros
//   GET  /attendance/student/:id/history     → historial de alumno
// ============================================================

import '../../../../core/api/api_client.dart';
import '../models/attendance_model.dart';

class AttendanceRemoteDataSource {
  final ApiClient _client;

  AttendanceRemoteDataSource(this._client);

  // ── createSession ─────────────────────────────────────────
  // El profesor crea una sesión de asistencia para su aula hoy.
  // Devuelve la sesión creada con los registros de todos los alumnos
  // (ya inicializados con estado 'present' por el backend).
  Future<AttendanceSessionModel> createSession({
    required int classroomId,
    required String date,      // "2024-03-15"
    int? courseId,
    String? notes,
  }) async {
    final body = {
      'classroomId': classroomId,
      'date': date,
      if (courseId != null) 'courseId': courseId,
      if (notes != null) 'notes': notes,
    };

    final response = await _client.post('attendance', data: body);
    return AttendanceSessionModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  // ── getSession ────────────────────────────────────────────
  // Obtiene una sesión por su ID con todos los registros de alumnos.
  Future<AttendanceSessionModel> getSession(int sessionId) async {
    final response = await _client.get('attendance/$sessionId');
    return AttendanceSessionModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  // ── getByClassroom ────────────────────────────────────────
  // Obtiene la sesión de un aula en una fecha.
  // Devuelve null si no existe sesión para esa fecha.
  Future<AttendanceSessionModel?> getByClassroom({
    required int classroomId,
    required String date,
  }) async {
    final response = await _client.get(
      'attendance/classroom/$classroomId',
      queryParams: {'date': date},
    );

    // El backend devuelve null si no existe sesión ese día
    if (response.data == null) return null;

    return AttendanceSessionModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  // ── updateRecords ─────────────────────────────────────────
  // Envía los registros actualizados al backend.
  // Solo enviamos los que cambiaron (isModified = true) para eficiencia.
  Future<AttendanceSessionModel> updateRecords({
    required int sessionId,
    required List<AttendanceRecordModel> records,
  }) async {
    // Convertir cada registro a JSON
    final body = {
      'records': records.map((r) => r.toJson()).toList(),
    };

    final response = await _client.put(
      'attendance/$sessionId/records',
      data: body,
    );

    return AttendanceSessionModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  // ── getStudentHistory ──────────────────────────────────────
  // Historial de asistencia de un alumno.
  // Retorna un mapa con 'records', 'total' y 'stats'.
  Future<Map<String, dynamic>> getStudentHistory({
    required int studentId,
    int limit = 30,
    int offset = 0,
  }) async {
    final response = await _client.get(
      'attendance/student/$studentId/history',
      queryParams: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    return response.data as Map<String, dynamic>;
  }
}
