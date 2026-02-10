import 'package:flutter/material.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/plan_nutricional.dart';
import 'package:nutri_app/screens/planes_nutricionales/plan_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

class PlanesListScreen extends StatefulWidget {
  final Paciente? paciente;
  const PlanesListScreen({super.key, this.paciente});

  @override
  State<PlanesListScreen> createState() => _PlanesListScreenState();
}

class _PlanesListScreenState extends State<PlanesListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<PlanNutricional>> _planesFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _showSearchField = false;
  String _filtroCompletado = 'No completados';

  @override
  void initState() {
    super.initState();
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
        _planesFuture = _apiService.getPlanes(widget.paciente!.codigo);
      } else {
        // Obtener todos los planes
        _planesFuture = _apiService.getPlanes(null);
      }
    });
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
              icon: const Icon(Icons.refresh), onPressed: _refreshPlanes),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: "No completados",
                          label: Text('No completados')),
                      ButtonSegment(value: "Todos", label: Text('Todos')),
                    ],
                    selected: {_filtroCompletado},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _filtroCompletado = newSelection.first;
                      });
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
                    debugPrint('Error al cargar planes: $errorMessage');
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

                      // --- MANEJO SEGURO DE FECHAS NULAS ---
                      final desdeStr = plan.desde != null
                          ? DateFormat('dd/MM/yyyy').format(plan.desde!)
                          : '-';
                      final hastaStr = plan.hasta != null
                          ? DateFormat('dd/MM/yyyy').format(plan.hasta!)
                          : '-';

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: InkWell(
                          onTap: () => _navigateToEditScreen(plan),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.paciente?.nombre ??
                                            plan.nombrePaciente ??
                                            'Paciente',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Plan del $desdeStr al $hastaStr',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ],
                                  ),
                                  subtitle: (plan.semanas != null &&
                                          plan.semanas!.isNotEmpty)
                                      ? Text(
                                          'Semanas: ${plan.semanas}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        )
                                      : null,
                                ),
                                if (plan.url != null &&
                                    plan.url!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () async {
                                      try {
                                        String urlString = plan.url!.trim();
                                        // Asegurarse de que la URL tenga un esquema
                                        if (!urlString.startsWith('http://') &&
                                            !urlString.startsWith('https://')) {
                                          urlString = 'https://$urlString';
                                        }
                                        final Uri url = Uri.parse(urlString);
                                        await launchUrl(url,
                                            mode:
                                                LaunchMode.externalApplication);
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'No se pudo abrir la URL: ${plan.url}'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.open_in_browser,
                                          size: 16,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Ver en el navegador',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.blue,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (plan.planIndicaciones != null &&
                                    plan.planIndicaciones!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Indicaciones:',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _truncateIndicaciones(
                                        plan.planIndicaciones!, 200),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (plan.planDocumentoNombre != null &&
                                    plan.planDocumentoNombre!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Center(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(
                                          Icons.download_for_offline_outlined),
                                      label: const Text('Descargar plan'),
                                      onPressed: () =>
                                          _downloadAndOpenFile(plan),
                                    ),
                                  ),
                                ],
                                // Botones de acciones
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    if (plan.completado != 'S')
                                      Flexible(
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.check),
                                              label: const Text('Completar'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: () =>
                                                  _showCompletarPlanDialog(
                                                      plan),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      const SizedBox.shrink(),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          color: Colors.blue,
                                          onPressed: () =>
                                              _navigateToEditScreen(plan),
                                          tooltip: 'Editar',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          color: Colors.red,
                                          onPressed: () =>
                                              _showDeleteConfirmation(plan),
                                          tooltip: 'Eliminar',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
}
