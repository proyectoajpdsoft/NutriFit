import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/config_service.dart';
import '../models/entrenamiento.dart';
import '../models/entrenamiento_ejercicio.dart';
import '../widgets/app_drawer.dart';
import '../widgets/entrenamiento_evolution_tabs.dart';
import '../widgets/entrenamiento_stats_chart.dart';
import '../widgets/entrenamiento_weight_progress_chart.dart';
import 'entrenamiento_edit_screen.dart' as edit;
import 'entrenamiento_view_screen.dart';
import 'entrenamientos_pacientes_plan_fit_screen.dart';
import 'entrenamiento_sensaciones_pendientes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EntrenamientosScreen extends StatefulWidget {
  const EntrenamientosScreen({super.key});

  @override
  State<EntrenamientosScreen> createState() => _EntrenamientosScreenState();
}

class _EntrenamientosScreenState extends State<EntrenamientosScreen>
    with SingleTickerProviderStateMixin {
  List<Entrenamiento> _entrenamientos = [];
  bool _isLoading = true;
  String _periodoFiltro = 'semana_actual';
  late TabController _tabController;
  bool _mostrarFiltroPeriodo = false;
  int _ultimosDiasFiltro = 30;
  final Map<int, int> _ejerciciosCountCache = {};
  final Map<int, List<EntrenamientoEjercicio>> _ejerciciosCache = {};
  final Map<String, String> _customActivityIcons = {};
  late bool _isNutri;
  int _sensacionesPendientes = 0;
  bool _showTotalsBox = true;
  bool _showEquivalenciasBox = true;
  bool _showMotivacionalBox = true;

  static const String _prefsFiltroVisibleKey = 'entrenamientos_filtro_visible';
  static const String _prefsFiltroPeriodoKey = 'entrenamientos_filtro_periodo';
  static const String _prefsFiltroUltimosDiasKey =
      'entrenamientos_filtro_ultimos_dias';

  static const List<int> _ultimosDiasSugeridos = [
    15,
    30,
    60,
    90,
    120,
    160,
    180,
    365,
  ];

  static const Map<String, String> _periodosFiltro = {
    'semana_actual': 'Semana',
    'mes_actual': 'Mes',
    'mes_anterior': 'Mes anterior',
    'trimestre': 'Trimestre',
    'semestre': 'Semestre',
    'anio_actual': 'Año actual',
    'anio_anterior': 'Año anterior',
    'siempre': 'Siempre',
    'ultimos_dias': 'Últimos .. días',
  };

  String get _localeName => Localizations.localeOf(context).toString();

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _isNutri = authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';
    _tabController = TabController(length: _isNutri ? 4 : 3, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    _loadCustomActivityIcons();
    _loadFiltroPreferences();
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
      // debugPrint('Error cargando sensaciones pendientes: $e');
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
      // debugPrint('Error cargando iconos custom: $e');
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

  bool _shouldShowSharedFilterCard() {
    if (!_mostrarFiltroPeriodo) return false;
    if (!_isNutri) return true;
    // En modo nutricionista, solo mostrar en pestañas de actividades
    // (Listado y Estadísticas), no en Pacientes.
    return _tabController.index != 0;
  }

  void _showGuestDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Registro requerido'),
        content: const Text(
          'Para poder añadir actividades, debes registrarte (es gratis).',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/register');
            },
            icon: const Icon(Icons.app_registration),
            label: const Text('Iniciar registro'),
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
        _ejerciciosCountCache.clear();
        _ejerciciosCache.clear();
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
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar actividades. $errorMessage')),
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

  Future<void> _loadFiltroPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final visible = prefs.getBool(_prefsFiltroVisibleKey);
    final periodo = prefs.getString(_prefsFiltroPeriodoKey);
    final ultimosDias = prefs.getInt(_prefsFiltroUltimosDiasKey);

    if (!mounted) return;
    setState(() {
      if (visible != null) {
        _mostrarFiltroPeriodo = visible;
      }
      if (periodo != null && _periodosFiltro.containsKey(periodo)) {
        _periodoFiltro = periodo;
      }
      if (ultimosDias != null && ultimosDias > 0) {
        _ultimosDiasFiltro = ultimosDias;
      }
    });
  }

  Future<void> _saveFiltroPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsFiltroVisibleKey, _mostrarFiltroPeriodo);
    await prefs.setString(_prefsFiltroPeriodoKey, _periodoFiltro);
    await prefs.setInt(_prefsFiltroUltimosDiasKey, _ultimosDiasFiltro);
  }

  String _getPeriodoLabel(String key) {
    if (key == 'ultimos_dias') {
      return 'Últimos $_ultimosDiasFiltro días';
    }
    return _periodosFiltro[key] ?? key;
  }

  Future<int?> _showUltimosDiasDialog() async {
    int? selectedSuggestion = _ultimosDiasSugeridos.contains(_ultimosDiasFiltro)
        ? _ultimosDiasFiltro
        : null;
    final controller =
        TextEditingController(text: _ultimosDiasFiltro.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Últimos días'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedSuggestion,
                      decoration: const InputDecoration(
                        labelText: 'Sugerencias',
                        border: OutlineInputBorder(),
                      ),
                      items: _ultimosDiasSugeridos
                          .map(
                            (day) => DropdownMenuItem<int>(
                              value: day,
                              child: Text('$day días'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedSuggestion = value;
                          if (value != null) {
                            controller.text = value.toString();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Número de días personalizado',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  final dias = int.tryParse(controller.text.trim());
                  if (dias == null || dias <= 0) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Introduce un número de días válido.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, dias);
                },
                child: const Text('Aplicar'),
              ),
            ],
          ),
        );
      },
    );

    return result;
  }

  Future<void> _onPeriodoSelected(
    String periodoKey, {
    bool editarUltimosDias = false,
  }) async {
    if (periodoKey == 'ultimos_dias' && editarUltimosDias) {
      final dias = await _showUltimosDiasDialog();
      if (dias == null) return;
      setState(() {
        _ultimosDiasFiltro = dias;
        _periodoFiltro = periodoKey;
      });
      await _saveFiltroPreferences();
      return;
    }

    setState(() {
      _periodoFiltro = periodoKey;
    });
    await _saveFiltroPreferences();
  }

  List<Entrenamiento> _filtrarEntrenamientos() {
    DateTime? desde;
    DateTime? hasta;
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    switch (_periodoFiltro) {
      case 'semana_actual':
        final startOfWeek = hoy.subtract(Duration(days: hoy.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        desde = startOfWeek;
        hasta = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
        break;
      case 'mes_actual':
        desde = DateTime(ahora.year, ahora.month, 1);
        hasta = DateTime(ahora.year, ahora.month + 1, 0);
        break;
      case 'mes_anterior':
        final anterior = DateTime(ahora.year, ahora.month - 1, 1);
        desde = anterior;
        hasta = DateTime(anterior.year, anterior.month + 1, 0);
        break;
      case 'trimestre':
        final quarterStartMonth = ((ahora.month - 1) ~/ 3) * 3 + 1;
        desde = DateTime(ahora.year, quarterStartMonth, 1);
        hasta = DateTime(ahora.year, quarterStartMonth + 3, 0);
        break;
      case 'semestre':
        final semestreInicio = ahora.month <= 6 ? 1 : 7;
        desde = DateTime(ahora.year, semestreInicio, 1);
        hasta = DateTime(ahora.year, semestreInicio + 6, 0);
        break;
      case 'anio_actual':
        desde = DateTime(ahora.year, 1, 1);
        hasta = DateTime(ahora.year, 12, 31);
        break;
      case 'anio_anterior':
        desde = DateTime(ahora.year - 1, 1, 1);
        hasta = DateTime(ahora.year - 1, 12, 31);
        break;
      case 'ultimos_dias':
        desde = hoy.subtract(Duration(days: _ultimosDiasFiltro - 1));
        break;
      case 'siempre':
      default:
        break;
    }

    return _entrenamientos.where((entrenamiento) {
      final fecha = DateTime(
        entrenamiento.fecha.year,
        entrenamiento.fecha.month,
        entrenamiento.fecha.day,
      );

      if (desde != null && fecha.isBefore(desde)) {
        return false;
      }
      if (hasta != null && fecha.isAfter(hasta)) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _buildFiltroPeriodo() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: !_mostrarFiltroPeriodo
          ? const SizedBox.shrink()
          : Container(
              key: const ValueKey('filtro_periodo_entrenamientos'),
              margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtrar período',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _periodosFiltro.entries.map((entry) {
                        final selected = _periodoFiltro == entry.key;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onLongPress: entry.key == 'ultimos_dias'
                                ? () => _onPeriodoSelected(
                                      entry.key,
                                      editarUltimosDias: true,
                                    )
                                : null,
                            child: ChoiceChip(
                              label: Text(_getPeriodoLabel(entry.key)),
                              selected: selected,
                              onSelected: (_) => _onPeriodoSelected(entry.key),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
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

  double _getTotalDesnivel(List<Entrenamiento> entrenamientos) {
    return entrenamientos.fold(
        0.0,
        (sum, e) =>
            sum + (e.desnivelAcumulado != null ? e.desnivelAcumulado! : 0));
  }

  double _getPromedioEsfuerzo(List<Entrenamiento> entrenamientos) {
    if (entrenamientos.isEmpty) return 0;
    final suma = entrenamientos.fold(0, (sum, e) => sum + e.nivelEsfuerzo);
    return suma / entrenamientos.length;
  }

  Future<int> _getEjerciciosCountForEntrenamiento(int codigo) async {
    final ejercicios = await _getEjerciciosForEntrenamiento(codigo);
    _ejerciciosCountCache[codigo] = ejercicios.length;
    return ejercicios.length;
  }

  Future<List<EntrenamientoEjercicio>> _getEjerciciosForEntrenamiento(
      int codigo) async {
    final cached = _ejerciciosCache[codigo];
    if (cached != null) {
      return cached;
    }

    final cachedCount = _ejerciciosCountCache[codigo];
    if (cachedCount != null && cachedCount == 0) {
      _ejerciciosCache[codigo] = const <EntrenamientoEjercicio>[];
      return _ejerciciosCache[codigo]!;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final ejercicios = await apiService.getEntrenamientoEjercicios(codigo);
      _ejerciciosCache[codigo] = ejercicios;
      return ejercicios;
    } catch (_) {
      _ejerciciosCache[codigo] = const <EntrenamientoEjercicio>[];
      _ejerciciosCountCache[codigo] = 0;
      return _ejerciciosCache[codigo]!;
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

  Future<double> _getTotalKgLevantados(
      List<Entrenamiento> entrenamientos) async {
    final codigos = entrenamientos
        .where((e) => e.codigo != null)
        .map((e) => e.codigo!)
        .toList();
    if (codigos.isEmpty) {
      return 0;
    }

    double totalKg = 0;
    for (final codigo in codigos) {
      final ejercicios = await _getEjerciciosForEntrenamiento(codigo);
      for (final ejercicio in ejercicios) {
        if (ejercicio.realizado != 'S') continue;
        final kilos = (ejercicio.kilosPlan ?? 0).toDouble();
        if (kilos <= 0) continue;
        final repeticiones =
            ejercicio.repeticionesRealizadas ?? ejercicio.repeticionesPlan ?? 0;
        if (repeticiones <= 0) continue;
        totalKg += kilos * repeticiones;
      }
    }
    return totalKg;
  }

  String _formatRatio(double value) {
    if (value >= 100) return _formatDecimal(value, decimals: 0);
    if (value >= 10) return _formatDecimal(value, decimals: 1);
    if (value >= 1) return _formatDecimal(value, decimals: 2);
    return _formatDecimal(value, decimals: 4);
  }

  String _formatInteger(num value) {
    return NumberFormat.decimalPattern(_localeName).format(value);
  }

  String _formatDecimal(num value, {int decimals = 1}) {
    return NumberFormat.decimalPatternDigits(
      locale: _localeName,
      decimalDigits: decimals,
    ).format(value);
  }

  String _formatHoursMinutes(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${_formatInteger(hours)}h ${_formatInteger(minutes)}m';
  }

  String? _buildKgEquivalentMessage(double totalKg) {
    if (totalKg < 120) return null;

    final equivalents = <Map<String, dynamic>>[
      {
        'kg': 6000.0,
        'singular': 'elefante africano',
        'plural': 'elefantes africanos',
      },
      {
        'kg': 1200.0,
        'singular': 'coche compacto',
        'plural': 'coches compactos',
      },
      {
        'kg': 350.0,
        'singular': 'moto grande',
        'plural': 'motos grandes',
      },
      {
        'kg': 180.0,
        'singular': 'lavadora industrial',
        'plural': 'lavadoras industriales',
      },
    ];

    final viable = equivalents.where((item) {
      final ratio = totalKg / (item['kg'] as double);
      return ratio >= 0.2 && ratio <= 300;
    }).toList();

    if (viable.isEmpty) return null;
    final idx = totalKg.round() % viable.length;
    final selected = viable[idx];
    final ratio = totalKg / (selected['kg'] as double);
    final label = ratio >= 1.5 ? selected['plural'] : selected['singular'];
    return 'Has levantado el equivalente a ${_formatRatio(ratio)} $label.';
  }

  String? _buildKmEquivalentMessage(double totalKm) {
    if (totalKm < 2) return null;

    final equivalents = <Map<String, dynamic>>[
      {
        'km': 505.0,
        'singular': 'viaje Madrid-Barcelona',
        'plural': 'viajes Madrid-Barcelona',
      },
      {
        'km': 1365.0,
        'singular': 'viaje Madrid-Roma',
        'plural': 'viajes Madrid-Roma',
      },
      {
        'km': 42.195,
        'singular': 'maratón',
        'plural': 'maratones',
      },
      {
        'km': 384400.0,
        'singular': 'distancia a la Luna',
        'plural': 'distancias a la Luna',
      },
    ];

    final viable = equivalents.where((item) {
      final ratio = totalKm / (item['km'] as double);
      return ratio >= 0.000001 && ratio <= 200;
    }).toList();

    if (viable.isEmpty) return null;
    final idx = (totalKm * 10).round() % viable.length;
    final selected = viable[idx];
    final ratio = totalKm / (selected['km'] as double);
    final label = ratio >= 1.5 ? selected['plural'] : selected['singular'];
    return 'Has recorrido el equivalente a ${_formatRatio(ratio)} $label.';
  }

  Widget _buildEquivalenciasHumorCard({
    required double totalKg,
    required double totalKm,
    required double totalDesnivel,
  }) {
    final kgMsg = _buildKgEquivalentMessage(totalKg);
    final kmMsg = _buildKmEquivalentMessage(totalKm);
    final subidaMsg = totalDesnivel > 0
        ? 'Has subido ${_formatDecimal(totalDesnivel, decimals: 0)} m.'
        : null;

    if (kgMsg == null && kmMsg == null && subidaMsg == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: _buildDismissCardButton(
                onTap: () => setState(() => _showEquivalenciasBox = false),
                color: Colors.brown.shade400,
              ),
            ),
            if (kgMsg != null) Text(kgMsg),
            if (kgMsg != null && kmMsg != null) const SizedBox(height: 6),
            if (kmMsg != null) Text(kmMsg),
            if ((kgMsg != null || kmMsg != null) && subidaMsg != null)
              const SizedBox(height: 6),
            if (subidaMsg != null) Text(subidaMsg),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final canViewActivityStats = authService.isPremium ||
        authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';

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
                          horizontal: 6,
                          vertical: 2,
                        ),
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
          IconButton(
            onPressed: () {
              setState(() {
                _mostrarFiltroPeriodo = !_mostrarFiltroPeriodo;
              });
              _saveFiltroPreferences();
            },
            tooltip:
                _mostrarFiltroPeriodo ? 'Ocultar filtro' : 'Mostrar filtro',
            icon: Icon(
              _mostrarFiltroPeriodo ? Icons.filter_alt_off : Icons.filter_alt,
            ),
          ),
          IconButton(
            onPressed: _loadEntrenamientos,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            if (_isNutri) const Tab(text: 'Pacientes'),
            const Tab(
              icon: Icon(Icons.view_list_rounded),
              text: 'Listado',
            ),
            const Tab(
              icon: Icon(Icons.analytics_outlined),
              text: 'Análisis',
            ),
            const Tab(
              icon: Icon(Icons.show_chart_rounded),
              text: 'Evolución',
            ),
          ],
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
          : Column(
              children: [
                if (_shouldShowSharedFilterCard())
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: _buildFiltroPeriodo(),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      if (_isNutri)
                        const EntrenamientosPacientesPlanFitScreen(),
                      _buildListView(
                          canViewActivityStats: canViewActivityStats),
                      canViewActivityStats
                          ? EntrenamientoStatsChart(
                              entrenamientos: _filtrarEntrenamientos(),
                            )
                          : _buildPremiumOnlyStatsCard(
                              title: 'Gráfica de actividades Premium',
                              subtitle:
                                  'La gráfica de evolución de actividades está disponible solo para usuarios Premium.',
                            ),
                      canViewActivityStats
                          ? EntrenamientoEvolutionTabs(
                              entrenamientos: _filtrarEntrenamientos(),
                              loadEjercicios: _getEjerciciosForEntrenamiento,
                            )
                          : _buildPremiumOnlyStatsCard(
                              title: 'Evolución Premium',
                              subtitle:
                                  'La evolución de pesos y repeticiones por ejercicio está disponible solo para usuarios Premium.',
                            ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildListView({required bool canViewActivityStats}) {
    final showEquivalencias =
        context.watch<ConfigService>().showEquivalenciasActividades;
    final entrenamientosFiltrados = _filtrarEntrenamientos();

    final totalMinutos = _getTotalMinutos(entrenamientosFiltrados);
    final totalKilometros = _getTotalKilometros(entrenamientosFiltrados);
    final totalDesnivel = _getTotalDesnivel(entrenamientosFiltrados);
    final promedioEsfuerzo = _getPromedioEsfuerzo(entrenamientosFiltrados);
    final totalKgFuture = _getTotalKgLevantados(entrenamientosFiltrados);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
          left: 12.0, right: 12.0, top: 12.0, bottom: 80.0),
      child: Column(
        children: [
          // Tarjeta de estadísticas
          if (entrenamientosFiltrados.isNotEmpty) ...[
            if (canViewActivityStats && _showTotalsBox) ...[
              _buildEstadisticasCard(
                entrenamientosFiltrados,
                totalMinutos,
                totalKilometros,
                totalDesnivel,
                promedioEsfuerzo,
                totalKgFuture,
              ),
              if (_showEquivalenciasBox &&
                  showEquivalencias &&
                  entrenamientosFiltrados.length >= 5) ...[
                const SizedBox(height: 16),
                FutureBuilder<double>(
                  future: totalKgFuture,
                  builder: (context, snapshot) {
                    final totalKg = snapshot.data ?? 0;
                    return _buildEquivalenciasHumorCard(
                      totalKg: totalKg,
                      totalKm: totalKilometros,
                      totalDesnivel: totalDesnivel,
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ] else if (!canViewActivityStats && _showTotalsBox) ...[
              _buildPremiumOnlyStatsCard(
                title: 'Totales de actividades Premium',
                subtitle:
                    'El resumen de totales en el listado está disponible solo para usuarios Premium.',
              ),
              const SizedBox(height: 16),
            ],
          ],

          // Tarjeta motivacional
          if (_showMotivacionalBox) ...[
            _buildTarjetaMotivacional(entrenamientosFiltrados),
            const SizedBox(height: 16),
          ],

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

  Widget _buildPremiumOnlyStatsCard({
    required String title,
    required String subtitle,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [Colors.purple.shade50, Colors.deepPurple.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.purple.shade100),
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: _buildDismissCardButton(
                onTap: () => setState(() => _showTotalsBox = false),
                color: Colors.deepPurple.shade400,
              ),
            ),
            Icon(
              Icons.workspace_premium,
              size: 44,
              color: Colors.deepPurple.shade400,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.deepPurple.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.deepPurple.shade600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/premium_info'),
              icon: const Icon(Icons.workspace_premium),
              label: const Text('Hazte premium'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadisticasCard(
    List<Entrenamiento> entrenamientos,
    int totalMinutos,
    double totalKilometros,
    double totalDesnivel,
    double promedioEsfuerzo,
    Future<double> totalKgLevantadosFuture,
  ) {
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
            Align(
              alignment: Alignment.topRight,
              child: _buildDismissCardButton(
                onTap: () => setState(() => _showTotalsBox = false),
                color: Colors.white,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  '💪',
                  _formatInteger(entrenamientos.length),
                  'Actividades',
                  Colors.white,
                ),
                FutureBuilder<int>(
                  future: totalEjerciciosFuture,
                  builder: (context, snapshot) {
                    final totalEjercicios = snapshot.data ?? 0;
                    return _buildStatItem(
                      '🏋️',
                      _formatInteger(totalEjercicios),
                      'Ejercicios',
                      Colors.white,
                    );
                  },
                ),
                _buildStatItem(
                  '⏱️',
                  _formatHoursMinutes(totalMinutos),
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
                  _formatDecimal(promedioEsfuerzo, decimals: 1),
                  'Esfuerzo avg',
                  Colors.white,
                ),
                FutureBuilder<double>(
                  future: totalKgLevantadosFuture,
                  builder: (context, snapshot) {
                    final totalKg = snapshot.data ?? 0;
                    return _buildStatItem(
                      '🏋️',
                      '${_formatDecimal(totalKg, decimals: 0)} kg',
                      'Total levantado',
                      Colors.white,
                    );
                  },
                ),
                if (totalKilometros > 0)
                  _buildStatItem(
                    '📍',
                    _formatDecimal(totalKilometros, decimals: 2),
                    'Kilómetros',
                    Colors.white,
                  ),
              ],
            ),
            if (totalDesnivel > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Has subido ${_formatDecimal(totalDesnivel, decimals: 0)} m.',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: _buildDismissCardButton(
                onTap: () => setState(() => _showMotivacionalBox = false),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Row(
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
          ],
        ),
      ),
    );
  }

  Widget _buildDismissCardButton({
    required VoidCallback onTap,
    required Color color,
  }) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        onPressed: onTap,
        tooltip: 'Ocultar',
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.close, size: 18, color: color),
      ),
    );
  }

  Widget _buildEntrenamientoCard(Entrenamiento entrenamiento) {
    final duracion = _formatHoursMinutes(
      (entrenamiento.duracionHoras * 60) + entrenamiento.duracionMinutos,
    );
    final titulo = (entrenamiento.titulo ?? '').trim();
    final kmText = entrenamiento.duracionKilometros != null &&
            entrenamiento.duracionKilometros! > 0
        ? ' • ${_formatDecimal(entrenamiento.duracionKilometros!, decimals: 2)} km'
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
            titulo.isNotEmpty ? titulo : entrenamiento.actividad,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              if (titulo.isNotEmpty) ...[
                Text(
                  'Actividad: ${entrenamiento.actividad}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
              ],
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
              label: const Text('Agregar actividad'),
            ),
          ],
        ),
      ),
    );
  }
}
