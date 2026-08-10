// ============================================================
// suggestions_bloc.dart — BLoC + Models + DataSource de Sugerencias
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';

class SuggestionModel {
  final int id;
  final String category;
  final String title;
  final String description;
  final bool isAnonymous;
  final String status; // 'pending', 'reviewed', 'implemented', 'rejected'
  final DateTime createdAt;
  final List<SuggestionResponseModel> responses;

  const SuggestionModel({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.isAnonymous,
    required this.status,
    required this.createdAt,
    required this.responses,
  });

  String get statusLabel {
    switch (status) {
      case 'reviewed': return 'Revisada';
      case 'implemented': return 'Implementada';
      case 'rejected': return 'No procede';
      default: return 'Pendiente';
    }
  }

  int get statusColor {
    switch (status) {
      case 'reviewed': return 0xFF3B82F6;
      case 'implemented': return 0xFF10B981;
      case 'rejected': return 0xFFEF4444;
      default: return 0xFFF59E0B;
    }
  }

  factory SuggestionModel.fromJson(Map<String, dynamic> json) {
    return SuggestionModel(
      id: int.parse(json['id'].toString()),
      category: json['category'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      responses: (json['responses'] as List<dynamic>? ?? [])
          .map((r) => SuggestionResponseModel.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SuggestionResponseModel {
  final String response;
  final String responderName;
  final DateTime respondedAt;

  const SuggestionResponseModel({
    required this.response,
    required this.responderName,
    required this.respondedAt,
  });

  factory SuggestionResponseModel.fromJson(Map<String, dynamic> json) {
    final by = json['respondedBy'] as Map<String, dynamic>? ?? {};
    return SuggestionResponseModel(
      response: json['response'] as String,
      responderName: '${by['firstName'] ?? ''} ${by['lastName'] ?? ''}'.trim(),
      respondedAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class SuggestionsDataSource {
  final ApiClient _client;
  SuggestionsDataSource(this._client);

  Future<List<SuggestionModel>> getMySuggestions() async {
    final r = await _client.get('suggestions/my');
    return (r.data as List).map((s) => SuggestionModel.fromJson(s as Map<String, dynamic>)).toList();
  }

  Future<SuggestionModel> submit({
    required String category,
    required String title,
    required String description,
    bool isAnonymous = false,
  }) async {
    final r = await _client.post('suggestions', data: {
      'category': category,
      'title': title,
      'description': description,
      'isAnonymous': isAnonymous,
    });
    return SuggestionModel.fromJson(r.data as Map<String, dynamic>);
  }
}

// Events + States + BLoC
sealed class SuggestionsEvent { const SuggestionsEvent(); }
final class LoadMySuggestionsEvent extends SuggestionsEvent { const LoadMySuggestionsEvent(); }
final class SubmitSuggestionEvent extends SuggestionsEvent {
  final String category;
  final String title;
  final String description;
  final bool isAnonymous;
  const SubmitSuggestionEvent({
    required this.category,
    required this.title,
    required this.description,
    this.isAnonymous = false,
  });
}

sealed class SuggestionsState { const SuggestionsState(); }
final class SuggestionsInitial extends SuggestionsState { const SuggestionsInitial(); }
final class SuggestionsLoading extends SuggestionsState { const SuggestionsLoading(); }
final class SuggestionsLoaded extends SuggestionsState {
  final List<SuggestionModel> suggestions;
  const SuggestionsLoaded(this.suggestions);
}
final class SuggestionSubmitted extends SuggestionsState { const SuggestionSubmitted(); }
final class SuggestionsError extends SuggestionsState {
  final String message;
  const SuggestionsError(this.message);
}

class SuggestionsBloc extends Bloc<SuggestionsEvent, SuggestionsState> {
  final SuggestionsDataSource _ds;

  SuggestionsBloc(this._ds) : super(const SuggestionsInitial()) {
    on<LoadMySuggestionsEvent>((e, emit) async {
      emit(const SuggestionsLoading());
      try {
        emit(SuggestionsLoaded(await _ds.getMySuggestions()));
      } catch (ex) {
        emit(SuggestionsError(ex.toString().replaceFirst('Exception: ', '')));
      }
    });

    on<SubmitSuggestionEvent>((e, emit) async {
      emit(const SuggestionsLoading());
      try {
        await _ds.submit(
          category: e.category,
          title: e.title,
          description: e.description,
          isAnonymous: e.isAnonymous,
        );
        emit(const SuggestionSubmitted());
        add(const LoadMySuggestionsEvent());
      } catch (ex) {
        emit(SuggestionsError(ex.toString().replaceFirst('Exception: ', '')));
      }
    });
  }
}
