import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/push_notifications_service.dart';
import '../../../core/services/manufacturer_settings_service.dart';
import '../../auth/data/models/user_model.dart';

const _kDoneKey = 'notifications_onboarded_v1';
const _kAccent = Color(0xFF6C63FF);

/// Muestra el onboarding una sola vez por instalación.
Future<void> maybeShowNotificationOnboarding(
  BuildContext context,
  UserModel user,
) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kDoneKey) == true) return;
  if (!context.mounted) return;

  await Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black54,
      pageBuilder: (_, __, ___) => NotificationOnboardingPage(user: user),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
    ),
  );
}

class NotificationOnboardingPage extends StatefulWidget {
  final UserModel user;
  const NotificationOnboardingPage({super.key, required this.user});

  @override
  State<NotificationOnboardingPage> createState() =>
      _NotificationOnboardingPageState();
}

class _NotificationOnboardingPageState
    extends State<NotificationOnboardingPage> {
  bool _loading = false;
  // false = paso 1 (beneficios), true = paso 2 (fabricante)
  bool _showManufacturerStep = false;
  BrandInstructions? _brandInstructions;

  bool get _isTeacher =>
      widget.user.hasRole('teacher') ||
      widget.user.hasRole('school_admin') ||
      widget.user.hasRole('director');

  String get _firstName => widget.user.firstName;

  List<_Benefit> get _benefits {
    if (_isTeacher) {
      return [
        _Benefit('📢', 'Avisos de dirección',
            'Recibe comunicados importantes al instante, sin tener que revisar la app.'),
        _Benefit('✅', 'Confirmaciones',
            'Sabe al momento que la asistencia fue guardada correctamente.'),
        _Benefit('🔔', 'Novedades del colegio',
            'Mantente al día con lo que pasa sin perderte nada.'),
      ];
    }
    final hijoNombre = widget.user.children.isNotEmpty
        ? widget.user.children.first.firstName
        : 'tu hijo';
    return [
      _Benefit('📋', 'Asistencia al instante',
          'Sabe si $hijoNombre llegó ✅, llegó tarde ⏰ o está ausente ❌ — sin abrir la app.'),
      _Benefit('📸', 'Fotos del salón',
          'Mira las actividades y momentos del aula en tiempo real.'),
      _Benefit('📢', 'Comunicados del colegio',
          'Avisos importantes de dirección sin que se te pase ninguno.'),
    ];
  }

  Future<void> _onActivate() async {
    setState(() => _loading = true);

    // Paso 1a: permiso de notificaciones
    await PushNotificationsService.instance.requestPermission();

    // Paso 1b: exclusión de batería en Android
    if (Platform.isAndroid) {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }

      // Paso 2: configuración adicional según fabricante
      final needsExtra =
          await ManufacturerSettingsService.instance.needsExtraStep();
      if (needsExtra && mounted) {
        final instructions =
            await ManufacturerSettingsService.instance.getInstructions();
        await ManufacturerSettingsService.instance.recordReminderShown();
        setState(() {
          _loading = false;
          _showManufacturerStep = true;
          _brandInstructions = instructions;
        });
        return;
      }
    }

    await _markOnboardingDone();
  }

  Future<void> _onOpenManufacturerSettings() async {
    await ManufacturerSettingsService.instance.openAutostart();
    await ManufacturerSettingsService.instance.markAutostartDone();
    await _markOnboardingDone();
  }

  // Pospone el paso 2 — el recordatorio periódico lo retomará
  Future<void> _onSkipManufacturerStep() async => _markOnboardingDone();

  Future<void> _onSkip() async => _markOnboardingDone();

  Future<void> _markOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDoneKey, true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _showManufacturerStep
              ? _ManufacturerStep(
                  key: const ValueKey('step2'),
                  instructions: _brandInstructions!,
                  onOpen: _onOpenManufacturerSettings,
                  onSkip: _onSkipManufacturerStep,
                )
              : _BenefitsStep(
                  key: const ValueKey('step1'),
                  firstName: _firstName,
                  isTeacher: _isTeacher,
                  benefits: _benefits,
                  loading: _loading,
                  onActivate: _onActivate,
                  onSkip: _onSkip,
                ),
        ),
      ),
    );
  }
}

// ── Paso 1: beneficios + activar ─────────────────────────────
class _BenefitsStep extends StatelessWidget {
  final String firstName;
  final bool isTeacher;
  final List<_Benefit> benefits;
  final bool loading;
  final VoidCallback onActivate;
  final VoidCallback onSkip;

  const _BenefitsStep({
    super.key,
    required this.firstName,
    required this.isTeacher,
    required this.benefits,
    required this.loading,
    required this.onActivate,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final headline =
        isTeacher ? '¡Hola, $firstName!' : '¡Mantente cerca, $firstName!';
    final subtitle = isTeacher
        ? 'Activa las notificaciones para recibir avisos del colegio al instante.'
        : 'Activa las notificaciones y entérate de todo lo que pasa con tu hijo — en tiempo real.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Text('🔔', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            headline,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: benefits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, i) => _BenefitCard(benefits[i]),
            ),
          ),
          if (Platform.isAndroid) ...[
            const SizedBox(height: 16),
            _InfoBox(
              emoji: '⚡',
              text:
                  'También te pediremos que permitas que Kolexa funcione sin restricciones de batería, para que las notificaciones lleguen siempre.',
            ),
          ],
          const SizedBox(height: 24),
          _PrimaryButton(
            label: 'Activar notificaciones',
            loading: loading,
            onPressed: onActivate,
          ),
          const SizedBox(height: 12),
          _SkipButton(onPressed: loading ? null : onSkip),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Paso 2: configuración específica de fabricante ───────────
class _ManufacturerStep extends StatelessWidget {
  final BrandInstructions instructions;
  final VoidCallback onOpen;
  final VoidCallback onSkip;

  const _ManufacturerStep({
    super.key,
    required this.instructions,
    required this.onOpen,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Indicador de progreso
          Row(
            children: [
              _StepDot(active: false),
              const SizedBox(width: 6),
              _StepDot(active: true),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(instructions.emoji,
                  style: const TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Un paso más en ${instructions.brand}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${instructions.brand} restringe las apps en segundo plano. Para que Kolexa siempre te llegue, activa el inicio automático:',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // Mockup visual de lo que verá el usuario
          _AutostartMockup(brand: instructions.brand),
          const SizedBox(height: 20),
          // Pasos numerados
          ...instructions.steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _kAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: instructions.settingsLabel,
            loading: false,
            onPressed: onOpen,
          ),
          const SizedBox(height: 12),
          _SkipButton(
            label: 'Omitir este paso',
            onPressed: onSkip,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Widgets compartidos ──────────────────────────────────────
class _BenefitCard extends StatelessWidget {
  final _Benefit benefit;
  const _BenefitCard(this.benefit);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F4FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child:
                Text(benefit.emoji, style: const TextStyle(fontSize: 22)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                benefit.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                benefit.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String emoji;
  final String text;
  const _InfoBox({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F4FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  const _PrimaryButton(
      {required this.label,
      required this.loading,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const _SkipButton(
      {this.label = 'Ahora no', this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        child: Text(label,
            style: TextStyle(fontSize: 14, color: Colors.grey[500])),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool active;
  const _StepDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? _kAccent : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ── Mockup visual de la pantalla de autostart ────────────────
// Muestra al usuario cómo se verá la pantalla antes de abrirla.
class _AutostartMockup extends StatelessWidget {
  final String brand;
  const _AutostartMockup({required this.brand});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de título simulada
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.arrow_back, size: 16, color: Colors.black54),
                const SizedBox(width: 8),
                Text(
                  brand == 'Xiaomi'
                      ? 'Inicio automático'
                      : brand == 'Huawei'
                          ? 'Inicio de aplicaciones'
                          : 'Aplicaciones en segundo plano',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Filas de apps simuladas
          _MockAppRow(name: 'WhatsApp', enabled: true, isKolexa: false),
          _MockAppRow(name: 'Instagram', enabled: false, isKolexa: false),
          _MockAppRow(name: 'Kolexa', enabled: false, isKolexa: true),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _MockAppRow extends StatelessWidget {
  final String name;
  final bool enabled;
  final bool isKolexa;
  const _MockAppRow(
      {required this.name, required this.enabled, required this.isKolexa});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: isKolexa
          ? BoxDecoration(
              color: _kAccent.withOpacity(0.06),
              border: Border(
                left: BorderSide(color: _kAccent, width: 3),
              ),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isKolexa
                  ? _kAccent.withOpacity(0.15)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                isKolexa ? 'K' : name[0],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isKolexa ? _kAccent : Colors.grey.shade600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isKolexa ? FontWeight.w600 : FontWeight.w400,
                color:
                    isKolexa ? const Color(0xFF1A1A2E) : Colors.grey.shade700,
              ),
            ),
          ),
          if (isKolexa) ...[
            const SizedBox(width: 6),
            Text(
              'Activar aquí',
              style: TextStyle(
                fontSize: 11,
                color: _kAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, size: 12, color: _kAccent),
          ],
          const SizedBox(width: 8),
          // Toggle simulado
          Container(
            width: 36,
            height: 20,
            decoration: BoxDecoration(
              color: enabled ? Colors.green : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Align(
              alignment:
                  enabled ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(2),
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recordatorio periódico ────────────────────────────────────
/// Llama desde el home DESPUÉS de maybeShowNotificationOnboarding.
/// Muestra un bottom sheet si el usuario pospuso el paso 2.
Future<void> maybeShowAutostartReminder(BuildContext context) async {
  final service = ManufacturerSettingsService.instance;
  if (!await service.shouldShowReminder()) return;
  if (!context.mounted) return;

  await service.recordReminderShown();
  final instructions = await service.getInstructions();
  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AutostartReminderSheet(
      instructions: instructions,
      onOpen: () async {
        Navigator.pop(context);
        await service.openAutostart();
        await service.markAutostartDone();
      },
      onDismiss: () => Navigator.pop(context),
    ),
  );
}

class _AutostartReminderSheet extends StatelessWidget {
  final BrandInstructions instructions;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const _AutostartReminderSheet({
    required this.instructions,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                    child: Text('🔔', style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notificaciones en riesgo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${instructions.brand} puede bloquear notificaciones de Kolexa en segundo plano.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AutostartMockup(brand: instructions.brand),
          const SizedBox(height: 16),
          Text(
            'Solo toma 10 segundos: abre la pantalla y activa el interruptor de Kolexa.',
            style:
                TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onOpen,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                instructions.settingsLabel,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: onDismiss,
              child: Text('Después',
                  style:
                      TextStyle(fontSize: 14, color: Colors.grey[500])),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modelos internos ─────────────────────────────────────────
class _Benefit {
  final String emoji;
  final String title;
  final String description;
  const _Benefit(this.emoji, this.title, this.description);
}
