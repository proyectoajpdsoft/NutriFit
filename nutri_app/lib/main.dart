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

void main() {
  runApp(const AppState());
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
