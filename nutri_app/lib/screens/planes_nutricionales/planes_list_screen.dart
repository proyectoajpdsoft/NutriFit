import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/plan_nutricional.dart';
import 'package:nutri_app/screens/planes_nutricionales/plan_edit_screen.dart';
import 'package:nutri_app/services/adherencia_service.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';

class PlanesListScreen extends StatefulWidget {
  final Paciente? paciente;
  const PlanesListScreen({super.key, this.paciente});

  @override
  State<PlanesListScreen> createState() => _PlanesListScreenState();
}

class _PlanesListScreenState extends State<PlanesListScreen> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');

  final ApiService _apiService = ApiService();
  final AdherenciaService _adherenciaService = AdherenciaService();
  late Future<List<PlanNutricional>> _planesFuture;
  final TextEditingController _searchController = TextEditingController();
  final Map<int, Future<AdherenciaMetricaSemanal?>> _adherenciaNutriByPaciente =
      {};
  String _searchText = '';
  bool _showSearchField = false;
  bool _showFilterPlanes = false;
  String _filtroCompletado = 'No completados';

  @override
  void initState() {
    super.initState();
    _loadUiState();
    _refreshPlanes();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshPlanes() {
    setState(() {
      _adherenciaNutriByPaciente.clear();
      if (widget.paciente != null) {
        _planesFuture = _apiService.getPlanes(widget.paciente!.codigo);
      } else {
        // Obtener todos los planes
        _planesFuture = _apiService.getPlanes(null);
      }
    });
  }

  Future<AdherenciaMetricaSemanal?> _getAdherenciaNutriPaciente(
    int codigoPaciente,
  ) {
    return _adherenciaNutriByPaciente.putIfAbsent(codigoPaciente, () async {
      final resumen = await _adherenciaService.getResumenSemanal(
        userCode: codigoPaciente.toString(),
        incluirNutri: true,
        incluirFit: false,
        codigoUsuarioConsulta: codigoPaciente,
      );
      return resumen.nutri;
    });
  }

  Color _adherenciaColorByPercent(int percent) {
    if (percent >= 75) return Colors.green;
    if (percent >= 50) return Colors.orange;
    return Colors.red;
  }

  AdherenciaEstado? _parseEstado(dynamic raw) {
    final normalized = raw?.toString().trim().toLowerCase();
    if (normalized == 'cumplido') return AdherenciaEstado.cumplido;
    if (normalized == 'parcial') return AdherenciaEstado.parcial;
    if (normalized == 'no' || normalized == 'no_realizado') {
      return AdherenciaEstado.noRealizado;
    }
    return null;
  }

  bool _isTipoNutri(dynamic raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    return value == 'nutri' || value == 'plan_nutri';
  }

  Color _estadoColor(AdherenciaEstado estado) {
    switch (estado) {
      case AdherenciaEstado.cumplido:
        return Colors.green;
      case AdherenciaEstado.parcial:
        return Colors.amber;
      case AdherenciaEstado.noRealizado:
        return Colors.red;
    }
  }

  String _estadoLabel(AdherenciaEstado estado) {
    switch (estado) {
      case AdherenciaEstado.cumplido:
        return 'Completo';
      case AdherenciaEstado.parcial:
        return 'Parcial';
      case AdherenciaEstado.noRealizado:
        return 'No realizado';
    }
  }

  Widget _buildCumplimientoCircle({
    required int percent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: (percent.clamp(0, 100)) / 100,
              strokeWidth: 4,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                _adherenciaColorByPercent(percent),
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCumplimientoDetalleNutri(int codigoPaciente) async {
    try {
      final records = await _apiService.getAdherenciaRegistros(
        codigoUsuario: codigoPaciente,
      );

      final items = records
          .where((item) => _isTipoNutri(item['tipo']))
          .map((item) {
            final estado = _parseEstado(item['estado']);
            final fecha = DateTime.tryParse(item['fecha']?.toString() ?? '');
            if (estado == null || fecha == null) {
              return null;
            }
            final motivo = item['observacion']?.toString().trim();
            return {
              'estado': estado,
              'fecha': fecha,
              'motivo': (motivo == null || motivo.isEmpty) ? null : motivo,
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort(
          (a, b) => (b['fecha'] as DateTime).compareTo(a['fecha'] as DateTime),
        );

      final today = DateTime.now();
      final cutoff = DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: 29));

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          var showAll = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final visibleItems = showAll
                  ? items
                  : items
                      .where(
                        (entry) => (entry['fecha'] as DateTime)
                            .isAfter(cutoff.subtract(const Duration(days: 1))),
                      )
                      .toList();

              return AlertDialog(
                title: const Text('Cumplimiento Plan Nutri'),
                content: SizedBox(
                  width: 460,
                  child: items.isEmpty
                      ? const Text(
                          'No hay registros de cumplimiento para mostrar.')
                      : visibleItems.isEmpty
                          ? const Text(
                              'No hay registros en los últimos 30 días.')
                          : SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: visibleItems.map((entry) {
                                  final estado =
                                      entry['estado'] as AdherenciaEstado;
                                  final fecha = entry['fecha'] as DateTime;
                                  final motivo = entry['motivo'] as String?;
                                  final color = _estadoColor(estado);
                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _estadoLabel(estado),
                                              style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              DateFormat('dd/MM/yyyy')
                                                  .format(fecha),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (motivo != null) ...[
                                          const SizedBox(height: 6),
                                          Text('Motivo: $motivo'),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                ),
                actions: [
                  if (items.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          showAll = !showAll;
                        });
                      },
                      child: Text(showAll ? 'Últimos 30 días' : 'Ver todo'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cerrar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cargar el detalle de cumplimiento: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final showSearch = prefs.getBool('planes_show_search_field') ?? false;
    final showFilter = prefs.getBool('planes_show_filter') ?? false;
    final filtroCompletado =
        prefs.getString('planes_filtro_completado') ?? 'No completados';
    if (!mounted) return;
    setState(() {
      _showSearchField = showSearch;
      _showFilterPlanes = showFilter;
      _filtroCompletado = filtroCompletado;
    });
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('planes_show_search_field', _showSearchField);
    await prefs.setBool('planes_show_filter', _showFilterPlanes);
    await prefs.setString('planes_filtro_completado', _filtroCompletado);
  }

  List<PlanNutricional> _filterPlanes(List<PlanNutricional> planes) {
    // Filtrar por estado de completado
    if (_filtroCompletado == 'No completados') {
      planes = planes.where((plan) => plan.completado != 'S').toList();
    }

    // Filtrar por texto de búsqueda
    if (_searchText.isEmpty) {
      return planes;
    }

    return planes.where((plan) {
      final semanas = (plan.semanas ?? '').toLowerCase();
      final planIndicaciones = (plan.planIndicaciones ?? '').toLowerCase();
      final planIndicacionesVisibleUsuario =
          (plan.planIndicacionesVisibleUsuario ?? '').toLowerCase();
      final planDocumentoNombre =
          (plan.planDocumentoNombre ?? '').toLowerCase();
      final nombrePaciente = (plan.nombrePaciente ?? '').toLowerCase();

      return semanas.contains(_searchText) ||
          planIndicaciones.contains(_searchText) ||
          planIndicacionesVisibleUsuario.contains(_searchText) ||
          planDocumentoNombre.contains(_searchText) ||
          nombrePaciente.contains(_searchText);
    }).toList();
  }

  void _navigateToEditScreen([PlanNutricional? plan]) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => PlanEditScreen(
              paciente: widget.paciente,
              plan: plan,
            ),
          ),
        )
        .then((_) => _refreshPlanes());
  }

  String _buildFileName(PlanNutricional plan) {
    final pacienteNombre =
        widget.paciente?.nombre ?? plan.nombrePaciente ?? 'Paciente';
    final primeraPalabra = pacienteNombre.trim().split(' ').first;
    final semanas = (plan.semanas ?? 'SinSemanas').replaceAll(' ', '');
    final desdeStr = plan.desde != null
        ? DateFormat('dd-MM-yyyy').format(plan.desde!)
        : 'SinFecha';
    final hastaStr = plan.hasta != null
        ? DateFormat('dd-MM-yyyy').format(plan.hasta!)
        : 'SinFecha';
    return 'Plan_${primeraPalabra}_${semanas}_Del_${desdeStr}_al_$hastaStr.pdf';
  }

  Future<void> _downloadAndOpenFile(PlanNutricional plan) async {
    final fileName = _buildFileName(plan);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Descargando $fileName...')),
    );
    try {
      final filePath = await _apiService.downloadPlan(plan.codigo, fileName);
      if (filePath != null) {
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('No se pudo abrir el fichero: ${result.message}'),
                backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error en la descarga: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final configService =
        context.watch<ConfigService>(); // Se necesita para el modo debug

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.paciente != null
            ? 'Planes Nutri de ${widget.paciente!.nombre}'
            : 'Planes Nutri'),
        actions: [
          IconButton(
            icon: Icon(_showFilterPlanes
                ? Icons.filter_alt
                : Icons.filter_alt_outlined),
            tooltip: _showFilterPlanes ? 'Ocultar filtro' : 'Mostrar filtro',
            onPressed: () {
              setState(() {
                _showFilterPlanes = !_showFilterPlanes;
              });
              _saveUiState();
            },
          ),
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _refreshPlanes),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_showFilterPlanes)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: "No completados", label: Text('No compl.')),
                        ButtonSegment(value: "Todos", label: Text('Todos')),
                      ],
                      selected: {_filtroCompletado},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _filtroCompletado = newSelection.first;
                        });
                        _saveUiState();
                      },
                    ),
                    IconButton(
                      icon: Icon(
                          _showSearchField ? Icons.search_off : Icons.search),
                      onPressed: () {
                        setState(() {
                          _showSearchField = !_showSearchField;
                          if (!_showSearchField) {
                            _searchController.clear();
                          }
                        });
                        _saveUiState();
                      },
                      tooltip: _showSearchField
                          ? 'Ocultar búsqueda'
                          : 'Mostrar búsqueda',
                    ),
                  ],
                ),
              ),
            if (_showSearchField)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar en paciente, semanas, indicaciones...',
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
            Expanded(
              child: FutureBuilder<List<PlanNutricional>>(
                future: _planesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    // --- LÓGICA DE ERROR DUAL (DEBUG/NORMAL) ---
                    final errorMessage = snapshot.error.toString();
                    // DEBUG: Imprime el error completo en la consola
                    // debugPrint('Error al cargar planes: $errorMessage');
                    if (configService.appMode == AppMode.debug) {
                      return Center(
                          child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: SelectableText(errorMessage)));
                    } else {
                      return const Center(
                          child: Text("Error al cargar los planes."));
                    }
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text("No se encontraron planes nutricionales."));
                  }

                  final planes = _filterPlanes(snapshot.data!);

                  if (planes.isEmpty && _searchText.isNotEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron planes',
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

                  if (planes.isEmpty) {
                    return const Center(
                        child: Text("No se encontraron planes nutricionales."));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: planes.length,
                    itemBuilder: (context, index) {
                      final plan = planes[index];

                      final desdeStr = plan.desde != null
                          ? DateFormat('dd/MM/yyyy').format(plan.desde!)
                          : null;
                      final hastaStr = plan.hasta != null
                          ? DateFormat('dd/MM/yyyy').format(plan.hasta!)
                          : null;

                      // Construir el título del plan según las fechas disponibles
                      final planTitle = desdeStr == null
                          ? hastaStr != null
                              ? 'Plan nutri de $hastaStr'
                              : 'Plan nutri'
                          : hastaStr != null
                              ? 'Plan nutri del $desdeStr al $hastaStr'
                              : 'Plan nutri del $desdeStr';

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Paciente + Título del plan
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.paciente?.nombre ??
                                        plan.nombrePaciente ??
                                        'Paciente',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    planTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  final codigoPaciente = plan.codigoPaciente ??
                                      widget.paciente?.codigo;
                                  if (codigoPaciente == null ||
                                      codigoPaciente <= 0) {
                                    return const SizedBox.shrink();
                                  }
                                  return FutureBuilder<
                                      AdherenciaMetricaSemanal?>(
                                    future: _getAdherenciaNutriPaciente(
                                      codigoPaciente,
                                    ),
                                    builder: (context, adhSnapshot) {
                                      if (adhSnapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        );
                                      }
                                      final pct =
                                          adhSnapshot.data?.porcentaje ?? 0;
                                      return Row(
                                        children: [
                                          const Text(
                                            'Cumplimiento paciente:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildCumplimientoCircle(
                                            percent: pct,
                                            onTap: () =>
                                                _showCumplimientoDetalleNutri(
                                              codigoPaciente,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 12),

                              // Semanas (con icono y tag)
                              if (plan.semanas != null &&
                                  plan.semanas!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Chip(
                                    avatar: const Icon(Icons.calendar_today,
                                        size: 16),
                                    label: Text('${plan.semanas} semanas'),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),

                              // Indicaciones (recuadro amarillo, expandido al ancho)
                              if (plan.planIndicacionesVisibleUsuario != null &&
                                  plan.planIndicacionesVisibleUsuario!
                                      .isNotEmpty) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12.0),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.amber[300]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    plan.planIndicacionesVisibleUsuario!,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Primera fila: Descargar, Completar, Clonar, URL
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 6,
                                  children: [
                                    if (plan.planDocumentoNombre != null &&
                                        plan.planDocumentoNombre!.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons
                                            .download_for_offline_outlined),
                                        color: Colors.blue,
                                        onPressed: () =>
                                            _downloadAndOpenFile(plan),
                                        tooltip: 'Descargar',
                                        iconSize: 30,
                                      ),
                                    if (plan.completado != 'S')
                                      IconButton(
                                        icon: const Icon(Icons.check),
                                        color: Colors.green,
                                        onPressed: () =>
                                            _showCompletarPlanDialog(plan),
                                        tooltip: 'Completar',
                                        iconSize: 30,
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.content_copy),
                                      color: Colors.purple,
                                      onPressed: () => _clonPlan(plan),
                                      tooltip: 'Clonar',
                                      iconSize: 30,
                                    ),
                                    if (plan.url != null &&
                                        plan.url!.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.open_in_browser),
                                        color: Colors.blue,
                                        onPressed: () =>
                                            _launchUrlExternal(plan.url ?? ''),
                                        tooltip: 'Ver en navegador',
                                        iconSize: 30,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Segunda fila: Editar, Eliminar
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 6,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      color: Colors.blue,
                                      onPressed: () =>
                                          _navigateToEditScreen(plan),
                                      tooltip: 'Editar',
                                      iconSize: 30,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      color: Colors.red,
                                      onPressed: () =>
                                          _showDeleteConfirmation(plan),
                                      tooltip: 'Eliminar',
                                      iconSize: 30,
                                    ),
                                  ],
                                ),
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditScreen(),
        tooltip: 'Añadir Plan',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteConfirmation(PlanNutricional plan) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content:
              const Text('¿Estás seguro de que quieres eliminar este plan?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deletePlan(plan.codigo);
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  void _deletePlan(int codigo) async {
    try {
      final success = await _apiService.deletePlan(codigo);
      if (success) {
        _refreshPlanes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Plan eliminado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar el plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showCompletarPlanDialog(PlanNutricional plan) async {
    final TextEditingController indicacionesController =
        TextEditingController(text: plan.planIndicaciones ?? '');
    final TextEditingController indicacionesVisiblesController =
        TextEditingController(text: plan.planIndicacionesVisibleUsuario ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Completar Plan Nutricional'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Indicaciones (para el profesional):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: indicacionesController,
                  maxLines: 4,
                  minLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Indicaciones para el profesional...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Indicaciones (visibles para el usuario):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: indicacionesVisiblesController,
                  maxLines: 4,
                  minLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Indicaciones visibles para el usuario...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _completarPlanNutricional(
                  plan,
                  indicacionesController.text,
                  indicacionesVisiblesController.text,
                );
              },
              icon: const Icon(Icons.check),
              label: const Text('Completar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completarPlanNutricional(
    PlanNutricional plan,
    String indicaciones,
    String indicacionesVisibles,
  ) async {
    try {
      // Crear una copia actualizada del plan
      final planActualizado = PlanNutricional(
        codigo: plan.codigo,
        codigoPaciente: plan.codigoPaciente,
        desde: plan.desde,
        hasta: plan.hasta,
        semanas: plan.semanas,
        completado: 'S',
        codigoEntrevista: plan.codigoEntrevista,
        planDocumentoNombre: plan.planDocumentoNombre,
        planIndicaciones: indicaciones,
        planIndicacionesVisibleUsuario: indicacionesVisibles,
        nombrePaciente: plan.nombrePaciente,
      );

      await _apiService.updatePlan(planActualizado, null);

      _refreshPlanes();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan nutricional completado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _truncateIndicaciones(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return text.substring(0, maxChars);
  }

  Future<void> _clonPlan(PlanNutricional plan) async {
    try {
      // Confirmación de clonación
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clonar plan'),
          content:
              const Text('¿Desea realizar una copia del Plan Nutri actual?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No')),
            TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sí')),
          ],
        ),
      );

      if (confirm != true) return;
      // Mostrar diálogo de progreso
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            title: Text('Clonando plan...'),
            content: SizedBox(
              height: 50,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        );
      }

      // Calcular intervalo de días entre desde y hasta
      int intervaloDias = 0;
      if (plan.desde != null && plan.hasta != null) {
        intervaloDias = plan.hasta!.difference(plan.desde!).inDays;
      }

      // Crear nuevo plan con fechas actualizadas
      final hoy = DateTime.now();
      final planNuevo = PlanNutricional(
        codigo: 0, // El servidor asignará el código
        codigoPaciente: plan.codigoPaciente,
        desde: hoy,
        hasta: intervaloDias > 0 ? hoy.add(Duration(days: intervaloDias)) : hoy,
        semanas: plan.semanas,
        completado: 'N', // Siempre 'N' para un plan clonado
        codigoEntrevista: null, // Vacío para plan clonado
        planDocumentoNombre: null, // Vacío, no clonamos archivo
        planIndicaciones: plan.planIndicaciones,
        planIndicacionesVisibleUsuario: plan.planIndicacionesVisibleUsuario,
        url: plan.url,
        nombrePaciente: plan.nombrePaciente,
      );

      // Crear el nuevo plan
      await _apiService.createPlan(planNuevo, null);

      // Esperar un poco para que el servidor procese la creación
      await Future.delayed(const Duration(milliseconds: 500));

      // Cerrar diálogo de progreso
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Refrescar lista
      _refreshPlanes();

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Plan clonado exitosamente del ${DateFormat('dd/MM/yyyy').format(plan.desde ?? DateTime.now())} '
              'al ${DateFormat('dd/MM/yyyy').format(hoy.add(Duration(days: intervaloDias)))}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Cerrar diálogo de progreso si está abierto
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al clonar plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchUrlExternal(String url) async {
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        await _externalUrlChannel.invokeMethod('openUrl', {'url': url});
        return;
      }
      rethrow;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir la URL: $url'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
