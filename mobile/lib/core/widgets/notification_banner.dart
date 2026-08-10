// ============================================================
// notification_banner.dart — Banner de notificaciones desactivadas
// ============================================================
// Muestra un aviso persistente (estilo WhatsApp) cuando el usuario
// desactivó las notificaciones de Kolexa desde los Ajustes del sistema.
// Incluye un botón para abrir la configuración de notificaciones.
//
// Uso: colocar en el home (padre, docente, director). Se auto-oculta
// cuando las notificaciones vuelven a estar habilitadas.
// ============================================================

import 'package:flutter/material.dart';
import '../services/push_notifications_service.dart';

const _kAccent = Color(0xFF5B4A9E);
const _kAccentLt = Color(0xFFEDE8FA);
const _kTextDark = Color(0xFF1E1B29);

/// Widget que verifica el estado de las notificaciones y muestra un
/// banner si están desactivadas. Se re-evalúa al volver a primer plano.
class NotificationBanner extends StatefulWidget {
  const NotificationBanner({super.key});

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner>
    with WidgetsBindingObserver {
  bool _notificationsDisabled = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de Ajustes (donde el usuario pudo reactivar las
    // notificaciones), re-verificar el estado.
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  Future<void> _check() async {
    final enabled = await PushNotificationsService.instance
        .checkNotificationPermission();
    if (!mounted) return;
    setState(() {
      _notificationsDisabled = !enabled;
      _checking = false;
    });
  }

  Future<void> _openSettings() async {
    await PushNotificationsService.instance.openNotificationSettings();
    // Al volver, didChangeAppLifecycleState re-verificará el estado.
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || !_notificationsDisabled) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kAccentLt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_outlined,
              color: _kAccent, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notificaciones desactivadas',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Actívalas para no perderte la asistencia y las fotos de tu hijo.',
                  style: TextStyle(fontSize: 12, color: _kTextDark),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _openSettings,
            style: TextButton.styleFrom(
              foregroundColor: _kAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Activar',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
