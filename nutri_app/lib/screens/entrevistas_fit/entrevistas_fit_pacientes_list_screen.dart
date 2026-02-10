import 'package:flutter/material.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/screens/entrevistas_fit/entrevista_fit_edit_screen.dart';
import 'package:nutri_app/screens/entrevistas_fit/entrevistas_fit_list_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';

class EntrevistasFitPacientesListScreen extends StatefulWidget {
  const EntrevistasFitPacientesListScreen({super.key});

  @override
  State<EntrevistasFitPacientesListScreen> createState() =>
      _EntrevistasFitPacientesListScreenState();
}

class _EntrevistasFitPacientesListScreenState
    extends State<EntrevistasFitPacientesListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Paciente>> _pacientesFuture;
  late Future<Map<int, int>> _totalesEntrevistasFitMap;
  String _filtroActivo = "S"; // Por defecto, solo activos

  @override
  void initState() {
    super.initState();
    _refreshPacientes();
  }

  void _refreshPacientes() {
    setState(() {
      _pacientesFuture = _apiService.getPacientes(
        activo: _filtroActivo == "Todos" ? null : _filtroActivo,
      );
      _totalesEntrevistasFitMap = _fetchTotalesEntrevistasFit();
    });
  }

  Future<Map<int, int>> _fetchTotalesEntrevistasFit() async {
    try {
      final totales = await _apiService.getPacientesTotalesBatch();
      final map = <int, int>{};
      for (var item in totales) {
        map[item['codigo']] = item['total_entrevistas_fit'] ?? 0;
      }
      return map;
    } catch (e) {
      return {};
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
            title: const Text('Nueva Entrevista Fit'),
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
                      builder: (context) => EntrevistaFitEditScreen(
                        paciente: selected!,
                      ),
                    ))
                        .then((value) {
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
        title: const Text('Entrevistas Fit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPacientes,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const EntrevistasFitListScreen(
                    paciente: null,
                  ),
                ),
              );
            },
            tooltip: 'Ver todas las entrevistas',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPacienteSelectorAndAdd,
        tooltip: 'Nueva Entrevista Fit',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Center(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: "S", label: Text('Activas')),
                  ButtonSegment(value: "Todos", label: Text('Todas')),
                ],
                selected: {_filtroActivo},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _filtroActivo = newSelection.first;
                    _refreshPacientes();
                  });
                },
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Text(
              'Seleccione un paciente para ver sus Entrevistas Fit',
              style: TextStyle(fontSize: 16, color: Colors.black54),
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
                  future: _totalesEntrevistasFitMap,
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
                                      EntrevistasFitListScreen(
                                          paciente: paciente),
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
