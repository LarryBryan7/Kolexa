// ============================================================
// homework_model.dart — Modelos de datos de Tareas
// ============================================================

// ── HomeworkStatus ────────────────────────────────────────
// Estado de la entrega de un alumno específico
enum HomeworkSubmissionStatus {
  pending,   // sin entregar
  submitted, // entregado, pendiente de revisión
  reviewed,  // el profesor la revisó
  late,      // entregado pero tarde
}

extension HomeworkSubmissionStatusExt on HomeworkSubmissionStatus {
  String get label {
    switch (this) {
      case HomeworkSubmissionStatus.pending:
        return 'Pendiente';
      case HomeworkSubmissionStatus.submitted:
        return 'Entregado';
      case HomeworkSubmissionStatus.reviewed:
        return 'Revisado';
      case HomeworkSubmissionStatus.late:
        return 'Entregado tarde';
    }
  }

  // Color asociado al estado
  int get colorValue {
    switch (this) {
      case HomeworkSubmissionStatus.pending:
        return 0xFFF59E0B; // amarillo
      case HomeworkSubmissionStatus.submitted:
        return 0xFF3B82F6; // azul
      case HomeworkSubmissionStatus.reviewed:
        return 0xFF10B981; // verde
      case HomeworkSubmissionStatus.late:
        return 0xFFEF4444; // rojo
    }
  }
}

HomeworkSubmissionStatus submissionStatusFromJson(String value) {
  switch (value) {
    case 'submitted':
      return HomeworkSubmissionStatus.submitted;
    case 'reviewed':
      return HomeworkSubmissionStatus.reviewed;
    case 'late':
      return HomeworkSubmissionStatus.late;
    case 'pending':
    default:
      return HomeworkSubmissionStatus.pending;
  }
}

// ── StudentSubmissionModel ────────────────────────────────
// La entrega de UN alumno para UNA tarea
class StudentSubmissionModel {
  final int studentId;
  final String studentFirstName;
  final String studentLastName;
  final String? studentCode;
  final HomeworkSubmissionStatus status;
  final String? teacherNote;
  final int? grade;           // calificación 0-20

  const StudentSubmissionModel({
    required this.studentId,
    required this.studentFirstName,
    required this.studentLastName,
    this.studentCode,
    required this.status,
    this.teacherNote,
    this.grade,
  });

  String get studentFullName => '$studentLastName, $studentFirstName';

  factory StudentSubmissionModel.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>;
    return StudentSubmissionModel(
      studentId: int.parse(student['id'].toString()),
      studentFirstName: student['firstName'] as String,
      studentLastName: student['lastName'] as String,
      studentCode: student['code'] as String?,
      status: submissionStatusFromJson(json['status'] as String),
      teacherNote: json['teacherNote'] as String?,
      grade: json['grade'] == null ? null : double.parse(json['grade'].toString()).toInt(),
    );
  }
}

// ── HomeworkModel ─────────────────────────────────────────
// Una tarea completa con todas sus entregas (vista del profesor)
class HomeworkModel {
  final int id;
  final int classroomId;
  final String courseName;
  final String teacherName;
  final String title;
  final String description;
  final DateTime dueDate;
  final bool notifyParents;
  final List<StudentSubmissionModel> submissions;
  final int attachmentCount;

  const HomeworkModel({
    required this.id,
    required this.classroomId,
    required this.courseName,
    required this.teacherName,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.notifyParents,
    required this.submissions,
    required this.attachmentCount,
  });

  // Estadísticas calculadas
  int get pendingCount =>
      submissions.where((s) => s.status == HomeworkSubmissionStatus.pending).length;
  int get submittedCount =>
      submissions.where((s) => s.status == HomeworkSubmissionStatus.submitted).length;
  int get reviewedCount =>
      submissions.where((s) => s.status == HomeworkSubmissionStatus.reviewed).length;
  int get lateCount =>
      submissions.where((s) => s.status == HomeworkSubmissionStatus.late).length;

  // ¿La tarea ya venció?
  bool get isOverdue => DateTime.now().isAfter(dueDate);

  // Días restantes (negativo si ya venció)
  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;

  factory HomeworkModel.fromJson(Map<String, dynamic> json) {
    final course = json['course'] as Map<String, dynamic>;
    final teacher = json['teacher'] as Map<String, dynamic>;
    final countMap = json['_count'] as Map<String, dynamic>? ?? {};

    return HomeworkModel(
      id: int.parse(json['id'].toString()),
      classroomId: int.parse(json['classroomId'].toString()),
      courseName: course['name'] as String,
      teacherName: '${teacher['firstName']} ${teacher['lastName']}',
      title: json['title'] as String,
      description: json['description'] as String,
      dueDate: DateTime.parse(json['dueDate'] as String),
      notifyParents: json['notifyParents'] as bool? ?? true,
      submissions: (json['submissions'] as List<dynamic>? ?? [])
          .map((s) => StudentSubmissionModel.fromJson(s as Map<String, dynamic>))
          .toList(),
      attachmentCount: countMap['attachments'] as int? ?? 0,
    );
  }
}

// ── StudentHomeworkModel ──────────────────────────────────
// La tarea vista desde el alumno/padre (con su estado de entrega)
class StudentHomeworkModel {
  final int id;
  final String courseName;
  final String classroomName;
  final String teacherName;
  final String title;
  final String description;
  final DateTime dueDate;
  final HomeworkSubmissionStatus status;
  final String? teacherNote;
  final int? grade;

  const StudentHomeworkModel({
    required this.id,
    required this.courseName,
    required this.classroomName,
    required this.teacherName,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    this.teacherNote,
    this.grade,
  });

  bool get isOverdue =>
      DateTime.now().isAfter(dueDate) && status == HomeworkSubmissionStatus.pending;

  factory StudentHomeworkModel.fromJson(Map<String, dynamic> json) {
    final hw = json['homework'] as Map<String, dynamic>;
    final course = hw['course'] as Map<String, dynamic>;
    final classroom = hw['classroom'] as Map<String, dynamic>;
    final teacher = hw['teacher'] as Map<String, dynamic>;

    return StudentHomeworkModel(
      id: int.parse(hw['id'].toString()),
      courseName: course['name'] as String,
      classroomName: classroom['name'] as String? ?? '${classroom['grade']} ${classroom['section']}',
      teacherName: '${teacher['firstName']} ${teacher['lastName']}',
      title: hw['title'] as String,
      description: hw['description'] as String,
      dueDate: DateTime.parse(hw['dueDate'] as String),
      status: submissionStatusFromJson(json['status'] as String),
      teacherNote: json['teacherNote'] as String?,
      grade: json['grade'] == null ? null : double.parse(json['grade'].toString()).toInt(),
    );
  }
}
