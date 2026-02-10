import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/cita.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/screens/citas/cita_edit_screen.dart';
import 'package:nutri_app/screens/citas/citas_calendar_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/mixins/auth_error_handler_mixin.dart';
import 'package:provider/provider.dart';

class CitasListScreen extends StatefulWidget {
  final Paciente? paciente;
  const CitasListScreen({super.key, this.paciente});

  @override
  State<CitasListScreen> createState() => _CitasListScreenState();
}

class _CitasListScreenState extends State<CitasListScreen>
    with AuthErrorHandlerMixin {
  late Future<List<Cita>> _citasFuture;
  String _filtroEstado = 'Pendiente';
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _showSearchField = false;

  @override
  void initState() {
    super.initState();
    _loadCitas();
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

  void _loadCitas() {
    final apiService = context.read<ApiService>();
    setState(() {
      _citasFuture = apiService.getCitas(
        estado: _filtroEstado == 'Todas' ? null : _filtroEstado,
        codigoPaciente: widget.paciente?.codigo,
      );
    });
  }

  List<Cita> _filterCitas(List<Cita> citas) {
    if (_searchText.isEmpty) {
      return citas;
    }

    return citas.where((cita) {
      final nombrePaciente = (cita.nombrePaciente ?? '').toLowerCase();
      final asunto = cita.asunto.toLowerCase();
      final ubicacion = (cita.ubicacion ?? '').toLowerCase();
      final descripcion = (cita.descripcion ?? '').toLowerCase();
      final tipo = (cita.tipo ?? '').toLowerCase();

      return nombrePaciente.contains(_searchText) ||
          asunto.contains(_searchText) ||
          ubicacion.contains(_searchText) ||
          descripcion.contains(_searchText) ||
          tipo.contains(_searchText);
    }).toList();
  }

  void _navigateToEditScreen({Cita? cita}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => CitaEditScreen(
              cita: cita,
              paciente: widget.paciente,
              selectedDate: cita == null ? DateTime.now() : null,
            ),
          ),
        )
        .then((_) => _loadCitas());
  }

  Future<void> _deleteCita(int codigo) async {
    try {
      final apiService = context.read<ApiService>();
      final success = await apiService.deleteCita(codigo);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita eliminada'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCitas();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Maneja errores de autenticación
      if (!handleAuthError(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeleteConfirmation(Cita cita) {
    final fechaTexto = cita.comienzo == null
        ? 'sin fecha'
        : DateFormat('dd/MM/yyyy HH:mm').format(cita.comienzo!);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
              '¿Seguro que quieres eliminar la cita "${cita.asunto}" del $fechaTexto?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteCita(cita.codigo);
              },
            ),
          ],
        );
      },
    );
  }

  void _showRealizarCitaDialog(Cita cita) {
    final TextEditingController descController = TextEditingController();
    if (cita.descripcion != null && cita.descripcion!.isNotEmpty) {
      descController.text = cita.descripcion!;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Realizar Cita'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Descripción de la cita:'),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 4,
                minLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Resultado de la cita...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ],
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
                _realizarCita(cita, descController.text);
              },
              icon: const Icon(Icons.check),
              label: const Text('Realizar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _realizarCita(Cita cita, String descripcion) async {
    try {
      final apiService = context.read<ApiService>();
      final authService = context.read<AuthService>();
      final codusuario = authService.userCode;
      final ahora = DateTime.now();

      final datosActualizacion = {
        'codigo': cita.codigo,
        'codigo_paciente': cita.codigoPaciente,
        'estado': 'Realizada',
        'descripcion': descripcion,
        'fecham': ahora.toIso8601String(),
        'codusuariom': codusuario,
      };

      await apiService.updateCitaData(datosActualizacion);

      _loadCitas();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cita realizada correctamente'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.paciente == null
              ? 'Citas'
              : 'Citas de ${widget.paciente!.nombre}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Ver en calendario',
            onPressed: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) => CitasCalendarScreen(
                        paciente: widget.paciente,
                      ),
                    ),
                  )
                  .then((_) => _loadCitas());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loadCitas,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.paciente != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mostrando citas de: ${widget.paciente!.nombre}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: "Pendiente", label: Text('Pendientes')),
                        ButtonSegment(value: "Todas", label: Text('Todas')),
                      ],
                      selected: {_filtroEstado},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _filtroEstado = newSelection.first;
                          _loadCitas();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
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
            ),
            if (_showSearchField)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar en paciente, asunto, ubicación...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchText.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
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
              child: FutureBuilder<List<Cita>>(
                future: _citasFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    // Intenta manejar como error de autenticación
                    if (handleAuthError(snapshot.error)) {
                      return const SizedBox.shrink();
                    }
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text('No se encontraron citas.'));
                  }

                  final citas = _filterCitas(snapshot.data!);

                  if (citas.isEmpty) {
                    return const Center(
                        child: Text('No hay resultados para la búsqueda.'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: citas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final cita = citas[index];
                      final pacienteNombre = cita.nombrePaciente ??
                          widget.paciente?.nombre ??
                          'Paciente';
                      final fechaTexto = cita.comienzo == null
                          ? 'Sin fecha'
                          : DateFormat('dd/MM/yyyy HH:mm')
                              .format(cita.comienzo!);

                      return Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Línea 1: Paciente
                              Text(
                                pacienteNombre,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Línea 2: Empieza y Acaba
                              Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                children: [
                                  if (cita.comienzo != null) ...[
                                    Text(
                                      'Empieza: $fechaTexto',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    if (cita.fin != null)
                                      Text(
                                        '• Acaba: ${DateFormat("dd/MM/yyyy HH:mm").format(cita.fin!)}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                  ] else
                                    const Text(
                                      'Sin fecha',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Línea 3: Tipo y Estado (etiquetas)
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (cita.tipo != null)
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
                                      child: Text(
                                        cita.tipo!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ),
                                  if (cita.estado != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[50],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.orange[200]!,
                                        ),
                                      ),
                                      child: Text(
                                        cita.estado!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Línea 4: Asunto/Cita
                              Text(
                                'Cita: ${cita.asunto}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              // Botones
                              Row(
                                children: [
                                  if (cita.estado == 'Pendiente')
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () =>
                                            _showRealizarCitaDialog(cita),
                                        icon: const Icon(Icons.check),
                                        label: const Text(
                                          'Realizar',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  if (cita.estado == 'Pendiente')
                                    const SizedBox(width: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        color: Colors.blue,
                                        onPressed: () =>
                                            _navigateToEditScreen(cita: cita),
                                        tooltip: 'Editar',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        color: Colors.red,
                                        onPressed: () =>
                                            _showDeleteConfirmation(cita),
                                        tooltip: 'Eliminar',
                                      ),
                                    ],
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
        onPressed: () => _navigateToEditScreen(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
