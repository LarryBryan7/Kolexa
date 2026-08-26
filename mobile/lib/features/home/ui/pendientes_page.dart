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

// Íconos exportados 1:1 desde Figma (exportAsync SVG_STRING) — se
// tiñen en runtime con colorFilter según el estado activo/inactivo,
// en vez de depender del stroke color fijo que trae cada SVG.
const _kSvgChecklist =
    '<svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M6.41004 13.3337H4.66671C4.31309 13.3337 3.97395 13.1932 3.7239 12.9431C3.47385 12.6931 3.33337 12.3539 3.33337 12.0003V4.00033C3.33337 3.6467 3.47385 3.30756 3.7239 3.05752C3.97395 2.80747 4.31309 2.66699 4.66671 2.66699H10C10.3537 2.66699 10.6928 2.80747 10.9428 3.05752C11.1929 3.30756 11.3334 3.6467 11.3334 4.00033V9.33366M9.33337 12.667L10.6667 14.0003L13.3334 11.3337M6.00004 5.33366H8.66671M6.00004 8.00033H7.33337" stroke="#693902" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

const _kSvgCalendarStats =
    '<svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M7.86333 14H3.33333C2.97971 14 2.64057 13.8595 2.39052 13.6095C2.14048 13.3594 2 13.0203 2 12.6667V4.66667C2 4.31304 2.14048 3.97391 2.39052 3.72386C2.64057 3.47381 2.97971 3.33333 3.33333 3.33333H11.3333C11.687 3.33333 12.0261 3.47381 12.2761 3.72386C12.5262 3.97391 12.6667 4.31304 12.6667 4.66667V7.33333H2M12 9.33333V12H14.6667M12 9.33333C12.7072 9.33333 13.3855 9.61428 13.8856 10.1144C14.3857 10.6145 14.6667 11.2928 14.6667 12M12 9.33333C11.2928 9.33333 10.6145 9.61428 10.1144 10.1144C9.61428 10.6145 9.33333 11.2928 9.33333 12C9.33333 12.7072 9.61428 13.3855 10.1144 13.8856C10.6145 14.3857 11.2928 14.6667 12 14.6667C12.7072 14.6667 13.3855 14.3857 13.8856 13.8856C14.3857 13.3855 14.6667 12.7072 14.6667 12M10 2V4.66667M4.66667 2V4.66667" stroke="white" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

const _kSvgSemana =
    '<svg width="14" height="13" viewBox="0 0 14 13" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M10.25 0.5V3.16667M3.75 0.5V3.16667M0.5 5.83333H13.5M2.9375 7.83333H2.94806M5.38313 7.83333H5.3872M7.82063 7.83333H7.8247M10.2622 7.83333H10.2663M7.8247 9.83333H7.82876M2.94563 9.83333H2.9497M5.38313 9.83333H5.3872M0.5 3.16667C0.5 2.81304 0.671205 2.47391 0.975951 2.22386C1.2807 1.97381 1.69402 1.83333 2.125 1.83333H11.875C12.306 1.83333 12.7193 1.97381 13.024 2.22386C13.3288 2.47391 13.5 2.81304 13.5 3.16667V11.1667C13.5 11.5203 13.3288 11.8594 13.024 12.1095C12.7193 12.3595 12.306 12.5 11.875 12.5H2.125C1.69402 12.5 1.2807 12.3595 0.975951 12.1095C0.671205 11.8594 0.5 11.5203 0.5 11.1667V3.16667Z" stroke="#050505" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

const _kSvgCalendario =
    '<svg width="14" height="13" viewBox="0 0 14 13" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M9.5473 0.5V3.09259M3.51577 0.5V3.09259M0.5 5.68519H12.5631M3.51577 7.62963V10.2222M6.53153 7.62963V10.2222M9.5473 7.62963V10.2222M0.5 3.09259C0.5 2.74879 0.658866 2.41908 0.941649 2.17597C1.22443 1.93287 1.60797 1.7963 2.00788 1.7963H11.0552C11.4551 1.7963 11.8386 1.93287 12.1214 2.17597C12.4042 2.41908 12.5631 2.74879 12.5631 3.09259V10.8704C12.5631 11.2142 12.4042 11.5439 12.1214 11.787C11.8386 12.0301 11.4551 12.1667 11.0552 12.1667H2.00788C1.60797 12.1667 1.22443 12.0301 0.941649 11.787C0.658866 11.5439 0.5 11.2142 0.5 10.8704V3.09259Z" stroke="#050505" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

const _kBg = Color(0xFFF7F6F3);
const _kTextDark = Color(0xFF14171C);
const _kBack = Color(0xFF1E1B29);
const _kChevron = Color(0xFF8E8E93);
const _kGray = Color(0xFF666666);

// El contenedor del selector ahora usa el mismo color que el fondo de
// la página (antes tenía #FAFAFA propio) — queda "invisible", solo se
// ven flotando los 3 tabs.
const _kSegmentBg = _kBg;
const _kSegmentInactiveBg = Color(0xFFF0F0F0);
const _kSegmentInactiveText = Color(0xFF050505);
const _kHoyActiveBg = Color(0xFFA07424);

const _kChipActiveBg = Color(0xFFFBF0DD);
const _kChipActiveText = Color(0xFF693902);

const _kTaskIconBg = Color(0xFFFDEED3);
const _kTaskAmber = Color(0xFF96650C);

enum _RangoTab { hoy, semana, calendario }

enum _FiltroChip { tareas, comunicados, reuniones }

class PendientesPage extends StatefulWidget {
  const PendientesPage({super.key});

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
            // ── Header: fondo blanco, volver + título + subtítulo ──
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // El nodo "‹" en Figma es texto, no un ícono — y el
                  // ícono de calendario que estaba junto a él antes
                  // está vacío en el propio archivo (0 hijos), no se copia.
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 6, right: 7),
                      child: Text('‹',
                          style: TextStyle(fontSize: 20, color: _kBack)),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pendientes',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: _kTextDark,
                          ),
                        ),
                        // TODO: reemplazar por alumno/fecha reales una vez
                        // que se defina la conexión a datos de esta pantalla.
                        const Text(
                          'Sofía Arias · lunes 22 de junio',
                          style: TextStyle(fontSize: 12, color: _kGray),
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
                    ),
                    const SizedBox(height: 8),

                    // ── Chips de filtro ──────────────────────────
                    Row(
                      children: [
                        _FiltroChipWidget(
                          label: 'Tareas 2',
                          width: 71,
                          active: _filtro == _FiltroChip.tareas,
                          onTap: () =>
                              setState(() => _filtro = _FiltroChip.tareas),
                        ),
                        const SizedBox(width: 6),
                        _FiltroChipWidget(
                          label: 'Comunicados  1',
                          width: 108,
                          active: _filtro == _FiltroChip.comunicados,
                          onTap: () =>
                              setState(() => _filtro = _FiltroChip.comunicados),
                        ),
                        const SizedBox(width: 6),
                        _FiltroChipWidget(
                          label: 'Reuniones 2',
                          width: 89,
                          active: _filtro == _FiltroChip.reuniones,
                          onTap: () =>
                              setState(() => _filtro = _FiltroChip.reuniones),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Lista de tarjetas (estado Hoy + Tareas, único
                    // diseñado en Figma por ahora) ──────────────
                    if (_tab == _RangoTab.hoy &&
                        _filtro == _FiltroChip.tareas) ...[
                      const _TaskCard(
                        title: 'Colorear mariposa',
                        subtitle: 'Vence hoy · Sección Girasoles',
                      ),
                      const SizedBox(height: 8),
                      const _TaskCard(
                        title: 'Traer material para manualidad',
                        subtitle: 'Vence hoy 5:00 pm',
                      ),
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
class _RangoSelector extends StatelessWidget {
  final _RangoTab selected;
  final ValueChanged<_RangoTab> onChanged;

  const _RangoSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _kSegmentBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _RangoTabItem(
            label: 'Hoy',
            svg: _kSvgCalendarStats,
            // Extremo izquierdo del selector: la esquina exterior
            // hereda el radio del contenedor (20), la interior es 5.
            radius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              topRight: Radius.circular(5),
              bottomRight: Radius.circular(5),
            ),
            active: selected == _RangoTab.hoy,
            onTap: () => onChanged(_RangoTab.hoy),
          ),
          const SizedBox(width: 3),
          _RangoTabItem(
            label: 'Semana',
            svg: _kSvgSemana,
            radius: BorderRadius.circular(5),
            active: selected == _RangoTab.semana,
            onTap: () => onChanged(_RangoTab.semana),
          ),
          const SizedBox(width: 3),
          _RangoTabItem(
            label: 'Calendario',
            svg: _kSvgCalendario,
            // Extremo derecho: exterior 20, interior 5.
            radius: const BorderRadius.only(
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              topLeft: Radius.circular(5),
              bottomLeft: Radius.circular(5),
            ),
            active: selected == _RangoTab.calendario,
            onTap: () => onChanged(_RangoTab.calendario),
          ),
        ],
      ),
    );
  }
}

class _RangoTabItem extends StatelessWidget {
  final String label;
  final String svg;
  final BorderRadius radius;
  final bool active;
  final VoidCallback onTap;

  const _RangoTabItem({
    required this.label,
    required this.svg,
    required this.radius,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : _kSegmentInactiveText;
    return Expanded(
      child: GestureDetector(
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
              SvgPicture.string(
                svg,
                width: 14,
                height: 14,
                colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chip de filtro (Tareas / Comunicados / Reuniones) ───────
class _FiltroChipWidget extends StatelessWidget {
  final String label;
  final double width;
  final bool active;
  final VoidCallback onTap;

  const _FiltroChipWidget({
    required this.label,
    required this.width,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 30,
        decoration: BoxDecoration(
          color: active ? _kChipActiveBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: active ? _kChipActiveText : _kGray,
          ),
        ),
      ),
    );
  }
}

// ── Tarjeta de tarea pendiente ───────────────────────────────
class _TaskCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TaskCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: _kTaskIconBg,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.string(
              _kSvgChecklist,
              width: 14,
              height: 14,
              colorFilter: const ColorFilter.mode(_kTaskAmber, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 12),
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
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: _kTaskAmber),
                ),
              ],
            ),
          ),
          const Text('›',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: _kChevron)),
        ],
      ),
    );
  }
}
