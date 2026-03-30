import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/plan_nutri_estructura.dart';
import 'package:nutri_app/models/plan_nutricional.dart';
import 'package:nutri_app/screens/planes_nutricionales/plan_edit_screen.dart';
import 'package:nutri_app/screens/planes_nutricionales/plan_nutri_estructura_screen.dart';
import 'package:nutri_app/screens/planes_nutricionales/plan_nutri_reverse_builder_screen.dart';
import 'package:nutri_app/services/adherencia_service.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/services/plan_nutri_pdf_service.dart';
import 'package:nutri_app/services/plan_nutri_word_service.dart';
import 'package:nutri_app/services/plan_nutri_excel_service.dart';
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

  String _truncateRecomendaciones(String text, {int maxChars = 200}) {
    final normalized = text.trim();
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars)}...';
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

  bool _canOpenPlanStructure(PlanNutricional plan) {
    if (plan.desde != null && plan.hasta != null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Primero debes introducir la fecha de inicio y la fecha de fin del plan para generar las semanas en el calendario.',
        ),
        backgroundColor: Colors.orange,
      ),
    );
    return false;
  }

  bool _planNeedsDateRange(PlanNutricional plan) {
    return plan.desde == null || plan.hasta == null;
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

  // ignore: unused_element
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

  Future<void> _generatePlanPdf(PlanNutricional plan) async {
    try {
      await PlanNutriPdfService.generateWithOptions(
        context: context,
        apiService: _apiService,
        plan: plan,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
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
                              // Indicaciones (recuadro amarillo, expandido al ancho)
                              if (Theme.of(context).platform !=
                                      TargetPlatform.iOS &&
                                  Theme.of(context).platform !=
                                      TargetPlatform.android &&
                                  plan.planIndicacionesVisibleUsuario != null &&
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
                                    _truncateRecomendaciones(
                                      plan.planIndicacionesVisibleUsuario!,
                                    ),
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  final codigoPaciente = plan.codigoPaciente ??
                                      widget.paciente?.codigo;
                                  final semanasWidget = (plan.semanas != null &&
                                          plan.semanas!.isNotEmpty)
                                      ? Chip(
                                          avatar: const Icon(
                                              Icons.calendar_today,
                                              size: 16),
                                          label:
                                              Text('${plan.semanas} semanas'),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        )
                                      : null;
                                  if (codigoPaciente == null ||
                                      codigoPaciente <= 0) {
                                    if (semanasWidget != null) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12.0),
                                        child: semanasWidget,
                                      );
                                    }
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
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12.0),
                                        child: Wrap(
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            if (semanasWidget != null)
                                              semanasWidget,
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Cto.:',
                                                  style: const TextStyle(
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
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),

                              if (_planNeedsDateRange(plan)) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Faltan fecha de inicio y/o fecha de fin. Para estructurar el plan, primero introdúcelas en Editar plan.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Primera fila: Completar, Clonar, Editar, Eliminar
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 6,
                                  children: [
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
                              const SizedBox(height: 8),
                              // Segunda fila: Estructurar normal, rápido, calendario, PDF
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 6,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                          Icons.table_chart_outlined),
                                      color: Colors.indigo,
                                      onPressed: () async {
                                        if (!_canOpenPlanStructure(plan)) {
                                          return;
                                        }
                                        final changed =
                                            await Navigator.of(context)
                                                .push<bool>(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PlanNutriEstructuraScreen(
                                              plan: plan,
                                            ),
                                          ),
                                        );
                                        if (changed == true) {
                                          _refreshPlanes();
                                        }
                                      },
                                      tooltip: 'Estructurar plan',
                                      iconSize: 30,
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.ads_click_outlined,
                                      ),
                                      color: Colors.teal,
                                      onPressed: () async {
                                        if (!_canOpenPlanStructure(plan)) {
                                          return;
                                        }
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PlanNutriReverseBuilderScreen(
                                              plan: plan,
                                              onSwitchToNormal: () {
                                                Navigator.of(
                                                  context,
                                                ).pushReplacement(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        PlanNutriEstructuraScreen(
                                                      plan: plan,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                        _refreshPlanes();
                                      },
                                      tooltip: 'Estructurar rápido',
                                      iconSize: 30,
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.calendar_month_outlined,
                                      ),
                                      color: Colors.amber.shade800,
                                      onPressed: () async {
                                        if (!_canOpenPlanStructure(plan)) {
                                          return;
                                        }
                                        final changed =
                                            await Navigator.of(context)
                                                .push<bool>(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PlanNutriEstructuraScreen(
                                              plan: plan,
                                              openCalendarBuilderOnStart: true,
                                            ),
                                          ),
                                        );
                                        if (changed == true) {
                                          _refreshPlanes();
                                        }
                                      },
                                      tooltip: 'Estructurar desde calendario',
                                      iconSize: 30,
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.picture_as_pdf_outlined,
                                      ),
                                      color: Colors.deepOrange,
                                      onPressed: () => _generatePlanPdf(plan),
                                      tooltip: 'Generar PDF del plan',
                                      iconSize: 30,
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.article_outlined,
                                      ),
                                      color: Colors.blue.shade700,
                                      onPressed: () => PlanNutriWordService
                                          .generateWithOptions(
                                        context: context,
                                        apiService: _apiService,
                                        plan: plan,
                                      ),
                                      tooltip: 'Word',
                                      iconSize: 30,
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.table_chart_outlined,
                                      ),
                                      color: Colors.green.shade700,
                                      onPressed: () => PlanNutriExcelService
                                          .generateWithOptions(
                                        context: context,
                                        apiService: _apiService,
                                        plan: plan,
                                      ),
                                      tooltip: 'Excel',
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
                  'Indicaciones (pacciente):',
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
                  'Indicaciones (visibles para paciente):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: indicacionesVisiblesController,
                  maxLines: 4,
                  minLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Indicaciones visibles para el paciente...',
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

  // ignore: unused_element
  String _truncateIndicaciones(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return text.substring(0, maxChars);
  }

  bool _hasVisibleStructure(PlanNutriEstructura estructura) {
    if (estructura.semanas.isEmpty) return false;
    for (final semana in estructura.semanas) {
      for (final dia in semana.dias) {
        for (final ingesta in dia.ingestas) {
          if (ingesta.items.isNotEmpty) {
            return true;
          }
        }
      }
    }
    return false;
  }

  String _normalizeCloneText(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }

  String _weekTitleForClone(PlanNutriSemana semana) {
    final title = (semana.titulo ?? '').trim();
    if (title.isNotEmpty) return title;
    return 'Semana ${semana.numeroSemana}';
  }

  bool _isDefaultWeekTitle(String? title, int numeroSemana) {
    final normalized = _normalizeCloneText(title ?? '');
    return normalized.isEmpty || normalized == 'semana $numeroSemana';
  }

  List<_PlanNutriCloneBulkOption> _buildWeekdayBulkOptions(
    List<_PlanNutriCloneWeekNode> weeks,
  ) {
    final map = <int, String>{};
    for (final week in weeks) {
      for (final day in week.days) {
        map[day.dayOfWeek] = day.dayName;
      }
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map(
          (entry) => _PlanNutriCloneBulkOption(
            key: entry.key.toString(),
            label: entry.value,
            sortOrder: entry.key,
          ),
        )
        .toList();
  }

  List<_PlanNutriCloneBulkOption> _buildMealBulkOptions(
    List<_PlanNutriCloneWeekNode> weeks,
  ) {
    const mealOrder = {
      'desayuno': 1,
      'almuerzo': 2,
      'comida': 3,
      'merienda': 4,
      'cena': 5,
    };
    final map = <String, _PlanNutriCloneBulkOption>{};
    for (final week in weeks) {
      for (final day in week.days) {
        for (final meal in day.meals) {
          map.putIfAbsent(
            meal.normalizedType,
            () => _PlanNutriCloneBulkOption(
              key: meal.normalizedType,
              label: meal.label,
              sortOrder: mealOrder[meal.normalizedType] ?? 99,
            ),
          );
        }
      }
    }
    final values = map.values.toList()
      ..sort((a, b) {
        final cmp = a.sortOrder.compareTo(b.sortOrder);
        if (cmp != 0) return cmp;
        return a.label.compareTo(b.label);
      });
    return values;
  }

  List<_PlanNutriCloneWeekNode> _buildCloneSelectionTree(
    PlanNutriEstructura estructura,
  ) {
    return estructura.semanas.map((semana) {
      return _PlanNutriCloneWeekNode(
        semana: semana,
        selected: true,
        days: semana.dias.map((dia) {
          return _PlanNutriCloneDayNode(
            dia: dia,
            selected: true,
            meals: dia.ingestas.map((ingesta) {
              final label = ingesta.tipoIngesta.trim().isEmpty
                  ? 'Ingesta'
                  : ingesta.tipoIngesta.trim();
              return _PlanNutriCloneMealNode(
                ingesta: ingesta,
                selected: true,
                label: label,
                normalizedType: _normalizeCloneText(label),
              );
            }).toList(),
          );
        }).toList(),
      );
    }).toList();
  }

  void _toggleWeekSelection(_PlanNutriCloneWeekNode week, bool selected) {
    week.selected = selected;
    for (final day in week.days) {
      day.selected = selected;
      for (final meal in day.meals) {
        meal.selected = selected;
      }
    }
  }

  void _toggleDaySelection(
      _PlanNutriCloneWeekNode week, _PlanNutriCloneDayNode day, bool selected) {
    day.selected = selected;
    for (final meal in day.meals) {
      meal.selected = selected;
    }
    week.selected = week.days.any((entry) => entry.selected);
  }

  void _toggleMealSelection(
    _PlanNutriCloneWeekNode week,
    _PlanNutriCloneDayNode day,
    _PlanNutriCloneMealNode meal,
    bool selected,
  ) {
    meal.selected = selected;
    day.selected = day.meals.any((entry) => entry.selected);
    week.selected = week.days.any((entry) => entry.selected);
  }

  void _setAllCloneSelections(
    List<_PlanNutriCloneWeekNode> weeks,
    bool selected,
  ) {
    for (final week in weeks) {
      _toggleWeekSelection(week, selected);
    }
  }

  void _setWeekdaySelectionAcrossWeeks(
    List<_PlanNutriCloneWeekNode> weeks,
    int dayOfWeek,
    bool selected,
  ) {
    for (final week in weeks) {
      for (final day
          in week.days.where((entry) => entry.dayOfWeek == dayOfWeek)) {
        _toggleDaySelection(week, day, selected);
      }
    }
  }

  void _setMealSelectionAcrossWeeks(
    List<_PlanNutriCloneWeekNode> weeks,
    String normalizedMeal,
    bool selected,
  ) {
    for (final week in weeks) {
      for (final day in week.days) {
        for (final meal in day.meals
            .where((entry) => entry.normalizedType == normalizedMeal)) {
          _toggleMealSelection(week, day, meal, selected);
        }
      }
    }
  }

  bool _isWeekdaySelectedAcrossWeeks(
    List<_PlanNutriCloneWeekNode> weeks,
    int dayOfWeek,
  ) {
    final matchingDays = <_PlanNutriCloneDayNode>[];
    for (final week in weeks) {
      matchingDays.addAll(
        week.days.where((entry) => entry.dayOfWeek == dayOfWeek),
      );
    }
    if (matchingDays.isEmpty) return false;
    return matchingDays.every((entry) => entry.selected);
  }

  bool _isMealSelectedAcrossWeeks(
    List<_PlanNutriCloneWeekNode> weeks,
    String normalizedMeal,
  ) {
    final matchingMeals = <_PlanNutriCloneMealNode>[];
    for (final week in weeks) {
      for (final day in week.days) {
        matchingMeals.addAll(
          day.meals.where((entry) => entry.normalizedType == normalizedMeal),
        );
      }
    }
    if (matchingMeals.isEmpty) return false;
    return matchingMeals.every((entry) => entry.selected);
  }

  int _countSelectedWeeks(List<_PlanNutriCloneWeekNode> weeks) {
    return weeks
        .where((week) =>
            week.days.any((day) => day.meals.any((meal) => meal.selected)))
        .length;
  }

  PlanNutriEstructura _buildFilteredStructureForClone(
    PlanNutriEstructura estructura,
    List<_PlanNutriCloneWeekNode> weeks,
  ) {
    final clonedWeeks = <PlanNutriSemana>[];
    var nextWeekNumber = 1;

    for (final weekNode in weeks) {
      final clonedDays = <PlanNutriDia>[];
      for (final dayNode in weekNode.days) {
        final clonedMeals = dayNode.meals
            .where((meal) => meal.selected)
            .map((meal) => PlanNutriIngesta.fromJson(meal.ingesta.toJson()))
            .toList();
        if (clonedMeals.isEmpty) continue;

        final dayClone = PlanNutriDia.fromJson(dayNode.dia.toJson());
        dayClone.codigo = null;
        dayClone.ingestas = clonedMeals;
        clonedDays.add(dayClone);
      }

      if (clonedDays.isEmpty) continue;

      final weekClone = PlanNutriSemana.fromJson(weekNode.semana.toJson());
      weekClone.codigo = null;
      weekClone.numeroSemana = nextWeekNumber;
      weekClone.orden = nextWeekNumber;
      if (_isDefaultWeekTitle(weekClone.titulo, weekNode.semana.numeroSemana)) {
        weekClone.titulo = 'Semana $nextWeekNumber';
      }
      weekClone.dias = clonedDays;
      clonedWeeks.add(weekClone);
      nextWeekNumber++;
    }

    return PlanNutriEstructura(
      codigoPlanNutricional: 0,
      tituloPlan: estructura.tituloPlan,
      objetivoPlan: estructura.objetivoPlan,
      planIndicaciones: estructura.planIndicaciones,
      planIndicacionesVisibleUsuario: estructura.planIndicacionesVisibleUsuario,
      recetas: const [],
      semanas: clonedWeeks,
    );
  }

  Future<String?> _showCloneTargetDialog() {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'Clonar plan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            Material(
              color: Colors.grey.shade200,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(null),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('¿Dónde desea clonar el Plan Nutri?'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop('mismo'),
                    child: const Text(
                      'Mismo paciente',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop('otro'),
                    child: const Text(
                      'Otro paciente',
                      style: TextStyle(fontWeight: FontWeight.w700),
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

  Future<Paciente?> _showPacienteSelectorDialog({
    int? initialSelectedPacienteId,
  }) async {
    try {
      final pacientes = await _apiService.getPacientes();
      if (pacientes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay pacientes disponibles'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return null;
      }

      var tempSelected = initialSelectedPacienteId;
      final searchController = TextEditingController();

      final selectedId = await showDialog<int?>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setStateDialog) {
            final query = searchController.text.trim().toLowerCase();
            final filtered = pacientes.where((paciente) {
              if (query.isEmpty) return true;
              return paciente.nombre.toLowerCase().contains(query);
            }).toList();

            return AlertDialog(
              title: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Seleccionar paciente',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(dialogContext),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.all(4),
                      minimumSize: const Size(32, 32),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Buscar paciente...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 380),
                      child: filtered.isEmpty
                          ? const Center(child: Text('Sin resultados'))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final paciente = filtered[index];
                                return ListTile(
                                  dense: true,
                                  onTap: () => setStateDialog(
                                    () => tempSelected = paciente.codigo,
                                  ),
                                  leading: Radio<int>(
                                    value: paciente.codigo,
                                    groupValue: tempSelected,
                                    onChanged: (value) => setStateDialog(
                                      () => tempSelected = value,
                                    ),
                                  ),
                                  title: Text(paciente.nombre),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, tempSelected),
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        ),
      );

      if (selectedId == null) return null;
      for (final paciente in pacientes) {
        if (paciente.codigo == selectedId) return paciente;
      }
      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar pacientes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<_PlanNutriCloneSelectionResult?> _showStructureCloneDialog(
    PlanNutriEstructura estructura,
  ) {
    final weeks = _buildCloneSelectionTree(estructura);
    final weekdayOptions = _buildWeekdayBulkOptions(weeks);
    final mealOptions = _buildMealBulkOptions(weeks);

    return showDialog<_PlanNutriCloneSelectionResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final selectedWeekCount = _countSelectedWeeks(weeks);

          return AlertDialog(
            title: const Text('Seleccionar estructura a clonar'),
            content: SizedBox(
              width: 760,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 620),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Marca las semanas, días e ingestas que quieres copiar. Los alimentos de cada ingesta marcada se clonarán completos.',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => setStateDialog(
                              () => _setAllCloneSelections(weeks, true),
                            ),
                            child: const Text('Marcar todo'),
                          ),
                          OutlinedButton(
                            onPressed: () => setStateDialog(
                              () => _setAllCloneSelections(weeks, false),
                            ),
                            child: const Text('Desmarcar todo'),
                          ),
                        ],
                      ),
                      if (weekdayOptions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Días para todas las semanas',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: weekdayOptions.map((option) {
                            final dayOfWeek = int.tryParse(option.key) ?? 0;
                            final selected =
                                _isWeekdaySelectedAcrossWeeks(weeks, dayOfWeek);
                            return FilterChip(
                              label: Text(option.label),
                              selected: selected,
                              onSelected: (_) => setStateDialog(
                                () => _setWeekdaySelectionAcrossWeeks(
                                  weeks,
                                  dayOfWeek,
                                  !selected,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      if (mealOptions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Ingestas para todas las semanas',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: mealOptions.map((option) {
                            final selected = _isMealSelectedAcrossWeeks(
                              weeks,
                              option.key,
                            );
                            return FilterChip(
                              label: Text(option.label),
                              selected: selected,
                              onSelected: (_) => setStateDialog(
                                () => _setMealSelectionAcrossWeeks(
                                  weeks,
                                  option.key,
                                  !selected,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ...weeks.map((week) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CheckboxListTile(
                                  value: week.selected,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(
                                    _weekTitleForClone(week.semana),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${week.days.length} días',
                                  ),
                                  onChanged: (value) => setStateDialog(
                                    () => _toggleWeekSelection(
                                      week,
                                      value ?? false,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ...week.days.map((day) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CheckboxListTile(
                                          value: day.selected,
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          title: Text(day.dayName),
                                          onChanged: (value) => setStateDialog(
                                            () => _toggleDaySelection(
                                              week,
                                              day,
                                              value ?? false,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 24,
                                            bottom: 8,
                                          ),
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: day.meals.map((meal) {
                                              return FilterChip(
                                                label: Text(meal.label),
                                                selected: meal.selected,
                                                onSelected: (selected) =>
                                                    setStateDialog(
                                                  () => _toggleMealSelection(
                                                    week,
                                                    day,
                                                    meal,
                                                    selected,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(
                    _PlanNutriCloneSelectionResult(
                      estructura: _buildFilteredStructureForClone(
                        estructura,
                        weeks,
                      ),
                      selectedWeekCount: selectedWeekCount,
                    ),
                  );
                },
                child: Text(
                  selectedWeekCount > 0
                      ? 'Clonar selección'
                      : 'Clonar sin estructura',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _clonPlan(PlanNutricional plan) async {
    var progressVisible = false;
    try {
      final opcionClonacion = await _showCloneTargetDialog();
      if (opcionClonacion == null) return;

      var codigoPacienteDestino = plan.codigoPaciente;
      var nombrePacienteDestino = plan.nombrePaciente;

      if (opcionClonacion == 'otro') {
        final pacienteDestino = await _showPacienteSelectorDialog(
          initialSelectedPacienteId: plan.codigoPaciente,
        );
        if (pacienteDestino == null) return;
        codigoPacienteDestino = pacienteDestino.codigo;
        nombrePacienteDestino = pacienteDestino.nombre;
      }

      if (codigoPacienteDestino == null || codigoPacienteDestino <= 0) {
        throw Exception('No se ha podido determinar el paciente de destino.');
      }

      PlanNutriEstructura? estructuraSeleccionada;
      var selectedWeekCount = 0;

      try {
        final estructuraOriginal =
            await _apiService.getPlanNutriEstructura(plan.codigo);
        if (_hasVisibleStructure(estructuraOriginal)) {
          if (!mounted) return;
          final seleccion = await _showStructureCloneDialog(estructuraOriginal);
          if (seleccion == null) return;
          estructuraSeleccionada = seleccion.estructura;
          selectedWeekCount = seleccion.selectedWeekCount;
        }
      } catch (e) {
        throw Exception('No se pudo cargar la estructura del plan: $e');
      }

      if (mounted) {
        showDialog(
          context: context,
          useRootNavigator: true,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            title: Text('Clonando plan...'),
            content: SizedBox(
              height: 50,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        );
        progressVisible = true;
      }

      int intervaloDias = 0;
      if (plan.desde != null && plan.hasta != null) {
        intervaloDias = plan.hasta!.difference(plan.desde!).inDays;
      }

      final hoy = DateTime.now();
      final structureSelectionShown = estructuraSeleccionada != null;
      final hasSelectedStructure =
          estructuraSeleccionada != null && selectedWeekCount > 0;
      final planNuevo = PlanNutricional(
        codigo: 0,
        codigoPaciente: codigoPacienteDestino,
        tituloPlan: plan.tituloPlan,
        objetivoPlan: plan.objetivoPlan,
        desde: hoy,
        hasta: intervaloDias > 0 ? hoy.add(Duration(days: intervaloDias)) : hoy,
        semanas: hasSelectedStructure
            ? selectedWeekCount.toString()
            : (structureSelectionShown ? null : plan.semanas),
        totalSemanas: hasSelectedStructure
            ? selectedWeekCount
            : (structureSelectionShown ? null : plan.totalSemanas),
        usaEstructuraDetallada: hasSelectedStructure ? 'S' : 'N',
        completado: 'N',
        codigoEntrevista: null,
        planDocumentoNombre: null,
        planIndicaciones: plan.planIndicaciones,
        planIndicacionesVisibleUsuario: plan.planIndicacionesVisibleUsuario,
        url: plan.url,
        nombrePaciente: nombrePacienteDestino,
      );

      final nuevoCodigoPlan =
          await _apiService.createPlanAndReturnCodigo(planNuevo, null);

      if (hasSelectedStructure && estructuraSeleccionada != null) {
        estructuraSeleccionada.codigoPlanNutricional = nuevoCodigoPlan;
        await _apiService.savePlanNutriEstructura(estructuraSeleccionada);
      }

      if (progressVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        progressVisible = false;
      }

      _refreshPlanes();

      if (mounted) {
        final semanasClonadas = hasSelectedStructure
            ? '$selectedWeekCount semana${selectedWeekCount == 1 ? '' : 's'}'
            : 'sin estructura seleccionada';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Plan clonado correctamente para ${nombrePacienteDestino ?? 'el paciente destino'} ($semanasClonadas).',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (progressVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al clonar plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ignore: unused_element
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

class _PlanNutriCloneMealNode {
  _PlanNutriCloneMealNode({
    required this.ingesta,
    required this.label,
    required this.normalizedType,
    this.selected = true,
  });

  final PlanNutriIngesta ingesta;
  final String label;
  final String normalizedType;
  bool selected;
}

class _PlanNutriCloneDayNode {
  _PlanNutriCloneDayNode({
    required this.dia,
    required this.meals,
    this.selected = true,
  });

  final PlanNutriDia dia;
  final List<_PlanNutriCloneMealNode> meals;
  bool selected;

  int get dayOfWeek => dia.diaSemana;
  String get dayName => dia.nombreDia;
}

class _PlanNutriCloneWeekNode {
  _PlanNutriCloneWeekNode({
    required this.semana,
    required this.days,
    this.selected = true,
  });

  final PlanNutriSemana semana;
  final List<_PlanNutriCloneDayNode> days;
  bool selected;
}

class _PlanNutriCloneBulkOption {
  const _PlanNutriCloneBulkOption({
    required this.key,
    required this.label,
    required this.sortOrder,
  });

  final String key;
  final String label;
  final int sortOrder;
}

class _PlanNutriCloneSelectionResult {
  const _PlanNutriCloneSelectionResult({
    required this.estructura,
    required this.selectedWeekCount,
  });

  final PlanNutriEstructura estructura;
  final int selectedWeekCount;
}
