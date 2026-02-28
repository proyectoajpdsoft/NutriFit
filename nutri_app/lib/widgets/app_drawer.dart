import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:nutri_app/screens/revisiones/revisiones_pacientes_list_screen.dart';
import 'package:nutri_app/screens/clientes/clientes_list_screen.dart';
import 'package:nutri_app/screens/cobros/cobros_list_screen.dart';
import 'package:nutri_app/screens/usuarios/usuarios_list_screen.dart';
import 'package:nutri_app/screens/contacto_nutricionista_screen.dart';
import 'package:nutri_app/screens/chat_conversations_screen.dart';
import 'package:nutri_app/screens/chat_screen.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/constants/app_constants.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AppDrawer extends StatelessWidget {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');

  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userType = authService.userType;
    final isGuestMode = authService.isGuestMode;

    // Control de seguridad: si no hay userType, mostrar solo opción de logout
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
              title: const Text('Cerrar Sesión'),
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
      userTypeLabel = 'Usuario paciente';
    } else {
      userTypeLabel = 'Usuario registrado';
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
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    final isPacienteOrGuest =
                        userType == 'Paciente' || userType == 'Guest';
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        builder: (context) => const PacientesListScreen()));
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
                        builder: (context) => const CitasListScreen()));
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
                        builder: (context) =>
                            const RevisionesPacientesListScreen()));
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
                        builder: (context) =>
                            const MedicionesPacientesListScreen()));
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
                            const EntrevistasPacientesListScreen()));
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
                        builder: (context) =>
                            const PlanesPacientesListScreen()));
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
                            const EntrevistasFitPacientesListScreen()));
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
                        builder: (context) =>
                            const PlanesFitPacientesListScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.sports_mma),
              title: const Text('Ejercicios'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const PlanFitEjerciciosCatalogScreen()));
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
                        builder: (context) => const CobrosListScreen()));
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
                        builder: (context) => const ClientesListScreen()));
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
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configuración'),
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
                        builder: (context) => const UsuariosListScreen()));
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
                  // No cerrar el drawer para guest, mostrar diálogo sobre el drawer abierto
                  _showChatGuestDialog(context);
                  return;
                }
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatScreen(
                      otherDisplayName: 'Dietista',
                    ),
                  ),
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
                  final authService =
                      Provider.of<AuthService>(context, listen: false);
                  final usuario = Usuario(
                    codigo: int.parse(authService.userCode ?? '0'),
                    nick: '', // Se obtendrá del servidor si es necesario
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
              leading: const Icon(Icons.recommend_outlined),
              title: const Text('Recomendaciones'),
              onTap: () {
                Navigator.pop(context);
                final authService =
                    Provider.of<AuthService>(context, listen: false);
                final hasPatient = (authService.patientCode ?? '').isNotEmpty;

                // Si no está registrado o no tiene paciente
                if (authService.isGuestMode || !hasPatient) {
                  _showRecomendacionesRestrictedDialog(
                      context, authService.isGuestMode);
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
              leading: const Icon(Icons.article),
              title: const Text('Planes Nutri'),
              onTap: () {
                Navigator.pop(context);
                final authService =
                    Provider.of<AuthService>(context, listen: false);
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
                final authService =
                    Provider.of<AuthService>(context, listen: false);
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
                      context, 'Planes de Entrenamiento');
                }
              },
            ),
            const Divider(),
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
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('Recetas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/recetas_paciente');
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
            if (!isGuestMode) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Cerrar Sesión'),
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
              title: const Text('Cerrar Sesión'),
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
      BuildContext context, String planType) async {
    // Cargar información de contacto
    final apiService = ApiService();
    Map<String, String> contactInfo = {};

    try {
      final email = await apiService.getParametro('nutricionista_email');
      final telefono = await apiService.getParametro('nutricionista_telefono');

      contactInfo = {
        'email': email?['valor'] ?? '',
        'telefono': telefono?['valor'] ?? '',
      };
    } catch (e) {
      // Si hay error, continuar con valores vacíos
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_outline,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('$planType Personalizados')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para acceder a tus planes personalizados, primero necesitas contactar con el dietista para que te asigne un plan específico, adaptado a tus necesidades.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              const Text(
                'Formas de contacto:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              // Email
              if ((contactInfo['email'] ?? '').isNotEmpty)
                _buildDialogContactRow(
                  context,
                  icon: Icons.email,
                  label: 'Email',
                  value: contactInfo['email'] ?? '',
                  onTap: () => _launchUrl('mailto:${contactInfo['email']}'),
                ),

              // Teléfono
              if ((contactInfo['telefono'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDialogContactRow(
                  context,
                  icon: Icons.phone,
                  label: 'Teléfono',
                  value: contactInfo['telefono'] ?? '',
                  onTap: () => _launchUrl('tel:${contactInfo['telefono']}'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContactoNutricionistaScreen(),
                ),
              );
            },
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Otras opciones...'),
          ),
        ],
      ),
    );
  }

  static void _showRecomendacionesRestrictedDialog(
      BuildContext context, bool isGuest) async {
    // Cargar información de contacto
    final apiService = ApiService();
    Map<String, String> contactInfo = {};

    try {
      final email = await apiService.getParametro('nutricionista_email');
      final telefono = await apiService.getParametro('nutricionista_telefono');

      contactInfo = {
        'email': email?['valor'] ?? '',
        'telefono': telefono?['valor'] ?? '',
      };
    } catch (e) {
      // Si hay error, continuar con valores vacíos
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_outline,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Recomendaciones Personalizadas')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para acceder a tus recomendaciones personalizadas, primero necesitas contactar con el dietista para que te asigne un plan específico, ajustado a tus necesidades.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              const Text(
                'Formas de contacto:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (contactInfo.isNotEmpty) ...[
                if (contactInfo['email'] != null &&
                    contactInfo['email']!.isNotEmpty) ...[
                  InkWell(
                    onTap: () => _launchUrl('mailto:${contactInfo['email']}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.email,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(contactInfo['email'] ?? ''),
                        ],
                      ),
                    ),
                  ),
                ],
                if (contactInfo['telefono'] != null &&
                    contactInfo['telefono']!.isNotEmpty) ...[
                  InkWell(
                    onTap: () => _launchUrl('tel:${contactInfo['telefono']}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.phone,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(contactInfo['telefono'] ?? ''),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContactoNutricionistaScreen(),
                ),
              );
            },
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Más formas de contacto'),
          ),
        ],
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
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pop(context); // Cerrar drawer
              Navigator.pushNamed(context, '/register');
            },
            child: const Text('Registrarse'),
          ),
        ],
      ),
    );
  }

  static Widget _buildDialogContactRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  static Future<void> _launchUrl(String url) async {
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        await _externalUrlChannel.invokeMethod('openUrl', {'url': url});
      }
    } catch (_) {
      // Error silencioso
    }
  }
}
