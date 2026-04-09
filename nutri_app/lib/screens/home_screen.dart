import 'package:flutter/material.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
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
import 'package:nutri_app/services/menu_visibility_premium_service.dart';
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
  bool _entryOverlaysHandled = false;
  Map<String, MenuEntryConfig> _menuConfig =
      MenuVisibilityPremiumService.defaultConfig();

  @override
  void initState() {
    super.initState();
    _verifyUserAndLoad();
    _loadMenuConfig();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleEntryOverlays();
    });
  }

  Future<void> _loadMenuConfig() async {
    try {
      final config = await MenuVisibilityPremiumService.loadConfig(
        apiService: context.read<ApiService>(),
        forceRefresh: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _menuConfig = config;
      });
    } catch (_) {}
  }

  bool _isMenuEntryPremium(String key) {
    return MenuVisibilityPremiumService.isPremium(_menuConfig, key);
  }

  bool _isMenuEntryVisible(String key) {
    return MenuVisibilityPremiumService.isVisible(_menuConfig, key);
  }

  int _dashboardCrossAxisCount(double width) {
    if (width >= 1600) return 6;
    if (width >= 1100) return 5;
    if (width >= 800) return 4;
    return 3;
  }

  double _dashboardChildAspectRatio(double width) {
    if (width >= 1600) return 1.18;
    if (width >= 1100) return 1.12;
    if (width >= 800) return 1.05;
    return 1.1;
  }

  Future<void> _handleEntryOverlays() async {
    if (!mounted || _entryOverlaysHandled) return;
    _entryOverlaysHandled = true;

    await _checkAndShowPremiumPaymentConfirmation();
    if (!mounted) return;

    _checkAndShowTwoFactorRecommendation();
    _checkAndShowPremiumExpiryWarning();
  }

  Future<void> _checkAndShowPremiumPaymentConfirmation() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map<String, dynamic>) return;
    if (args[premiumPaymentConfirmationArgumentKey] != true) return;
    final l10n = AppLocalizations.of(context)!;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
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
                      Icons.verified_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.homePaymentNotifiedTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.homePaymentNotifiedMessage,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(l10n.commonAgree),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    final l10n = AppLocalizations.of(context)!;

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
                            ? l10n.homePremiumExpiredTitle
                            : l10n.homePremiumExpiringTitle,
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
                      ? l10n.homePremiumExpiredMessage(formattedExpiry)
                      : days == 0
                          ? l10n.homePremiumExpiringTodayMessage(
                              formattedExpiry,
                            )
                          : l10n.homePremiumExpiringInDaysMessage(
                              formattedExpiry,
                              days,
                            ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(l10n.commonLater),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.pushNamed(context, '/premium_info');
                      },
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: Text(l10n.homeRenewPremium),
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
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                l10n.navPremiumPreview,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(l10n.navPreviewRegisteredUser),
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
              title: Text(l10n.navPreviewGuestUser),
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
    final l10n = AppLocalizations.of(context)!;

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
                    Expanded(
                      child: Text(
                        l10n.homeSecurityRecommendedTitle,
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
                Text(
                  l10n.homeSecurityRecommendedBody,
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
                      label: Text(l10n.homeGoToEditProfile),
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
                      child: Text(l10n.homeDoNotShowAgain),
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
    final l10n = AppLocalizations.of(context)!;
    final isDebugAppMode =
        context.watch<ConfigService>().appMode == AppMode.debug;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final crossAxisCount = _dashboardCrossAxisCount(screenWidth);
    final childAspectRatio = _dashboardChildAspectRatio(screenWidth);

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
                child: Text(
                  l10n.commonDebug,
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
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: childAspectRatio,
            children: <Widget>[
              _buildDashboardCard(
                context,
                icon: Icons.mark_chat_unread_outlined,
                label: l10n.navChat,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ChatConversationsScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.people_outline,
                label: l10n.navPatients,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PacientesListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.calendar_today_outlined,
                label: l10n.navAppointments,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CitasListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.rate_review_outlined,
                label: l10n.navReviews,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const RevisionesPacientesListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.show_chart_outlined,
                label: l10n.navMeasurements,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const MedicionesPacientesListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.assignment_outlined,
                label: l10n.navNutriInterviews,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const EntrevistasPacientesListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.article_outlined,
                label: l10n.navNutriPlans,
                showPremiumBadge: _isMenuEntryPremium(
                  MenuVisibilityPremiumService.planesNutri,
                ),
                showHiddenBadge: !_isMenuEntryVisible(
                  MenuVisibilityPremiumService.planesNutri,
                ),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const PlanesPacientesListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.sports_gymnastics_outlined,
                label: l10n.navFitInterviews,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const EntrevistasFitPacientesListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.fitness_center_outlined,
                label: l10n.navFitPlans,
                showPremiumBadge: _isMenuEntryPremium(
                  MenuVisibilityPremiumService.planesFit,
                ),
                showHiddenBadge: !_isMenuEntryVisible(
                  MenuVisibilityPremiumService.planesFit,
                ),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const PlanesFitPacientesListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.set_meal_outlined,
                label: l10n.navFoods,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AlimentosScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.medication_outlined,
                label: l10n.navSupplements,
                showPremiumBadge: _isMenuEntryPremium(
                  MenuVisibilityPremiumService.suplementos,
                ),
                showHiddenBadge: !_isMenuEntryVisible(
                  MenuVisibilityPremiumService.suplementos,
                ),
                onTap: () => Navigator.pushNamed(context, '/suplementos_list'),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.science_outlined,
                label: l10n.navAdditives,
                showPremiumBadge: _isMenuEntryPremium(
                  MenuVisibilityPremiumService.aditivosAlimentarios,
                ),
                showHiddenBadge: !_isMenuEntryVisible(
                  MenuVisibilityPremiumService.aditivosAlimentarios,
                ),
                onTap: () => Navigator.pushNamed(context, '/aditivos_list'),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.sports_mma,
                label: l10n.navExercises,
                showPremiumBadge: _isMenuEntryPremium(
                  MenuVisibilityPremiumService.catalogoEjercicios,
                ),
                showHiddenBadge: !_isMenuEntryVisible(
                  MenuVisibilityPremiumService.catalogoEjercicios,
                ),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const PlanFitEjerciciosCatalogScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.play_circle_outline,
                label: l10n.navExerciseVideos,
                showPremiumBadge: _isMenuEntryPremium(
                  MenuVisibilityPremiumService.videosEjercicios,
                ),
                showHiddenBadge: !_isMenuEntryVisible(
                  MenuVisibilityPremiumService.videosEjercicios,
                ),
                onTap: () =>
                    Navigator.pushNamed(context, '/videos_ejercicios_admin'),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.swap_horiz_rounded,
                label: l10n.navSubstitutions,
                showPremiumBadge: _isMenuEntryPremium(
                  MenuVisibilityPremiumService.sustitucionesSaludables,
                ),
                showHiddenBadge: !_isMenuEntryVisible(
                  MenuVisibilityPremiumService.sustitucionesSaludables,
                ),
                onTap: () => Navigator.pushNamed(
                    context, '/sustituciones_saludables_list'),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.record_voice_over_outlined,
                label: l10n.navTalks,
                showPremiumBadge: _isMenuEntryPremium(
                  MenuVisibilityPremiumService.charlasSeminarios,
                ),
                showHiddenBadge: !_isMenuEntryVisible(
                  MenuVisibilityPremiumService.charlasSeminarios,
                ),
                onTap: () =>
                    Navigator.pushNamed(context, '/charlas_seminarios_list'),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.workspace_premium_outlined,
                label: l10n.navPremium,
                onTap: _openPremiumPreviewMenu,
              ),
              _buildDashboardCard(
                context,
                icon: Icons.directions_run,
                label: l10n.navActivities,
                showPremiumBadge: _isMenuEntryPremium(
                  MenuVisibilityPremiumService.actividades,
                ),
                showHiddenBadge: !_isMenuEntryVisible(
                  MenuVisibilityPremiumService.actividades,
                ),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const EntrenamientosScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.dashboard_outlined,
                label: l10n.navDashboard,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DashboardScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.payment_outlined,
                label: l10n.navCharges,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CobrosListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.business_center_outlined,
                label: l10n.navClients,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ClientesListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.lightbulb_outlined,
                label: l10n.navTips,
                showPremiumBadge: _isMenuEntryPremium(
                  MenuVisibilityPremiumService.consejos,
                ),
                showHiddenBadge: !_isMenuEntryVisible(
                  MenuVisibilityPremiumService.consejos,
                ),
                onTap: () => Navigator.pushNamed(context, '/consejos_list'),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.restaurant_menu_outlined,
                label: l10n.navRecipes,
                showPremiumBadge: _isMenuEntryPremium(
                  MenuVisibilityPremiumService.recetas,
                ),
                showHiddenBadge: !_isMenuEntryVisible(
                  MenuVisibilityPremiumService.recetas,
                ),
                onTap: () => Navigator.pushNamed(context, '/recetas_list'),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.document_scanner_outlined,
                label: l10n.navScanner,
                showPremiumBadge: _isMenuEntryPremium(
                  MenuVisibilityPremiumService.escaner,
                ),
                showHiddenBadge: !_isMenuEntryVisible(
                  MenuVisibilityPremiumService.escaner,
                ),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const EtiquetaNutricionalScannerScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.settings_outlined,
                label: l10n.settingsAndPrivacyTitle,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ConfigScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.manage_accounts_outlined,
                label: l10n.navUsers,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const UsuariosListScreen())),
              ),
              _buildDashboardCard(
                context,
                icon: Icons.checklist_outlined,
                label: l10n.navTasks,
                showPremiumBadge: _isMenuEntryPremium(
                  MenuVisibilityPremiumService.tareas,
                ),
                showHiddenBadge: !_isMenuEntryVisible(
                  MenuVisibilityPremiumService.tareas,
                ),
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
      bool showPremiumBadge = false,
      bool showHiddenBadge = false}) {
    final compact = MediaQuery.sizeOf(context).width >= 800;
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
                Icon(
                  icon,
                  size: compact ? 22 : 26,
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(height: compact ? 4 : 2),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: compact ? 11 : 12),
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
            if (showHiddenBadge)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Icon(
                    Icons.visibility_off_outlined,
                    size: 12,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
