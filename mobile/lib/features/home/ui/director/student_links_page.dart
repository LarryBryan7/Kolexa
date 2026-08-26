// ============================================================
// student_links_page.dart — Accesos de lectura a un alumno (director)
// ============================================================
// No es una vista nueva de cada módulo: reutiliza las pantallas que
// ya existen para el padre (asistencia, tareas, notas, anécdotas,
// Google Classroom), solo con el studentId del alumno tocado desde
// Salones. El backend ya deja pasar a school_admin en todos estos
// endpoints (ver plan de visibilidad del director) — acá solo se
// arma la navegación de solo lectura.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/api/api_client.dart';
import '../../../attendance/bloc/attendance_bloc.dart';
import '../../../attendance/data/repositories/attendance_repository.dart';
import '../../../attendance/data/datasources/attendance_remote_datasource.dart';
import '../../../attendance/ui/attendance_history_page.dart';
import '../../../homework/bloc/homework_bloc.dart';
import '../../../homework/data/datasources/homework_remote_datasource.dart';
import '../../../homework/data/repositories/homework_repository.dart';
import '../../../homework/ui/homework_page.dart';
import '../../../grades/bloc/grades_bloc.dart';
import '../../../grades/ui/grades_page.dart';
import '../../../anecdotes/bloc/anecdotes_bloc.dart';
import '../../../anecdotes/ui/anecdotes_page.dart';
import '../../../classroom/bloc/classroom_bloc.dart';
import '../../../classroom/ui/classroom_page.dart';

const _kBg = Color(0xFFF7F6F3);
const _kPrimary = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kTextDark = Color(0xFF1E1B29);

class StudentLinksPage extends StatelessWidget {
  final int studentId;
  final String studentName;

  const StudentLinksPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  void _navigate(BuildContext context, Widget page) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    final items = <(IconData, String, VoidCallback)>[
      (
        Icons.event_available_outlined,
        'Asistencia',
        () => _navigate(
              context,
              BlocProvider(
                create: (_) => AttendanceBloc(
                  AttendanceRepository(AttendanceRemoteDataSource(api)),
                ),
                child: AttendanceHistoryPage(studentId: studentId, studentName: studentName),
              ),
            ),
      ),
      (
        Icons.assignment_outlined,
        'Tareas',
        () => _navigate(
              context,
              BlocProvider(
                create: (_) => HomeworkBloc(
                  HomeworkRepository(HomeworkRemoteDataSource(api)),
                ),
                child: HomeworkParentPage(studentId: studentId, studentName: studentName),
              ),
            ),
      ),
      (
        Icons.grade_outlined,
        'Notas',
        () => _navigate(
              context,
              BlocProvider(
                create: (_) => GradesBloc(GradesDataSource(api)),
                child: GradesPage(studentId: studentId, studentName: studentName),
              ),
            ),
      ),
      (
        Icons.auto_stories_outlined,
        'Anécdotas',
        // role: 'parent' → vista de solo lectura (sin botón de crear/eliminar).
        // El backend igual muestra las anécdotas privadas al director: el
        // rol real se deriva del JWT, no de este parámetro (ver anecdotes.controller.ts).
        () => _navigate(
              context,
              BlocProvider(
                create: (_) => AnecdotesBloc(AnecdotesDataSource(api)),
                child: AnecdotesPage(
                  studentId: studentId,
                  studentName: studentName,
                  role: 'parent',
                ),
              ),
            ),
      ),
      (
        Icons.laptop_chromebook,
        'Google Classroom',
        () => _navigate(
              context,
              BlocProvider.value(
                value: context.read<ClassroomBloc>()
                  ..add(LoadClassroom(studentId.toString())),
                child: ClassroomPage(
                  studentId: studentId.toString(),
                  studentName: studentName,
                ),
              ),
            ),
      ),
    ];

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        title: Text(studentName, style: const TextStyle(color: _kTextDark)),
        iconTheme: const IconThemeData(color: _kTextDark),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final (icon, label, onTap) = items[i];
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: _kPrimaryLt, shape: BoxShape.circle),
                      child: Icon(icon, color: _kPrimary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kTextDark)),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF8E8E93)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
