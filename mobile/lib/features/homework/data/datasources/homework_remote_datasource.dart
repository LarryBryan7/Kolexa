// ============================================================
// homework_remote_datasource.dart — DataSource de Tareas
// ============================================================

import '../../../../core/api/api_client.dart';
import '../models/homework_model.dart';

class HomeworkRemoteDataSource {
  final ApiClient _client;

  HomeworkRemoteDataSource(this._client);

  // Crear tarea (profesor)
  Future<HomeworkModel> createHomework({
    required int classroomId,
    required int courseId,
    required String title,
    required String description,
    required String dueDate,
    bool notifyParents = true,
  }) async {
    final response = await _client.post('homework', data: {
      'classroomId': classroomId,
      'courseId': courseId,
      'title': title,
      'description': description,
      'dueDate': dueDate,
      'notifyParents': notifyParents,
    });
    return HomeworkModel.fromJson(response.data as Map<String, dynamic>);
  }

  // Tareas del aula (lista del profesor)
  Future<List<HomeworkModel>> getClassroomHomework(int classroomId) async {
    final response = await _client.get('homework/classroom/$classroomId');
    return (response.data as List<dynamic>)
        .map((h) => HomeworkModel.fromJson(h as Map<String, dynamic>))
        .toList();
  }

  // Tareas de un alumno (vista del padre)
  Future<List<StudentHomeworkModel>> getStudentHomework(int studentId) async {
    final response = await _client.get('homework/student/$studentId');
    return (response.data as List<dynamic>)
        .map((h) => StudentHomeworkModel.fromJson(h as Map<String, dynamic>))
        .toList();
  }

  // Detalle de una tarea con todas las entregas
  Future<HomeworkModel> getHomework(int homeworkId) async {
    final response = await _client.get('homework/$homeworkId');
    return HomeworkModel.fromJson(response.data as Map<String, dynamic>);
  }

  // Marcar entrega de un alumno como revisada
  Future<void> updateSubmission({
    required int homeworkId,
    required int studentId,
    required String status,
    String? teacherNote,
    int? grade,
  }) async {
    await _client.patch(
      'homework/$homeworkId/students/$studentId',
      data: {
        'status': status,
        if (teacherNote != null) 'teacherNote': teacherNote,
        if (grade != null) 'grade': grade,
      },
    );
  }

  // Eliminar tarea
  Future<void> deleteHomework(int homeworkId) async {
    await _client.delete('homework/$homeworkId');
  }
}
