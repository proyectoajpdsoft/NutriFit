import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/screens/home_screen.dart';
import 'package:nutri_app/screens/login_screen.dart';
import 'package:nutri_app/screens/register_screen.dart';
import 'package:nutri_app/screens/paciente_home_screen.dart';
import 'package:nutri_app/screens/splash_screen.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/screens/debug_screen.dart';
import 'package:nutri_app/screens/config_screen.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/screens/dashboard_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/screens/consejos_list_screen.dart';
import 'package:nutri_app/screens/consejo_edit_screen.dart';
import 'package:nutri_app/screens/consejos_paciente_screen.dart';
import 'package:nutri_app/screens/recetas_paciente_screen.dart';
import 'package:nutri_app/screens/recetas_list_screen.dart';
import 'package:nutri_app/screens/receta_edit_screen.dart';
import 'package:nutri_app/screens/sustitucion_saludable_edit_screen.dart';
import 'package:nutri_app/screens/sustituciones_saludables_list_screen.dart';
import 'package:nutri_app/screens/sustituciones_saludables_screen.dart';
import 'package:nutri_app/screens/charlas_seminarios_screen.dart';
import 'package:nutri_app/screens/charlas_seminarios_list_screen.dart';
import 'package:nutri_app/screens/suplementos_list_screen.dart';
import 'package:nutri_app/screens/suplemento_edit_screen.dart';
import 'package:nutri_app/screens/suplementos_paciente_screen.dart';
import 'package:nutri_app/screens/aditivos_list_screen.dart';
import 'package:nutri_app/screens/aditivo_edit_screen.dart';
import 'package:nutri_app/screens/aditivos_paciente_screen.dart';
import 'package:nutri_app/screens/lista_compra_screen.dart';
import 'package:nutri_app/screens/entrenamientos_screen.dart';
import 'package:nutri_app/screens/todo_list_screen.dart';
import 'package:nutri_app/screens/etiqueta_nutricional_scanner_screen.dart';
import 'package:nutri_app/screens/user_settings_screen.dart';
import 'package:nutri_app/screens/videos_ejercicios/videos_ejercicios_paciente_screen.dart';
import 'package:nutri_app/screens/videos_ejercicios/videos_ejercicios_list_screen.dart';
import 'package:nutri_app/screens/premium_info_screen.dart';
import 'package:nutri_app/services/app_version_service.dart';
import 'package:nutri_app/services/ads_service.dart';
import 'package:nutri_app/services/auth_error_handler.dart';
import 'package:nutri_app/constants/app_constants.dart';
import 'package:nutri_app/widgets/premium_ad_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

const _windowWidthKey = 'window_width';
const _windowHeightKey = 'window_height';
const _windowXKey = 'window_x';
const _windowYKey = 'window_y';
const _windowMaximizedKey = 'window_maximized';
const _lastSeenAppVersionKey = 'last_seen_app_version_key';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (_) {
    // Si Firebase no estÃ¡ configurado todavÃ­a en el entorno local,
    // no bloqueamos el arranque de la app.
  }
  await _initWindowManager();
  runApp(const AppState());
}

Future<void> _initWindowManager() async {
  if (!Platform.isWindows) {
    return;
  }

  await windowManager.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final width = prefs.getDouble(_windowWidthKey);
  final height = prefs.getDouble(_windowHeightKey);
  final x = prefs.getDouble(_windowXKey);
  final y = prefs.getDouble(_windowYKey);
  final wasMaximized = prefs.getBool(_windowMaximizedKey) ?? false;

  final options = WindowOptions(
    size: (width != null && height != null) ? Size(width, height) : null,
    center: width == null || height == null,
    title: AppConstants.appTitle,
  );

  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
    if (x != null && y != null) {
      await windowManager.setPosition(Offset(x, y));
    }
    if (wasMaximized) {
      await windowManager.maximize();
    }
  });

  windowManager.addListener(WindowStateHandler(prefs));
}

class AppState extends StatelessWidget {
  const AppState({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => AdsService()),
        ChangeNotifierProvider(
          create: (_) => ConfigService(),
        ), // <-- SERVICIO AÃ‘ADIDO
        Provider(
          create: (_) => ApiService(),
        ), // <-- SERVICIO AÃ‘ADIDO para ApiService
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        context.read<AuthService>().refreshCurrentUserSnapshot(force: true),
      );
      unawaited(context.read<AdsService>().ensureInitialized());
      unawaited(_showUpdateNoticeIfNeeded());
    });
  }

  Future<void> _showUpdateNoticeIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final currentVersionKey = await AppVersionService.getVersionKey();
    final currentVersionLabel = await AppVersionService.getVersionLabel();
    final previousVersionKey = prefs.getString(_lastSeenAppVersionKey);

    await prefs.setString(_lastSeenAppVersionKey, currentVersionKey);

    if (!mounted ||
        previousVersionKey == null ||
        previousVersionKey == currentVersionKey) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    final routeContext = AuthErrorHandler.navigatorKey.currentContext;
    if (routeContext == null) {
      return;
    }

    final l10n = AppLocalizations.of(routeContext);
    final messenger = ScaffoldMessenger.maybeOf(routeContext);
    if (l10n == null || messenger == null) {
      return;
    }

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          content: Text(l10n.appUpdatedNotice(currentVersionLabel)),
          action: SnackBarAction(
            label: l10n.commonClose,
            onPressed: messenger.hideCurrentSnackBar,
          ),
        ),
      );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(
        context.read<AuthService>().refreshCurrentUserSnapshot(force: true),
      );
      unawaited(context.read<AdsService>().refreshConfig());
    }
  }

  bool get _isMobileTitlePlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final mobileTitle = _isMobileTitlePlatform;
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.pink);
    final configService = context.watch<ConfigService>();

    return MaterialApp(
      title: AppConstants.appTitle,
      navigatorKey: AuthErrorHandler.navigatorKey,
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(
        colorScheme: colorScheme,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          foregroundColor: colorScheme.onSurface,
          titleTextStyle: TextStyle(
            fontSize: mobileTitle ? 17 : 20,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          toolbarTextStyle: TextStyle(
            fontSize: mobileTitle ? 14 : 16,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        useMaterial3: true,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: configService.appLocale,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) {
          return const Locale('es');
        }

        for (final supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale.languageCode) {
            return supportedLocale;
          }
        }

        return const Locale('es');
      },
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return PremiumAdShell(child: child ?? const SizedBox.shrink());
      },
      initialRoute: 'splash',
      routes: {
        'splash': (_) => const SplashScreen(),
        'login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        'home': (_) => const HomeScreen(),
        'paciente_home': (_) => const PacienteHomeScreen(),
        'debug': (_) => const DebugScreen(),
        'config': (_) => const ConfigScreen(),
        'dashboard': (_) => const DashboardScreen(),
        '/consejos_list': (_) => const ConsejosListScreen(),
        '/consejo_edit': (_) => const ConsejoEditScreen(),
        '/consejos_paciente': (_) => const ConsejosPacienteScreen(),
        '/recetas_paciente': (_) => const RecetasPacienteScreen(),
        '/recetas_list': (_) => const RecetasListScreen(),
        '/receta_edit': (_) => const RecetaEditScreen(),
        '/sustituciones_saludables': (_) =>
            const SustitucionesSaludablesScreen(),
        '/sustituciones_saludables_list': (_) =>
            const SustitucionesSaludablesListScreen(),
        '/sustitucion_saludable_edit': (_) =>
            const SustitucionSaludableEditScreen(),
        '/lista_compra': (_) => const ListaCompraScreen(),
        '/entrenamientos': (_) => const EntrenamientosScreen(),
        '/todo_list': (_) => const TodoListScreen(),
        '/scanner_etiquetas': (_) => const EtiquetaNutricionalScannerScreen(),
        '/user_settings': (_) => const UserSettingsScreen(),
        '/videos_ejercicios': (_) => const VideosEjerciciosPacienteScreen(),
        '/videos_ejercicios_admin': (_) => const VideosEjerciciosListScreen(),
        '/charlas_seminarios': (_) => const CharlasSeminariosScreen(),
        '/charlas_seminarios_list': (_) => const CharlasSeminariosListScreen(),
        '/suplementos': (_) => const SuplementosPacienteScreen(),
        '/suplementos_list': (_) => const SuplementosListScreen(),
        '/suplemento_edit': (_) => const SuplementoEditScreen(),
        '/aditivos': (_) => const AditivosPacienteScreen(),
        '/aditivos_list': (_) => const AditivosListScreen(),
        '/aditivo_edit': (_) => const AditivoEditScreen(),
        '/premium_info': (_) => const PremiumInfoScreen(),
      },
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}

class WindowStateHandler extends WindowListener {
  WindowStateHandler(this._prefs);

  final SharedPreferences _prefs;
  Timer? _saveTimer;

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), _saveNow);
  }

  Future<void> _saveNow() async {
    if (!Platform.isWindows) {
      return;
    }

    final isMaximized = await windowManager.isMaximized();
    await _prefs.setBool(_windowMaximizedKey, isMaximized);
    if (isMaximized) {
      return;
    }

    final size = await windowManager.getSize();
    final position = await windowManager.getPosition();
    await _prefs.setDouble(_windowWidthKey, size.width);
    await _prefs.setDouble(_windowHeightKey, size.height);
    await _prefs.setDouble(_windowXKey, position.dx);
    await _prefs.setDouble(_windowYKey, position.dy);
  }

  @override
  void onWindowResized() {
    _scheduleSave();
  }

  @override
  void onWindowMoved() {
    _scheduleSave();
  }

  @override
  void onWindowClose() {
    _saveNow();
  }
}
