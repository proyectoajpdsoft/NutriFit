import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entrenamiento.dart';
import '../models/entrenamiento_ejercicio.dart';
import '../models/paciente.dart';
import '../services/api_service.dart';
import 'entrenamiento_view_screen.dart';

class EntrenamientoPacienteScreen extends StatefulWidget {
  final Paciente paciente;

  const EntrenamientoPacienteScreen({
    super.key,
    required this.paciente,
  });

  @override
  State<EntrenamientoPacienteScreen> createState() =>
      _EntrenamientoPacienteScreenState();
}

class _EntrenamientoPacienteScreenState
    extends State<EntrenamientoPacienteScreen> {
  List<Entrenamiento> _entrenamientos = [];
  bool _isLoading = true;
  bool _mostrarFiltroPeriodo = false;
  String _periodoFiltro = 'semana_actual';
  int _ultimosDiasFiltro = 30;

  final Map<int, bool> _comentariosCache = {};
  final Map<int, int> _ejerciciosCountCache = {};
  final Map<int, List<EntrenamientoEjercicio>> _ejerciciosCache = {};

  static const String _prefsFiltroVisiblePrefix =
      'entrenamiento_paciente_filtro_visible';
  static const String _prefsFiltroPeriodoPrefix =
      'entrenamiento_paciente_filtro_periodo';
  static const String _prefsFiltroUltimosDiasPrefix =
      'entrenamiento_paciente_filtro_ultimos_dias';

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

  String get _prefsFiltroVisibleKey =>
      '${_prefsFiltroVisiblePrefix}_${widget.paciente.codigo}';
  String get _prefsFiltroPeriodoKey =>
      '${_prefsFiltroPeriodoPrefix}_${widget.paciente.codigo}';
  String get _prefsFiltroUltimosDiasKey =>
      '${_prefsFiltroUltimosDiasPrefix}_${widget.paciente.codigo}';

  @override
  void initState() {
    super.initState();
    _loadFiltroPreferences();
    _loadEntrenamientos();
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

  Future<void> _loadEntrenamientos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final url =
          'api/entrenamientos.php?action=get_entrenamientos&paciente=${widget.paciente.codigo}';

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
          SnackBar(
            content: Text('Error al cargar entrenamientos. $errorMessage'),
          ),
        );
      }
    }
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
              key: const ValueKey('filtro_periodo_entrenamiento_paciente'),
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
      0,
      (sum, e) => sum + ((e.duracionHoras * 60) + e.duracionMinutos),
    );
  }

  double _getTotalKilometros(List<Entrenamiento> entrenamientos) {
    return entrenamientos.fold(
      0.0,
      (sum, e) =>
          sum + (e.duracionKilometros != null ? e.duracionKilometros! : 0),
    );
  }

  double _getTotalDesnivel(List<Entrenamiento> entrenamientos) {
    return entrenamientos.fold(
      0.0,
      (sum, e) =>
          sum + (e.desnivelAcumulado != null ? e.desnivelAcumulado! : 0),
    );
  }

  double _getPromedioEsfuerzo(List<Entrenamiento> entrenamientos) {
    if (entrenamientos.isEmpty) return 0;
    final suma = entrenamientos.fold(0, (sum, e) => sum + e.nivelEsfuerzo);
    return suma / entrenamientos.length;
  }

  Future<List<EntrenamientoEjercicio>> _getEjerciciosForEntrenamiento(
      int codigo) async {
    final cached = _ejerciciosCache[codigo];
    if (cached != null) return cached;

    final cachedCount = _ejerciciosCountCache[codigo];
    if (cachedCount != null && cachedCount == 0) {
      _ejerciciosCache[codigo] = const <EntrenamientoEjercicio>[];
      return _ejerciciosCache[codigo]!;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final ejercicios = await apiService.getEntrenamientoEjercicios(codigo);
      _ejerciciosCache[codigo] = ejercicios;
      _ejerciciosCountCache[codigo] = ejercicios.length;
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
    if (codigos.isEmpty) return 0;

    var total = 0;
    for (final codigo in codigos) {
      final ejercicios = await _getEjerciciosForEntrenamiento(codigo);
      total += ejercicios.length;
    }
    return total;
  }

  Future<double> _getTotalKgLevantados(
      List<Entrenamiento> entrenamientos) async {
    final codigos = entrenamientos
        .where((e) => e.codigo != null)
        .map((e) => e.codigo!)
        .toList();
    if (codigos.isEmpty) return 0;

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
    if (value >= 100) return value.toStringAsFixed(0);
    if (value >= 10) return value.toStringAsFixed(1);
    if (value >= 1) return value.toStringAsFixed(2);
    return value.toStringAsFixed(4);
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
        ? 'Has subido ${totalDesnivel.toStringAsFixed(0)} m.'
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
            const Text(
              'Equivalencias curiosas',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (kgMsg != null) Text('• $kgMsg'),
            if (kmMsg != null) Text('• $kmMsg'),
            if (subidaMsg != null) Text('• $subidaMsg'),
          ],
        ),
      ),
    );
  }

  Map<String, int> _agruparPorActividad(List<Entrenamiento> entrenamientos) {
    final resultado = <String, int>{};
    for (final e in entrenamientos) {
      resultado[e.actividad] = (resultado[e.actividad] ?? 0) + 1;
    }
    return resultado;
  }

  Future<bool> _hasComentarios(int codigoEntrenamiento) async {
    if (_comentariosCache.containsKey(codigoEntrenamiento)) {
      return _comentariosCache[codigoEntrenamiento] ?? false;
    }
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final ejercicios =
          await apiService.getEntrenamientoEjercicios(codigoEntrenamiento);
      final has = ejercicios
          .any((e) => (e.comentarioNutricionista ?? '').trim().isNotEmpty);
      _comentariosCache[codigoEntrenamiento] = has;
      return has;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entrenamientosFiltrados = _filtrarEntrenamientos();
    final totalMinutos = _getTotalMinutos(entrenamientosFiltrados);
    final totalKilometros = _getTotalKilometros(entrenamientosFiltrados);
    final totalDesnivel = _getTotalDesnivel(entrenamientosFiltrados);
    final promedioEsfuerzo = _getPromedioEsfuerzo(entrenamientosFiltrados);
    final totalKgFuture = _getTotalKgLevantados(entrenamientosFiltrados);
    final porActividad = _agruparPorActividad(entrenamientosFiltrados);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Actividades de ${widget.paciente.nombre}'),
        actions: [
          IconButton(
            onPressed: _loadEntrenamientos,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
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
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              child: Column(
                children: [
                  _buildFiltroPeriodo(),
                  if (entrenamientosFiltrados.isNotEmpty) ...[
                    _buildEstadisticasCard(
                      entrenamientosFiltrados,
                      totalMinutos,
                      totalKilometros,
                      totalDesnivel,
                      promedioEsfuerzo,
                      totalKgFuture,
                    ),
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
                  if (porActividad.isNotEmpty) ...[
                    _buildActividadesCard(porActividad),
                    const SizedBox(height: 16),
                  ],
                  if (entrenamientosFiltrados.isEmpty)
                    _buildEmptyState()
                  else
                    ...(entrenamientosFiltrados
                        .map((e) => _buildEntrenamientoCard(e))
                        .toList()),
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
    Future<double> totalKgFuture,
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
                FutureBuilder<double>(
                  future: totalKgFuture,
                  builder: (context, snapshot) {
                    final totalKg = snapshot.data ?? 0;
                    return _buildStatItem(
                      '🏋️',
                      '${totalKg.toStringAsFixed(0)} kg',
                      'Total levantado',
                      Colors.white,
                    );
                  },
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
            if (totalDesnivel > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Has subido ${totalDesnivel.toStringAsFixed(0)} m.',
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

  Widget _buildActividadesCard(Map<String, int> porActividad) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actividades favoritas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...porActividad.entries.map((e) {
              final icono = ActividadDeportiva.getIconoActividad(e.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(icono, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(e.key),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${e.value}x',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEntrenamientoCard(Entrenamiento entrenamiento) {
    final duracion =
        '${entrenamiento.duracionHoras}h ${entrenamiento.duracionMinutos}m';
    final titulo = (entrenamiento.titulo ?? '').trim();
    final icono = ActividadDeportiva.getIconoActividad(entrenamiento.actividad);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  EntrenamientoViewScreen(entrenamiento: entrenamiento),
            ),
          );
        },
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
                  '⏱️ $duracion',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Text(
                  '${Entrenamiento.getIconoNivelEsfuerzo(entrenamiento.nivelEsfuerzo)} ${entrenamiento.textoNivelEsfuerzo}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            if (entrenamiento.notas != null) ...[
              const SizedBox(height: 4),
              Text(
                entrenamiento.notas!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            FutureBuilder<bool>(
              future: _hasComentarios(entrenamiento.codigo ?? 0),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '💬 Comentarios del dietista',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
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
              'El paciente aún no ha registrado entrenamientos',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
