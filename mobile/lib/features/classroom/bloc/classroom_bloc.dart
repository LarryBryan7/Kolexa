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
      // Una sola petición HTTP combinada (connected + sync + courses + upcoming).
      // Reduce de 4 requests a 1, ahorrando el overhead de red de Railway
      // (~1.5s por request) y las consultas al pooler.
      final overview = await _repo.getOverview(event.studentId);
      if (!overview.connected) {
        emit(ClassroomNotConnected());
        return;
      }
      emit(ClassroomLoaded(courses: overview.courses, upcoming: overview.upcoming));
    } catch (e) {
      emit(ClassroomError(e.toString()));
    }
  }

  Future<void> _onConnect(ConnectClassroom event, Emitter<ClassroomState> emit) async {
    try {
      final url = await _repo.getAuthUrl(event.studentId);
      // inAppBrowserView (Custom Tabs): mismo motivo que en las otras 2
      // pantallas que conectan Classroom — evita el reinicio en frío al volver
      // del consentimiento de Google.
      await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      emit(ClassroomError('No se pudo abrir el navegador'));
    }
  }

  Future<void> _onConnectedCallback(
      ClassroomConnectedCallback event, Emitter<ClassroomState> emit) async {
    emit(ClassroomLoading());
    try {
      // Una sola petición combinada (sync + courses + upcoming).
      final overview = await _repo.getOverview(event.studentId);
      if (!overview.connected) {
        emit(ClassroomNotConnected());
        return;
      }
      emit(ClassroomLoaded(courses: overview.courses, upcoming: overview.upcoming));
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
      // Una sola petición combinada (sync + courses + upcoming).
      final overview = await _repo.getOverview(event.studentId);
      if (!overview.connected) {
        emit(ClassroomNotConnected());
        return;
      }
      emit(ClassroomLoaded(courses: overview.courses, upcoming: overview.upcoming));
    } catch (e) {
      emit(ClassroomError(e.toString()));
    }
  }
}
