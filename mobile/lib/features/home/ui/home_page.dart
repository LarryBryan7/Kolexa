// ============================================================
// home_page.dart — Dashboard principal de Kolexa
// ============================================================
// Vista diferenciada por rol:
//   parent  → comunicados, tareas, notas, pagos, citas, recojo,
//             chat, cuponera, sugerencias
//   teacher → asistencia, tareas, comunicados, notas, anécdotas,
//             citas, chat
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── Auth ──────────────────────────────────────────────────
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';

// ── Core ─────────────────────────────────────────────────
import '../../../core/api/api_client.dart';

// ── BLoCs y páginas de cada módulo ────────────────────────
import '../../attendance/ui/attendance_page.dart';
import '../../teachers/data/teacher_repository.dart';

import '../../homework/bloc/homework_bloc.dart';
import '../../homework/data/datasources/homework_remote_datasource.dart';
import '../../homework/data/repositories/homework_repository.dart';
import '../../homework/ui/homework_page.dart';

import '../../announcements/bloc/announcements_bloc.dart';
import '../../announcements/ui/announcements_page.dart';

import '../../chat/bloc/chat_bloc.dart';
import '../../chat/ui/chat_page.dart';

import '../../grades/bloc/grades_bloc.dart';
import '../../grades/ui/grades_page.dart';

import '../../appointments/bloc/appointments_bloc.dart';
import '../../appointments/ui/appointments_page.dart';

import '../../pickup/bloc/pickup_bloc.dart';
import '../../pickup/ui/pickup_page.dart';

import '../../payments/bloc/payments_bloc.dart';
import '../../payments/ui/payments_page.dart';

import '../../anecdotes/bloc/anecdotes_bloc.dart';
import '../../anecdotes/ui/anecdotes_page.dart';

import '../../suggestions/bloc/suggestions_bloc.dart';
import '../../suggestions/ui/suggestions_page.dart';

import '../../coupons/bloc/coupons_bloc.dart';
import '../../coupons/ui/coupons_page.dart';

import '../../messages/bloc/messages_bloc.dart';
import '../../messages/ui/messages_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();

    final user = authState.user;
    final isTeacher = user.hasRole('teacher');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar expandida con saludo y avatar ──────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              backgroundImage: user.avatar != null
                                  ? NetworkImage(user.avatar!)
                                  : null,
                              child: user.avatar == null
                                  ? Text(
                                      user.firstName[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _greeting(),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                  ),
                                  Text(
                                    user.fullName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout, color: Colors.white),
                              tooltip: 'Cerrar sesión',
                              onPressed: () =>
                                  context.read<AuthBloc>().add(LogoutEvent()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isTeacher ? '👨‍🏫 Docente' : '👨‍👩‍👧 Padre / Tutor',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              title: Text(
                'Hola, ${user.firstName}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            ),
            backgroundColor: const Color(0xFF6366F1),
          ),

          // ── Grid de módulos ──────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: isTeacher
                  ? _buildTeacherModules(context)
                  : _buildParentModules(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── Módulos para el DOCENTE ──────────────────────────────
  List<Widget> _buildTeacherModules(BuildContext context) {
    final api = context.read<ApiClient>();

    return [
      _ModuleCard(
        icon: Icons.how_to_reg,
        label: 'Asistencia',
        color: const Color(0xFF10B981),
        onTap: () => _navigate(
          context,
          AttendancePage(
            classroomName: '—',
            dateLabel: '—',
            repo: TeacherRepository(api),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.assignment,
        label: 'Tareas',
        color: const Color(0xFF3B82F6),
        onTap: () => _navigate(
          context,
          BlocProvider(
            create: (_) => HomeworkBloc(
              HomeworkRepository(HomeworkRemoteDataSource(api)),
            ),
            child: const HomeworkTeacherPage(classroomId: 0),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.campaign,
        label: 'Comunicados',
        color: const Color(0xFFF59E0B),
        onTap: () => _navigate(
          context,
          BlocProvider(
            create: (_) => AnnouncementsBloc(AnnouncementsDataSource(api)),
            child: const AnnouncementsPage(),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.grade,
        label: 'Notas',
        color: const Color(0xFF8B5CF6),
        onTap: () => _navigate(
          context,
          BlocProvider(
            create: (_) => GradesBloc(GradesDataSource(api)),
            child: GradesPage(studentId: 0, studentName: 'Salón'),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.auto_stories,
        label: 'Anécdotas',
        color: const Color(0xFFEF4444),
        onTap: () => _navigate(
          context,
          BlocProvider(
            create: (_) => AnecdotesBloc(AnecdotesDataSource(api)),
            child: AnecdotesPage(studentId: 0, studentName: 'Alumno', role: 'teacher'),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.event,
        label: 'Citas',
        color: const Color(0xFF06B6D4),
        onTap: () => _navigate(
          context,
          BlocProvider(
            create: (_) => AppointmentsBloc(AppointmentsDataSource(api)),
            child: const AppointmentsPage(role: 'teacher'),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.mail_outline,
        label: 'Mensajes',
        color: const Color(0xFF84CC16),
        onTap: () => _navigate(
          context,
          BlocProvider(
            create: (_) => MessagesBloc(MessagesDataSource(api)),
            child: const MessagesPage(),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.chat_bubble_outline,
        label: 'Chat',
        color: const Color(0xFFEC4899),
        onTap: () => _navigate(
          context,
          BlocProvider(
            create: (_) => ChatBloc(ChatDataSource(api)),
            child: const ConversationsPage(),
          ),
        ),
      ),
    ];
  }

  // ── Módulos para el PADRE ────────────────────────────────
  List<Widget> _buildParentModules(BuildContext context) {
    final api = context.read<ApiClient>();
    final authState = context.read<AuthBloc>().state as AuthAuthenticated;
    final user = authState.user;

    // Abre módulo que necesita studentId. Si hay un solo hijo, abre directo.
    // Si hay varios, muestra un selector primero.
    void openStudentModule(
      BuildContext ctx,
      Widget Function(int studentId, String studentName) pageBuilder,
    ) {
      final children = user.children;
      if (children.isEmpty) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('No hay alumnos vinculados a tu cuenta')),
        );
        return;
      }
      if (children.length == 1) {
        _navigate(ctx, pageBuilder(children[0].id, children[0].firstName));
        return;
      }
      // Selector de hijo
      showModalBottomSheet(
        context: ctx,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('¿Para qué alumno?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ...children.map((c) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      child: Text(c.firstName[0],
                          style: const TextStyle(color: Color(0xFF6366F1))),
                    ),
                    title: Text(c.fullName),
                    onTap: () {
                      Navigator.pop(ctx);
                      _navigate(ctx, pageBuilder(c.id, c.firstName));
                    },
                  )),
            ],
          ),
        ),
      );
    }

    return [
      _ModuleCard(
        icon: Icons.campaign,
        label: 'Comunicados',
        color: const Color(0xFFF59E0B),
        onTap: () => _navigate(
          context,
          BlocProvider(
            create: (_) => AnnouncementsBloc(AnnouncementsDataSource(api)),
            child: const AnnouncementsPage(),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.assignment,
        label: 'Tareas',
        color: const Color(0xFF3B82F6),
        onTap: () => openStudentModule(
          context,
          (id, name) => BlocProvider(
            create: (_) => HomeworkBloc(HomeworkRepository(HomeworkRemoteDataSource(api))),
            child: HomeworkParentPage(studentId: id, studentName: name),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.grade,
        label: 'Notas',
        color: const Color(0xFF8B5CF6),
        onTap: () => openStudentModule(
          context,
          (id, name) => BlocProvider(
            create: (_) => GradesBloc(GradesDataSource(api)),
            child: GradesPage(studentId: id, studentName: name),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.account_balance_wallet,
        label: 'Pagos',
        color: const Color(0xFF10B981),
        onTap: () => openStudentModule(
          context,
          (id, name) => BlocProvider(
            create: (_) => PaymentsBloc(PaymentsDataSource(api)),
            child: PaymentsPage(studentId: id, studentName: name),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.event_available,
        label: 'Citas',
        color: const Color(0xFF06B6D4),
        onTap: () => _navigate(
          context,
          BlocProvider(
            create: (_) => AppointmentsBloc(AppointmentsDataSource(api)),
            child: const AppointmentsPage(role: 'parent'),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.directions_walk,
        label: 'Recojo',
        color: const Color(0xFFEF4444),
        onTap: () => openStudentModule(
          context,
          (id, name) => BlocProvider(
            create: (_) => PickupBloc(PickupDataSource(api)),
            child: PickupPage(studentId: id, studentName: name),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.mail_outline,
        label: 'Mensajes',
        color: const Color(0xFF84CC16),
        onTap: () => _navigate(
          context,
          BlocProvider(
            create: (_) => MessagesBloc(MessagesDataSource(api)),
            child: const MessagesPage(),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.chat_bubble_outline,
        label: 'Chat',
        color: const Color(0xFFEC4899),
        onTap: () => _navigate(
          context,
          BlocProvider(
            create: (_) => ChatBloc(ChatDataSource(api)),
            child: const ConversationsPage(),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.local_offer_outlined,
        label: 'Cuponera',
        color: const Color(0xFFF97316),
        onTap: () => _navigate(
          context,
          BlocProvider(
            create: (_) => CouponsBloc(CouponsDataSource(api)),
            child: const CouponsPage(),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.inbox_outlined,
        label: 'Sugerencias',
        color: const Color(0xFF64748B),
        onTap: () => _navigate(
          context,
          BlocProvider(
            create: (_) => SuggestionsBloc(SuggestionsDataSource(api)),
            child: const SuggestionsPage(),
          ),
        ),
      ),
    ];
  }

  // Navega a una página usando el Navigator de Flutter (por encima del router)
  void _navigate(BuildContext context, Widget page) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }
}

// ── Widget: tarjeta de módulo en el grid ──────────────────────
class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: color.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
