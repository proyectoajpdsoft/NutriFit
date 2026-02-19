import 'package:flutter/material.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/plan_fit.dart';
import 'package:nutri_app/models/plan_fit_dia.dart';
import 'package:nutri_app/models/plan_fit_ejercicio.dart';
import 'package:nutri_app/screens/planes_fit/plan_fit_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/services/plan_fit_pdf_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
// import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PlanFitPdfOptions {
  final bool fichaPorDias;
  final bool showMiniThumbs;
  final bool showConsejos;
  final bool showRecomendaciones;

  const _PlanFitPdfOptions({
    required this.fichaPorDias,
    required this.showMiniThumbs,
    required this.showConsejos,
    required this.showRecomendaciones,
  });
}

class PlanesFitListScreen extends StatefulWidget {
  final Paciente? paciente;
  const PlanesFitListScreen({super.key, this.paciente});

  @override
  State<PlanesFitListScreen> createState() => _PlanesFitListScreenState();
}

class _PlanesFitListScreenState extends State<PlanesFitListScreen> {
  static const _pdfFullPrefix = 'plan_fit_pdf_full';
  static const _pdfResumenPrefix = 'plan_fit_pdf_resumen';
  final ApiService _apiService = ApiService();
  late Future<List<PlanFit>> _planesFuture;
  final TextEditingController _searchController = TextEditingController();
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
      if (widget.paciente != null) {
        _planesFuture = _apiService.getPlanesFit(widget.paciente!.codigo);
      } else {
        _planesFuture = _apiService.getPlanesFit(null);
      }
    });
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final showSearch = prefs.getBool('planes_fit_show_search_field') ?? false;
    final showFilter = prefs.getBool('planes_fit_show_filter') ?? false;
    final filtroCompletado =
        prefs.getString('planes_fit_filtro_completado') ?? 'No completados';
    if (!mounted) return;
    setState(() {
      _showSearchField = showSearch;
      _showFilterPlanes = showFilter;
      _filtroCompletado = filtroCompletado;
    });
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('planes_fit_show_search_field', _showSearchField);
    await prefs.setBool('planes_fit_show_filter', _showFilterPlanes);
    await prefs.setString('planes_fit_filtro_completado', _filtroCompletado);
  }

  List<PlanFit> _filterPlanes(List<PlanFit> planes) {
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
      final url = (plan.url ?? '').toLowerCase();

      return semanas.contains(_searchText) ||
          planIndicaciones.contains(_searchText) ||
          planIndicacionesVisibleUsuario.contains(_searchText) ||
          planDocumentoNombre.contains(_searchText) ||
          nombrePaciente.contains(_searchText) ||
          url.contains(_searchText);
    }).toList();
  }

  void _navigateToEditScreen(
    PlanFit? plan, {
    bool openDayDialog = false,
    bool openExerciseDialog = false,
  }) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => PlanFitEditScreen(
              paciente: widget.paciente,
              plan: plan,
              openDayDialog: openDayDialog,
              openExerciseDialog: openExerciseDialog,
            ),
          ),
        )
        .then((_) => _refreshPlanes());
  }

  String _buildFileName(PlanFit plan) {
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
    return 'PlanFit_${primeraPalabra}_${semanas}_Del_${desdeStr}_al_$hastaStr.pdf';
  }

  Future<Map<String, int>> _getPlanCounts(int planCodigo) async {
    try {
      final results = await Future.wait([
        _apiService.getPlanFitEjercicios(planCodigo),
        _apiService.getDiasPlanFit(planCodigo),
      ]);
      final ejercicios = results[0] as List<PlanFitEjercicio>;
      final dias = results[1] as List<PlanFitDia>;
      return {
        'ejercicios': ejercicios.length,
        'dias': dias.length,
      };
    } catch (_) {
      return {
        'ejercicios': 0,
        'dias': 0,
      };
    }
  }

  Future<void> _generatePlanFitPdf(PlanFit plan) async {
    final options = await _showPlanFitPdfOptionsDialog(showFichaOptions: true);
    if (options == null) return;
    await PlanFitPdfService.generatePlanFitPdf(
      context: context,
      apiService: _apiService,
      plan: plan,
      fileName: _buildFileName(plan),
      fichaPorDias: options.fichaPorDias,
      showMiniThumbs: options.showMiniThumbs,
      showConsejos: options.showConsejos,
      showRecomendaciones: options.showRecomendaciones,
    );
  }

  Future<void> _generatePlanFitPdfResumen(PlanFit plan) async {
    final options = await _showPlanFitPdfOptionsDialog(showFichaOptions: false);
    if (options == null) return;
    await PlanFitPdfService.generatePlanFitPdf(
      context: context,
      apiService: _apiService,
      plan: plan,
      fileName: _buildFileName(plan),
      resumen: true,
      showMiniThumbs: options.showMiniThumbs,
      showConsejos: options.showConsejos,
      showRecomendaciones: options.showRecomendaciones,
    );
  }

  Future<_PlanFitPdfOptions?> _showPlanFitPdfOptionsDialog({
    required bool showFichaOptions,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final modePrefix = showFichaOptions ? _pdfFullPrefix : _pdfResumenPrefix;
    String key(String suffix) => '${modePrefix}_$suffix';
    var fichaPorDias = prefs.getBool(key('ficha_por_dias')) ?? true;
    var showMiniThumbs = prefs.getBool(key('show_mini_thumbs')) ?? false;
    var showConsejos = prefs.getBool(key('show_consejos')) ?? true;
    var showRecomendaciones =
        prefs.getBool(key('show_recomendaciones')) ?? true;
    return showDialog<_PlanFitPdfOptions>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Opciones del PDF'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showFichaOptions) ...[
                    RadioListTile<bool>(
                      value: true,
                      groupValue: fichaPorDias,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => fichaPorDias = value);
                      },
                      title: const Text('Ficha por días'),
                    ),
                    RadioListTile<bool>(
                      value: false,
                      groupValue: fichaPorDias,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => fichaPorDias = value);
                      },
                      title: const Text('Ficha únicos'),
                    ),
                  ],
                  SwitchListTile(
                    value: showMiniThumbs,
                    onChanged: (value) {
                      setState(() => showMiniThumbs = value);
                    },
                    title: const Text('Mostrar miniatura'),
                  ),
                  SwitchListTile(
                    value: showConsejos,
                    onChanged: (value) {
                      setState(() => showConsejos = value);
                    },
                    title: const Text('Mostrar consejos'),
                  ),
                  SwitchListTile(
                    value: showRecomendaciones,
                    onChanged: (value) {
                      setState(() => showRecomendaciones = value);
                    },
                    title: const Text('Mostrar recomendaciones'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    prefs.setBool(key('ficha_por_dias'), fichaPorDias);
                    prefs.setBool(key('show_mini_thumbs'), showMiniThumbs);
                    prefs.setBool(key('show_consejos'), showConsejos);
                    prefs.setBool(
                        key('show_recomendaciones'), showRecomendaciones);
                    Navigator.of(dialogContext).pop(
                      _PlanFitPdfOptions(
                        fichaPorDias: fichaPorDias,
                        showMiniThumbs: showMiniThumbs,
                        showConsejos: showConsejos,
                        showRecomendaciones: showRecomendaciones,
                      ),
                    );
                  },
                  child: const Text('Generar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _downloadAndOpenFile(PlanFit plan) async {
    final fileName = _buildFileName(plan);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Descargando $fileName...')),
    );
    try {
      final filePath = await _apiService.downloadPlanFit(plan.codigo, fileName);
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
    final configService = context.watch<ConfigService>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.paciente != null
            ? 'Planes Fit de ${widget.paciente!.nombre}'
            : 'Planes Fit'),
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
                    hintText:
                        'Buscar en paciente, semanas, indicaciones, URL...',
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
              child: FutureBuilder<List<PlanFit>>(
                future: _planesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    final errorMessage = snapshot.error.toString();
                    // debugPrint('Error al cargar planes fit: $errorMessage');
                    if (configService.appMode == AppMode.debug) {
                      return Center(
                          child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: SelectableText(errorMessage)));
                    } else {
                      return const Center(
                          child: Text("Error al cargar los planes fit."));
                    }
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text("No se encontraron planes fit."));
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
                            'No se encontraron planes fit',
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
                        child: Text("No se encontraron planes fit."));
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
                              ? 'Plan fit de $hastaStr'
                              : 'Plan fit'
                          : hastaStr != null
                              ? 'Desde $desdeStr hasta $hastaStr'
                              : 'Desde $desdeStr';

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
                              const SizedBox(height: 12),

                              // Semanas + Ejercicios + Días
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Semanas
                                  if (plan.semanas != null &&
                                      plan.semanas!.isNotEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: Chip(
                                        avatar: const Icon(Icons.calendar_today,
                                            size: 16),
                                        label: Text('${plan.semanas} sem'),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  // Ejercicios + Días
                                  FutureBuilder<Map<String, int>>(
                                    future: _getPlanCounts(plan.codigo),
                                    builder: (context, snapshot) {
                                      final data = snapshot.data ??
                                          const {'ejercicios': 0, 'dias': 0};
                                      final ejercicios =
                                          data['ejercicios'] ?? 0;
                                      final dias = data['dias'] ?? 0;
                                      return Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (ejercicios > 0)
                                            Chip(
                                              avatar: const Icon(
                                                  Icons.fitness_center,
                                                  size: 16),
                                              label: Text('$ejercicios ej'),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                          if (dias > 0)
                                            Chip(
                                              avatar: const Icon(
                                                  Icons.date_range,
                                                  size: 16),
                                              label: Text('$dias días'),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

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

                              // Primera fila: Generar, Resumen, Descargar, Clonar, Completar
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 6,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.picture_as_pdf),
                                      color: Colors.red,
                                      onPressed: () =>
                                          _generatePlanFitPdf(plan),
                                      tooltip: 'Generar PDF',
                                      iconSize: 30,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.summarize),
                                      color: Colors.orange,
                                      onPressed: () =>
                                          _generatePlanFitPdfResumen(plan),
                                      tooltip: 'Resumen PDF',
                                      iconSize: 30,
                                    ),
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
                                    IconButton(
                                      icon: const Icon(Icons.content_copy),
                                      color: Colors.purple,
                                      onPressed: () => _clonPlan(plan),
                                      tooltip: 'Clonar',
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
                                      icon: const Icon(Icons.open_in_browser),
                                      color: Colors.blue,
                                      onPressed: () async {
                                        // try {
                                        //   String urlString =
                                        //       plan.url?.trim() ?? '';
                                        //   if (urlString.isEmpty) {
                                        //     throw Exception('URL vacía');
                                        //   }
                                        //   if (!urlString
                                        //           .startsWith('http://') &&
                                        //       !urlString
                                        //           .startsWith('https://')) {
                                        //     urlString = 'https://$urlString';
                                        //   }
                                        //   Uri url;
                                        //   try {
                                        //     url = Uri.parse(urlString);
                                        //   } catch (_) {
                                        //     url = Uri.parse(
                                        //         Uri.encodeFull(urlString));
                                        //   }
                                        //
                                        //   if (await canLaunchUrl(url)) {
                                        //     final opened = await launchUrl(url,
                                        //         mode: LaunchMode
                                        //             .externalApplication);
                                        //     if (!opened) {
                                        //       throw Exception(
                                        //           'No se pudo abrir la URL');
                                        //     }
                                        //   } else {
                                        //     throw Exception(
                                        //         'No se puede lanzar la URL');
                                        //   }
                                        // } catch (e) {
                                        //   if (context.mounted) {
                                        //     ScaffoldMessenger.of(context)
                                        //         .showSnackBar(
                                        //       SnackBar(
                                        //         content: Text(
                                        //             'No se pudo abrir la URL: ${plan.url}'),
                                        //         backgroundColor: Colors.red,
                                        //       ),
                                        //     );
                                        //   }
                                        // }
                                      },
                                      tooltip: 'Ver en navegador',
                                      iconSize: 30,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Segunda fila: URL, Día, Ejercicio, Editar, Eliminar
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 6,
                                  children: [
                                    if (plan.url != null &&
                                        plan.url!.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.open_in_browser),
                                        color: Colors.blue,
                                        onPressed: () async {
                                          // try {
                                          //   String urlString = plan.url!.trim();
                                          //   if (!urlString
                                          //           .startsWith('http://') &&
                                          //       !urlString
                                          //           .startsWith('https://')) {
                                          //     urlString = 'https://$urlString';
                                          //   }
                                          //   final Uri url =
                                          //       Uri.parse(urlString);
                                          //   await launchUrl(url,
                                          //       mode: LaunchMode
                                          //           .externalApplication);
                                          // } catch (e) {
                                          //   if (context.mounted) {
                                          //     ScaffoldMessenger.of(context)
                                          //         .showSnackBar(
                                          //       SnackBar(
                                          //         content: Text(
                                          //             'No se pudo abrir la URL: ${plan.url}'),
                                          //         backgroundColor: Colors.red,
                                          //       ),
                                          //     );
                                          //   }
                                          // }
                                        },
                                        tooltip: 'Ver en navegador',
                                        iconSize: 30,
                                      ),
                                    IconButton(
                                      onPressed: () => _navigateToEditScreen(
                                          plan,
                                          openDayDialog: true),
                                      icon: const Icon(Icons.calendar_today),
                                      tooltip: 'Añadir Día',
                                      iconSize: 30,
                                    ),
                                    IconButton(
                                      onPressed: () => _navigateToEditScreen(
                                          plan,
                                          openExerciseDialog: true),
                                      icon: const Icon(Icons.fitness_center),
                                      tooltip: 'Añadir Ejercicio',
                                      iconSize: 30,
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          _navigateToEditScreen(plan),
                                      icon: const Icon(Icons.edit),
                                      color: Colors.blue,
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
        onPressed: () => _navigateToEditScreen(null),
        tooltip: 'Añadir Plan Fit',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteConfirmation(PlanFit plan) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: const Text(
              '¿Estás seguro de que quieres eliminar este plan fit?'),
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

  Future<void> _showCompletarPlanDialog(PlanFit plan) async {
    final TextEditingController indicacionesController =
        TextEditingController(text: plan.planIndicaciones ?? '');
    final TextEditingController indicacionesVisiblesController =
        TextEditingController(text: plan.planIndicacionesVisibleUsuario ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Completar Plan Fit'),
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
                _completarPlanFit(
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

  Future<void> _completarPlanFit(
    PlanFit plan,
    String indicaciones,
    String indicacionesVisibles,
  ) async {
    try {
      // Crear una copia actualizada del plan
      final planActualizado = PlanFit(
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
        url: plan.url,
        nombrePaciente: plan.nombrePaciente,
      );

      await _apiService.updatePlanFit(planActualizado, null);

      _refreshPlanes();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan Fit completado correctamente'),
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

  void _deletePlan(int codigo) async {
    try {
      final success = await _apiService.deletePlanFit(codigo);
      if (success) {
        _refreshPlanes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Plan fit eliminado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar el plan fit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clonPlan(PlanFit plan) async {
    try {
      // Confirmación de clonación
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clonar plan'),
          content: const Text('¿Desea realizar una copia del Plan Fit actual?'),
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

      // Obtener días y ejercicios del plan original
      final diasOriginales = await _apiService.getDiasPlanFit(plan.codigo);
      final ejerciciosOriginales =
          await _apiService.getPlanFitEjercicios(plan.codigo);

      // Calcular intervalo de días entre desde y hasta
      int intervaloDias = 0;
      if (plan.desde != null && plan.hasta != null) {
        intervaloDias = plan.hasta!.difference(plan.desde!).inDays;
      }

      // Crear nuevo plan con fechas actualizadas
      final hoy = DateTime.now();
      final planNuevo = PlanFit(
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
        rondas: plan.rondas,
        consejos: plan.consejos,
        recomendaciones: plan.recomendaciones,
      );

      // Crear el nuevo plan
      await _apiService.createPlanFit(planNuevo, null);

      // Esperar un poco para que el servidor procese la creación
      await Future.delayed(const Duration(milliseconds: 500));

      // Obtener los planes actualizados para encontrar el nuevo
      final planesActualizado =
          await _apiService.getPlanesFit(plan.codigoPaciente);

      // Encontrar el plan recién creado (el más nuevo con fecha desde = hoy)
      PlanFit? nuevoPlanCreado;
      for (final p in planesActualizado) {
        if (p.desde != null &&
            p.desde!.year == hoy.year &&
            p.desde!.month == hoy.month &&
            p.desde!.day == hoy.day) {
          nuevoPlanCreado = p;
          break;
        }
      }

      if (nuevoPlanCreado == null) {
        throw Exception('No se pudo encontrar el plan clonado recién creado');
      }

      // Clonar días
      // Asegurarse de que cada día tenga un `numeroDia` válido (>=1).
      for (var idx = 0; idx < diasOriginales.length; idx++) {
        final dia = diasOriginales[idx];
        final numeroDia = (dia.numeroDia > 0) ? dia.numeroDia : (idx + 1);
        final diaNuevo = PlanFitDia(
          codigo: 0,
          codigoPlanFit: nuevoPlanCreado.codigo,
          numeroDia: numeroDia,
          titulo: dia.titulo,
          descripcion: dia.descripcion,
          orden: dia.orden,
        );
        await _apiService.createDia(diaNuevo);
      }

      // Obtener los nuevos días para mapear códigos (mapear por posición si los
      // número de día no coinciden, para mayor robustez).
      final diasNuevos =
          await _apiService.getDiasPlanFit(nuevoPlanCreado.codigo);

      // Crear un mapa para asociar días antiguos con nuevos (por posición)
      final diaMapeo = <int, int>{};
      for (var i = 0; i < diasOriginales.length && i < diasNuevos.length; i++) {
        diaMapeo[diasOriginales[i].codigo] = diasNuevos[i].codigo;
      }

      // Clonar ejercicios
      try {
        for (final ejercicio in ejerciciosOriginales) {
          final codigoDiaNuevo = ejercicio.codigoDia != null
              ? diaMapeo[ejercicio.codigoDia]
              : null;

          final ejercicioNuevo = PlanFitEjercicio(
            codigo: 0,
            codigoPlanFit: nuevoPlanCreado.codigo,
            codigoDia: codigoDiaNuevo,
            codigoEjercicioCatalogo: ejercicio.codigoEjercicioCatalogo,
            nombre: ejercicio.nombre,
            instrucciones: ejercicio.instrucciones,
            urlVideo: ejercicio.urlVideo,
            fotoBase64: ejercicio.fotoBase64,
            fotoNombre: ejercicio.fotoNombre,
            fotoMiniatura: ejercicio.fotoMiniatura,
            tiempo: ejercicio.tiempo,
            descanso: ejercicio.descanso,
            repeticiones: ejercicio.repeticiones,
            kilos: ejercicio.kilos,
            orden: ejercicio.orden,
          );
          await _apiService.createPlanFitEjercicio(ejercicioNuevo, null);
        }
      } catch (e) {
        debugPrint('Advertencia: Error al clonar ejercicios: $e');
        // No lanzar excepción aquí, los días ya se han creado exitosamente
      }

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
              'al ${DateFormat('dd/MM/yyyy').format(nuevoPlanCreado.hasta ?? DateTime.now())}',
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
}
