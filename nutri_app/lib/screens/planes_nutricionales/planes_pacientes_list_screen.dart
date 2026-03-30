import 'package:flutter/material.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/screens/planes_nutricionales/planes_list_screen.dart';
import 'package:nutri_app/screens/planes_nutricionales/plan_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _OrdenPlanes { nombre, numPlanes, fechaPlan }

enum _PlanesTopAction {
  filtrar,
  verTodos,
  refrescar,
  sortNombre,
  sortNumPlanes,
  sortFechaPlan
}

class PlanesPacientesListScreen extends StatefulWidget {
  const PlanesPacientesListScreen({super.key});

  @override
  State<PlanesPacientesListScreen> createState() =>
      _PlanesPacientesListScreenState();
}

class _PlanesPacientesListScreenState extends State<PlanesPacientesListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Paciente>> _pacientesFuture;
  late Future<Map<int, Map<String, dynamic>>> _totalesPlanesMap;
  String _filtroActivo = "S"; // Por defecto, solo activos
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _showSearchField = false;
  bool _showFilterPlanes = false;
  bool _showInfoMessage = true;

  _OrdenPlanes _ordenPlanes = _OrdenPlanes.nombre;
  bool _ordenAscendente = true;

  static const String _prefOrdenKey = 'planes_pacientes_orden';
  static const String _prefOrdenAscKey = 'planes_pacientes_orden_asc';

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

  void _refreshPacientes() {
    setState(() {
      _pacientesFuture = _apiService.getPacientes(
        activo: _filtroActivo == "Todos" ? null : _filtroActivo,
      );
      _totalesPlanesMap = _fetchTotalesPlanes();
    });
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final filtro =
        prefs.getString('planes_pacientes_filtro_activo') ?? _filtroActivo;
    final showSearch =
        prefs.getBool('planes_pacientes_show_search_field') ?? false;
    final showFilter = prefs.getBool('planes_pacientes_show_filter') ?? false;
    final hasShownInfo = prefs.getBool('planes_pacientes_shown_info') ?? false;
    final storedOrden = prefs.getInt(_prefOrdenKey);
    final storedOrdenAsc = prefs.getBool(_prefOrdenAscKey);
    if (!mounted) return;
    setState(() {
      _filtroActivo = filtro;
      _showSearchField = showSearch;
      _showFilterPlanes = showFilter;
      _showInfoMessage = !hasShownInfo;
      _ordenPlanes = storedOrden != null &&
              storedOrden >= 0 &&
              storedOrden < _OrdenPlanes.values.length
          ? _OrdenPlanes.values[storedOrden]
          : _OrdenPlanes.nombre;
      _ordenAscendente = storedOrdenAsc ?? true;
    });
    if (!hasShownInfo) {
      await prefs.setBool('planes_pacientes_shown_info', true);
    }
    _refreshPacientes();
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('planes_pacientes_filtro_activo', _filtroActivo);
    await prefs.setBool('planes_pacientes_show_search_field', _showSearchField);
    await prefs.setBool('planes_pacientes_show_filter', _showFilterPlanes);
  }

  Future<void> _applySortSelection(_OrdenPlanes orden) async {
    setState(() {
      if (_ordenPlanes == orden) {
        _ordenAscendente = !_ordenAscendente;
      } else {
        _ordenPlanes = orden;
        _ordenAscendente = orden == _OrdenPlanes.nombre;
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefOrdenKey, _ordenPlanes.index);
    await prefs.setBool(_prefOrdenAscKey, _ordenAscendente);
  }

  Future<void> _handleTopAction(_PlanesTopAction action) async {
    switch (action) {
      case _PlanesTopAction.filtrar:
        setState(() {
          _showFilterPlanes = !_showFilterPlanes;
        });
        _saveUiState();
        break;
      case _PlanesTopAction.verTodos:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const PlanesListScreen(paciente: null),
          ),
        );
        break;
      case _PlanesTopAction.refrescar:
        _refreshPacientes();
        break;
      case _PlanesTopAction.sortNombre:
        await _applySortSelection(_OrdenPlanes.nombre);
        break;
      case _PlanesTopAction.sortNumPlanes:
        await _applySortSelection(_OrdenPlanes.numPlanes);
        break;
      case _PlanesTopAction.sortFechaPlan:
        await _applySortSelection(_OrdenPlanes.fechaPlan);
        break;
    }
  }

  Future<Map<int, Map<String, dynamic>>> _fetchTotalesPlanes() async {
    try {
      final totales = await _apiService.getPacientesTotalesBatch();
      final map = <int, Map<String, dynamic>>{};
      for (var item in totales) {
        map[item['codigo']] = {
          'count': item['total_planes'] ?? 0,
          'fecha': item['fecha_ultimo_plan'],
        };
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
        title: const Text('Planes Nutricionales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PlanesListScreen(paciente: null),
                ),
              );
            },
            tooltip: 'Ver todos los planes',
          ),
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
          PopupMenuButton<_PlanesTopAction>(
            tooltip: 'Más opciones',
            onSelected: _handleTopAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _PlanesTopAction.filtrar,
                child: Row(children: [
                  Icon(
                    _showFilterPlanes
                        ? Icons.filter_alt
                        : Icons.filter_alt_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  const Text('Filtrar'),
                ]),
              ),
              const PopupMenuItem(
                value: _PlanesTopAction.verTodos,
                child: Row(children: [
                  Icon(Icons.list, size: 18),
                  SizedBox(width: 10),
                  Text('Ver todos los planes'),
                ]),
              ),
              const PopupMenuItem(
                value: _PlanesTopAction.refrescar,
                child: Row(children: [
                  Icon(Icons.refresh, size: 18),
                  SizedBox(width: 10),
                  Text('Refrescar'),
                ]),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                value: _PlanesTopAction.sortNombre,
                checked: _ordenPlanes == _OrdenPlanes.nombre,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar paciente')),
                    if (_ordenPlanes == _OrdenPlanes.nombre)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem(
                value: _PlanesTopAction.sortNumPlanes,
                checked: _ordenPlanes == _OrdenPlanes.numPlanes,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar nº planes')),
                    if (_ordenPlanes == _OrdenPlanes.numPlanes)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem(
                value: _PlanesTopAction.sortFechaPlan,
                checked: _ordenPlanes == _OrdenPlanes.fechaPlan,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Recientes')),
                    if (_ordenPlanes == _OrdenPlanes.fechaPlan)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const PlanEditScreen()),
          );
        },
        tooltip: 'Añadir Plan',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (_showFilterPlanes)
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
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
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade100,
                  border: Border.all(color: Colors.yellow.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    'Seleccione un paciente para ver sus Planes Nutricionales',
                    style: TextStyle(
                      fontSize: 12,
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
                return FutureBuilder<Map<int, Map<String, dynamic>>>(
                  future: _totalesPlanesMap,
                  builder: (context, totalesSnap) {
                    final totalesMap = totalesSnap.data ?? {};
                    // Sort pacientes according to current sort criteria
                    final sorted = List<Paciente>.from(pacientes)
                      ..sort((a, b) {
                        int cmp;
                        switch (_ordenPlanes) {
                          case _OrdenPlanes.nombre:
                            cmp = a.nombre
                                .toLowerCase()
                                .compareTo(b.nombre.toLowerCase());
                            break;
                          case _OrdenPlanes.numPlanes:
                            final countA =
                                (totalesMap[a.codigo]?['count'] ?? 0) as int;
                            final countB =
                                (totalesMap[b.codigo]?['count'] ?? 0) as int;
                            cmp = countA.compareTo(countB);
                            if (cmp == 0) {
                              cmp = a.nombre
                                  .toLowerCase()
                                  .compareTo(b.nombre.toLowerCase());
                            }
                            break;
                          case _OrdenPlanes.fechaPlan:
                            final fechaA = (totalesMap[a.codigo]?['fecha'] ??
                                '') as String;
                            final fechaB = (totalesMap[b.codigo]?['fecha'] ??
                                '') as String;
                            cmp = fechaA.compareTo(fechaB);
                            if (cmp == 0) {
                              cmp = a.nombre
                                  .toLowerCase()
                                  .compareTo(b.nombre.toLowerCase());
                            }
                            break;
                        }
                        return _ordenAscendente ? cmp : -cmp;
                      });
                    return ListView.builder(
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        final paciente = sorted[index];
                        final count =
                            (totalesMap[paciente.codigo]?['count'] ?? 0) as int;
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
                                      PlanesListScreen(paciente: paciente),
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
