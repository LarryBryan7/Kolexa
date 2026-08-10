// ============================================================
// anecdotes_bloc.dart — BLoC + Models + DataSource de Anécdotas
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';

class AnecdoteModel {
  final int id;
  final int studentId;
  final String authorName;
  final String? authorAvatar;
  final String title;
  final String description;
  final String category; // 'general', 'behavior', 'academic', 'social', 'health'
  final bool isPrivate;
  final DateTime occurredAt;

  const AnecdoteModel({
    required this.id,
    required this.studentId,
    required this.authorName,
    this.authorAvatar,
    required this.title,
    required this.description,
    required this.category,
    required this.isPrivate,
    required this.occurredAt,
  });

  // Ícono por categoría para mostrar en la lista
  String get categoryIcon {
    switch (category) {
      case 'behavior': return '🔴';
      case 'academic': return '📚';
      case 'social': return '🤝';
      case 'health': return '🏥';
      default: return '📝';
    }
  }

  factory AnecdoteModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>? ?? {};
    return AnecdoteModel(
      id: int.parse(json['id'].toString()),
      studentId: int.parse(json['studentId'].toString()),
      authorName: '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}'.trim(),
      authorAvatar: author['avatar'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String? ?? 'general',
      isPrivate: json['isPrivate'] as bool? ?? false,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
    );
  }
}

class AnecdotesDataSource {
  final ApiClient _client;
  AnecdotesDataSource(this._client);

  Future<List<AnecdoteModel>> getForStudent(int studentId, {String role = 'parent'}) async {
    final r = await _client.get(
      'anecdotes/student/$studentId',
      queryParams: {'role': role},
    );
    return (r.data as List)
        .map((a) => AnecdoteModel.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  Future<AnecdoteModel> create({
    required int studentId,
    required String title,
    required String description,
    String category = 'general',
    bool isPrivate = false,
  }) async {
    final r = await _client.post('anecdotes', data: {
      'studentId': studentId,
      'title': title,
      'description': description,
      'category': category,
      'isPrivate': isPrivate,
    });
    return AnecdoteModel.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _client.delete('anecdotes/$id');
  }
}

// Events + States + BLoC
sealed class AnecdotesEvent { const AnecdotesEvent(); }
final class LoadAnecdotesEvent extends AnecdotesEvent {
  final int studentId;
  final String role;
  const LoadAnecdotesEvent(this.studentId, {this.role = 'parent'});
}
final class CreateAnecdoteEvent extends AnecdotesEvent {
  final int studentId;
  final String title;
  final String description;
  final String category;
  final bool isPrivate;
  const CreateAnecdoteEvent({
    required this.studentId,
    required this.title,
    required this.description,
    this.category = 'general',
    this.isPrivate = false,
  });
}
final class DeleteAnecdoteEvent extends AnecdotesEvent {
  final int id;
  final int studentId;
  const DeleteAnecdoteEvent({required this.id, required this.studentId});
}

sealed class AnecdotesState { const AnecdotesState(); }
final class AnecdotesInitial extends AnecdotesState { const AnecdotesInitial(); }
final class AnecdotesLoading extends AnecdotesState { const AnecdotesLoading(); }
final class AnecdotesLoaded extends AnecdotesState {
  final List<AnecdoteModel> anecdotes;
  const AnecdotesLoaded(this.anecdotes);
}
final class AnecdotesError extends AnecdotesState {
  final String message;
  const AnecdotesError(this.message);
}

class AnecdotesBloc extends Bloc<AnecdotesEvent, AnecdotesState> {
  final AnecdotesDataSource _ds;

  AnecdotesBloc(this._ds) : super(const AnecdotesInitial()) {
    on<LoadAnecdotesEvent>((e, emit) async {
      emit(const AnecdotesLoading());
      try {
        emit(AnecdotesLoaded(await _ds.getForStudent(e.studentId, role: e.role)));
      } catch (ex) {
        emit(AnecdotesError(ex.toString().replaceFirst('Exception: ', '')));
      }
    });

    on<CreateAnecdoteEvent>((e, emit) async {
      try {
        await _ds.create(
          studentId: e.studentId,
          title: e.title,
          description: e.description,
          category: e.category,
          isPrivate: e.isPrivate,
        );
        add(LoadAnecdotesEvent(e.studentId, role: 'teacher'));
      } catch (ex) {
        emit(AnecdotesError(ex.toString().replaceFirst('Exception: ', '')));
      }
    });

    on<DeleteAnecdoteEvent>((e, emit) async {
      try {
        await _ds.delete(e.id);
        add(LoadAnecdotesEvent(e.studentId, role: 'teacher'));
      } catch (ex) {
        emit(AnecdotesError(ex.toString().replaceFirst('Exception: ', '')));
      }
    });
  }
}
