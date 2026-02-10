import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/medicion.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/screens/mediciones/medicion_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:provider/provider.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiService = Provider.of<ApiService>(context);
    _filtroActivo = widget.filtroActivo ?? "S";
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar el paciente: $e'),
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMediciones,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.paciente == null)
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
                              _refreshMediciones();
                            });
                          },
                        ),
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
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (nombrePaciente != null) ...[
                                      Text(nombrePaciente,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                        'Fecha: ${DateFormat('dd/MM/yyyy').format(medicion.fecha)}'),
                                  ],
                                ),
                                subtitle:
                                    Text('Peso: ${medicion.peso ?? '-'} kg'),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Editar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () =>
                                        _navigateToEditScreen(medicion),
                                  ),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.delete),
                                    label: const Text('Eliminar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () =>
                                        _showDeleteConfirmation(medicion),
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
}
