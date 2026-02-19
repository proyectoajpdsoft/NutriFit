import 'package:flutter/material.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/screens/entrevistas_fit/entrevista_fit_edit_screen.dart';
import 'package:nutri_app/screens/entrevistas_fit/entrevistas_fit_list_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _showSearchField = false;
  bool _showFilterEntrevistas = false;
  bool _showInfoMessage = true;

  @override
  void initState() {
    super.initState();
    _loadUiState();
    _refreshPacientes();
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
    final filtro = prefs.getString('entrevistas_fit_pacientes_filtro_activo') ??
        _filtroActivo;
    final showSearch =
        prefs.getBool('entrevistas_fit_pacientes_show_search_field') ?? false;
    final showFilter =
        prefs.getBool('entrevistas_fit_pacientes_show_filter') ?? false;
    final hasShownInfo =
        prefs.getBool('entrevistas_fit_pacientes_shown_info') ?? false;
    if (!mounted) return;
    setState(() {
      _filtroActivo = filtro;
      _showSearchField = showSearch;
      _showFilterEntrevistas = showFilter;
      _showInfoMessage = !hasShownInfo;
    });
    if (!hasShownInfo) {
      await prefs.setBool('entrevistas_fit_pacientes_shown_info', true);
    }
    _refreshPacientes();
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'entrevistas_fit_pacientes_filtro_activo', _filtroActivo);
    await prefs.setBool(
        'entrevistas_fit_pacientes_show_search_field', _showSearchField);
    await prefs.setBool(
        'entrevistas_fit_pacientes_show_filter', _showFilterEntrevistas);
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
          IconButton(
            icon: Icon(_showFilterEntrevistas
                ? Icons.filter_alt
                : Icons.filter_alt_outlined),
            tooltip:
                _showFilterEntrevistas ? 'Ocultar filtro' : 'Mostrar filtro',
            onPressed: () {
              setState(() {
                _showFilterEntrevistas = !_showFilterEntrevistas;
              });
              _saveUiState();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPacientes,
            tooltip: 'Actualizar',
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
          if (_showFilterEntrevistas)
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
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
                          _saveUiState();
                        },
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon:
                      Icon(_showSearchField ? Icons.search_off : Icons.search),
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
                  hintText: 'Buscar paciente...',
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
                    'Seleccione un paciente para ver sus Entrevistas Fit',
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

                var pacientes = snapshot.data!;
                if (_searchText.isNotEmpty) {
                  pacientes = pacientes
                      .where(
                          (p) => p.nombre.toLowerCase().contains(_searchText))
                      .toList();
                }
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
