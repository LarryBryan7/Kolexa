// ============================================================
// grades_bloc.dart — BLoC + Models + DataSource de Notas
// ============================================================
// Gestiona las calificaciones del alumno.
// Vista del padre: boleta con notas por periodo y materia.
// Vista del profesor: notas de todos sus alumnos para ingresarlas.
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';

// ── Models ────────────────────────────────────────────────

class GradePeriodModel {
  final int id;
  final String name;       // "Primer Bimestre", "Segundo Trimestre"
  final DateTime startDate;
  final DateTime endDate;

  const GradePeriodModel({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  factory GradePeriodModel.fromJson(Map<String, dynamic> json) {
    return GradePeriodModel(
      id: int.parse(json['id'].toString()),
      name: json['name'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
    );
  }
}

class GradeModel {
  final int id;
  final int studentId;
  final int courseId;
  final String courseName;
  final int periodId;
  final String periodName;
  final double grade;     // 0-20
  final String? observations;
  final DateTime gradedAt;

  const GradeModel({
    required this.id,
    required this.studentId,
    required this.courseId,
    required this.courseName,
    required this.periodId,
    required this.periodName,
    required this.grade,
    this.observations,
    required this.gradedAt,
  });

  // ¿Aprobado? En el sistema peruano: nota ≥ 11
  bool get isPassing => grade >= 11;

  // Color visual según la nota
  int get colorValue {
    if (grade >= 18) return 0xFF10B981; // verde oscuro — excelente
    if (grade >= 14) return 0xFF3B82F6; // azul — bueno
    if (grade >= 11) return 0xFFF59E0B; // amarillo — aprobado
    return 0xFFEF4444;                  // rojo — desaprobado
  }

  factory GradeModel.fromJson(Map<String, dynamic> json) {
    final course = json['course'] as Map<String, dynamic>;
    final period = json['period'] as Map<String, dynamic>;
    return GradeModel(
      id: int.parse(json['id'].toString()),
      studentId: int.parse(json['studentId'].toString()),
      courseId: int.parse(json['courseId'].toString()),
      courseName: course['name'] as String,
      periodId: int.parse(json['periodId'].toString()),
      periodName: period['name'] as String,
      grade: double.parse(json['grade'].toString()),
      observations: json['observations'] as String?,
      gradedAt: DateTime.parse(json['gradedAt'] as String),
    );
  }
}

// Reporte completo del alumno: notas agrupadas por periodo
class StudentReportModel {
  final List<GradeModel> grades;
  final Map<String, List<GradeModel>> byPeriod; // periodId → notas

  const StudentReportModel({
    required this.grades,
    required this.byPeriod,
  });

  // Promedio general de todas las notas
  double get overallAverage {
    if (grades.isEmpty) return 0;
    return grades.fold(0.0, (sum, g) => sum + g.grade) / grades.length;
  }
}

// ── DataSource ────────────────────────────────────────────

class GradesDataSource {
  final ApiClient _client;

  GradesDataSource(this._client);

  Future<List<GradePeriodModel>> getPeriods() async {
    final response = await _client.get('grades/periods');
    return (response.data as List<dynamic>)
        .map((p) => GradePeriodModel.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<StudentReportModel> getStudentReport(int studentId) async {
    final response = await _client.get('grades/student/$studentId');
    final data = response.data as Map<String, dynamic>;
    final grades = (data['grades'] as List<dynamic>)
        .map((g) => GradeModel.fromJson(g as Map<String, dynamic>))
        .toList();

    // Agrupar por periodo usando el mapa que devuelve el backend
    final rawByPeriod = data['byPeriod'] as Map<String, dynamic>;
    final byPeriod = rawByPeriod.map((key, value) => MapEntry(
          key,
          (value as List<dynamic>)
              .map((g) => GradeModel.fromJson(g as Map<String, dynamic>))
              .toList(),
        ));

    return StudentReportModel(grades: grades, byPeriod: byPeriod);
  }

  Future<GradeModel> setGrade({
    required int studentId,
    required int courseId,
    required int periodId,
    required double grade,
    String? observations,
  }) async {
    final response = await _client.post('grades', data: {
      'studentId': studentId,
      'courseId': courseId,
      'periodId': periodId,
      'grade': grade,
      if (observations != null) 'observations': observations,
    });
    return GradeModel.fromJson(response.data as Map<String, dynamic>);
  }
}

// ── Events ────────────────────────────────────────────────
sealed class GradesEvent { const GradesEvent(); }

final class LoadStudentReportEvent extends GradesEvent {
  final int studentId;
  const LoadStudentReportEvent(this.studentId);
}

final class LoadPeriodsEvent extends GradesEvent {
  const LoadPeriodsEvent();
}

final class SetGradeEvent extends GradesEvent {
  final int studentId;
  final int courseId;
  final int periodId;
  final double grade;
  final String? observations;
  const SetGradeEvent({
    required this.studentId,
    required this.courseId,
    required this.periodId,
    required this.grade,
    this.observations,
  });
}

// ── States ────────────────────────────────────────────────
sealed class GradesState { const GradesState(); }

final class GradesInitial extends GradesState { const GradesInitial(); }
final class GradesLoading extends GradesState { const GradesLoading(); }

final class StudentReportLoaded extends GradesState {
  final StudentReportModel report;
  final List<GradePeriodModel> periods;
  const StudentReportLoaded({required this.report, required this.periods});
}

final class PeriodsLoaded extends GradesState {
  final List<GradePeriodModel> periods;
  const PeriodsLoaded(this.periods);
}

final class GradeSetSuccess extends GradesState {
  final GradeModel grade;
  const GradeSetSuccess(this.grade);
}

final class GradesError extends GradesState {
  final String message;
  const GradesError(this.message);
}

// ── BLoC ──────────────────────────────────────────────────
class GradesBloc extends Bloc<GradesEvent, GradesState> {
  final GradesDataSource _ds;

  GradesBloc(this._ds) : super(const GradesInitial()) {
    on<LoadStudentReportEvent>(_onLoadReport);
    on<LoadPeriodsEvent>(_onLoadPeriods);
    on<SetGradeEvent>(_onSetGrade);
  }

  Future<void> _onLoadReport(
    LoadStudentReportEvent event,
    Emitter<GradesState> emit,
  ) async {
    emit(const GradesLoading());
    try {
      final results = await Future.wait([
        _ds.getStudentReport(event.studentId),
        _ds.getPeriods(),
      ]);
      emit(StudentReportLoaded(
        report: results[0] as StudentReportModel,
        periods: results[1] as List<GradePeriodModel>,
      ));
    } catch (e) {
      emit(GradesError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onLoadPeriods(
    LoadPeriodsEvent event,
    Emitter<GradesState> emit,
  ) async {
    emit(const GradesLoading());
    try {
      final periods = await _ds.getPeriods();
      emit(PeriodsLoaded(periods));
    } catch (e) {
      emit(GradesError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onSetGrade(
    SetGradeEvent event,
    Emitter<GradesState> emit,
  ) async {
    try {
      final grade = await _ds.setGrade(
        studentId: event.studentId,
        courseId: event.courseId,
        periodId: event.periodId,
        grade: event.grade,
        observations: event.observations,
      );
      emit(GradeSetSuccess(grade));
    } catch (e) {
      emit(GradesError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
