import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManufacturerSettingsService {
  ManufacturerSettingsService._();
  static final ManufacturerSettingsService instance =
      ManufacturerSettingsService._();

  static const _channel = MethodChannel('kolexa/manufacturer_settings');

  String? _manufacturer;

  Future<String> getManufacturer() async {
    if (!Platform.isAndroid) return 'apple';
    _manufacturer ??=
        await _channel.invokeMethod<String>('getManufacturer') ?? 'unknown';
    return _manufacturer!;
  }

  // Fabricantes que tienen capas de restricción adicionales más allá
  // del optimizador de batería estándar de Android.
  Future<bool> needsExtraStep() async {
    if (!Platform.isAndroid) return false;
    final m = await getManufacturer();
    return m.contains('xiaomi') ||
        m.contains('redmi') ||
        m.contains('huawei') ||
        m.contains('honor') ||
        m.contains('samsung') ||
        m.contains('oppo') ||
        m.contains('realme') ||
        m.contains('oneplus') ||
        m.contains('vivo');
  }

  Future<String> getBrandName() async {
    final m = await getManufacturer();
    if (m.contains('xiaomi') || m.contains('redmi')) return 'Xiaomi';
    if (m.contains('huawei') || m.contains('honor')) return 'Huawei';
    if (m.contains('samsung')) return 'Samsung';
    if (m.contains('oppo')) return 'Oppo';
    if (m.contains('realme')) return 'Realme';
    if (m.contains('oneplus')) return 'OnePlus';
    if (m.contains('vivo')) return 'Vivo';
    return 'tu teléfono';
  }

  Future<BrandInstructions> getInstructions() async {
    final m = await getManufacturer();

    if (m.contains('xiaomi') || m.contains('redmi')) {
      return BrandInstructions(
        brand: 'Xiaomi',
        emoji: '📱',
        steps: [
          'Se abrirá "Administrar inicio automático"',
          'Busca Kolexa en la lista',
          'Activa el interruptor de Kolexa',
        ],
        settingsLabel: 'Abrir Inicio Automático',
      );
    }

    if (m.contains('huawei') || m.contains('honor')) {
      return BrandInstructions(
        brand: 'Huawei',
        emoji: '📱',
        steps: [
          'Se abrirá "Inicio de aplicaciones"',
          'Busca Kolexa en la lista',
          'Desactiva "Gestión automática" y activa las tres opciones manualmente',
        ],
        settingsLabel: 'Abrir Inicio de aplicaciones',
      );
    }

    if (m.contains('samsung')) {
      return BrandInstructions(
        brand: 'Samsung',
        emoji: '📱',
        steps: [
          'Se abrirá el Cuidado del dispositivo',
          'Ve a Batería → Límites de uso en segundo plano',
          'Verifica que Kolexa no esté en la lista de apps en espera',
        ],
        settingsLabel: 'Abrir Batería',
      );
    }

    return BrandInstructions(
      brand: 'tu teléfono',
      emoji: '📱',
      steps: [
        'Se abrirá la configuración de batería',
        'Busca Kolexa y permite que funcione sin restricciones',
      ],
      settingsLabel: 'Abrir configuración',
    );
  }

  // Abre la pantalla de autostart específica del fabricante.
  Future<bool> openAutostart() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('openAutostart');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // Abre una URL externa (ej. una tarea de Google Classroom) forzando
  // una tarea de Android independiente (FLAG_ACTIVITY_NEW_TASK). Sin
  // esto, url_launcher abre la app externa DENTRO de la misma tarea de
  // Kolexa — funciona, pero en "apps recientes" aparece como una sola
  // tarjeta que cambia de ícono en vez de dos apps independientes.
  Future<bool> openExternalUrl(String url) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'openExternalUrl',
        {'url': url},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Tracking de recordatorios ────────────────────────────

  static const _kDone = 'autostart_done';
  static const _kCount = 'autostart_remind_count';
  static const _kLastMs = 'autostart_last_remind_ms';
  static const _kMaxReminders = 4;
  static const _kIntervalDays = 3;

  Future<bool> isAutostartDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDone) ?? false;
  }

  Future<void> markAutostartDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDone, true);
  }

  // Retorna true si hay que mostrar el recordatorio ahora.
  Future<bool> shouldShowReminder() async {
    if (!Platform.isAndroid) return false;
    if (!await needsExtraStep()) return false;
    if (await isAutostartDone()) return false;

    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_kCount) ?? 0;
    if (count >= _kMaxReminders) return false;

    final lastMs = prefs.getInt(_kLastMs) ?? 0;
    if (lastMs == 0) return true; // nunca se mostró

    final daysSinceLast =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastMs)).inDays;
    return daysSinceLast >= _kIntervalDays;
  }

  Future<void> recordReminderShown() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_kCount) ?? 0;
    await prefs.setInt(_kCount, count + 1);
    await prefs.setInt(_kLastMs, DateTime.now().millisecondsSinceEpoch);
  }
}

class BrandInstructions {
  final String brand;
  final String emoji;
  final List<String> steps;
  final String settingsLabel;

  const BrandInstructions({
    required this.brand,
    required this.emoji,
    required this.steps,
    required this.settingsLabel,
  });
}
