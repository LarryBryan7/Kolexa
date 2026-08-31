import 'package:flutter/material.dart';

// Tono "presionado" de una card: en vez del gris plano por defecto de
// Material (que no combina con cards de color propio, ej. el ámbar de
// "Urgente para hoy"), desatura y oscurece levemente el color base de
// CADA card para usarlo como splash/highlight — así el estado
// seleccionado se ve como una versión grisácea del color original, no un
// gris genérico sin relación con la tarjeta.
Color pressedTint(Color base) {
  final hsl = HSLColor.fromColor(base);
  return hsl
      .withSaturation((hsl.saturation * 0.65).clamp(0.0, 1.0))
      .withLightness((hsl.lightness * 0.85).clamp(0.0, 1.0))
      .toColor()
      .withValues(alpha: 0.35);
}

// Feedback de "presionado" hecho a mano (sin InkWell): el fade interno
// de Material no se puede afinar (entra y sale con el mismo timing
// fijo), y el toque se sentía poco "limpio". Acá se controla el propio
// estado con TapDown/TapUp/TapCancel: entra instantáneo y sale más
// lento (350ms), para que el tinte se sienta un poco más sostenido en
// vez de desaparecer de golpe al soltar.
class PressTint extends StatefulWidget {
  final Widget child;
  final Color tintColor;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  const PressTint({
    super.key,
    required this.child,
    required this.tintColor,
    required this.borderRadius,
    this.onTap,
  });

  @override
  State<PressTint> createState() => _PressTintState();
}

class _PressTintState extends State<PressTint> {
  bool _pressed = false;
  DateTime? _pressedAt;

  // Toque rápido/leve: onTapDown y onTapUp pueden llegar dentro del MISMO
  // frame — Flutter solo pinta el último estado antes de construir ese
  // frame, así que el tinte nunca llega a verse aunque el toque se haya
  // registrado bien. Se garantiza un mínimo de tiempo visible antes de
  // dejar apagar el tinte, sin tocar la entrada instantánea.
  static const _minVisible = Duration(milliseconds: 80);

  void _setPressed(bool value) {
    if (value) {
      _pressedAt = DateTime.now();
      if (!_pressed) setState(() => _pressed = true);
      return;
    }
    final pressedAt = _pressedAt;
    final elapsed = pressedAt == null ? _minVisible : DateTime.now().difference(pressedAt);
    if (elapsed >= _minVisible) {
      if (_pressed) setState(() => _pressed = false);
    } else {
      Future.delayed(_minVisible - elapsed, () {
        // Solo apaga si sigue siendo el mismo toque que originó este
        // delay — evita apagar de golpe un toque nuevo que arrancó
        // mientras se esperaba el mínimo del anterior (doble-tap rápido).
        if (mounted && _pressed && _pressedAt == pressedAt) {
          setState(() => _pressed = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Por defecto GestureDetector solo responde donde hay contenido
      // "opaco" debajo (deferToChild) — deja zonas muertas en paddings
      // y espacios vacíos. InkWell, en cambio, cubre TODA el área del
      // widget; con `opaque` igualamos ese comportamiento.
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      // Un solo AnimatedContainer envolviendo el contenido (nada de
      // Stack): así el ancho/alto siguen viniendo del padre y del
      // propio contenido exactamente igual que un Container normal —
      // un Stack (con StackFit.loose o .expand) rompía el centrado o
      // el alto automático de la tarjeta.
      child: AnimatedContainer(
        // Al presionar: cambio INSTANTÁNEO (sin transición) — el
        // usuario tiene que ver de inmediato que está seleccionando
        // algo, sin esperar ningún fade. Se mantiene fijo mientras
        // sigue tocando. Recién al soltar se anima (350ms) la salida.
        duration: Duration(milliseconds: _pressed ? 0 : 350),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _pressed ? widget.tintColor : widget.tintColor.withValues(alpha: 0),
          borderRadius: widget.borderRadius,
        ),
        child: widget.child,
      ),
    );
  }
}
