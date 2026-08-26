import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/notification_banner.dart';
import '../../announcements/bloc/announcements_bloc.dart';
import '../../announcements/ui/announcements_page.dart';
import 'home_docente_page.dart' show PerfilTab;
import '../data/director_repository.dart';
import 'director/salones_page.dart';
import 'director/personal_page.dart';
import 'director/pensiones_page.dart';

// ── Paleta ─────────────────────────────────────────────────
const _kBg        = Color(0xFFF7F6F3);
const _kPrimary   = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kDark      = Color(0xFF1E1B29);
const _kGray      = Color(0xFF666666);
const _kGrayLt    = Color(0xFF999999);
const _kNavInact  = Color(0xFF707070);
const _kChevron   = Color(0xFF8E8E93);

const _kYellowBg     = Color(0xFFFAEED3);
const _kYellowCircle = Color(0xFFF6E0AB);
const _kYellowText   = Color(0xFF693902);

// ── Página ─────────────────────────────────────────────────
class HomeDirectorPage extends StatefulWidget {
  const HomeDirectorPage({super.key});

  @override
  State<HomeDirectorPage> createState() => _HomeDirectorPageState();
}

class _HomeDirectorPageState extends State<HomeDirectorPage> {
  int _navIndex = 0;
  late Future<SchoolSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = DirectorRepository(context.read<ApiClient>()).getSchoolSummary();
  }

  Future<void> _onRefresh() async {
    final future = DirectorRepository(context.read<ApiClient>()).getSchoolSummary();
    setState(() => _summaryFuture = future);
    await future;
  }

  String _greeting(String name) {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días, $name';
    if (h < 19) return 'Buenas tardes, $name';
    return 'Buenas noches, $name';
  }

  String _todayLabel() {
    const days = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final now = DateTime.now();
    return '${days[now.weekday % 7]} ${now.day} de ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final firstName = user?.fullName.split(' ').first ?? 'Directora';
    final schoolName = user?.schoolName ?? 'Colegio';

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _navIndex == 2
                  ? const PerfilTab()
                  : RefreshIndicator(
                      color: _kPrimary,
                      onRefresh: _onRefresh,
                      child: FutureBuilder<SchoolSummary>(
                        future: _summaryFuture,
                        builder: (context, snapshot) {
                          final summary = snapshot.data;
                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Banner: notificaciones desactivadas ──
                                const NotificationBanner(),
                                const SizedBox(height: 12),

                                // ── Saludo ─────────────────────────────
                                Text(
                                  _greeting(firstName),
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: _kDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$schoolName · ${_todayLabel()}',
                                  style: const TextStyle(fontSize: 12, color: _kGray),
                                ),
                                const SizedBox(height: 20),

                                // ── Card: colegio ──────────────────────
                                _ColegioCard(schoolName: schoolName, summary: summary),
                                const SizedBox(height: 12),

                                // ── Alertas (solo si hay algo real que alertar) ──
                                if (summary != null &&
                                    (summary.classroomsWithoutAttendanceToday > 0 ||
                                        summary.overduePaymentsTotal > 0)) ...[
                                  _AlertCard(
                                    bgColor: _kYellowBg,
                                    circleColor: _kYellowCircle,
                                    textColor: _kYellowText,
                                    icon: Icons.notifications_outlined,
                                    title: 'necesita tu atención',
                                    subtitle: [
                                      if (summary.classroomsWithoutAttendanceToday > 0)
                                        '${summary.classroomsWithoutAttendanceToday} salones sin asistencia',
                                      if (summary.overduePaymentsTotal > 0)
                                        'S/ ${summary.overduePaymentsTotal.toStringAsFixed(2)} en pensiones vencidas',
                                    ].join(' · '),
                                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                                      MaterialPageRoute(
                                        builder: (_) => PensionesPage(
                                          overdueTotal: summary.overduePaymentsTotal,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // ── Resumen del colegio ────────────────
                                _ResumenCard(summary: summary),
                                const SizedBox(height: 12),

                                // ── Comunicados ────────────────────────
                                _ComunicadosCard(summary: summary),
                                const SizedBox(height: 20),

                                // ── Accesos rápidos ────────────────────
                                const Text(
                                  'Accesos Rápidos',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _kGray,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _AccesosRapidos(summary: summary),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
            _BottomNav(
              selected: _navIndex,
              onTap: (i) => setState(() => _navIndex = i),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card: colegio ──────────────────────────────────────────
class _ColegioCard extends StatelessWidget {
  final String schoolName;
  final SchoolSummary? summary;
  const _ColegioCard({required this.schoolName, required this.summary});

  @override
  Widget build(BuildContext context) {
    final subtitle = summary != null
        ? '${summary!.classroomCount} salones · ${summary!.studentCount} alumnos'
        : '—';
    return GestureDetector(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => const SalonesPage()),
      ),
      child: _BaseCard(
        child: Row(
          children: [
            _IconCircle(
              size: 44,
              bg: _kPrimaryLt,
              child: const Icon(Icons.school_outlined, color: _kPrimary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(schoolName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: _kDark)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: _kGray)),
                ],
              ),
            ),
            const _Chevron(),
          ],
        ),
      ),
    );
  }
}

// ── Alertas ────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final Color bgColor;
  final Color circleColor;
  final Color textColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _AlertCard({
    required this.bgColor,
    required this.circleColor,
    required this.textColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _IconCircle(
              size: 32,
              bg: circleColor,
              child: Icon(icon, color: textColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 11, color: textColor)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('›', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
          ],
        ),
      ),
    );
  }
}

// ── Resumen del colegio ────────────────────────────────────
class _ResumenCard extends StatelessWidget {
  final SchoolSummary? summary;
  const _ResumenCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final classroomsWithAttendance =
        s != null ? s.classroomCount - s.classroomsWithoutAttendanceToday : null;
    return GestureDetector(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => const SalonesPage()),
      ),
      child: _BaseCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Expanded(
                  child: Text('resumen del colegio',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: _kDark)),
                ),
                _Chevron(),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatItem(
                  icon: Icons.calendar_month_outlined,
                  label: 'aulas con asistencia',
                  value: s != null ? '$classroomsWithAttendance de ${s.classroomCount}' : '—',
                ),
                _StatItem(
                  icon: Icons.people_outline,
                  label: 'asistencia hoy',
                  value: s?.attendanceTodayPercent != null ? '${s!.attendanceTodayPercent}%' : '—',
                ),
                _StatItem(
                  icon: Icons.person_outline,
                  label: 'docentes en Classroom',
                  value: s != null ? '${s.teachersConnectedToClassroom} de ${s.teacherCount}' : '—',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          _IconCircle(
            size: 32,
            bg: _kPrimaryLt,
            child: Icon(icon, color: _kPrimary, size: 16),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(fontSize: 11, color: _kGray),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _kDark),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Comunicados ────────────────────────────────────────────
class _ComunicadosCard extends StatelessWidget {
  final SchoolSummary? summary;
  const _ComunicadosCard({required this.summary});

  String _relativeDate(DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    if (days <= 0) return 'hoy';
    if (days == 1) return 'hace 1 día';
    return 'hace $days días';
  }

  @override
  Widget build(BuildContext context) {
    final latest = summary?.latestAnnouncement;
    final subtitle = latest != null ? 'último: ${_relativeDate(latest.createdAt)}' : 'sin comunicados aún';
    return GestureDetector(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => AnnouncementsBloc(AnnouncementsDataSource(context.read<ApiClient>())),
            child: const AnnouncementsPage(),
          ),
        ),
      ),
      child: _BaseCard(
        child: Row(
          children: [
            _IconCircle(
              size: 32,
              bg: _kPrimaryLt,
              child: const Icon(Icons.campaign_outlined, color: _kPrimary, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(latest?.title ?? 'comunicados institucionales',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: _kDark)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: _kGray)),
                ],
              ),
            ),
            const _Chevron(),
          ],
        ),
      ),
    );
  }
}

// ── Accesos rápidos ────────────────────────────────────────
class _AccesosRapidos extends StatelessWidget {
  final SchoolSummary? summary;
  const _AccesosRapidos({required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback)>[
      (
        Icons.door_front_door_outlined,
        'salones',
        () => Navigator.of(context, rootNavigator: true)
            .push(MaterialPageRoute(builder: (_) => const SalonesPage())),
      ),
      (
        Icons.person_outline,
        'profesoras',
        () => Navigator.of(context, rootNavigator: true)
            .push(MaterialPageRoute(builder: (_) => const PersonalPage())),
      ),
      (
        Icons.receipt_long_outlined,
        'pensiones',
        () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => PensionesPage(overdueTotal: summary?.overduePaymentsTotal ?? 0),
              ),
            ),
      ),
    ];
    return Row(
      children: items.map((item) {
        return Expanded(
          child: GestureDetector(
            onTap: item.$3,
            child: Container(
              margin: EdgeInsets.only(
                right: item == items.last ? 0 : 9,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _IconCircle(
                    size: 36,
                    bg: _kPrimaryLt,
                    child: Icon(item.$1, color: _kPrimary, size: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(item.$2,
                      style: const TextStyle(fontSize: 12, color: _kDark)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Bottom Nav ─────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.selected, required this.onTap});

  static const _items = [
    ('assets/icons/ic_nav_inicio.svg', 'Inicio'),
    ('assets/icons/ic_nav_bandeja.svg', 'Bandeja'),
    ('assets/icons/ic_nav_perfil.svg', 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: _items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final active = i == selected;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        item.$1,
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(
                          active ? _kPrimary : _kNavInact,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                          color: active ? _kPrimary : _kNavInact,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────
class _BaseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const _BaseCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _IconCircle extends StatelessWidget {
  final double size;
  final Color bg;
  final Widget child;
  const _IconCircle({required this.size, required this.bg, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(child: child),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return const Text('›',
        style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: _kChevron));
  }
}
