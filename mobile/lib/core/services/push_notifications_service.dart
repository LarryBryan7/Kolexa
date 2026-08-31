import 'dart:io';
import 'package:flutter/material.dart' show Color;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

// Handler de background/terminated — debe ser top-level (no dentro de clase)
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Firebase ya muestra la notificación del sistema automáticamente
  // cuando la app está en background/terminated. No necesitamos hacer nada.
}

class PushNotificationsService {
  PushNotificationsService._();
  static final PushNotificationsService instance = PushNotificationsService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // Canal de notificaciones para Android 8+ (Oreo+)
  // Importance.max = banner flotante heads-up (igual que WhatsApp)
  static const _channel = AndroidNotificationChannel(
    'kolexa_default',
    'Notificaciones Kolexa',
    description: 'Asistencia, fotos y comunicados del colegio',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFF6C63FF),
  );

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Callback que se llama cuando llega una notificación y el usuario la toca
  Function(Map<String, dynamic> data)? onNotificationTap;

  // Callback para reenviar el token al backend cuando Firebase lo rota
  Function(String token)? onTokenRefresh;

  // Se dispara cuando llega un mensaje de datos (data message) con el flag
  // `refresh: true`. Se usa para refrescar una pantalla "en tiempo real"
  // (home padre, bandeja de chats, una conversación abierta) sin mostrar
  // una notificación visible. Es una LISTA porque más de una pantalla
  // puede estar escuchando a la vez (ej. el home sigue montado atrás
  // mientras hay una conversación abierta encima) — un callback único
  // hacía que una pantalla se "robara" el aviso de otra al suscribirse.
  final List<void Function(Map<String, dynamic> data)> _dataRefreshListeners = [];

  void addDataRefreshListener(void Function(Map<String, dynamic> data) listener) {
    _dataRefreshListeners.add(listener);
  }

  void removeDataRefreshListener(void Function(Map<String, dynamic> data) listener) {
    _dataRefreshListeners.remove(listener);
  }

  Future<void> initialize() async {
    // Registrar handler para cuando la app está en background/terminated
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Crear el canal de notificaciones en Android (requerido desde Android 8)
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Inicializar flutter_local_notifications para mostrar notifs en foreground
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false, // pedimos permiso separado en requestPermission()
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // El usuario tocó la notificación local (foreground)
        // TODO: parsear details.payload y navegar si hace falta
      },
    );

    // En iOS: deshabilitar la presentación automática en foreground
    // (la manejamos nosotros con flutter_local_notifications)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    // Listener de notificaciones en FOREGROUND (app abierta)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Listener cuando el usuario toca la notificación desde BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Verificar si la app se abrió desde una notificación (TERMINATED)
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleNotificationTap(initial);

    // Obtener el FCM token
    await _refreshToken();

    // Escuchar actualizaciones del token (cuando Firebase lo rota)
    _messaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      onTokenRefresh?.call(token);
    });
  }

  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
             settings.authorizationStatus == AuthorizationStatus.provisional;
    }
    // Android 13+: el permiso POST_NOTIFICATIONS. Antes esta función
    // devolvía `true` sin pedir nada, asumiendo que se mostraba solo "al
    // primer mensaje" — en la práctica nunca se pedía de verdad, así que
    // el banner de "notificaciones desactivadas" seguía apareciendo aunque
    // el usuario tocara "Activar" (el único permiso que sí se pedía a
    // continuación era el de batería, uno distinto). Se pide explícito acá,
    // igual que ya se hace con `Permission.ignoreBatteryOptimizations`.
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  Future<void> _refreshToken() async {
    try {
      _fcmToken = await _messaging.getToken();
    } catch (_) {
      // Sin Google Play Services (emuladores sin GMS) — ignorar
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Flag de refresh: refresca la pantalla en tiempo real (ej. home padre)
    // SIN interrumpir el flujo. Después seguimos y mostramos la notificación
    // visible normalmente (igual que WhatsApp: notifica Y actualiza).
    if (message.data['refresh'] == 'true') {
      // Copia de la lista: un listener podría des-suscribirse a sí mismo
      // durante la iteración (ej. un dispose que corre en el mismo tick).
      for (final listener in List.of(_dataRefreshListeners)) {
        listener(message.data);
      }
    }

    final notif = message.notification;
    if (notif == null) return;

    // Agrupar notificaciones del mismo tipo (asistencia/fotos) en una pila,
    // igual que WhatsApp agrupa los mensajes de un mismo chat.
    final groupKey = message.data['groupKey'] ?? 'kolexa_default';
    final groupSummary = message.data['groupSummary'] ?? 'Novedades de Kolexa';

    // Mostrar la notificación como banner heads-up mientras la app está abierta
    _localNotifications.show(
      notif.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
          enableLights: true,
          ledColor: const Color(0xFF6C63FF),
          ledOnMs: 1000,
          ledOffMs: 500,
          playSound: true,
          // Agrupamiento estilo WhatsApp: varias notifs del mismo grupo
          // se apilan en una sola entrada expandible.
          groupKey: groupKey,
          setAsGroupSummary: false,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: message.data['screen'],
    );

    // Mostrar la notificación resumen del grupo (la que aparece al expandir
    // la pila), solo si aún no existe una para este grupo.
    _maybeShowGroupSummary(groupKey, groupSummary);
  }

  // Muestra la notificación "resumen" del grupo (estilo WhatsApp) que
  // aparece como cabecera al expandir la pila de notificaciones.
  Future<void> _maybeShowGroupSummary(String groupKey, String summary) async {
    await _localNotifications.show(
      groupKey.hashCode,
      'Kolexa',
      summary,
      NotificationDetails(
        android: AndroidNotificationDetails(
          '${_channel.id}_group',
          'Novedades agrupadas',
          channelDescription: 'Resumen de notificaciones agrupadas',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
          groupKey: groupKey,
          setAsGroupSummary: true,
        ),
      ),
      payload: 'group',
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    if (message.data.isNotEmpty) {
      onNotificationTap?.call(message.data);
    }
  }

  // ── Verificación de permisos (nivel WhatsApp) ─────────────
  // Devuelve true si las notificaciones están habilitadas en el sistema.
  // En Android 13+ verifica POST_NOTIFICATIONS; en versiones anteriores
  // y en iOS usa el estado reportado por el sistema.
  Future<bool> checkNotificationPermission() async {
    if (Platform.isIOS) {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }
    // Android 13+ (API 33): permiso POST_NOTIFICATIONS
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  // Abre la pantalla de Ajustes de notificaciones de Kolexa en el sistema.
  // Equivalente al botón "Abrir ajustes" que WhatsApp muestra en su banner
  // de "notificaciones desactivadas".
  Future<void> openNotificationSettings() async {
    await openAppSettings();
  }
}
