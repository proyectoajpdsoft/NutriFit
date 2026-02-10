import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/entrenamiento.dart';
import '../widgets/app_drawer.dart';
import '../widgets/entrenamiento_stats_chart.dart';
import 'entrenamiento_edit_screen.dart' as edit;
import 'entrenamiento_view_screen.dart';
import 'entrenamientos_pacientes_plan_fit_screen.dart';
import 'entrenamiento_sensaciones_pendientes_screen.dart';

class EntrenamientosScreen extends StatefulWidget {
  const EntrenamientosScreen({super.key});

  @override
  State<EntrenamientosScreen> createState() => _EntrenamientosScreenState();
}

class _EntrenamientosScreenState extends State<EntrenamientosScreen>
    with SingleTickerProviderStateMixin {
  List<Entrenamiento> _entrenamientos = [];
  bool _isLoading = true;
  String _filtroActual = 'semana'; // 'semana', 'mes', 'todos'
  late TabController _tabController;
  final Map<int, int> _ejerciciosCountCache = {};
  final Map<String, String> _customActivityIcons = {};
  late bool _isNutri;
  int _sensacionesPendientes = 0;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _isNutri = authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';
    _tabController = TabController(length: _isNutri ? 5 : 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _cambiarPeriodo();
      }
    });
    _loadCustomActivityIcons();
    if (_isNutri) {
      _loadSensacionesPendientes();
    }
    _loadEntrenamientos();
  }

  Future<void> _loadSensacionesPendientes() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final items = await apiService.getSensacionesPendientesNutri();
      if (!mounted) return;
      setState(() {
        _sensacionesPendientes = items.length;
      });
    } catch (e) {
      debugPrint('Error cargando sensaciones pendientes: $e');
    }
  }

  Future<void> _loadCustomActivityIcons() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isGuestMode) return;
    if (authService.patientCode == null || authService.patientCode!.isEmpty) {
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final items = await apiService.getActividadesCustom();
      if (!mounted) return;
      setState(() {
        _customActivityIcons
          ..clear()
          ..addEntries(items.map((e) => MapEntry(e.nombre, e.icono)));
      });
    } catch (e) {
      debugPrint('Error cargando iconos custom: $e');
    }
  }

  String _getIconoActividad(String actividad) {
    return _customActivityIcons[actividad] ??
        ActividadDeportiva.getIconoActividad(actividad);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showGuestDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Registro requerido'),
        content: const Text(
          'Para agregar actividades necesitas registrarte. '
          '¿Deseas crear una cuenta ahora? Es gratis y rápido.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
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
  }

  void _agregarEntrenamiento() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isGuestMode) {
      _showGuestDialog();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const edit.EntrenamientoEditScreen(),
        ),
      ).then((_) => _loadEntrenamientos());
    }
  }

  void _cambiarPeriodo() {
    final periodos = ['semana', 'mes', 'todos'];
    if (_tabController.index < periodos.length) {
      setState(() {
        _filtroActual = periodos[_tabController.index];
      });
      _loadEntrenamientos();
    }
  }

  Future<void> _loadEntrenamientos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);
      final codigoPaciente = authService.patientCode ?? authService.userCode;

      if (codigoPaciente == null || codigoPaciente.isEmpty) {
        setState(() {
          _entrenamientos = [];
          _isLoading = false;
        });
        return;
      }

      String url =
          'api/entrenamientos.php?action=get_entrenamientos&paciente=$codigoPaciente';

      final response = await apiService.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _entrenamientos =
              data.map((item) => Entrenamiento.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _entrenamientos = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar actividades: $e')),
        );
      }
    }
  }

  Future<void> _deleteEntrenamiento(int codigo) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.delete(
          'api/entrenamientos.php?action=delete_entrenamiento&codigo=$codigo');

      if (response.statusCode == 200) {
        _loadEntrenamientos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Actividad eliminada')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  List<Entrenamiento> _filtrarEntrenamientos() {
    final ahora = DateTime.now();

    if (_filtroActual == 'semana') {
      final hace7Dias = ahora.subtract(const Duration(days: 7));
      return _entrenamientos.where((e) => e.fecha.isAfter(hace7Dias)).toList();
    } else if (_filtroActual == 'mes') {
      final hace30Dias = ahora.subtract(const Duration(days: 30));
      return _entrenamientos.where((e) => e.fecha.isAfter(hace30Dias)).toList();
    }

    return _entrenamientos;
  }

  int _getTotalMinutos(List<Entrenamiento> entrenamientos) {
    return entrenamientos.fold(
        0, (sum, e) => sum + ((e.duracionHoras * 60) + e.duracionMinutos));
  }

  double _getTotalKilometros(List<Entrenamiento> entrenamientos) {
    return entrenamientos.fold(
        0.0,
        (sum, e) =>
            sum + (e.duracionKilometros != null ? e.duracionKilometros! : 0));
  }

  double _getPromedioEsfuerzo(List<Entrenamiento> entrenamientos) {
    if (entrenamientos.isEmpty) return 0;
    final suma = entrenamientos.fold(0, (sum, e) => sum + e.nivelEsfuerzo);
    return suma / entrenamientos.length;
  }

  Future<int> _getEjerciciosCountForEntrenamiento(int codigo) async {
    final cached = _ejerciciosCountCache[codigo];
    if (cached != null) {
      return cached;
    }
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final ejercicios = await apiService.getEntrenamientoEjercicios(codigo);
      _ejerciciosCountCache[codigo] = ejercicios.length;
      return ejercicios.length;
    } catch (_) {
      _ejerciciosCountCache[codigo] = 0;
      return 0;
    }
  }

  Future<int> _getTotalEjercicios(List<Entrenamiento> entrenamientos) async {
    final codigos = entrenamientos
        .where((e) => e.codigo != null)
        .map((e) => e.codigo!)
        .toList();
    if (codigos.isEmpty) {
      return 0;
    }
    var total = 0;
    for (final codigo in codigos) {
      total += await _getEjerciciosCountForEntrenamiento(codigo);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final entrenamientosFiltrados = _filtrarEntrenamientos();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mis actividades'),
        elevation: 0,
        actions: [
          if (_isNutri)
            IconButton(
              tooltip: 'Sensaciones de ejercicios pendientes',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const EntrenamientoSensacionesPendientesScreen(),
                  ),
                );
                if (mounted) {
                  _loadSensacionesPendientes();
                }
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.mark_chat_unread_outlined),
                  if (_sensacionesPendientes > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _sensacionesPendientes > 99
                              ? '99+'
                              : _sensacionesPendientes.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Scrollbar(
            thumbVisibility: true,
            child: TabBar(
              controller: _tabController,
              tabs: [
                const Tab(text: 'Semana'),
                const Tab(text: 'Mes'),
                const Tab(text: 'Todos'),
                const Tab(text: 'Estadísticas'),
                if (_isNutri) const Tab(text: 'Pacientes'),
              ],
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarEntrenamiento,
        tooltip: 'Agregar actividad',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Pestaña 1: Esta semana
                _buildListView('semana'),
                // Pestaña 2: Este mes
                _buildListView('mes'),
                // Pestaña 3: Todos
                _buildListView('todos'),
                // Pestaña 4: Estadísticas
                EntrenamientoStatsChart(entrenamientos: _entrenamientos),
                if (_isNutri) const EntrenamientosPacientesPlanFitScreen(),
              ],
            ),
    );
  }

  Widget _buildListView(String periodo) {
    String filtroTemp = _filtroActual;
    _filtroActual = periodo;
    final entrenamientosFiltrados = _filtrarEntrenamientos();
    _filtroActual = filtroTemp;

    final totalMinutos = _getTotalMinutos(entrenamientosFiltrados);
    final totalKilometros = _getTotalKilometros(entrenamientosFiltrados);
    final promedioEsfuerzo = _getPromedioEsfuerzo(entrenamientosFiltrados);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
          left: 12.0, right: 12.0, top: 12.0, bottom: 80.0),
      child: Column(
        children: [
          // Tarjeta de estadísticas
          if (entrenamientosFiltrados.isNotEmpty) ...[
            _buildEstadisticasCard(
              entrenamientosFiltrados,
              totalMinutos,
              totalKilometros,
              promedioEsfuerzo,
            ),
            const SizedBox(height: 16),
          ],

          // Tarjeta motivacional
          _buildTarjetaMotivacional(entrenamientosFiltrados),
          const SizedBox(height: 16),

          // Lista de entrenamientos
          if (entrenamientosFiltrados.isEmpty)
            _buildEmptyState()
          else
            ...(entrenamientosFiltrados
                .map((e) => _buildEntrenamientoCard(e))
                .toList()),
        ],
      ),
    );
  }

  Widget _buildEstadisticasCard(
    List<Entrenamiento> entrenamientos,
    int totalMinutos,
    double totalKilometros,
    double promedioEsfuerzo,
  ) {
    final horas = totalMinutos ~/ 60;
    final minutos = totalMinutos % 60;
    final totalEjerciciosFuture = _getTotalEjercicios(entrenamientos);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  '💪',
                  '${entrenamientos.length}',
                  'Actividades',
                  Colors.white,
                ),
                FutureBuilder<int>(
                  future: totalEjerciciosFuture,
                  builder: (context, snapshot) {
                    final totalEjercicios = snapshot.data ?? 0;
                    return _buildStatItem(
                      '🏋️',
                      totalEjercicios.toString(),
                      'Ejercicios',
                      Colors.white,
                    );
                  },
                ),
                _buildStatItem(
                  '⏱️',
                  '${horas}h ${minutos}m',
                  'Tiempo total',
                  Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  '🔥',
                  promedioEsfuerzo.toStringAsFixed(1),
                  'Esfuerzo avg',
                  Colors.white,
                ),
                if (totalKilometros > 0)
                  _buildStatItem(
                    '📍',
                    totalKilometros.toStringAsFixed(2),
                    'Kilómetros',
                    Colors.white,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String emoji,
    String valor,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 8),
        Text(
          valor,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildTarjetaMotivacional(List<Entrenamiento> entrenamientos) {
    String mensaje = '';
    String emoji = '';

    if (entrenamientos.isEmpty) {
      mensaje = '¡Vamos! 💪\nEs hora de comenzar tu primera actividad.';
      emoji = '🚀';
    } else if (entrenamientos.length == 1) {
      mensaje = '¡Excelente comienzo! 🌟\nYa tienes tu primera actividad.';
      emoji = '👏';
    } else if (entrenamientos.length < 3) {
      mensaje = '¡Vas muy bien! 🔥\nSigue así, poco a poco.';
      emoji = '💪';
    } else if (entrenamientos.length < 5) {
      mensaje = '¡Increíble! ⭐\nTienes una racha muy buena.';
      emoji = '🏆';
    } else {
      mensaje = '¡Eres un campeón! 🥇\nTus actividades son consistentes.';
      emoji = '👑';
    }

    return Card(
      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                mensaje,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntrenamientoCard(Entrenamiento entrenamiento) {
    final duracion =
        '${entrenamiento.duracionHoras}h ${entrenamiento.duracionMinutos}m';
    final kmText = entrenamiento.duracionKilometros != null &&
            entrenamiento.duracionKilometros! > 0
        ? ' • ${entrenamiento.duracionKilometros!.toStringAsFixed(2)} km'
        : '';
    final icono = _getIconoActividad(entrenamiento.actividad);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  EntrenamientoViewScreen(entrenamiento: entrenamiento),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(icono, style: const TextStyle(fontSize: 28)),
            ),
          ),
          title: Text(
            entrenamiento.actividad,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '📅 ${entrenamiento.fecha.day}/${entrenamiento.fecha.month}/${entrenamiento.fecha.year} ${entrenamiento.fecha.hour.toString().padLeft(2, '0')}:${entrenamiento.fecha.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '⏱️ $duracion$kmText',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${Entrenamiento.getIconoNivelEsfuerzo(entrenamiento.nivelEsfuerzo)} ${entrenamiento.textoNivelEsfuerzo}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    entrenamiento.validado == true
                        ? Icons.verified
                        : Icons.pending_actions,
                    size: 16,
                    color: entrenamiento.validado == true
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    entrenamiento.validado == true
                        ? 'Validado por dietista'
                        : 'Pendiente de validar',
                    style: TextStyle(
                      fontSize: 12,
                      color: entrenamiento.validado == true
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EntrenamientoViewScreen(
                              entrenamiento: entrenamiento),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Visualizar'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => edit.EntrenamientoEditScreen(
                            entrenamiento: entrenamiento,
                          ),
                        ),
                      ).then((_) => _loadEntrenamientos());
                    },
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Eliminar actividad'),
                          content: const Text(
                              '¿Estás seguro de que deseas eliminar esta actividad?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteEntrenamiento(entrenamiento.codigo!);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Text(
              '🏃‍♂️',
              style: TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin entrenamientos registrados',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Comienza a registrar tus entrenamientos para ver tus progresos',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _agregarEntrenamiento,
              icon: const Icon(Icons.add),
              label: const Text('Agregar entrenamiento'),
            ),
          ],
        ),
      ),
    );
  }
}
