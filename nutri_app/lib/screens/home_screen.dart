import 'package:flutter/material.dart';
import 'package:nutri_app/screens/citas/citas_list_screen.dart';
import 'package:nutri_app/screens/clientes/clientes_list_screen.dart';
import 'package:nutri_app/screens/cobros/cobros_list_screen.dart';
import 'package:nutri_app/screens/config_screen.dart';
import 'package:nutri_app/screens/dashboard_screen.dart';
import 'package:nutri_app/screens/entrevistas/entrevistas_pacientes_list_screen.dart';
import 'package:nutri_app/screens/entrevistas_fit/entrevistas_fit_pacientes_list_screen.dart';
import 'package:nutri_app/screens/mediciones/mediciones_pacientes_list_screen.dart';
import 'package:nutri_app/screens/notifications_screen.dart';
import 'package:nutri_app/screens/messages_inbox_screen.dart';
import 'package:nutri_app/screens/pacientes/pacientes_list_screen.dart';
import 'package:nutri_app/screens/planes_nutricionales/planes_pacientes_list_screen.dart';
import 'package:nutri_app/screens/planes_fit/planes_fit_pacientes_list_screen.dart';
import 'package:nutri_app/screens/planes_fit/plan_fit_ejercicios_catalog_screen.dart';
import 'package:nutri_app/screens/revisiones/revisiones_pacientes_list_screen.dart';
import 'package:nutri_app/screens/usuarios/usuarios_list_screen.dart';
import 'package:nutri_app/screens/entrenamientos_screen.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/mixins/auth_error_handler_mixin.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _verifyUserAndLoad();
  }

  Future<void> _verifyUserAndLoad() async {
    final authService = context.read<AuthService>();

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

    await _loadPendingCounts();
  }

  Future<void> _loadPendingCounts() async {
    try {
      final apiService = context.read<ApiService>();

      // Obtener citas pendientes (estado != 'Realizada')
      final citas = await apiService.getCitas();
      final pendingCitas = citas
          .where((c) => c.estado != null && c.estado != 'Realizada')
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsPendingScreen(),
                    ),
                  );
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
                        builder: (context) => const MessagesInboxScreen())),
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
                icon: Icons.sports_mma,
                label: 'Ejercicios',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const PlanFitEjerciciosCatalogScreen())),
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
                icon: Icons.settings_outlined,
                label: 'Configuración',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 26, color: Theme.of(context).primaryColor),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
