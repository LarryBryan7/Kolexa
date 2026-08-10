// ============================================================
// homework_bloc.dart — BLoC de Tareas (Events + States + BLoC juntos)
// ============================================================
// Para módulos más simples, podemos tener events, states y bloc
// en un solo archivo. Cuando crezca, separar en tres archivos.
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/homework_model.dart';
import '../data/repositories/homework_repository.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// EVENTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sealed class HomeworkEvent {
  const HomeworkEvent();
}

// Cargar tareas del aula (vista del profesor)
final class LoadClassroomHomeworkEvent extends HomeworkEvent {
  final int classroomId;
  final bool forceRefresh;

  const LoadClassroomHomeworkEvent(
    this.classroomId, {
    this.forceRefresh = false,
  });
}

// Cargar tareas de un alumno (vista del padre)
final class LoadStudentHomeworkEvent extends HomeworkEvent {
  final int studentId;

  const LoadStudentHomeworkEvent(this.studentId);
}

// El profesor crea una nueva tarea
final class CreateHomeworkEvent extends HomeworkEvent {
  final int classroomId;
  final int courseId;
  final String title;
  final String description;
  final String dueDate;
  final bool notifyParents;

  const CreateHomeworkEvent({
    required this.classroomId,
    required this.courseId,
    required this.title,
    required this.description,
    required this.dueDate,
    this.notifyParents = true,
  });
}

// El profesor marca la entrega de un alumno
final class UpdateSubmissionEvent extends HomeworkEvent {
  final int homeworkId;
  final int studentId;
  final String status;
  final String? teacherNote;
  final int? grade;

  const UpdateSubmissionEvent({
    required this.homeworkId,
    required this.studentId,
    required this.status,
    this.teacherNote,
    this.grade,
  });
}

// El profesor elimina una tarea
final class DeleteHomeworkEvent extends HomeworkEvent {
  final int homeworkId;
  final int classroomId;

  const DeleteHomeworkEvent({
    required this.homeworkId,
    required this.classroomId,
  });
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// STATES
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sealed class HomeworkState {
  const HomeworkState();
}

final class HomeworkInitial extends HomeworkState {
  const HomeworkInitial();
}

final class HomeworkLoading extends HomeworkState {
  const HomeworkLoading();
}

// Lista de tareas del aula (profesor)
final class ClassroomHomeworkLoaded extends HomeworkState {
  final List<HomeworkModel> homeworks;
  final bool isCreating; // ¿se está creando una tarea nueva?

  const ClassroomHomeworkLoaded({
    required this.homeworks,
    this.isCreating = false,
  });

  ClassroomHomeworkLoaded copyWith({
    List<HomeworkModel>? homeworks,
    bool? isCreating,
  }) {
    return ClassroomHomeworkLoaded(
      homeworks: homeworks ?? this.homeworks,
      isCreating: isCreating ?? this.isCreating,
    );
  }
}

// Lista de tareas del alumno (padre)
final class StudentHomeworkLoaded extends HomeworkState {
  final List<StudentHomeworkModel> homeworks;

  const StudentHomeworkLoaded(this.homeworks);

  // Tareas agrupadas por estado para la UI
  List<StudentHomeworkModel> get pending =>
      homeworks.where((h) => h.status == HomeworkSubmissionStatus.pending).toList();
  List<StudentHomeworkModel> get submitted =>
      homeworks.where((h) => h.status != HomeworkSubmissionStatus.pending).toList();
}

final class HomeworkOperationSuccess extends HomeworkState {
  final String message;

  const HomeworkOperationSuccess(this.message);
}

final class HomeworkError extends HomeworkState {
  final String message;

  const HomeworkError(this.message);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BLOC
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class HomeworkBloc extends Bloc<HomeworkEvent, HomeworkState> {
  final HomeworkRepository _repository;

  HomeworkBloc(this._repository) : super(const HomeworkInitial()) {
    on<LoadClassroomHomeworkEvent>(_onLoadClassroom);
    on<LoadStudentHomeworkEvent>(_onLoadStudent);
    on<CreateHomeworkEvent>(_onCreate);
    on<UpdateSubmissionEvent>(_onUpdateSubmission);
    on<DeleteHomeworkEvent>(_onDelete);
  }

  Future<void> _onLoadClassroom(
    LoadClassroomHomeworkEvent event,
    Emitter<HomeworkState> emit,
  ) async {
    emit(const HomeworkLoading());
    try {
      final homeworks = await _repository.getClassroomHomework(
        event.classroomId,
        forceRefresh: event.forceRefresh,
      );
      emit(ClassroomHomeworkLoaded(homeworks: homeworks));
    } catch (e) {
      emit(HomeworkError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onLoadStudent(
    LoadStudentHomeworkEvent event,
    Emitter<HomeworkState> emit,
  ) async {
    emit(const HomeworkLoading());
    try {
      final homeworks = await _repository.getStudentHomework(event.studentId);
      emit(StudentHomeworkLoaded(homeworks));
    } catch (e) {
      emit(HomeworkError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onCreate(
    CreateHomeworkEvent event,
    Emitter<HomeworkState> emit,
  ) async {
    // Si ya hay una lista cargada, mostrar "creando..." sin borrar la lista
    if (state is ClassroomHomeworkLoaded) {
      emit((state as ClassroomHomeworkLoaded).copyWith(isCreating: true));
    } else {
      emit(const HomeworkLoading());
    }

    try {
      await _repository.createHomework(
        classroomId: event.classroomId,
        courseId: event.courseId,
        title: event.title,
        description: event.description,
        dueDate: event.dueDate,
        notifyParents: event.notifyParents,
      );

      // Recargar la lista del aula para incluir la nueva tarea
      final homeworks = await _repository.getClassroomHomework(
        event.classroomId,
        forceRefresh: true,
      );
      emit(ClassroomHomeworkLoaded(homeworks: homeworks));
    } catch (e) {
      emit(HomeworkError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onUpdateSubmission(
    UpdateSubmissionEvent event,
    Emitter<HomeworkState> emit,
  ) async {
    try {
      await _repository.updateSubmission(
        homeworkId: event.homeworkId,
        studentId: event.studentId,
        status: event.status,
        teacherNote: event.teacherNote,
        grade: event.grade,
      );
      emit(const HomeworkOperationSuccess('Entrega actualizada'));
    } catch (e) {
      emit(HomeworkError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onDelete(
    DeleteHomeworkEvent event,
    Emitter<HomeworkState> emit,
  ) async {
    try {
      await _repository.deleteHomework(event.homeworkId, event.classroomId);
      // Recargar la lista sin la tarea eliminada
      final homeworks = await _repository.getClassroomHomework(
        event.classroomId,
        forceRefresh: true,
      );
      emit(ClassroomHomeworkLoaded(homeworks: homeworks));
    } catch (e) {
      emit(HomeworkError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
