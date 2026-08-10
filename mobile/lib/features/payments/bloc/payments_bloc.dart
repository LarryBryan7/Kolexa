// ============================================================
// payments_bloc.dart — BLoC + Models + DataSource de Pagos
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';

// ── Models ────────────────────────────────────────────────

class PaymentObligationModel {
  final int id;
  final String conceptName;
  final String? conceptDescription;
  final double amount;
  final String currency;
  final DateTime? dueDate;
  final String status; // 'pending', 'partial', 'paid'
  final DateTime? paidAt;
  final List<PaymentRecordModel> payments;

  const PaymentObligationModel({
    required this.id,
    required this.conceptName,
    this.conceptDescription,
    required this.amount,
    required this.currency,
    this.dueDate,
    required this.status,
    this.paidAt,
    required this.payments,
  });

  bool get isPaid => status == 'paid';
  bool get isOverdue => dueDate != null && DateTime.now().isAfter(dueDate!) && !isPaid;

  // Monto ya pagado (suma de todos los pagos parciales)
  double get amountPaid =>
      payments.fold(0.0, (sum, p) => sum + p.amountPaid);

  // Monto pendiente
  double get amountPending => amount - amountPaid;

  String get formattedAmount => '${currency} ${(amount / 100).toStringAsFixed(2)}';

  factory PaymentObligationModel.fromJson(Map<String, dynamic> json) {
    final concept = json['concept'] as Map<String, dynamic>? ?? {};
    return PaymentObligationModel(
      id: int.parse(json['id'].toString()),
      conceptName: concept['name'] as String? ?? 'Pago',
      conceptDescription: concept['description'] as String?,
      amount: double.parse(json['amount'].toString()),
      currency: json['currency'] as String? ?? 'PEN',
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      status: json['status'] as String,
      paidAt: json['paidAt'] != null
          ? DateTime.parse(json['paidAt'] as String)
          : null,
      payments: (json['payments'] as List<dynamic>? ?? [])
          .map((p) => PaymentRecordModel.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PaymentRecordModel {
  final double amountPaid;
  final DateTime paidAt;
  final String paymentMethod;

  const PaymentRecordModel({
    required this.amountPaid,
    required this.paidAt,
    required this.paymentMethod,
  });

  factory PaymentRecordModel.fromJson(Map<String, dynamic> json) {
    return PaymentRecordModel(
      amountPaid: double.parse(json['amountPaid'].toString()),
      paidAt: DateTime.parse(json['paidAt'] as String),
      paymentMethod: json['paymentMethod'] as String,
    );
  }
}

class StudentFinancialReport {
  final List<PaymentObligationModel> obligations;
  final double totalOwed;
  final double totalPaid;

  const StudentFinancialReport({
    required this.obligations,
    required this.totalOwed,
    required this.totalPaid,
  });

  List<PaymentObligationModel> get pending =>
      obligations.where((o) => !o.isPaid).toList();
  List<PaymentObligationModel> get paid =>
      obligations.where((o) => o.isPaid).toList();
  List<PaymentObligationModel> get overdue =>
      obligations.where((o) => o.isOverdue).toList();
}

// ── DataSource ────────────────────────────────────────────
class PaymentsDataSource {
  final ApiClient _client;
  PaymentsDataSource(this._client);

  Future<StudentFinancialReport> getStudentObligations(int studentId) async {
    final r = await _client.get('payments/student/$studentId');
    final data = r.data as Map<String, dynamic>;
    return StudentFinancialReport(
      obligations: (data['obligations'] as List)
          .map((o) => PaymentObligationModel.fromJson(o as Map<String, dynamic>))
          .toList(),
      totalOwed: double.parse(data['totalOwed'].toString()),
      totalPaid: double.parse(data['totalPaid'].toString()),
    );
  }
}

// ── Events + States + BLoC (compacto) ────────────────────
sealed class PaymentsEvent { const PaymentsEvent(); }
final class LoadStudentPaymentsEvent extends PaymentsEvent {
  final int studentId;
  const LoadStudentPaymentsEvent(this.studentId);
}

sealed class PaymentsState { const PaymentsState(); }
final class PaymentsInitial extends PaymentsState { const PaymentsInitial(); }
final class PaymentsLoading extends PaymentsState { const PaymentsLoading(); }
final class PaymentsLoaded extends PaymentsState {
  final StudentFinancialReport report;
  const PaymentsLoaded(this.report);
}
final class PaymentsError extends PaymentsState {
  final String message;
  const PaymentsError(this.message);
}

class PaymentsBloc extends Bloc<PaymentsEvent, PaymentsState> {
  final PaymentsDataSource _ds;

  PaymentsBloc(this._ds) : super(const PaymentsInitial()) {
    on<LoadStudentPaymentsEvent>((e, emit) async {
      emit(const PaymentsLoading());
      try {
        emit(PaymentsLoaded(await _ds.getStudentObligations(e.studentId)));
      } catch (ex) {
        emit(PaymentsError(ex.toString().replaceFirst('Exception: ', '')));
      }
    });
  }
}
