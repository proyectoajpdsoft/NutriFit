import 'package:flutter/material.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/models/session.dart';
import 'package:nutri_app/screens/parametros/parametro_edit_screen.dart'
    as parametro;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 10,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Configuración'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight),
            child: Scrollbar(
              thumbVisibility: true,
              child: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Parámetros'),
                  Tab(text: 'General'),
                  Tab(text: 'Seguridad'),
                  Tab(text: 'Usuario'),
                  Tab(text: 'Citas'),
                  Tab(text: 'Entrevistas'),
                  Tab(text: 'Revisiones'),
                  Tab(text: 'Planes'),
                  Tab(text: 'Pacientes'),
                  Tab(text: 'Clientes'),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            _ParametrosTab(),
            _GeneralTab(),
            _SecurityTab(),
            _UsuarioTab(),
            _CitasTab(),
            _EntrevistasTab(),
            _RevisionesTab(),
            _PlanesTab(),
            _PacientesTab(),
            _ClientesTab(),
          ],
        ),
      ),
    );
  }
}

// Tab General
class _GeneralTab extends StatelessWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Modo Depuración (Debug)'),
          subtitle: const Text(
              'Muestra errores detallados de la API en la aplicación.'),
          value: configService.appMode == AppMode.debug,
          onChanged: (bool value) {
            final newMode = value ? AppMode.debug : AppMode.normal;
            context.read<ConfigService>().setAppMode(newMode);
          },
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.bug_report),
            label: const Text('Abrir Pantalla de Debug'),
            onPressed: () {
              Navigator.pushNamed(context, 'debug');
            },
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

// Tab Seguridad
class _SecurityTab extends StatelessWidget {
  const _SecurityTab();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: const Scrollbar(
              thumbVisibility: true,
              child: TabBar(
                tabs: [
                  Tab(text: 'Sesiones'),
                  Tab(text: 'Acceso'),
                ],
              ),
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _SessionsSubTab(),
                _AccessSubTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// SubTab de Sesiones (contenido anterior de _SecurityTab)
class _SessionsSubTab extends StatefulWidget {
  const _SessionsSubTab();

  @override
  State<_SessionsSubTab> createState() => _SessionsSubTabState();
}

class _SessionsSubTabState extends State<_SessionsSubTab> {
  late Future<SessionResponse> _sessionDataFuture;

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  void _loadSessionData() {
    final apiService = context.read<ApiService>();
    final authService = context.read<AuthService>();
    final usuarioCode = authService.userCode;

    if (usuarioCode != null) {
      _sessionDataFuture = apiService.getSessionData(usuarioCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final usuarioCode = authService.userCode;

    if (usuarioCode == null) {
      return const Center(
        child: Text('Código de usuario no disponible'),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _loadSessionData();
        });
        await _sessionDataFuture;
      },
      child: FutureBuilder<SessionResponse>(
        future: _sessionDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                      onPressed: () {
                        setState(() {
                          _loadSessionData();
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text('No hay datos de sesión disponibles'),
            );
          }

          final sessionData = snapshot.data!;
          final ultimasSesionesExitosas = sessionData.ultimasSesionesExitosas;
          final ultimosIntentosFallidos = sessionData.ultimosIntentosFallidos;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Card de últimas sesiones exitosas
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.security, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Últimos Inicios de Sesión Exitosos',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (ultimasSesionesExitosas.isNotEmpty) ...[
                        for (int i = 0;
                            i < ultimasSesionesExitosas.length;
                            i++) ...[
                          if (i > 0) const Divider(height: 24),
                          Text(
                            i == 0 ? 'Sesión actual:' : 'Sesión anterior:',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildSessionInfo(ultimasSesionesExitosas[i]),
                        ],
                      ] else
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('No hay sesiones exitosas registradas'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Card de últimos intentos fallidos
              if (ultimosIntentosFallidos.isNotEmpty)
                Card(
                  elevation: 2,
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Últimos Intentos de Acceso Fallidos',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (int i = 0;
                            i < ultimosIntentosFallidos.length;
                            i++) ...[
                          if (i > 0) const Divider(height: 24),
                          Text(
                            'Intento ${i + 1}:',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildSessionInfo(ultimosIntentosFallidos[i]),
                        ],
                      ],
                    ),
                  ),
                )
              else if (ultimasSesionesExitosas.isNotEmpty)
                Card(
                  elevation: 2,
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green.shade700, size: 24),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'No hay intentos fallidos registrados.',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              // Card de estadísticas totales
              Card(
                elevation: 1,
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estadísticas de Sesiones',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.analytics,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Total de sesiones: ${sessionData.totalSesiones}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Intentos exitosos: ${sessionData.totalExitosas}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.error, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            'Intentos fallidos: ${sessionData.totalFallidas}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSessionInfo(SessionLog sesion) {
    final fechaFormato = sesion.fecha;
    final horaFormato = sesion.hora ?? 'N/A';
    final tipoDispositivo = sesion.tipo ?? 'N/A';
    final ipPublica = sesion.ipPublica ?? '-';
    final ipLocal = sesion.ipLocal ?? '-';

    // Función para obtener el icono según el tipo de dispositivo
    IconData getDeviceIcon(String? tipo) {
      switch (tipo) {
        case 'Android':
          return Icons.android;
        case 'iOS':
          return Icons.apple;
        case 'Web':
          return Icons.computer;
        default:
          return Icons.devices;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 8),
            Text(
              'Fecha: $fechaFormato',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.access_time, size: 18),
            const SizedBox(width: 8),
            Text(
              'Hora: $horaFormato',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(getDeviceIcon(sesion.tipo), size: 18),
            const SizedBox(width: 8),
            Text(
              'Dispositivo: $tipoDispositivo',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 16),
        const Text(
          'Dirección IP:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.public, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pública: $ipPublica',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              const Icon(Icons.router, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Local: $ipLocal',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Nueva SubTab de Acceso
class _AccessSubTab extends StatefulWidget {
  const _AccessSubTab();

  @override
  State<_AccessSubTab> createState() => _AccessSubTabState();
}

class _AccessSubTabState extends State<_AccessSubTab> {
  late TextEditingController _minLengthController;
  bool _requireUpperLower = false;
  bool _requireNumbers = false;
  bool _requireSpecialChars = false;
  bool _isLoading = true;
  bool _isSaving = false;

  static const String _categoryName = 'complejidad_contraseña';

  @override
  void initState() {
    super.initState();
    _minLengthController = TextEditingController(text: '8');
    _loadPasswordPolicies();
  }

  Future<void> _loadPasswordPolicies() async {
    try {
      final apiService = context.read<ApiService>();

      final minLengthParam = await apiService.getParametro(
        '${_categoryName}_longitud_minima',
      );
      final upperLowerParam = await apiService.getParametro(
        '${_categoryName}_mayuscula_minuscula',
      );
      final numbersParam = await apiService.getParametro(
        '${_categoryName}_numeros',
      );
      final specialCharsParam = await apiService.getParametro(
        '${_categoryName}_caracteres_especiales',
      );

      setState(() {
        if (minLengthParam != null) {
          _minLengthController.text =
              minLengthParam['valor']?.toString() ?? '8';
        }
        _requireUpperLower = upperLowerParam != null &&
            (upperLowerParam['valor'] == 'S' ||
                upperLowerParam['valor'] == '1');
        _requireNumbers = numbersParam != null &&
            (numbersParam['valor'] == 'S' || numbersParam['valor'] == '1');
        _requireSpecialChars = specialCharsParam != null &&
            (specialCharsParam['valor'] == 'S' ||
                specialCharsParam['valor'] == '1');
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar políticas. $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _savePasswordPolicies() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final apiService = context.read<ApiService>();

      // Guardar longitud mínima
      await apiService.updateParametro(
        nombre: '${_categoryName}_longitud_minima',
        valor: _minLengthController.text,
        categoria: 'Aplicación',
        tipo: 'General',
        descripcion:
            'Número de caracteres mínimo que deben tener todas las contraseñas de los usuarios del sistema.',
      );

      // Guardar mayúscula y minúscula
      await apiService.updateParametro(
        nombre: '${_categoryName}_mayuscula_minuscula',
        valor: _requireUpperLower ? 'S' : 'N',
        categoria: 'Aplicación',
        tipo: 'General',
        descripcion:
            'Indica si las contraseñas de los usuarios deben contener al menos una letra mayúscula y una letra minúscula.',
      );

      // Guardar números
      await apiService.updateParametro(
        nombre: '${_categoryName}_numeros',
        valor: _requireNumbers ? 'S' : 'N',
        categoria: 'Aplicación',
        tipo: 'General',
        descripcion:
            'Indica si las contraseñas de los usuarios deben contener al menos un número (0-9).',
      );

      // Guardar caracteres especiales
      await apiService.updateParametro(
        nombre: '${_categoryName}_caracteres_especiales',
        valor: _requireSpecialChars ? 'S' : 'N',
        categoria: 'Aplicación',
        tipo: 'General',
        descripcion:
            'Indica si las contraseñas de los usuarios deben contener al menos un carácter especial (* , . + - # \$ ? ¿ ! ¡ _ ( ) / \\ % &).',
      );

      setState(() {
        _isSaving = false;
      });

      // Actualizar ConfigService con los nuevos valores
      final configService = context.read<ConfigService>();
      await configService.loadPasswordPoliciesFromDatabase(apiService);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Políticas de contraseña guardadas correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar políticas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _minLengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.password, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Políticas de Contraseña',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Configura los requisitos que deben cumplir las contraseñas al crear o modificar usuarios. Esta configuración se aplica a todos los usuarios.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const Divider(height: 32),

                    // Longitud mínima
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Longitud Mínima',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Número mínimo de caracteres para la contraseña',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _minLengthController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            enabled: !_isSaving,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              suffix: Text('chars'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Requiere mayúsculas y minúsculas
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CheckboxListTile(
                        enabled: !_isSaving,
                        title: const Text(
                          'Requiere Mayúsculas y Minúsculas',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'La contraseña debe contener al menos una letra mayúscula y una minúscula',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _requireUpperLower,
                        onChanged: (value) {
                          setState(() {
                            _requireUpperLower = value ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Requiere números
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CheckboxListTile(
                        enabled: !_isSaving,
                        title: const Text(
                          'Requiere Números',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'La contraseña debe contener al menos un número (0-9)',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _requireNumbers,
                        onChanged: (value) {
                          setState(() {
                            _requireNumbers = value ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Requiere caracteres especiales
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CheckboxListTile(
                        enabled: !_isSaving,
                        title: const Text(
                          'Requiere Caracteres Especiales',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Debe contener al menos uno de: * , . + - # \$ ? ¿ ! ¡ - _ ( ) / \\ % &',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _requireSpecialChars,
                        onChanged: (value) {
                          setState(() {
                            _requireSpecialChars = value ?? false;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Botón guardar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _savePasswordPolicies,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _isSaving ? 'Guardando...' : 'Guardar Políticas',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Estas políticas se guardan a nivel de base de datos y se aplicarán a todos los usuarios de la aplicación.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Tab Citas
class _CitasTab extends StatefulWidget {
  const _CitasTab();

  @override
  State<_CitasTab> createState() => _CitasTabState();
}

class _CitasTabState extends State<_CitasTab> {
  List<String> tiposCita = [];
  bool _isLoadingTipos = true;
  late ApiService _apiService;
  String _citasView = 'list';

  static const estadosCita = ["Pendiente", "Realizada", "Anulada", "Aplazada"];

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _loadCitasViewPref();
    _loadTiposCita();
  }

  Future<void> _loadCitasViewPref() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('citas_default_view') ?? 'list';
    if (!mounted) return;
    setState(() {
      _citasView = value;
    });
  }

  Future<void> _saveCitasViewPref(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('citas_default_view', value);
  }

  Future<void> _loadTiposCita() async {
    try {
      final tiposStr = await _apiService.getParametroValor('tipos_de_citas');
      if (tiposStr != null && tiposStr.isNotEmpty) {
        setState(() {
          tiposCita = tiposStr
              .split(';')
              .map((tipo) => tipo.trim().replaceAll('"', ''))
              .toList();
          _isLoadingTipos = false;
        });
      } else {
        _setDefaultTipos();
      }
    } catch (e) {
      // debugPrint('Error al cargar tipos de citas: $e');
      _setDefaultTipos();
    }
  }

  void _setDefaultTipos() {
    setState(() {
      tiposCita = [
        "Entrevista Nutri",
        "Entrevista Fit",
        "Revisión Nutri",
        "Revisión Fit",
        "Asistencia/Dudas",
        "Charla",
        "Medición",
        "Otro"
      ];
      _isLoadingTipos = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visualizar citas',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'calendar', label: Text('Calendario')),
                ButtonSegment(value: 'list', label: Text('Lista')),
              ],
              selected: {_citasView},
              onSelectionChanged: (Set<String> newSelection) {
                final nextValue = newSelection.first;
                setState(() {
                  _citasView = nextValue;
                });
                _saveCitasViewPref(nextValue);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingTipos)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Cargando tipos de cita...'),
                ],
              ),
            ),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: tiposCita.contains(configService.defaultTipoCita)
                ? configService.defaultTipoCita
                : null,
            decoration: const InputDecoration(
              labelText: 'Tipo de Cita por defecto',
              border: OutlineInputBorder(),
            ),
            items: tiposCita
                .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)))
                .toList(),
            onChanged: (value) {
              context.read<ConfigService>().setDefaultTipoCita(value);
            },
          ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: configService.defaultEstadoCita,
          decoration: const InputDecoration(
            labelText: 'Estado de Cita por defecto',
            border: OutlineInputBorder(),
          ),
          items: estadosCita
              .map((estado) =>
                  DropdownMenuItem(value: estado, child: Text(estado)))
              .toList(),
          onChanged: (value) {
            context.read<ConfigService>().setDefaultEstadoCita(value);
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Cita Online por defecto'),
          value: configService.defaultOnlineCita,
          onChanged: (bool value) {
            context.read<ConfigService>().setDefaultOnlineCita(value);
          },
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

// Tab Entrevistas
class _EntrevistasTab extends StatelessWidget {
  const _EntrevistasTab();

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Entrevista Completada por defecto'),
          value: configService.defaultCompletadaEntrevista,
          onChanged: (bool value) {
            context.read<ConfigService>().setDefaultCompletadaEntrevista(value);
          },
        ),
        SwitchListTile(
          title: const Text('Entrevista Online por defecto'),
          value: configService.defaultOnlineEntrevista,
          onChanged: (bool value) {
            context.read<ConfigService>().setDefaultOnlineEntrevista(value);
          },
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

// Tab Revisiones
class _RevisionesTab extends StatelessWidget {
  const _RevisionesTab();

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Revisión Completada por defecto'),
          value: configService.defaultCompletadaRevision,
          onChanged: (bool value) {
            context.read<ConfigService>().setDefaultCompletadaRevision(value);
          },
        ),
        SwitchListTile(
          title: const Text('Revisión Online por defecto'),
          value: configService.defaultOnlineRevision,
          onChanged: (bool value) {
            context.read<ConfigService>().setDefaultOnlineRevision(value);
          },
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

// Tab Planes
class _PlanesTab extends StatelessWidget {
  const _PlanesTab();

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Plan Completado por defecto'),
          value: configService.defaultCompletadaPlan,
          onChanged: (bool value) {
            context.read<ConfigService>().setDefaultCompletadaPlan(value);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: configService.defaultSemanasPlan,
          decoration: const InputDecoration(
            labelText: 'Semanas por defecto',
            border: OutlineInputBorder(),
            hintText: 'Ej: 1, 2, 3, 4',
          ),
          onChanged: (value) {
            context.read<ConfigService>().setDefaultSemanasPlan(value);
          },
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

// Tab Pacientes
class _PacientesTab extends StatelessWidget {
  const _PacientesTab();

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Online por defecto'),
          value: configService.defaultOnlinePaciente,
          onChanged: (bool value) {
            context.read<ConfigService>().setDefaultOnlinePaciente(value);
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Activo por defecto'),
          value: configService.defaultActivoPaciente,
          onChanged: (bool value) {
            context.read<ConfigService>().setDefaultActivoPaciente(value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          initialValue: configService.defaultSexoPaciente,
          decoration: const InputDecoration(
            labelText: 'Sexo por defecto',
            border: OutlineInputBorder(),
          ),
          items: const <DropdownMenuItem<String?>>[
            DropdownMenuItem<String?>(
                value: null, child: Text('(Sin especificar)')),
            DropdownMenuItem<String?>(value: 'Hombre', child: Text('Hombre')),
            DropdownMenuItem<String?>(value: 'Mujer', child: Text('Mujer')),
          ],
          onChanged: (value) {
            context.read<ConfigService>().setDefaultSexoPaciente(value);
          },
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

// Tab Clientes
class _ClientesTab extends StatelessWidget {
  const _ClientesTab();

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          initialValue: configService.defaultPoblacionCliente,
          decoration: const InputDecoration(
            labelText: 'Población por defecto',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            context.read<ConfigService>().setDefaultPoblacionCliente(value);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: configService.defaultProvinciaCliente,
          decoration: const InputDecoration(
            labelText: 'Provincia por defecto',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            context.read<ConfigService>().setDefaultProvinciaCliente(value);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: configService.defaultCPCliente,
          decoration: const InputDecoration(
            labelText: 'Código Postal por defecto',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            context.read<ConfigService>().setDefaultCPCliente(value);
          },
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

// Tab Usuario
class _UsuarioTab extends StatefulWidget {
  const _UsuarioTab();

  @override
  State<_UsuarioTab> createState() => _UsuarioTabState();
}

class _UsuarioTabState extends State<_UsuarioTab> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  // Valores por defecto
  double _maxImageSizeKb = 500.0;
  String _defaultUserType = 'Paciente';
  bool _defaultActivo = true;
  bool _defaultAcceso = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final configService = context.read<ConfigService>();

      // Cargar tamaño máximo de imagen (desde base de datos - global)
      final sizeParam = await _apiService.getParametro('usuario_max_imagen_kb');
      if (sizeParam != null) {
        _maxImageSizeKb = double.tryParse(sizeParam['valor'] ?? '500') ?? 500.0;
      }

      // Cargar valores por defecto locales
      _defaultUserType = configService.defaultTipoUsuario;
      _defaultActivo = configService.defaultActivoUsuario;
      _defaultAcceso = configService.defaultAccesoUsuario;
    } catch (e) {
      // Si no existen, usar valores por defecto
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveConfig() async {
    try {
      final configService = context.read<ConfigService>();

      // Guardar tamaño máximo de imagen (en base de datos - global)
      await _apiService.updateParametroValor(
        nombre: 'usuario_max_imagen_kb',
        valor: _maxImageSizeKb.round().toString(),
      );

      // Guardar valores por defecto locales
      await configService.setDefaultTipoUsuario(_defaultUserType);
      await configService.setDefaultActivoUsuario(_defaultActivo);
      await configService.setDefaultAccesoUsuario(_defaultAcceso);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sección: Tamaño de imagen
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tamaño de imagen de perfil',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tamaño máximo permitido: ${_maxImageSizeKb.round()} KB',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _maxImageSizeKb,
                  min: 1,
                  max: 3000,
                  divisions: 2999,
                  label: '${_maxImageSizeKb.round()} KB',
                  onChanged: (value) {
                    setState(() {
                      _maxImageSizeKb = value;
                    });
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1 KB', style: TextStyle(color: Colors.grey[600])),
                    Text('3000 KB', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Sección: Valores por defecto
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Valores por defecto en alta de usuario',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                // Tipo de usuario por defecto
                DropdownButtonFormField<String>(
                  initialValue: _defaultUserType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de usuario por defecto',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Paciente',
                      child: Text('Paciente'),
                    ),
                    DropdownMenuItem(
                      value: 'Nutricionista',
                      child: Text('Nutricionista'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _defaultUserType = value ?? 'Paciente';
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Activo por defecto
                SwitchListTile(
                  title: const Text('Activo por defecto'),
                  subtitle: const Text(
                    'Los nuevos usuarios se crearán activos',
                  ),
                  value: _defaultActivo,
                  onChanged: (value) {
                    setState(() {
                      _defaultActivo = value;
                    });
                  },
                ),
                // Acceso por defecto
                SwitchListTile(
                  title: const Text('Permitir acceso por defecto'),
                  subtitle: const Text(
                    'Los nuevos usuarios tendrán acceso habilitado',
                  ),
                  value: _defaultAcceso,
                  onChanged: (value) {
                    setState(() {
                      _defaultAcceso = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Botón guardar
        ElevatedButton.icon(
          onPressed: _saveConfig,
          icon: const Icon(Icons.save),
          label: const Text('Guardar configuración'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

// Tab Parámetros
class _ParametrosTab extends StatefulWidget {
  const _ParametrosTab();

  @override
  State<_ParametrosTab> createState() => _ParametrosTabState();
}

class _ParametrosTabState extends State<_ParametrosTab> {
  late Future<List<dynamic>> _parametrosFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String? _userType;

  @override
  void initState() {
    super.initState();
    _loadParametros();
    _loadUserType();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
  }

  void _loadUserType() {
    final authService = context.read<AuthService>();
    _userType = authService.userType;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadParametros() {
    final apiService = context.read<ApiService>();
    _parametrosFuture = apiService.getParametros();
  }

  void _refresh() {
    setState(() {
      _loadParametros();
    });
  }

  List<dynamic> _filterParametros(List<dynamic> parametros) {
    if (_searchText.isEmpty) {
      return parametros;
    }

    return parametros.where((parametro) {
      final nombre = (parametro['nombre'] ?? '').toString().toLowerCase();
      final valor = (parametro['valor'] ?? '').toString().toLowerCase();
      final valor2 = (parametro['valor2'] ?? '').toString().toLowerCase();
      final descripcion =
          (parametro['descripcion'] ?? '').toString().toLowerCase();

      return nombre.contains(_searchText) ||
          valor.contains(_searchText) ||
          valor2.contains(_searchText) ||
          descripcion.contains(_searchText);
    }).toList();
  }

  String _truncateText(String? text, {int maxLength = 200, int maxLines = 2}) {
    if (text == null || text.isEmpty) return '';

    // Contar líneas
    final lines = text.split('\n');
    if (lines.length > maxLines) {
      text = lines.take(maxLines).join('\n');
    }

    // Truncar por caracteres
    if (text.length > maxLength) {
      return '${text.substring(0, maxLength)}...';
    }

    return text;
  }

  Future<void> _deleteParametro(Map<String, dynamic> parametro) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Desea eliminar el parámetro "${parametro['nombre']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final apiService = context.read<ApiService>();
        await apiService.deleteParametro(parametro['codigo']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parámetro eliminado')),
          );
          _refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Campo de búsqueda
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, valor o descripción...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          // Lista de parámetros
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _refresh();
                await _parametrosFuture;
              },
              child: FutureBuilder<List<dynamic>>(
                future: _parametrosFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: ${snapshot.error}'),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                              onPressed: _refresh,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final allParametros = snapshot.data ?? [];
                  final parametros = _filterParametros(allParametros);

                  if (allParametros.isEmpty) {
                    return const Center(
                      child: Text('No hay parámetros registrados'),
                    );
                  }

                  if (parametros.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron parámetros',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Intenta con otros términos de búsqueda',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 8,
                      top: 8,
                      bottom: 80,
                    ),
                    itemCount: parametros.length,
                    itemBuilder: (context, index) {
                      final paramData = parametros[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            paramData['nombre'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                _truncateText(paramData['valor']),
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (paramData['descripcion'] != null &&
                                  paramData['descripcion']
                                      .toString()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  paramData['descripcion'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_userType == 'Nutricionista')
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            parametro.ParametroEditScreen(
                                                parametro: paramData),
                                      ),
                                    );
                                    if (result == true) {
                                      _refresh();
                                    }
                                  },
                                ),
                              if (_userType == 'Nutricionista')
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteParametro(paramData),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _userType == 'Nutricionista'
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const parametro.ParametroEditScreen(),
                  ),
                );
                if (result == true) {
                  _refresh();
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
