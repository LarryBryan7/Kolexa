import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../core/router/app_router.dart';
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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.role});

  // Rol elegido en role_selection_page ('parent' | 'teacher' | 'director' |
  // 'student' | null). Para 'parent' esta pantalla muestra SOLO el código de
  // invitación + botón de Google — el usuario/contraseña no sirve para
  // padres (su passwordHash es un valor aleatorio que nadie conoce, ver
  // auth.service.ts).
  final String? role;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Credenciales por defecto para el piloto (cuenta demo de Sofía).
  // El usuario puede editarlas antes de iniciar sesión.
  final _emailController      = TextEditingController(text: 'sofia.mendez@gmail.com');
  final _passwordController   = TextEditingController(text: '123456');
  final _invitationController = TextEditingController();
  final _formKey               = GlobalKey<FormState>();
  bool _obscurePassword       = true;

  bool get _isParent => widget.role == 'parent';

  // Padre que ya vinculó Google con éxito antes en este dispositivo — se le
  // muestra un saludo personalizado (nombre + avatar) en vez del logo K,
  // y ya no ve el campo de código (ver más abajo).
  bool get _isReturningParent =>
      _isParent && OnboardingService.instance.hasLinkedGoogleParentBefore;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _invitationController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    if (_formKey.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
      LoginEvent(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
        firebaseToken: PushNotificationsService.instance.fcmToken,
      ),
    );
  }

  // Mensajes de UI para los códigos de error estructurados que devuelve
  // el backend para el flujo de invitación de padre. Comparación por
  // IGUALDAD EXACTA — nunca .contains(), para no repetir el bug de
  // Classroom donde Flutter confundía TOKEN_EXPIRED con una sesión KOLEXA
  // vencida por hacer un match parcial de substring.
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
  // vinculado todavía — ver AuthService.loginWithGoogle). Para un padre
  // que YA está vinculado, el backend acepta el login sin código en
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
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kTextGray, fontSize: 14),
      prefixIcon: Icon(icon, color: _kIconGray, size: 17),
      prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 17),
      suffixIcon: suffixIcon,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
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
          if (state is AuthAuthenticated) context.go(AppRouter.home);
          if (state is AuthError) {
            // state.message llega tal cual del backend (ver AuthBloc._onGoogleLogin
            // y AuthError). Para los códigos de invitación se mapea por
            // IGUALDAD EXACTA a un mensaje de UI — cualquier otro mensaje
            // (ej. "Credenciales incorrectas") se muestra tal cual.
            _showError(_invitationErrorMessages[state.message] ?? state.message);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ── Logo K, o avatar si es un padre que ya vinculó ──
                    const SizedBox(height: 58),
                    if (_isReturningParent)
                      Center(
                        child: _LoginAvatar(
                          avatarUrl: OnboardingService.instance.lastParentAvatar,
                          firstName: OnboardingService.instance.lastParentFirstName ?? '',
                          lastName: OnboardingService.instance.lastParentLastName ?? '',
                        ),
                      )
                    else
                      const Center(
                        child: KolexaLogo(height: 53, color: _kPrimary),
                      ),

                    // ── Título ────────────────────────────────
                    const SizedBox(height: 19),
                    Text(
                      _isReturningParent
                          ? 'Hola ${OnboardingService.instance.lastParentFirstName ?? ''} 👋'
                          : (_isParent ? 'Ingresa a Kolexa' : 'Iniciar sesión'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _kTextDark,
                      ),
                    ),

                    // ── Subtítulo ─────────────────────────────
                    const SizedBox(height: 5),
                    Text(
                      _isReturningParent
                          ? 'Continúa viendo las novedades de tu hijo en un solo lugar'
                          : (_isParent
                              ? 'Brindanos el código que te generó tu colegio y continúa con Google'
                              : 'Ingresa tus datos para continuar'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, color: _kTextGray),
                    ),

                    if (!_isParent) ...[
                    // ── Campo Email ───────────────────────────
                    const SizedBox(height: 30),
                    SizedBox(
                      height: 52,
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        enabled: !isLoading,
                        style: const TextStyle(color: _kTextDark, fontSize: 14),
                        decoration: _fieldDecoration(
                          hint: 'Correo electrónico',
                          icon: Icons.mail_outline,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa tu correo electrónico';
                          }
                          final parts = v.trim().split('@');
                          if (parts.length != 2 || !parts[1].contains('.')) {
                            return 'El email no tiene un formato válido';
                          }
                          return null;
                        },
                      ),
                    ),

                    // ── Campo Contraseña ──────────────────────
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        enabled: !isLoading,
                        style: const TextStyle(color: _kTextDark, fontSize: 14),
                        onFieldSubmitted: (_) => _onLoginPressed(),
                        decoration: _fieldDecoration(
                          hint: 'Contraseña',
                          icon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: _kIconGray,
                              size: 19,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                          if (v.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),
                    ),

                    // ── ¿Olvidaste tu contraseña? ─────────────
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoading ? null : () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(
                            color: _kPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),

                    // ── Botón Iniciar sesión ──────────────────
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          // Color del botón cuando está deshabilitado (durante la carga)
                          disabledBackgroundColor: const Color(0xFF6F60AA),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: isLoading ? null : _onLoginPressed,
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Iniciar sesión',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),

                    // ── Separador "o" ─────────────────────────
                    const SizedBox(height: 18),
                    const Row(
                      children: [
                        Expanded(child: Divider(color: _kBorder)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'o',
                            style: TextStyle(color: _kTextGray, fontSize: 12.5),
                          ),
                        ),
                        Expanded(child: Divider(color: _kBorder)),
                      ],
                    ),
                    ], // fin if (!_isParent)

                    // ── Código de invitación (solo la primera vez) ──
                    // Una vez que este dispositivo vinculó Google con éxito
                    // al menos una vez, el backend ya no exige el código en
                    // logins futuros (returning-parent fast path) — mostrar
                    // el campo de nuevo no tiene sentido, ni después de un
                    // logout explícito.
                    if (!OnboardingService.instance.hasLinkedGoogleParentBefore) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: TextFormField(
                        controller: _invitationController,
                        textInputAction: TextInputAction.done,
                        enabled: !isLoading,
                        style: const TextStyle(color: _kTextDark, fontSize: 14),
                        decoration: _fieldDecoration(
                          hint: 'Código de invitación',
                          icon: Icons.key_outlined,
                        ),
                      ),
                    ),
                    ],

                    // ── Continuar con Google ──────────────────
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _kTextDark,
                          side: const BorderSide(color: _kBorder),
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
                                  color: _kPrimary,
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
                                      color: _kTextDark,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    // ── Crear cuenta ──────────────────────────
                    // No tiene sentido para un padre que ya tiene cuenta y
                    // ya está vinculado en este dispositivo.
                    if (!_isReturningParent) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¿No tienes cuenta? ',
                          style: TextStyle(color: _kTextGray, fontSize: 12.5),
                        ),
                        GestureDetector(
                          onTap: () => context.go(AppRouter.roleSelection),
                          child: const Text(
                            'Crear cuenta gratis',
                            style: TextStyle(
                              color: _kPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ],
                  ],
                ),
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
