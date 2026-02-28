import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/pacientes_pdf_service.dart';
// import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:nutri_app/screens/citas/citas_list_screen.dart';
import 'package:nutri_app/screens/revisiones/revisiones_list_screen.dart';
import 'package:nutri_app/screens/mediciones/mediciones_list_screen.dart';
import 'package:nutri_app/screens/planes_nutricionales/planes_list_screen.dart';
import 'package:nutri_app/screens/planes_fit/planes_fit_list_screen.dart';
import 'package:nutri_app/screens/entrevistas/entrevistas_list_screen.dart';
import 'package:nutri_app/screens/entrevistas_fit/entrevistas_fit_list_screen.dart';
import 'package:nutri_app/screens/cobros/cobros_list_screen.dart';
import 'package:nutri_app/screens/pacientes/paciente_edit_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PacientesListScreen extends StatefulWidget {
  const PacientesListScreen({super.key});

  @override
  State<PacientesListScreen> createState() => _PacientesListScreenState();
}

class _PacientesListScreenState extends State<PacientesListScreen> {
  late Future<List<Paciente>> _pacientesFuture;
  String _filtroActivo = "S";
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _showSearchField = false;
  bool _showFilterPacientes = false;
  final Map<int, Map<String, int>> _contadores = {};
  final Set<int> _expandedPacientes = {};
  bool _expandAllMode = false;

  @override
  void initState() {
    super.initState();
    _initStateAsync();
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

  Future<void> _initStateAsync() async {
    await _loadUiState();
    _refreshPacientes();
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final filtro = prefs.getString('pacientes_filtro_activo') ?? 'S';
    final showSearch = prefs.getBool('pacientes_show_search_field') ?? false;
    final showFilter = prefs.getBool('pacientes_show_filter') ?? false;
    final expandedList = prefs.getStringList('pacientes_expanded') ?? [];
    if (!mounted) return;
    setState(() {
      _filtroActivo = filtro;
      _showSearchField = showSearch;
      _showFilterPacientes = showFilter;
      _expandedPacientes.clear();
      _expandedPacientes.addAll(expandedList.map((s) => int.parse(s)));
    });
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pacientes_filtro_activo', _filtroActivo);
    await prefs.setBool('pacientes_show_search_field', _showSearchField);
    await prefs.setBool('pacientes_show_filter', _showFilterPacientes);
  }

  Future<void> _saveExpandedState() async {
    final prefs = await SharedPreferences.getInstance();
    final expandedList =
        _expandedPacientes.map((code) => code.toString()).toList();
    await prefs.setStringList('pacientes_expanded', expandedList);
  }

  void _toggleExpanded(int codigoPaciente) {
    setState(() {
      if (_expandedPacientes.contains(codigoPaciente)) {
        _expandedPacientes.remove(codigoPaciente);
      } else {
        _expandedPacientes.add(codigoPaciente);
      }
    });
    _saveExpandedState();
  }

  void _expandAllTapped() {
    setState(() {
      _expandAllMode = !_expandAllMode;
      if (!_expandAllMode) {
        _expandedPacientes.clear();
        _saveExpandedState();
      }
    });

    if (_expandAllMode) {
      // When turning expand-all on, wait for pacientes future then update state
      _pacientesFuture.then((pacientes) {
        if (!mounted) return;
        setState(() {
          _expandedPacientes.clear();
          _expandedPacientes.addAll(pacientes.map((p) => p.codigo).cast<int>());
        });
        _saveExpandedState();
      });
    }
  }

  Future<void> _refreshPacientes() async {
    setState(() {
      _pacientesFuture = ApiService().getPacientes(
          activo: _filtroActivo == "Todos" ? null : _filtroActivo);
    });
  }

  List<Paciente> _filterPacientes(List<Paciente> pacientes) {
    if (_searchText.isEmpty) {
      return pacientes;
    }

    return pacientes.where((paciente) {
      final nombre = (paciente.nombre).toLowerCase();
      final observacion = (paciente.observacion ?? '').toLowerCase();
      final provincia = (paciente.provincia ?? '').toLowerCase();
      final telefono = (paciente.telefono ?? '').toLowerCase();
      final dni = (paciente.dni ?? '').toLowerCase();

      return nombre.contains(_searchText) ||
          observacion.contains(_searchText) ||
          provincia.contains(_searchText) ||
          telefono.contains(_searchText) ||
          dni.contains(_searchText);
    }).toList();
  }

  Future<void> _loadContadores(int codigoPaciente) async {
    if (_contadores.containsKey(codigoPaciente)) {
      return; // Ya están cargados
    }

    try {
      final apiService = ApiService();
      final citas = await apiService.getCitas(
          codigoPaciente: codigoPaciente, estado: null);
      final revisiones = await apiService.getRevisiones(
          codigoPaciente: codigoPaciente, completada: null);
      final mediciones = await apiService.getMediciones(codigoPaciente);
      final entrevistas = await apiService.getEntrevistas(codigoPaciente);
      final planes = await apiService.getPlanes(codigoPaciente);
      final entrevistasFit = await apiService.getEntrevistasFit(codigoPaciente);
      // NOTE: getPlansFit has a Dart analyzer caching issue, will load count on demand
      final cobros = await apiService.getCobros(codigoPaciente: codigoPaciente);

      setState(() {
        _contadores[codigoPaciente] = {
          'citas': citas.length,
          'revisiones': revisiones.length,
          'mediciones': mediciones.length,
          'entrevistas': entrevistas.length,
          'planes': planes.length,
          'entrevistas_fit': entrevistasFit.length,
          'planes_fit': 0, // Will be loaded when button is clicked
          'cobros': cobros.length,
        };
      });
    } catch (e) {
      // Si hay error, no hacer nada
    }
  }

  Future<void> _generarPdfPacientes() async {
    try {
      final apiService = ApiService();

      // Obtener los pacientes según filtro
      final pacientes = await apiService.getPacientes(
          activo: _filtroActivo == 'Todos' ? null : _filtroActivo);

      if (pacientes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay pacientes para exportar'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Obtener todos los cobros
      final cobros = await apiService.getCobros();

      // Obtener parámetros del nutricionista
      final nutricionistaParam =
          await apiService.getParametro('nutricionista_nombre');
      final nutricionistaNombre =
          nutricionistaParam?['valor']?.toString() ?? 'Nutricionista';
      final nutricionistaSubtitulo =
          nutricionistaParam?['valor2']?.toString() ?? '';

      final logoParam =
          await apiService.getParametro('logotipo_dietista_documentos');
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
      final accentColorParam =
          await apiService.getParametro('color_fondo_banda_encabezado_pie_pdf');
      final accentColorStr = accentColorParam?['valor']?.toString() ?? '';

      if (!mounted) return;

      await PacientesPdfService.generatePacientesPdf(
        context: context,
        nutricionistaNombre: nutricionistaNombre,
        nutricionistaSubtitulo: nutricionistaSubtitulo,
        logoBytes: logoBytes,
        logoSizeStr: logoSizeStr,
        accentColorStr: accentColorStr,
        pacientes: pacientes,
        cobros: cobros,
        filtroActivo: _filtroActivo,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  Widget _buildCountBadge(int? count) {
    final hasCount = count != null && count > 0;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: hasCount ? Colors.green : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      constraints: const BoxConstraints(
        minWidth: 20,
        minHeight: 20,
      ),
      child: Center(
        child: Text(
          count?.toString() ?? '0',
          style: TextStyle(
            color: hasCount ? Colors.white : Colors.grey[600],
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTag({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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

  void _navigateToEditScreen([Paciente? paciente]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PacienteEditScreen(paciente: paciente),
      ),
    );
    _refreshPacientes();
  }

  // Navegar a una pantalla y recargar contadores del paciente al volver
  Future<void> _navigateAndRefreshCounters(
      Widget screen, int codigoPaciente) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
    // Recargar solo los contadores del paciente cuando se vuelve
    _loadContadores(codigoPaciente);
  }

  void _showDeleteConfirmation(Paciente paciente) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
              '¿Estás seguro de que quieres eliminar el paciente ${paciente.nombre}?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deletePaciente(paciente.codigo);
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  void _deletePaciente(int codigo) async {
    try {
      await ApiService().deletePaciente(codigo);
      _refreshPacientes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Paciente eliminado'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar paciente: $e')),
        );
      }
    }
  }

  // Función de llamadas telefónicas deshabilitada - feature temporarily disabled
  // void _makePhoneCall(Paciente paciente) {
  //   if (paciente.telefono == null || paciente.telefono!.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('Este paciente no tiene teléfono registrado'),
  //         backgroundColor: Colors.orange,
  //       ),
  //     );
  //     return;
  //   }
  //
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Realizar llamada'),
  //         content: Text(
  //             '¿Deseas llamar a ${paciente.nombre} al número ${paciente.telefono}?'),
  //         actions: <Widget>[
  //           TextButton(
  //             onPressed: () => Navigator.of(context).pop(),
  //             child: const Text('Cancelar'),
  //           ),
  //           TextButton(
  //             onPressed: () async {
  //               Navigator.of(context).pop();
  //               final Uri telUri = Uri(scheme: 'tel', path: paciente.telefono);
  //               // await PermissionsService.launchUrl(telUri, context: context);
  //             },
  //             child: const Text('Llamar'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  // Función de envío de email deshabilitada - feature temporarily disabled
  // void _sendEmail(Paciente paciente) {
  //   if (paciente.email1 == null || paciente.email1!.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('Este paciente no tiene email registrado'),
  //         backgroundColor: Colors.orange,
  //       ),
  //     );
  //     return;
  //   }
  //
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Enviar email'),
  //         content: Text(
  //             '¿Deseas enviar un email a ${paciente.nombre} (${paciente.email1})?'),
  //         actions: <Widget>[
  //           TextButton(
  //             onPressed: () => Navigator.of(context).pop(),
  //             child: const Text('Cancelar'),
  //           ),
  //           TextButton(
  //             onPressed: () async {
  //               Navigator.of(context).pop();
  //               final Uri emailUri = Uri(
  //                 scheme: 'mailto',
  //                 path: paciente.email1!,
  //                 queryParameters: {
  //                   'subject': 'Asunto del email',
  //                   'body': 'Mensaje para ${paciente.nombre}',
  //                 },
  //               );
  //               // await PermissionsService.launchUrl(
  //               //   emailUri,
  //               //   mode: url_launcher.LaunchMode.externalApplication,
  //               //   context: context,
  //               // );
  //             },
  //             child: const Text('Enviar'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Volver',
        ),
        title: const Text('Pacientes'),
        actions: [
          IconButton(
            icon: Icon(_expandAllMode ? Icons.unfold_less : Icons.unfold_more),
            tooltip: _expandAllMode ? 'Contraer todo' : 'Expandir todo',
            onPressed: _expandAllTapped,
          ),
          IconButton(
            icon: Icon(_showFilterPacientes
                ? Icons.filter_alt
                : Icons.filter_alt_outlined),
            tooltip: _showFilterPacientes ? 'Ocultar filtro' : 'Mostrar filtro',
            onPressed: () {
              setState(() {
                _showFilterPacientes = !_showFilterPacientes;
              });
              _saveUiState();
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Generar PDF',
            onPressed: () => _generarPdfPacientes(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPacientes,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showFilterPacientes)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: "S", label: Text('Activos')),
                            ButtonSegment(value: "Todos", label: Text('Todos')),
                          ],
                          selected: {_filtroActivo},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              _filtroActivo = newSelection.first;
                            });
                            _saveUiState();
                            _refreshPacientes();
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
              ),
            if (_showSearchField)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, DNI, teléfono, provincia...',
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
              child: FutureBuilder<List<Paciente>>(
                future: _pacientesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text('No hay pacientes registrados.'));
                  } else {
                    final allPacientes = snapshot.data!;
                    final pacientes = _filterPacientes(allPacientes);

                    if (pacientes.isEmpty && _searchText.isNotEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No se encontraron pacientes',
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

                    return ListView.builder(
                      itemCount: pacientes.length,
                      itemBuilder: (context, index) {
                        final paciente = pacientes[index];
                        // Cargar contadores para este paciente
                        _loadContadores(paciente.codigo);
                        final contadores = _contadores[paciente.codigo];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          elevation: 2,
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Contenido principal del paciente
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Información del paciente
                                      ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 2),
                                        title: InkWell(
                                          onTap: () =>
                                              _navigateToEditScreen(paciente),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  paciente.nombre,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.edit,
                                                size: 20,
                                                color: Colors.blue,
                                              ),
                                            ],
                                          ),
                                        ),
                                        subtitle: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2.0),
                                          child: Builder(
                                            builder: (context) {
                                              final hasSexo =
                                                  (paciente.sexo ?? '')
                                                      .trim()
                                                      .isNotEmpty;
                                              final hasEdad =
                                                  paciente.edad != null;
                                              final hasAltura =
                                                  paciente.altura != null &&
                                                      paciente.altura! > 0;
                                              final hasPeso =
                                                  paciente.peso != null &&
                                                      paciente.peso! > 0;

                                              final hasBmi = hasSexo &&
                                                  hasEdad &&
                                                  hasAltura &&
                                                  hasPeso;

                                              double? bmi;
                                              if (hasBmi) {
                                                final alturaM =
                                                    paciente.altura! / 100.0;
                                                if (alturaM > 0) {
                                                  bmi = paciente.peso! /
                                                      (alturaM * alturaM);
                                                }
                                              }

                                              String? sexoLabel;
                                              IconData? sexoIcon;
                                              if (hasSexo) {
                                                final sexoRaw = paciente.sexo!
                                                    .toLowerCase();
                                                if (sexoRaw.startsWith('h')) {
                                                  sexoLabel = 'H';
                                                  sexoIcon = Icons.male;
                                                } else if (sexoRaw
                                                    .startsWith('m')) {
                                                  sexoLabel = 'M';
                                                  sexoIcon = Icons.female;
                                                } else {
                                                  sexoLabel = paciente.sexo;
                                                  sexoIcon = Icons.person;
                                                }
                                              }

                                              return Wrap(
                                                spacing: 8,
                                                runSpacing: 6,
                                                children: [
                                                  if (hasSexo &&
                                                      sexoLabel != null &&
                                                      sexoIcon != null)
                                                    _buildInfoTag(
                                                      icon: sexoIcon,
                                                      text: sexoLabel,
                                                      color: Colors.purple,
                                                    ),
                                                  if (hasEdad)
                                                    _buildInfoTag(
                                                      icon: Icons.cake,
                                                      text: '${paciente.edad}',
                                                      color: Colors
                                                          .purple.shade700,
                                                    ),
                                                  if (hasAltura)
                                                    _buildInfoTag(
                                                      icon: Icons.height,
                                                      text:
                                                          '${paciente.altura}',
                                                      color: Colors
                                                          .purple.shade500,
                                                    ),
                                                  if (hasPeso)
                                                    _buildInfoTag(
                                                      icon: Icons.scale,
                                                      text: paciente.peso!
                                                          .toStringAsFixed(1),
                                                      color: Colors
                                                          .purple.shade600,
                                                    ),
                                                  if (bmi != null)
                                                    InkWell(
                                                      onTap: () =>
                                                          _showBmiInfoDialog(
                                                              bmi!),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      child: _buildInfoTag(
                                                        icon: Icons.analytics,
                                                        text:
                                                            'IMC ${bmi.toStringAsFixed(1)}',
                                                        color:
                                                            _getBmiColor(bmi),
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                        onTap: null,
                                      ),
                                      // Sección de botones organizados
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            12.0, 0, 12.0, 4.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Primera fila: comunicación y edición
                                            Wrap(
                                              spacing: 4.0,
                                              runSpacing: 2.0,
                                              children: [
                                                if (paciente.telefono != null &&
                                                    paciente
                                                        .telefono!.isNotEmpty)
                                                  IconButton(
                                                    icon:
                                                        const Icon(Icons.phone),
                                                    color: Colors.green,
                                                    iconSize: 28,
                                                    tooltip: 'Llamar',
                                                    onPressed:
                                                        () {}, // Phone call disabled
                                                  ),
                                                if (paciente.email1 != null &&
                                                    paciente.email1!.isNotEmpty)
                                                  IconButton(
                                                    icon:
                                                        const Icon(Icons.email),
                                                    color: Colors.blue,
                                                    iconSize: 28,
                                                    tooltip: 'Email',
                                                    onPressed:
                                                        () {}, // Email disabled
                                                  ),
                                                const SizedBox(width: 4),
                                                IconButton(
                                                  icon: const Icon(Icons.edit),
                                                  color: Colors.blue,
                                                  iconSize: 28,
                                                  tooltip: 'Editar',
                                                  onPressed: () =>
                                                      _navigateToEditScreen(
                                                          paciente),
                                                ),
                                                const SizedBox(width: 4),
                                                IconButton(
                                                  icon:
                                                      const Icon(Icons.delete),
                                                  color: Colors.red,
                                                  iconSize: 28,
                                                  tooltip: 'Eliminar',
                                                  onPressed: () =>
                                                      _onDeletePacienteTapped(
                                                          paciente),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            // Expandable row: consultas
                                            Theme(
                                              data: Theme.of(context).copyWith(
                                                dividerColor:
                                                    Colors.transparent,
                                                splashColor: Colors.grey[100],
                                              ),
                                              child: Builder(
                                                builder: (context) {
                                                  final isExpanded =
                                                      _expandedPacientes
                                                          .contains(
                                                              paciente.codigo);
                                                  return ExpansionTile(
                                                    key: ValueKey(
                                                        'paciente-${paciente.codigo}-$isExpanded'),
                                                    tilePadding:
                                                        const EdgeInsets.all(0),
                                                    childrenPadding:
                                                        const EdgeInsets
                                                            .fromLTRB(
                                                            0, 8, 0, 0),
                                                    initiallyExpanded:
                                                        isExpanded,
                                                    onExpansionChanged: (_) =>
                                                        _toggleExpanded(
                                                            paciente.codigo),
                                                    title: const Text(
                                                      'Consultas',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                    children: [
                                                      Wrap(
                                                        spacing: 4.0,
                                                        runSpacing: 2.0,
                                                        children: [
                                                          ActionChip(
                                                            avatar: const Icon(
                                                                Icons
                                                                    .calendar_today,
                                                                size: 12,
                                                                color: Colors
                                                                    .purple),
                                                            label: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Text('CI',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            11)),
                                                                const SizedBox(
                                                                    width: 2),
                                                                _buildCountBadge(
                                                                    contadores?[
                                                                        'citas']),
                                                              ],
                                                            ),
                                                            onPressed: () =>
                                                                _navigateAndRefreshCounters(
                                                              CitasListScreen(
                                                                  paciente:
                                                                      paciente),
                                                              paciente.codigo,
                                                            ),
                                                            backgroundColor:
                                                                Colors
                                                                    .purple[50],
                                                            side: BorderSide(
                                                                color: Colors
                                                                        .purple[
                                                                    200]!),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        4,
                                                                    vertical:
                                                                        1),
                                                          ),
                                                          ActionChip(
                                                            avatar: const Icon(
                                                                Icons
                                                                    .rate_review,
                                                                size: 12,
                                                                color: Colors
                                                                    .indigo),
                                                            label: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Text('RE',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            11)),
                                                                const SizedBox(
                                                                    width: 2),
                                                                _buildCountBadge(
                                                                    contadores?[
                                                                        'revisiones']),
                                                              ],
                                                            ),
                                                            onPressed: () =>
                                                                _navigateAndRefreshCounters(
                                                              RevisionesListScreen(
                                                                  paciente:
                                                                      paciente),
                                                              paciente.codigo,
                                                            ),
                                                            backgroundColor:
                                                                Colors
                                                                    .indigo[50],
                                                            side: BorderSide(
                                                                color: Colors
                                                                        .indigo[
                                                                    200]!),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        4,
                                                                    vertical:
                                                                        1),
                                                          ),
                                                          ActionChip(
                                                            avatar: const Icon(
                                                                Icons
                                                                    .fitbit_rounded,
                                                                size: 12,
                                                                color: Colors
                                                                    .green),
                                                            label: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Text('ME',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            11)),
                                                                const SizedBox(
                                                                    width: 2),
                                                                _buildCountBadge(
                                                                    contadores?[
                                                                        'mediciones']),
                                                              ],
                                                            ),
                                                            onPressed: () =>
                                                                _navigateAndRefreshCounters(
                                                              MedicionesListScreen(
                                                                  paciente:
                                                                      paciente),
                                                              paciente.codigo,
                                                            ),
                                                            backgroundColor:
                                                                Colors
                                                                    .green[50],
                                                            side: BorderSide(
                                                                color: Colors
                                                                        .green[
                                                                    200]!),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        4,
                                                                    vertical:
                                                                        1),
                                                          ),
                                                          ActionChip(
                                                            avatar: const Icon(
                                                                Icons
                                                                    .assignment,
                                                                size: 12,
                                                                color: Colors
                                                                    .orange),
                                                            label: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Text('EN',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            11)),
                                                                const SizedBox(
                                                                    width: 2),
                                                                _buildCountBadge(
                                                                    contadores?[
                                                                        'entrevistas']),
                                                              ],
                                                            ),
                                                            onPressed: () =>
                                                                _navigateAndRefreshCounters(
                                                              EntrevistasListScreen(
                                                                  paciente:
                                                                      paciente),
                                                              paciente.codigo,
                                                            ),
                                                            backgroundColor:
                                                                Colors
                                                                    .orange[50],
                                                            side: BorderSide(
                                                                color: Colors
                                                                        .orange[
                                                                    200]!),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        4,
                                                                    vertical:
                                                                        1),
                                                          ),
                                                          ActionChip(
                                                            avatar: const Icon(
                                                                Icons
                                                                    .sports_gymnastics,
                                                                size: 12,
                                                                color:
                                                                    Colors.red),
                                                            label: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Text('EF',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            11)),
                                                                const SizedBox(
                                                                    width: 2),
                                                                _buildCountBadge(
                                                                    contadores?[
                                                                        'entrevistas_fit']),
                                                              ],
                                                            ),
                                                            onPressed: () =>
                                                                _navigateAndRefreshCounters(
                                                              EntrevistasFitListScreen(
                                                                  paciente:
                                                                      paciente),
                                                              paciente.codigo,
                                                            ),
                                                            backgroundColor:
                                                                Colors.red[50],
                                                            side: BorderSide(
                                                                color: Colors
                                                                    .red[200]!),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        4,
                                                                    vertical:
                                                                        1),
                                                          ),
                                                          ActionChip(
                                                            avatar: const Icon(
                                                                Icons
                                                                    .description,
                                                                size: 12,
                                                                color: Colors
                                                                    .teal),
                                                            label: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Text('PN',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            11)),
                                                                const SizedBox(
                                                                    width: 2),
                                                                _buildCountBadge(
                                                                    contadores?[
                                                                        'planes']),
                                                              ],
                                                            ),
                                                            onPressed: () =>
                                                                _navigateAndRefreshCounters(
                                                              PlanesListScreen(
                                                                  paciente:
                                                                      paciente),
                                                              paciente.codigo,
                                                            ),
                                                            backgroundColor:
                                                                Colors.teal[50],
                                                            side: BorderSide(
                                                                color:
                                                                    Colors.teal[
                                                                        200]!),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        4,
                                                                    vertical:
                                                                        1),
                                                          ),
                                                          ActionChip(
                                                            avatar: const Icon(
                                                                Icons
                                                                    .fitness_center_outlined,
                                                                size: 12,
                                                                color: Colors
                                                                    .purple),
                                                            label: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Text('PF',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            11)),
                                                                const SizedBox(
                                                                    width: 2),
                                                                _buildCountBadge(
                                                                    contadores?[
                                                                        'planes_fit']),
                                                              ],
                                                            ),
                                                            onPressed: () =>
                                                                _navigateAndRefreshCounters(
                                                              PlanesFitListScreen(
                                                                  paciente:
                                                                      paciente),
                                                              paciente.codigo,
                                                            ),
                                                            backgroundColor:
                                                                Colors
                                                                    .purple[50],
                                                            side: BorderSide(
                                                                color: Colors
                                                                        .purple[
                                                                    200]!),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        4,
                                                                    vertical:
                                                                        1),
                                                          ),
                                                          ActionChip(
                                                            avatar: const Icon(
                                                                Icons
                                                                    .monetization_on,
                                                                size: 12,
                                                                color: Colors
                                                                    .amber),
                                                            label: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Text('CO',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            11)),
                                                                const SizedBox(
                                                                    width: 2),
                                                                _buildCountBadge(
                                                                    contadores?[
                                                                        'cobros']),
                                                              ],
                                                            ),
                                                            onPressed: () =>
                                                                _navigateAndRefreshCounters(
                                                              CobrosListScreen(
                                                                  paciente:
                                                                      paciente),
                                                              paciente.codigo,
                                                            ),
                                                            backgroundColor:
                                                                Colors
                                                                    .amber[50],
                                                            side: BorderSide(
                                                                color: Colors
                                                                        .amber[
                                                                    300]!),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        4,
                                                                    vertical:
                                                                        1),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  );
                                                },
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
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditScreen(),
        tooltip: 'Añadir Paciente',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _onDeletePacienteTapped(Paciente paciente) async {
    try {
      // Primero verificar dependencias en las nuevas tablas
      final dependencies =
          await ApiService().checkPacienteDependencies(paciente.codigo);

      if (dependencies.isNotEmpty) {
        // Tiene dependencias, mostrar diálogo con opciones
        if (!mounted) return;
        _showDependenciesDialog(paciente.codigo, dependencies);
        return;
      }

      // Luego verificar las tablas antiguas (citas, revisiones, etc.) para compatibilidad
      final hasRelated = await _hasRelatedData(paciente.codigo);
      if (hasRelated) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No se puede eliminar'),
            content: const Text(
                'Este paciente tiene citas, revisiones, entrevistas, mediciones o cobros asociados. Por seguridad, no se permite eliminarlo.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Aceptar'),
              )
            ],
          ),
        );
        return;
      }

      // Si no tiene dependencias, mostrar confirmación simple
      _showDeleteConfirmation(paciente);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDependenciesDialog(int codigo, Map<String, dynamic> dependencies) {
    showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('El paciente tiene registros asociados'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Este paciente tiene los siguientes registros en otras tablas:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...dependencies.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      '• ${entry.key}: ${entry.value} registros',
                      style: const TextStyle(fontSize: 14),
                    ),
                  )),
              const SizedBox(height: 16),
              const Text(
                'Si desea continuar, se eliminarán también todos estos registros.',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context, 'cancel'),
          ),
          TextButton(
            child: const Text('Eliminar completo'),
            onPressed: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    ).then((action) async {
      if (action == 'delete') {
        await _deletePacienteCascade(codigo);
      }
    });
  }

  Future<void> _deletePacienteCascade(int codigo) async {
    try {
      final success = await ApiService().deletePacienteCascade(codigo);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Paciente y todos sus registros eliminados'),
                backgroundColor: Colors.green),
          );
          _refreshPacientes();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<bool> _hasRelatedData(int codigoPaciente) async {
    final api = ApiService();
    try {
      final citas = await api.getCitas(codigoPaciente: codigoPaciente);
      if (citas.isNotEmpty) return true;

      final revisiones =
          await api.getRevisiones(codigoPaciente: codigoPaciente);
      if (revisiones.isNotEmpty) return true;

      final entrevistas = await api.getEntrevistas(codigoPaciente);
      if (entrevistas.isNotEmpty) return true;

      final mediciones = await api.getMediciones(codigoPaciente);
      if (mediciones.isNotEmpty) return true;

      final cobros = await api.getCobros(codigoPaciente: codigoPaciente);
      if (cobros.isNotEmpty) return true;

      final planes = await api.getPlanes(codigoPaciente);
      if (planes.isNotEmpty) return true;

      final entrevistasFit = await api.getEntrevistasFit(codigoPaciente);
      if (entrevistasFit.isNotEmpty) return true;

      // TODO: Uncomment when getPlansFit is properly recognized
      // final planesFit = await api.getPlansFit(codigoPaciente);
      // if (planesFit.isNotEmpty) return true;

      return false;
    } catch (_) {
      return true;
    }
  }
}
