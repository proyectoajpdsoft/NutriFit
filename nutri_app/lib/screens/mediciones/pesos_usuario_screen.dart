import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/medicion.dart';
import 'package:nutri_app/screens/mediciones/bmi_dialog_helper.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PesosUsuarioScreen extends StatefulWidget {
  const PesosUsuarioScreen({super.key});

  @override
  State<PesosUsuarioScreen> createState() => _PesosUsuarioScreenState();
}

class _PesosUsuarioScreenState extends State<PesosUsuarioScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  Future<List<Medicion>>? _pesosFuture;
  late final TabController _tabController;
  double? _pesoObjetivo;
  double? _pesoObjetivoSugerido;
  int? _alturaObjetivoCm;
  bool _mostrarFiltroPeriodo = false;
  String _periodoFiltro = 'siempre';
  int _ultimosDiasFiltro = 30;
  static const String _prefsFiltroVisibleKey = 'peso_usuario_filtro_visible';
  static const String _prefsFiltroPeriodoKey = 'peso_usuario_filtro_periodo';
  static const String _prefsFiltroUltimosDiasKey =
      'peso_usuario_filtro_ultimos_dias';
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
    'mes_actual': 'Mes actual',
    'mes_anterior': 'Mes anterior',
    'trimestre': 'Trimestre',
    'semestre': 'Semestre',
    'anio_actual': 'Año',
    'anio_anterior': 'Año anterior',
    'siempre': 'Siempre',
    'ultimos_dias': 'Últimos .. días',
  };

  void _refresh() {
    final authService = context.read<AuthService>();
    if (authService.isGuestMode) {
      setState(() {
        _pesosFuture = Future.value(<Medicion>[]);
        _pesoObjetivo = null;
        _pesoObjetivoSugerido = null;
        _alturaObjetivoCm = null;
      });
      return;
    }

    setState(() {
      _pesosFuture = _apiService.getPesosUsuario();
    });
    _loadPesoObjetivo();
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFiltroPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatPeso(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toStringAsFixed(0)} kg';
    }
    return '${value.toStringAsFixed(1)} kg';
  }

  String _variacionPeso(Medicion actual, Medicion? anterior) {
    if (actual.peso == null || anterior?.peso == null) {
      return 'Sin referencia';
    }

    final delta = actual.peso! - anterior!.peso!;
    if (delta.abs() < 0.01) {
      return 'Sin cambios';
    }

    final value = delta.abs().toStringAsFixed(1);
    if (delta > 0) {
      return 'Engordó +$value kg';
    }
    return 'Adelgazó -$value kg';
  }

  double? _calculateImc(Medicion medicion) {
    if (medicion.peso == null || medicion.alturaPaciente == null) {
      return null;
    }

    final alturaCm = medicion.alturaPaciente!;
    if (alturaCm <= 0) return null;

    final alturaM = alturaCm / 100.0;
    return medicion.peso! / (alturaM * alturaM);
  }

  void _showBmiInfoDialog(double bmi) {
    BmiDialogHelper.showBmiInfoDialog(context, bmi);
  }

  Future<void> _loadPesoObjetivo() async {
    try {
      final data = await _apiService.getPesoObjetivoUsuario();
      if (!mounted) return;
      setState(() {
        _pesoObjetivo = data['peso_objetivo'] as double?;
        _pesoObjetivoSugerido = data['peso_objetivo_sugerido'] as double?;
        _alturaObjetivoCm = data['altura_paciente'] as int?;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pesoObjetivo = null;
        _pesoObjetivoSugerido = null;
        _alturaObjetivoCm = null;
      });
    }
  }

  double? _getPesoObjetivoSugeridoLocal(List<Medicion> mediciones) {
    if (_pesoObjetivoSugerido != null) {
      return _pesoObjetivoSugerido;
    }

    int? alturaCm = _alturaObjetivoCm;
    if (alturaCm == null || alturaCm <= 0) {
      for (final medicion in mediciones) {
        if (medicion.alturaPaciente != null && medicion.alturaPaciente! > 0) {
          alturaCm = medicion.alturaPaciente;
          break;
        }
      }
    }

    if (alturaCm == null || alturaCm <= 0) {
      return null;
    }

    final alturaM = alturaCm / 100.0;
    return double.parse((22.0 * alturaM * alturaM).toStringAsFixed(1));
  }

  List<Medicion> _aplicarFiltroPeriodo(List<Medicion> mediciones) {
    if (_periodoFiltro == 'siempre') {
      return mediciones;
    }

    final ahora = DateTime.now();
    DateTime? desde;
    DateTime? hasta;

    switch (_periodoFiltro) {
      case 'mes_actual':
        desde = DateTime(ahora.year, ahora.month, 1);
        break;
      case 'mes_anterior':
        final primerDiaMesActual = DateTime(ahora.year, ahora.month, 1);
        desde = DateTime(
          primerDiaMesActual.year,
          primerDiaMesActual.month - 1,
          1,
        );
        hasta = primerDiaMesActual.subtract(const Duration(days: 1));
        break;
      case 'trimestre':
        desde = DateTime(ahora.year, ahora.month - 2, 1);
        break;
      case 'semestre':
        desde = DateTime(ahora.year, ahora.month - 5, 1);
        break;
      case 'anio_actual':
        desde = DateTime(ahora.year, 1, 1);
        break;
      case 'anio_anterior':
        desde = DateTime(ahora.year - 1, 1, 1);
        hasta = DateTime(ahora.year, 1, 1).subtract(const Duration(days: 1));
        break;
      case 'ultimos_dias':
        final hoy = DateTime(ahora.year, ahora.month, ahora.day);
        desde = hoy.subtract(Duration(days: _ultimosDiasFiltro - 1));
        break;
    }

    return mediciones.where((medicion) {
      final fecha = DateTime(
        medicion.fecha.year,
        medicion.fecha.month,
        medicion.fecha.day,
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
              key: const ValueKey('filtro_periodo'),
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
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
                    'Filtrar periodo',
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

  Future<void> _showPesoObjetivoDialog({
    double? valorInicial,
    bool esPrimeraVez = false,
  }) async {
    final controller = TextEditingController(
      text: valorInicial != null ? valorInicial.toStringAsFixed(1) : '',
    );

    final dialogResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Peso objetivo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Define tu peso objetivo para compararlo con tu evolución.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*([\.,]\d*)?$'),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: 'Peso objetivo (kg)',
                  border: const OutlineInputBorder(),
                  helperText: valorInicial != null
                      ? 'Sugerido: ${valorInicial.toStringAsFixed(1)} kg'
                      : null,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(esPrimeraVez ? 'Más tarde' : 'Cancelar'),
            ),
            if (!esPrimeraVez && _pesoObjetivo != null)
              TextButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  {'action': 'remove'},
                ),
                child: const Text('Quitar objetivo'),
              ),
            ElevatedButton(
              onPressed: () {
                final raw = controller.text.trim().replaceAll(',', '.');
                final objetivo = double.tryParse(raw);
                if (objetivo == null || objetivo <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Introduce un peso objetivo válido.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  {'action': 'save', 'value': objetivo},
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (dialogResult == null) return;

    try {
      final action = dialogResult['action'];
      if (action == 'remove') {
        await _apiService.setPesoObjetivoUsuario(null);
        await _loadPesoObjetivo();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Objetivo eliminado.'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      final value = dialogResult['value'];
      final objetivo = value is num ? value.toDouble() : null;
      if (objetivo == null || objetivo <= 0) return;

      await _apiService.setPesoObjetivoUsuario(objetivo);
      await _loadPesoObjetivo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Objetivo guardado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error guardando objetivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showAddPesoDialog() async {
    DateTime fecha = DateTime.now();
    final pesoController = TextEditingController();
    final observacionController = TextEditingController();

    final dialogResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Nuevo peso'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}',
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fecha,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) {
                        setStateDialog(() => fecha = picked);
                      }
                    },
                  ),
                  TextField(
                    controller: pesoController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*([\.,]\d*)?$')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Peso (kg)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: observacionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Observación',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final raw = pesoController.text.trim().replaceAll(',', '.');
                  final peso = double.tryParse(raw);
                  if (peso == null || peso <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Introduce un peso válido.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, {
                    'fecha': fecha,
                    'peso': peso,
                    'observacion': observacionController.text.trim(),
                  });
                },
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );

    if (dialogResult == null) return;

    try {
      await _apiService.createPesoUsuario(
        fecha: dialogResult['fecha'] as DateTime,
        peso: (dialogResult['peso'] as num).toDouble(),
        observacionUsuario: dialogResult['observacion'] as String?,
      );

      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Peso guardado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar peso: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showEditPesoDialog(Medicion medicion) async {
    DateTime fecha = medicion.fecha;
    final pesoController =
        TextEditingController(text: (medicion.peso ?? 0).toStringAsFixed(1));
    final observacionController =
        TextEditingController(text: medicion.observacionUsuario ?? '');

    final dialogResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Editar peso'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}',
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fecha,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) {
                        setStateDialog(() => fecha = picked);
                      }
                    },
                  ),
                  TextField(
                    controller: pesoController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*([\.,]\d*)?$')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Peso (kg)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: observacionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Observación',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final raw = pesoController.text.trim().replaceAll(',', '.');
                  final peso = double.tryParse(raw);
                  if (peso == null || peso <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Introduce un peso válido.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, {
                    'fecha': fecha,
                    'peso': peso,
                    'observacion': observacionController.text.trim(),
                  });
                },
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );

    if (dialogResult == null) return;

    try {
      final edited = Medicion(
        codigo: medicion.codigo,
        codigoPaciente: medicion.codigoPaciente,
        codigoUsuario: medicion.codigoUsuario,
        fecha: dialogResult['fecha'] as DateTime,
        peso: (dialogResult['peso'] as num).toDouble(),
        tipo: 'Usuario',
        observacionUsuario: dialogResult['observacion'] as String?,
      );

      await _apiService.updateMedicion(edited);

      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Peso actualizado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar peso: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletePeso(Medicion medicion) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar peso'),
            content: const Text('¿Seguro que deseas eliminar este peso?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await _apiService.deleteMedicion(medicion.codigo);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Peso eliminado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar peso: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isGuest = authService.isGuestMode;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Control de peso'),
        actions: isGuest
            ? []
            : [
                IconButton(
                  onPressed: () => _showPesoObjetivoDialog(
                    valorInicial: _pesoObjetivo ?? _pesoObjetivoSugerido,
                  ),
                  tooltip: 'Cambiar peso objetivo',
                  icon: const Icon(Icons.flag_outlined),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _mostrarFiltroPeriodo = !_mostrarFiltroPeriodo;
                    });
                    _saveFiltroPreferences();
                  },
                  tooltip: _mostrarFiltroPeriodo
                      ? 'Ocultar filtro'
                      : 'Mostrar filtro',
                  icon: Icon(
                    _mostrarFiltroPeriodo
                        ? Icons.filter_alt_off
                        : Icons.filter_alt,
                  ),
                ),
                IconButton(
                  onPressed: _refresh,
                  tooltip: 'Actualizar',
                  icon: const Icon(Icons.refresh),
                ),
              ],
        bottom: isGuest
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.list)),
                  Tab(icon: Icon(Icons.show_chart)),
                ],
              ),
      ),
      drawer: const AppDrawer(),
      floatingActionButton: isGuest
          ? null
          : FloatingActionButton(
              onPressed: _showAddPesoDialog,
              tooltip: 'Añadir peso',
              child: const Icon(Icons.add),
            ),
      body: isGuest
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Para poder gestionar tu control de pesos debes registrarte (es gratis).',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register'),
                      child: const Text('Registrarse'),
                    ),
                  ],
                ),
              ),
            )
          : FutureBuilder<List<Medicion>>(
              future: _pesosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Error cargando pesos: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final mediciones = (snapshot.data ?? <Medicion>[])
                    .where((m) => m.peso != null && m.tipo == 'Usuario')
                    .toList()
                  ..sort((a, b) => b.fecha.compareTo(a.fecha));

                final medicionesFiltradas = _aplicarFiltroPeriodo(mediciones);

                if (mediciones.isEmpty) {
                  return const Center(
                    child: Text('Todavía no hay pesos registrados.'),
                  );
                }

                return Column(
                  children: [
                    _buildFiltroPeriodo(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          medicionesFiltradas.isEmpty
                              ? Center(
                                  child: Text(
                                    'No hay pesos para ${_getPeriodoLabel(_periodoFiltro).toLowerCase()}.',
                                  ),
                                )
                              : _buildListaPesos(medicionesFiltradas),
                          medicionesFiltradas.isEmpty
                              ? Center(
                                  child: Text(
                                    'No hay datos para ${_getPeriodoLabel(_periodoFiltro).toLowerCase()}.',
                                  ),
                                )
                              : _buildGraficaPesos(medicionesFiltradas),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildListaPesos(List<Medicion> mediciones) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.height < 740 || media.size.width < 380;
    final bottomPadding = (isCompact ? 12.0 : 16.0) + media.padding.bottom;
    final tagFontSize = isCompact ? 10.8 : 12.0;
    final tagIconSize = isCompact ? 13.8 : 15.0;

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(12, isCompact ? 6 : 8, 12, bottomPadding),
      itemCount: mediciones.length,
      separatorBuilder: (_, __) => SizedBox(height: isCompact ? 6 : 8),
      itemBuilder: (context, index) {
        final actual = mediciones[index];
        final anterior =
            index + 1 < mediciones.length ? mediciones[index + 1] : null;
        final imc = _calculateImc(actual);
        final diferencia =
            (anterior?.peso != null) ? (actual.peso! - anterior!.peso!) : null;

        return Card(
          elevation: 4,
          margin: EdgeInsets.symmetric(
            horizontal: isCompact ? 6 : 8,
            vertical: isCompact ? 6 : 8,
          ),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: tagIconSize,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yyyy').format(actual.fecha),
                            style: TextStyle(
                              fontSize: tagFontSize,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.purple[200]!,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.monitor_weight,
                                  size: tagIconSize,
                                  color: Colors.purple,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  actual.peso!.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: tagFontSize,
                                    color: Colors.purple[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (imc != null)
                            InkWell(
                              onTap: () => _showBmiInfoDialog(imc),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: BmiDialogHelper.getBmiColor(imc)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: BmiDialogHelper.getBmiColor(imc)
                                        .withOpacity(0.6),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.analytics,
                                      size: tagIconSize,
                                      color: BmiDialogHelper.getBmiColor(imc),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'IMC ${imc.toStringAsFixed(1)}',
                                      style: TextStyle(
                                        fontSize: tagFontSize,
                                        color: BmiDialogHelper.getBmiColor(imc),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (diferencia != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: diferencia < 0
                                    ? Colors.green[50]
                                    : Colors.red[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: diferencia < 0
                                      ? Colors.green[200]!
                                      : Colors.red[200]!,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    diferencia < 0
                                        ? Icons.trending_down
                                        : Icons.trending_up,
                                    size: tagIconSize,
                                    color: diferencia < 0
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    diferencia < 0
                                        ? 'Adelgaza ${diferencia.abs().toStringAsFixed(1)}'
                                        : 'Engorda ${diferencia.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: tagFontSize,
                                      color: diferencia < 0
                                          ? Colors.green[700]
                                          : Colors.red[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if ((actual.observacionUsuario ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      actual.observacionUsuario!.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: isCompact ? 11 : 12,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: isCompact ? 6 : 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showEditPesoDialog(actual),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Editar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _deletePeso(actual),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Eliminar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGraficaPesos(List<Medicion> mediciones) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.height < 740 || media.size.width < 380;
    final bottomPadding = (isCompact ? 12.0 : 16.0) + media.padding.bottom;

    final datos = [...mediciones]..sort((a, b) => a.fecha.compareTo(b.fecha));
    final pesoObjetivo = _pesoObjetivo;

    if (datos.isEmpty) {
      return const Center(child: Text('No hay datos para mostrar la gráfica.'));
    }

    final spots = <FlSpot>[];
    double minY = datos.first.peso!;
    double maxY = datos.first.peso!;

    for (var i = 0; i < datos.length; i++) {
      final peso = datos[i].peso!;
      spots.add(FlSpot(i.toDouble(), peso));
      if (peso < minY) minY = peso;
      if (peso > maxY) maxY = peso;
    }

    if (pesoObjetivo != null) {
      if (pesoObjetivo < minY) minY = pesoObjetivo;
      if (pesoObjetivo > maxY) maxY = pesoObjetivo;
    }

    if ((maxY - minY).abs() < 0.5) {
      minY -= 1;
      maxY += 1;
    } else {
      minY -= 0.5;
      maxY += 0.5;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12, isCompact ? 6 : 8, 12, bottomPadding),
      child: Card(
        elevation: 3,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 10 : 12,
            isCompact ? 12 : 16,
            isCompact ? 12 : 16,
            isCompact ? 10 : 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Evolución',
                      style: TextStyle(
                        fontSize: isCompact ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_pesoObjetivo != null)
                    Chip(
                      visualDensity: isCompact
                          ? const VisualDensity(horizontal: -2, vertical: -2)
                          : VisualDensity.standard,
                      avatar: Icon(Icons.flag, size: isCompact ? 14 : 16),
                      label: Text('Objetivo: ${_formatPeso(_pesoObjetivo!)}'),
                    ),
                ],
              ),
              SizedBox(height: isCompact ? 8 : 12),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (datos.length - 1).toDouble(),
                    minY: minY,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (maxY - minY) / 4,
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: isCompact ? 40 : 46,
                          interval: (maxY - minY) / 4,
                          getTitlesWidget: (value, _) {
                            return Text('${value.toStringAsFixed(1)} kg',
                                style: TextStyle(fontSize: isCompact ? 9 : 10));
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: isCompact ? 24 : 28,
                          interval: 1,
                          getTitlesWidget: (value, _) {
                            final index = value.round();
                            if (index < 0 || index >= datos.length) {
                              return const SizedBox.shrink();
                            }

                            final shouldShow = datos.length <= 6 ||
                                index == 0 ||
                                index == datos.length - 1 ||
                                index == (datos.length ~/ 2);

                            if (!shouldShow) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: EdgeInsets.only(top: isCompact ? 4 : 6),
                              child: Text(
                                DateFormat('dd/MM').format(datos[index].fecha),
                                style: TextStyle(fontSize: isCompact ? 9 : 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        barWidth: isCompact ? 2.5 : 3,
                        color: Colors.purple,
                        isStrokeCapRound: true,
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.purple.withOpacity(0.12),
                        ),
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, _, __, ___) =>
                              FlDotCirclePainter(
                            radius: isCompact ? 2.5 : 3,
                            color: Colors.purple,
                            strokeWidth: 1.5,
                            strokeColor: Colors.white,
                          ),
                        ),
                      ),
                      if (pesoObjetivo != null)
                        LineChartBarData(
                          spots: [
                            FlSpot(0, pesoObjetivo),
                            FlSpot((datos.length - 1).toDouble(), pesoObjetivo),
                          ],
                          isCurved: false,
                          barWidth: isCompact ? 1.8 : 2,
                          color: Colors.orange,
                          dashArray: [8, 4],
                          dotData: const FlDotData(show: false),
                        ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final index = spot.x.round();
                            final item = datos[index];
                            return LineTooltipItem(
                              '${DateFormat('dd/MM/yyyy').format(item.fecha)}\n${_formatPeso(item.peso!)}',
                              TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: isCompact ? 10 : 11,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
