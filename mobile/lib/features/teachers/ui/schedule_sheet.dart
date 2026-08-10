import 'package:flutter/material.dart';
import '../data/teacher_repository.dart';

// ── Paleta ────────────────────────────────────────────────
const _kBg = Color(0xFFF7F6F3);
const _kPrimary = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);
const _kWarnBg = Color(0xFFFEF3CD);
const _kWarnText = Color(0xFF8B5A00);
const _kLine = Color(0xFFBBB5D8);
const _kInputBg = Color(0xFFF2F1F4);
const _kRecreoBg = Color(0xFFE8F6EE);
const _kRecreoAccent = Color(0xFF2D8A5A);
const _kRecreoId = '__recreo__';

// ── Modelo ────────────────────────────────────────────────
class ScheduleEntry {
  final String courseId;
  final String courseName;
  final TimeOfDay from;
  final TimeOfDay to;

  const ScheduleEntry({
    required this.courseId,
    required this.courseName,
    required this.from,
    required this.to,
  });

  int get fromMins => from.hour * 60 + from.minute;
  int get toMins => to.hour * 60 + to.minute;

  bool conflictsWith(ScheduleEntry o) =>
      fromMins < o.toMins && toMins > o.fromMins;
}

String _fmtShort(TimeOfDay t) =>
    '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

String _fmtLong(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.period == DayPeriod.am ? 'am' : 'pm'}';
}

// ─────────────────────────────────────────────────────────
// Entrada: abre el modal de método (Pantalla 1)
// ─────────────────────────────────────────────────────────
void showCreateScheduleSheet(
  BuildContext context,
  List<GcTeacherCourse> courses,
  TeacherRepository repo, {
  VoidCallback? onSaved,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _MethodPickerSheet(courses: courses, repo: repo, onSaved: onSaved),
  );
}

// ─────────────────────────────────────────────────────────
// Pantalla 1 — Modal: elige método
// ─────────────────────────────────────────────────────────
class _MethodPickerSheet extends StatefulWidget {
  final List<GcTeacherCourse> courses;
  final TeacherRepository repo;
  final VoidCallback? onSaved;
  const _MethodPickerSheet({required this.courses, required this.repo, this.onSaved});

  @override
  State<_MethodPickerSheet> createState() => _MethodPickerSheetState();
}

class _MethodPickerSheetState extends State<_MethodPickerSheet> {
  // 0 = subir foto, 1 = manual
  int _selected = 0;

  void _onContinue() {
    final courses = widget.courses;
    final manual = _selected == 1;
    final nav = Navigator.of(context);
    nav.pop();
    if (manual) {
      final repo = widget.repo;
      final onSaved = widget.onSaved;
      Future.microtask(
        () => nav.push(
          MaterialPageRoute(
            builder: (_) => ScheduleBuilderPage(
                courses: courses, repo: repo, onSaved: onSaved),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        decoration: const BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Crea tu horario',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _kTextDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Elige cómo prefieres hacerlo',
              style: TextStyle(fontSize: 14, color: _kTextGray),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE5E5E5)),
            const SizedBox(height: 16),
            _OptionTile(
              selected: _selected == 0,
              icon: Icons.upload_outlined,
              title: 'subir foto o archivo',
              subtitle:
                  'Kolexa leera el contenido y creará tu horario, requiere revision',
              onTap: () => setState(() => _selected = 0),
            ),
            const SizedBox(height: 12),
            _OptionTile(
              selected: _selected == 1,
              icon: Icons.edit_calendar_outlined,
              title: 'llenarlo manualmente',
              subtitle: 'Día por día, tocando cada curso',
              onTap: () => setState(() => _selected = 1),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Seleccionar y crear',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _kPrimary : const Color(0xFFE5E5E5),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: _kPrimaryLt, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, color: _kPrimary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kTextDark)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: _kTextGray, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Pantalla 2 — Constructor de horario (pantalla completa)
// ─────────────────────────────────────────────────────────
class ScheduleBuilderPage extends StatefulWidget {
  final List<GcTeacherCourse> courses;
  final TeacherRepository repo;
  final VoidCallback? onSaved;
  const ScheduleBuilderPage(
      {super.key, required this.courses, required this.repo, this.onSaved});

  @override
  State<ScheduleBuilderPage> createState() => _ScheduleBuilderPageState();
}

class _ScheduleBuilderPageState extends State<ScheduleBuilderPage> {
  static const _dayLabels = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie'];
  static const _dayNames = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes'];

  int _selectedDay = 0;
  bool _saving = false;
  final Map<int, List<ScheduleEntry>> _schedule = {
    0: [], 1: [], 2: [], 3: [], 4: [],
  };

  String _pad(int n) => n.toString().padLeft(2, '0');

  Future<void> _save() async {
    final blocks = <Map<String, dynamic>>[];
    _schedule.forEach((day, entries) {
      for (final e in entries) {
        blocks.add({
          'gcCourseId': e.courseId,
          'dayOfWeek': day + 1,
          'startTime': '${_pad(e.from.hour)}:${_pad(e.from.minute)}',
          'endTime': '${_pad(e.to.hour)}:${_pad(e.to.minute)}',
        });
      }
    });

    if (blocks.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repo.saveSchedule(blocks);
      widget.onSaved?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar el horario')),
        );
      }
    }
  }

  Future<void> _onCourseTap({
    required String courseId,
    required String courseName,
  }) async {
    final existing = List<ScheduleEntry>.from(_schedule[_selectedDay]!);
    final entry = await showDialog<ScheduleEntry>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _TimeRangeDialog(
        courseId: courseId,
        courseName: courseName,
        dayName: _dayNames[_selectedDay],
        existingSlots: existing,
      ),
    );
    if (entry != null && mounted) {
      setState(() {
        _schedule[_selectedDay]!.add(entry);
        _schedule[_selectedDay]!
            .sort((a, b) => a.fromMins.compareTo(b.fromMins));
      });
    }
  }

  Future<void> _onSlotTap(ScheduleEntry entry) async {
    // Excluye la entrada actual para no detectarla como conflicto consigo misma
    final existing = _schedule[_selectedDay]!
        .where((e) => e.courseId != entry.courseId)
        .toList();
    final updated = await showDialog<ScheduleEntry>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _TimeRangeDialog(
        courseId: entry.courseId,
        courseName: entry.courseName,
        dayName: _dayNames[_selectedDay],
        existingSlots: existing,
        initialFrom: entry.from,
        initialTo: entry.to,
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        final list = _schedule[_selectedDay]!;
        final idx = list.indexWhere((e) => e.courseId == entry.courseId);
        if (idx != -1) list[idx] = updated;
        list.sort((a, b) => a.fromMins.compareTo(b.fromMins));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = _schedule[_selectedDay]!;
    final scheduledIds = slots.map((e) => e.courseId).toSet();
    final showRecreo = !scheduledIds.contains(_kRecreoId);
    final availableCourses = widget.courses
        .where((c) => !scheduledIds.contains(c.googleId))
        .toList();

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: _kTextDark),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Selecciona cursos',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _kTextDark)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE5E5E5)),
            // Body: columna izquierda (cursos) + columna derecha (horario)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Columna izquierda: lista de cursos ──────────
                  SizedBox(
                    width: 148,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(14, 14, 14, 8),
                          child: Text('CURSOS',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _kTextGray,
                                  letterSpacing: 1.0)),
                        ),
                        Expanded(
                          child: ListView(
                            padding:
                                const EdgeInsets.fromLTRB(10, 0, 10, 16),
                            children: [
                              if (showRecreo) ...[
                                _CourseListItem(
                                  name: 'Recreo',
                                  isRecreo: true,
                                  onTap: () => _onCourseTap(
                                      courseId: _kRecreoId,
                                      courseName: 'Recreo'),
                                ),
                                const SizedBox(height: 8),
                              ],
                              ...availableCourses.map((c) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 8),
                                    child: _CourseListItem(
                                      name: c.name,
                                      isRecreo: false,
                                      onTap: () => _onCourseTap(
                                          courseId: c.googleId,
                                          courseName: c.name),
                                    ),
                                  )),
                              if (showRecreo == false &&
                                  availableCourses.isEmpty)
                                const Padding(
                                  padding:
                                      EdgeInsets.fromLTRB(4, 8, 4, 0),
                                  child: Text(
                                    'todos los cursos están en el horario',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: _kTextGray,
                                        height: 1.4),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(
                      width: 1, color: Color(0xFFE5E5E5)),
                  // ── Columna derecha: tabs de día + timeline ──────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        // Selector de días
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 6),
                            itemCount: 5,
                            itemBuilder: (_, i) {
                              final sel = i == _selectedDay;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedDay = i),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color:
                                        sel ? _kPrimary : Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: sel
                                        ? null
                                        : Border.all(
                                            color: const Color(
                                                0xFFDDDDDD)),
                                  ),
                                  child: Text(
                                    _dayLabels[i],
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: sel
                                          ? Colors.white
                                          : _kTextGray,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            _dayNames[_selectedDay],
                            style: const TextStyle(
                                fontSize: 11, color: _kTextGray),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            child: _TimelineView(
                              slots: slots,
                              onSlotTap: _onSlotTap,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Botón guardar
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _kPrimary.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'confirmar y guardar',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Ítem de curso en la lista izquierda
// ─────────────────────────────────────────────────────────
class _CourseListItem extends StatelessWidget {
  final String name;
  final bool isRecreo;
  final VoidCallback onTap;

  const _CourseListItem({
    required this.name,
    required this.isRecreo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isRecreo ? _kRecreoBg : Colors.white;
    final accent = isRecreo ? _kRecreoAccent : _kPrimary;
    final border = isRecreo
        ? _kRecreoAccent.withValues(alpha: 0.25)
        : const Color(0xFFE5E5E5);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                name.toLowerCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isRecreo ? _kRecreoAccent : _kTextDark,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.add_rounded, size: 16, color: accent),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Timeline
// ─────────────────────────────────────────────────────────
class _TimelineView extends StatelessWidget {
  final List<ScheduleEntry> slots;
  final void Function(ScheduleEntry)? onSlotTap;
  const _TimelineView({required this.slots, this.onSlotTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...slots.map((s) => _TimelineRow(
              time: _fmtShort(s.from),
              showLine: true,
              child: _SlotCard(
                entry: s,
                onTap: onSlotTap != null ? () => onSlotTap!(s) : null,
              ),
            )),
        _TimelineRow(
          time: slots.isNotEmpty ? _fmtShort(slots.last.to) : '',
          showLine: false,
          child: const _EmptySlot(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String time;
  final Widget child;
  final bool showLine;

  const _TimelineRow({
    required this.time,
    required this.child,
    required this.showLine,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiempo + línea + punto
          SizedBox(
            width: 52,
            child: Stack(
              children: [
                if (showLine)
                  Positioned(
                    left: 44,
                    top: 12,
                    bottom: 0,
                    child: Container(width: 2, color: _kLine),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            time,
                            style: const TextStyle(
                                fontSize: 11,
                                color: _kTextGray,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                              color: _kPrimary, shape: BoxShape.circle),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final ScheduleEntry entry;
  final VoidCallback? onTap;
  const _SlotCard({required this.entry, this.onTap});

  bool get _isRecreo => entry.courseId == _kRecreoId;

  @override
  Widget build(BuildContext context) {
    final bg = _isRecreo ? _kRecreoBg : _kPrimaryLt;
    final nameColor = _isRecreo ? _kRecreoAccent : _kTextDark;
    final timeColor = _isRecreo ? _kRecreoAccent : _kPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.courseName.toLowerCase(),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: nameColor),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_fmtShort(entry.from)} – ${_fmtShort(entry.to)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: timeColor,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.edit_outlined,
                  size: 15,
                  color: _isRecreo
                      ? _kRecreoAccent.withValues(alpha: 0.6)
                      : _kPrimary.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFCCCCCC),
          style: BorderStyle.solid,
          width: 1.5,
        ),
      ),
      child: const Text(
        'toca un curso arriba para agregarlo aquí',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Pantalla 3 — Dialog: rango de hora
// ─────────────────────────────────────────────────────────
class _TimeRangeDialog extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String dayName;
  final List<ScheduleEntry> existingSlots;
  final TimeOfDay? initialFrom;
  final TimeOfDay? initialTo;

  const _TimeRangeDialog({
    required this.courseId,
    required this.courseName,
    required this.dayName,
    required this.existingSlots,
    this.initialFrom,
    this.initialTo,
  });

  @override
  State<_TimeRangeDialog> createState() => _TimeRangeDialogState();
}

class _TimeRangeDialogState extends State<_TimeRangeDialog> {
  late TimeOfDay _from;
  late TimeOfDay _to;

  @override
  void initState() {
    super.initState();
    if (widget.initialFrom != null) {
      _from = widget.initialFrom!;
      _to = widget.initialTo!;
    } else {
      final lastEnd = widget.existingSlots.isNotEmpty
          ? widget.existingSlots.last.to
          : const TimeOfDay(hour: 8, minute: 0);
      _from = lastEnd;
      _to = TimeOfDay(hour: (lastEnd.hour + 1) % 24, minute: lastEnd.minute);
    }
  }

  ScheduleEntry? get _conflict {
    final candidate = ScheduleEntry(
        courseId: widget.courseId,
        courseName: widget.courseName,
        from: _from,
        to: _to);
    for (final s in widget.existingSlots) {
      if (candidate.conflictsWith(s)) return s;
    }
    return null;
  }

  bool get _validRange =>
      _from.hour * 60 + _from.minute < _to.hour * 60 + _to.minute;

  Future<void> _pickTime(bool isFrom) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isFrom ? _from : _to,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  void _apply() {
    if (_conflict != null || !_validRange) return;
    Navigator.pop(
      context,
      ScheduleEntry(
        courseId: widget.courseId,
        courseName: widget.courseName,
        from: _from,
        to: _to,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conflict = _conflict;
    final canApply = conflict == null && _validRange;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Text(
              widget.courseName.toLowerCase(),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kTextDark),
            ),
            const SizedBox(height: 2),
            Text(
              widget.dayName,
              style: const TextStyle(fontSize: 14, color: _kTextGray),
            ),
            const SizedBox(height: 20),
            // Pickers
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('desde',
                          style:
                              TextStyle(fontSize: 12, color: _kTextGray)),
                      const SizedBox(height: 6),
                      _TimePicker(
                          value: _from, onTap: () => _pickTime(true)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('hasta',
                          style:
                              TextStyle(fontSize: 12, color: _kTextGray)),
                      const SizedBox(height: 6),
                      _TimePicker(
                          value: _to, onTap: () => _pickTime(false)),
                    ],
                  ),
                ),
              ],
            ),
            // Warning de cruce
            if (conflict != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _kWarnBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'esto se cruza con ${conflict.courseName.toLowerCase()} '
                      '(${_fmtShort(conflict.from)} – ${_fmtShort(conflict.to)})',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kWarnText),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'ajusta el rango para continuar',
                      style: TextStyle(fontSize: 12, color: _kWarnText),
                    ),
                  ],
                ),
              ),
            ] else if (!_validRange) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _kWarnBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'la hora de inicio debe ser antes de la hora de fin',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kWarnText),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Botón aplicar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canApply ? _apply : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canApply ? _kPrimary : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade400,
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('aplicar',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 8),
            // Cancelar
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Center(
                child: Text('cancelar',
                    style: TextStyle(fontSize: 14, color: _kTextGray)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  final TimeOfDay value;
  final VoidCallback onTap;
  const _TimePicker({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _kInputBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _fmtLong(value),
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _kTextDark),
        ),
      ),
    );
  }
}
