import 'package:flutter/material.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/screens/planes_fit/planes_fit_list_screen.dart';
import 'package:nutri_app/screens/planes_fit/plan_fit_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';

class PlanesFitPacientesListScreen extends StatefulWidget {
  const PlanesFitPacientesListScreen({super.key});

  @override
  State<PlanesFitPacientesListScreen> createState() =>
      _PlanesFitPacientesListScreenState();
}

class _PlanesFitPacientesListScreenState
    extends State<PlanesFitPacientesListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Paciente>> _pacientesFuture;
  late Future<Map<int, int>> _totalesPlanesFitMap;
  String _filtroActivo = "S";

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
      _totalesPlanesFitMap = _fetchTotalesPlanesFit();
    });
  }

  Future<Map<int, int>> _fetchTotalesPlanesFit() async {
    try {
      final totales = await _apiService.getPacientesTotalesBatch();
      final map = <int, int>{};
      for (var item in totales) {
        map[item['codigo']] = item['total_planes_fit'] ?? 0;
      }
      return map;
    } catch (e) {
      return {};
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
        title: const Text('Planes Fit'),
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
                  builder: (context) =>
                      const PlanesFitListScreen(paciente: null),
                ),
              );
            },
            tooltip: 'Ver todos los planes fit',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const PlanFitEditScreen()),
          );
        },
        tooltip: 'Añadir Plan Fit',
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
              'Seleccione un paciente para ver sus Planes Fit',
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
                  future: _totalesPlanesFitMap,
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
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_ios, size: 16),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => PlanesFitListScreen(
                                    paciente: paciente,
                                  ),
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
