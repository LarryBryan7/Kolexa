// ============================================================
// grades_page.dart — Pantalla de Notas (Boleta del alumno)
// ============================================================
// Vista del padre: boleta organizada por periodo con colores
// que indican si la nota es aprobatoria o no.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/grades_bloc.dart';

class GradesPage extends StatefulWidget {
  final int studentId;
  final String studentName;

  const GradesPage({super.key, required this.studentId, required this.studentName});

  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  @override
  void initState() {
    super.initState();
    context.read<GradesBloc>().add(LoadStudentReportEvent(widget.studentId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notas de ${widget.studentName}')),
      body: BlocBuilder<GradesBloc, GradesState>(
        builder: (context, state) {
          if (state is GradesLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is GradesError) {
            return Center(child: Text(state.message));
          }

          if (state is StudentReportLoaded) {
            final report = state.report;

            if (report.grades.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.grade_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Aún no hay notas registradas',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Resumen general ──────────────────────────
                _SummaryCard(
                  average: report.overallAverage,
                  totalSubjects: report.grades.map((g) => g.courseId).toSet().length,
                ),
                const SizedBox(height: 16),

                // ── Notas por periodo ────────────────────────
                ...report.byPeriod.entries.map((entry) {
                  final periodGrades = entry.value;
                  if (periodGrades.isEmpty) return const SizedBox.shrink();
                  final periodName = periodGrades.first.periodName;
                  final periodAvg = periodGrades.fold(0.0, (s, g) => s + g.grade) /
                      periodGrades.length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header del periodo
                      Row(
                        children: [
                          Text(
                            periodName,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Spacer(),
                          Text(
                            'Prom: ${periodAvg.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: periodAvg >= 11 ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Tarjetas de notas
                      ...periodGrades.map((g) => _GradeCard(grade: g)),
                      const SizedBox(height: 20),
                    ],
                  );
                }),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double average;
  final int totalSubjects;

  const _SummaryCard({required this.average, required this.totalSubjects});

  @override
  Widget build(BuildContext context) {
    final color = average >= 11 ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Promedio general', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  average.toStringAsFixed(1),
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  average >= 11 ? 'Aprobado' : 'Desaprobado',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const Spacer(),
            Column(
              children: [
                Icon(Icons.menu_book_outlined, size: 36, color: color),
                const SizedBox(height: 4),
                Text('$totalSubjects cursos', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  final GradeModel grade;

  const _GradeCard({required this.grade});

  @override
  Widget build(BuildContext context) {
    final color = Color(grade.colorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              grade.courseName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                grade.grade.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
