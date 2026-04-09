import 'dart:io';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nutri_app/exceptions/auth_exceptions.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/nutri_push_settings_service.dart';
import 'package:nutri_app/services/user_settings_service.dart';
import 'package:local_notifier/local_notifier.dart';

class PushNotificationsService {
  PushNotificationsService._();

  static final PushNotificationsService instance = PushNotificationsService._();
  static const String _androidChatChannelId = 'nutrifit_chat_messages';
  static const String _androidChatChannelName = 'Mensajes de chat';
  static const String _androidChatChannelDescription =
      'Notificaciones de mensajes nuevos de chat';
  static const Duration _desktopPollInterval = Duration(seconds: 30);

  bool _initialized = false;
  bool _desktopNotifierInitialized = false;
  Timer? _desktopPollTimer;
  int? _lastDesktopUnreadCount;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> _initMobileLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChatChannelId,
        _androidChatChannelName,
        description: _androidChatChannelDescription,
        importance: Importance.high,
      ),
    );
  }

  Future<void> _showForegroundChatNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title?.trim();
    final body = notification?.body?.trim();

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    await _localNotifications.show(
      message.hashCode,
      title?.isNotEmpty == true ? title : 'Nuevo mensaje',
      body?.isNotEmpty == true ? body : 'Tienes un nuevo mensaje de chat',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChatChannelId,
          _androidChatChannelName,
          channelDescription: _androidChatChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
    );
  }

  bool _isNutri(AuthService authService) {
    return authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';
  }

  String _scope(AuthService authService) {
    return UserSettingsService.buildScopeKey(
      isGuestMode: authService.isGuestMode,
      userCode: authService.userCode,
      patientCode: authService.patientCode,
      userType: authService.userType,
    );
  }

  String _platformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  bool _supportsFirebasePush() {
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  bool _supportsDesktopNativeNotifications() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  Future<bool> _getChatUnreadPushEnabled(
    AuthService authService,
    String scope,
  ) async {
    if (_isNutri(authService)) {
      return NutriPushSettingsService.getChatUnreadPushEnabled(scope);
    }
    return UserSettingsService.getChatUnreadPushEnabled(scope);
  }

  Future<void> _ensureDesktopNotifierInitialized() async {
    if (_desktopNotifierInitialized || !_supportsDesktopNativeNotifications()) {
      return;
    }

    await localNotifier.setup(
      appName: 'NutriFit',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );
    _desktopNotifierInitialized = true;
  }

  Future<void> _showDesktopNativeNotification({
    required String title,
    required String body,
  }) async {
    await _ensureDesktopNotifierInitialized();
    final notification = LocalNotification(
      title: title,
      body: body,
    );
    await notification.show();
  }

  void _startDesktopPolling({
    required AuthService authService,
    required ApiService apiService,
    required String scope,
  }) {
    _desktopPollTimer?.cancel();

    Future<void> pollOnce() async {
      try {
        if (!authService.isLoggedIn ||
            (authService.userCode ?? '').trim().isEmpty) {
          _lastDesktopUnreadCount = null;
          return;
        }

        if (authService.isGuestMode) {
          _lastDesktopUnreadCount = null;
          return;
        }

        final enabled = await _getChatUnreadPushEnabled(authService, scope);
        if (!enabled) {
          _lastDesktopUnreadCount = null;
          return;
        }

        final unread = await apiService.getChatUnreadCount();
        if (_lastDesktopUnreadCount != null &&
            unread > _lastDesktopUnreadCount!) {
          final diff = unread - _lastDesktopUnreadCount!;
          await _showDesktopNativeNotification(
            title: 'Nuevos mensajes de chat',
            body: diff == 1
                ? 'Tienes 1 mensaje nuevo sin leer.'
                : 'Tienes $diff mensajes nuevos sin leer.',
          );
        }
        _lastDesktopUnreadCount = unread;
      } on TokenExpiredException {
        clearUserSessionState();
      } on UnauthorizedException {
        clearUserSessionState();
      } catch (_) {
        // Polling silencioso: no lanzar errores no controlados en tareas unawaited.
      }
    }

    unawaited(pollOnce());
    _desktopPollTimer = Timer.periodic(_desktopPollInterval, (_) {
      unawaited(pollOnce());
    });
  }

  Future<void> initForCurrentUser({
    required AuthService authService,
    required ApiService apiService,
  }) async {
    if (authService.isGuestMode) {
      return;
    }

    final userCode = (authService.userCode ?? '').trim();
    if (userCode.isEmpty) {
      return;
    }

    final scope = _scope(authService);
    final chatUnreadEnabled =
        await _getChatUnreadPushEnabled(authService, scope);
    final platform = _platformName();

    try {
      if (!_initialized) {
        if (_supportsFirebasePush()) {
          try {
            Firebase.app();
          } catch (_) {
            await Firebase.initializeApp();
          }

          await _initMobileLocalNotifications();

          await FirebaseMessaging.instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );

          FirebaseMessaging.onMessage.listen((message) async {
            final messageType = (message.data['type'] ?? '').toString();
            final latestChatUnreadEnabled =
                await _getChatUnreadPushEnabled(authService, scope);
            if (!latestChatUnreadEnabled || messageType != 'chat_unread') {
              return;
            }
            await _showForegroundChatNotification(message);
          });

          FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
            final trimmed = token.trim();
            if (trimmed.isEmpty) return;
            try {
              await apiService.registerPushDeviceToken(
                token: trimmed,
                platform: platform,
                chatUnreadEnabled: chatUnreadEnabled,
              );
            } catch (_) {}
          });
        }

        if (!_supportsFirebasePush() && _supportsDesktopNativeNotifications()) {
          _startDesktopPolling(
            authService: authService,
            apiService: apiService,
            scope: scope,
          );
        }

        _initialized = true;
      }

      if (!_supportsFirebasePush() &&
          _supportsDesktopNativeNotifications() &&
          _desktopPollTimer == null) {
        _startDesktopPolling(
          authService: authService,
          apiService: apiService,
          scope: scope,
        );
      }

      if (_supportsFirebasePush()) {
        final token = await FirebaseMessaging.instance.getToken();
        final trimmed = token?.trim() ?? '';
        if (trimmed.isNotEmpty) {
          await apiService.registerPushDeviceToken(
            token: trimmed,
            platform: platform,
            chatUnreadEnabled: chatUnreadEnabled,
          );
        }
      }

      await apiService.setChatUnreadPushEnabled(
        enabled: chatUnreadEnabled,
      );
    } catch (_) {
      // Mantener la app operativa aunque falle push en alguna plataforma.
    }
  }

  Future<void> initForCurrentNutriUser({
    required AuthService authService,
    required ApiService apiService,
  }) async {
    await initForCurrentUser(authService: authService, apiService: apiService);
  }

  void clearUserSessionState() {
    _desktopPollTimer?.cancel();
    _desktopPollTimer = null;
    _lastDesktopUnreadCount = null;
  }
}
