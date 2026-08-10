// ============================================================
// pickup_bloc.dart — BLoC + Models + DataSource de Recojo
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';

// ── Models ────────────────────────────────────────────────

class AuthorizedPersonModel {
  final int id;
  final int studentId;
  final String fullName;
  final String relationship; // 'madre', 'padre', 'abuelo', etc.
  final String? documentId;
  final String? phone;
  final String? photoUrl;

  const AuthorizedPersonModel({
    required this.id,
    required this.studentId,
    required this.fullName,
    required this.relationship,
    this.documentId,
    this.phone,
    this.photoUrl,
  });

  factory AuthorizedPersonModel.fromJson(Map<String, dynamic> json) {
    return AuthorizedPersonModel(
      id: int.parse(json['id'].toString()),
      studentId: int.parse(json['studentId'].toString()),
      fullName: json['fullName'] as String,
      relationship: json['relationship'] as String,
      documentId: json['documentId'] as String?,
      phone: json['phone'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }
}

class PickupEventModel {
  final int id;
  final String pickedUpByName;
  final String? relationship;
  final String? photoUrl;
  final DateTime pickedUpAt;
  final String? notes;

  const PickupEventModel({
    required this.id,
    required this.pickedUpByName,
    this.relationship,
    this.photoUrl,
    required this.pickedUpAt,
    this.notes,
  });

  factory PickupEventModel.fromJson(Map<String, dynamic> json) {
    final authorized = json['authorizedPickup'] as Map<String, dynamic>?;
    return PickupEventModel(
      id: int.parse(json['id'].toString()),
      pickedUpByName: json['pickedUpByName'] as String,
      relationship: authorized?['relationship'] as String?,
      photoUrl: authorized?['photoUrl'] as String? ?? json['photoUrl'] as String?,
      pickedUpAt: DateTime.parse(json['pickedUpAt'] as String),
      notes: json['notes'] as String?,
    );
  }
}

// ── DataSource ────────────────────────────────────────────
class PickupDataSource {
  final ApiClient _client;
  PickupDataSource(this._client);

  Future<List<AuthorizedPersonModel>> getAuthorized(int studentId) async {
    final r = await _client.get('pickup/student/$studentId/authorized');
    return (r.data as List).map((e) => AuthorizedPersonModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AuthorizedPersonModel> addAuthorized({
    required int studentId,
    required String fullName,
    required String relationship,
    String? documentId,
    String? phone,
    String? photoUrl,
  }) async {
    final r = await _client.post('pickup/authorized', data: {
      'studentId': studentId,
      'fullName': fullName,
      'relationship': relationship,
      if (documentId != null) 'documentId': documentId,
      if (phone != null) 'phone': phone,
      if (photoUrl != null) 'photoUrl': photoUrl,
    });
    return AuthorizedPersonModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> removeAuthorized(int id) async {
    await _client.delete('pickup/authorized/$id');
  }

  Future<List<PickupEventModel>> getHistory(int studentId) async {
    final r = await _client.get('pickup/student/$studentId/history');
    return (r.data as List).map((e) => PickupEventModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}

// ── Events ────────────────────────────────────────────────
sealed class PickupEvent { const PickupEvent(); }

final class LoadAuthorizedEvent extends PickupEvent {
  final int studentId;
  const LoadAuthorizedEvent(this.studentId);
}

final class AddAuthorizedPersonEvent extends PickupEvent {
  final int studentId;
  final String fullName;
  final String relationship;
  final String? documentId;
  final String? phone;
  const AddAuthorizedPersonEvent({
    required this.studentId,
    required this.fullName,
    required this.relationship,
    this.documentId,
    this.phone,
  });
}

final class RemoveAuthorizedPersonEvent extends PickupEvent {
  final int pickupId;
  final int studentId;
  const RemoveAuthorizedPersonEvent({required this.pickupId, required this.studentId});
}

final class LoadPickupHistoryEvent extends PickupEvent {
  final int studentId;
  const LoadPickupHistoryEvent(this.studentId);
}

// ── States ────────────────────────────────────────────────
sealed class PickupState { const PickupState(); }
final class PickupInitial extends PickupState { const PickupInitial(); }
final class PickupLoading extends PickupState { const PickupLoading(); }

final class AuthorizedListLoaded extends PickupState {
  final List<AuthorizedPersonModel> persons;
  const AuthorizedListLoaded(this.persons);
}

final class PickupHistoryLoaded extends PickupState {
  final List<PickupEventModel> events;
  const PickupHistoryLoaded(this.events);
}

final class PickupError extends PickupState {
  final String message;
  const PickupError(this.message);
}

// ── BLoC ──────────────────────────────────────────────────
class PickupBloc extends Bloc<PickupEvent, PickupState> {
  final PickupDataSource _ds;

  PickupBloc(this._ds) : super(const PickupInitial()) {
    on<LoadAuthorizedEvent>(_onLoad);
    on<AddAuthorizedPersonEvent>(_onAdd);
    on<RemoveAuthorizedPersonEvent>(_onRemove);
    on<LoadPickupHistoryEvent>(_onHistory);
  }

  Future<void> _onLoad(LoadAuthorizedEvent e, Emitter<PickupState> emit) async {
    emit(const PickupLoading());
    try {
      emit(AuthorizedListLoaded(await _ds.getAuthorized(e.studentId)));
    } catch (ex) {
      emit(PickupError(ex.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onAdd(AddAuthorizedPersonEvent e, Emitter<PickupState> emit) async {
    emit(const PickupLoading());
    try {
      await _ds.addAuthorized(
        studentId: e.studentId,
        fullName: e.fullName,
        relationship: e.relationship,
        documentId: e.documentId,
        phone: e.phone,
      );
      add(LoadAuthorizedEvent(e.studentId));
    } catch (ex) {
      emit(PickupError(ex.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onRemove(RemoveAuthorizedPersonEvent e, Emitter<PickupState> emit) async {
    try {
      await _ds.removeAuthorized(e.pickupId);
      add(LoadAuthorizedEvent(e.studentId));
    } catch (ex) {
      emit(PickupError(ex.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onHistory(LoadPickupHistoryEvent e, Emitter<PickupState> emit) async {
    emit(const PickupLoading());
    try {
      emit(PickupHistoryLoaded(await _ds.getHistory(e.studentId)));
    } catch (ex) {
      emit(PickupError(ex.toString().replaceFirst('Exception: ', '')));
    }
  }
}
