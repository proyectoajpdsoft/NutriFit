import 'package:flutter/material.dart';
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
import 'package:nutri_app/widgets/restricted_access_dialog_helper.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/constants/app_constants.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.appName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    AppConstants.appVersion,
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
              title: const Text('Cerrar sesión'),
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
      userTypeLabel = 'Usuario invitado';
    } else if (userType == 'Nutricionista' || userType == 'Administrador') {
      userTypeLabel = 'Usuario administrador';
    } else if (authService.patientCode != null &&
        authService.patientCode!.isNotEmpty) {
      userTypeLabel = authService.isPremium
          ? 'Usuario paciente Premium'
          : 'Usuario paciente';
    } else {
      userTypeLabel = authService.isPremium
          ? 'Usuario registrado Premium'
          : 'Usuario registrado';
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
                      const Text(
                        AppConstants.appVersion,
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
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.workspace_premium,
                                size: 14,
                                color: Colors.black87,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'PREMIUM',
                                style: TextStyle(
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
                  label: const Text(
                    'Inicio',
                    style: TextStyle(color: Colors.white, fontSize: 14),
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
          if (userType == 'Nutricionista') ...[
            ListTile(
              leading: const Icon(Icons.mark_chat_unread_outlined),
              title: const Text('Chat'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatConversationsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Pacientes'),
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
              title: const Text('Citas'),
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
              title: const Text('Revisiones'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RevisionesPacientesListScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('Mediciones'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MedicionesPacientesListScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Entrevistas Nutri'),
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
              title: const Text('Planes Nutri'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlanesPacientesListScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.sports_gymnastics),
              title: const Text('Entrevistas Fit'),
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
              title: const Text('Planes Fit'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlanesFitPacientesListScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.sports_mma),
              title: const Text('Ejercicios'),
              trailing: Container(
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
              title: const Text('Vídeos Ejercicios'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/videos_ejercicios_admin');
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_run),
              title: const Text('Actividades'),
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
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, 'dashboard');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('Cobros'),
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
              title: const Text('Clientes'),
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
              title: const Text('Consejos'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/consejos_list');
              },
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('Recetas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/recetas_list');
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: const Text('Sustituciones'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/sustituciones_saludables_list');
              },
            ),
            ListTile(
              leading: const Icon(Icons.present_to_all_rounded),
              title: const Text('Charlas y Seminarios'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/charlas_seminarios_list');
              },
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium),
              title: const Text('Hazte Premium (vista)'),
              onTap: () {
                Navigator.pop(context);
                Future.microtask(() => _showPremiumPreviewMenu(context));
              },
            ),
            ListTile(
              leading: const Icon(Icons.set_meal_outlined),
              title: const Text('Alimentos'),
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
              title: const Text('Suplementos'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/suplementos_list');
              },
            ),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Aditivos alimentarios'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/aditivos_list');
              },
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner_outlined),
              title: const Text('Escáner'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/scanner_etiquetas');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Ajustes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, 'config');
              },
            ),
            ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: const Text('Usuarios'),
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
              title: const Text('Tareas'),
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
          ] else ...[
            // Menú para Paciente o Guest
            ListTile(
              leading: const Icon(Icons.mark_chat_unread_outlined),
              title: const Text('Chat con dietista'),
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
              title: const Text('Contactar con dietista'),
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
                title: const Text('Editar Perfil'),
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
            ListTile(
              leading: const Icon(Icons.article),
              title: const Text('Planes Nutri'),
              onTap: () {
                Navigator.pop(context);
                final authService = Provider.of<AuthService>(
                  context,
                  listen: false,
                );
                final hasPatient = (authService.patientCode ?? '').isNotEmpty;

                if (hasPatient) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlanesPacienteListScreen(),
                    ),
                  );
                } else {
                  _showPlanesRestrictedDialog(context, 'Planes Nutricionales');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Planes Fit'),
              onTap: () {
                Navigator.pop(context);
                final authService = Provider.of<AuthService>(
                  context,
                  listen: false,
                );
                final hasPatient = (authService.patientCode ?? '').isNotEmpty;

                if (hasPatient) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlanesFitPacienteListScreen(),
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
            ListTile(
              leading: const Icon(Icons.recommend_outlined),
              title: const Text('Recomendaciones'),
              onTap: () {
                Navigator.pop(context);
                final authService = Provider.of<AuthService>(
                  context,
                  listen: false,
                );
                final hasPatient = (authService.patientCode ?? '').isNotEmpty;

                // Si no está registrado o no tiene paciente
                if (authService.isGuestMode || !hasPatient) {
                  _showRecomendacionesRestrictedDialog(
                    context,
                    authService.isGuestMode,
                  );
                } else {
                  // Usuario con paciente: abrir pestaña Personales
                  Navigator.pushNamed(
                    context,
                    '/consejos_paciente',
                    arguments: {'openPersonalizados': true},
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb),
              title: const Text('Consejos'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/consejos_paciente',
                  arguments: {'openDestacados': true},
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Vídeos Ejercicios'),
              trailing: Container(
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
              ),
              onTap: () {
                Navigator.pop(context);
                final auth = Provider.of<AuthService>(context, listen: false);
                if (auth.isPremium ||
                    auth.userType == 'Nutricionista' ||
                    auth.userType == 'Administrador') {
                  Navigator.pushNamed(context, '/videos_ejercicios');
                } else {
                  RestrictedAccessDialogHelper.show(
                    context,
                    title: 'Vídeos de ejercicios',
                    message:
                        'Los vídeos de ejercicios completos están disponibles para usuarios Premium. Desde aquí puedes consultar sus ventajas y solicitar el acceso al nutricionista.',
                    primaryActionLabel: 'Hazte Premium',
                    primaryActionIcon: Icons.workspace_premium,
                    primaryRouteName: '/premium_info',
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center_outlined),
              title: const Text('Catálogo ejercicios'),
              trailing: Container(
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
              ),
              onTap: () {
                Navigator.pop(context);
                final auth = Provider.of<AuthService>(context, listen: false);
                if (auth.isPremium ||
                    auth.userType == 'Nutricionista' ||
                    auth.userType == 'Administrador') {
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
                } else {
                  RestrictedAccessDialogHelper.show(
                    context,
                    title: 'Catálogo ejercicios',
                    message:
                        'El catálogo de ejercicios para pacientes está disponible para usuarios Premium. Activa Premium para consultar los ejercicios habilitados y usarlos en tus actividades.',
                    primaryActionLabel: 'Hazte Premium',
                    primaryActionIcon: Icons.workspace_premium,
                    primaryRouteName: '/premium_info',
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('Recetas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/recetas_paciente');
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: const Text('Sustituciones'),
              trailing: Container(
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
              ),
              onTap: () {
                Navigator.pop(context);
                final auth = Provider.of<AuthService>(context, listen: false);
                if (auth.isPremium ||
                    auth.userType == 'Nutricionista' ||
                    auth.userType == 'Administrador') {
                  Navigator.pushNamed(context, '/sustituciones_saludables');
                } else {
                  RestrictedAccessDialogHelper.show(
                    context,
                    title: 'Sustituciones',
                    message:
                        'La biblioteca de sustituciones saludables está disponible para usuarios Premium. Desde aquí puedes revisar sus ventajas y solicitar el acceso al nutricionista.',
                    primaryActionLabel: 'Hazte Premium',
                    primaryActionIcon: Icons.workspace_premium,
                    primaryRouteName: '/premium_info',
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.present_to_all_rounded),
              title: const Text('Charlas'),
              trailing: Container(
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
              ),
              onTap: () {
                Navigator.pop(context);
                final auth = Provider.of<AuthService>(context, listen: false);
                if (auth.isPremium ||
                    auth.userType == 'Nutricionista' ||
                    auth.userType == 'Administrador') {
                  Navigator.pushNamed(context, '/charlas_seminarios');
                } else {
                  RestrictedAccessDialogHelper.show(
                    context,
                    title: 'Charlas y Seminarios',
                    message:
                        'Las charlas y seminarios están disponibles para usuarios Premium. Activa Premium para acceder al contenido exclusivo.',
                    primaryActionLabel: 'Hazte Premium',
                    primaryActionIcon: Icons.workspace_premium,
                    primaryRouteName: '/premium_info',
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.medication_outlined),
              title: const Text('Suplementos'),
              trailing: Container(
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
              ),
              onTap: () {
                Navigator.pop(context);
                final auth = Provider.of<AuthService>(context, listen: false);
                if (auth.isPremium ||
                    auth.userType == 'Nutricionista' ||
                    auth.userType == 'Administrador') {
                  Navigator.pushNamed(context, '/suplementos');
                } else {
                  RestrictedAccessDialogHelper.show(
                    context,
                    title: 'Suplementos',
                    message:
                        'La sección de suplementos está disponible para usuarios Premium. Activa Premium para consultar el catálogo de suplementos.',
                    primaryActionLabel: 'Hazte Premium',
                    primaryActionIcon: Icons.workspace_premium,
                    primaryRouteName: '/premium_info',
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Aditivos'),
              trailing: Container(
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
              ),
              onTap: () {
                Navigator.pop(context);
                final auth = Provider.of<AuthService>(context, listen: false);
                if (auth.isPremium ||
                    auth.userType == 'Nutricionista' ||
                    auth.userType == 'Administrador') {
                  Navigator.pushNamed(context, '/aditivos');
                } else {
                  RestrictedAccessDialogHelper.show(
                    context,
                    title: 'Aditivos alimentarios',
                    message:
                        'La sección de aditivos alimentarios está disponible para usuarios Premium. Activa Premium para consultar el catálogo de aditivos.',
                    primaryActionLabel: 'Hazte Premium',
                    primaryActionIcon: Icons.workspace_premium,
                    primaryRouteName: '/premium_info',
                  );
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Actividades'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/entrenamientos');
              },
            ),
            ListTile(
              leading: const Icon(Icons.monitor_weight_outlined),
              title: const Text('Control de peso'),
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
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Lista de la compra'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/lista_compra');
              },
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner_outlined),
              title: const Text('Escáner'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/scanner_etiquetas');
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: const Text('Tareas'),
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
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Ajustes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/user_settings');
              },
            ),
            if (isGuestMode) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.app_registration),
                title: const Text('Iniciar registro'),
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
                title: const Text('Cerrar sesión'),
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
              title: const Text('Contactar con dietista'),
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
              title: const Text('Cerrar sesión'),
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
    final dialogTitle = planType == 'Planes Nutricionales'
        ? 'Planes nutricionales'
        : 'Entrenamientos personalizados';
    RestrictedAccessDialogHelper.show(context, title: dialogTitle);
  }

  static void _showRecomendacionesRestrictedDialog(
    BuildContext context,
    bool isGuest,
  ) {
    RestrictedAccessDialogHelper.show(context, title: 'Recomendaciones');
  }

  static Future<void> _showPremiumPreviewMenu(BuildContext context) async {
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

  static void _showChatGuestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registro requerido'),
        content: const Text(
          'Para chatear con tu dietista online, por favor, regístrate (es gratis).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar di├ílogo
              Navigator.pop(context); // Cerrar drawer
              Navigator.pushNamed(context, '/register');
            },
            child: const Text('Iniciar registro'),
          ),
        ],
      ),
    );
  }
}
