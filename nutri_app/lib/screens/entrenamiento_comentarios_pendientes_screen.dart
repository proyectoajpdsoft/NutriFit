import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entrenamiento.dart';
import '../screens/entrenamiento_view_screen.dart';
import '../services/api_service.dart';

class EntrenamientoComentariosPendientesScreen extends StatefulWidget {
  const EntrenamientoComentariosPendientesScreen({super.key});

  @override
  State<EntrenamientoComentariosPendientesScreen> createState() =>
      _EntrenamientoComentariosPendientesScreenState();
}

class _EntrenamientoComentariosPendientesScreenState
    extends State<EntrenamientoComentariosPendientesScreen> {
  late Future<List<Map<String, dynamic>>> _comentariosFuture;

  @override
  void initState() {
    super.initState();
    _comentariosFuture = _loadComentarios();
  }

  Future<List<Map<String, dynamic>>> _loadComentarios() async {
    final apiService = context.read<ApiService>();
    return apiService.getComentariosPendientes();
  }

  Future<void> _markAsRead(int codigoEjercicio) async {
    final apiService = context.read<ApiService>();
    await apiService.markComentarioLeido(codigoEjercicio);
    if (!mounted) return;
    setState(() {
      _comentariosFuture = _loadComentarios();
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
      codigoPlanFit: null,
      codUsuario: '',
      fechaA: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comentarios pendientes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _comentariosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar comentarios: ${snapshot.error}'),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('No tienes comentarios pendientes.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final actividad = item['actividad']?.toString() ?? '';
              final fecha = _formatFecha(item['fecha']?.toString());
              final horas =
                  int.tryParse(item['duracion_horas']?.toString() ?? '') ?? 0;
              final minutos =
                  int.tryParse(item['duracion_minutos']?.toString() ?? '') ?? 0;
              final esfuerzo = item['nivel_esfuerzo']?.toString() ?? '-';
              final comentario =
                  item['comentario_nutricionista']?.toString() ?? '';
              final codigoEjercicio =
                  int.tryParse(item['codigo_ejercicio']?.toString() ?? '') ?? 0;
              final codigoEntrenamiento = int.tryParse(
                      item['codigo_entrenamiento']?.toString() ?? '') ??
                  0;

              final tiempoActividad = '${horas}h ${minutos}m';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actividad,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          if (fecha.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.event, size: 16),
                                const SizedBox(width: 4),
                                Text(fecha,
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer, size: 16),
                              const SizedBox(width: 4),
                              Text(tiempoActividad,
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.flash_on, size: 16),
                              const SizedBox(width: 4),
                              Text('Esfuerzo: $esfuerzo',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          comentario,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: codigoEntrenamiento == 0
                                ? null
                                : () {
                                    final entrenamiento =
                                        _buildEntrenamientoFromItem(item);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            EntrenamientoViewScreen(
                                          entrenamiento: entrenamiento,
                                        ),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Ver actividad'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: codigoEjercicio == 0
                                ? null
                                : () => _markAsRead(codigoEjercicio),
                            icon: const Icon(Icons.thumb_up_alt_outlined),
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
