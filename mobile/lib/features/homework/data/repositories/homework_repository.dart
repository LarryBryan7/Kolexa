// ============================================================
// homework_repository.dart — Repositorio de Tareas
// ============================================================
// Coordina el DataSource remoto con la caché en memoria.
// Dos modos: vista del profesor (HomeworkModel) y
//            vista del padre/alumno (StudentHomeworkModel).
// ============================================================

import '../datasources/homework_remote_datasource.dart';
import '../models/homework_model.dart';

class HomeworkRepository {
  final HomeworkRemoteDataSource _remote;

  // Caché simple en memoria: classroomId → lista de tareas
  final Map<int, List<HomeworkModel>> _classroomCache = {};

  HomeworkRepository(this._remote);

  // Obtener tareas del aula (con caché)
  Future<List<HomeworkModel>> getClassroomHomework(
    int classroomId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _classroomCache.containsKey(classroomId)) {
      return _classroomCache[classroomId]!;
    }

    final homeworks = await _remote.getClassroomHomework(classroomId);
    _classroomCache[classroomId] = homeworks;
    return homeworks;
  }

  // Obtener tareas de un alumno (el padre las ve)
  Future<List<StudentHomeworkModel>> getStudentHomework(int studentId) async {
    return _remote.getStudentHomework(studentId);
  }

  // Crear nueva tarea
  Future<HomeworkModel> createHomework({
    required int classroomId,
    required int courseId,
    required String title,
    required String description,
    required String dueDate,
    bool notifyParents = true,
  }) async {
    final homework = await _remote.createHomework(
      classroomId: classroomId,
      courseId: courseId,
      title: title,
      description: description,
      dueDate: dueDate,
      notifyParents: notifyParents,
    );

    // Invalidar caché del aula para forzar recarga
    _classroomCache.remove(classroomId);
    return homework;
  }

  // Marcar entrega de un alumno
  Future<void> updateSubmission({
    required int homeworkId,
    required int studentId,
    required String status,
    String? teacherNote,
    int? grade,
  }) async {
    await _remote.updateSubmission(
      homeworkId: homeworkId,
      studentId: studentId,
      status: status,
      teacherNote: teacherNote,
      grade: grade,
    );
    // Invalidar caché completa porque no sabemos qué aula afecta
    _classroomCache.clear();
  }

  // Eliminar tarea
  Future<void> deleteHomework(int homeworkId, int classroomId) async {
    await _remote.deleteHomework(homeworkId);
    _classroomCache.remove(classroomId);
  }
}
