import 'package:flutter/material.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:nutri_app/screens/citas/citas_list_screen.dart';
import 'package:nutri_app/screens/entrevistas/entrevistas_pacientes_list_screen.dart';
import 'package:nutri_app/screens/entrevistas_fit/entrevistas_fit_pacientes_list_screen.dart';
import 'package:nutri_app/screens/mediciones/mediciones_pacientes_list_screen.dart';
import 'package:nutri_app/screens/mediciones/pesos_usuario_screen.dart';
import 'package:nutri_app/screens/paciente_profile_edit_screen.dart';
import 'package:nutri_app/screens/pacientes/pacientes_list_screen.dart';
import 'package:nutri_app/screens/planes_nutricionales/planes_pacientes_list_screen.dart';
import 'package:nutri_app/screens/planes_nutricionales/planes_paciente_list_screen.dart';
import 'package:nutri_app/screens/planes_fit/planes_fit_pacientes_list_screen.dart';
import 'package:nutri_app/screens/planes_fit/planes_fit_paciente_list_screen.dart';
import 'package:nutri_app/screens/planes_fit/plan_fit_ejercicios_catalog_screen.dart';
import 'package:nutri_app/screens/alimentos/alimentos_screen.dart';
import 'package:nutri_app/screens/revisiones/revisiones_pacientes_list_screen.dart';
import 'package:nutri_app/screens/clientes/clientes_list_screen.dart';
import 'package:nutri_app/screens/cobros/cobros_list_screen.dart';
import 'package:nutri_app/screens/usuarios/usuarios_list_screen.dart';
import 'package:nutri_app/screens/contacto_nutricionista_screen.dart';
import 'package:nutri_app/screens/chat_conversations_screen.dart';
import 'package:nutri_app/screens/chat_screen.dart';
import 'package:nutri_app/screens/premium_info_screen.dart';
import 'package:nutri_app/screens/todo_list_screen.dart';
import 'package:nutri_app/screens/entrenamientos_screen.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/menu_visibility_premium_service.dart';
import 'package:nutri_app/widgets/restricted_access_dialog_helper.dart';
import 'package:nutri_app/widgets/app_version_label.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/constants/app_constants.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  static Widget? _premiumBadge(bool enabled) {
    if (!enabled) {
      return null;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.shade300,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Icon(
        Icons.workspace_premium,
        size: 13,
        color: Colors.black87,
      ),
    );
  }

  static Widget? _hiddenBadge(bool enabled) {
    if (!enabled) {
      return null;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Icon(
        Icons.visibility_off_outlined,
        size: 13,
        color: Colors.red.shade700,
      ),
    );
  }

  static Widget? _statusBadges({
    required bool premium,
    required bool hidden,
  }) {
    final badges = <Widget>[
      if (premium) _premiumBadge(true)!,
      if (hidden) _hiddenBadge(true)!,
    ];
    if (badges.isEmpty) {
      return null;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < badges.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          badges[i],
        ],
      ],
    );
  }

  static bool _isVisible(
    Map<String, MenuEntryConfig> config,
    String key,
  ) {
    return MenuVisibilityPremiumService.isVisible(config, key);
  }

  static bool _isPremium(
    Map<String, MenuEntryConfig> config,
    String key,
  ) {
    return MenuVisibilityPremiumService.isPremium(config, key);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = Provider.of<AuthService>(context, listen: false);
    final userType = authService.userType;
    final isGuestMode = authService.isGuestMode;

    // Control de seguridad: si no hay userType, mostrar solo opci├│n de logout
    if (userType == null) {
      return Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Container(
              color: Colors.purple,
              padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    AppConstants.appName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const AppVersionLabel(
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(l10n.navLogout),
              onTap: () {
                authService.logout();
                Navigator.of(context).pushReplacementNamed('login');
              },
            ),
          ],
        ),
      );
    }

    // Determinar el texto del tipo de usuario
    String userTypeLabel;
    if (isGuestMode ||
        authService.token == null ||
        authService.token!.isEmpty) {
      userTypeLabel = l10n.drawerGuestUser;
    } else if (userType == 'Nutricionista' || userType == 'Administrador') {
      userTypeLabel = l10n.drawerAdminUser;
    } else if (authService.patientCode != null &&
        authService.patientCode!.isNotEmpty) {
      userTypeLabel = authService.isPremium
          ? l10n.drawerPremiumPatientUser
          : l10n.drawerPatientUser;
    } else {
      userTypeLabel = authService.isPremium
          ? l10n.drawerPremiumRegisteredUser
          : l10n.drawerRegisteredUser;
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          Container(
            color: Colors.purple,
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const AppVersionLabel(
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userTypeLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      if (authService.isPremium) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade400,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.workspace_premium,
                                size: 14,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l10n.drawerPremiumBadge,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    final auth = context.read<AuthService>();
                    final isPacienteOrGuest = auth.isPatientAreaUser;
                    Navigator.pushReplacementNamed(
                      context,
                      isPacienteOrGuest ? 'paciente_home' : 'home',
                    );
                  },
                  icon: const Icon(Icons.home, color: Colors.white, size: 20),
                  label: Text(
                    l10n.navHome,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (userType == 'Nutricionista')
            FutureBuilder<Map<String, MenuEntryConfig>>(
              future: MenuVisibilityPremiumService.loadConfig(),
              builder: (context, snapshot) {
                final menuConfig = snapshot.data ??
                    MenuVisibilityPremiumService.defaultConfig();

                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.mark_chat_unread_outlined),
                      title: Text(l10n.navChat),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ChatConversationsScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.people),
                      title: Text(l10n.navPatients),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PacientesListScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text(l10n.navAppointments),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CitasListScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.rate_review),
                      title: Text(l10n.navReviews),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const RevisionesPacientesListScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.show_chart),
                      title: Text(l10n.navMeasurements),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const MedicionesPacientesListScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.assignment),
                      title: Text(l10n.navNutriInterviews),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const EntrevistasPacientesListScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.article),
                      title: Text(l10n.navNutriPlans),
                      trailing: _statusBadges(
                        premium: _isPremium(
                          menuConfig,
                          MenuVisibilityPremiumService.planesNutri,
                        ),
                        hidden: !_isVisible(
                          menuConfig,
                          MenuVisibilityPremiumService.planesNutri,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const PlanesPacientesListScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.sports_gymnastics),
                      title: Text(l10n.navFitInterviews),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const EntrevistasFitPacientesListScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.fitness_center_outlined),
                      title: Text(l10n.navFitPlans),
                      trailing: _statusBadges(
                        premium: _isPremium(
                          menuConfig,
                          MenuVisibilityPremiumService.planesFit,
                        ),
                        hidden: !_isVisible(
                          menuConfig,
                          MenuVisibilityPremiumService.planesFit,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const PlanesFitPacientesListScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.sports_mma),
                      title: Text(l10n.navExercises),
                      trailing: _statusBadges(
                        premium: _isPremium(
                          menuConfig,
                          MenuVisibilityPremiumService.catalogoEjercicios,
                        ),
                        hidden: !_isVisible(
                          menuConfig,
                          MenuVisibilityPremiumService.catalogoEjercicios,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const PlanFitEjerciciosCatalogScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(l10n.navExerciseVideos),
                      trailing: _statusBadges(
                        premium: _isPremium(
                          menuConfig,
                          MenuVisibilityPremiumService.videosEjercicios,
                        ),
                        hidden: !_isVisible(
                          menuConfig,
                          MenuVisibilityPremiumService.videosEjercicios,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                            context, '/videos_ejercicios_admin');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.directions_run),
                      title: Text(l10n.navActivities),
                      trailing: _statusBadges(
                        premium: _isPremium(
                          menuConfig,
                          MenuVisibilityPremiumService.actividades,
                        ),
                        hidden: !_isVisible(
                          menuConfig,
                          MenuVisibilityPremiumService.actividades,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EntrenamientosScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.dashboard),
                      title: Text(l10n.navDashboard),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, 'dashboard');
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.payment),
                      title: Text(l10n.navCharges),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CobrosListScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.business_center),
                      title: Text(l10n.navClients),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ClientesListScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.lightbulb),
                      title: Text(l10n.navTips),
                      trailing: _statusBadges(
                        premium: _isPremium(
                          menuConfig,
                          MenuVisibilityPremiumService.consejos,
                        ),
                        hidden: !_isVisible(
                          menuConfig,
                          MenuVisibilityPremiumService.consejos,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/consejos_list');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.restaurant_menu),
                      title: Text(l10n.navRecipes),
                      trailing: _statusBadges(
                        premium: _isPremium(
                          menuConfig,
                          MenuVisibilityPremiumService.recetas,
                        ),
                        hidden: !_isVisible(
                          menuConfig,
                          MenuVisibilityPremiumService.recetas,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/recetas_list');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.swap_horiz_rounded),
                      title: Text(l10n.navSubstitutions),
                      trailing: _statusBadges(
                        premium: _isPremium(
                          menuConfig,
                          MenuVisibilityPremiumService.sustitucionesSaludables,
                        ),
                        hidden: !_isVisible(
                          menuConfig,
                          MenuVisibilityPremiumService.sustitucionesSaludables,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                            context, '/sustituciones_saludables_list');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.present_to_all_rounded),
                      title: Text(l10n.navTalksAndSeminars),
                      trailing: _statusBadges(
                        premium: _isPremium(
                          menuConfig,
                          MenuVisibilityPremiumService.charlasSeminarios,
                        ),
                        hidden: !_isVisible(
                          menuConfig,
                          MenuVisibilityPremiumService.charlasSeminarios,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                            context, '/charlas_seminarios_list');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.workspace_premium),
                      title: Text(l10n.navPremiumPreview),
                      onTap: () {
                        Navigator.pop(context);
                        _showPremiumPreviewMenu(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.set_meal_outlined),
                      title: Text(l10n.navFoods),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AlimentosScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.medication_outlined),
                      title: Text(l10n.navSupplements),
                      trailing: _statusBadges(
                        premium: _isPremium(
                          menuConfig,
                          MenuVisibilityPremiumService.suplementos,
                        ),
                        hidden: !_isVisible(
                          menuConfig,
                          MenuVisibilityPremiumService.suplementos,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/suplementos_list');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.science_outlined),
                      title: Text(l10n.navFoodAdditives),
                      trailing: _statusBadges(
                        premium: _isPremium(
                          menuConfig,
                          MenuVisibilityPremiumService.aditivosAlimentarios,
                        ),
                        hidden: !_isVisible(
                          menuConfig,
                          MenuVisibilityPremiumService.aditivosAlimentarios,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/aditivos_list');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.document_scanner_outlined),
                      title: Text(l10n.navScanner),
                      trailing: _statusBadges(
                        premium: _isPremium(
                          menuConfig,
                          MenuVisibilityPremiumService.escaner,
                        ),
                        hidden: !_isVisible(
                          menuConfig,
                          MenuVisibilityPremiumService.escaner,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/scanner_etiquetas');
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: Text(l10n.settingsAndPrivacyMenuLabel),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, 'config');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.manage_accounts),
                      title: Text(l10n.navUsers),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UsuariosListScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.checklist_outlined),
                      title: Text(l10n.navTasks),
                      trailing: _statusBadges(
                        premium: _isPremium(
                          menuConfig,
                          MenuVisibilityPremiumService.tareas,
                        ),
                        hidden: !_isVisible(
                          menuConfig,
                          MenuVisibilityPremiumService.tareas,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TodoListScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(),
                  ],
                );
              },
            )
          else ...[
            // Menú para Paciente o Guest
            ListTile(
              leading: const Icon(Icons.mark_chat_unread_outlined),
              title: Text(l10n.navChatWithDietitian),
              onTap: () {
                if (isGuestMode) {
                  // No cerrar el drawer para guest, mostrar di├ílogo sobre el drawer abierto
                  _showChatGuestDialog(context);
                  return;
                }
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(l10n.navContactDietitian),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContactoNutricionistaScreen(),
                  ),
                );
              },
            ),
            if (!isGuestMode) ...[
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(l10n.navEditProfile),
                onTap: () {
                  Navigator.pop(context);
                  final authService = Provider.of<AuthService>(
                    context,
                    listen: false,
                  );
                  final usuario = Usuario(
                    codigo: int.parse(authService.userCode ?? '0'),
                    nick: '', // Se obtendr├í del servidor si es necesario
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PacienteProfileEditScreen(usuario: usuario),
                    ),
                  );
                },
              ),
            ],
            const Divider(),
            FutureBuilder<Map<String, MenuEntryConfig>>(
              future: MenuVisibilityPremiumService.loadConfig(),
              builder: (context, snapshot) {
                final menuConfig = snapshot.data ??
                    MenuVisibilityPremiumService.defaultConfig();

                return Column(
                  children: [
                    if (_isVisible(
                        menuConfig, MenuVisibilityPremiumService.planesNutri))
                      ListTile(
                        leading: const Icon(Icons.article),
                        title: Text(l10n.navNutriPlans),
                        trailing: _premiumBadge(
                          _isPremium(menuConfig,
                              MenuVisibilityPremiumService.planesNutri),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          final authService = Provider.of<AuthService>(
                            context,
                            listen: false,
                          );
                          final hasPatient =
                              (authService.patientCode ?? '').isNotEmpty;

                          if (hasPatient) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PlanesPacienteListScreen(),
                              ),
                            );
                          } else {
                            _showPlanesRestrictedDialog(
                              context,
                              'Planes Nutricionales',
                            );
                          }
                        },
                      ),
                    if (_isVisible(
                        menuConfig, MenuVisibilityPremiumService.planesFit))
                      ListTile(
                        leading: const Icon(Icons.fitness_center),
                        title: Text(l10n.navFitPlans),
                        trailing: _premiumBadge(
                          _isPremium(menuConfig,
                              MenuVisibilityPremiumService.planesFit),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          final authService = Provider.of<AuthService>(
                            context,
                            listen: false,
                          );
                          final hasPatient =
                              (authService.patientCode ?? '').isNotEmpty;

                          if (hasPatient) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PlanesFitPacienteListScreen(),
                              ),
                            );
                          } else {
                            _showPlanesRestrictedDialog(
                              context,
                              'Planes de Entrenamiento',
                            );
                          }
                        },
                      ),
                    const Divider(),
                    if (_isVisible(menuConfig,
                        MenuVisibilityPremiumService.recomendaciones))
                      ListTile(
                        leading: const Icon(Icons.recommend_outlined),
                        title: Text(l10n.navRecommendations),
                        trailing: _premiumBadge(
                          _isPremium(
                            menuConfig,
                            MenuVisibilityPremiumService.recomendaciones,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          final authService = Provider.of<AuthService>(
                            context,
                            listen: false,
                          );
                          final hasPatient =
                              (authService.patientCode ?? '').isNotEmpty;

                          if (authService.isGuestMode || !hasPatient) {
                            _showRecomendacionesRestrictedDialog(
                              context,
                              authService.isGuestMode,
                            );
                          } else {
                            Navigator.pushNamed(
                              context,
                              '/consejos_paciente',
                              arguments: {'openPersonalizados': true},
                            );
                          }
                        },
                      ),
                    if (_isVisible(
                        menuConfig, MenuVisibilityPremiumService.consejos))
                      ListTile(
                        leading: const Icon(Icons.lightbulb),
                        title: Text(l10n.navTips),
                        trailing: _premiumBadge(
                          _isPremium(menuConfig,
                              MenuVisibilityPremiumService.consejos),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(
                            context,
                            '/consejos_paciente',
                            arguments: {'openDestacados': true},
                          );
                        },
                      ),
                    if (_isVisible(
                      menuConfig,
                      MenuVisibilityPremiumService.videosEjercicios,
                    ))
                      ListTile(
                        leading: const Icon(Icons.play_circle_outline),
                        title: Text(l10n.navExerciseVideos),
                        trailing: _premiumBadge(
                          _isPremium(
                            menuConfig,
                            MenuVisibilityPremiumService.videosEjercicios,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/videos_ejercicios');
                        },
                      ),
                    if (_isVisible(
                      menuConfig,
                      MenuVisibilityPremiumService.catalogoEjercicios,
                    ))
                      ListTile(
                        leading: const Icon(Icons.fitness_center_outlined),
                        title: Text(l10n.navExerciseCatalog),
                        trailing: _premiumBadge(
                          _isPremium(
                            menuConfig,
                            MenuVisibilityPremiumService.catalogoEjercicios,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PlanFitEjerciciosCatalogScreen(
                                readOnly: true,
                                premiumVisibleOnly: true,
                              ),
                            ),
                          );
                        },
                      ),
                    if (_isVisible(
                        menuConfig, MenuVisibilityPremiumService.recetas))
                      ListTile(
                        leading: const Icon(Icons.restaurant_menu),
                        title: Text(l10n.navRecipes),
                        trailing: _premiumBadge(
                          _isPremium(
                              menuConfig, MenuVisibilityPremiumService.recetas),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/recetas_paciente');
                        },
                      ),
                    if (_isVisible(
                      menuConfig,
                      MenuVisibilityPremiumService.sustitucionesSaludables,
                    ))
                      ListTile(
                        leading: const Icon(Icons.swap_horiz_rounded),
                        title: Text(l10n.navSubstitutions),
                        trailing: _premiumBadge(
                          _isPremium(
                            menuConfig,
                            MenuVisibilityPremiumService
                                .sustitucionesSaludables,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(
                            context,
                            '/sustituciones_saludables',
                          );
                        },
                      ),
                    if (_isVisible(
                      menuConfig,
                      MenuVisibilityPremiumService.charlasSeminarios,
                    ))
                      ListTile(
                        leading: const Icon(Icons.present_to_all_rounded),
                        title: Text(l10n.navTalks),
                        trailing: _premiumBadge(
                          _isPremium(
                            menuConfig,
                            MenuVisibilityPremiumService.charlasSeminarios,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/charlas_seminarios');
                        },
                      ),
                    if (_isVisible(
                      menuConfig,
                      MenuVisibilityPremiumService.suplementos,
                    ))
                      ListTile(
                        leading: const Icon(Icons.medication_outlined),
                        title: Text(l10n.navSupplements),
                        trailing: _premiumBadge(
                          _isPremium(
                            menuConfig,
                            MenuVisibilityPremiumService.suplementos,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/suplementos');
                        },
                      ),
                    if (_isVisible(
                      menuConfig,
                      MenuVisibilityPremiumService.aditivosAlimentarios,
                    ))
                      ListTile(
                        leading: const Icon(Icons.science_outlined),
                        title: Text(l10n.navAdditives),
                        trailing: _premiumBadge(
                          _isPremium(
                            menuConfig,
                            MenuVisibilityPremiumService.aditivosAlimentarios,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/aditivos');
                        },
                      ),
                    const Divider(),
                    if (_isVisible(
                        menuConfig, MenuVisibilityPremiumService.actividades))
                      ListTile(
                        leading: const Icon(Icons.fitness_center),
                        title: Text(l10n.navActivities),
                        trailing: _premiumBadge(
                          _isPremium(menuConfig,
                              MenuVisibilityPremiumService.actividades),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/entrenamientos');
                        },
                      ),
                    if (_isVisible(
                        menuConfig, MenuVisibilityPremiumService.controlPeso))
                      ListTile(
                        leading: const Icon(Icons.monitor_weight_outlined),
                        title: Text(l10n.navWeightControl),
                        trailing: _premiumBadge(
                          _isPremium(menuConfig,
                              MenuVisibilityPremiumService.controlPeso),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PesosUsuarioScreen(),
                            ),
                          );
                        },
                      ),
                    if (_isVisible(
                        menuConfig, MenuVisibilityPremiumService.listaCompra))
                      ListTile(
                        leading: const Icon(Icons.shopping_cart),
                        title: Text(l10n.navShoppingList),
                        trailing: _premiumBadge(
                          _isPremium(menuConfig,
                              MenuVisibilityPremiumService.listaCompra),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/lista_compra');
                        },
                      ),
                    if (_isVisible(
                        menuConfig, MenuVisibilityPremiumService.escaner))
                      ListTile(
                        leading: const Icon(Icons.document_scanner_outlined),
                        title: Text(l10n.navScanner),
                        trailing: _premiumBadge(
                          _isPremium(
                              menuConfig, MenuVisibilityPremiumService.escaner),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/scanner_etiquetas');
                        },
                      ),
                    const Divider(height: 1),
                    if (_isVisible(
                        menuConfig, MenuVisibilityPremiumService.tareas))
                      ListTile(
                        leading: const Icon(Icons.checklist_outlined),
                        title: Text(l10n.navTasks),
                        trailing: _premiumBadge(
                          _isPremium(
                              menuConfig, MenuVisibilityPremiumService.tareas),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TodoListScreen(),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(l10n.settingsAndPrivacyMenuLabel),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/user_settings');
              },
            ),
            if (isGuestMode) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.app_registration),
                title: Text(l10n.navStartRegistration),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/register');
                },
              ),
            ],
            if (!isGuestMode) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(l10n.navLogout),
                onTap: () {
                  Provider.of<AuthService>(context, listen: false).logout();
                  Navigator.of(context).pushReplacementNamed('login');
                },
              ),
            ],
          ],
          if (userType == 'Nutricionista') ...[
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(l10n.navContactDietitian),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContactoNutricionistaScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(l10n.navLogout),
              onTap: () {
                Provider.of<AuthService>(context, listen: false).logout();
                Navigator.of(context).pushReplacementNamed('login');
              },
            ),
          ],
          // Espaciador para asegurar que el botón de cerrar sesión sea visible
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  static void _showPlanesRestrictedDialog(
    BuildContext context,
    String planType,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final dialogTitle = planType == 'Planes Nutricionales'
        ? l10n.drawerRestrictedNutriPlansTitle
        : l10n.drawerRestrictedTrainingTitle;
    RestrictedAccessDialogHelper.show(context, title: dialogTitle);
  }

  static void _showRecomendacionesRestrictedDialog(
    BuildContext context,
    bool isGuest,
  ) {
    RestrictedAccessDialogHelper.show(
      context,
      title: AppLocalizations.of(context)!.drawerRestrictedRecommendationsTitle,
    );
  }

  static Future<void> _showPremiumPreviewMenu(BuildContext context) async {
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

  static void _showChatGuestDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.drawerRegistrationRequiredTitle),
        content: Text(
          l10n.drawerRegistrationRequiredChatMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar di├ílogo
              Navigator.pop(context); // Cerrar drawer
              Navigator.pushNamed(context, '/register');
            },
            child: Text(l10n.navStartRegistration),
          ),
        ],
      ),
    );
  }
}
