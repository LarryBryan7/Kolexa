// ============================================================
// attendance_state.dart — Estados del BLoC de Asistencia
// ============================================================
// Estados posibles de la pantalla de asistencia:
//
//   AttendanceInitial    → estado inicial, nada cargado
//   AttendanceLoading    → cargando desde el backend
//   AttendanceLoaded     → sesión cargada, el profesor puede marcar
//   AttendanceSaving     → guardando cambios al backend
//   AttendanceSaved      → guardado exitoso (muestra confirmación)
//   AttendanceError      → error en alguna operación
//   AttendanceHistoryLoaded → historial del alumno cargado
// ============================================================

import '../data/models/attendance_model.dart';

sealed class AttendanceState {
  const AttendanceState();
}

// Estado inicial cuando el BLoC se acaba de crear
final class AttendanceInitial extends AttendanceState {
  const AttendanceInitial();
}

// Cargando la sesión desde el backend
final class AttendanceLoading extends AttendanceState {
  const AttendanceLoading();
}

// ── AttendanceLoaded ──────────────────────────────────────
// La sesión está cargada y lista para que el profesor la edite.
// Este es el estado principal de la pantalla del profesor.
//
// Tiene dos subestados implícitos controlados por 'isSaving':
//   isSaving = false → el profesor puede editar
//   isSaving = true  → se está guardando (deshabilitar botones)
final class AttendanceLoaded extends AttendanceState {
  final AttendanceSessionModel session;
  final bool isSaving;      // ¿se está guardando ahora mismo?
  final bool justSaved;     // ¿se acaba de guardar? (para mostrar confirmación)
  final bool hasChanges;    // ¿hay cambios sin guardar?

  const AttendanceLoaded({
    required this.session,
    this.isSaving = false,
    this.justSaved = false,
    this.hasChanges = false,
  });

  // copyWith para crear versiones modificadas del estado
  AttendanceLoaded copyWith({
    AttendanceSessionModel? session,
    bool? isSaving,
    bool? justSaved,
    bool? hasChanges,
  }) {
    return AttendanceLoaded(
      session: session ?? this.session,
      isSaving: isSaving ?? this.isSaving,
      justSaved: justSaved ?? this.justSaved,
      hasChanges: hasChanges ?? this.hasChanges,
    );
  }
}

// Error en cualquier operación (carga, guardado, etc.)
final class AttendanceError extends AttendanceState {
  final String message;

  const AttendanceError(this.message);
}

// ── AttendanceHistoryLoaded ───────────────────────────────
// El historial del alumno está cargado (vista del padre de familia).
final class AttendanceHistoryLoaded extends AttendanceState {
  final List<dynamic> records; // lista de AttendanceRecord con sesión incluida
  final int total;             // total de registros (para paginación)
  final Map<String, int> stats; // {'present': 45, 'absent': 3, ...}

  const AttendanceHistoryLoaded({
    required this.records,
    required this.total,
    required this.stats,
  });

  // Porcentaje de asistencia calculado desde las estadísticas
  double get attendanceRate {
    final present = stats['present'] ?? 0;
    final late = stats['late'] ?? 0;
    if (total == 0) return 0;
    return (present + late) / total * 100;
  }
}
