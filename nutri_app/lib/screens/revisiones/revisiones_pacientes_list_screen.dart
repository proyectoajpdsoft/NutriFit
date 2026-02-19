import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/screens/revisiones/revisiones_list_screen.dart';
import 'package:nutri_app/screens/revisiones/revision_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/revisiones_pdf_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RevisionesPacientesListScreen extends StatefulWidget {
  const RevisionesPacientesListScreen({super.key});

  @override
  State<RevisionesPacientesListScreen> createState() =>
      _RevisionesPacientesListScreenState();
}

class _RevisionesPacientesListScreenState
    extends State<RevisionesPacientesListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Paciente>> _pacientesFuture;
  late Future<Map<int, int>> _totalesRevisionesMap;
  String _filtroActivo = "S"; // Por defecto, solo activos
  bool _showFilterRevisiones = false;
  bool _showInfoMessage = true;

  @override
  void initState() {
    super.initState();
    _loadUiStateAndRefresh();
  }

  Future<void> _loadUiStateAndRefresh() async {
    await _loadUiState();
    if (mounted) {
      _refreshPacientes();
    }
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final filtro = prefs.getString('revisiones_pacientes_filtro_activo') ?? 'S';
    final showFilter =
        prefs.getBool('revisiones_pacientes_show_filter') ?? false;
    final hasShownInfo =
        prefs.getBool('revisiones_pacientes_shown_info') ?? false;
    if (!mounted) return;
    setState(() {
      _filtroActivo = filtro;
      _showFilterRevisiones = showFilter;
      _showInfoMessage = !hasShownInfo;
    });
    if (!hasShownInfo) {
      await prefs.setBool('revisiones_pacientes_shown_info', true);
    }
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('revisiones_pacientes_filtro_activo', _filtroActivo);
    await prefs.setBool(
        'revisiones_pacientes_show_filter', _showFilterRevisiones);
  }

  void _refreshPacientes() {
    setState(() {
      _pacientesFuture = _apiService.getPacientes(
        activo: _filtroActivo == "Todos" ? null : _filtroActivo,
      );
      _totalesRevisionesMap = _fetchTotalesRevisiones();
    });
  }

  Future<Map<int, int>> _fetchTotalesRevisiones() async {
    try {
      final totales = await _apiService.getPacientesTotalesBatch();
      final map = <int, int>{};
      for (var item in totales) {
        map[item['codigo']] = item['total_revisiones'] ?? 0;
      }
      return map;
    } catch (e) {
      return {};
    }
  }

  Future<void> _generateRevisionesPdf() async {
    try {
      // Cargar todas las revisiones
      final revisiones = await _apiService.getRevisiones(
        completada: _filtroActivo == "Todos" ? null : "N",
      );

      // Obtener códigos únicos de pacientes que tienen revisiones
      final pacientesConRevisiones = <int>{};
      for (final revision in revisiones) {
        if (revision.codigoPaciente != null) {
          pacientesConRevisiones.add(revision.codigoPaciente!);
        }
      }

      // Cargar todos los pacientes y luego filtrar solo los que tienen revisiones
      final todosPacientes = await _apiService.getPacientes();
      final pacientes = todosPacientes
          .where((p) => pacientesConRevisiones.contains(p.codigo))
          .toList();
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

      await RevisionesPdfService.generateRevisionesPdf(
        context: context,
        nutricionistaNombre: nutricionistaNombre,
        nutricionistaSubtitulo: nutricionistaSubtitulo,
        logoBytes: logoBytes,
        logoSizeStr: logoSizeStr,
        accentColorStr: accentColorStr,
        revisiones: revisiones,
        pacientesMap: pacientesMap,
        filtroActivo: _filtroActivo,
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

  Future<void> _showPacienteSelectorAndAdd() async {
    try {
      final pacientes = await _apiService.getPacientes(
        activo: _filtroActivo == "Todos" ? null : _filtroActivo,
      );
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
                decoration: const InputDecoration(labelText: 'Paciente'),
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
                        .push(MaterialPageRoute(
                      builder: (context) => RevisionEditScreen(
                        paciente: selected!,
                      ),
                    ))
                        .then((value) {
                      // Si se creó/guardó, refrescar lista
                      _refreshPacientes();
                    });
                  }
                },
                child: const Text('Continuar'),
              )
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Revisiones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RevisionesListScreen(
                    paciente: null,
                  ),
                ),
              );
            },
            tooltip: 'Ver todas las revisiones',
          ),
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
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPacientes,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPacienteSelectorAndAdd,
        tooltip: 'Añadir Revisión',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (_showFilterRevisiones)
            Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
          if (_showInfoMessage)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade100,
                  border: Border.all(color: Colors.yellow.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    'Seleccione un paciente para ver sus revisiones',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber.shade900,
                      fontStyle: FontStyle.italic,
                    ),
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
                  return Center(child: Text("Error: ${snapshot.error}"));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text("No se encontraron pacientes."));
                }

                final pacientes = snapshot.data!;
                return FutureBuilder<Map<int, int>>(
                  future: _totalesRevisionesMap,
                  builder: (context, totalesSnap) {
                    final totalesMap = totalesSnap.data ?? {};
                    return ListView.builder(
                      itemCount: pacientes.length,
                      itemBuilder: (context, index) {
                        final paciente = pacientes[index];
                        final count = totalesMap[paciente.codigo] ?? 0;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          elevation: 3,
                          child: ListTile(
                            title: Text(paciente.nombre),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  radius: 14,
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_ios),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      RevisionesListScreen(paciente: paciente),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
