// ============================================================
// attendance_bloc.dart — BLoC de Asistencia
// ============================================================
// Orquesta la lógica de la pantalla de asistencia.
// Recibe eventos de la UI y emite estados de vuelta.
//
// Casos especiales importantes:
//
// 1. UpdateStudentStatusEvent NO hace petición HTTP.
//    Solo modifica la lista de records en memoria y emite AttendanceLoaded
//    con hasChanges = true. Esto permite:
//      - Marcado de alumnos sin lag de red
//      - El profesor puede marcar todos y guardar al final
//      - Si cierra sin guardar, se pierden los cambios (comportamiento esperado)
//
// 2. SaveAttendanceEvent sí hace petición HTTP.
//    Solo envía los records con isModified = true (eficiencia).
//
// 3. El BLoC es por pantalla, no global.
//    A diferencia del AuthBloc que vive en la raíz de la app,
//    el AttendanceBloc se crea y destruye con la pantalla de asistencia.
//    Esto evita acumulación de estado entre sesiones.
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/attendance_model.dart';
import '../data/repositories/attendance_repository.dart';
import 'attendance_event.dart';
import 'attendance_state.dart';

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final AttendanceRepository _repository;

  AttendanceBloc(this._repository) : super(const AttendanceInitial()) {
    on<LoadTodayAttendanceEvent>(_onLoadToday);
    on<UpdateStudentStatusEvent>(_onUpdateStudentStatus);
    on<SaveAttendanceEvent>(_onSave);
    on<LoadStudentHistoryEvent>(_onLoadHistory);
  }

  // ── _onLoadToday ──────────────────────────────────────────
  // Carga (o crea) la sesión de asistencia de hoy para el aula.
  Future<void> _onLoadToday(
    LoadTodayAttendanceEvent event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(const AttendanceLoading());

    try {
      final session = await _repository.getTodaySession(event.classroomId);
      emit(AttendanceLoaded(session: session));
    } catch (e) {
      emit(AttendanceError(
        e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  // ── _onUpdateStudentStatus ─────────────────────────────────
  // Actualiza el estado de UN alumno en memoria (sin HTTP).
  // Se ejecuta cada vez que el profesor toca el estado de un alumno.
  //
  // La operación más importante aquí: marcar isModified = true
  // para que SaveAttendanceEvent sepa qué enviar al backend.
  void _onUpdateStudentStatus(
    UpdateStudentStatusEvent event,
    Emitter<AttendanceState> emit,
  ) {
    // Solo podemos actualizar si hay una sesión cargada
    if (state is! AttendanceLoaded) return;
    final currentState = state as AttendanceLoaded;

    // Encontrar el record del alumno y actualizar su estado
    final updatedRecords = currentState.session.records.map((record) {
      if (record.studentId == event.studentId) {
        // Este es el alumno que el profesor modificó
        return record.copyWith(
          status: attendanceStatusFromJson(event.status.status),
          lateMinutes: event.status.lateMinutes,
          justification: event.status.justification,
          isModified: true, // marcar como modificado para el guardado
        );
      }
      return record; // los demás alumnos no cambian
    }).toList();

    // Crear una nueva sesión con los records actualizados
    // (no mutamos la original — Flutter detecta cambios comparando objetos)
    final updatedSession = AttendanceSessionModel(
      id: currentState.session.id,
      classroomId: currentState.session.classroomId,
      classroomName: currentState.session.classroomName,
      courseName: currentState.session.courseName,
      date: currentState.session.date,
      notes: currentState.session.notes,
      records: updatedRecords,
    );

    emit(currentState.copyWith(
      session: updatedSession,
      hasChanges: true, // hay cambios sin guardar
      justSaved: false, // limpiar el estado de "recién guardado"
    ));
  }

  // ── _onSave ───────────────────────────────────────────────
  // Guarda los cambios al backend.
  // Solo envía los records marcados con isModified = true.
  Future<void> _onSave(
    SaveAttendanceEvent event,
    Emitter<AttendanceState> emit,
  ) async {
    if (state is! AttendanceLoaded) return;
    final currentState = state as AttendanceLoaded;

    // Mostrar spinner de guardado (deshabilitar botón Guardar)
    emit(currentState.copyWith(isSaving: true));

    try {
      final savedSession = await _repository.saveAttendance(
        sessionId: currentState.session.id,
        allRecords: currentState.session.records,
      );

      // Guardado exitoso:
      // - Actualizar con la sesión devuelta por el backend
      // - hasChanges = false (ya no hay cambios pendientes)
      // - justSaved = true (para mostrar SnackBar de confirmación)
      emit(AttendanceLoaded(
        session: savedSession,
        isSaving: false,
        hasChanges: false,
        justSaved: true,
      ));
    } catch (e) {
      // Error al guardar — mantener los cambios en memoria
      // para que el profesor pueda intentarlo de nuevo
      emit(currentState.copyWith(
        isSaving: false,
        justSaved: false,
      ));
      // Emitir el error después para que la UI lo muestre
      emit(AttendanceError(e.toString().replaceFirst('Exception: ', '')));
      // Volver al estado cargado para que el profesor pueda reintentar
      emit(currentState.copyWith(isSaving: false));
    }
  }

  // ── _onLoadHistory ────────────────────────────────────────
  // Carga el historial de asistencia de un alumno.
  Future<void> _onLoadHistory(
    LoadStudentHistoryEvent event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(const AttendanceLoading());

    try {
      final result = await _repository.getStudentHistory(
        studentId: event.studentId,
        limit: event.limit,
        offset: event.offset,
      );

      // Construir el mapa de estadísticas desde la respuesta del backend
      final rawStats = result['stats'] as List<dynamic>? ?? [];
      final stats = <String, int>{};
      for (final stat in rawStats) {
        final statusMap = stat as Map<String, dynamic>;
        stats[statusMap['status'] as String] =
            (statusMap['_count'] as Map)['status'] as int;
      }

      emit(AttendanceHistoryLoaded(
        records: result['records'] as List<dynamic>,
        total: result['total'] as int,
        stats: stats,
      ));
    } catch (e) {
      emit(AttendanceError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
