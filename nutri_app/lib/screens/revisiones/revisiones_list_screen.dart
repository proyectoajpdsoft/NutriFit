import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/revision.dart';
import 'package:nutri_app/screens/revisiones/revision_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/services/revisiones_pdf_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RevisionesListScreen extends StatefulWidget {
  final Paciente? paciente; // Made optional

  const RevisionesListScreen({super.key, this.paciente});

  @override
  _RevisionesListScreenState createState() => _RevisionesListScreenState();
}

class _RevisionesListScreenState extends State<RevisionesListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Revision>> _revisionesFuture;
  String _filtroCompletada = "N";
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _showSearchField = false;
  bool _showFilterRevisiones = false;
  final Map<int, double?> _pesosAnteriores =
      {}; // Cacheo de pesos anteriores por paciente
  final Map<int, Paciente> _pacientesCache = {}; // Cacheo de datos de pacientes

  @override
  void initState() {
    super.initState();
    _loadUiStateAndRefresh();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
  }

  Future<void> _loadUiStateAndRefresh() async {
    await _loadUiState();
    if (mounted) {
      _refreshRevisiones();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final filtro = prefs.getString('revisiones_filtro_completada') ?? 'N';
    final showSearch = prefs.getBool('revisiones_show_search_field') ?? false;
    final showFilter = prefs.getBool('revisiones_show_filter') ?? false;
    if (!mounted) return;
    setState(() {
      _filtroCompletada = filtro;
      _showSearchField = showSearch;
      _showFilterRevisiones = showFilter;
    });
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('revisiones_filtro_completada', _filtroCompletada);
    await prefs.setBool('revisiones_show_search_field', _showSearchField);
    await prefs.setBool('revisiones_show_filter', _showFilterRevisiones);
  }

  void _refreshRevisiones() {
    setState(() {
      _revisionesFuture = _apiService.getRevisiones(
          codigoPaciente: widget.paciente?.codigo, // Pass optional patient code
          completada: _filtroCompletada == "Todas" ? null : _filtroCompletada);
    });
  }

  List<Revision> _filterRevisiones(List<Revision> revisiones) {
    if (_searchText.isEmpty) {
      return revisiones;
    }

    return revisiones.where((revision) {
      final nombrePaciente = (revision.nombrePaciente ?? '').toLowerCase();
      final asunto = (revision.asunto).toLowerCase();
      final semanas = (revision.semanas).toLowerCase();
      final modificacionDieta =
          (revision.modificacionDieta ?? '').toLowerCase();

      return nombrePaciente.contains(_searchText) ||
          asunto.contains(_searchText) ||
          semanas.contains(_searchText) ||
          modificacionDieta.contains(_searchText);
    }).toList();
  }

  Future<double?> _getPesoAnterior(int codigoPaciente) async {
    // Si ya está en caché, devolverlo
    if (_pesosAnteriores.containsKey(codigoPaciente)) {
      return _pesosAnteriores[codigoPaciente];
    }

    try {
      // Obtener todas las entrevistas del paciente
      final entrevistas = await _apiService.getEntrevistas(codigoPaciente);

      // Filtrar entrevistas que tienen peso y ordenar por fecha
      final entrevistasConPeso = entrevistas
          .where((e) => e.peso != null && e.fechaRealizacion != null)
          .toList()
        ..sort((a, b) => b.fechaRealizacion!.compareTo(a.fechaRealizacion!));

      // Si hay al menos una entrevista con peso, devolver el más reciente
      if (entrevistasConPeso.isNotEmpty) {
        final pesoAnterior = entrevistasConPeso.first.peso;
        _pesosAnteriores[codigoPaciente] = pesoAnterior;
        return pesoAnterior;
      }
    } catch (e) {
      // En caso de error, guardar null en caché
      _pesosAnteriores[codigoPaciente] = null;
    }

    _pesosAnteriores[codigoPaciente] = null;
    return null;
  }

  Future<Paciente?> _getPacienteData(int codigoPaciente) async {
    // Si ya está en caché, devolverlo
    if (_pacientesCache.containsKey(codigoPaciente)) {
      return _pacientesCache[codigoPaciente];
    }

    try {
      final pacientes = await _apiService.getPacientes();
      final paciente = pacientes.firstWhere(
        (p) => p.codigo == codigoPaciente,
        orElse: () => throw Exception('Paciente no encontrado'),
      );
      _pacientesCache[codigoPaciente] = paciente;
      return paciente;
    } catch (e) {
      return null;
    }
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 16.0) return 'Infrapeso: Delgadez Severa';
    if (bmi < 17.0) return 'Infrapeso: Delgadez moderada';
    if (bmi < 18.5) return 'Infrapeso: Delgadez aceptable';
    if (bmi < 25.0) return 'Peso Normal';
    if (bmi < 30.0) return 'Sobrepeso';
    if (bmi < 35.0) return 'Obeso: Tipo I';
    if (bmi < 40.0) return 'Obeso: Tipo II';
    return 'Obeso: Tipo III';
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 16.0) return Colors.red.shade800;
    if (bmi < 17.0) return Colors.deepOrange;
    if (bmi < 18.5) return Colors.orange;
    if (bmi < 25.0) return Colors.green;
    if (bmi < 30.0) return Colors.lime.shade700;
    if (bmi < 35.0) return Colors.deepOrange;
    if (bmi < 40.0) return Colors.red;
    return Colors.red.shade800;
  }

  void _showBmiInfoDialog(double bmi) {
    final bmiColor = _getBmiColor(bmi);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IMC (OMS)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bmiColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: bmiColor.withOpacity(0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monitor_weight, size: 18, color: bmiColor),
                  const SizedBox(width: 6),
                  Text(
                    'IMC ${bmi.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: bmiColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getBmiCategory(bmi),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text('Tipos:'),
            const SizedBox(height: 6),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('- Infrapeso: Delgadez Severa'),
                Text('- Infrapeso: Delgadez moderada'),
                Text('- Infrapeso: Delgadez aceptable'),
                Text('- Peso Normal'),
                Text('- Sobrepeso'),
                Text('- Obeso: Tipo I'),
                Text('- Obeso: Tipo II'),
                Text('- Obeso: Tipo III'),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text('IMC = peso (kg) / altura (m)²'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _navigateToEditScreen([Revision? revision]) async {
    Paciente? pacienteToUse = widget.paciente;

    if (pacienteToUse == null && revision != null) {
      // Cargar el paciente de la revisión
      try {
        final pacientes = await _apiService.getPacientes();
        pacienteToUse = pacientes.firstWhere(
          (p) => p.codigo == revision.codigoPaciente,
        );
      } catch (e) {
        if (mounted) {
          final errorMessage = e.toString().replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar el paciente. $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    if (pacienteToUse == null && revision == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione un paciente para crear una revisión'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (pacienteToUse != null && mounted) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => RevisionEditScreen(
                revision: revision,
                paciente: pacienteToUse!,
              ),
            ),
          )
          .then((_) => _refreshRevisiones());
    }
  }

  Future<void> _deleteRevision(int codigo) async {
    try {
      final success = await _apiService.deleteRevision(codigo);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Revisión eliminada'),
              backgroundColor: Colors.green),
        );
        _refreshRevisiones();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al eliminar'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.paciente != null
            ? 'Revisiones de ${widget.paciente!.nombre}'
            : 'Todas las Revisiones'),
        actions: [
          IconButton(
            icon: Icon(_showFilterRevisiones
                ? Icons.filter_alt
                : Icons.filter_alt_outlined),
            tooltip:
                _showFilterRevisiones ? 'Ocultar filtro' : 'Mostrar filtro',
            onPressed: () {
              setState(() {
                _showFilterRevisiones = !_showFilterRevisiones;
              });
              _saveUiState();
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Generar PDF',
            onPressed: _generateRevisionesPdf,
          ),
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _refreshRevisiones),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_showFilterRevisiones)
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: "N", label: Text('No completadas')),
                          ButtonSegment(value: "Todas", label: Text('Todas')),
                        ],
                        selected: {_filtroCompletada},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _filtroCompletada = newSelection.first;
                          });
                          _saveUiState();
                          _refreshRevisiones();
                        },
                      ),
                    ),
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
            if (_showSearchField)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar en asunto, semanas, modificación...',
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
              child: FutureBuilder<List<Revision>>(
                future: _revisionesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    final errorMessage = snapshot.error.toString();
                    // debugPrint('Error al cargar revisiones: $errorMessage');
                    if (configService.appMode == AppMode.debug) {
                      return Center(
                          child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: SelectableText(errorMessage)));
                    } else {
                      return const Center(
                          child: Text("Error al cargar las revisiones."));
                    }
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text("No se encontraron revisiones."));
                  }

                  var revisiones = snapshot.data!;
                  revisiones = _filterRevisiones(revisiones);

                  if (revisiones.isEmpty && _searchText.isNotEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron revisiones',
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

                  if (revisiones.isEmpty) {
                    return const Center(
                        child: Text("No se encontraron revisiones."));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: revisiones.length,
                    itemBuilder: (context, index) {
                      final revision = revisiones[index];

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nombre del paciente
                              if ((revision.nombrePaciente ??
                                      widget.paciente?.nombre) !=
                                  null) ...[
                                Text(
                                  revision.nombrePaciente ??
                                      widget.paciente!.nombre,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              // Tags de Semanas, Prevista, Realizada
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (revision.semanas.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.blue[200]!,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.calendar_view_week,
                                            size: 14,
                                            color: Colors.blue,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            revision.semanas,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (revision.fechaPrevista != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[50],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.orange[200]!,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.event,
                                            size: 14,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            DateFormat('dd/MM/yyyy HH:mm')
                                                .format(
                                                    revision.fechaPrevista!),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (revision.fechaRealizacion != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.green[200]!,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            size: 14,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            DateFormat('dd/MM/yyyy').format(
                                                revision.fechaRealizacion!),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              // Tags de peso (en línea separada)
                              if (revision.peso != null &&
                                  revision.codigoPaciente != null) ...[
                                const SizedBox(height: 6),
                                FutureBuilder<List<dynamic>>(
                                  future: Future.wait([
                                    _getPesoAnterior(revision.codigoPaciente!),
                                    _getPacienteData(revision.codigoPaciente!),
                                  ]),
                                  builder: (context, snapshot) {
                                    final pesoAnterior =
                                        snapshot.data?[0] as double?;
                                    final paciente =
                                        snapshot.data?[1] as Paciente?;
                                    final pesoActual = revision.peso!;
                                    double? diferencia;
                                    double? bmi;

                                    if (pesoAnterior != null) {
                                      diferencia = pesoActual - pesoAnterior;
                                    }

                                    // Calcular IMC si hay altura disponible
                                    if (paciente?.altura != null &&
                                        paciente!.altura! > 0) {
                                      final alturaMetros =
                                          paciente.altura! / 100;
                                      bmi = pesoActual /
                                          (alturaMetros * alturaMetros);
                                    }

                                    return Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        // Peso actual
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.purple[50],
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                              color: Colors.purple[200]!,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.scale,
                                                size: 14,
                                                color: Colors.purple,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                pesoActual.toStringAsFixed(1),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.purple[700],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // IMC (si hay altura disponible)
                                        if (bmi != null)
                                          InkWell(
                                            onTap: () =>
                                                _showBmiInfoDialog(bmi!),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _getBmiColor(bmi)
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: _getBmiColor(bmi)
                                                      .withOpacity(0.6),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.analytics,
                                                    size: 14,
                                                    color: _getBmiColor(bmi),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'IMC ${bmi.toStringAsFixed(1)}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: _getBmiColor(bmi),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        // Peso anterior (si existe)
                                        if (pesoAnterior != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.grey[300]!,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.history,
                                                  size: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  ' ${pesoAnterior.toStringAsFixed(1)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        // Diferencia (si existe peso anterior)
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
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                                                  size: 14,
                                                  color: diferencia < 0
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${diferencia > 0 ? '+' : ''}${diferencia.toStringAsFixed(1)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
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
                                    );
                                  },
                                ),
                              ],
                              // Asunto con fondo amarillo
                              if (revision.asunto.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[100],
                                    borderRadius: BorderRadius.circular(6),
                                    border:
                                        Border.all(color: Colors.amber[300]!),
                                  ),
                                  child: Text(
                                    revision.asunto,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  if (revision.completada != 'S')
                                    IconButton(
                                      icon: const Icon(Icons.check),
                                      color: Colors.green,
                                      iconSize: 28,
                                      onPressed: () =>
                                          _showCompletarRevisionDialog(
                                              revision),
                                      tooltip: 'Completar',
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    color: Colors.blue,
                                    iconSize: 28,
                                    onPressed: () =>
                                        _navigateToEditScreen(revision),
                                    tooltip: 'Editar',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    iconSize: 28,
                                    onPressed: () =>
                                        _showDeleteConfirmation(revision),
                                    tooltip: 'Eliminar',
                                  ),
                                ],
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
        onPressed: () {
          if (widget.paciente != null) {
            _navigateToEditScreen();
          } else {
            _showPacienteSelectorAndAdd();
          }
        },
        tooltip: 'Añadir Revisión',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showPacienteSelectorAndAdd() async {
    try {
      final pacientes = await _apiService.getPacientes();
      if (!mounted) return;

      Paciente? selected;
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Nueva Revisión'),
            content: SizedBox(
              width: double.maxFinite,
              child: DropdownButtonFormField<Paciente>(
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Seleccione un paciente'),
                items: pacientes
                    .map((p) => DropdownMenuItem<Paciente>(
                          value: p,
                          child: Text(p.nombre),
                        ))
                    .toList(),
                onChanged: (value) {
                  selected = value;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  if (selected != null) {
                    Navigator.of(context).pop();
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (context) => RevisionEditScreen(
                              paciente: selected!,
                            ),
                          ),
                        )
                        .then((_) => _refreshRevisiones());
                  }
                },
                child: const Text('Continuar'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showDeleteConfirmation(Revision revision) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
              '¿Seguro que quieres eliminar la revisión del ${DateFormat('dd/MM/yyyy').format(revision.fechaPrevista!)}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteRevision(revision.codigo);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCompletarRevisionDialog(Revision revision) async {
    DateTime selectedDate = revision.fechaRealizacion ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    final TextEditingController modificacionController =
        TextEditingController(text: revision.modificacionDieta ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Completar Revisión'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(selectedDate.copyWith(hour: selectedTime.hour, minute: selectedTime.minute))}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                          locale: const Locale('es', 'ES'),
                          keyboardType: TextInputType.datetime,
                          helpText: 'Introduzca la fecha (dd/mm/yyyy)',
                        );
                        if (pickedDate != null) {
                          setState(() => selectedDate = pickedDate);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Hora: ${selectedTime.format(context)}'),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (pickedTime != null) {
                          setState(() => selectedTime = pickedTime);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Modificación de la dieta:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: modificacionController,
                      maxLines: 4,
                      minLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Modificación de la dieta...',
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
                    _completarRevision(
                      revision,
                      selectedDate.copyWith(
                        hour: selectedTime.hour,
                        minute: selectedTime.minute,
                      ),
                      modificacionController.text,
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Completar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _completarRevision(
    Revision revision,
    DateTime fechaRealizacion,
    String modificacionDieta,
  ) async {
    try {
      final authService = context.read<AuthService>();
      final codusuario = authService.userCode;

      // Crear una copia actualizada de la revisión
      final revisionActualizada = Revision(
        codigo: revision.codigo,
        codigoPaciente: revision.codigoPaciente,
        nombrePaciente: revision.nombrePaciente,
        pacienteActivo: revision.pacienteActivo,
        asunto: revision.asunto,
        fechaPrevista: revision.fechaPrevista,
        fechaRealizacion: fechaRealizacion,
        semanas: revision.semanas,
        modificacionDieta: modificacionDieta,
        completada: 'S',
        online: revision.online,
        peso: revision.peso,
      );

      await _apiService.updateRevision(revisionActualizada);

      _refreshRevisiones();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisión completada correctamente'),
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

  Future<void> _generateRevisionesPdf() async {
    try {
      // Cargar revisiones
      final revisiones = await _revisionesFuture;

      // Cargar pacientes
      final pacientes = await _apiService.getPacientes();
      final pacientesMap = {for (final p in pacientes) p.codigo: p};

      // Obtener parámetros del nutricionista
      final nutricionistaParam =
          await _apiService.getParametro('nutricionista_nombre');
      final nutricionistaNombre =
          nutricionistaParam?['valor']?.toString() ?? 'Nutricionista';
      final nutricionistaSubtitulo =
          nutricionistaParam?['valor2']?.toString() ?? '';

      final logoParam =
          await _apiService.getParametro('logotipo_dietista_documentos');
      final logoBase64 = logoParam?['valor']?.toString() ?? '';
      final logoSizeStr = logoParam?['valor2']?.toString() ?? '';
      Uint8List? logoBytes;
      if (logoBase64.isNotEmpty) {
        try {
          logoBytes = _decodeBase64Image(logoBase64);
        } catch (_) {
          logoBytes = null;
        }
      }

      // Obtener color de acento
      final accentColorParam = await _apiService
          .getParametro('color_fondo_banda_encabezado_pie_pdf');
      final accentColorStr = accentColorParam?['valor']?.toString() ?? '';

      if (!mounted) return;

      // Determinar filtro para el título del PDF
      final String filtroActivo;
      if (widget.paciente != null) {
        // Si es de un paciente específico, usar 'Activos'
        filtroActivo = 'S';
      } else {
        // Si es del listado general, usar 'Todos'
        filtroActivo = 'N';
      }

      await RevisionesPdfService.generateRevisionesPdf(
        context: context,
        nutricionistaNombre: nutricionistaNombre,
        nutricionistaSubtitulo: nutricionistaSubtitulo,
        logoBytes: logoBytes,
        logoSizeStr: logoSizeStr,
        accentColorStr: accentColorStr,
        revisiones: revisiones,
        pacientesMap: pacientesMap,
        filtroActivo: filtroActivo,
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

  static Uint8List? _decodeBase64Image(String base64String) {
    final raw = base64String.trim();
    if (raw.isEmpty) {
      return null;
    }
    var data = raw;
    const marker = 'base64,';
    final index = raw.indexOf(marker);
    if (index >= 0) {
      data = raw.substring(index + marker.length);
    }
    while (data.length % 4 != 0) {
      data += '=';
    }
    try {
      return Uint8List.fromList(base64Decode(data));
    } catch (_) {
      return null;
    }
  }
}
