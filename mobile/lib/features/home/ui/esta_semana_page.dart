import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../classroom/data/models/gc_models.dart';
import '../../classroom/data/repository/classroom_repository.dart';

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
(DateTime, DateTime) _currentWeekBounds() {
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final start = DateTime(monday.year, monday.month, monday.day);
  final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  return (start, end);
}

List<GcCoursework> _filterThisWeek(List<GcCoursework> all) {
  final (start, end) = _currentWeekBounds();
  return all.where((cw) {
    if (cw.dueDate == null) return false;
    final d = DateTime(cw.dueDate!.year, cw.dueDate!.month, cw.dueDate!.day);
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

  const EstaSemanPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<EstaSemanPage> createState() => _EstaSemanPageState();
}

class _EstaSemanPageState extends State<EstaSemanPage> {
  late Future<List<GcCoursework>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = ClassroomRepository(context.read<ApiClient>());
    _future = repo.getUpcoming(widget.studentId);
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
                    return const _ErrorState();
                  }
                  final week = _filterThisWeek(snap.data!);
                  if (week.isEmpty) return const _EmptyState();
                  return _WeeklyList(items: week);
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
  const _WeeklyList({required this.items});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    // Agrupar por día
    final Map<DateTime, List<GcCoursework>> byDay = {};
    for (final cw in items) {
      final d = cw.dueDate!;
      final day = DateTime(d.year, d.month, d.day);
      byDay.putIfAbsent(day, () => []).add(cw);
    }
    final days = byDay.keys.toList()..sort();

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: () async {},
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
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconCircle(icon: Icons.cloud_off_outlined),
            SizedBox(height: 16),
            Text(
              'No se pudo cargar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _kDark),
            ),
            SizedBox(height: 6),
            Text(
              'Verifica que Classroom esté conectado.',
              style: TextStyle(fontSize: 13, color: _kGrayLt),
              textAlign: TextAlign.center,
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
