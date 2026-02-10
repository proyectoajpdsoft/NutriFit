import 'package:flutter/material.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/screens/entrevistas/entrevistas_list_screen.dart';
import 'package:nutri_app/screens/entrevistas/entrevista_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';

class EntrevistasPacientesListScreen extends StatefulWidget {
  const EntrevistasPacientesListScreen({super.key});

  @override
  State<EntrevistasPacientesListScreen> createState() =>
      _EntrevistasPacientesListScreenState();
}

class _EntrevistasPacientesListScreenState
    extends State<EntrevistasPacientesListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Paciente>> _pacientesFuture;
  late Future<Map<int, int>> _totalesEntrevistasMap;
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
      _totalesEntrevistasMap = _fetchTotalesEntrevistas();
    });
  }

  Future<Map<int, int>> _fetchTotalesEntrevistas() async {
    try {
      final totales = await _apiService.getPacientesTotalesBatch();
      final map = <int, int>{};
      for (var item in totales) {
        map[item['codigo']] = item['total_entrevistas'] ?? 0;
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
            title: const Text('Nueva Entrevista'),
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
                      builder: (context) => EntrevistaEditScreen(
                        paciente: selected!,
                      ),
                    ))
                        .then((value) {
                      // Si se creó/guardó, refrescar listas
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
        title: const Text('Entrevistas Nutri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPacientes,
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EntrevistasListScreen(
                    paciente: null,
                    filtroActivo: _filtroActivo,
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
        tooltip: 'Añadir Entrevista',
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
                  ButtonSegment(value: "S", label: Text('Activos')),
                  ButtonSegment(value: "Todos", label: Text('Todos')),
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
              'Seleccione un paciente para ver sus Entrevistas Nutri',
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
                  future: _totalesEntrevistasMap,
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
                                      EntrevistasListScreen(paciente: paciente),
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
