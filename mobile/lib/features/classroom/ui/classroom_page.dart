import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/classroom_bloc.dart';
import '../data/models/gc_models.dart';

const _kBg       = Color(0xFFF7F6F3);
const _kPrimary  = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);

class ClassroomPage extends StatelessWidget {
  final String studentId;
  final String studentName;

  const ClassroomPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kTextDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Google Classroom',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kTextDark)),
            Text(studentName,
                style: const TextStyle(fontSize: 12, color: _kTextGray)),
          ],
        ),
        actions: [
          BlocBuilder<ClassroomBloc, ClassroomState>(
            builder: (context, state) {
              if (state is ClassroomLoaded || state is ClassroomSyncing) {
                return IconButton(
                  icon: state is ClassroomSyncing
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary))
                      : const Icon(Icons.sync, color: _kPrimary),
                  onPressed: state is ClassroomSyncing
                      ? null
                      : () => context.read<ClassroomBloc>().add(SyncClassroom(studentId)),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocConsumer<ClassroomBloc, ClassroomState>(
        listener: (context, state) {
          if (state is ClassroomError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red[700]),
            );
          }
        },
        builder: (context, state) {
          if (state is ClassroomInitial || state is ClassroomLoading) {
            return const Center(
              child: CircularProgressIndicator(color: _kPrimary),
            );
          }
          if (state is ClassroomNotConnected) {
            return _NotConnectedView(studentId: studentId);
          }
          if (state is ClassroomLoaded || state is ClassroomSyncing) {
            final courses = state is ClassroomLoaded
                ? state.courses
                : (state as ClassroomSyncing).courses;
            final upcoming = state is ClassroomLoaded
                ? state.upcoming
                : (state as ClassroomSyncing).upcoming;
            return _LoadedView(courses: courses, upcoming: upcoming);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ── Vista: no conectado ───────────────────────────────────
class _NotConnectedView extends StatefulWidget {
  final String studentId;
  const _NotConnectedView({required this.studentId});

  @override
  State<_NotConnectedView> createState() => _NotConnectedViewState();
}

class _NotConnectedViewState extends State<_NotConnectedView>
    with WidgetsBindingObserver {
  bool _waitingConfirm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingConfirm) {
      context.read<ClassroomBloc>().add(ClassroomConnectedCallback(widget.studentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(color: _kPrimaryLt, shape: BoxShape.circle),
              child: const Icon(Icons.school_outlined, size: 40, color: _kPrimary),
            ),
            const SizedBox(height: 24),
            const Text('Conecta Google Classroom',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kTextDark),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text(
              'Para ver las tareas y materiales del alumno,\nconéctate con la cuenta escolar de Google.',
              style: TextStyle(fontSize: 13, color: _kTextGray, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Conectar con Google',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                onPressed: () async {
                  context.read<ClassroomBloc>().add(ConnectClassroom(widget.studentId));
                  setState(() => _waitingConfirm = true);
                },
              ),
            ),
            if (_waitingConfirm) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary),
                  ),
                  SizedBox(width: 8),
                  Text('Verificando conexión...',
                      style: TextStyle(fontSize: 13, color: _kTextGray)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Vista: cargado ────────────────────────────────────────
class _LoadedView extends StatelessWidget {
  final List<GcCourse> courses;
  final List<GcCoursework> upcoming;
  const _LoadedView({required this.courses, required this.upcoming});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (upcoming.isNotEmpty) ...[
            const Text('Próximas entregas',
                style: TextStyle(fontSize: 11, color: _kTextGray, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...upcoming.map((cw) => _CourseworkCard(cw: cw)),
            const SizedBox(height: 20),
          ],
          const Text('Cursos',
              style: TextStyle(fontSize: 11, color: _kTextGray, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (courses.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Sin cursos sincronizados aún',
                    style: TextStyle(color: _kTextGray)),
              ),
            )
          else
            ...courses.map((c) => _CourseCard(course: c)),
        ],
      ),
    );
  }
}

class _CourseworkCard extends StatelessWidget {
  final GcCoursework cw;
  const _CourseworkCard({required this.cw});

  String _formatDue(DateTime? date) {
    if (date == null) return 'Sin fecha';
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    return DateFormat('d MMM', 'es').format(date);
  }

  Color _dueColor(DateTime? date) {
    if (date == null) return _kTextGray;
    final diff = date.difference(DateTime.now()).inDays;
    if (diff <= 1) return Colors.red[600]!;
    if (diff <= 3) return Colors.orange[700]!;
    return _kTextGray;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(color: _kPrimaryLt, shape: BoxShape.circle),
            child: const Icon(Icons.assignment_outlined, size: 18, color: _kPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cw.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextDark),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(cw.courseName,
                    style: const TextStyle(fontSize: 11, color: _kTextGray)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_formatDue(cw.dueDate),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: _dueColor(cw.dueDate))),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final GcCourse course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(color: _kPrimaryLt, shape: BoxShape.circle),
                child: const Icon(Icons.menu_book_rounded, size: 18, color: _kPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kTextDark)),
                    if (course.section != null)
                      Text(course.section!,
                          style: const TextStyle(fontSize: 11, color: _kTextGray)),
                  ],
                ),
              ),
              Text('${course.courseworks.length} tareas',
                  style: const TextStyle(fontSize: 11, color: _kTextGray)),
            ],
          ),
        ],
      ),
    );
  }
}
