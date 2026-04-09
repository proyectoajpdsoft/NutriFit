import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/models/entrenamiento.dart';
import 'package:nutri_app/models/entrenamiento_ejercicio.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/screens/entrenamiento_sensaciones_pendientes_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/entrenamiento_evolution_tabs.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EntrenamientoPacienteEvolutionScreen extends StatefulWidget {
  const EntrenamientoPacienteEvolutionScreen({
    super.key,
    required this.paciente,
  });

  final Paciente paciente;

  @override
  State<EntrenamientoPacienteEvolutionScreen> createState() =>
      _EntrenamientoPacienteEvolutionScreenState();
}

class _EntrenamientoPacienteEvolutionScreenState
    extends State<EntrenamientoPacienteEvolutionScreen> {
  static const String _prefsFiltroVisiblePrefix =
      'entrenamiento_paciente_evolution_filtro_visible';
  static const String _prefsFiltroPeriodoPrefix =
      'entrenamiento_paciente_evolution_filtro_periodo';
  static const String _prefsFiltroUltimosDiasPrefix =
      'entrenamiento_paciente_evolution_filtro_ultimos_dias';

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

  final Map<int, List<EntrenamientoEjercicio>> _ejerciciosCache = {};
  List<Entrenamiento> _entrenamientos = [];
  bool _isLoading = true;
  bool _mostrarFiltroPeriodo = false;
  String _periodoFiltro = 'semana_actual';
  int _ultimosDiasFiltro = 30;

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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = context.read<ApiService>();
      final items =
          await apiService.getEntrenamientosPaciente(widget.paciente.codigo);
      if (!mounted) return;
      setState(() {
        _ejerciciosCache.clear();
        _entrenamientos = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _entrenamientos = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar actividades: $e')),
      );
    }
  }

  Future<List<EntrenamientoEjercicio>> _getEjerciciosForEntrenamiento(
    int codigo,
  ) async {
    final cached = _ejerciciosCache[codigo];
    if (cached != null) {
      return cached;
    }

    try {
      final apiService = context.read<ApiService>();
      final ejercicios = await apiService.getEntrenamientoEjercicios(codigo);
      _ejerciciosCache[codigo] = ejercicios;
      return ejercicios;
    } catch (_) {
      _ejerciciosCache[codigo] = const <EntrenamientoEjercicio>[];
      return _ejerciciosCache[codigo]!;
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
              key: const ValueKey('filtro_periodo_entrenamiento_evolution'),
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart_rounded,
              size: 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  void _openSensacionesPaciente() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EntrenamientoSensacionesPendientesScreen(
          codigoPaciente: widget.paciente.codigo,
          incluirLeidas: true,
          titulo: 'Sensaciones de ${widget.paciente.nombre}',
          emptyMessage: 'No hay sensaciones registradas para este paciente.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entrenamientosFiltrados = _filtrarEntrenamientos();

    return Scaffold(
      appBar: AppBar(
        title: Text('Evolución de ${widget.paciente.nombre}'),
        actions: [
          IconButton(
            onPressed: _openSensacionesPaciente,
            tooltip: 'Ver sensaciones',
            icon: const Icon(Icons.forum_outlined),
          ),
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
          : Column(
              children: [
                _buildFiltroPeriodo(),
                Expanded(
                  child: _entrenamientos.isEmpty
                      ? _buildEmptyState(
                          'Este paciente no tiene actividades para mostrar su evolución.',
                        )
                      : entrenamientosFiltrados.isEmpty
                          ? _buildEmptyState(
                              'No hay actividades en el período seleccionado.',
                            )
                          : EntrenamientoEvolutionTabs(
                              entrenamientos: entrenamientosFiltrados,
                              loadEjercicios: _getEjerciciosForEntrenamiento,
                            ),
                ),
              ],
            ),
    );
  }
}
