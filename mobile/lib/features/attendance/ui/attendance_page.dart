import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../teachers/data/teacher_repository.dart';

// ─── Colores ────────────────────────────────────────────────
const _kBg = Color(0xFFF7F6F3);
const _kPrimary = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kGreen = Color(0xFF1F6B44);
const _kGreenBg = Color(0xFFE0EFE5);
const _kAmber = Color(0xFF693902);
const _kAmberBg = Color(0xFFFAEED3);
const _kRed = Color(0xFFBA3428);
const _kRedBg = Color(0xFFFAE6E5);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);
const _kTextMid = Color(0xFF999999);

// ─── Modelo local (solo layout) ─────────────────────────────
enum AttendanceStatus { none, present, late, absent }

class StudentAttendanceItem {
  final int id;     // gc_course_students.id (DB)
  final String name;
  String? note;
  AttendanceStatus status;

  StudentAttendanceItem({
    required this.id,
    required this.name,
    this.note,
    this.status = AttendanceStatus.none,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, 2).toUpperCase();
  }
}

// ─── AttendancePage ─────────────────────────────────────────
class AttendancePage extends StatefulWidget {
  final String classroomName;
  final String dateLabel;
  final TeacherRepository repo;

  const AttendancePage({
    super.key,
    required this.classroomName,
    required this.dateLabel,
    required this.repo,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<StudentAttendanceItem> _students = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    try {
      final roster = await widget.repo.getClassroomRoster();
      setState(() {
        _students = roster
            .map((s) => StudentAttendanceItem(
                  id: s.id,
                  name: s.fullName,
                  status: AttendanceStatus.present,
                ))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudo cargar la lista de alumnos';
        _loading = false;
      });
    }
  }

  int get _presentCount =>
      _students.where((s) => s.status == AttendanceStatus.present).length;
  int get _lateCount =>
      _students.where((s) => s.status == AttendanceStatus.late).length;
  int get _absentCount =>
      _students.where((s) => s.status == AttendanceStatus.absent).length;

  void _setStatus(StudentAttendanceItem student, AttendanceStatus status) {
    setState(() {
      student.status =
          student.status == status ? AttendanceStatus.none : status;
      if (student.status != AttendanceStatus.late) student.note = null;
    });
  }

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _onSave() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final records = _students
          .where((s) => s.status != AttendanceStatus.none)
          .map((s) => {
                'gcStudentId': s.id,
                'status': s.status.name,
                if (s.note != null) 'note': s.note!,
              })
          .toList();

      await widget.repo.saveAttendance(date: _todayDate, records: records);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al guardar la asistencia'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _saving = false);
      return;
    }

    setState(() => _saving = false);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PhotoModal(
        onConfirm: (photos) async {
          try {
            if (photos.isNotEmpty) {
              await widget.repo.uploadAttendancePhotos(
                date: _todayDate,
                photoPaths: photos.map((p) => p.path).toList(),
              );
            }
          } catch (_) {}
          if (!mounted) return;
          Navigator.pop(context); // cierra modal
          Navigator.pop(context); // vuelve al home
        },
        onSkip: () {
          Navigator.pop(context); // cierra modal
          Navigator.pop(context); // vuelve al home
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 20, color: _kTextDark),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Tomar asistencia',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _kTextDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 17),
                    child: Text(
                      '${widget.classroomName} · ${widget.dateLabel}',
                      style: const TextStyle(fontSize: 12, color: _kTextGray),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Chips de resumen ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _SummaryChip(
                    count: _presentCount,
                    label: 'temprano',
                    icon: Icons.check_rounded,
                    bg: _kGreenBg,
                    fg: _kGreen,
                  ),
                  const SizedBox(width: 10),
                  _SummaryChip(
                    count: _lateCount,
                    label: 'tarde',
                    icon: Icons.schedule_rounded,
                    bg: _kAmberBg,
                    fg: _kAmber,
                  ),
                  const SizedBox(width: 10),
                  _SummaryChip(
                    count: _absentCount,
                    label: 'ausente',
                    icon: Icons.close_rounded,
                    bg: _kRedBg,
                    fg: _kRed,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Lista de estudiantes ──────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _kPrimary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: _kTextGray, size: 36),
                              const SizedBox(height: 10),
                              Text(_error!,
                                  style: const TextStyle(
                                      color: _kTextGray, fontSize: 13)),
                              const SizedBox(height: 14),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _loading = true;
                                    _error = null;
                                  });
                                  _loadRoster();
                                },
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _students.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _StudentCard(
                            student: _students[i],
                            onStatusChanged: (s) =>
                                _setStatus(_students[i], s),
                          ),
                        ),
            ),

            // ── Botón guardar ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'guardar asistencia',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
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

// ─── _SummaryChip ────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final int count;
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;

  const _SummaryChip({
    required this.count,
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(icon, size: 16, color: fg),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    height: 1.0,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _StudentCard ─────────────────────────────────────────────
class _StudentCard extends StatelessWidget {
  final StudentAttendanceItem student;
  final void Function(AttendanceStatus) onStatusChanged;

  const _StudentCard({
    required this.student,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isAbsent = student.status == AttendanceStatus.absent;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: _kPrimaryLt,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              student.initials,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _kPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Nombre + nota
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isAbsent ? FontWeight.w400 : FontWeight.w600,
                    color: isAbsent ? _kTextMid : _kTextDark,
                  ),
                ),
                if (student.note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    student.note!,
                    style: const TextStyle(
                        fontSize: 10, color: _kTextMid),
                  ),
                ],
              ],
            ),
          ),
          // Botones de estado
          _ActionBtn(
            icon: Icons.check_rounded,
            selected: student.status == AttendanceStatus.present,
            selectedBg: _kGreenBg,
            selectedFg: _kGreen,
            onTap: () => onStatusChanged(AttendanceStatus.present),
          ),
          const SizedBox(width: 8),
          _ActionBtn(
            icon: Icons.schedule_rounded,
            selected: student.status == AttendanceStatus.late,
            selectedBg: _kAmberBg,
            selectedFg: _kAmber,
            onTap: () => onStatusChanged(AttendanceStatus.late),
          ),
          const SizedBox(width: 8),
          _ActionBtn(
            icon: Icons.close_rounded,
            selected: student.status == AttendanceStatus.absent,
            selectedBg: _kRedBg,
            selectedFg: _kRed,
            onTap: () => onStatusChanged(AttendanceStatus.absent),
          ),
        ],
      ),
    );
  }
}

// ─── _ActionBtn ──────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final Color selectedBg;
  final Color selectedFg;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.selected,
    required this.selectedBg,
    required this.selectedFg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? selectedBg
                : const Color(0xFFE5E5E5),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 14,
          color: selected ? selectedFg : const Color(0xFFD0D0D0),
        ),
      ),
    );
  }
}

// ─── PhotoModal ──────────────────────────────────────────────
class PhotoModal extends StatefulWidget {
  final Future<void> Function(List<XFile>) onConfirm;
  final VoidCallback onSkip;

  const PhotoModal({super.key, required this.onConfirm, required this.onSkip});

  @override
  State<PhotoModal> createState() => _PhotoModalState();
}

class _PhotoModalState extends State<PhotoModal> {
  final _picker = ImagePicker();
  final List<XFile> _photos = [];
  bool _uploading = false;

  Future<void> _pickCamera() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 75,
    );
    if (photo != null) setState(() => _photos.add(photo));
  }

  Future<void> _pickGallery() async {
    final picked = await _picker.pickMultiImage(
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 75,
    );
    if (picked.isNotEmpty) setState(() => _photos.addAll(picked));
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<void> _confirm() async {
    setState(() => _uploading = true);
    await widget.onConfirm(List.unmodifiable(_photos));
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 32 + MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: _kPrimaryLt,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('📷', style: TextStyle(fontSize: 28)),
            ),
            const SizedBox(height: 20),
            const Text(
              'antes de guardar',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _kTextDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'sube una foto de inicio del día de tus niños',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _kTextGray),
            ),

            // ── Miniaturas seleccionadas ───────────────────
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(_photos[i].path),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removePhoto(i),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Botón tomar foto ───────────────────────────
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _uploading ? null : _pickCamera,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('tomar foto',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),

            // ── Botón galería ──────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: _uploading ? null : _pickGallery,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPrimary,
                  side: const BorderSide(color: _kPrimary, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('elegir de galería',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),

            // ── Botón confirmar (solo con fotos) ───────────
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _uploading ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _uploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'guardar fotos y asistencia',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            GestureDetector(
              onTap: _uploading ? null : widget.onSkip,
              child: Text(
                'ahora no',
                style: TextStyle(
                    fontSize: 13,
                    color: _uploading ? _kTextMid : _kTextGray),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SuccessSheet ─────────────────────────────────────────────
class SuccessSheet extends StatelessWidget {
  final int presentCount;
  final int totalCount;
  final String dateLabel;
  final VoidCallback onDone;

  const SuccessSheet({
    super.key,
    required this.presentCount,
    required this.totalCount,
    required this.dateLabel,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDone,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Container(
          decoration: BoxDecoration(
            color: _kGreenBg,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '✓',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _kGreen,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'asistencia y foto del día listas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _kGreen,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$presentCount de $totalCount presentes · $dateLabel',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: _kTextGray),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
