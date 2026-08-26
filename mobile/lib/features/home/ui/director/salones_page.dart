// ============================================================
// salones_page.dart — Aulas del colegio (director, solo lectura)
// ============================================================
// Lista de aulas desde GET /admin/classrooms. Tocar un aula muestra
// su lista de alumnos (GET /admin/students filtrado en el cliente),
// y tocar un alumno abre StudentLinksPage (accesos de lectura ya
// existentes: asistencia, tareas, notas, anécdotas, Classroom).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/api/api_client.dart';
import '../../data/director_repository.dart';
import 'student_links_page.dart';

const _kBg = Color(0xFFF7F6F3);
const _kPrimary = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);

class SalonesPage extends StatefulWidget {
  const SalonesPage({super.key});

  @override
  State<SalonesPage> createState() => _SalonesPageState();
}

class _SalonesPageState extends State<SalonesPage> {
  late final DirectorRepository _repo;
  late Future<List<DirectorClassroom>> _future;

  @override
  void initState() {
    super.initState();
    _repo = DirectorRepository(context.read<ApiClient>());
    _future = _repo.getClassrooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        title: const Text('Salones', style: TextStyle(color: _kTextDark)),
        iconTheme: const IconThemeData(color: _kTextDark),
      ),
      body: FutureBuilder<List<DirectorClassroom>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudieron cargar los salones'));
          }
          final classrooms = snapshot.data ?? [];
          if (classrooms.isEmpty) {
            return const Center(child: Text('Sin salones registrados', style: TextStyle(color: _kTextGray)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: classrooms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final c = classrooms[i];
              return _Tile(
                icon: Icons.door_front_door_outlined,
                title: c.label,
                subtitle: '${c.locationName} · ${c.studentCount} alumnos',
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => _ClassroomRosterPage(repo: _repo, classroom: c),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ClassroomRosterPage extends StatefulWidget {
  final DirectorRepository repo;
  final DirectorClassroom classroom;
  const _ClassroomRosterPage({required this.repo, required this.classroom});

  @override
  State<_ClassroomRosterPage> createState() => _ClassroomRosterPageState();
}

class _ClassroomRosterPageState extends State<_ClassroomRosterPage> {
  late Future<List<DirectorStudent>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.getStudents(classroomId: widget.classroom.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        title: Text(widget.classroom.label, style: const TextStyle(color: _kTextDark)),
        iconTheme: const IconThemeData(color: _kTextDark),
      ),
      body: FutureBuilder<List<DirectorStudent>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudo cargar la lista de alumnos'));
          }
          final students = snapshot.data ?? [];
          if (students.isEmpty) {
            return const Center(child: Text('Sin alumnos matriculados', style: TextStyle(color: _kTextGray)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final s = students[i];
              return _Tile(
                icon: Icons.person_outline,
                title: s.fullName,
                subtitle: null,
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => StudentLinksPage(studentId: s.id, studentName: s.fullName),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _Tile({required this.icon, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kTextDark)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: const TextStyle(fontSize: 12, color: _kTextGray)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF8E8E93)),
            ],
          ),
        ),
      ),
    );
  }
}
