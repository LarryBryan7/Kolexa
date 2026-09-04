import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../core/widgets/kolexa_logo.dart';
import '../../../core/services/push_notifications_service.dart';
import '../../../core/services/google_sign_in_service.dart';
import '../../../core/services/onboarding_service.dart';

// ── Paleta del frame "04 — Login v2 (paleta ajustada)" ───
const _kBg       = Color(0xFFF7F6F3);
const _kPrimary  = Color(0xFF5B4A9E);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);
const _kIconGray = Color(0xFF737378);
const _kBorder   = Color(0xFFE5E5EA);

// Login único para todos los roles (padre, docente, director): Google +
// código de invitación. El rol se valida en el backend por el email
// (ver AuthService.loginWithGoogle) — no hay selección de rol ni
// usuario/contraseña en la app.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _invitationController = TextEditingController();

  // Cuenta que ya vinculó Google con éxito antes en este dispositivo — se le
  // muestra un saludo personalizado (nombre + avatar) en vez del logo K,
  // y ya no ve el campo de código (ver más abajo).
  bool get _isReturningUser => OnboardingService.instance.hasLinkedGoogleBefore;

  @override
  void dispose() {
    _invitationController.dispose();
    super.dispose();
  }

  // Mensajes de UI para los códigos de error estructurados que devuelve
  // el backend para el flujo de invitación. Comparación por IGUALDAD
  // EXACTA — nunca .contains(), para no repetir el bug de Classroom donde
  // Flutter confundía TOKEN_EXPIRED con una sesión KOLEXA vencida por
  // hacer un match parcial de substring.
  static const _invitationErrorMessages = <String, String>{
    'INVITATION_REQUIRED': 'Ingresa el código que te dio el colegio.',
    'INVITATION_NOT_FOUND': 'El código no es válido.',
    'INVITATION_EXPIRED': 'Este código ha vencido. Solicita una nueva invitación al colegio.',
    'INVITATION_ALREADY_USED': 'Este código ya fue utilizado.',
    'INVITATION_EMAIL_MISMATCH': 'Usa la cuenta de Google registrada por el colegio.',
    'INVITATION_INVALID_ROLE': 'No se pudo procesar la invitación. Contacta al colegio.',
  };

  // ── Continuar con Google ─────────────────────────────────
  // El código de invitación es obligatorio SOLO la primera vez (backend
  // rechaza con INVITATION_REQUIRED si el googleSub es nuevo o no está
  // vinculado todavía — ver AuthService.loginWithGoogle). Para una cuenta
  // que YA está vinculada, el backend acepta el login sin código en
  // absoluto — por eso acá NO se bloquea localmente si el campo está
  // vacío; se manda tal cual y es el backend quien decide, mostrando
  // INVITATION_REQUIRED (mapeado más abajo) solo si de verdad hacía falta.
  Future<void> _onGoogleLoginPressed() async {
    FocusScope.of(context).unfocus();
    final invitationToken = _invitationController.text.trim();
    try {
      final idToken = await GoogleSignInService.instance.signIn();
      if (!mounted) return;
      context.read<AuthBloc>().add(
        GoogleLoginEvent(
          idToken: idToken,
          invitationToken: invitationToken,
          firebaseToken: PushNotificationsService.instance.fcmToken,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Si el usuario canceló, no mostramos error (es una acción esperada).
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.toLowerCase().contains('cancelado')) return;
      _showError(_invitationErrorMessages[msg] ?? msg);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ));
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: _kTextGray.withValues(alpha: 0.85),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, color: _kIconGray, size: 17),
      prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 17),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: _kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: _kPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          // La navegación a home/hijosEncontrados la decide el redirect
          // central de AppRouter (se re-evalúa solo con refreshListenable
          // en cuanto AuthBloc emite AuthAuthenticated) — un context.go()
          // manual acá competía en carrera contra ese redirect y siempre
          // perdía, así que "encontramos a tus hijos" nunca se veía.
          if (state is AuthError) {
            // state.message llega tal cual del backend (ver AuthBloc._onGoogleLogin
            // y AuthError). Para los códigos de invitación se mapea por
            // IGUALDAD EXACTA a un mensaje de UI — cualquier otro mensaje
            // se muestra tal cual.
            _showError(_invitationErrorMessages[state.message] ?? state.message);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  // ── Logo K, o avatar si ya vinculó antes ──
                  const SizedBox(height: 32),
                  if (_isReturningUser)
                    Center(
                      child: _LoginAvatar(
                        avatarUrl: OnboardingService.instance.lastLoginAvatar,
                        firstName: OnboardingService.instance.lastLoginFirstName ?? '',
                        lastName: OnboardingService.instance.lastLoginLastName ?? '',
                      ),
                    )
                  else
                    const Center(
                      // Wordmark completo "Kolexa" (no solo el isotipo K) —
                      // la "K" en color primario, "olexa" en gris, tal como
                      // en el frame "04 — Login Padre" de Figma.
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          KolexaLogo(height: 25, color: _kPrimary),
                          Text(
                            'olexa',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: _kTextGray,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Título ────────────────────────────────
                  // Figma: 149px entre el logo y el título en el estado de
                  // primera vez (frame "04 — Login Padre") — el estado de
                  // usuario que vuelve no está en ese frame, se mantiene un
                  // espaciado más compacto para ese caso.
                  SizedBox(height: _isReturningUser ? 19 : 149),
                  Text(
                    _isReturningUser
                        ? 'Hola ${OnboardingService.instance.lastLoginFirstName ?? ''} 👋'
                        : 'Bienvenido a Kolexa',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _isReturningUser ? _kTextDark : _kTextGray,
                    ),
                  ),

                  // ── Subtítulo ─────────────────────────────
                  const SizedBox(height: 12),
                  Text(
                    _isReturningUser
                        ? 'Continúa viendo las novedades de tu colegio en un solo lugar'
                        : 'Brindanos tu código por favor, y continúa con tu cuenta de Google',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: _kTextGray),
                  ),

                  // ── Código de invitación (solo la primera vez) ──
                  // Una vez que este dispositivo vinculó Google con éxito
                  // al menos una vez, el backend ya no exige el código en
                  // logins futuros (returning-user fast path) — mostrar
                  // el campo de nuevo no tiene sentido, ni después de un
                  // logout explícito.
                  if (!_isReturningUser) ...[
                    const SizedBox(height: 57),
                    SizedBox(
                      height: 52,
                      child: TextFormField(
                        controller: _invitationController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        enabled: !isLoading,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _kTextDark,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                        ),
                        decoration: _fieldDecoration(
                          hint: '777678',
                          icon: Icons.key_outlined,
                        ).copyWith(counterText: ''),
                      ),
                    ),
                  ],

                  // ── Continuar con Google ──────────────────
                  SizedBox(height: _isReturningUser ? 20 : 25),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        disabledBackgroundColor: const Color(0xFF6F60AA),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: isLoading ? null : _onGoogleLoginPressed,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SvgPicture.asset(
                                  'assets/icons/ic_google.svg',
                                  width: 18,
                                  height: 18,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Continuar con Google',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.white,
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
        },
      ),
    );
  }
}

// ── Avatar del saludo de retorno ─────────────────────────────
// Foto de Google si existe (User.avatar), si no, iniciales sobre fondo
// _kPrimary — mismo patrón que _AvatarCircle en home_v2_page.dart.
class _LoginAvatar extends StatelessWidget {
  const _LoginAvatar({
    required this.avatarUrl,
    required this.firstName,
    required this.lastName,
  });

  final String? avatarUrl;
  final String firstName;
  final String lastName;

  String get _initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    if (avatarUrl != null) {
      return ClipOval(
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
