import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../classroom/data/repository/classroom_repository.dart';

const _kBg          = Color(0xFFF7F6F3);
const _kHeaderTitle = Color(0xFF444444);
const _kBackPillBg  = Color(0xFFF0F0F0);
const _kSectionLbl  = Color(0xFF53515B);
const _kGray        = Color(0xFF666666);
const _kGrayLt      = Color(0xFF999999);
const _kLine        = Color(0xFFE5E5EB);
const _kRecess      = Color(0xFFEBEBEB);
const _kRecessTx    = Color(0xFF595959);
const _kGreen       = Color(0xFF145D10);
const _kGreenBg     = Color(0xFFE2F9E3);
const _kGreenMid    = Color(0xFF5D805A);
const _kGreenLine   = Color(0xFFB2D9B2);
const _kBlueBg      = Color(0xFFDFEBF7);
const _kBlueText    = Color(0xFF133597);
const _kBlueChevron = Color(0xFF186DE8);
const _kBlueLine    = Color(0xFFA7C5EF);

const _kSvgBook =
    '<svg width="13" height="15" viewBox="0 0 13 15" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M1 11.7431C1 12.1501 1.16556 12.5405 1.46026 12.8283C1.75496 13.1161 2.15466 13.2778 2.57143 13.2778H12V1H2.57143C2.15466 1 1.75496 1.16169 1.46026 1.44951C1.16556 1.73733 1 2.12769 1 2.53472V11.7431ZM1 11.7431C1 11.336 1.16556 10.9457 1.46026 10.6578C1.75496 10.37 2.15466 10.2083 2.57143 10.2083H12M4.14286 4.06944H8.85714" stroke="#133597" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

const _kSvgClipboardTask =
    '<svg width="12" height="13" viewBox="0 0 12 13" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M3.60714 1.99667H2.17857C1.79969 1.99667 1.43633 2.12801 1.16842 2.36181C0.90051 2.5956 0.75 2.9127 0.75 3.24333V10.7233C0.75 11.054 0.90051 11.3711 1.16842 11.6049C1.43633 11.8387 1.79969 11.97 2.17857 11.97H9.32143C9.70031 11.97 10.0637 11.8387 10.3316 11.6049C10.5995 11.3711 10.75 11.054 10.75 10.7233V3.24333C10.75 2.9127 10.5995 2.5956 10.3316 2.36181C10.0637 2.12801 9.70031 1.99667 9.32143 1.99667H7.89286M3.60714 1.99667C3.60714 1.66603 3.75765 1.34894 4.02556 1.11514C4.29347 0.881345 4.65683 0.75 5.03571 0.75H6.46429C6.84317 0.75 7.20653 0.881345 7.47444 1.11514C7.74235 1.34894 7.89286 1.66603 7.89286 1.99667M3.60714 1.99667C3.60714 2.3273 3.75765 2.6444 4.02556 2.87819C4.29347 3.11199 4.65683 3.24333 5.03571 3.24333H6.46429C6.84317 3.24333 7.20653 3.11199 7.47444 2.87819C7.74235 2.6444 7.89286 2.3273 7.89286 1.99667M3.60714 6.36H7.89286M3.60714 8.85333H7.89286" stroke="#133597" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

const _kSvgRecess =
    '<svg width="16" height="17" viewBox="0 0 16 17" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M7.82969 2.42259C7.67524 2.26631 7.58848 2.05435 7.58848 1.83333C7.58848 1.61232 7.67524 1.40036 7.82969 1.24408C7.98413 1.0878 8.1936 1 8.41201 1C8.63042 1 8.83989 1.0878 8.99433 1.24408C9.14877 1.40036 9.23554 1.61232 9.23554 1.83333C9.23554 2.05435 9.14877 2.26631 8.99433 2.42259C8.83989 2.57887 8.63042 2.66667 8.41201 2.66667C8.1936 2.66667 7.98413 2.57887 7.82969 2.42259Z" fill="#999999"/>'
    '<path d="M14.5885 15.1667C14.6977 15.1667 14.8024 15.1228 14.8796 15.0446C14.9569 14.9665 15.0002 14.8605 15.0002 14.75C15.0002 14.6395 14.9569 14.5335 14.8796 14.4554C14.8024 14.3772 14.6977 14.3333 14.5885 14.3333C14.4793 14.3333 14.3745 14.3772 14.2973 14.4554C14.2201 14.5335 14.1767 14.6395 14.1767 14.75C14.1767 14.8605 14.2201 14.9665 14.2973 15.0446C14.3745 15.1228 14.4793 15.1667 14.5885 15.1667Z" fill="#999999"/>'
    '<path d="M1.00024 12.6667L5.11789 13.5L5.73554 12.25M10.0591 16V12.6667L6.76495 10.1667L7.58848 5.16667M12.5297 8.5L10.0591 7.66667L7.58848 5.16667L3.47083 6V8.5M7.58848 1.83333C7.58848 2.05435 7.67524 2.26631 7.82969 2.42259C7.98413 2.57887 8.1936 2.66667 8.41201 2.66667C8.63042 2.66667 8.83989 2.57887 8.99433 2.42259C9.14877 2.26631 9.23554 2.05435 9.23554 1.83333C9.23554 1.61232 9.14877 1.40036 8.99433 1.24408C8.83989 1.0878 8.63042 1 8.41201 1C8.1936 1 7.98413 1.0878 7.82969 1.24408C7.67524 1.40036 7.58848 1.61232 7.58848 1.83333ZM14.5885 15.1667C14.6977 15.1667 14.8024 15.1228 14.8796 15.0446C14.9569 14.9665 15.0002 14.8605 15.0002 14.75C15.0002 14.6395 14.9569 14.5335 14.8796 14.4554C14.8024 14.3772 14.6977 14.3333 14.5885 14.3333C14.4793 14.3333 14.3745 14.3772 14.2973 14.4554C14.2201 14.5335 14.1767 14.6395 14.1767 14.75C14.1767 14.8605 14.2201 14.9665 14.2973 15.0446C14.3745 15.1228 14.4793 15.1667 14.5885 15.1667Z" stroke="#595959" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

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
            child: Container(
              width: 27,
              height: 27,
              margin: const EdgeInsets.only(right: 10),
              decoration: const BoxDecoration(color: _kBackPillBg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.chevron_left, size: 20, color: _kHeaderTitle),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resumen del día',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kHeaderTitle),
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
    return Text(text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _kSectionLbl));
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
            decoration: const BoxDecoration(color: _kGreenBg, shape: BoxShape.circle),
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/ic_ahora.svg',
                width: 20,
                colorFilter: const ColorFilter.mode(_kGreen, BlendMode.srcIn),
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kHeaderTitle),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: _kGray)),
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

    final bgColor      = isRecess ? _kRecess : (isActive ? _kGreenBg : _kBlueBg);
    final titleColor   = isRecess ? _kRecessTx : (isActive ? _kGreen : _kBlueText);
    final timeColor    = isRecess ? _kGrayLt : (isActive ? _kGreen : _kBlueText);
    final divColor     = isActive ? _kGreenLine : _kBlueLine;
    final taskColor    = isActive ? _kGreen : _kBlueText;
    final chevronColor = isActive ? _kGreen : _kBlueChevron;

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!isRecess) ...[
                SvgPicture.string(_kSvgBook,
                    width: 12,
                    colorFilter: ColorFilter.mode(titleColor, BlendMode.srcIn)),
                const SizedBox(width: 9),
              ] else ...[
                SvgPicture.string(_kSvgRecess, width: 14),
                const SizedBox(width: 9),
              ],
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
          Padding(
            padding: const EdgeInsets.only(left: 21),
            child: Text(
              '${block.startTime} – ${block.endTime}',
              style: TextStyle(fontSize: 11, color: timeColor),
            ),
          ),
          if (showTaskSection) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 21),
              child: Divider(height: 1, thickness: 1, color: divColor),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 21, top: 1),
                  child: hasTask
                      ? SvgPicture.string(_kSvgClipboardTask,
                          width: 11,
                          colorFilter: ColorFilter.mode(taskColor, BlendMode.srcIn))
                      : const SizedBox(width: 11),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: hasTask
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tarea: ${block.task}',
                              style: TextStyle(fontSize: 12, color: taskColor),
                            ),
                            if (block.taskDue != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'vence ${block.taskDue}',
                                style: TextStyle(fontSize: 11, color: isActive ? _kGreenMid : taskColor),
                              ),
                            ],
                          ],
                        )
                      : Text(
                          'sin tarea asignada por ahora',
                          style: TextStyle(fontSize: 12, color: isActive ? _kGreenMid : _kGray),
                        ),
                ),
                if (hasTask)
                  Text('›', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: chevronColor)),
              ],
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
            placeholder: (_, __) => Container(color: _kRecess),
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
