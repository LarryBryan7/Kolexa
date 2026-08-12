import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models/gc_models.dart';
import '../data/repository/classroom_repository.dart';

// ── Events ────────────────────────────────────────────────
abstract class ClassroomEvent extends Equatable {
  const ClassroomEvent();
  @override
  List<Object?> get props => [];
}

class LoadClassroom extends ClassroomEvent {
  final String studentId;
  const LoadClassroom(this.studentId);
  @override
  List<Object?> get props => [studentId];
}

class ConnectClassroom extends ClassroomEvent {
  final String studentId;
  const ConnectClassroom(this.studentId);
  @override
  List<Object?> get props => [studentId];
}

class ClassroomConnectedCallback extends ClassroomEvent {
  final String studentId;
  const ClassroomConnectedCallback(this.studentId);
  @override
  List<Object?> get props => [studentId];
}

class SyncClassroom extends ClassroomEvent {
  final String studentId;
  const SyncClassroom(this.studentId);
  @override
  List<Object?> get props => [studentId];
}

// ── States ────────────────────────────────────────────────
abstract class ClassroomState extends Equatable {
  const ClassroomState();
  @override
  List<Object?> get props => [];
}

class ClassroomInitial extends ClassroomState {}

class ClassroomLoading extends ClassroomState {}

class ClassroomSyncing extends ClassroomState {
  final List<GcCourse> courses;
  final List<GcCoursework> upcoming;
  const ClassroomSyncing({required this.courses, required this.upcoming});
  @override
  List<Object?> get props => [courses, upcoming];
}

class ClassroomNotConnected extends ClassroomState {}

class ClassroomLoaded extends ClassroomState {
  final List<GcCourse> courses;
  final List<GcCoursework> upcoming;
  const ClassroomLoaded({required this.courses, required this.upcoming});
  @override
  List<Object?> get props => [courses, upcoming];
}

class ClassroomError extends ClassroomState {
  final String message;
  const ClassroomError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ──────────────────────────────────────────────────
class ClassroomBloc extends Bloc<ClassroomEvent, ClassroomState> {
  final ClassroomRepository _repo;

  ClassroomBloc(this._repo) : super(ClassroomInitial()) {
    on<LoadClassroom>(_onLoad);
    on<ConnectClassroom>(_onConnect);
    on<ClassroomConnectedCallback>(_onConnectedCallback);
    on<SyncClassroom>(_onSync);
  }

  Future<void> _onLoad(LoadClassroom event, Emitter<ClassroomState> emit) async {
    emit(ClassroomLoading());
    try {
      final connected = await _repo.isConnected(event.studentId);
      if (!connected) {
        emit(ClassroomNotConnected());
        return;
      }
      // Muestra datos cacheados primero (respuesta inmediata).
      // getCourses + getUpcoming se lanzan EN PARALELO (Future.wait) para
      // reducir el tiempo: con el pooler de Supabase (~1.9s por consulta),
      // secuencial serían ~4s, en paralelo ~2s.
      final results = await Future.wait([
        _repo.getCourses(event.studentId),
        _repo.getUpcoming(event.studentId),
      ]);
      final courses = results[0] as List<GcCourse>;
      final upcoming = results[1] as List<GcCoursework>;
      emit(ClassroomLoaded(courses: courses, upcoming: upcoming));

      // Luego sincroniza en segundo plano y refresca.
      emit(ClassroomSyncing(courses: courses, upcoming: upcoming));
      final syncResult = await _repo.sync(event.studentId);
      // Si el sync no cambió los conteos (caché activo), NO recargamos
      // courses/upcoming (evita 2 consultas redundantes al pooler).
      if (syncResult['courses'] == courses.length &&
          syncResult['courseworks'] == upcoming.length) {
        emit(ClassroomLoaded(courses: courses, upcoming: upcoming));
        return;
      }
      // Si cambió, recargamos en paralelo.
      final freshResults = await Future.wait([
        _repo.getCourses(event.studentId),
        _repo.getUpcoming(event.studentId),
      ]);
      emit(ClassroomLoaded(
        courses: freshResults[0] as List<GcCourse>,
        upcoming: freshResults[1] as List<GcCoursework>,
      ));
    } catch (e) {
      emit(ClassroomError(e.toString()));
    }
  }

  Future<void> _onConnect(ConnectClassroom event, Emitter<ClassroomState> emit) async {
    try {
      final url = await _repo.getAuthUrl(event.studentId);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      emit(ClassroomError('No se pudo abrir el navegador'));
    }
  }

  Future<void> _onConnectedCallback(
      ClassroomConnectedCallback event, Emitter<ClassroomState> emit) async {
    emit(ClassroomLoading());
    try {
      // Sincronizar inmediatamente tras conectar
      await _repo.sync(event.studentId);
      // Cargar courses + upcoming EN PARALELO
      final results = await Future.wait([
        _repo.getCourses(event.studentId),
        _repo.getUpcoming(event.studentId),
      ]);
      emit(ClassroomLoaded(
        courses: results[0] as List<GcCourse>,
        upcoming: results[1] as List<GcCoursework>,
      ));
    } catch (e) {
      emit(ClassroomError(e.toString()));
    }
  }

  Future<void> _onSync(SyncClassroom event, Emitter<ClassroomState> emit) async {
    final current = state;
    List<GcCourse> courses = [];
    List<GcCoursework> upcoming = [];
    if (current is ClassroomLoaded) {
      courses = current.courses;
      upcoming = current.upcoming;
    }
    emit(ClassroomSyncing(courses: courses, upcoming: upcoming));
    try {
      final syncResult = await _repo.sync(event.studentId);
      // Si el sync no cambió los conteos (caché activo), NO recargamos.
      if (syncResult['courses'] == courses.length &&
          syncResult['courseworks'] == upcoming.length) {
        emit(ClassroomLoaded(courses: courses, upcoming: upcoming));
        return;
      }
      // Si cambió, recargamos en paralelo.
      final results = await Future.wait([
        _repo.getCourses(event.studentId),
        _repo.getUpcoming(event.studentId),
      ]);
      emit(ClassroomLoaded(
        courses: results[0] as List<GcCourse>,
        upcoming: results[1] as List<GcCoursework>,
      ));
    } catch (e) {
      emit(ClassroomError(e.toString()));
    }
  }
}
