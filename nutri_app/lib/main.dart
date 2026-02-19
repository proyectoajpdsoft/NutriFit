import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'package:nutri_app/screens/lista_compra_screen.dart';
import 'package:nutri_app/screens/entrenamientos_screen.dart';
import 'package:nutri_app/services/auth_error_handler.dart';
import 'package:nutri_app/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

const _windowWidthKey = 'window_width';
const _windowHeightKey = 'window_height';
const _windowXKey = 'window_x';
const _windowYKey = 'window_y';
const _windowMaximizedKey = 'window_maximized';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        ChangeNotifierProvider(
            create: (_) => ConfigService()), // <-- SERVICIO AÑADIDO
        Provider(
            create: (_) =>
                ApiService()), // <-- SERVICIO AÑADIDO para ApiService
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appTitle,
      navigatorKey: AuthErrorHandler.navigatorKey,
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      locale: const Locale('es', 'ES'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      debugShowCheckedModeBanner: false,
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
        '/lista_compra': (_) => const ListaCompraScreen(),
        '/entrenamientos': (_) => const EntrenamientosScreen(),
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
