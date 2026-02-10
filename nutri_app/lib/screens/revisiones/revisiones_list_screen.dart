import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/revision.dart';
import 'package:nutri_app/screens/revisiones/revision_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    _refreshRevisiones();
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
              icon: const Icon(Icons.refresh), onPressed: _refreshRevisiones),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                          _refreshRevisiones();
                        });
                      },
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
                    debugPrint('Error al cargar revisiones: $errorMessage');
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

                      // Formato de fecha
                      final String fechaLineaTexto;
                      if (revision.fechaRealizacion != null) {
                        fechaLineaTexto =
                            'Realizada: ${DateFormat('dd/MM/yyyy').format(revision.fechaRealizacion!)}';
                      } else if (revision.fechaPrevista != null) {
                        fechaLineaTexto =
                            'Prevista: ${DateFormat('dd/MM/yyyy HH:mm').format(revision.fechaPrevista!)}';
                      } else {
                        fechaLineaTexto = 'Sin fecha';
                      }

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if ((revision.nombrePaciente ??
                                                widget.paciente?.nombre) !=
                                            null) ...[
                                          Text(
                                            revision.nombrePaciente ??
                                                widget.paciente!.nombre,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        if (revision.asunto.isNotEmpty) ...[
                                          Text(
                                            revision.asunto,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        if (revision.semanas.isNotEmpty) ...[
                                          Text(
                                            'Semanas: ${revision.semanas}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Colors.grey[700],
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        Text(
                                          fechaLineaTexto,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey[700],
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (revision.completada != 'S')
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.check),
                                      label: const Text('Completar'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () =>
                                          _showCompletarRevisionDialog(
                                              revision),
                                    ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    color: Colors.blue,
                                    onPressed: () =>
                                        _navigateToEditScreen(revision),
                                    tooltip: 'Editar',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
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
}
