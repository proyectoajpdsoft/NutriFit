import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/cita.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/screens/citas/cita_edit_screen.dart';
import 'package:nutri_app/screens/citas/citas_calendar_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/citas_pdf_service.dart';
import 'package:nutri_app/mixins/auth_error_handler_mixin.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _showFilterCitas = false;
  bool _openCalendarOnStart = false;

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
    _loadCitas();
    if (_openCalendarOnStart && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openCalendarView();
      });
    }
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final filtro = prefs.getString('citas_filtro_estado') ?? 'Pendiente';
    final showSearch = prefs.getBool('citas_show_search_field') ?? false;
    final showFilter = prefs.getBool('citas_list_show_filter') ?? false;
    final defaultView = prefs.getString('citas_default_view') ?? 'list';
    if (!mounted) return;
    setState(() {
      _filtroEstado = filtro;
      _showSearchField = showSearch;
      _showFilterCitas = showFilter;
      _openCalendarOnStart = defaultView == 'calendar';
    });
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('citas_filtro_estado', _filtroEstado);
    await prefs.setBool('citas_show_search_field', _showSearchField);
    await prefs.setBool('citas_list_show_filter', _showFilterCitas);
  }

  void _openCalendarView() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => CitasCalendarScreen(
              paciente: widget.paciente,
              fromListView: true,
            ),
          ),
        )
        .then((_) => _loadCitas());
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

  Future<void> _generarPdfCitas() async {
    try {
      final apiService = context.read<ApiService>();

      // Obtener las citas del estado actual
      final citasFuture = apiService.getCitas(
        estado: _filtroEstado == 'Todas' ? null : _filtroEstado,
        codigoPaciente: widget.paciente?.codigo,
      );

      final citas = await citasFuture;

      if (citas.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay citas para exportar'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

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

      await CitasPdfService.generateCitasPdf(
        context: context,
        nutricionistaNombre: nutricionistaNombre,
        nutricionistaSubtitulo: nutricionistaSubtitulo,
        logoBytes: logoBytes,
        logoSizeStr: logoSizeStr,
        accentColorStr: accentColorStr,
        citas: citas,
        filtroEstado: _filtroEstado,
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
              _openCalendarView();
            },
          ),
          IconButton(
            icon: Icon(_showFilterCitas
                ? Icons.filter_alt
                : Icons.filter_alt_outlined),
            tooltip: _showFilterCitas ? 'Ocultar filtro' : 'Mostrar filtro',
            onPressed: () {
              setState(() {
                _showFilterCitas = !_showFilterCitas;
              });
              _saveUiState();
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Generar PDF',
            onPressed: () => _generarPdfCitas(),
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
            if (_showFilterCitas)
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
                              value: "Pendiente", label: Text('Pend.')),
                          ButtonSegment(value: "Todas", label: Text('Todas')),
                        ],
                        selected: {_filtroEstado},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _filtroEstado = newSelection.first;
                          });
                          _saveUiState();
                          _loadCitas();
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
                              // Línea 2: Empieza y Acaba (tags con icono)
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (cita.comienzo != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.green[200]!,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.play_circle_outline,
                                              size: 14, color: Colors.green),
                                          const SizedBox(width: 4),
                                          Text(
                                            fechaTexto,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (cita.fin != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red[50],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.red[200]!,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.stop_circle_outlined,
                                              size: 14, color: Colors.red),
                                          const SizedBox(width: 4),
                                          Text(
                                            DateFormat("dd/MM/yyyy HH:mm")
                                                .format(cita.fin!),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.red[700],
                                            ),
                                          ),
                                        ],
                                      ),
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
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber[100],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber[300]!),
                                ),
                                child: Text(
                                  cita.asunto,
                                  style: const TextStyle(fontSize: 12),
                                ),
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
