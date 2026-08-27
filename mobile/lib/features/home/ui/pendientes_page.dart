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
import '../../classroom/data/models/gc_models.dart';

// Íconos exportados 1:1 desde Figma (exportAsync SVG_STRING) — se
// tiñen en runtime con colorFilter según el estado activo/inactivo,
// en vez de depender del stroke color fijo que trae cada SVG.
const _kSvgClipboardList =
    '<svg width="20" height="21" viewBox="0 0 20 21" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M8.14286 3.77778H6.57143C6.15466 3.77778 5.75496 3.96508 5.46026 4.29848C5.16556 4.63187 5 5.08406 5 5.55556V16.2222C5 16.6937 5.16556 17.1459 5.46026 17.4793C5.75496 17.8127 6.15466 18 6.57143 18H14.4286C14.8453 18 15.245 17.8127 15.5397 17.4793C15.8344 17.1459 16 16.6937 16 16.2222V5.55556C16 5.08406 15.8344 4.63187 15.5397 4.29848C15.245 3.96508 14.8453 3.77778 14.4286 3.77778H12.8571M8.14286 3.77778C8.14286 3.30628 8.30842 2.8541 8.60312 2.5207C8.89782 2.1873 9.29752 2 9.71429 2H11.2857C11.7025 2 12.1022 2.1873 12.3969 2.5207C12.6916 2.8541 12.8571 3.30628 12.8571 3.77778M8.14286 3.77778C8.14286 4.24927 8.30842 4.70146 8.60312 5.03486C8.89782 5.36825 9.29752 5.55556 9.71429 5.55556H11.2857C11.7025 5.55556 12.1022 5.36825 12.3969 5.03486C12.6916 4.70146 12.8571 4.24927 12.8571 3.77778M8.14286 10H8.15071M11.2857 10H12.8571M8.14286 13.5556H8.15071M11.2857 13.5556H12.8571" stroke="#5B4A9E" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

const _kBg = Color(0xFFF7F6F3);
// "Pendientes" (título del header) — gris medio, distinto del gris de
// subtítulo y del casi-negro de los títulos de tarjeta (medido en Figma).
const _kHeaderTitle = Color(0xFF444444);
// Atrás (‹) + título de cada tarjeta de tarea.
const _kBack = Color(0xFF1E1B29);
const _kGray = Color(0xFF666666);
// Morado: acento de todo lo "activo" (chip seleccionado, tarjeta de
// tarea, link "Ver en classroom") — reemplazó al ámbar que tenía antes.
const _kPrimary = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);

// Fondo compartido por tabs y chips en su estado inactivo.
const _kSegmentInactiveBg = Color(0xFFF0F0F0);

// Tab "Hoy" activo: ámbar sólido + texto blanco.
const _kHoyActiveBg = Color(0xFFE29A2E);
const _kAmberBadgeBg = Color(0xFFF6E0AB);
const _kAmberBadgeText = Color(0xFF693902);

// Badge numérico (círculo) de los chips de filtro.
const _kChipBadgeActiveBg = Color(0xFFD4C9F0);
const _kChipBadgeInactiveBg = Color(0xFFDEDEDE);
const _kChipBadgeInactiveText = Color(0xFFA9A9A9);

// Separador vertical entre "Semana" y "Calendario" en el selector.
const _kTabDivider = Color(0xFFD0D7DF);

enum _RangoTab { hoy, semana, calendario }

enum _FiltroChip { tareas, comunicados, reuniones }

class PendientesPage extends StatefulWidget {
  final String studentName;
  // Tareas de Classroom que vencen HOY (ya cargadas por el Home vía
  // /parent/home — esta pantalla no hace su propia petición, igual que
  // EstaSemanPage reutiliza los datos que ya trajo el Home).
  final List<GcCoursework> todayTasks;
  // Conteo real del resto de la semana (ya calculado por el Home) —
  // solo alimenta el badge del tab "Semana"; el contenido de esa
  // pestaña sigue sin conectar a datos reales.
  final int weekCount;

  const PendientesPage({
    super.key,
    this.studentName = '',
    this.todayTasks = const [],
    this.weekCount = 0,
  });

  @override
  State<PendientesPage> createState() => _PendientesPageState();
}

class _PendientesPageState extends State<PendientesPage> {
  _RangoTab _tab = _RangoTab.hoy;
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
                      child: const Text('‹',
                          style: TextStyle(fontSize: 20, color: _kBack)),
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
                      semanaCount: widget.weekCount,
                    ),
                    const SizedBox(height: 8),

                    // ── Chips de filtro ──────────────────────────
                    Row(
                      children: [
                        _FiltroChipWidget(
                          label: 'Tareas',
                          count: widget.todayTasks.length,
                          width: 73,
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
                    // Hoy + Tareas ya usa datos reales de Classroom (las
                    // tareas que vencen hoy). El resto de combinaciones
                    // (Semana/Calendario, Comunicados/Reuniones) sigue
                    // pendiente de conectar a datos reales.
                    if (_tab == _RangoTab.hoy &&
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
  final _RangoTab selected;
  final ValueChanged<_RangoTab> onChanged;
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
                      active: selected == _RangoTab.hoy,
                      onTap: () => onChanged(_RangoTab.hoy),
                    ),
                  ),
                  Expanded(
                    flex: _wSemana.toInt(),
                    child: _RangoTabItem(
                      label: 'Semana',
                      count: semanaCount,
                      radius: BorderRadius.zero,
                      active: selected == _RangoTab.semana,
                      onTap: () => onChanged(_RangoTab.semana),
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
                      active: selected == _RangoTab.calendario,
                      onTap: () => onChanged(_RangoTab.calendario),
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
    final bg = active ? _kPrimaryLt : _kSegmentInactiveBg;
    final fg = active ? _kPrimary : _kGray;
    final badgeBg = active ? _kChipBadgeActiveBg : _kChipBadgeInactiveBg;
    final badgeFg = active ? _kPrimary : _kChipBadgeInactiveText;
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
      padding: const EdgeInsets.fromLTRB(12, 13, 9, 9),
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
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: _kPrimaryLt,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SvgPicture.string(
                  _kSvgClipboardList,
                  width: 20,
                  height: 21,
                  colorFilter: const ColorFilter.mode(_kPrimary, BlendMode.srcIn),
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
                        color: _kBack,
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
                        color: _kPrimary)),
            ],
          ),
          if (tieneLink) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: _abrirClassroom,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Image.asset(
                    'assets/icons/google_classroom_icon.png',
                    width: 17,
                    height: 17,
                  ),
                  const SizedBox(width: 2),
                  const Text(
                    'Ver en classroom',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('›',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _kPrimary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
