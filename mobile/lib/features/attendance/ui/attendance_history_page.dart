// ============================================================
// attendance_history_page.dart — Historial de asistencia (lectura)
// ============================================================
// El BLoC/Repository/DataSource (LoadStudentHistoryEvent,
// AttendanceHistoryLoaded) ya existían para esto pero no tenían
// pantalla propia — esta es esa pantalla, para padres y para la
// visibilidad de solo lectura del director sobre su colegio.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/attendance_bloc.dart';
import '../bloc/attendance_event.dart';
import '../bloc/attendance_state.dart';

const _kPrimary = Color(0xFF5B4A9E);

class AttendanceHistoryPage extends StatefulWidget {
  final int studentId;
  final String studentName;

  const AttendanceHistoryPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  @override
  void initState() {
    super.initState();
    context.read<AttendanceBloc>().add(
          LoadStudentHistoryEvent(studentId: widget.studentId),
        );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'present':
        return 'Presente';
      case 'late':
        return 'Tardanza';
      case 'justified':
        return 'Justificado';
      case 'absent':
        return 'Ausente';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present':
        return const Color(0xFF1F6B44);
      case 'late':
        return const Color(0xFF96650C);
      case 'justified':
        return const Color(0xFF1D4ED8);
      case 'absent':
        return const Color(0xFFBA3428);
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String isoDate) {
    final d = DateTime.parse(isoDate);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Asistencia · ${widget.studentName}')),
      body: BlocBuilder<AttendanceBloc, AttendanceState>(
        builder: (context, state) {
          if (state is AttendanceLoading || state is AttendanceInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AttendanceError) {
            return Center(child: Text(state.message));
          }
          if (state is AttendanceHistoryLoaded) {
            if (state.records.isEmpty) {
              return const Center(
                child: Text('Sin registros de asistencia', style: TextStyle(color: Colors.grey)),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatChip(label: 'Presente', value: state.stats['present'] ?? 0),
                      _StatChip(label: 'Tardanza', value: state.stats['late'] ?? 0),
                      _StatChip(label: 'Ausente', value: state.stats['absent'] ?? 0),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: state.records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = state.records[i] as Map<String, dynamic>;
                      final attendance = r['attendance'] as Map<String, dynamic>? ?? {};
                      final classroom = attendance['classroom'] as Map<String, dynamic>?;
                      final status = r['status'] as String? ?? 'present';
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          title: Text(_formatDate(attendance['date'] as String)),
                          subtitle: classroom != null
                              ? Text('${classroom['name']} ${classroom['section'] ?? ''}'.trim())
                              : null,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _statusColor(status),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _kPrimary)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
