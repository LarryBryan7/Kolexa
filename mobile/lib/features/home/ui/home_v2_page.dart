import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/push_notifications_service.dart';
import '../../../core/widgets/notification_banner.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../notifications/ui/notification_onboarding_page.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/api/api_client.dart';
import '../../classroom/data/models/gc_models.dart';
import '../../classroom/data/repository/classroom_repository.dart';
import 'novedades_detail_page.dart';
import 'esta_semana_page.dart';
import 'pendientes_page.dart';
import '../../../core/utils/lima_date.dart';
import 'home_docente_page.dart' show PerfilTab;

// ── Paleta extraída de Figma ──────────────────────────────
const _kBg = Color(0xFFF7F6F3);
const _kPrimary = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);
const _kChevron = Color(0xFF8E8E93);
const _kNavInact = Color(0xFF707070);
const _kSwitchSec = Color(0xFFB4AFC8);

// ── Datos de un hijo ──────────────────────────────────────
class _Child {
  final String studentId;
  final String initials;
  final String fullName;
  final String? section;
  final int? age;
  final String? avatarUrl;
  const _Child({
    required this.studentId,
    required this.initials,
    required this.fullName,
    this.section,
    this.age,
    this.avatarUrl,
  });
}

String _initials(String first, String last) {
  final f = first.isNotEmpty ? first[0].toUpperCase() : '';
  final l = last.isNotEmpty ? last[0].toUpperCase() : '';
  return '$f$l';
}

// ─────────────────────────────────────────────────────────
class HomeV2Page extends StatefulWidget {
  /// Nombre del alumno que llega al tocar una notificación de asistencia.
  /// Se usa para preseleccionar al hijo correcto en el switcher.
  final String? initialStudentName;
  const HomeV2Page({super.key, this.initialStudentName});

  @override
  State<HomeV2Page> createState() => _HomeV2PageState();
}

class _HomeV2PageState extends State<HomeV2Page> with WidgetsBindingObserver {
  int _selectedChild = 0;
  int _navIndex = 0;
  int _refreshKey = 0;
  bool _wentToClassroomBrowser = false;
  bool _waitingClassroomConfirm = false;
  bool _connectingClassroom = false;
  // Mejora D: guarda de reentrada para que pull-to-refresh, el resume por
  // notificación FCM o el post-frame inicial no lancen syncs duplicados.
  bool _refreshing = false;
  // El botón manual "Ya autoricé, verificar" solo aparece si el flujo
  // automático (didChangeAppLifecycleState) no detecta el regreso del
  // navegador dentro del tiempo de respaldo.
  bool _showManualVerify = false;
  Timer? _verifyTimeout;
  Future<bool>? _classroomStatusFuture;
  // Estado de conexión a Classroom conocido de forma síncrona (bool?).
  // Se actualiza cuando resuelve `_classroomStatusFuture` (isConnected) y se
  // usa para que el card "Esta semana" se muestre en estado de carga junto al
  // de "Novedades" desde el inicio, sin esperar a /parent/home.
  bool? _classroomConnected;
  // Estado de conexión recordado por alumno (persistido en SharedPreferences).
  // Permite saber de forma síncrona si un hijo está conectado a Classroom al
  // entrar al Home o al cambiar de hijo, sin esperar a isConnected ni a
  // /parent/home. Clave = studentId.
  final Map<String, bool> _knownConnected = {};
  // Datos combinados del home del padre (todaySummary + upcomingStatus) en
  // UNA sola petición. Ambos cards ("Novedades" y "Esta semana") comparten
  // este resultado, evitando que compitan por la única conexión del pooler
  // (connection_limit=1) y se serialicen (~1.9s por query).
  ParentHomeData? _parentHome;

  // Marca de tiempo del montaje del Home para medir cuánto tarda en
  // cargarse el primer /parent/home (instrumentación [FLOW]).
  late final int _homeStartMs;

  @override
  void initState() {
    super.initState();
    _homeStartMs = DateTime.now().millisecondsSinceEpoch;
    WidgetsBinding.instance.addObserver(this);
    // Cargamos (rápido, la instancia ya está cacheada por auth) el estado de
    // conexión recordado por alumno, para que el card "Esta semana" pueda
    // mostrarse en estado de carga junto al de "Novedades" desde el primer
    // frame en la segunda entrada (cuando ya no hace falta conectar Classroom).
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        for (final c in _buildChildren(authState)) {
          final v = p.getBool(_gcConnectedKey(c.studentId));
          if (v != null) {
            _knownConnected[c.studentId] = v;
          }
        }
        // Sembramos el estado de conexión del hijo actual de forma síncrona.
        final children = _buildChildren(authState);
        if (children.isNotEmpty) {
          final sid = children[_selectedChild.clamp(0, children.length - 1)].studentId;
          final known = _knownConnected[sid];
          // Mejora A: la card "Conectar Google Classroom" se muestra/oculta de
          // forma determinista desde el primer frame (sin depender de GET
          // /status): true si recordamos conectado, false en caso contrario.
          setState(() {
            if (known != null) _classroomConnected = known;
            _classroomStatusFuture = Future.value(known ?? false);
          });
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _onRefresh();
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        // Si venimos de una notificación de un alumno concreto,
        // preseleccionar a ese hijo en el switcher.
        final targetName = widget.initialStudentName;
        if (targetName != null && targetName.isNotEmpty) {
          final children = _buildChildren(authState);
          final idx = children.indexWhere((c) =>
              c.fullName.toLowerCase().contains(targetName.toLowerCase()));
          if (idx >= 0) {
            _selectedChild = idx;
            if (mounted) setState(() {});
          }
        }
        await maybeShowNotificationOnboarding(context, authState.user);
        await maybeShowAutostartReminder(context);
      }
    });
  }

  @override
  void dispose() {
    _verifyTimeout?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wentToClassroomBrowser) {
      setState(() => _wentToClassroomBrowser = false);
      // Volvimos del navegador de Google Classroom. Recién AHORA activamos el
      // estado de verificación/carga ("Estamos cargando tus tareas...") y
      // sincronizamos, porque el usuario ya aceptó (o no) los permisos.
      // No llamamos a _onRefresh en paralelo para que la card de conexión no
      // reaparezca brevemente con un estado de conexión desactualizado.
      _verifyClassroomConnection();
    }
  }

  void _switchChild(int index) {
    setState(() {
      _selectedChild = index;
      // Limpiar los datos del hijo anterior para no mostrar datos cruzados.
      _parentHome = null;
    });
    final authState = context.read<AuthBloc>().state;
    final children = _buildChildren(authState);
    if (children.isNotEmpty) {
      final studentId = children[index.clamp(0, children.length - 1)].studentId;
      // Mejora A: estado de conexión 100% síncrono (_knownConnected persistido),
      // sin GET /status. La reconciliación con el backend la hace
      // _loadParentHome vía upcomingStatus.connected.
      final known = _knownConnected[studentId] ?? false;
      setState(() {
        _classroomConnected = known;
        _classroomStatusFuture = Future.value(known);
      });
      _loadParentHome(studentId);
    }
  }

  String? _currentStudentId() {
    final authState = context.read<AuthBloc>().state;
    final children = _buildChildren(authState);
    if (children.isEmpty) return null;
    return children[_selectedChild.clamp(0, children.length - 1)].studentId;
  }

  String _gcConnectedKey(String studentId) => 'gc_connected_$studentId';

  /// Guarda el estado de conexión conocido para este alumno: en memoria para
  /// lectura síncrona inmediata y persistido en SharedPreferences para la
  /// próxima entrada.
  void _rememberConnected(String studentId, bool connected) {
    _knownConnected[studentId] = connected;
    SharedPreferences.getInstance().then((p) {
      p.setBool(_gcConnectedKey(studentId), connected);
    });
  }

  // force: true SOLO para el pull-to-refresh manual (el usuario deslizó
  // pidiendo datos frescos) — salta la caché de 15 min del sync con Google.
  // La carga automática (initState, resume de la app) deja force=false para
  // no pagar el sync completo (~26-30s) en cada apertura normal.
  Future<void> _onRefresh({bool showErrors = false, bool force = false}) async {
    // Mejora D: guarda de reentrada. Si ya hay un refresh en vuelo (pull-to-
    // refresh + resume por FCM + post-frame inicial), se ignora la llamada.
    if (_refreshing) return;
    _refreshing = true;
    try {
      final authState = context.read<AuthBloc>().state;
      final children = _buildChildren(authState);
      if (children.isNotEmpty) {
        final studentId = children[_selectedChild.clamp(0, children.length - 1)].studentId;
        final api = context.read<ApiClient>();
        final repo = ClassroomRepository(api);
        // 1er /parent/home: trae upcomingStatus.connected (fuente de verdad del
        // backend). La decisión de sync ya NO depende de _knownConnected (que
        // puede no estar poblado por la carrera con SharedPreferences).
        final home = await _loadParentHome(studentId);
        if (!mounted) return;
        final connected = home?.upcomingStatus.connected ?? false;
        // Sincronizamos la card "Conectar" de forma determinista con el dato
        // del servidor (redundante con _loadParentHome, pero explícito).
        setState(() {
          _classroomStatusFuture = Future.value(connected);
          _classroomConnected = connected;
        });
        // El sync solo tiene sentido si el alumno está conectado a Google
        // Classroom (según el backend). Si no lo está, se omite.
        if (connected) {
          try {
            final result = await repo.sync(studentId, force: force);
            // Mejora C: si el sync fue cache hit (no trajo datos nuevos de
            // Google), la primera carga de /parent/home ya es suficiente y
            // evitamos el segundo /parent/home redundante. Solo recargamos
            // si el sync realmente trajo datos nuevos (cache miss).
            if (!result.cacheHit) {
              await _loadParentHome(studentId);
            }
          } catch (_) {
            // Sync falla silenciosamente — los datos locales siguen cargando.
          }
        }
      } else {
        setState(() => _refreshKey++);
      }
    } finally {
      _refreshing = false;
    }
  }

  /// Carga los datos combinados del home del padre en UNA sola petición.
  /// `_NovedadesCard` y `_EstaSemanRow` consumen este resultado compartido.
  Future<ParentHomeData?> _loadParentHome(String studentId) async {
    try {
      final repo = ClassroomRepository(context.read<ApiClient>());
      final data = await repo.getParentHome(studentId);
      if (!mounted) return null;
      setState(() {
        _parentHome = data;
        _refreshKey++;
        // Mejora A: fuente de verdad de connected = upcomingStatus.connected
        // (la misma petición). Auto-corrige un _knownConnected desactualizado
        // (p. ej. token revocado en otro dispositivo) sin GET /status.
        final serverConnected = data.upcomingStatus.connected;
        if (serverConnected != _classroomConnected) {
          _classroomConnected = serverConnected;
          _classroomStatusFuture = Future.value(serverConnected);
        }
      });
      if (data.upcomingStatus.connected != _knownConnected[studentId]) {
        _rememberConnected(studentId, data.upcomingStatus.connected);
      }
      print('[FLOW] home-to-first-data = '
          '${DateTime.now().millisecondsSinceEpoch - _homeStartMs} ms');
      return data;
    } catch (_) {
      // Error de red: mantener los datos anteriores sin romper la UI.
      return null;
    }
  }

  Future<void> _connectClassroom() async {
    final studentId = _currentStudentId();
    if (studentId == null) return;
    // Evita doble toque: deshabilita el botón mientras se procesa.
    if (_connectingClassroom) return;
    setState(() => _connectingClassroom = true);
    try {
      final url = await ClassroomRepository(context.read<ApiClient>()).getAuthUrl(studentId);
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el navegador')),
        );
        return;
      }
      if (mounted) {
        // Marcamos que fuimos al navegador de Google. NO activamos
        // _waitingClassroomConfirm aquí: el mensaje "Estamos cargando tus
        // tareas..." SOLO debe aparecer DESPUÉS de volver del navegador y
        // haber aceptado los permisos (ver didChangeAppLifecycleState →
        // _verifyClassroomConnection), nunca antes de ir al navegador.
        _wentToClassroomBrowser = true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _connectingClassroom = false);
    }
  }

  Future<void> _verifyClassroomConnection() async {
    final studentId = _currentStudentId();
    if (studentId == null) return;
    // Evita doble toque: deshabilita el botón mientras se procesa.
    if (_connectingClassroom) return;
    // El flujo automático (o el manual) ya se disparó: cancelamos el timer de
    // respaldo para que NO muestre el botón manual mientras verificamos.
    _verifyTimeout?.cancel();
    _verifyTimeout = null;
    final api = context.read<ApiClient>();
    final repo = ClassroomRepository(api);
    // Mantenemos el estado "Verificando conexión..." mientras se sincroniza.
    if (mounted) {
      setState(() {
        _connectingClassroom = true;
        _waitingClassroomConfirm = true;
        _showManualVerify = false;
      });
    }
    // Verificamos REALMENTE si el usuario autorizó los permisos al volver del
    // navegador. isConnected consulta el backend (devuelve true solo si hay
    // token guardado). Esto cubre el caso en que el usuario vuelve SIN aceptar
    // permisos (canceló): en ese caso NO debe marcarse como conectado.
    bool connected = false;
    try {
      connected = await repo.isConnected(studentId);
    } catch (_) {
      connected = false;
    }
    if (!mounted) return;
    if (!connected) {
      // El usuario NO autorizó (canceló o volvió sin aceptar): NO marcamos el
      // alumno como conectado. Dejamos el estado en "no conectado" para que el
      // home vuelva a mostrar la card "Conectar Google Classroom" (botón
      // "Conectar con Google") y NO la card "Esta semana".
      setState(() {
        _connectingClassroom = false;
        _waitingClassroomConfirm = false;
        _showManualVerify = false;
        _classroomStatusFuture = Future.value(false);
        _classroomConnected = false;
      });
      _rememberConnected(studentId, false);
      return;
    }
    // El usuario SÍ autorizó: sincronizamos ANTES de mostrar la card "Esta
    // semana" para que el conteo de pendientes ya incluya los datos recién
    // traídos de Google.
    try { await repo.sync(studentId); } catch (_) {}
    if (!mounted) return;
    // Mantenemos "Estamos cargando tus tareas..." visible (waitingConfirm=true)
    // mientras cargamos los datos combinados del home. Así el card "Esta
    // semana" aparece YA con el conteo real ("N tareas" o "sin pendientes") y
    // NO muestra "Sin pendientes" ni "Cargando tus tareas..." brevemente antes
    // de actualizarse.
    await _loadParentHome(studentId);
    if (!mounted) return;
    setState(() {
      _connectingClassroom = false;
      _waitingClassroomConfirm = false;
      _showManualVerify = false;
      _classroomStatusFuture = Future.value(true);
      _classroomConnected = true;
    });
    // Persistimos el estado de conexión para la próxima entrada.
    _rememberConnected(studentId, true);
  }

  void _selectChild(int index) {
    setState(() {
      _selectedChild = index;
      // Limpiar los datos del hijo anterior para no mostrar datos cruzados
      // mientras cargan los del hijo recién seleccionado.
      _parentHome = null;
    });
    // Recalcular el estado de conexión de Classroom del hijo recién
    // seleccionado para que la card de conectar se muestre/oculte bien.
    final authState = context.read<AuthBloc>().state;
    final children = _buildChildren(authState);
    if (children.isNotEmpty) {
      final studentId = children[index.clamp(0, children.length - 1)].studentId;
      // Mejora A: estado de conexión 100% síncrono (_knownConnected persistido),
      // sin GET /status. La reconciliación con el backend la hace
      // _loadParentHome vía upcomingStatus.connected.
      final known = _knownConnected[studentId] ?? false;
      setState(() {
        _classroomConnected = known;
        _classroomStatusFuture = Future.value(known);
      });
      // Cargar los datos combinados del nuevo hijo.
      _loadParentHome(studentId);
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return '¡Buenos días';
    if (h < 19) return '¡Buenas tardes';
    return '¡Buenas noches';
  }

  List<_Child> _buildChildren(AuthState state) {
    if (state is AuthAuthenticated && state.user.children.isNotEmpty) {
      return state.user.children
          .map((c) => _Child(
                studentId: c.id.toString(),
                initials: _initials(c.firstName, c.lastName),
                fullName: c.fullName,
                section: c.section,
                age: c.age,
                avatarUrl: c.avatarUrl,
              ))
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Screen size: ${MediaQuery.of(context).size}');
    final authState = context.read<AuthBloc>().state;
    final firstName =
        authState is AuthAuthenticated ? authState.user.firstName : '';
    final parentAvatarUrl =
        authState is AuthAuthenticated ? authState.user.avatar : null;
    final parentInitials = authState is AuthAuthenticated
        ? _initials(authState.user.firstName, authState.user.lastName)
        : '';
    final children = _buildChildren(authState);
    final safeIndex =
        children.isEmpty ? 0 : _selectedChild.clamp(0, children.length - 1);

    final now = DateTime.now();
    final days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    final months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    final dateStr =
        '${days[now.weekday - 1]} ${now.day} de ${months[now.month - 1]}';
    final sizes = Theme.of(context).extension<AppSizes>()!;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Contenido scrollable ───────────────────────
            // Tope de ancho: a partir de 600dp (breakpoint de tablet de
            // Android WindowSizeClass) el contenido deja de estirarse y
            // se centra, en vez de romper el layout de las tarjetas.
            Expanded(
              child: _navIndex == 2
                  ? const PerfilTab()
                  : RefreshIndicator(
                color: _kPrimary,
                onRefresh: () => _onRefresh(force: true),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                        sizes.cardPadding, 19, sizes.cardPadding, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Banner: notificaciones desactivadas ──
                        // Se muestra si el usuario apagó las notificaciones
                        // desde Ajustes (nivel WhatsApp).
                        const NotificationBanner(),
                        const SizedBox(height: 12),

                        // ── Header: saludo + switcher ──────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${_greeting()}, $firstName!',
                                      style: TextStyle(
                                        fontSize: sizes.titleHorizontal,
                                        fontWeight: FontWeight.w700,
                                        color: _kTextDark,
                                      )),
                                  const SizedBox(height: 4),
                                  Text(dateStr,
                                      style: TextStyle(
                                        fontSize: sizes.textFecha,
                                        color: _kTextGray,
                                      )),
                                ],
                              ),
                            ),
                            // Con un solo hijo no hay nada entre qué elegir
                            // — en vez del switcher (pensado para 2+ hijos,
                            // con círculo secundario y badge) se muestra la
                            // foto de perfil de Google del padre.
                            if (children.length > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: _ChildSwitcher(
                                  children: children,
                                  selectedIndex: safeIndex,
                                  onSelect: _selectChild,
                                ),
                              )
                            else if (children.length == 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: _AvatarCircle(
                                  initials: parentInitials,
                                  size: sizes.childSwitcherCircle,
                                  avatarUrl: parentAvatarUrl,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 13),

                        // ── Card: datos del hijo ───────────────
                        if (children.isNotEmpty) ...[
                          _ChildInfoCard(
                            child: children[safeIndex],
                            onTap: () => _showChildPicker(children, safeIndex),
                          ),
                          const SizedBox(height: 12),

                          // ── Card: urgente para hoy ─────────────
                          // Tareas de Classroom que vencen hoy — mismo dato
                          // ya cargado por /parent/home, sin petición extra.
                          _UrgentCard(
                            tasksToday: (_parentHome?.upcomingStatus.upcoming ?? [])
                                .where((cw) =>
                                    cw.dueDate != null &&
                                    limaDay(cw.dueDate!) == limaToday())
                                .toList(),
                            // Resto de la semana (sin contar hoy) — mismo
                            // criterio que la tarjeta "Esta semana".
                            weekCount: (_parentHome?.upcomingStatus.upcoming ?? [])
                                .where((cw) {
                              if (cw.dueDate == null) return false;
                              final today = limaToday();
                              final weekStart =
                                  today.subtract(Duration(days: today.weekday - 1));
                              final weekEnd = weekStart.add(const Duration(
                                  days: 6, hours: 23, minutes: 59, seconds: 59));
                              final restOfWeekStart =
                                  today.add(const Duration(days: 1));
                              final d = limaDay(cw.dueDate!);
                              return !d.isBefore(restOfWeekStart) &&
                                  !d.isAfter(weekEnd);
                            }).length,
                            studentName: children[safeIndex].fullName,
                          ),
                          const SizedBox(height: 12),

                          // ── Card: novedades de hoy ─────────────
                          // Recibe el summary del estado padre (cargado por
                          // /parent/home en UNA sola petición) y un callback
                          // para refrescar. Ya no hace su propia llamada.
                          _NovedadesCard(
                            child: children[safeIndex],
                            dateLabel: dateStr,
                            summary: _parentHome?.todaySummary,
                            onRefresh: () => _loadParentHome(
                                children[safeIndex].studentId),
                          ),
                          const SizedBox(height: 12),

                          // ── Row: esta semana ───────────────────
                          // Recibe el upcomingStatus del estado padre
                          // (cargado por /parent/home en la misma petición
                          // que las novedades). Ya no hace su propia llamada,
                          // evitando que ambos cards compitan por la única
                          // conexión del pooler.
                          Column(
                            children: [
                              _EstaSemanRow(
                                child: children[safeIndex],
                                refreshKey: _refreshKey,
                                upcomingStatus: _parentHome?.upcomingStatus,
                                // Estado de conexión conocido de forma
                                // síncrona (isConnected): permite que el card
                                // se muestre en estado de carga junto al de
                                // "Novedades" desde el inicio, sin esperar a
                                // /parent/home.
                                connected: _classroomConnected,
                                // Mientras la card "Conectar Google Classroom"
                                // muestra "Estamos cargando tus tareas...", el
                                // card "Esta semana" se oculta para no mostrar
                                // 2 cards a la vez.
                                waitingConfirm: _waitingClassroomConfirm,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),

                          // ── Card: conectar Google Classroom ─────
                          // Solo se muestra si el alumno aún no ha
                          // vinculado su cuenta de Google.
                          FutureBuilder<bool>(
                            future: _classroomStatusFuture,
                            builder: (context, snap) {
                              final connected = snap.data ?? true;
                              // Mientras se está verificando la conexión
                              // (_waitingClassroomConfirm), la card debe seguir
                              // visible mostrando "Estamos cargando" para no
                              // dejar un hueco vacío antes de que aparezca
                              // "Esta semana".
                              if (connected && !_waitingClassroomConfirm) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                children: [
                                  _ClassroomConnectCardParent(
                                    childName: children[safeIndex].fullName,
                                    waitingConfirm: _waitingClassroomConfirm,
                                    connecting: _connectingClassroom,
                                    showManualVerify: _showManualVerify,
                                    onConnect: _connectClassroom,
                                    onVerify: _verifyClassroomConnection,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              );
                            },
                          ),

                        ],

                        // ── Accesos rápidos ────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Text('Accesos Rápidos',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _kTextDark)),
                            ),
                            const Text('Ver todo',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _kPrimary)),
                            const SizedBox(width: 4),
                            const Text('›',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: _kPrimary)),
                            const SizedBox(width: 16),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const _AccesosRapidos(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  ),
                ),
              ),
            ),

            // ── Bottom Nav (fijo) ──────────────────────────
            _BottomNav(
              selected: _navIndex,
              onTap: (i) => setState(() => _navIndex = i),
            ),
          ],
        ),
      ),
    );
  }

  void _showChildPicker(List<_Child> children, int currentIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selecciona un hijo',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark)),
            const SizedBox(height: 16),
            ...children.asMap().entries.map((e) {
              final i = e.key;
              final c = e.value;
              final selected = i == currentIndex;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _AvatarCircle(
                    initials: c.initials,
                    size: 40,
                    color: selected ? _kPrimary : _kSwitchSec,
                    avatarUrl: c.avatarUrl),
                title: Text(c.fullName,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: _kTextDark,
                    )),
                subtitle: c.section != null
                    ? Text(
                        c.age != null
                            ? '${c.section} · ${c.age} años'
                            : c.section!,
                        style: const TextStyle(color: _kTextGray, fontSize: 12),
                      )
                    : null,
                trailing: selected
                    ? const Icon(Icons.check_circle, color: _kPrimary)
                    : null,
                onTap: () {
                  _switchChild(i);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Child Switcher animado
// Al tocar, el círculo frontal (36×36) y el trasero (28×28)
// intercambian posición, tamaño y color con animación suave.
// Al terminar notifica al padre para avanzar _selectedChild.
// ─────────────────────────────────────────────────────────
class _ChildSwitcher extends StatelessWidget {
  final List<_Child> children;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _ChildSwitcher({
    required this.children,
    required this.selectedIndex,
    required this.onSelect,
  });

  void _openSheet(BuildContext context) {
    if (children.length < 2) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDD8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Seleccionar hijo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF888099),
                    ),
                  ),
                ),
              ),
              ...children.asMap().entries.map((e) {
                final i = e.key;
                final child = e.value;
                final isSelected = i == selectedIndex;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: _AvatarCircle(
                    initials: child.initials,
                    size: 40,
                    color: isSelected ? _kPrimary : _kSwitchSec,
                    fontSize: 15,
                    avatarUrl: child.avatarUrl,
                  ),
                  title: Text(
                    child.fullName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? _kPrimary : const Color(0xFF1A0F3A),
                    ),
                  ),
                  subtitle: child.section != null
                      ? Text(child.section!,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF888099)))
                      : null,
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: _kPrimary, size: 20)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    onSelect(i);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final selIdx = selectedIndex;
    final nextIdx = (selIdx + 1) % children.length;
    final hasMore = children.length > 2;
    final extra = children.length - 2;
    final sizes = Theme.of(context).extension<AppSizes>()!;

    final ratio = sizes.childSwitcherCircle / 36.0;
    final circleBig = sizes.childSwitcherCircle;
    final circleSmall = 28.0 * ratio;
    final boxWidth = 52.0 * ratio;
    final boxHeight = 40.0 * ratio;
    final fontBig = 12.0 * ratio;
    final fontSmall = 10.0 * ratio;
    final badgeFont = 9.0 * ratio;
    final badgeSize = 15.0 * ratio;
    final offsetX = 24.0 * ratio;
    final offsetY = 4.0 * ratio;

    return GestureDetector(
      onTap: () => _openSheet(context),
      child: SizedBox(
        width: boxWidth,
        height: boxHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Círculo secundario (atrás)
            Positioned(
              left: offsetX,
              top: offsetY,
              child: _AvatarCircle(
                initials: children[nextIdx].initials,
                size: circleSmall,
                color: _kSwitchSec,
                fontSize: fontSmall,
                avatarUrl: children[nextIdx].avatarUrl,
              ),
            ),
            // Círculo activo (adelante) con borde
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _kBg, width: 2),
                ),
                child: _AvatarCircle(
                  initials: children[selIdx].initials,
                  size: circleBig,
                  color: _kPrimary,
                  fontSize: fontBig,
                  avatarUrl: children[selIdx].avatarUrl,
                ),
              ),
            ),
            // Badge: coordenadas exactas del diseño Figma (27, 25) en frame 52×40
            if (children.length >= 2)
              Positioned(
                left: 27.0 * ratio,
                top: 25.0 * ratio,
                child: hasMore
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kBg, width: 1.5),
                        ),
                        child: Text('+$extra',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: badgeFont,
                                fontWeight: FontWeight.w700)),
                      )
                    : Container(
                        width: badgeSize,
                        height: badgeSize,
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: _kBg, width: 1.5),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: badgeSize * 0.8,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Card: info del hijo seleccionado
// ─────────────────────────────────────────────────────────
class _ChildInfoCard extends StatelessWidget {
  final _Child child;
  final VoidCallback onTap;
  const _ChildInfoCard({required this.child, required this.onTap});

  static const _kMenuText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: _kTextDark,
  );

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return _Card(
      onTap: onTap,
      child: Row(
        children: [
          _AvatarCircle(
            initials: child.initials,
            size: sizes.avatarLarge,
            fontSize: sizes.avatarLarge / 55 * 16,
            avatarUrl: child.avatarUrl,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child.fullName,
                    style: TextStyle(
                        fontSize: sizes.textNombreHijo,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        color: _kTextDark)),
                if (child.section != null || child.age != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (child.section != null) 'Sección ${child.section!}',
                      if (child.age != null) '${child.age} años',
                    ].join(' · '),
                    style: TextStyle(
                        fontSize: sizes.textSubtitulo,
                        height: 1.0,
                        color: _kTextGray),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: _kChevron, size: 26),
            padding: EdgeInsets.zero,
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.white,
            elevation: 8,
            shadowColor: Colors.black26,
            constraints: const BoxConstraints(minWidth: 180),
            onSelected: (value) {},
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'archivo',
                height: 44,
                child: Row(
                  children: [
                    Icon(Icons.history, color: _kPrimary, size: 20),
                    SizedBox(width: 10),
                    Text('Archivo de días', style: _kMenuText),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'editar',
                height: 44,
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/ic_edit_perfil.svg',
                      width: 20,
                      colorFilter: const ColorFilter.mode(_kPrimary, BlendMode.srcIn),
                    ),
                    const SizedBox(width: 10),
                    const Text('Editar perfil', style: _kMenuText),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'horario',
                height: 44,
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, color: _kPrimary, size: 20),
                    SizedBox(width: 10),
                    Text('Ver horario', style: _kMenuText),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Card: novedades de hoy (llegada · ahora · fotos)
// ─────────────────────────────────────────────────────────
class _NovedadesCard extends StatefulWidget {
  final _Child child;
  final String dateLabel;
  /// Resumen de hoy compartido desde el estado padre (cargado por
  /// /parent/home en la misma petición que "Esta semana").
  final TodaySummary? summary;
  /// Callback para refrescar los datos desde el padre.
  final VoidCallback onRefresh;
  const _NovedadesCard({
    required this.child,
    required this.dateLabel,
    required this.summary,
    required this.onRefresh,
  });

  @override
  State<_NovedadesCard> createState() => _NovedadesCardState();
}

class _NovedadesCardState extends State<_NovedadesCard>
    with WidgetsBindingObserver {
  // Copia local del summary para poder recalcular el "Ahora" cada 30s sin
  // tocar la red. Se sincroniza con widget.summary cuando el padre refresca.
  TodaySummary? _summary;
  bool _initialized = false;
  Timer? _scheduleTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _startAutoRefresh();
    }
  }

  @override
  void didUpdateWidget(_NovedadesCard old) {
    super.didUpdateWidget(old);
    // Cambió el hijo: limpiar los datos del hijo anterior para no mostrar
    // datos cruzados mientras cargan los del nuevo.
    if (old.child.studentId != widget.child.studentId) {
      setState(() => _summary = null);
    }
    // El padre refrescó los datos (FCM, resume, sync): sincronizamos la
    // copia local. Si ya tenemos datos locales con el "Ahora" recalculado,
    // conservamos el currentCourse actualizado.
    if (old.summary != widget.summary && widget.summary != null) {
      setState(() {
        _summary = widget.summary;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Si el padre ya tiene datos cargados (p. ej. al cambiar de hijo),
    // usarlos de inmediato en lugar de mostrar el estado de carga.
    _summary = widget.summary;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scheduleTimer?.cancel();
    // Limpiar el callback global de refresh para no dejar referencias colgadas.
    if (PushNotificationsService.instance.onDataRefresh == _handleDataRefresh) {
      PushNotificationsService.instance.onDataRefresh = null;
    }
    super.dispose();
  }

  // ── Auto-refresh en tiempo real ──────────────────────────
  // 1) FCM data message: el backend envía `refresh: true` cuando se
  //    registra asistencia o se suben fotos → refresca desde el padre.
  // 2) Timer local: recalcula el bloque de horario activo cada 30s
  //    para que el "Ahora" cambie de clase sin tocar la red.
  // 3) Al volver de background (resume) → refresca por si hubo cambios.
  void _startAutoRefresh() {
    PushNotificationsService.instance.onDataRefresh = _handleDataRefresh;
    _scheduleTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _recalculateSchedule();
    });
  }

  void _handleDataRefresh() {
    if (!mounted) return;
    widget.onRefresh();
  }

  // Recalcula el curso activo ("Ahora") desde los bloques de horario
  // ya cargados, comparando con la hora actual. No requiere red.
  void _recalculateSchedule() {
    final blocks = _summary?.scheduleBlocks;
    if (blocks == null || blocks.isEmpty) return;

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    String? activeCourse;
    for (final b in blocks) {
      final start = _toMinutes(b.startTime);
      final end = _toMinutes(b.endTime);
      if (nowMinutes >= start && nowMinutes < end) {
        if (b.type == 'class') activeCourse = b.courseName;
        break;
      }
    }

    final newCourse = activeCourse ?? '–';
    if (_summary!.currentCourse != newCourse) {
      setState(() {
        _summary = TodaySummary(
          arrivalStatus: _summary!.arrivalStatus,
          arrivalTime: _summary!.arrivalTime,
          currentCourse: newCourse,
          photoCount: _summary!.photoCount,
          photoUrls: _summary!.photoUrls,
          scheduleBlocks: _summary!.scheduleBlocks,
        );
      });
    }
  }

  int _toMinutes(String time) {
    final parts = time.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return h * 60 + m;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleDataRefresh();
    }
  }

  void _openDetail() {
    if (_summary == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovedadesDetailPage(
          summary: _summary!,
          childName: widget.child.fullName,
          dateLabel: widget.dateLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return GestureDetector(
      onTap: _openDetail,
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Novedades de hoy',
                    style: TextStyle(
                        fontSize: sizes.textValueCard,
                        fontWeight: FontWeight.w700,
                        color: _kTextDark)),
                const Text('›',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _kChevron)),
              ],
            ),
            const SizedBox(height: 16),
            // Fuente de verdad: `_summary` (se sincroniza con el summary del
            // padre, que se actualiza por FCM data message, refresh on resume
            // y tras el sync). Mientras carga, mostramos placeholders.
            if (_summary == null)
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NovedadItem(
                    iconAsset: 'assets/icons/ic_llegada.svg',
                    label: 'Llegada',
                    value: 'Cargando...',
                  ),
                  _NovedadItem(
                    iconAsset: 'assets/icons/ic_ahora.svg',
                    label: 'Ahora',
                    value: '–',
                  ),
                  _NovedadItem(
                    iconAsset: 'assets/icons/ic_fotos.svg',
                    label: 'Fotos',
                    value: '–',
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NovedadItem(
                    iconAsset: 'assets/icons/ic_llegada.svg',
                    label: 'Llegada',
                    value: _summary!.arrivalLabel,
                    valueColor: _summary!.arrivalStatus == 'present'
                        ? const Color(0xFF1F6B44)
                        : _summary!.arrivalStatus == 'late'
                            ? const Color(0xFF96650C)
                            : _summary!.arrivalStatus == 'absent'
                                ? Colors.red[700]
                                : _summary!.arrivalStatus == 'justified'
                                    ? const Color(0xFF5B4A9E)
                                    : _kTextGray,
                  ),
                  _NovedadItem(
                    iconAsset: 'assets/icons/ic_ahora.svg',
                    label: 'Ahora',
                    value: _summary!.currentCourse ?? '–',
                  ),
                  _NovedadItem(
                    iconAsset: 'assets/icons/ic_fotos.svg',
                    label: 'Fotos',
                    value: _summary!.photoLabel,
                  ),
                ],
              ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Card: conectar Google Classroom del hijo (padre)
// ─────────────────────────────────────────────────────────
class _ClassroomConnectCardParent extends StatelessWidget {
  final String childName;
  final bool waitingConfirm;
  final bool connecting;
  final bool showManualVerify;
  final VoidCallback onConnect;
  final VoidCallback onVerify;

  const _ClassroomConnectCardParent({
    required this.childName,
    required this.waitingConfirm,
    required this.connecting,
    required this.showManualVerify,
    required this.onConnect,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPrimaryLt, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: _kPrimaryLt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_outlined, color: _kPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conecta Google Classroom',
                      style: TextStyle(
                        fontSize: sizes.textValueCard,
                        fontWeight: FontWeight.w700,
                        color: _kTextDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vincula la cuenta de $childName para ver sus tareas y novedades',
                      style: TextStyle(fontSize: sizes.textLabelCard, color: _kTextGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── Estado: esperando confirmación del navegador o verificando ──
          // Mientras se espera el regreso del navegador o se sincronizan las
          // tareas, NO mostramos botones: solo un mensaje de espera claro.
          if (waitingConfirm) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    showManualVerify
                        ? 'No pudimos verificar automáticamente'
                        : 'Estamos cargando tus tareas, un momento por favor...',
                    style: TextStyle(fontSize: sizes.textLabelCard, color: _kTextGray),
                  ),
                ),
              ],
            ),
            // Si el flujo automático no detecta el regreso del navegador,
            // mostramos el botón manual como respaldo.
            if (showManualVerify) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: connecting ? null : onVerify,
                  icon: connecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _kPrimary),
                        )
                      : const Icon(Icons.verified_outlined,
                          size: 16, color: _kPrimary),
                  label: Text(
                    connecting ? 'Verificando...' : 'Ya autoricé, verificar',
                    style: TextStyle(
                        fontSize: sizes.textValueCard,
                        fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kPrimary,
                    side: BorderSide(
                        color: connecting ? const Color(0xFF6F60AA) : _kPrimary),
                    disabledForegroundColor: const Color(0xFF6F60AA),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ] else ...[
            // ── Estado: botón "Conectar con Google" ──
            // Mientras se prepara la conexión (esperando la URL del navegador)
            // ocultamos el botón y mostramos un mensaje de espera.
            if (connecting) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _kPrimary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Preparando la conexión...',
                    style: TextStyle(
                        fontSize: sizes.textLabelCard, color: _kTextGray),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onConnect,
                  icon: const Icon(Icons.link, size: 16, color: Colors.white),
                  label: Text(
                    'Conectar con Google',
                    style: TextStyle(
                        fontSize: sizes.textValueCard,
                        fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _NovedadItem extends StatelessWidget {
  final String? iconAsset;
  final IconData? icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _NovedadItem({
    this.iconAsset,
    this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: sizes.circleIconNovedades,
            height: sizes.circleIconNovedades,
            decoration: const BoxDecoration(
              color: Color(0xFFE2F9E3),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: sizes.glyphNovedades, color: const Color(0xFF145D10))
                : SvgPicture.asset(
                    iconAsset!,
                    width: sizes.glyphNovedades,
                    colorFilter: const ColorFilter.mode(
                        Color(0xFF145D10), BlendMode.srcIn),
                  ),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: sizes.textLabelCard,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF145D10))),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: sizes.textValueCard,
              fontWeight: FontWeight.w400,
              color: valueColor ?? _kTextGray,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Modelo interno de ítem pendiente (extensible a pagos, etc.)
// ─────────────────────────────────────────────────────────
enum _PendingType { tarea, pago }

class _PendingItem {
  final _PendingType type;
  final String title;
  final String subtitle;
  final DateTime? dueDate;
  final String? workType; // 'ASSIGNMENT' | 'SHORT_ANSWER_QUESTION' | 'MULTIPLE_CHOICE_QUESTION'

  const _PendingItem({
    required this.type,
    required this.title,
    required this.subtitle,
    this.dueDate,
    this.workType,
  });
}

// ─────────────────────────────────────────────────────────
// Card: pendientes (tareas de Classroom; pagos cuando esté listo)
// Muestra máx 3 ítems; si hay más, el 3ro muestra "y N más" al costado.
// Si solo hay tareas, el header lo indica con "ver solo tareas →".
// ─────────────────────────────────────────────────────────
class _PendientesCard extends StatefulWidget {
  final String studentId;
  const _PendientesCard({super.key, required this.studentId});

  @override
  State<_PendientesCard> createState() => _PendientesCardState();
}

class _PendientesCardState extends State<_PendientesCard> {
  late Future<List<_PendingItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(_PendientesCard old) {
    super.didUpdateWidget(old);
    if (old.studentId != widget.studentId) {
      setState(() => _future = _load());
    }
  }

  Future<List<_PendingItem>> _load() async {
    if (widget.studentId.isEmpty) return [];
    try {
      final upcoming = await ClassroomRepository(context.read<ApiClient>())
          .getUpcoming(widget.studentId);
      final items = upcoming
          .map((cw) => _PendingItem(
                type: _PendingType.tarea,
                title: cw.title,
                subtitle: cw.courseName,
                dueDate: cw.dueDate,
                workType: cw.workType,
              ))
          .toList();
      // Cuando haya pagos: añadirlos aquí y reordenar por dueDate
      return items;
    } catch (e) {
      debugPrint('[PendientesCard] getUpcoming error: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;

    return _Card(
      radius: 16,
      child: FutureBuilder<List<_PendingItem>>(
        future: _future,
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          final onlyTareas = items.every((i) => i.type == _PendingType.tarea);
          final visible = items.take(5).toList();
          final extra = items.length - visible.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cabecera ─────────────────────────────────
              Row(
                children: [
                  Text(
                    'Pendientes',
                    style: TextStyle(
                      fontSize: sizes.textValueCard,
                      fontWeight: FontWeight.w600,
                      color: _kTextDark,
                    ),
                  ),
                  const Spacer(),
                  if (items.isNotEmpty && onlyTareas)
                    Text(
                      'ver tareas →',
                      style: TextStyle(
                        fontSize: sizes.textLabelCard,
                        color: _kPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    const Text('›',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _kChevron)),
                ],
              ),

              // ── Estado vacío ──────────────────────────────
              if (!snapshot.hasData) ...[
                const SizedBox(height: 14),
                const SizedBox(
                  height: 20,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kPrimary),
                    ),
                  ),
                ),
              ] else if (items.isEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Sin pendientes esta semana',
                  style: TextStyle(
                      fontSize: sizes.textLabelCard, color: _kTextGray),
                ),
              ] else ...[
                const SizedBox(height: 4),
                ...visible.asMap().entries.map((e) {
                  final isLast = e.key == visible.length - 1;
                  return _PendienteRow(
                    item: e.value,
                    showDivider: !isLast,
                    extraCount: isLast ? extra : 0,
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Fila individual de ítem pendiente
// ─────────────────────────────────────────────────────────
class _PendienteRow extends StatelessWidget {
  final _PendingItem item;
  final bool showDivider;
  final int extraCount;

  const _PendienteRow({
    required this.item,
    this.showDivider = true,
    this.extraCount = 0,
  });

  String _fmtDue(DateTime d) {
    final local = d.toLocal();
    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return '${local.day} ${months[local.month]}';
  }

  IconData get _icon {
    if (item.type == _PendingType.pago) return Icons.credit_card_outlined;
    switch (item.workType) {
      case 'SHORT_ANSWER_QUESTION':
      case 'MULTIPLE_CHOICE_QUESTION':
        return Icons.quiz_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: _kPrimaryLt,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(_icon, size: 13, color: _kPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: sizes.textValueCard,
                        fontWeight: FontWeight.w600,
                        color: _kTextDark,
                      ),
                    ),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: sizes.textLabelCard, color: _kTextGray),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (item.dueDate != null)
                Text(
                  _fmtDue(item.dueDate!),
                  style: TextStyle(
                      fontSize: sizes.textLabelCard, color: _kTextGray),
                ),
              if (extraCount > 0) ...[
                const SizedBox(width: 6),
                Text(
                  'y $extraCount más',
                  style: TextStyle(
                    fontSize: sizes.textLabelCard,
                    color: _kPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0EFF4)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Accesos rápidos (2 filas × 3)
// ─────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────
// Card: urgente para hoy (ámbar)
// ─────────────────────────────────────────────────────────
class _UrgentCard extends StatelessWidget {
  final List<GcCoursework> tasksToday;
  final int weekCount;
  final String studentName;

  const _UrgentCard({
    required this.tasksToday,
    required this.weekCount,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => PendientesPage(
            studentName: studentName,
            todayTasks: tasksToday,
            weekCount: weekCount,
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF0DD),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFF6E0AB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFF693902), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Urgente para hoy',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF693902))),
                  const SizedBox(height: 1),
                  Text(
                    tasksToday.isEmpty
                        ? 'Sin tareas urgentes hoy'
                        : tasksToday.length == 1
                            ? '1 tarea vence hoy'
                            : '${tasksToday.length} tareas vencen hoy',
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF693902)),
                  ),
                ],
              ),
            ),
            const Text('›',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _kChevron)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Row: esta semana (resumen semanal)
// ─────────────────────────────────────────────────────────
class _EstaSemanRow extends StatefulWidget {
  final _Child child;
  final int refreshKey;
  /// upcomingStatus compartido desde el estado padre (cargado por
  /// /parent/home en la misma petición que "Novedades").
  final UpcomingStatus? upcomingStatus;
  /// Estado de conexión a Classroom conocido de forma síncrona (isConnected).
  /// Permite mostrar el card en estado de carga ("Cargando tus tareas...")
  /// junto al de "Novedades" desde el inicio, sin esperar a /parent/home.
  final bool? connected;
  /// Mientras la card "Conectar Google Classroom" muestra "Estamos cargando
  /// tus tareas..." (verificación tras volver del navegador), el card "Esta
  /// semana" NO debe aparecer para evitar mostrar 2 cards a la vez.
  final bool waitingConfirm;
  const _EstaSemanRow({
    required this.child,
    required this.refreshKey,
    required this.upcomingStatus,
    this.connected,
    this.waitingConfirm = false,
  });

  @override
  State<_EstaSemanRow> createState() => _EstaSemanRowState();
}

class _EstaSemanRowState extends State<_EstaSemanRow> {
  int? _count;
  List<GcCoursework>? _items;
  bool? _connected;

  @override
  void initState() {
    super.initState();
    _applyStatus(widget.upcomingStatus);
  }

  @override
  void didUpdateWidget(_EstaSemanRow old) {
    super.didUpdateWidget(old);
    // Recalcular cuando cambia el hijo, el home se refresca o llegan datos
    // nuevos del padre (p. ej. al volver de conectar Google Classroom).
    if (old.child.studentId != widget.child.studentId) {
      // Cambió el hijo: limpiar los datos del hijo anterior para no mostrar
      // datos cruzados mientras cargan los del nuevo.
      setState(() {
        _count = null;
        _items = null;
        _connected = null;
      });
    }
    if (old.child.studentId != widget.child.studentId ||
        old.refreshKey != widget.refreshKey ||
        old.upcomingStatus != widget.upcomingStatus) {
      _applyStatus(widget.upcomingStatus);
    }
  }

  // Deriva el conteo semanal desde el upcomingStatus compartido. No hace
  // ninguna llamada de red propia: los datos vienen de /parent/home.
  void _applyStatus(UpcomingStatus? status) {
    if (status == null) {
      // Aún no hay datos: mantener el estado de carga.
      if (_count == null && _connected == null) return;
      return;
    }
    final all = status.upcoming;
    final today = limaToday();
    // "Esta semana" arranca al día siguiente de hoy: el día actual ya
    // lo cubre la tarjeta/pestaña "Hoy", así que no se duplica aquí.
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    final restOfWeekStart = today.add(const Duration(days: 1));
    final count = all.where((cw) {
      if (cw.dueDate == null) return false;
      final d = limaDay(cw.dueDate!);
      return !d.isBefore(restOfWeekStart) && !d.isAfter(weekEnd);
    }).length;
    setState(() {
      _connected = status.connected;
      _count = count;
      _items = all;
    });
  }

  String get _subtitle {
    if (_count == null) return 'Cargando tus tareas...';
    if (_count == 0) return 'Sin pendientes';
    return '$_count tarea${_count != 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    // REQUISITO (UX): el card "Esta semana" SOLO debe verse cuando el alumno
    // está conectado a Google Classroom. Si NO está conectado, no debe
    // aparecer en ningún momento (ni siquiera en estado de carga).
    //
    // La fuente canónica es `_connected` (viene de /parent/home). Mientras
    // /parent/home aún no responde (_connected == null), usamos el estado de
    // conexión conocido de forma síncrona (widget.connected, de isConnected)
    // para que el card aparezca en estado de carga JUNTO al de "Novedades"
    // desde el inicio, sin esperar a /parent/home — pero ÚNICAMENTE si ese
    // estado conocido es `true` (conectado).
    //
    // Además, mientras la card "Conectar Google Classroom" está mostrando
    // "Estamos cargando tus tareas..." (widget.waitingConfirm == true, durante
    // la verificación tras volver del navegador), este card NO debe aparecer
    // para evitar mostrar 2 cards a la vez.
    final showCard = !widget.waitingConfirm &&
        (_connected == true || (widget.connected == true && _connected == null));
    if (!showCard) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EstaSemanPage(
            studentId: widget.child.studentId,
            studentName: widget.child.fullName,
            // Reutilizamos la lista ya cargada en el home para que la
            // página abra al instante, sin esperar otra llamada de red.
            initialData: _items,
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: _kPrimaryLt,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_today_outlined,
                  color: _kPrimary, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Esta semana',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kTextDark)),
                  const SizedBox(height: 1),
                  Text(_subtitle,
                      style: TextStyle(
                          fontSize: 13,
                          color: (_count != null && _count! > 0)
                              ? _kPrimary
                              : _kTextGray)),
                ],
              ),
            ),
            // Mientras carga, mostramos un spinner pequeño en lugar del badge
            // para que no parezca que "no hay pendientes".
            if (_count == null)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _kPrimary),
              )
            else if (_count! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kPrimaryLt,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_count',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kPrimary,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Text('›',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _kChevron)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
class _AccesosRapidos extends StatelessWidget {
  const _AccesosRapidos();

  static const _items = [
    (Icons.calendar_month_outlined, 'Calendario'),
    (Icons.photo_library_outlined,  'Fotos'),
    (Icons.bar_chart_rounded,       'Progreso'),
  ];

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return Row(
      children: _items.map((i) => _buildItem(context, i, sizes)).toList(),
    );
  }

  Widget _buildItem(BuildContext context, (IconData, String) item, AppSizes sizes) {
    return Expanded(
      child: GestureDetector(
        onTap: null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                width: sizes.circleIconAccesos,
                height: sizes.circleIconAccesos,
                decoration: const BoxDecoration(
                  color: _kPrimaryLt,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.$1, size: sizes.glyphAccesos, color: _kPrimary),
              ),
              const SizedBox(height: 8),
              Text(item.$2,
                  style: TextStyle(
                      fontSize: sizes.textLabelAccesos, color: _kTextDark)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Bottom Nav
// ─────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.selected, required this.onTap});

  static const _items = [
    ('assets/icons/ic_nav_inicio.svg', 'Inicio'),
    ('assets/icons/ic_nav_bandeja.svg', 'Bandeja'),
    ('assets/icons/ic_nav_perfil.svg', 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final sizes = Theme.of(context).extension<AppSizes>()!;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SizedBox(
              height: 64,
              child: Row(
                children: _items.asMap().entries.map((e) {
                  final i = e.key;
                  final item = e.value;
                  final active = i == selected;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            item.$1,
                            width: sizes.iconBottomNav,
                            height: sizes.iconBottomNav,
                            colorFilter: ColorFilter.mode(
                              active ? _kPrimary : _kNavInact,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(item.$2,
                              style: TextStyle(
                                fontSize: sizes.textLabelBottomNav,
                                fontWeight:
                                    active ? FontWeight.w600 : FontWeight.w400,
                                color: active ? _kPrimary : _kNavInact,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Widgets reutilizables
// ─────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  const _Card({required this.child, this.onTap, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String initials;
  final double size;
  final Color color;
  final double fontSize;
  final String? avatarUrl;

  const _AvatarCircle({
    required this.initials,
    required this.size,
    this.color = _kPrimary,
    this.fontSize = 14,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null) {
      return ClipOval(
        child: avatarUrl!.startsWith('assets/')
            ? Image.asset(
                avatarUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : Image.network(
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
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          )),
    );
  }
}
