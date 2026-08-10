// ============================================================
// home_docente_page.dart — Home del docente (v1)
// ============================================================
// Primera versión, portada 1:1 desde el frame de Figma
// "06 — Inicio Docente v1". Usa el mismo sistema de tamaños
// responsivo (AppSizes) y el mismo tope de ancho de 600dp que
// el Home del padre — ver home_v2_page.dart para el patrón base.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/services/push_notifications_service.dart';
import '../../../core/widgets/notification_banner.dart';
import '../../notifications/ui/notification_onboarding_page.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../teachers/data/teacher_repository.dart';
import '../../teachers/ui/schedule_sheet.dart';
import 'package:image_picker/image_picker.dart';
import '../../attendance/ui/attendance_page.dart';

// ── Paleta (compartida con el Home del padre) ─────────────
const _kBg = Color(0xFFF7F6F3);
const _kPrimary = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);
const _kChevron = Color(0xFF8E8E93);
const _kNavInact = Color(0xFF707070);
const _kSuccessText = Color(0xFF1F6B44);
const _kAmber = Color(0xFF96650C);

// ── Paleta propia del aviso "plan semanal" ────────────────
const _kBannerBg = Color(0xFFFAEED3);
const _kBannerText = Color(0xFF693902);

class HomeDocentePage extends StatefulWidget {
  const HomeDocentePage({super.key});

  @override
  State<HomeDocentePage> createState() => _HomeDocentePageState();
}

class _HomeDocentePageState extends State<HomeDocentePage>
    with WidgetsBindingObserver {
  int _navIndex = 0;
  late Future<TeacherHomeData> _homeDataFuture;
  late Future<bool> _classroomStatusFuture;
  late Future<List<GcTeacherCourse>> _coursesFuture;
  late Future<int> _pendingFuture;
  late Future<List<ScheduleSlot>> _scheduleFuture;
  bool _waitingClassroomConfirm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final repo = TeacherRepository(context.read<ApiClient>());
    _homeDataFuture = repo.getHomeData();
    _classroomStatusFuture = repo.isClassroomConnected();
    _coursesFuture = repo.getCourses();
    _pendingFuture = repo.getPendingCount();
    _scheduleFuture = repo.getTodaySchedule();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _syncOnLogin();
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        await maybeShowNotificationOnboarding(context, authState.user);
        await maybeShowAutostartReminder(context);
      }
    });
  }

  Future<void> _syncOnLogin() async {
    final repo = TeacherRepository(context.read<ApiClient>());
    try { await repo.syncClassroom(); } catch (_) {}
    if (!mounted) return;
    setState(() {
      _homeDataFuture = repo.getHomeData();
      _coursesFuture = repo.getCourses();
      _pendingFuture = repo.getPendingCount();
      _scheduleFuture = repo.getTodaySchedule();
    });
  }

  void _onAttendanceComplete() {
    if (!mounted) return;
    final repo = TeacherRepository(context.read<ApiClient>());
    setState(() => _homeDataFuture = repo.getHomeData());
  }

  void _onScheduleSaved() {
    final repo = TeacherRepository(context.read<ApiClient>());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('¡Horario guardado exitosamente!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF1F6B44),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
    setState(() {
      _homeDataFuture = repo.getHomeData();
      _scheduleFuture = repo.getTodaySchedule();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingClassroomConfirm) {
      _verifyClassroomConnection();
    }
  }

  Future<void> _onRefresh() async {
    final repo = TeacherRepository(context.read<ApiClient>());
    try { await repo.syncClassroom(); } catch (_) {}
    if (!mounted) return;
    setState(() {
      _homeDataFuture = repo.getHomeData();
      _classroomStatusFuture = repo.isClassroomConnected();
      _coursesFuture = repo.getCourses();
      _pendingFuture = repo.getPendingCount();
      _scheduleFuture = repo.getTodaySchedule();
      _waitingClassroomConfirm = false;
    });
    await Future.wait([_homeDataFuture, _classroomStatusFuture]);
  }

  Future<void> _connectClassroom() async {
    try {
      final repo = TeacherRepository(context.read<ApiClient>());
      final url = await repo.getClassroomAuthUrl();
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el navegador')),
        );
        return;
      }
      if (mounted) setState(() => _waitingClassroomConfirm = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  Future<void> _verifyClassroomConnection() async {
    final repo = TeacherRepository(context.read<ApiClient>());
    if (mounted) {
      setState(() {
        _waitingClassroomConfirm = false;
        _classroomStatusFuture = repo.isClassroomConnected();
      });
    }
    try {
      await repo.syncClassroom();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _classroomStatusFuture = repo.isClassroomConnected();
      _coursesFuture = repo.getCourses();
      _pendingFuture = repo.getPendingCount();
      _homeDataFuture = repo.getHomeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    final authState = context.read<AuthBloc>().state;
    final firstName = authState is AuthAuthenticated ? authState.user.firstName : '';
    final now = DateTime.now();
    final days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    final months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    final dateStr =
        '${days[now.weekday - 1]} ${now.day} de ${months[now.month - 1]}';

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _navIndex == 3
                  ? const PerfilTab()
                  : RefreshIndicator(
                color: _kPrimary,
                onRefresh: _onRefresh,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: FutureBuilder<TeacherHomeData>(
                      future: _homeDataFuture,
                      builder: (context, snapshot) {
                        final data = snapshot.data;
                        final classroom = data?.classrooms.length == 1
                            ? data!.classrooms.first
                            : null;
                        final hasSchedule = data?.hasSchedule ?? false;

                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                              sizes.cardPadding, 0, sizes.cardPadding, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Banner: notificaciones desactivadas ──
                              const NotificationBanner(),
                              const SizedBox(height: 12),

                              // ── Header: saludo ──────────────────
                              Text('Hola, $firstName',
                                  style: TextStyle(
                                    fontSize: sizes.titleHorizontal,
                                    fontWeight: FontWeight.w700,
                                    color: _kTextDark,
                                  )),
                              const SizedBox(height: 4),
                              Text(dateStr,
                                  style: TextStyle(
                                    fontSize: sizes.textFecha,
                                    color: _kTextGray,
                                  )),
                              const SizedBox(height: 16),

                              // ── Card: salón ─────────────────────
                              FutureBuilder<List<GcTeacherCourse>>(
                                future: _coursesFuture,
                                builder: (ctx, cSnap) => _SalonCard(
                                  classroom: classroom,
                                  gcSection: data?.gcSection,
                                  gcStudentCount: data?.gcStudentCount,
                                  showCreateButton: data != null && !hasSchedule,
                                  isLoading: snapshot.connectionState ==
                                      ConnectionState.waiting,
                                  courses: cSnap.data ?? [],
                                  repo: TeacherRepository(context.read<ApiClient>()),
                                  onSaved: _onScheduleSaved,
                                  attendanceState: data?.attendanceState ?? 'none',
                                  attendanceSummary: data?.attendanceSummary,
                                  onAttendanceComplete: _onAttendanceComplete,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ── Horario del día (cuando hay horario)
                              if (hasSchedule) ...[
                                Text('Horario',
                                    style: TextStyle(
                                      fontSize: sizes.textLabelCard,
                                      fontWeight: FontWeight.w600,
                                      color: _kTextGray,
                                    )),
                                const SizedBox(height: 10),
                                FutureBuilder<List<ScheduleSlot>>(
                                  future: _scheduleFuture,
                                  builder: (ctx, sSnap) => _HorarioRow(
                                    slots: sSnap.data ?? [],
                                    now: now,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // ── Cursos y pendientes (si hay classroom)
                              FutureBuilder<bool>(
                                future: _classroomStatusFuture,
                                builder: (context, snap) {
                                  if (snap.connectionState == ConnectionState.waiting ||
                                      snap.data != true) {
                                    return const SizedBox.shrink();
                                  }
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Pendientes
                                      FutureBuilder<int>(
                                        future: _pendingFuture,
                                        builder: (context, pendSnap) {
                                          final count = pendSnap.data ?? 0;
                                          if (count == 0) return const SizedBox.shrink();
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _PendientesDocenteCard(pendingCount: count),
                                              const SizedBox(height: 12),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),

                              // ── Aviso plan semanal (con horario guardado)
                              if (data != null && hasSchedule) ...[
                                const _AvisoBanner(),
                                const SizedBox(height: 12),
                              ],

                              // ── Accesos rápidos (siempre visible)
                              Text('Accesos Rápidos',
                                  style: TextStyle(
                                    fontSize: sizes.textLabelCard,
                                    color: _kTextGray,
                                  )),
                              const SizedBox(height: 10),
                              const _AccesosRapidosDocente(),
                              const SizedBox(height: 12),

                              // ── Classroom: card de conexión ────
                              FutureBuilder<bool>(
                                future: _classroomStatusFuture,
                                builder: (context, snap) {
                                  if (snap.connectionState == ConnectionState.waiting ||
                                      snap.data == true) {
                                    return const SizedBox.shrink();
                                  }
                                  return _ClassroomConnectCard(
                                    waitingConfirm: _waitingClassroomConfirm,
                                    onConnect: _connectClassroom,
                                    onVerify: _verifyClassroomConnection,
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            _BottomNavDocente(
              selected: _navIndex,
              onTap: (i) => setState(() => _navIndex = i),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Card: mi salón (avatar + nombre + botón de acción directa)
// ─────────────────────────────────────────────────────────
class _SalonCard extends StatelessWidget {
  final TeacherClassroom? classroom;
  final String? gcSection;
  final int? gcStudentCount;
  final bool showCreateButton;
  final bool isLoading;
  final List<GcTeacherCourse> courses;
  final TeacherRepository repo;
  final VoidCallback? onSaved;
  final String attendanceState; // 'none' | 'attendance_only' | 'complete'
  final AttendanceSummary? attendanceSummary;
  final VoidCallback? onAttendanceComplete;

  const _SalonCard({
    required this.classroom,
    required this.showCreateButton,
    required this.isLoading,
    required this.courses,
    required this.repo,
    this.gcSection,
    this.gcStudentCount,
    this.onSaved,
    this.attendanceState = 'none',
    this.attendanceSummary,
    this.onAttendanceComplete,
  });

  void _openPhotoModal(BuildContext context) {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PhotoModal(
        onConfirm: (List<XFile> photos) async {
          try {
            if (photos.isNotEmpty) {
              await repo.uploadAttendancePhotos(
                date: date,
                photoPaths: photos.map((p) => p.path).toList(),
              );
            }
          } catch (_) {}
          if (!context.mounted) return;
          Navigator.pop(context);
          onAttendanceComplete?.call();
        },
        onSkip: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    final salonName = classroom != null
        ? classroom!.name
        : (isLoading ? '...' : (gcSection ?? 'Sin salón asignado'));

    final count = classroom?.studentCount ?? gcStudentCount;
    final String subtitle;
    if (attendanceSummary != null) {
      subtitle = attendanceSummary!.label;
    } else {
      final scheduleText = showCreateButton ? 'Sin horario' : null;
      subtitle = [
        if (count != null) '$count alumnos hábiles',
        if (scheduleText != null) scheduleText,
      ].join('  ·  ');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: sizes.circleIconNovedades,
                height: sizes.circleIconNovedades,
                decoration: const BoxDecoration(
                  color: _kPrimaryLt,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/icons/ic_cap.svg',
                  width: sizes.glyphNovedades,
                  height: sizes.glyphNovedades * 17 / 24,
                  colorFilter:
                      const ColorFilter.mode(_kPrimary, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(salonName,
                        style: TextStyle(
                          fontSize: sizes.textValueCard,
                          fontWeight: FontWeight.w700,
                          color: _kTextDark,
                        )),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                            fontSize: sizes.textLabelCard,
                            color: _kTextGray,
                          )),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (showCreateButton) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showCreateScheduleSheet(
                    context, courses, repo, onSaved: onSaved),
                icon: const Icon(Icons.edit_calendar_outlined,
                    size: 16, color: Colors.white),
                label: Text('Crear horario',
                    style: TextStyle(
                      fontSize: sizes.textValueCard,
                      fontWeight: FontWeight.w700,
                    )),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDEF3FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.info_outline,
                      size: 11, color: Color(0xFF476376)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Edítalo cuando quieras en accesos rápidos.',
                    style: TextStyle(fontSize: sizes.textLabelCard, color: _kTextGray),
                  ),
                ),
              ],
            ),
          ] else if (attendanceState == 'complete') ...[
            // ✓ Asistencia y foto listas
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE0EFE5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '✓ asistencia y foto del día listas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kSuccessText,
                ),
              ),
            ),
          ] else if (attendanceState == 'attendance_only') ...[
            // Tomar foto del día
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openPhotoModal(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('tomar foto del día',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ] else ...[
            // Tomar asistencia
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final now = DateTime.now();
                  final days = ['', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
                  final months = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
                  final dateLabel = '${days[now.weekday]} ${now.day} de ${months[now.month]}';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AttendancePage(
                        classroomName: salonName,
                        dateLabel: dateLabel,
                        repo: repo,
                      ),
                    ),
                  ).then((_) => onAttendanceComplete?.call());
                },
                icon: const Icon(Icons.timer_outlined,
                    size: 16, color: Colors.white),
                label: const Text('Tomar asistencia',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Horario del día: fila con scroll horizontal
// ─────────────────────────────────────────────────────────
class _HorarioRow extends StatelessWidget {
  final List<ScheduleSlot> slots;
  final DateTime now;
  const _HorarioRow({required this.slots, required this.now});

  String _fmt(String hhmm) {
    final p = hhmm.split(':');
    final h = int.parse(p[0]);
    final m = p[1];
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m';
  }

  @override
  Widget build(BuildContext context) {
    final current = slots.firstWhere(
      (s) => s.isActive(now),
      orElse: () => const ScheduleSlot(
          courseName: 'Sin clase ahora',
          type: 'none',
          startTime: '--:--',
          endTime: '--:--'),
    );
    final upcoming = slots.where((s) => s.isUpcoming(now)).toList();
    final next = upcoming.isNotEmpty ? upcoming.first : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ClaseActualChip(slot: current, fmt: _fmt),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 150,
            child: _MiniClaseChip(
              nombre: next?.courseName ?? '–',
              hora: next != null ? _fmt(next.startTime) : '–',
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaseActualChip extends StatelessWidget {
  final ScheduleSlot slot;
  final String Function(String) fmt;
  const _ClaseActualChip({required this.slot, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    final isActive = slot.type != 'none';
    final label = isActive
        ? '${fmt(slot.startTime)} – ${fmt(slot.endTime)} · En curso'
        : 'Sin clase ahora';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: sizes.circleIconNovedades,
            height: sizes.circleIconNovedades,
            decoration: const BoxDecoration(
              color: _kPrimaryLt,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.schedule_rounded,
                size: sizes.glyphNovedades, color: _kPrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(slot.courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: sizes.textValueCard,
                      fontWeight: FontWeight.w700,
                      color: _kTextDark,
                    )),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive ? _kSuccessText : _kTextGray,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniClaseChip extends StatelessWidget {
  final String nombre;
  final String hora;
  const _MiniClaseChip({required this.nombre, required this.hora});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF999999),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kTextDark,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(hora,
              style: const TextStyle(fontSize: 11, color: _kTextGray)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Card: pendientes (tareas, reuniones, y más)
// ─────────────────────────────────────────────────────────
class _PendientesDocenteCard extends StatelessWidget {
  final int pendingCount;
  const _PendientesDocenteCard({required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    final label = '$pendingCount pendientes esta semana';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: sizes.circleIconNovedades,
            height: sizes.circleIconNovedades,
            decoration: const BoxDecoration(
              color: _kBannerBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.chat_bubble_outline, color: _kAmber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontSize: sizes.textValueCard,
                      fontWeight: FontWeight.w600,
                      color: _kTextDark,
                    )),
                const SizedBox(height: 2),
                Text('Tareas por calificar',
                    style: TextStyle(
                      fontSize: sizes.textLabelCard,
                      color: _kTextGray,
                    )),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: _kChevron, size: sizes.iconChevron),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────
// Aviso: plan semanal
// ─────────────────────────────────────────────────────────
class _AvisoBanner extends StatelessWidget {
  const _AvisoBanner();

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kBannerBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: _kBannerText,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Actualiza el plan semanal antes del lunes',
                style: TextStyle(
                  fontSize: sizes.textLabelCard,
                  fontWeight: FontWeight.w600,
                  color: _kBannerText,
                )),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Accesos rápidos (2 filas × 3)
// ─────────────────────────────────────────────────────────
class _AccesosRapidosDocente extends StatelessWidget {
  const _AccesosRapidosDocente();

  static const _items = [
    (Icons.calendar_month_outlined, 'Plan semanal'),
    (Icons.schedule_outlined, 'Horario'),
    (Icons.assignment_outlined, 'Tareas'),
    (Icons.grade_outlined, 'Calificaciones'),
    (Icons.campaign_outlined, 'Comunicados'),
    (Icons.emoji_events_outlined, 'Logros'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: _items.take(3).map((i) => _buildItem(context, i)).toList()),
        const SizedBox(height: 10),
        Row(children: _items.skip(3).map((i) => _buildItem(context, i)).toList()),
      ],
    );
  }

  Widget _buildItem(BuildContext context, (IconData, String) item) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              width: sizes.circleIconAccesos,
              height: sizes.circleIconAccesos,
              decoration: const BoxDecoration(
                color: _kPrimaryLt,
                shape: BoxShape.circle,
              ),
              child: Icon(item.$1, size: sizes.glyphAccesos, color: _kPrimary),
            ),
            const SizedBox(height: 8),
            Text(item.$2,
                style: TextStyle(
                    fontSize: sizes.textLabelAccesos, color: _kTextDark)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Card: conectar Google Classroom del docente
// ─────────────────────────────────────────────────────────
class _ClassroomConnectCard extends StatelessWidget {
  final bool waitingConfirm;
  final VoidCallback onConnect;
  final VoidCallback onVerify;

  const _ClassroomConnectCard({
    required this.waitingConfirm,
    required this.onConnect,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE8FA), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: sizes.circleIconNovedades,
                height: sizes.circleIconNovedades,
                decoration: const BoxDecoration(
                  color: _kPrimaryLt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_outlined,
                    color: _kPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Conecta Google Classroom',
                        style: TextStyle(
                          fontSize: sizes.textValueCard,
                          fontWeight: FontWeight.w700,
                          color: _kTextDark,
                        )),
                    const SizedBox(height: 2),
                    Text('Sincroniza tus cursos y alumnos',
                        style: TextStyle(
                          fontSize: sizes.textLabelCard,
                          color: _kTextGray,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.link, size: 16, color: Colors.white),
              label: Text('Conectar con Google',
                  style: TextStyle(
                    fontSize: sizes.textValueCard,
                    fontWeight: FontWeight.w700,
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (waitingConfirm) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary),
                ),
                const SizedBox(width: 8),
                Text('Verificando conexión...',
                    style: TextStyle(fontSize: sizes.textLabelCard, color: _kTextGray)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Bottom Nav (4 tabs: Inicio, Alumnos, Bandeja, Perfil)
// ─────────────────────────────────────────────────────────
class _BottomNavDocente extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  const _BottomNavDocente({required this.selected, required this.onTap});

  static const _items = [
    ('assets/icons/ic_nav_inicio.svg', 'Inicio', null),
    (null, 'Alumnos', Icons.groups_outlined),
    ('assets/icons/ic_nav_bandeja.svg', 'Bandeja', null),
    ('assets/icons/ic_nav_perfil.svg', 'Perfil', null),
  ];

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SizedBox(
              height: 64,
              child: Row(
                children: _items.asMap().entries.map((e) {
                  final i = e.key;
                  final (asset, label, materialIcon) = e.value;
                  final active = i == selected;
                  final color = active ? _kPrimary : _kNavInact;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          asset != null
                              ? SvgPicture.asset(
                                  asset,
                                  width: sizes.iconBottomNav,
                                  height: sizes.iconBottomNav,
                                  colorFilter:
                                      ColorFilter.mode(color, BlendMode.srcIn),
                                )
                              : Icon(materialIcon,
                                  size: sizes.iconBottomNav, color: color),
                          const SizedBox(height: 4),
                          Text(label,
                              style: TextStyle(
                                fontSize: sizes.textLabelBottomNav,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: color,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Tab Perfil — solo cerrar sesión (compartido con home padre)
// ─────────────────────────────────────────────────────────
class PerfilTab extends StatelessWidget {
  const PerfilTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.read<AuthBloc>().add(const LogoutEvent()),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Cerrar sesión',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFBA3428),
              side: const BorderSide(color: Color(0xFFBA3428)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }
}
