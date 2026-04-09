import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entrenamiento.dart';
import '../screens/entrenamientos_pacientes_plan_fit_screen.dart';
import '../services/api_service.dart';
import 'dart:convert';

class EntrenamientoSensacionesPendientesScreen extends StatefulWidget {
  const EntrenamientoSensacionesPendientesScreen({
    super.key,
    this.codigoPaciente,
    this.codigoPlanFit,
    this.incluirLeidas = false,
    this.titulo,
    this.emptyMessage,
  });

  final int? codigoPaciente;
  final int? codigoPlanFit;
  final bool incluirLeidas;
  final String? titulo;
  final String? emptyMessage;

  @override
  State<EntrenamientoSensacionesPendientesScreen> createState() =>
      _EntrenamientoSensacionesPendientesScreenState();
}

class _EntrenamientoSensacionesPendientesScreenState
    extends State<EntrenamientoSensacionesPendientesScreen> {
  late Future<List<Map<String, dynamic>>> _sensacionesFuture;

  @override
  void initState() {
    super.initState();
    _sensacionesFuture = _loadSensaciones();
  }

  Future<List<Map<String, dynamic>>> _loadSensaciones() async {
    final apiService = context.read<ApiService>();
    return apiService.getSensacionesNutri(
      codigoPaciente: widget.codigoPaciente,
      codigoPlanFit: widget.codigoPlanFit,
      incluirLeidas: widget.incluirLeidas,
    );
  }

  Future<void> _markAsRead(int codigoEjercicio) async {
    final apiService = context.read<ApiService>();
    await apiService.markSensacionesLeidas(codigoEjercicio);
    if (!mounted) return;
    setState(() {
      _sensacionesFuture = _loadSensaciones();
    });
  }

  String _formatFecha(String? fechaRaw) {
    if (fechaRaw == null || fechaRaw.isEmpty) return '';
    final parsed = DateTime.tryParse(fechaRaw);
    if (parsed == null) return '';
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
  }

  Entrenamiento _buildEntrenamientoFromItem(Map<String, dynamic> item) {
    final fecha =
        DateTime.tryParse(item['fecha']?.toString() ?? '') ?? DateTime.now();

    return Entrenamiento(
      codigo: int.tryParse(item['codigo_entrenamiento']?.toString() ?? ''),
      codigoPaciente: item['codigo_paciente']?.toString() ?? '',
      actividad: item['actividad']?.toString() ?? '',
      descripcionActividad: null,
      fecha: fecha,
      duracionHoras:
          int.tryParse(item['duracion_horas']?.toString() ?? '') ?? 0,
      duracionMinutos:
          int.tryParse(item['duracion_minutos']?.toString() ?? '') ?? 0,
      duracionKilometros: null,
      nivelEsfuerzo:
          int.tryParse(item['nivel_esfuerzo']?.toString() ?? '') ?? 5,
      notas: null,
      fotos: null,
      vueltas: null,
      codigoPlanFit: int.tryParse(item['codigo_plan_fit']?.toString() ?? ''),
      codUsuario: '',
      fechaA: null,
    );
  }

  bool _isSensacionLeida(Map<String, dynamic> item) {
    final raw = item['sensaciones_leido_nutri'];
    if (raw == null) return false;
    final value = raw.toString().toLowerCase();
    return value == '1' || value == 'true' || value == 's';
  }

  String get _screenTitle {
    return widget.titulo ??
        (widget.incluirLeidas
            ? 'Sensaciones de ejercicios'
            : 'Sensaciones de ejercicios pendientes');
  }

  String get _emptyStateMessage {
    return widget.emptyMessage ??
        (widget.incluirLeidas
            ? 'No hay sensaciones de ejercicios registradas.'
            : 'No hay sensaciones pendientes.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _sensacionesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar sensaciones: ${snapshot.error}'),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text(_emptyStateMessage),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final actividad = item['actividad']?.toString() ?? '';
              final paciente = item['nombre_paciente']?.toString() ?? '';
              final fecha = _formatFecha(item['fecha']?.toString());
              final sensaciones = item['sensaciones']?.toString() ?? '';
              final sensacionLeida = _isSensacionLeida(item);
              final fechaLectura = _formatFecha(
                  item['sensaciones_leido_nutri_fecha']?.toString());
              final codigoEjercicio =
                  int.tryParse(item['codigo_ejercicio']?.toString() ?? '') ?? 0;
              final codigoEntrenamiento = int.tryParse(
                      item['codigo_entrenamiento']?.toString() ?? '') ??
                  0;
              final nombreEjercicio =
                  item['nombre_ejercicio']?.toString() ?? '';
              final usuarioImgPerfil =
                  item['usuario_img_perfil']?.toString() ?? '';

              // Widget para mostrar solo la imagen de perfil del usuario
              Widget buildThumbnail() {
                if (usuarioImgPerfil.isNotEmpty) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(usuarioImgPerfil),
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  );
                } else {
                  return Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        const Icon(Icons.person, size: 36, color: Colors.grey),
                  );
                }
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado: Actividad
                      Text(
                        actividad,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Fila con miniatura y contenido
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Miniatura a la izquierda
                          buildThumbnail(),
                          const SizedBox(width: 12),
                          // Contenido a la derecha
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Nombre del ejercicio
                                Text(
                                  nombreEjercicio,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                // Paciente y fecha
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    if (paciente.isNotEmpty)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.person,
                                              size: 14, color: Colors.grey),
                                          const SizedBox(width: 3),
                                          Text(paciente,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey)),
                                        ],
                                      ),
                                    if (fecha.isNotEmpty)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.event,
                                              size: 14, color: Colors.grey),
                                          const SizedBox(width: 3),
                                          Text(fecha,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey)),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Sensaciones
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: Colors.amber.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    sensaciones,
                                    style: const TextStyle(fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      sensacionLeida
                                          ? Icons.mark_email_read_outlined
                                          : Icons.mark_email_unread_outlined,
                                      size: 16,
                                      color: sensacionLeida
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        sensacionLeida
                                            ? (fechaLectura.isNotEmpty
                                                ? 'Leído el $fechaLectura'
                                                : 'Leído')
                                            : 'Pendiente de leer',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Botones
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          IconButton(
                            onPressed: codigoEntrenamiento == 0
                                ? null
                                : () {
                                    final entrenamiento =
                                        _buildEntrenamientoFromItem(item);
                                    final nombrePaciente =
                                        item['nombre_paciente']?.toString() ??
                                            '';
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            EntrenamientoPacientePlanFitDetailScreen(
                                          entrenamiento: entrenamiento,
                                          nombrePaciente:
                                              nombrePaciente.isNotEmpty
                                                  ? nombrePaciente
                                                  : null,
                                        ),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.visibility_outlined),
                            iconSize: 28,
                            tooltip: 'Ver actividad',
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: codigoEjercicio == 0 || sensacionLeida
                                ? null
                                : () => _markAsRead(codigoEjercicio),
                            icon: const Icon(Icons.mark_chat_read_outlined,
                                size: 28),
                            label: const Text('Leido'),
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
    );
  }
}
