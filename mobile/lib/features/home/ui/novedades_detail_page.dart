import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../classroom/data/repository/classroom_repository.dart';

const _kBg        = Color(0xFFF7F6F3);
const _kPrimary   = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kDark      = Color(0xFF1E1B29);
const _kGray      = Color(0xFF666666);
const _kGrayLt    = Color(0xFF999999);
const _kLine      = Color(0xFFE5E5EB);
const _kRecess    = Color(0xFFEBEBEB);
const _kRecessTx  = Color(0xFF595959);
const _kGreen     = Color(0xFF145D10);
const _kGreenBg   = Color(0xFFE2F9E3);
const _kGreenMid  = Color(0xFF5D805A);
const _kGreenLine = Color(0xFFB2D9B2);

class NovedadesDetailPage extends StatelessWidget {
  final TodaySummary summary;
  final String childName;
  final String dateLabel;

  const NovedadesDetailPage({
    super.key,
    required this.summary,
    required this.childName,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(childName: childName, dateLabel: dateLabel),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel('Hora de llegada'),
                    const SizedBox(height: 8),
                    _ArrivalCard(summary: summary),
                    if (summary.photoCount > 0) ...[
                      const SizedBox(height: 24),
                      _SectionLabel('Fotos de hoy · ${summary.photoCount}'),
                      const SizedBox(height: 8),
                      _PhotoGrid(urls: summary.photoUrls),
                    ],
                    const SizedBox(height: 24),
                    const _SectionLabel('Horario de hoy'),
                    const SizedBox(height: 8),
                    if (summary.scheduleBlocks.isEmpty)
                      const _EmptyHint('Sin horario registrado para hoy')
                    else
                      _ScheduleTimeline(blocks: summary.scheduleBlocks),
                  ],
                ),
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
  final String childName;
  final String dateLabel;
  const _Header({required this.childName, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(11, 13, 16, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                'Resumen del día',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kDark),
              ),
              const SizedBox(height: 2),
              Text(
                '$childName · $dateLabel',
                style: const TextStyle(fontSize: 13, color: _kGray),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 11, color: _kGray));
  }
}

// ── Arrival card ───────────────────────────────────────────
class _ArrivalCard extends StatelessWidget {
  final TodaySummary summary;
  const _ArrivalCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.arrivalStatus == null) {
      return const _EmptyHint('Sin datos de llegada');
    }

    final time = summary.arrivalTime ?? '–';
    final isAbsent = summary.arrivalStatus == 'absent';
    final statusWord = switch (summary.arrivalStatus) {
      'present' => 'temprano',
      'late'    => 'tarde',
      'absent'  => 'ausente',
      _         => summary.arrivalStatus ?? '',
    };
    final subtitle = isAbsent
        ? 'no asistió hoy'
        : '$statusWord · al momento de tomar la asistencia';

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
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: _kPrimaryLt, shape: BoxShape.circle),
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/ic_ahora.svg',
                width: 20,
                colorFilter: const ColorFilter.mode(_kPrimary, BlendMode.srcIn),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kDark),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: _kGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Schedule timeline ──────────────────────────────────────
class _ScheduleTimeline extends StatelessWidget {
  final List<ScheduleBlock> blocks;
  const _ScheduleTimeline({required this.blocks});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < blocks.length; i++)
          _TimelineRow(block: blocks[i], isLast: i == blocks.length - 1),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final ScheduleBlock block;
  final bool isLast;
  const _TimelineRow({required this.block, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(block.startTime, style: const TextStyle(fontSize: 10, color: _kGrayLt)),
                    const SizedBox(width: 4),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: block.isActive ? _kGreen : Colors.white,
                        border: Border.all(
                          color: block.isActive ? _kGreen : _kLine,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: _kLine,
                      margin: const EdgeInsets.only(right: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BlockCard(block: block),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  final ScheduleBlock block;
  const _BlockCard({required this.block});

  @override
  Widget build(BuildContext context) {
    final isRecess = block.type == 'recess' || block.type == 'break' || block.type == 'lunch';
    final isActive = block.isActive;
    final hasTask = block.task != null;
    final showTaskSection = !isRecess && (isActive || hasTask);

    final bgColor    = isRecess ? _kRecess : (isActive ? _kGreenBg : _kPrimaryLt);
    final titleColor = isRecess ? _kRecessTx : (isActive ? _kGreen : _kDark);
    final timeColor  = isRecess ? _kGrayLt : (isActive ? _kGreen : _kPrimary);
    final divColor   = isActive ? _kGreenLine : const Color(0xFFE5E5EA);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  block.courseName,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: titleColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isActive)
                Text('Ahora', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGreen)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${block.startTime} – ${block.endTime}',
            style: TextStyle(fontSize: 12, color: timeColor),
          ),
          if (showTaskSection) ...[
            const SizedBox(height: 10),
            Divider(height: 1, thickness: 1, color: divColor),
            const SizedBox(height: 10),
            if (hasTask) ...[
              Text(
                'tarea: ${block.task}',
                style: TextStyle(fontSize: 12, color: isActive ? _kGreen : _kPrimary),
              ),
              if (block.taskDue != null) ...[
                const SizedBox(height: 2),
                Text(
                  'vence ${block.taskDue}',
                  style: TextStyle(fontSize: 11, color: isActive ? _kGreenMid : _kPrimary),
                ),
              ],
            ] else
              Text(
                'sin tarea asignada por ahora',
                style: TextStyle(fontSize: 12, color: isActive ? _kGreenMid : _kGray),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Photo grid ─────────────────────────────────────────────
class _PhotoGrid extends StatelessWidget {
  final List<String> urls;
  const _PhotoGrid({required this.urls});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: urls.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => _openViewer(context, i),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CachedNetworkImage(
            imageUrl: urls[i],
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: _kPrimaryLt),
            errorWidget: (_, __, ___) => Container(color: _kRecess),
          ),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) =>
            _PhotoViewer(urls: urls, initialIndex: initialIndex),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

// ── Photo viewer ───────────────────────────────────────────
class _PhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _PhotoViewer({required this.urls, required this.initialIndex});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final target = (_current + delta).clamp(0, widget.urls.length - 1);
    _pageCtrl.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.urls.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Visor con swipe ──────────────────────────────
          PageView.builder(
            controller: _pageCtrl,
            itemCount: total,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.urls[i],
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
            ),
          ),

          // ── Barra superior: cerrar + contador ───────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_current + 1} / $total',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),

          // ── Flecha izquierda ─────────────────────────────
          if (_current > 0)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavArrow(
                  icon: Icons.chevron_left,
                  onTap: () => _go(-1),
                ),
              ),
            ),

          // ── Flecha derecha ───────────────────────────────
          if (_current < total - 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavArrow(
                  icon: Icons.chevron_right,
                  onTap: () => _go(1),
                ),
              ),
            ),

          // ── Indicadores de puntos ────────────────────────
          if (total > 1)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _current ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _current
                        ? Colors.white
                        : Colors.white38,
                    borderRadius: BorderRadius.circular(3),
                  ),
                )),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────
class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: const TextStyle(fontSize: 13, color: _kGrayLt)),
    );
  }
}
