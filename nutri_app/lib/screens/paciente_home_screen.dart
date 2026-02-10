import 'package:flutter/material.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:nutri_app/models/consejo.dart';
import 'package:nutri_app/screens/paciente_profile_edit_screen.dart';
import 'package:nutri_app/screens/planes_fit/planes_fit_paciente_list_screen.dart';
import 'package:nutri_app/screens/planes_nutricionales/planes_paciente_list_screen.dart';
import 'package:nutri_app/screens/consejos_paciente_screen.dart';
import 'package:nutri_app/screens/contacto_nutricionista_screen.dart';
import 'package:nutri_app/screens/messages_inbox_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PacienteHomeScreen extends StatefulWidget {
  const PacienteHomeScreen({super.key});

  @override
  _PacienteHomeScreenState createState() => _PacienteHomeScreenState();
}

class _PacienteHomeScreenState extends State<PacienteHomeScreen> {
  final ApiService _apiService = ApiService();
  bool _isAuthorized = true;
  bool _isLoading = true;
  Paciente? _paciente;
  bool _hasPlanes = false;
  Map<String, String> _contactInfo = {};
  List<Consejo> _consejosDestacados = [];
  int _consejosNoLeidos = 0;
  int _comentariosNoLeidos = 0;
  int _chatNoLeidos = 0;
  bool _showWelcomeMessage = false;

  @override
  void initState() {
    super.initState();
    _verifyUser();
    _loadPatientData();
    _loadConsejosDestacados();
    _loadComentariosPendientes();
    _loadChatPendientes();
    _checkFirstTime();
  }

  Future<void> _loadComentariosPendientes() async {
    try {
      final authService = context.read<AuthService>();
      if (authService.isGuestMode) {
        setState(() {
          _comentariosNoLeidos = 0;
        });
        return;
      }
      final items = await _apiService.getComentariosPendientes();
      if (!mounted) return;
      setState(() {
        _comentariosNoLeidos = items.length;
      });
    } catch (e) {
      debugPrint('Error al cargar comentarios pendientes: $e');
    }
  }

  Future<void> _loadChatPendientes() async {
    try {
      final authService = context.read<AuthService>();
      if (authService.isGuestMode) {
        setState(() {
          _chatNoLeidos = 0;
        });
        return;
      }
      final total = await _apiService.getChatUnreadCount();
      if (!mounted) return;
      setState(() {
        _chatNoLeidos = total;
      });
    } catch (e) {
      debugPrint('Error al cargar chat pendientes: $e');
    }
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('is_first_time') ?? true;

    if (isFirstTime) {
      setState(() {
        _showWelcomeMessage = true;
      });
      await prefs.setBool('is_first_time', false);
    }
  }

  void _verifyUser() {
    final authService = context.read<AuthService>();

    // Verificar que el usuario sea realmente paciente o guest
    if (authService.userType != 'Paciente' &&
        authService.userType != 'Usuario' &&
        authService.userType != 'Guest') {
      setState(() {
        _isAuthorized = false;
      });
      // Redirigir al usuario a su pantalla correcta
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('home');
      }
      return;
    }
  }

  Future<void> _loadPatientData() async {
    try {
      final authService = context.read<AuthService>();
      final patientCode = authService.patientCode;
      final isGuestMode = authService.isGuestMode;

      if (patientCode != null && patientCode.isNotEmpty && !isGuestMode) {
        final patientId = int.parse(patientCode);

        // Cargar datos del paciente
        final pacientes = await _apiService.getPacientes();
        _paciente = pacientes.firstWhere(
          (p) => p.codigo == patientId,
          orElse: () => throw Exception('Paciente no encontrado'),
        );

        // Verificar si tiene planes
        final planesNutri = await _apiService.getPlanes(patientId);
        final planesFit = await _apiService.getPlanesFit(patientId);
        _hasPlanes = planesNutri.isNotEmpty || planesFit.isNotEmpty;

        // Si no tiene planes, cargar información de contacto
        if (!_hasPlanes) {
          await _loadContactInfo();
        }
      } else if (isGuestMode) {
        // En modo guest, siempre mostrar información de contacto
        await _loadContactInfo();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadContactInfo() async {
    try {
      final email = await _apiService.getParametro('nutricionista_email');
      final telefono = await _apiService.getParametro('nutricionista_telefono');
      final telegram =
          await _apiService.getParametro('nutricionista_usuario_telegram');

      _contactInfo = {
        'email': email?['valor'] ?? '',
        'telefono': telefono?['valor'] ?? '',
        'whatsapp': telefono?['valor'] ?? '',
        'telegram': telegram?['valor'] ?? '',
      };
    } catch (e) {
      debugPrint('Error al cargar información de contacto: $e');
    }
  }

  Future<void> _loadConsejosDestacados() async {
    try {
      final authService = context.read<AuthService>();
      final patientCode = authService.patientCode;

      // Para guest mode o sin patientCode, usar 0 para obtener solo visible_para_todos
      final patientParam = patientCode ?? '0';
      final response = await _apiService.get(
        'api/consejo_usuario.php?destacados_no_leidos=1&paciente=$patientParam',
      );

      if (response.statusCode == 200) {
        try {
          final List<dynamic> data = json.decode(response.body);
          setState(() {
            _consejosDestacados = data.map((c) => Consejo.fromJson(c)).toList();
            _consejosNoLeidos = _consejosDestacados.length;
          });
        } catch (parseError) {
          // La API devolvió un error HTML en lugar de JSON (error 500, etc)
          debugPrint('Error al parsear consejos destacados: $parseError');
          debugPrint('Response body: ${response.body.substring(0, 100)}');
          setState(() {
            _consejosDestacados = [];
            _consejosNoLeidos = 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error al cargar consejos destacados: $e');
    }
  }

  Future<void> _marcarConsejoLeido(int consejoId) async {
    try {
      final authService = context.read<AuthService>();
      final patientCode = authService.patientCode;
      final isGuestMode = authService.isGuestMode;

      // No marcar como leído en modo guest
      if (isGuestMode || patientCode == null || patientCode.isEmpty) {
        return;
      }

      final data = {
        'codigo_consejo': consejoId,
        'codigo_paciente': int.parse(patientCode),
      };

      await _apiService.post(
        'api/consejo_usuario.php?marcar_leido=1',
        body: json.encode(data),
      );

      // Recargar consejos después de marcar como leído
      await _loadConsejosDestacados();
    } catch (e) {
      debugPrint('Error al marcar consejo como leído: $e');
    }
  }

  Future<void> _launchEmail(String email) async {
    if (email.isEmpty) return;

    try {
      final uri = Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: {
          'subject': 'Solicitud de servicios de Nutricionista Online',
          'body': '',
        },
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se puede abrir el email'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir el email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchPhone(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;

    try {
      final uri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se puede realizar la llamada'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al realizar la llamada: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildWelcomeCard() {
    final genero = _paciente?.sexo ?? '';
    final saludo = genero.isEmpty
        ? 'Bienvenid@'
        : (genero.toLowerCase() == 'mujer' ? 'Bienvenida' : 'Bienvenido');

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$saludo a NutriFit',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Desde aquí podrás consultar tus planes nutricionales y de entrenamiento personalizados. \n\nTambién podrás consultar Consejos de nutrición y salud y Recetas de cocina.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsejoDestacadoCard(Consejo consejo) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          _marcarConsejoLeido(consejo.codigo!);
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.lightbulb, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(child: Text(consejo.titulo)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (consejo.imagenPortada != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(consejo.imagenPortada!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(consejo.texto),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConsejoDetailScreen(
                          consejo: consejo,
                        ),
                      ),
                    ).then((_) {
                      // Recargar consejos después de ver el detalle
                      _loadConsejosDestacados();
                    });
                  },
                  child: const Text('Leer más'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/consejos_paciente');
                  },
                  child: const Text('Ver todos'),
                ),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.lightbulb, color: Colors.amber, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nuevo consejo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      consejo.titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    final authService = context.read<AuthService>();
    final hasPatient = (authService.patientCode ?? '').isNotEmpty;

    // Si es paciente con planes asociados, mostrar en acordeón plegado
    if (hasPatient && _hasPlanes) {
      return _buildContactAccordion();
    }

    // Si es paciente sin planes o guest, mostrar formas principales de contacto
    return _buildPrimaryContactCard();
  }

  Widget _buildContactAccordion() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: const Row(
          children: [
            Icon(Icons.help_outline, size: 20),
            SizedBox(width: 8),
            Text('Contactar con el dietista...'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPrimaryContactItems(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryContactCard() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Contactar con dietista online',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPrimaryContactItems(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContactoNutricionistaScreen(),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Más formas de contacto'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryContactItems() {
    final authService = context.read<AuthService>();
    final hasPatient = (authService.patientCode ?? '').isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Email - siempre se muestra si existe
        if ((_contactInfo['email'] ?? '').isNotEmpty)
          _buildSimpleContactRow(
            icon: Icons.email,
            label: hasPatient
                ? 'Enviar email a dietista'
                : 'Enviar email a dietista',
            onTap: () => _launchEmail(_contactInfo['email'] ?? ''),
          ),

        // Teléfono - solo para usuarios sin paciente o guest
        if (!hasPatient && (_contactInfo['telefono'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSimpleContactRow(
            icon: Icons.phone,
            label: 'Llamar a dietista',
            onTap: () => _launchPhone(_contactInfo['telefono'] ?? ''),
          ),
        ],
      ],
    );
  }

  /// Widget simplificado sin mostrar el valor
  Widget _buildSimpleContactRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(' $label',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Future<void> _addToContacts() async {
    // Implementación simple: mostrar un diálogo con instrucciones
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar dietista a contactos'),
        content: const Text(
          'Por favor, agrega al dietista manualmente a tus contactos con los siguientes datos:\n\n'
          'Nombre: Dietista Online - NutriFit',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handlePlanesAccess(String planType, VoidCallback onAccess) {
    final authService = context.read<AuthService>();
    final hasPatient = (authService.patientCode ?? '').isNotEmpty;

    // Si el usuario tiene paciente asociado, permitir acceso directo
    if (hasPatient) {
      onAccess();
      return;
    }

    // Si no tiene paciente, mostrar diálogo de contacto
    _showPlanesRestrictedDialog(planType);
  }

  void _showPlanesRestrictedDialog(String planType) {
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
                'Para acceder a tus planes personalizados, primero necesitas contactar con el dietista para que te asigne un plan específico, ajustado a tus necesidades.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              const Text(
                'Formas de contacto:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              // Email
              if ((_contactInfo['email'] ?? '').isNotEmpty)
                _buildDialogContactRow(
                  icon: Icons.email,
                  label: 'Email',
                  value: _contactInfo['email'] ?? '',
                  onTap: () => _launchEmail(_contactInfo['email'] ?? ''),
                ),

              // Teléfono
              if ((_contactInfo['telefono'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDialogContactRow(
                  icon: Icons.phone,
                  label: 'Teléfono',
                  value: _contactInfo['telefono'] ?? '',
                  onTap: () => _launchPhone(_contactInfo['telefono'] ?? ''),
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
            label: const Text('Más formas de contacto'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogContactRow({
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

  void _handleListaCompraNavigation(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (authService.isGuestMode) {
      // Mostrar diálogo para usuarios invitados
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Registro requerido'),
          content: const Text(
            'Para utilizar la Lista de la Compra necesitas registrarte. '
            '¿Deseas crear una cuenta ahora?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/register');
              },
              child: const Text('Registrarse'),
            ),
          ],
        ),
      );
    } else {
      // Usuario registrado: navegar a la lista de compra
      Navigator.pushNamed(context, '/lista_compra');
    }
  }

  Widget _buildHomeCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 38, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontSize:
                          (Theme.of(context).textTheme.titleSmall?.fontSize ??
                                  14) +
                              1,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si el usuario no está autorizado, mostrar una pantalla de carga mientras se redirige
    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Inicio'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          // Comentarios pendientes
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.mark_chat_unread_outlined),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MessagesInboxScreen(),
                    ),
                  );
                  if (mounted) {
                    _loadChatPendientes();
                    _loadComentariosPendientes();
                  }
                },
              ),
              if ((_comentariosNoLeidos + _chatNoLeidos) > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      (_comentariosNoLeidos + _chatNoLeidos) > 99
                          ? '99+'
                          : '${_comentariosNoLeidos + _chatNoLeidos}',
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
          // Campanita de notificaciones
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.pushNamed(context, '/consejos_paciente');
                },
              ),
              if (_consejosNoLeidos > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _consejosNoLeidos > 99 ? '99+' : '$_consejosNoLeidos',
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
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              final authService = context.read<AuthService>();
              if (authService.isGuestMode) {
                Navigator.pushNamed(context, '/register');
                return;
              }
              // Crear un objeto Usuario simplificado para la edición
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
          )
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // Tarjeta de bienvenida (solo primera vez)
                  if (_showWelcomeMessage) _buildWelcomeCard(),

                  // Consejos destacados no leídos
                  if (_consejosDestacados.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...(_consejosDestacados
                        .take(2)
                        .map((consejo) => _buildConsejoDestacadoCard(consejo))
                        .toList()),
                    if (_consejosDestacados.length > 2)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/consejos_paciente',
                              );
                            },
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(
                              'Ver todos los consejos (${_consejosDestacados.length})',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 8),

                  // Tarjeta de contacto (solo si no tiene planes)
                  if (!_hasPlanes) _buildContactCard(),

                  // Grid de botones
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.2,
                    children: [
                      _buildHomeCard(
                        context: context,
                        icon: Icons.article_outlined,
                        label: 'Planes Nutri',
                        onTap: () => _handlePlanesAccess(
                          'Planes Nutricionales',
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PlanesPacienteListScreen(),
                            ),
                          ),
                        ),
                      ),
                      _buildHomeCard(
                        context: context,
                        icon: Icons.fitness_center_outlined,
                        label: 'Planes Fit',
                        onTap: () => _handlePlanesAccess(
                          'Planes de Entrenamiento',
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PlanesFitPacienteListScreen(),
                            ),
                          ),
                        ),
                      ),
                      _buildHomeCard(
                        context: context,
                        icon: Icons.lightbulb_outlined,
                        label: 'Consejos',
                        onTap: () =>
                            Navigator.pushNamed(context, '/consejos_paciente'),
                      ),
                      _buildHomeCard(
                        context: context,
                        icon: Icons.restaurant_menu,
                        label: 'Recetas',
                        onTap: () =>
                            Navigator.pushNamed(context, '/recetas_paciente'),
                      ),
                      _buildHomeCard(
                        context: context,
                        icon: Icons.shopping_cart_outlined,
                        label: 'Lista Compra',
                        onTap: () => _handleListaCompraNavigation(context),
                      ),
                      _buildHomeCard(
                        context: context,
                        icon: Icons.fitness_center_outlined,
                        label: 'Actividades',
                        onTap: () =>
                            Navigator.pushNamed(context, '/entrenamientos'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
