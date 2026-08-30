// ============================================================
// pendientes_page.dart — Pantalla "Pendientes" (Figma: 08 — Pendientes)
// ============================================================
// Destino al tocar las cards "Urgente para hoy" / "Esta semana" del
// Home del padre. Copiado 1:1 del frame de Figma "08 — Pendientes
// (hoy, semanal, calendario)": título, selector Hoy/Semana/Calendario,
// chips de filtro (Tareas/Comunicados/Reuniones) y lista de tarjetas.
//
// Por ahora solo el estado "Hoy" + "Tareas" tiene contenido real (el
// único diseñado en Figma) — el resto de combinaciones son solo
// visuales (cambian el chip/tab activo) hasta que se defina qué dato
// real debe mostrar cada una.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/manufacturer_settings_service.dart';
import '../../../core/utils/lima_date.dart';
import '../../classroom/data/models/gc_models.dart';

// Íconos exportados 1:1 desde Figma (exportAsync SVG_STRING) — se
// tiñen en runtime con colorFilter según el estado activo/inactivo,
// en vez de depender del stroke color fijo que trae cada SVG.
const _kSvgClipboardList =
    '<svg width="20" height="21" viewBox="0 0 20 21" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M8.33333 3.75H6.66667C6.22464 3.75 5.80072 3.93437 5.48816 4.26256C5.17559 4.59075 5 5.03587 5 5.5V16C5 16.4641 5.17559 16.9092 5.48816 17.2374C5.80072 17.5656 6.22464 17.75 6.66667 17.75H15C15.442 17.75 15.866 17.5656 16.1785 17.2374C16.4911 16.9092 16.6667 16.4641 16.6667 16V5.5C16.6667 5.03587 16.4911 4.59075 16.1785 4.26256C15.866 3.93437 15.442 3.75 15 3.75H13.3333M8.33333 3.75C8.33333 3.28587 8.50893 2.84075 8.82149 2.51256C9.13405 2.18437 9.55797 2 10 2H11.6667C12.1087 2 12.5326 2.18437 12.8452 2.51256C13.1577 2.84075 13.3333 3.28587 13.3333 3.75M8.33333 3.75C8.33333 4.21413 8.50893 4.65925 8.82149 4.98744C9.13405 5.31563 9.55797 5.5 10 5.5H11.6667C12.1087 5.5 12.5326 5.31563 12.8452 4.98744C13.1577 4.65925 13.3333 4.21413 13.3333 3.75M8.33333 9.875H8.34167M11.6667 9.875H13.3333M8.33333 13.375H8.34167M11.6667 13.375H13.3333" stroke="#186DE8" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

const _kBg = Color(0xFFF7F6F3);
// "Pendientes" (título del header) — gris medio, distinto del gris de
// subtítulo y del casi-negro de los títulos de tarjeta (medido en Figma).
const _kHeaderTitle = Color(0xFF444444);
const _kGray = Color(0xFF666666);
// Fondo compartido por tabs y chips en su estado inactivo.
const _kSegmentInactiveBg = Color(0xFFF0F0F0);

// Tab "Hoy" activo: ámbar sólido + texto blanco.
const _kHoyActiveBg = Color(0xFFE29A2E);
const _kAmberBadgeBg = Color(0xFFF6E0AB);
const _kAmberBadgeText = Color(0xFF693902);

// Chip de filtro (Tareas/Comunicados/Reuniones) activo — ámbar, mismo
// texto/badge que el tab "Hoy" pero con su propio fondo más clarito.
const _kChipActiveBg = Color(0xFFFBF0DD);

// Badge numérico (círculo) de los chips de filtro.
const _kChipBadgeInactiveBg = Color(0xFFDEDEDE);
const _kChipBadgeInactiveText = Color(0xFFA9A9A9);

// Separador vertical entre "Semana" y "Calendario" en el selector.
const _kTabDivider = Color(0xFFD0D7DF);

// Divisor horizontal dentro de la tarjeta de tarea, entre el subtítulo
// y el chip "Ver en classroom".
const _kCardDivider = Color(0xFFE5E5EA);

// Tarjeta de tarea (medido de nuevo en Figma): título y acento del
// ícono pasaron de violeta a una paleta azul, y "Ver en classroom" se
// convirtió en un chip/botón con fondo propio (antes era texto suelto).
const _kTaskTitle = Color(0xFF0C3271);
const _kTaskIconBg = Color(0xFFDFEBF7);
const _kTaskIconFg = Color(0xFF186DE8);

// Público: home_v2_page.dart lo usa para abrir esta pantalla ya
// posicionada en un tab específico (ej. "Esta semana" → RangoTab.semana).
enum RangoTab { hoy, semana, calendario }

enum _FiltroChip { tareas, comunicados, reuniones }

class PendientesPage extends StatefulWidget {
  final String studentName;
  // Tareas de Classroom que vencen HOY (ya cargadas por el Home vía
  // /parent/home — esta pantalla no hace su propia petición).
  final List<GcCoursework> todayTasks;
  // Tareas del resto de la semana (sin contar hoy) — ya cargadas y
  // filtradas por el Home con el mismo criterio que antes usaba
  // EstaSemanPage (que se eliminó; este tab absorbió su contenido).
  final List<GcCoursework> weekTasks;
  final RangoTab initialTab;

  const PendientesPage({
    super.key,
    this.studentName = '',
    this.todayTasks = const [],
    this.weekTasks = const [],
    this.initialTab = RangoTab.hoy,
  });

  @override
  State<PendientesPage> createState() => _PendientesPageState();
}

class _PendientesPageState extends State<PendientesPage> {
  late RangoTab _tab = widget.initialTab;
  _FiltroChip _filtro = _FiltroChip.tareas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: fondo blanco (esquinas inferiores redondeadas),
            // botón atrás circular + título + subtítulo ──
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(7, 13, 18, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: 27,
                      height: 27,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: _kSegmentInactiveBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left,
                          size: 20, color: _kHeaderTitle),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pendientes',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: _kHeaderTitle,
                          ),
                        ),
                        Text(
                          [
                            if (widget.studentName.isNotEmpty)
                              widget.studentName,
                            DateFormat("EEEE d 'de' MMMM", 'es')
                                .format(DateTime.now()),
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12, color: _kGray),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Selector Hoy / Semana / Calendario ──────
                    _RangoSelector(
                      selected: _tab,
                      onChanged: (t) => setState(() => _tab = t),
                      hoyCount: widget.todayTasks.length,
                      semanaCount: widget.weekTasks.length,
                    ),
                    const SizedBox(height: 8),

                    // ── Chips de filtro ──────────────────────────
                    Row(
                      children: [
                        _FiltroChipWidget(
                          label: 'Tareas',
                          // El conteo del chip sigue al tab activo: tareas de
                          // hoy en el tab Hoy, del resto de la semana en Semana.
                          count: _tab == RangoTab.semana
                              ? widget.weekTasks.length
                              : widget.todayTasks.length,
                          width: 80,
                          active: _filtro == _FiltroChip.tareas,
                          onTap: () =>
                              setState(() => _filtro = _FiltroChip.tareas),
                        ),
                        const SizedBox(width: 5),
                        _FiltroChipWidget(
                          // Sin datos reales de comunicados todavía — sin
                          // número hasta que se conecte a algo real.
                          label: 'Comunicados',
                          count: 0,
                          width: 112,
                          active: _filtro == _FiltroChip.comunicados,
                          onTap: () =>
                              setState(() => _filtro = _FiltroChip.comunicados),
                        ),
                        const SizedBox(width: 5),
                        _FiltroChipWidget(
                          // Sin datos reales de reuniones todavía — sin
                          // número hasta que se conecte a algo real.
                          label: 'Reuniones',
                          count: 0,
                          width: 90,
                          active: _filtro == _FiltroChip.reuniones,
                          onTap: () =>
                              setState(() => _filtro = _FiltroChip.reuniones),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Lista de tarjetas ────────────────────────
                    // Hoy y Semana + Tareas ya usan datos reales de
                    // Classroom. El resto (Calendario, Comunicados/
                    // Reuniones) sigue pendiente de conectar a datos reales.
                    if (_tab == RangoTab.hoy &&
                        _filtro == _FiltroChip.tareas) ...[
                      if (widget.todayTasks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(
                            child: Text(
                              'Sin tareas que venzan hoy.',
                              style: TextStyle(fontSize: 13, color: _kGray),
                            ),
                          ),
                        )
                      else
                        for (final cw in widget.todayTasks) ...[
                          _TaskCard(
                            title: cw.title,
                            subtitle: 'Vence hoy · ${cw.courseName}',
                            classroomLink: cw.alternateLink,
                          ),
                          const SizedBox(height: 8),
                        ],
                    ] else if (_tab == RangoTab.semana &&
                        _filtro == _FiltroChip.tareas) ...[
                      if (widget.weekTasks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(
                            child: Text(
                              'Sin pendientes esta semana.',
                              style: TextStyle(fontSize: 13, color: _kGray),
                            ),
                          ),
                        )
                      else
                        for (final cw in widget.weekTasks) ...[
                          if (cw.dueDate != null) ...[
                            _TaskCard(
                              title: cw.title,
                              subtitle:
                                  'Vence ${_relativeDayLabel(limaDay(cw.dueDate!))} · ${cw.courseName}',
                              classroomLink: cw.alternateLink,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(
                          child: Text(
                            'Todavía no hay datos para esta vista.',
                            style: TextStyle(fontSize: 13, color: _kGray),
                          ),
                        ),
                      ),
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

// ── Selector Hoy / Semana / Calendario ──────────────────────
// Tres segmentos contiguos (sin separación ni contenedor exterior):
// Hoy (redondeado a la izquierda) + Semana (recto) + Calendario
// (redondeado a la derecha), con una línea divisoria fina entre
// Semana y Calendario — copiado 1:1 de Figma.
class _RangoSelector extends StatelessWidget {
  final RangoTab selected;
  final ValueChanged<RangoTab> onChanged;
  final int hoyCount;
  final int semanaCount;

  const _RangoSelector({
    required this.selected,
    required this.onChanged,
    required this.hoyCount,
    required this.semanaCount,
  });

  // Proporciones exactas medidas en Figma (84 : 101 : 107 de 292 total).
  static const double _wHoy = 84;
  static const double _wSemana = 101;
  static const double _wCalendario = 107;
  static const double _wTotal = _wHoy + _wSemana + _wCalendario;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Separador entre Hoy/Semana y entre Semana/Calendario — los
        // tres segmentos son contiguos (sin gap), así que el límite
        // entre cada par se marca con esta línea fina, igual en ambos.
        final hoySemanaDividerX = constraints.maxWidth * _wHoy / _wTotal;
        final semanaCalendarioDividerX =
            constraints.maxWidth * (_wHoy + _wSemana) / _wTotal;
        return SizedBox(
          height: 30,
          child: Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: _wHoy.toInt(),
                    child: _RangoTabItem(
                      label: 'Hoy',
                      count: hoyCount,
                      radius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                      ),
                      active: selected == RangoTab.hoy,
                      onTap: () => onChanged(RangoTab.hoy),
                    ),
                  ),
                  Expanded(
                    flex: _wSemana.toInt(),
                    child: _RangoTabItem(
                      label: 'Semana',
                      count: semanaCount,
                      radius: BorderRadius.zero,
                      active: selected == RangoTab.semana,
                      onTap: () => onChanged(RangoTab.semana),
                    ),
                  ),
                  Expanded(
                    flex: _wCalendario.toInt(),
                    child: _RangoTabItem(
                      label: 'Calendario',
                      radius: const BorderRadius.only(
                        topRight: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                      active: selected == RangoTab.calendario,
                      onTap: () => onChanged(RangoTab.calendario),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: hoySemanaDividerX - 0.5,
                top: 7,
                child: Container(width: 1, height: 16, color: _kTabDivider),
              ),
              Positioned(
                left: semanaCalendarioDividerX - 0.5,
                top: 7,
                child: Container(width: 1, height: 16, color: _kTabDivider),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RangoTabItem extends StatelessWidget {
  final String label;
  final int count;
  final BorderRadius radius;
  final bool active;
  final VoidCallback onTap;

  const _RangoTabItem({
    required this.label,
    this.count = 0,
    required this.radius,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : _kGray;
    final badgeBg = active ? _kAmberBadgeBg : _kChipBadgeInactiveBg;
    final badgeFg = active ? _kAmberBadgeText : _kChipBadgeInactiveText;
    // Calendario es un modo sin conteo — sin badge, solo texto (igual
    // que en Figma, ya no muestra el ícono de calendario al costado).
    final showBadge = count > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        decoration: BoxDecoration(
          color: active ? _kHoyActiveBg : _kSegmentInactiveBg,
          borderRadius: radius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                color: fg,
              ),
            ),
            if (showBadge) ...[
              const SizedBox(width: 6),
              Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Chip de filtro (Tareas / Comunicados / Reuniones) ───────
class _FiltroChipWidget extends StatelessWidget {
  final String label;
  final int count;
  final double width;
  final bool active;
  final VoidCallback onTap;

  const _FiltroChipWidget({
    required this.label,
    required this.count,
    required this.width,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? _kChipActiveBg : _kSegmentInactiveBg;
    final fg = active ? _kAmberBadgeText : _kGray;
    final badgeBg = active ? _kAmberBadgeBg : _kChipBadgeInactiveBg;
    final badgeFg = active ? _kAmberBadgeText : _kChipBadgeInactiveText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 26,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg),
            ),
            // Si no hay pendientes en este chip, no se muestra ningún
            // número — solo el nombre.
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: badgeFg),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Etiqueta relativa de día (tab "Semana") ─────────────────
// En vez de un encabezado de fecha aparte por grupo de día, cada
// tarjeta dice "Vence mañana · curso" (si el día es mañana) o "Vence
// 29 Agosto · curso" (cualquier otro día) — mismo patrón de una sola
// línea que usa el tab "Hoy" ("Vence hoy · curso"). widget.weekTasks
// ya viene filtrado a "de mañana en adelante", así que "mañana"
// siempre es el primer día posible.
String _relativeDayLabel(DateTime day) {
  final tomorrow = limaToday().add(const Duration(days: 1));
  if (day == tomorrow) return 'mañana';
  final dayNum = DateFormat('d', 'es').format(day);
  final month = DateFormat('MMMM', 'es').format(day);
  final monthCap = month.isEmpty ? month : month[0].toUpperCase() + month.substring(1);
  return '$dayNum $monthCap';
}

// ── Tarjeta de tarea pendiente ───────────────────────────────
class _TaskCard extends StatelessWidget {
  final String title;
  final String subtitle;
  // Si la tarea trae link de Classroom, se muestra la fila "Ver en
  // classroom" (con el ícono oficial); si no, la tarjeta se queda solo
  // con el chevron — copiado 1:1 del comportamiento en Figma (la
  // tarjeta "Colorear mariposa" sí lo tiene, "Traer material..." no).
  final String? classroomLink;

  const _TaskCard({
    required this.title,
    required this.subtitle,
    this.classroomLink,
  });

  Future<void> _abrirClassroom() async {
    final link = classroomLink;
    if (link == null) return;
    // En Android, url_launcher abre la app externa dentro de la MISMA
    // tarea de Kolexa (sin FLAG_ACTIVITY_NEW_TASK) — funciona, pero en
    // "apps recientes" se ve como una sola tarjeta compartida en vez de
    // dos apps independientes. El canal nativo abre con esa bandera.
    final openedNative = await ManufacturerSettingsService.instance.openExternalUrl(link);
    if (openedNative) return;
    final uri = Uri.tryParse(link);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final tieneLink = classroomLink != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 13, 9, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: _kTaskIconBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SvgPicture.string(
                  _kSvgClipboardList,
                  width: 20,
                  height: 21,
                  colorFilter: const ColorFilter.mode(_kTaskIconFg, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kTaskTitle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: _kGray),
                    ),
                  ],
                ),
              ),
              if (!tieneLink)
                const Text('›',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _kTaskIconFg)),
            ],
          ),
          if (tieneLink) ...[
            const SizedBox(height: 13),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Container(height: 1, color: _kCardDivider),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: _abrirClassroom,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(13, 5, 10, 5),
                  decoration: BoxDecoration(
                    color: _kTaskIconBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icons/google_classroom_icon.png',
                        width: 16,
                        height: 16,
                      ),
                      const SizedBox(width: 11),
                      const Text(
                        'Ver en classroom',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kTaskIconFg,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('›',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _kTaskIconFg)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
