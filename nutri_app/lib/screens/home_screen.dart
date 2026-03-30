import 'package:flutter/material.dart';
import 'package:nutri_app/screens/citas/citas_list_screen.dart';
import 'package:nutri_app/screens/clientes/clientes_list_screen.dart';
import 'package:nutri_app/screens/cobros/cobros_list_screen.dart';
import 'package:nutri_app/screens/chat_conversations_screen.dart';
import 'package:nutri_app/screens/config_screen.dart';
import 'package:nutri_app/screens/dashboard_screen.dart';
import 'package:nutri_app/screens/etiqueta_nutricional_scanner_screen.dart';
import 'package:nutri_app/screens/entrevistas/entrevistas_pacientes_list_screen.dart';
import 'package:nutri_app/screens/entrevistas_fit/entrevistas_fit_pacientes_list_screen.dart';
import 'package:nutri_app/screens/mediciones/mediciones_pacientes_list_screen.dart';
import 'package:nutri_app/screens/notifications_screen.dart';
import 'package:nutri_app/screens/messages_inbox_screen.dart';
import 'package:nutri_app/screens/pacientes/pacientes_list_screen.dart';
import 'package:nutri_app/screens/planes_nutricionales/planes_pacientes_list_screen.dart';
import 'package:nutri_app/screens/planes_fit/planes_fit_pacientes_list_screen.dart';
import 'package:nutri_app/screens/planes_fit/plan_fit_ejercicios_catalog_screen.dart';
import 'package:nutri_app/screens/alimentos/alimentos_screen.dart';
import 'package:nutri_app/screens/revisiones/revisiones_pacientes_list_screen.dart';
import 'package:nutri_app/screens/usuarios/usuarios_list_screen.dart';
import 'package:nutri_app/screens/entrenamientos_screen.dart';
import 'package:nutri_app/screens/paciente_profile_edit_screen.dart';
import 'package:nutri_app/screens/premium_info_screen.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/services/push_notifications_service.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:nutri_app/mixins/auth_error_handler_mixin.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:url_launcher/url_launcher.dart' as url_launcher;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AuthErrorHandlerMixin {
  int _pendingCount = 0;
  int _sensacionesPendientes = 0;
  int _chatNoLeidos = 0;
  bool _isLoading = true;
  bool _isAuthorized = true;
  bool _twoFactorPromptShownInSession = false;
  bool _premiumWarningShownInSession = false;

  @override
  void initState() {
    super.initState();
    _verifyUserAndLoad();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTwoFactorRecommendation();
      _checkAndShowPremiumExpiryWarning();
    });
  }

  String _premiumWarningShownKey(String userCode, String dayKey) {
    return 'premium_warning_shown_${userCode}_$dayKey';
  }

  Future<void> _checkAndShowPremiumExpiryWarning() async {
    if (!mounted || _premiumWarningShownInSession) return;

    final authService = context.read<AuthService>();
    final type = (authService.userType ?? '').toLowerCase();
    if (type == 'nutricionista' || type == 'administrador' || type == 'guest') {
      return;
    }

    final expiry = authService.premiumExpiryDate;
    final days = authService.premiumDaysUntilExpiry;
    final userCode = (authService.userCode ?? '').trim();
    if (expiry == null || days == null || userCode.isEmpty) return;

    int warningDays = 7;
    try {
      final raw = await context
          .read<ApiService>()
          .getParametroValor('premium_dias_aviso_vencimiento');
      final parsed = int.tryParse((raw ?? '').trim());
      if (parsed != null && parsed > 0 && parsed <= 90) {
        warningDays = parsed;
      }
    } catch (_) {}

    if (days > warningDays) return;

    final today = DateTime.now();
    final dayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_premiumWarningShownKey(userCode, dayKey)) == true) {
      return;
    }

    _premiumWarningShownInSession = true;
    final formattedExpiry =
        '${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}';
    final isExpired = days < 0;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isExpired
                            ? 'Tu Premium ha caducado'
                            : 'Tu Premium está próximo a caducar',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isExpired
                      ? 'Tu Premium caducó el $formattedExpiry. Puedes renovarlo ahora.'
                      : 'Tu Premium vence el $formattedExpiry (${days == 0 ? 'hoy' : 'en $days día${days == 1 ? '' : 's'}'}). Te recomendamos renovarlo para no perder ventajas.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Más tarde'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.pushNamed(context, '/premium_info');
                      },
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: const Text('Renovar Premium'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    await prefs.setBool(_premiumWarningShownKey(userCode, dayKey), true);
  }

  String _twoFactorPromptDismissedKey(String userCode) {
    return 'two_factor_prompt_dismissed_$userCode';
  }

  Future<void> _openProfileEditor() async {
    final authService = context.read<AuthService>();
    if (authService.userCode == null || authService.userCode!.isEmpty) {
      return;
    }

    final usuario = Usuario(
      codigo: int.parse(authService.userCode ?? '0'),
      nick: '',
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PacienteProfileEditScreen(usuario: usuario),
      ),
    );
  }

  Future<void> _openPremiumPreviewMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Hazte Premium (vista previa)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Ver como usuario registrado'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PremiumInfoScreen(
                      previewMode: PremiumPreviewMode.registered,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: const Text('Ver como usuario no registrado'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PremiumInfoScreen(
                      previewMode: PremiumPreviewMode.guest,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkAndShowTwoFactorRecommendation() async {
    if (!mounted || _twoFactorPromptShownInSession) return;

    final authService = context.read<AuthService>();
    if (authService.userType != 'Nutricionista') return;

    final userCode = (authService.userCode ?? '').trim();
    if (userCode.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_twoFactorPromptDismissedKey(userCode)) == true) {
      return;
    }

    bool enabled = false;
    try {
      final status = await context.read<ApiService>().getTwoFactorStatus();
      enabled = status['enabled'] == true;
    } catch (_) {
      return;
    }

    if (!mounted || enabled) return;

    _twoFactorPromptShownInSession = true;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Seguridad recomendada',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Trabajas con datos médicos sensibles. Te recomendamos activar el doble factor (2FA) para proteger mejor tu cuenta.',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _openProfileEditor();
                      },
                      icon: const Icon(Icons.person_outline, size: 18),
                      label: const Text('Ir a editar perfil'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await prefs.setBool(
                          _twoFactorPromptDismissedKey(userCode),
                          true,
                        );
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                      child: const Text('No volver a mostrar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _verifyUserAndLoad() async {
    final authService = context.read<AuthService>();
    final apiService = context.read<ApiService>();

    // Verificar que el usuario sea administrador (Nutricionista)
    if (authService.userType != 'Nutricionista') {
      setState(() {
        _isAuthorized = false;
        _isLoading = false;
      });
      // Redirigir al usuario a su pantalla correcta
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('paciente_home');
      }
      return;
    }

    await PushNotificationsService.instance.initForCurrentUser(
      authService: authService,
      apiService: apiService,
    );

    await _loadPendingCounts();
  }

  Future<void> _loadPendingCounts() async {
    try {
      final apiService = context.read<ApiService>();

      // Obtener citas pendientes con el mismo criterio de NotificationsPendingScreen.
      final citas = await apiService.getCitas();
      final pendingCitas = citas
          .where((c) => c.estado != null && c.estado == 'Pendiente')
          .length;

      // Obtener revisiones pendientes (completada != 'S')
      final revisiones = await apiService.getRevisiones();
      final pendingRevisiones =
          revisiones.where((r) => r.completada != 'S').length;

      final sensacionesPendientes =
          await apiService.getSensacionesPendientesNutri();
      final chatNoLeidos = await apiService.getChatUnreadCount();

      if (mounted) {
        setState(() {
          _pendingCount = pendingCitas + pendingRevisiones;
          _sensacionesPendientes = sensacionesPendientes.length;
          _chatNoLeidos = chatNoLeidos;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Maneja errores de autenticación
      if (!handleAuthError(e)) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDebugAppMode =
        context.watch<ConfigService>().appMode == AppMode.debug;

    // Si el usuario no está autorizado, mostrar una pantalla de carga mientras se redirige
    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('NutriFit'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('NutriFit'),
        elevation: 4,
        toolbarHeight: 48,
        actions: [
          if (isDebugAppMode)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 8.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'DEBUG',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 4.0, top: 8.0),
              child: GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MessagesInboxScreen(),
                    ),
                  );
                  if (mounted) {
                    _loadPendingCounts();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.mark_chat_unread_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                      if ((_sensacionesPendientes + _chatNoLeidos) > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              (_sensacionesPendientes + _chatNoLeidos) > 99
                                  ? '99+'
                                  : (_sensacionesPendientes + _chatNoLeidos)
                                      .toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (_pendingCount > 0 && !_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 8.0),
              child: GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsPendingScreen(),
                    ),
                  );
                  if (mounted) {
                    _loadPendingCounts();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            _pendingCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1.1,
            children: <Widget>[
              _buildDashboardCard(
                context,
                icon: Icons.mark_chat_unread_outlined,
                label: 'Chat',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ChatConversationsScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.people_outline,
                label: 'Pacientes',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PacientesListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.calendar_today_outlined,
                label: 'Citas',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CitasListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.rate_review_outlined,
                label: 'Revisiones',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const RevisionesPacientesListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.show_chart_outlined,
                label: 'Mediciones',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const MedicionesPacientesListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.assignment_outlined,
                label: 'Entrevistas Nutri',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const EntrevistasPacientesListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.article_outlined,
                label: 'Planes Nutri',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const PlanesPacientesListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.sports_gymnastics_outlined,
                label: 'Entrevistas Fit',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const EntrevistasFitPacientesListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.fitness_center_outlined,
                label: 'Planes Fit',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const PlanesFitPacientesListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.set_meal_outlined,
                label: 'Alimentos',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AlimentosScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.medication_outlined,
                label: 'Suplementos',
                showPremiumBadge: true,
                onTap: () => Navigator.pushNamed(context, '/suplementos_list'),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.science_outlined,
                label: 'Aditivos',
                showPremiumBadge: true,
                onTap: () => Navigator.pushNamed(context, '/aditivos_list'),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.sports_mma,
                label: 'Ejercicios',
                showPremiumBadge: true,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const PlanFitEjerciciosCatalogScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.play_circle_outline,
                label: 'Vídeos Ejercicios',
                showPremiumBadge: true,
                onTap: () =>
                    Navigator.pushNamed(context, '/videos_ejercicios_admin'),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.swap_horiz_rounded,
                label: 'Sustituciones',
                showPremiumBadge: true,
                onTap: () => Navigator.pushNamed(
                    context, '/sustituciones_saludables_list'),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.record_voice_over_outlined,
                label: 'Charlas',
                showPremiumBadge: true,
                onTap: () =>
                    Navigator.pushNamed(context, '/charlas_seminarios_list'),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.workspace_premium_outlined,
                label: 'Hazte Premium',
                onTap: _openPremiumPreviewMenu,
              ),
              _buildDashboardCard(
                context,
                icon: Icons.directions_run,
                label: 'Actividades',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const EntrenamientosScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DashboardScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.payment_outlined,
                label: 'Cobros',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CobrosListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.business_center_outlined,
                label: 'Clientes',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ClientesListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.lightbulb_outlined,
                label: 'Consejos',
                onTap: () => Navigator.pushNamed(context, '/consejos_list'),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.restaurant_menu_outlined,
                label: 'Recetas',
                onTap: () => Navigator.pushNamed(context, '/recetas_list'),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.document_scanner_outlined,
                label: 'Escáner',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const EtiquetaNutricionalScannerScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.settings_outlined,
                label: 'Ajustes',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ConfigScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.manage_accounts_outlined,
                label: 'Usuarios',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const UsuariosListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.checklist_outlined,
                label: 'Tareas',
                onTap: () => Navigator.pushNamed(context, '/todo_list'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool showPremiumBadge = false}) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 26, color: Theme.of(context).primaryColor),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            if (showPremiumBadge)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    size: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
