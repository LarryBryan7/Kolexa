// ============================================================
// payments_page.dart — Pantalla de Pagos / Finanzas del alumno
// ============================================================
// Muestra obligaciones pendientes, vencidas y pagadas.
// Secciones coloreadas según el estado de cada pago.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/payments_bloc.dart';

class PaymentsPage extends StatefulWidget {
  final int studentId;
  final String studentName;

  const PaymentsPage({super.key, required this.studentId, required this.studentName});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  @override
  void initState() {
    super.initState();
    context.read<PaymentsBloc>().add(LoadStudentPaymentsEvent(widget.studentId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pagos · ${widget.studentName}')),
      body: BlocBuilder<PaymentsBloc, PaymentsState>(
        builder: (context, state) {
          if (state is PaymentsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is PaymentsError) {
            return Center(child: Text(state.message));
          }
          if (state is PaymentsLoaded) {
            final report = state.report;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Resumen financiero ────────────────────────
                _FinancialSummaryCard(report: report),
                const SizedBox(height: 20),

                // ── Vencidas (rojo) ───────────────────────────
                if (report.overdue.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'VENCIDAS',
                    count: report.overdue.length,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 8),
                  ...report.overdue.map((o) => _ObligationCard(obligation: o)),
                  const SizedBox(height: 16),
                ],

                // ── Pendientes (amarillo) ─────────────────────
                if (report.pending.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'PENDIENTES',
                    count: report.pending.length,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  ...report.pending
                      .where((o) => !o.isOverdue)
                      .map((o) => _ObligationCard(obligation: o)),
                  const SizedBox(height: 16),
                ],

                // ── Pagadas (verde) ───────────────────────────
                if (report.paid.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'PAGADAS',
                    count: report.paid.length,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 8),
                  ...report.paid.map((o) => _ObligationCard(obligation: o)),
                ],
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ── Resumen con totales ───────────────────────────────────────
class _FinancialSummaryCard extends StatelessWidget {
  final StudentFinancialReport report;
  const _FinancialSummaryCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final pending = report.totalOwed - report.totalPaid;

    return Card(
      elevation: 0,
      color: const Color(0xFF6366F1).withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF6366F1), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Total adeudado',
                value: 'S/ ${(report.totalOwed / 100).toStringAsFixed(2)}',
                color: Colors.black87,
              ),
            ),
            Container(width: 1, height: 40, color: Colors.grey.shade300),
            Expanded(
              child: _Stat(
                label: 'Pagado',
                value: 'S/ ${(report.totalPaid / 100).toStringAsFixed(2)}',
                color: Colors.green,
              ),
            ),
            Container(width: 1, height: 40, color: Colors.grey.shade300),
            Expanded(
              child: _Stat(
                label: 'Pendiente',
                value: 'S/ ${(pending / 100).toStringAsFixed(2)}',
                color: pending > 0 ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SectionHeader({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$label ($count)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }
}

// ── Tarjeta de obligación ─────────────────────────────────────
class _ObligationCard extends StatelessWidget {
  final PaymentObligationModel obligation;
  const _ObligationCard({required this.obligation});

  Color get _statusColor {
    if (obligation.isPaid) return Colors.green;
    if (obligation.isOverdue) return Colors.red;
    return Colors.orange;
  }

  IconData get _statusIcon {
    if (obligation.isPaid) return Icons.check_circle;
    if (obligation.isOverdue) return Icons.warning;
    return Icons.schedule;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_statusIcon, color: _statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    obligation.conceptName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  obligation.formattedAmount,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (obligation.conceptDescription != null) ...[
              const SizedBox(height: 4),
              Text(
                obligation.conceptDescription!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (obligation.dueDate != null)
                  Text(
                    'Vence: ${_formatDate(obligation.dueDate!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: obligation.isOverdue ? Colors.red : Colors.grey,
                    ),
                  ),
                const Spacer(),
                // Barra de progreso de pago parcial
                if (!obligation.isPaid && obligation.amountPaid > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Pagado: S/ ${(obligation.amountPaid / 100).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 11, color: Colors.green),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 80,
                        child: LinearProgressIndicator(
                          value: obligation.amountPaid / obligation.amount,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation(Colors.green),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
