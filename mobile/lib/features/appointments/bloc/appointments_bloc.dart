// ============================================================
// appointments_bloc.dart — BLoC + Models + DataSource de Citas
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';

// ── Models ────────────────────────────────────────────────

class AppointmentSlotModel {
  final int id;
  final int teacherId;
  final String teacherName;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final int maxBookings;
  final int bookingCount;   // cuántos padres ya reservaron
  final bool isAvailable;

  const AppointmentSlotModel({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.startTime,
    required this.endTime,
    this.location,
    required this.maxBookings,
    required this.bookingCount,
    required this.isAvailable,
  });

  bool get isFull => bookingCount >= maxBookings;

  // Getters de formato para la UI
  String get formattedDate {
    final m = startTime.month.toString().padLeft(2, '0');
    final d = startTime.day.toString().padLeft(2, '0');
    return '${startTime.year}-$m-$d';
  }

  String get formattedTime {
    final sh = startTime.hour.toString().padLeft(2, '0');
    final sm = startTime.minute.toString().padLeft(2, '0');
    final eh = endTime.hour.toString().padLeft(2, '0');
    final em = endTime.minute.toString().padLeft(2, '0');
    return '$sh:$sm - $eh:$em';
  }

  factory AppointmentSlotModel.fromJson(Map<String, dynamic> json) {
    final teacher = json['teacher'] as Map<String, dynamic>?;
    final countMap = json['_count'] as Map<String, dynamic>? ?? {};
    return AppointmentSlotModel(
      id: int.parse(json['id'].toString()),
      teacherId: int.parse(json['teacherId'].toString()),
      teacherName: teacher != null
          ? '${teacher['firstName']} ${teacher['lastName']}'
          : 'Profesor',
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      location: json['location'] as String?,
      maxBookings: json['maxBookings'] as int? ?? 1,
      bookingCount: countMap['appointments'] as int? ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }
}

class AppointmentModel {
  final int id;
  final String teacherName;
  final String? teacherAvatar;
  final String studentName;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String reason;
  final String status; // 'scheduled', 'completed', 'cancelled', 'no_show'
  final String? teacherNotes;

  const AppointmentModel({
    required this.id,
    required this.teacherName,
    this.teacherAvatar,
    required this.studentName,
    required this.startTime,
    required this.endTime,
    this.location,
    required this.reason,
    required this.status,
    this.teacherNotes,
  });

  bool get isUpcoming => startTime.isAfter(DateTime.now());

  String get formattedDate {
    final m = startTime.month.toString().padLeft(2, '0');
    final d = startTime.day.toString().padLeft(2, '0');
    return '$d/$m/${startTime.year}';
  }

  String get formattedTime {
    final sh = startTime.hour.toString().padLeft(2, '0');
    final sm = startTime.minute.toString().padLeft(2, '0');
    return '$sh:$sm';
  }

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    final slot = json['slot'] as Map<String, dynamic>;
    final teacher = slot['teacher'] as Map<String, dynamic>? ?? {};
    final student = json['student'] as Map<String, dynamic>? ?? {};
    return AppointmentModel(
      id: int.parse(json['id'].toString()),
      teacherName: '${teacher['firstName'] ?? ''} ${teacher['lastName'] ?? ''}'.trim(),
      teacherAvatar: teacher['avatar'] as String?,
      studentName: '${student['firstName'] ?? ''} ${student['lastName'] ?? ''}'.trim(),
      startTime: DateTime.parse(slot['startTime'] as String),
      endTime: DateTime.parse(slot['endTime'] as String),
      location: slot['location'] as String?,
      reason: json['reason'] as String,
      status: json['status'] as String,
      teacherNotes: json['teacherNotes'] as String?,
    );
  }
}

// ── DataSource ────────────────────────────────────────────

class AppointmentsDataSource {
  final ApiClient _client;
  AppointmentsDataSource(this._client);

  Future<List<AppointmentSlotModel>> getAvailableSlots() async {
    final response = await _client.get('appointments/slots');
    return (response.data as List<dynamic>)
        .map((s) => AppointmentSlotModel.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<List<AppointmentSlotModel>> getTeacherSlots(int teacherId) async {
    final response = await _client.get('appointments/slots/$teacherId');
    return (response.data as List<dynamic>)
        .map((s) => AppointmentSlotModel.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<AppointmentModel> bookAppointment({
    required int slotId,
    required int studentId,
    required String reason,
  }) async {
    final response = await _client.post('appointments', data: {
      'slotId': slotId,
      'studentId': studentId,
      'reason': reason,
    });
    return AppointmentModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<AppointmentModel>> getMyAppointments({String role = 'parent'}) async {
    final response = await _client.get(
      'appointments/my',
      queryParams: {'role': role},
    );
    return (response.data as List<dynamic>)
        .map((a) => AppointmentModel.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  Future<void> createSlot({
    required DateTime startTime,
    required DateTime endTime,
    required int maxBookings,
    String? location,
  }) async {
    await _client.post('appointments/slots', data: {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'maxBookings': maxBookings,
      if (location != null) 'location': location,
    });
  }

  Future<void> updateStatus(int appointmentId, String status, {String? notes}) async {
    await _client.patch('appointments/$appointmentId/status', data: {
      'status': status,
      if (notes != null) 'notes': notes,
    });
  }
}

// ── Events ────────────────────────────────────────────────
sealed class AppointmentsEvent { const AppointmentsEvent(); }

final class LoadAvailableSlotsEvent extends AppointmentsEvent {
  const LoadAvailableSlotsEvent();
}

final class LoadTeacherSlotsEvent extends AppointmentsEvent {
  final int teacherId;
  const LoadTeacherSlotsEvent(this.teacherId);
}

final class LoadMyAppointmentsEvent extends AppointmentsEvent {
  final String role;
  const LoadMyAppointmentsEvent({this.role = 'parent'});
}

final class BookAppointmentEvent extends AppointmentsEvent {
  final int slotId;
  final int studentId;
  final String reason;
  const BookAppointmentEvent({
    required this.slotId,
    required this.studentId,
    required this.reason,
  });
}

final class CreateSlotEvent extends AppointmentsEvent {
  final DateTime startTime;
  final DateTime endTime;
  final int maxBookings;
  final String? location;
  const CreateSlotEvent({
    required this.startTime,
    required this.endTime,
    this.maxBookings = 1,
    this.location,
  });
}

final class UpdateAppointmentStatusEvent extends AppointmentsEvent {
  final int appointmentId;
  final String status;
  final String? notes;
  const UpdateAppointmentStatusEvent({
    required this.appointmentId,
    required this.status,
    this.notes,
  });
}

// ── States ────────────────────────────────────────────────
sealed class AppointmentsState { const AppointmentsState(); }

final class AppointmentsInitial extends AppointmentsState { const AppointmentsInitial(); }
final class AppointmentsLoading extends AppointmentsState { const AppointmentsLoading(); }

final class SlotsLoaded extends AppointmentsState {
  final List<AppointmentSlotModel> slots;
  const SlotsLoaded(this.slots);
}

final class MyAppointmentsLoaded extends AppointmentsState {
  final List<AppointmentModel> upcoming;
  final List<AppointmentModel> past;
  const MyAppointmentsLoaded({required this.upcoming, required this.past});
}

final class AppointmentBooked extends AppointmentsState {
  final AppointmentModel appointment;
  const AppointmentBooked(this.appointment);
}

final class AppointmentsError extends AppointmentsState {
  final String message;
  const AppointmentsError(this.message);
}

// ── BLoC ──────────────────────────────────────────────────
class AppointmentsBloc extends Bloc<AppointmentsEvent, AppointmentsState> {
  final AppointmentsDataSource _ds;

  AppointmentsBloc(this._ds) : super(const AppointmentsInitial()) {
    on<LoadAvailableSlotsEvent>(_onLoadAvailableSlots);
    on<LoadTeacherSlotsEvent>(_onLoadSlots);
    on<LoadMyAppointmentsEvent>(_onLoadMy);
    on<BookAppointmentEvent>(_onBook);
    on<CreateSlotEvent>(_onCreateSlot);
    on<UpdateAppointmentStatusEvent>(_onUpdateStatus);
  }

  Future<void> _onLoadAvailableSlots(
    LoadAvailableSlotsEvent event,
    Emitter<AppointmentsState> emit,
  ) async {
    emit(const AppointmentsLoading());
    try {
      final slots = await _ds.getAvailableSlots();
      emit(SlotsLoaded(slots));
    } catch (e) {
      emit(AppointmentsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onLoadSlots(
    LoadTeacherSlotsEvent event,
    Emitter<AppointmentsState> emit,
  ) async {
    emit(const AppointmentsLoading());
    try {
      final slots = await _ds.getTeacherSlots(event.teacherId);
      emit(SlotsLoaded(slots));
    } catch (e) {
      emit(AppointmentsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onLoadMy(
    LoadMyAppointmentsEvent event,
    Emitter<AppointmentsState> emit,
  ) async {
    emit(const AppointmentsLoading());
    try {
      final appts = await _ds.getMyAppointments(role: event.role);
      final now = DateTime.now();
      emit(MyAppointmentsLoaded(
        upcoming: appts.where((a) => a.startTime.isAfter(now)).toList(),
        past: appts.where((a) => !a.startTime.isAfter(now)).toList(),
      ));
    } catch (e) {
      emit(AppointmentsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onCreateSlot(
    CreateSlotEvent event,
    Emitter<AppointmentsState> emit,
  ) async {
    try {
      await _ds.createSlot(
        startTime: event.startTime,
        endTime: event.endTime,
        maxBookings: event.maxBookings,
        location: event.location,
      );
      // Recarga los slots del docente actual
      add(const LoadMyAppointmentsEvent(role: 'teacher'));
    } catch (e) {
      emit(AppointmentsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onBook(
    BookAppointmentEvent event,
    Emitter<AppointmentsState> emit,
  ) async {
    emit(const AppointmentsLoading());
    try {
      final appt = await _ds.bookAppointment(
        slotId: event.slotId,
        studentId: event.studentId,
        reason: event.reason,
      );
      emit(AppointmentBooked(appt));
    } catch (e) {
      emit(AppointmentsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onUpdateStatus(
    UpdateAppointmentStatusEvent event,
    Emitter<AppointmentsState> emit,
  ) async {
    try {
      await _ds.updateStatus(event.appointmentId, event.status, notes: event.notes);
      add(const LoadMyAppointmentsEvent());
    } catch (e) {
      emit(AppointmentsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
