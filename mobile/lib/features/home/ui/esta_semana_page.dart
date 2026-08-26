import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../classroom/data/models/gc_models.dart';
import '../../classroom/data/repository/classroom_repository.dart';
import '../../../core/utils/lima_date.dart';

const _kBg        = Color(0xFFF7F6F3);
const _kPrimary   = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kDark      = Color(0xFF1E1B29);
const _kGray      = Color(0xFF666666);
const _kGrayLt    = Color(0xFF999999);
const _kLine      = Color(0xFFE5E5EB);
const _kOverdue   = Color(0xFFB91C1C);
const _kOverdueBg = Color(0xFFFEE2E2);

// ── Helpers de semana ──────────────────────────────────────
// "Esta semana" arranca al día siguiente de hoy: el día actual ya lo
// cubre la pestaña/tarjeta "Hoy", así que no se duplica aquí.
(DateTime, DateTime) _currentWeekBounds() {
  final today = limaToday();
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final end = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  final start = today.add(const Duration(days: 1));
  return (start, end);
}

List<GcCoursework> _filterThisWeek(List<GcCoursework> all) {
  final (start, end) = _currentWeekBounds();
  return all.where((cw) {
    if (cw.dueDate == null) return false;
    final d = limaDay(cw.dueDate!);
    return !d.isBefore(start) && !d.isAfter(end);
  }).toList()
    ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
}

String _workTypeLabel(String type) {
  switch (type.toUpperCase()) {
    case 'ASSIGNMENT':               return 'Tarea';
    case 'SHORT_ANSWER_QUESTION':    return 'Pregunta';
    case 'MULTIPLE_CHOICE_QUESTION': return 'Cuestionario';
    default:                         return 'Tarea';
  }
}

IconData _workTypeIcon(String type) {
  switch (type.toUpperCase()) {
    case 'SHORT_ANSWER_QUESTION':
    case 'MULTIPLE_CHOICE_QUESTION': return Icons.quiz_outlined;
    default:                         return Icons.assignment_outlined;
  }
}

// ── Página principal ───────────────────────────────────────
class EstaSemanPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  // Lista ya cargada en el home. Si viene, la página abre al instante
  // sin esperar otra llamada de red.
  final List<GcCoursework>? initialData;

  const EstaSemanPage({
    super.key,
    required this.studentId,
    required this.studentName,
    this.initialData,
  });

  @override
  State<EstaSemanPage> createState() => _EstaSemanPageState();
}

class _EstaSemanPageState extends State<EstaSemanPage> {
  late Future<List<GcCoursework>> _future;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = ClassroomRepository(context.read<ApiClient>());
    // Si ya tenemos los datos del home, los usamos al instante.
    _future = widget.initialData != null
        ? Future.value(widget.initialData)
        : repo.getUpcoming(widget.studentId);
  }

  // Pull-to-refresh: recarga desde la red (no usa la caché del home).
  Future<void> _refresh() async {
    final repo = ClassroomRepository(context.read<ApiClient>());
    final fresh = await repo.getUpcoming(widget.studentId);
    if (!mounted) return;
    setState(() => _future = Future.value(fresh));
  }

  Future<void> _connectClassroom() async {
    // Evita doble toque: deshabilita el botón mientras se procesa.
    if (_connecting) return;
    setState(() => _connecting = true);
    try {
      final url = await ClassroomRepository(context.read<ApiClient>())
          .getAuthUrl(widget.studentId);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el navegador: $e')),
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  String _weekRangeLabel() {
    final (start, end) = _currentWeekBounds();
    final fmt = DateFormat('d MMM', 'es');
    return '${fmt.format(start)} – ${fmt.format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              weekRange: _weekRangeLabel(),
              studentName: widget.studentName,
            ),
            Expanded(
              child: FutureBuilder<List<GcCoursework>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError || !snap.hasData) {
                    return _ErrorState(
                      onConnect: _connectClassroom,
                      connecting: _connecting,
                    );
                  }
                  final week = _filterThisWeek(snap.data!);
                  if (week.isEmpty) return const _EmptyState();
                  return _WeeklyList(items: week, onRefresh: _refresh);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String weekRange;
  final String studentName;
  const _Header({required this.weekRange, required this.studentName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(11, 13, 16, 13),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_left, size: 28, color: _kDark),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Esta semana',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kDark),
              ),
              const SizedBox(height: 2),
              Text(
                '$studentName · $weekRange',
                style: const TextStyle(fontSize: 13, color: _kGray),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Lista agrupada por día ─────────────────────────────────
class _WeeklyList extends StatelessWidget {
  final List<GcCoursework> items;
  final Future<void> Function() onRefresh;
  const _WeeklyList({required this.items, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final todayNorm = limaToday();

    // Agrupar por día
    final Map<DateTime, List<GcCoursework>> byDay = {};
    for (final cw in items) {
      final day = limaDay(cw.dueDate!);
      byDay.putIfAbsent(day, () => []).add(cw);
    }
    final days = byDay.keys.toList()..sort();

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        itemCount: days.length,
        itemBuilder: (context, i) {
          final day = days[i];
          final isToday = day == todayNorm;
          final isPast = day.isBefore(todayNorm);
          return _DayGroup(
            day: day,
            tasks: byDay[day]!,
            isToday: isToday,
            isPast: isPast,
          );
        },
      ),
    );
  }
}

// ── Grupo por día ──────────────────────────────────────────
class _DayGroup extends StatelessWidget {
  final DateTime day;
  final List<GcCoursework> tasks;
  final bool isToday;
  final bool isPast;
  const _DayGroup({
    required this.day,
    required this.tasks,
    required this.isToday,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    final rawLabel = DateFormat('EEEE d MMM', 'es').format(day);
    final dayLabel = isToday ? 'Hoy · $rawLabel' : rawLabel;
    final labelColor = isToday ? _kPrimary : (isPast ? _kOverdue : _kGray);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                dayLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(height: 1, color: _kLine)),
              if (isPast && !isToday) ...[
                const SizedBox(width: 8),
                const Text('vencida',
                    style: TextStyle(fontSize: 10, color: _kOverdue)),
              ],
            ],
          ),
        ),
        ...tasks.map((cw) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TaskCard(cw: cw, isOverdue: isPast && !isToday),
            )),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ── Tarjeta de tarea ───────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final GcCoursework cw;
  final bool isOverdue;
  const _TaskCard({required this.cw, required this.isOverdue});

  @override
  Widget build(BuildContext context) {
    final bgColor = isOverdue ? _kOverdueBg : Colors.white;
    final accentColor = isOverdue ? _kOverdue : _kPrimary;
    final accentLt = isOverdue ? _kOverdueBg : _kPrimaryLt;
    final typeLabel = _workTypeLabel(cw.workType);
    final typeIcon = _workTypeIcon(cw.workType);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: isOverdue
            ? Border.all(color: _kOverdue.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: accentLt, shape: BoxShape.circle),
            child: Icon(typeIcon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  cw.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  cw.courseName,
                  style: TextStyle(
                    fontSize: 12,
                    color: accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Estados vacío / error ──────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconCircle(icon: Icons.check_circle_outline),
            SizedBox(height: 16),
            Text(
              'Sin pendientes esta semana',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _kDark),
            ),
            SizedBox(height: 6),
            Text(
              'Todas las tareas de Classroom están al día.',
              style: TextStyle(fontSize: 13, color: _kGrayLt),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onConnect;
  final bool connecting;
  const _ErrorState({required this.onConnect, required this.connecting});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _IconCircle(icon: Icons.cloud_off_outlined),
            const SizedBox(height: 16),
            const Text(
              'No se pudo cargar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _kDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Verifica que Classroom esté conectado.',
              style: TextStyle(fontSize: 13, color: _kGrayLt),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                // Misma lógica que el login: se deshabilita mientras se procesa.
                onPressed: connecting ? null : onConnect,
                icon: connecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.link, size: 18, color: Colors.white),
                label: Text(
                  connecting ? 'Conectando...' : 'Conectar con Google',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  // Color del botón deshabilitado (igual que el login).
                  disabledBackgroundColor: const Color(0xFF6F60AA),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  final IconData icon;
  const _IconCircle({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(color: _kPrimaryLt, shape: BoxShape.circle),
      child: Icon(icon, size: 32, color: _kPrimary),
    );
  }
}
