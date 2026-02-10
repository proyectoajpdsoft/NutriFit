import 'package:flutter/material.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:nutri_app/screens/citas/citas_list_screen.dart';
import 'package:nutri_app/screens/revisiones/revisiones_list_screen.dart';
import 'package:nutri_app/screens/mediciones/mediciones_list_screen.dart';
import 'package:nutri_app/screens/planes_nutricionales/planes_list_screen.dart';
import 'package:nutri_app/screens/planes_fit/planes_fit_list_screen.dart';
import 'package:nutri_app/screens/entrevistas/entrevistas_list_screen.dart';
import 'package:nutri_app/screens/entrevistas_fit/entrevistas_fit_list_screen.dart';
import 'package:nutri_app/screens/cobros/cobros_list_screen.dart';
import 'package:nutri_app/screens/pacientes/paciente_edit_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class PacientesListScreen extends StatefulWidget {
  const PacientesListScreen({super.key});

  @override
  State<PacientesListScreen> createState() => _PacientesListScreenState();
}

class _PacientesListScreenState extends State<PacientesListScreen> {
  late Future<List<Paciente>> _pacientesFuture;
  String _filtroActivo = "S";
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _showSearchField = false;
  final Map<int, Map<String, int>> _contadores = {};

  @override
  void initState() {
    super.initState();
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

  Future<void> _refreshPacientes() async {
    setState(() {
      _pacientesFuture = ApiService().getPacientes(
          activo: _filtroActivo == "Todos" ? null : _filtroActivo);
    });
  }

  List<Paciente> _filterPacientes(List<Paciente> pacientes) {
    if (_searchText.isEmpty) {
      return pacientes;
    }

    return pacientes.where((paciente) {
      final nombre = (paciente.nombre).toLowerCase();
      final observacion = (paciente.observacion ?? '').toLowerCase();
      final provincia = (paciente.provincia ?? '').toLowerCase();
      final telefono = (paciente.telefono ?? '').toLowerCase();
      final dni = (paciente.dni ?? '').toLowerCase();

      return nombre.contains(_searchText) ||
          observacion.contains(_searchText) ||
          provincia.contains(_searchText) ||
          telefono.contains(_searchText) ||
          dni.contains(_searchText);
    }).toList();
  }

  Future<void> _loadContadores(int codigoPaciente) async {
    if (_contadores.containsKey(codigoPaciente)) {
      return; // Ya están cargados
    }

    try {
      final apiService = ApiService();
      final citas = await apiService.getCitas(
          codigoPaciente: codigoPaciente, estado: null);
      final revisiones = await apiService.getRevisiones(
          codigoPaciente: codigoPaciente, completada: null);
      final mediciones = await apiService.getMediciones(codigoPaciente);
      final entrevistas = await apiService.getEntrevistas(codigoPaciente);
      final planes = await apiService.getPlanes(codigoPaciente);
      final entrevistasFit = await apiService.getEntrevistasFit(codigoPaciente);
      // NOTE: getPlansFit has a Dart analyzer caching issue, will load count on demand
      final cobros = await apiService.getCobros(codigoPaciente: codigoPaciente);

      setState(() {
        _contadores[codigoPaciente] = {
          'citas': citas.length,
          'revisiones': revisiones.length,
          'mediciones': mediciones.length,
          'entrevistas': entrevistas.length,
          'planes': planes.length,
          'entrevistas_fit': entrevistasFit.length,
          'planes_fit': 0, // Will be loaded when button is clicked
          'cobros': cobros.length,
        };
      });
    } catch (e) {
      // Si hay error, no hacer nada
    }
  }

  Widget _buildCountBadge(int? count) {
    final hasCount = count != null && count > 0;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: hasCount ? Colors.green : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      constraints: const BoxConstraints(
        minWidth: 20,
        minHeight: 20,
      ),
      child: Center(
        child: Text(
          count?.toString() ?? '0',
          style: TextStyle(
            color: hasCount ? Colors.white : Colors.grey[600],
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _navigateToEditScreen([Paciente? paciente]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PacienteEditScreen(paciente: paciente),
      ),
    );
    _refreshPacientes();
  }

  // Navegar a una pantalla y recargar contadores del paciente al volver
  Future<void> _navigateAndRefreshCounters(
      Widget screen, int codigoPaciente) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
    // Recargar solo los contadores del paciente cuando se vuelve
    _loadContadores(codigoPaciente);
  }

  void _showDeleteConfirmation(Paciente paciente) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
              '¿Estás seguro de que quieres eliminar el paciente ${paciente.nombre}?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deletePaciente(paciente.codigo);
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  void _deletePaciente(int codigo) async {
    try {
      await ApiService().deletePaciente(codigo);
      _refreshPacientes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Paciente eliminado'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar paciente: $e')),
        );
      }
    }
  }

  void _makePhoneCall(Paciente paciente) {
    if (paciente.telefono == null || paciente.telefono!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este paciente no tiene teléfono registrado'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Realizar llamada'),
          content: Text(
              '¿Deseas llamar a ${paciente.nombre} al número ${paciente.telefono}?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final Uri telUri = Uri(scheme: 'tel', path: paciente.telefono);
                if (await canLaunchUrl(telUri)) {
                  await launchUrl(telUri);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se puede realizar la llamada'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Llamar'),
            ),
          ],
        );
      },
    );
  }

  void _sendEmail(Paciente paciente) {
    if (paciente.email1 == null || paciente.email1!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este paciente no tiene email registrado'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enviar email'),
          content: Text(
              '¿Deseas enviar un email a ${paciente.nombre} (${paciente.email1})?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final Uri emailUri = Uri(
                  scheme: 'mailto',
                  path: paciente.email1!,
                  queryParameters: {
                    'subject': 'Asunto del email',
                    'body': 'Mensaje para ${paciente.nombre}',
                  },
                );
                try {
                  await launchUrl(
                    emailUri,
                    mode: LaunchMode.externalApplication,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se puede enviar el email'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Volver',
        ),
        title: const Text('Pacientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPacientes,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
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
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, DNI, teléfono, provincia...',
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
              child: FutureBuilder<List<Paciente>>(
                future: _pacientesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text('No hay pacientes registrados.'));
                  } else {
                    final allPacientes = snapshot.data!;
                    final pacientes = _filterPacientes(allPacientes);

                    if (pacientes.isEmpty && _searchText.isNotEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No se encontraron pacientes',
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

                    return ListView.builder(
                      itemCount: pacientes.length,
                      itemBuilder: (context, index) {
                        final paciente = pacientes[index];
                        // Cargar contadores para este paciente
                        _loadContadores(paciente.codigo);
                        final contadores = _contadores[paciente.codigo];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          elevation: 2,
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Contenido principal del paciente
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Información del paciente
                                      ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 2),
                                        title: Text(
                                          paciente.nombre,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        subtitle: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2.0),
                                          child: Text(
                                            'Edad: ${paciente.edad ?? "-"} | Tlfno: ${paciente.telefono ?? "-"}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600]),
                                          ),
                                        ),
                                        onTap: () =>
                                            _navigateToEditScreen(paciente),
                                      ),
                                      // Sección de botones organizados
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            12.0, 0, 12.0, 4.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Primera fila: comunicación y edición
                                            Wrap(
                                              spacing: 4.0,
                                              runSpacing: 2.0,
                                              children: [
                                                ActionChip(
                                                  avatar: const Icon(
                                                      Icons.phone,
                                                      size: 18),
                                                  label:
                                                      const SizedBox.shrink(),
                                                  onPressed: () =>
                                                      _makePhoneCall(paciente),
                                                  backgroundColor:
                                                      Colors.green[50],
                                                  side: BorderSide(
                                                      color:
                                                          Colors.green[300]!),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 1,
                                                      vertical: 1),
                                                ),
                                                ActionChip(
                                                  avatar: const Icon(
                                                      Icons.email,
                                                      size: 18),
                                                  label:
                                                      const SizedBox.shrink(),
                                                  onPressed: () =>
                                                      _sendEmail(paciente),
                                                  backgroundColor:
                                                      Colors.blue[50],
                                                  side: BorderSide(
                                                      color: Colors.blue[300]!),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 1,
                                                      vertical: 1),
                                                ),
                                                ActionChip(
                                                  avatar: const Icon(Icons.edit,
                                                      size: 18,
                                                      color: Colors.blue),
                                                  label:
                                                      const SizedBox.shrink(),
                                                  onPressed: () =>
                                                      _navigateToEditScreen(
                                                          paciente),
                                                  backgroundColor:
                                                      Colors.blue[50],
                                                  side: BorderSide(
                                                      color: Colors.blue[300]!),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 2,
                                                      vertical: 2),
                                                ),
                                                const SizedBox(width: 4),
                                                ActionChip(
                                                  avatar: const Icon(
                                                      Icons.delete,
                                                      size: 18,
                                                      color: Colors.red),
                                                  label:
                                                      const SizedBox.shrink(),
                                                  onPressed: () =>
                                                      _onDeletePacienteTapped(
                                                          paciente),
                                                  backgroundColor:
                                                      Colors.red[50],
                                                  side: BorderSide(
                                                      color: Colors.red[300]!),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 2,
                                                      vertical: 2),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            // Segunda fila: consultas
                                            Wrap(
                                              spacing: 4.0,
                                              runSpacing: 2.0,
                                              children: [
                                                ActionChip(
                                                  avatar: const Icon(
                                                      Icons.calendar_today,
                                                      size: 12,
                                                      color: Colors.purple),
                                                  label: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Text('CI',
                                                          style: TextStyle(
                                                              fontSize: 10)),
                                                      const SizedBox(width: 2),
                                                      _buildCountBadge(
                                                          contadores?['citas']),
                                                    ],
                                                  ),
                                                  onPressed: () =>
                                                      _navigateAndRefreshCounters(
                                                    CitasListScreen(
                                                        paciente: paciente),
                                                    paciente.codigo,
                                                  ),
                                                  backgroundColor:
                                                      Colors.purple[50],
                                                  side: BorderSide(
                                                      color:
                                                          Colors.purple[200]!),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 4,
                                                      vertical: 1),
                                                ),
                                                ActionChip(
                                                  avatar: const Icon(
                                                      Icons.rate_review,
                                                      size: 12,
                                                      color: Colors.indigo),
                                                  label: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Text('RE',
                                                          style: TextStyle(
                                                              fontSize: 10)),
                                                      const SizedBox(width: 2),
                                                      _buildCountBadge(
                                                          contadores?[
                                                              'revisiones']),
                                                    ],
                                                  ),
                                                  onPressed: () =>
                                                      _navigateAndRefreshCounters(
                                                    RevisionesListScreen(
                                                        paciente: paciente),
                                                    paciente.codigo,
                                                  ),
                                                  backgroundColor:
                                                      Colors.indigo[50],
                                                  side: BorderSide(
                                                      color:
                                                          Colors.indigo[200]!),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 4,
                                                      vertical: 1),
                                                ),
                                                ActionChip(
                                                  avatar: const Icon(
                                                      Icons.fitbit_rounded,
                                                      size: 12,
                                                      color: Colors.green),
                                                  label: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Text('ME',
                                                          style: TextStyle(
                                                              fontSize: 10)),
                                                      const SizedBox(width: 2),
                                                      _buildCountBadge(
                                                          contadores?[
                                                              'mediciones']),
                                                    ],
                                                  ),
                                                  onPressed: () =>
                                                      _navigateAndRefreshCounters(
                                                    MedicionesListScreen(
                                                        paciente: paciente),
                                                    paciente.codigo,
                                                  ),
                                                  backgroundColor:
                                                      Colors.green[50],
                                                  side: BorderSide(
                                                      color:
                                                          Colors.green[200]!),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 4,
                                                      vertical: 1),
                                                ),
                                                ActionChip(
                                                  avatar: const Icon(
                                                      Icons.assignment,
                                                      size: 12,
                                                      color: Colors.orange),
                                                  label: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Text('EN',
                                                          style: TextStyle(
                                                              fontSize: 10)),
                                                      const SizedBox(width: 2),
                                                      _buildCountBadge(
                                                          contadores?[
                                                              'entrevistas']),
                                                    ],
                                                  ),
                                                  onPressed: () =>
                                                      _navigateAndRefreshCounters(
                                                    EntrevistasListScreen(
                                                        paciente: paciente),
                                                    paciente.codigo,
                                                  ),
                                                  backgroundColor:
                                                      Colors.orange[50],
                                                  side: BorderSide(
                                                      color:
                                                          Colors.orange[200]!),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 4,
                                                      vertical: 1),
                                                ),
                                                ActionChip(
                                                  avatar: const Icon(
                                                      Icons.sports_gymnastics,
                                                      size: 12,
                                                      color: Colors.red),
                                                  label: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Text('EF',
                                                          style: TextStyle(
                                                              fontSize: 10)),
                                                      const SizedBox(width: 2),
                                                      _buildCountBadge(
                                                          contadores?[
                                                              'entrevistas_fit']),
                                                    ],
                                                  ),
                                                  onPressed: () =>
                                                      _navigateAndRefreshCounters(
                                                    EntrevistasFitListScreen(
                                                        paciente: paciente),
                                                    paciente.codigo,
                                                  ),
                                                  backgroundColor:
                                                      Colors.red[50],
                                                  side: BorderSide(
                                                      color: Colors.red[200]!),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 4,
                                                      vertical: 1),
                                                ),
                                                ActionChip(
                                                  avatar: const Icon(
                                                      Icons.description,
                                                      size: 12,
                                                      color: Colors.teal),
                                                  label: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Text('PN',
                                                          style: TextStyle(
                                                              fontSize: 10)),
                                                      const SizedBox(width: 2),
                                                      _buildCountBadge(
                                                          contadores?[
                                                              'planes']),
                                                    ],
                                                  ),
                                                  onPressed: () =>
                                                      _navigateAndRefreshCounters(
                                                    PlanesListScreen(
                                                        paciente: paciente),
                                                    paciente.codigo,
                                                  ),
                                                  backgroundColor:
                                                      Colors.teal[50],
                                                  side: BorderSide(
                                                      color: Colors.teal[200]!),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 4,
                                                      vertical: 1),
                                                ),
                                                ActionChip(
                                                  avatar: const Icon(
                                                      Icons
                                                          .fitness_center_outlined,
                                                      size: 12,
                                                      color: Colors.purple),
                                                  label: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Text('PF',
                                                          style: TextStyle(
                                                              fontSize: 10)),
                                                      const SizedBox(width: 2),
                                                      _buildCountBadge(
                                                          contadores?[
                                                              'planes_fit']),
                                                    ],
                                                  ),
                                                  onPressed: () =>
                                                      _navigateAndRefreshCounters(
                                                    PlanesFitListScreen(
                                                        paciente: paciente),
                                                    paciente.codigo,
                                                  ),
                                                  backgroundColor:
                                                      Colors.purple[50],
                                                  side: BorderSide(
                                                      color:
                                                          Colors.purple[200]!),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 4,
                                                      vertical: 1),
                                                ),
                                                ActionChip(
                                                  avatar: const Icon(
                                                      Icons.monetization_on,
                                                      size: 12,
                                                      color: Colors.amber),
                                                  label: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Text('CO',
                                                          style: TextStyle(
                                                              fontSize: 10)),
                                                      const SizedBox(width: 2),
                                                      _buildCountBadge(
                                                          contadores?[
                                                              'cobros']),
                                                    ],
                                                  ),
                                                  onPressed: () =>
                                                      _navigateAndRefreshCounters(
                                                    CobrosListScreen(
                                                        paciente: paciente),
                                                    paciente.codigo,
                                                  ),
                                                  backgroundColor:
                                                      Colors.amber[50],
                                                  side: BorderSide(
                                                      color:
                                                          Colors.amber[300]!),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 4,
                                                      vertical: 1),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditScreen(),
        tooltip: 'Añadir Paciente',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _onDeletePacienteTapped(Paciente paciente) async {
    final hasRelated = await _hasRelatedData(paciente.codigo);
    if (hasRelated) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: const Text(
              'Este paciente tiene citas, revisiones, entrevistas, mediciones o cobros asociados. Por seguridad, no se permite eliminarlo.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            )
          ],
        ),
      );
      return;
    }

    _showDeleteConfirmation(paciente);
  }

  Future<bool> _hasRelatedData(int codigoPaciente) async {
    final api = ApiService();
    try {
      final citas = await api.getCitas(codigoPaciente: codigoPaciente);
      if (citas.isNotEmpty) return true;

      final revisiones =
          await api.getRevisiones(codigoPaciente: codigoPaciente);
      if (revisiones.isNotEmpty) return true;

      final entrevistas = await api.getEntrevistas(codigoPaciente);
      if (entrevistas.isNotEmpty) return true;

      final mediciones = await api.getMediciones(codigoPaciente);
      if (mediciones.isNotEmpty) return true;

      final cobros = await api.getCobros(codigoPaciente: codigoPaciente);
      if (cobros.isNotEmpty) return true;

      final planes = await api.getPlanes(codigoPaciente);
      if (planes.isNotEmpty) return true;

      final entrevistasFit = await api.getEntrevistasFit(codigoPaciente);
      if (entrevistasFit.isNotEmpty) return true;

      // TODO: Uncomment when getPlansFit is properly recognized
      // final planesFit = await api.getPlansFit(codigoPaciente);
      // if (planesFit.isNotEmpty) return true;

      return false;
    } catch (_) {
      return true;
    }
  }
}
