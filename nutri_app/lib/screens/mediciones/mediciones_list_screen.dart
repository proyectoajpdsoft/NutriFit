import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/medicion.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/screens/mediciones/bmi_dialog_helper.dart';
import 'package:nutri_app/screens/mediciones/medicion_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/mediciones_pdf_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicionesListScreen extends StatefulWidget {
  final Paciente? paciente;
  final String? filtroActivo;

  const MedicionesListScreen({super.key, this.paciente, this.filtroActivo});

  @override
  _MedicionesListScreenState createState() => _MedicionesListScreenState();
}

class _MedicionesListScreenState extends State<MedicionesListScreen> {
  Future<List<Medicion>>? _medicionesFuture;
  late ApiService _apiService;
  late String _filtroActivo;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _showSearchField = false;
  bool _showFilterMediciones = false;
  final Map<int, Paciente> _pacientesCache = {}; // Cacheo de datos de pacientes
  final Map<int, List<Medicion>> _medicionesPacienteCache =
      {}; // Cacheo de mediciones por paciente

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiService = Provider.of<ApiService>(context);
    _filtroActivo = widget.filtroActivo ?? "S";
    _loadUiState();
    _refreshMediciones();
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

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final filtro = prefs.getString('mediciones_filtro_activo') ?? 'S';
    final showSearch = prefs.getBool('mediciones_show_search_field') ?? false;
    final showFilter = prefs.getBool('mediciones_show_filter') ?? false;
    if (!mounted) return;
    setState(() {
      _filtroActivo = filtro;
      _showSearchField = showSearch;
      _showFilterMediciones = showFilter;
    });
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mediciones_filtro_activo', _filtroActivo);
    await prefs.setBool('mediciones_show_search_field', _showSearchField);
    await prefs.setBool('mediciones_show_filter', _showFilterMediciones);
  }

  void _refreshMediciones() {
    setState(() {
      if (widget.paciente != null) {
        _medicionesFuture = _apiService.getMediciones(widget.paciente!.codigo);
      } else {
        _medicionesFuture = _apiService.getMediciones(null);
      }
    });
  }

  List<Medicion> _filterMediciones(List<Medicion> mediciones) {
    if (_searchText.isEmpty) {
      return mediciones;
    }

    return mediciones.where((medicion) {
      final nombrePaciente = (medicion.nombrePaciente ?? '').toLowerCase();
      final observacion = (medicion.observacion ?? '').toLowerCase();
      final actividadFisica = (medicion.actividadFisica ?? '').toLowerCase();

      return nombrePaciente.contains(_searchText) ||
          observacion.contains(_searchText) ||
          actividadFisica.contains(_searchText);
    }).toList();
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

  Future<List<Medicion>> _getMedicionesPaciente(int codigoPaciente) async {
    // Si ya está en caché, devolverlo
    if (_medicionesPacienteCache.containsKey(codigoPaciente)) {
      return _medicionesPacienteCache[codigoPaciente]!;
    }

    try {
      final mediciones = await _apiService.getMediciones(codigoPaciente);
      // Ordenar por fecha (más reciente primero)
      mediciones.sort((a, b) => b.fecha.compareTo(a.fecha));
      _medicionesPacienteCache[codigoPaciente] = mediciones;
      return mediciones;
    } catch (e) {
      return [];
    }
  }

  String _getBmiCategory(double bmi) {
    return BmiDialogHelper.getBmiCategory(bmi);
  }

  Color _getBmiColor(double bmi) {
    return BmiDialogHelper.getBmiColor(bmi);
  }

  void _showBmiInfoDialog(double bmi) {
    BmiDialogHelper.showBmiInfoDialog(context, bmi);
  }

  void _navigateToEditScreen([Medicion? medicion]) async {
    Paciente? pacienteToUse = widget.paciente;

    if (pacienteToUse == null && medicion != null) {
      // Cargar el paciente de la medición
      try {
        final pacientes = await _apiService.getPacientes();
        pacienteToUse = pacientes.firstWhere(
          (p) => p.codigo == medicion.codigoPaciente,
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

    if (pacienteToUse == null && medicion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione un paciente para crear una medición'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (pacienteToUse != null && mounted) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => MedicionEditScreen(
                medicion: medicion,
                paciente: pacienteToUse!,
              ),
            ),
          )
          .then((_) => _refreshMediciones());
    }
  }

  Future<void> _deleteMedicion(int codigo) async {
    try {
      final success = await _apiService.deleteMedicion(codigo);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Medición eliminada'),
              backgroundColor: Colors.green),
        );
        _refreshMediciones();
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.paciente != null
            ? 'Mediciones de ${widget.paciente!.nombre}'
            : 'Todas las Mediciones'),
        actions: [
          if (widget.paciente != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              color: Colors.red,
              tooltip: 'Generar PDF',
              onPressed: _generatePDFForPatient,
            ),
          IconButton(
            icon: Icon(_showFilterMediciones
                ? Icons.filter_alt
                : Icons.filter_alt_outlined),
            tooltip:
                _showFilterMediciones ? 'Ocultar filtro' : 'Mostrar filtro',
            onPressed: () {
              setState(() {
                _showFilterMediciones = !_showFilterMediciones;
              });
              _saveUiState();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMediciones,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_showFilterMediciones)
              Row(
                children: [
                  if (widget.paciente == null)
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: "S", label: Text('Activos')),
                              ButtonSegment(
                                  value: "Todos", label: Text('Todos')),
                            ],
                            selected: {_filtroActivo},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _filtroActivo = newSelection.first;
                              });
                              _saveUiState();
                              _refreshMediciones();
                            },
                          ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
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
                    hintText: 'Buscar en paciente, observación...',
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
              child: FutureBuilder<List<Medicion>>(
                future: _medicionesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No hay mediciones."));
                  }

                  var mediciones = snapshot.data!;
                  // Filtrar por estado activo si es necesario
                  if (widget.paciente == null && _filtroActivo != "Todos") {
                    mediciones = mediciones
                        .where((m) => m.pacienteActivo == "S")
                        .toList();
                  }

                  mediciones = _filterMediciones(mediciones);

                  if (mediciones.isEmpty && _searchText.isNotEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron mediciones',
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

                  if (mediciones.isEmpty) {
                    return const Center(child: Text("No hay mediciones."));
                  }

                  return ListView.builder(
                    itemCount: mediciones.length,
                    itemBuilder: (context, index) {
                      final medicion = mediciones[index];
                      final nombrePaciente =
                          medicion.nombrePaciente ?? widget.paciente?.nombre;

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nombre del paciente
                              if (nombrePaciente != null) ...[
                                Text(
                                  nombrePaciente,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              // Fecha como tag
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
                                    Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: Colors.blue[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('dd/MM/yyyy')
                                          .format(medicion.fecha),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Tags de peso, IMC y diferencias
                              if (medicion.peso != null) ...[
                                const SizedBox(height: 8),
                                FutureBuilder<List<dynamic>>(
                                  future: Future.wait([
                                    _getPacienteData(medicion.codigoPaciente),
                                    _getMedicionesPaciente(
                                        medicion.codigoPaciente),
                                  ]),
                                  builder: (context, snapshot) {
                                    final paciente =
                                        snapshot.data?[0] as Paciente?;
                                    final todasMediciones =
                                        snapshot.data?[1] as List<Medicion>? ??
                                            [];
                                    final pesoActual = medicion.peso!;
                                    double? bmi;
                                    double? pesoAnterior;
                                    double? pesoInicial;
                                    double? diferencia;
                                    double? diferenciaTotal;

                                    // Calcular IMC si hay altura
                                    if (paciente?.altura != null &&
                                        paciente!.altura! > 0) {
                                      final alturaMetros =
                                          paciente.altura! / 100;
                                      bmi = pesoActual /
                                          (alturaMetros * alturaMetros);
                                    }

                                    // Buscar peso anterior (medición anterior a esta)
                                    final medicionesConPeso = todasMediciones
                                        .where((m) =>
                                            m.peso != null &&
                                            m.codigo != medicion.codigo)
                                        .toList();

                                    if (medicionesConPeso.isNotEmpty) {
                                      // Primera medición (más antigua)
                                      pesoInicial = medicionesConPeso.last.peso;

                                      // Medición anterior (la más reciente antes de esta)
                                      final medicionesAnteriores =
                                          medicionesConPeso
                                              .where((m) => m.fecha
                                                  .isBefore(medicion.fecha))
                                              .toList();
                                      if (medicionesAnteriores.isNotEmpty) {
                                        pesoAnterior =
                                            medicionesAnteriores.first.peso;
                                        diferencia = pesoActual - pesoAnterior!;
                                      }

                                      // Diferencia desde el inicio
                                      if (pesoInicial != null) {
                                        diferenciaTotal =
                                            pesoActual - pesoInicial;
                                      }
                                    }

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Primera fila: Peso, IMC, Anterior, Diferencia
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            // Peso actual
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                    Icons.monitor_weight,
                                                    size: 14,
                                                    color: Colors.purple,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    pesoActual
                                                        .toStringAsFixed(1),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.purple[700],
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // IMC (si hay altura)
                                            if (bmi != null)
                                              InkWell(
                                                onTap: () =>
                                                    _showBmiInfoDialog(bmi!),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _getBmiColor(bmi)
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                    border: Border.all(
                                                      color: _getBmiColor(bmi)
                                                          .withOpacity(0.6),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.analytics,
                                                        size: 14,
                                                        color:
                                                            _getBmiColor(bmi),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'IMC ${bmi.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              _getBmiColor(bmi),
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            // Peso anterior
                                            if (pesoAnterior != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
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
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.history,
                                                      size: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      pesoAnterior
                                                          .toStringAsFixed(1),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            // Diferencia desde medición anterior
                                            if (diferencia != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
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
                                                  mainAxisSize:
                                                      MainAxisSize.min,
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
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        // Segunda fila: Desde inicio
                                        if (pesoInicial != null &&
                                            diferenciaTotal != null) ...[
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[50],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: Colors.blue[200]!,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.start,
                                                      size: 14,
                                                      color: Colors.blue[700],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Inicial: ${pesoInicial.toStringAsFixed(1)}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.blue[700],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: diferenciaTotal < 0
                                                      ? Colors.green[100]
                                                      : Colors.red[100],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: diferenciaTotal < 0
                                                        ? Colors.green[300]!
                                                        : Colors.red[300]!,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      diferenciaTotal < 0
                                                          ? Icons.arrow_downward
                                                          : Icons.arrow_upward,
                                                      size: 14,
                                                      color: diferenciaTotal < 0
                                                          ? Colors.green[800]
                                                          : Colors.red[800],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Total: ${diferenciaTotal > 0 ? '+' : ''}${diferenciaTotal.toStringAsFixed(1)} kg',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: diferenciaTotal <
                                                                0
                                                            ? Colors.green[800]
                                                            : Colors.red[800],
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ],
                              // Tercera fila: Medidas corporales
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (medicion.cadera != null)
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
                                          Icon(
                                            Icons.straighten,
                                            size: 14,
                                            color: Colors.green[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Cadera: ${medicion.cadera!.toStringAsFixed(1)} cm',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (medicion.cintura != null)
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
                                          Icon(
                                            Icons.straighten,
                                            size: 14,
                                            color: Colors.green[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Cintura: ${medicion.cintura!.toStringAsFixed(1)} cm',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (medicion.muslo != null)
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
                                          Icon(
                                            Icons.straighten,
                                            size: 14,
                                            color: Colors.green[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Muslo: ${medicion.muslo!.toStringAsFixed(1)} cm',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (medicion.brazo != null)
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
                                          Icon(
                                            Icons.straighten,
                                            size: 14,
                                            color: Colors.green[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Brazo: ${medicion.brazo!.toStringAsFixed(1)} cm',
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
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    color: Colors.blue,
                                    iconSize: 28,
                                    onPressed: () =>
                                        _navigateToEditScreen(medicion),
                                    tooltip: 'Editar',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    iconSize: 28,
                                    onPressed: () =>
                                        _showDeleteConfirmation(medicion),
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
        tooltip: 'Añadir Medición',
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
            title: const Text('Nueva Medición'),
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
                            builder: (context) => MedicionEditScreen(
                              paciente: selected!,
                            ),
                          ),
                        )
                        .then((_) => _refreshMediciones());
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

  void _showDeleteConfirmation(Medicion medicion) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
              '¿Seguro que quieres eliminar la medición del ${DateFormat('dd/MM/yyyy').format(medicion.fecha)}?'),
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
                _deleteMedicion(medicion.codigo);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _generatePDFForPatient() async {
    try {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return const AlertDialog(
            title: Text('Generando PDF'),
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(
                  child: Text('Por favor, espere...'),
                ),
              ],
            ),
          );
        },
      );

      // Obtener datos del paciente actual
      final paciente = widget.paciente;
      if (paciente == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: No se pudo cargar el paciente'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Obtener todas las mediciones del paciente actual
      final allMediciones = await _apiService.getMediciones(paciente.codigo);

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
      Navigator.pop(context);

      await MedicionesPdfService.generateMedicionesPdf(
        context: context,
        nutricionistaNombre: nutricionistaNombre,
        nutricionistaSubtitulo: nutricionistaSubtitulo,
        logoBytes: logoBytes,
        logoSizeStr: logoSizeStr,
        accentColorStr: accentColorStr,
        mediciones: allMediciones,
        pacientesMap: {paciente.codigo: paciente},
        filtroActivo: 'S',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _generatePDF(Medicion medicion) async {
    try {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return const AlertDialog(
            title: Text('Generando PDF'),
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(
                  child: Text('Por favor, espere...'),
                ),
              ],
            ),
          );
        },
      );

      // Obtener datos del paciente actual
      final paciente = widget.paciente;
      if (paciente == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: No se pudo cargar el paciente'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Obtener todas las mediciones del paciente actual
      final allMediciones =
          await _apiService.getMediciones(medicion.codigoPaciente);

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
      Navigator.pop(context);

      await MedicionesPdfService.generateMedicionesPdf(
        context: context,
        nutricionistaNombre: nutricionistaNombre,
        nutricionistaSubtitulo: nutricionistaSubtitulo,
        logoBytes: logoBytes,
        logoSizeStr: logoSizeStr,
        accentColorStr: accentColorStr,
        mediciones: allMediciones,
        pacientesMap: {paciente.codigo: paciente},
        filtroActivo: 'S',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Uint8List? _decodeBase64Image(String base64String) {
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
