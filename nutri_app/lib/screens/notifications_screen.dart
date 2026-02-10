import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/cita.dart';
import 'package:nutri_app/models/revision.dart';
import 'package:nutri_app/screens/citas/cita_edit_screen.dart';
import 'package:nutri_app/screens/revisiones/revision_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/services/auth_service.dart';

class NotificationsPendingScreen extends StatefulWidget {
  const NotificationsPendingScreen({super.key});

  @override
  State<NotificationsPendingScreen> createState() =>
      _NotificationsPendingScreenState();
}

class _NotificationsPendingScreenState
    extends State<NotificationsPendingScreen> {
  late Future<Map<String, dynamic>> _pendingDataFuture;

  @override
  void initState() {
    super.initState();
    _loadPendingData();
  }

  void _loadPendingData() {
    _pendingDataFuture = _fetchPendingData();
  }

  Future<Map<String, dynamic>> _fetchPendingData() async {
    try {
      final apiService = context.read<ApiService>();

      // Obtener citas pendientes (solo con estado = 'Pendiente')
      final citas = await apiService.getCitas();
      final pendingCitas = citas
          .where((c) => c.estado != null && c.estado == 'Pendiente')
          .toList();
      // Ordenar por Empieza de mayor a menor (descendente)
      pendingCitas.sort((a, b) {
        if (a.comienzo == null || b.comienzo == null) return 0;
        return b.comienzo!.compareTo(a.comienzo!);
      });

      // Obtener revisiones pendientes
      final revisiones = await apiService.getRevisiones();
      final pendingRevisiones =
          revisiones.where((r) => r.completada != 'S').toList();

      return {
        'citas': pendingCitas,
        'revisiones': pendingRevisiones,
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones Pendientes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _pendingDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loadPendingData();
                        });
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            final citas = snapshot.data?['citas'] as List<Cita>? ?? [];
            final revisiones =
                snapshot.data?['revisiones'] as List<Revision>? ?? [];

            if (citas.isEmpty && revisiones.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 64, color: Colors.green[300]),
                    const SizedBox(height: 16),
                    const Text(
                      '¡Todo al día!',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No tienes citas ni revisiones pendientes',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _loadPendingData();
                });
                await _pendingDataFuture;
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sección de Citas Pendientes
                      if (citas.isNotEmpty) ...[
                        _buildSectionHeader(
                          icon: Icons.calendar_today,
                          title: 'Citas Pendientes',
                          count: citas.length,
                        ),
                        const SizedBox(height: 12),
                        ...citas.map((cita) => _buildCitaCard(cita)),
                        const SizedBox(height: 20),
                      ],

                      // Sección de Revisiones Pendientes
                      if (revisiones.isNotEmpty) ...[
                        _buildSectionHeader(
                          icon: Icons.rate_review_outlined,
                          title: 'Revisiones Pendientes',
                          count: revisiones.length,
                        ),
                        const SizedBox(height: 12),
                        ...revisiones
                            .map((revision) => _buildRevisionCard(revision)),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required int count,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.pink, size: 28),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$count pendiente${count > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCitaCard(Cita cita) {
    final comienzoFormato = cita.comienzo != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(cita.comienzo!)
        : null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con nombre paciente y tipo
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (cita.nombrePaciente != null) ...[
                        Text(
                          cita.nombrePaciente!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (cita.tipo != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.pink[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.pink[200]!,
                                ),
                              ),
                              child: Text(
                                cita.tipo!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.pink[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (cita.estado != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.blue[200]!,
                                ),
                              ),
                              child: Text(
                                cita.estado!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CitaEditScreen(cita: cita),
                      ),
                    ).then((_) {
                      setState(() {
                        _loadPendingData();
                      });
                    });
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Realizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _showRealizarCitaDialog(cita),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (comienzoFormato != null)
              _buildDetailRow(
                icon: Icons.access_time,
                label: 'Empieza',
                value: comienzoFormato,
              ),
            if (cita.asunto.isNotEmpty)
              _buildDetailRow(
                icon: Icons.subject,
                label: 'Asunto',
                value: cita.asunto,
              ),
            if (cita.online != null && cita.online == 'S')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.videocam, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Cita Online',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevisionCard(Revision revision) {
    final fechaPrevista = revision.fechaPrevista != null
        ? DateFormat('dd/MM/yyyy').format(revision.fechaPrevista!)
        : null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con nombre paciente
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (revision.nombrePaciente != null) ...[
                        Text(
                          revision.nombrePaciente!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (revision.asunto.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.orange[200]!,
                            ),
                          ),
                          child: Text(
                            revision.asunto,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RevisionEditScreen(revision: revision),
                      ),
                    ).then((_) {
                      setState(() {
                        _loadPendingData();
                      });
                    });
                  },
                  tooltip: 'Editar revisión',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Detalles
            if (fechaPrevista != null)
              _buildDetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Fecha prevista',
                value: fechaPrevista,
              ),
            if (revision.semanas.isNotEmpty)
              _buildDetailRow(
                icon: Icons.access_time,
                label: 'Semanas',
                value: revision.semanas,
              ),
            if (revision.online != null && revision.online == 'S')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.videocam, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Revisión Online',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            if (revision.modificacionDieta != null &&
                revision.modificacionDieta!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Modificación de la dieta',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            revision.modificacionDieta!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
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
  }

  void _showRealizarCitaDialog(Cita cita) {
    final TextEditingController descController = TextEditingController();
    // Cargar descripción existente si la hay
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _realizarCita(cita, descController.text);
              },
              child: const Text('Realizar'),
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

      setState(() {
        _loadPendingData();
      });

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

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
