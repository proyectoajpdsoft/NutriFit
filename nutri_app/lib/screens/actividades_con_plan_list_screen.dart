import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entrenamiento.dart';
import '../screens/entrenamientos_pacientes_plan_fit_screen.dart';
import '../services/api_service.dart';

class ActividadesConPlanListScreen extends StatefulWidget {
  const ActividadesConPlanListScreen({super.key});

  @override
  State<ActividadesConPlanListScreen> createState() =>
      _ActividadesConPlanListScreenState();
}

class _ActividadesConPlanListScreenState
    extends State<ActividadesConPlanListScreen> {
  late Future<List<Map<String, dynamic>>> _actividadesFuture;

  @override
  void initState() {
    super.initState();
    _actividadesFuture = _loadActividades();
  }

  Future<List<Map<String, dynamic>>> _loadActividades() async {
    final apiService = context.read<ApiService>();
    return apiService.getActividadesConPlan();
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
      codigo: int.tryParse(item['codigo']?.toString() ?? ''),
      codigoPaciente: item['codigo_paciente']?.toString() ?? '',
      actividad: item['actividad']?.toString() ?? '',
      descripcionActividad: item['descripcion_actividad']?.toString(),
      fecha: fecha,
      duracionHoras:
          int.tryParse(item['duracion_horas']?.toString() ?? '') ?? 0,
      duracionMinutos:
          int.tryParse(item['duracion_minutos']?.toString() ?? '') ?? 0,
      duracionKilometros:
          double.tryParse(item['duracion_kilometros']?.toString() ?? ''),
      nivelEsfuerzo:
          int.tryParse(item['nivel_esfuerzo']?.toString() ?? '') ?? 5,
      notas: item['notas']?.toString(),
      fotos: null,
      vueltas: int.tryParse(item['vueltas']?.toString() ?? ''),
      codigoPlanFit: int.tryParse(item['codigo_plan_fit']?.toString() ?? ''),
      codUsuario: item['codusuario']?.toString() ?? '',
      fechaA: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividades con Plan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _actividadesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar actividades: ${snapshot.error}'),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('No hay actividades con plan.'),
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
              final duracionHoras =
                  int.tryParse(item['duracion_horas']?.toString() ?? '') ?? 0;
              final duracionMinutos =
                  int.tryParse(item['duracion_minutos']?.toString() ?? '') ?? 0;
              final nivelEsfuerzo =
                  int.tryParse(item['nivel_esfuerzo']?.toString() ?? '') ?? 0;
              final validado = item['validado']?.toString() == '1' ||
                  item['validado']?.toString().toLowerCase() == 'true';

              String duracionStr = '';
              if (duracionHoras > 0 || duracionMinutos > 0) {
                final parts = <String>[];
                if (duracionHoras > 0) parts.add('${duracionHoras}h');
                if (duracionMinutos > 0) parts.add('${duracionMinutos}m');
                duracionStr = parts.join(' ');
              }

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              actividad,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (validado)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 14, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'Validado',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          if (paciente.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person, size: 16),
                                const SizedBox(width: 4),
                                Text(paciente,
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
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
                          if (duracionStr.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer, size: 16),
                                const SizedBox(width: 4),
                                Text(duracionStr,
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          if (nivelEsfuerzo > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.favorite,
                                    size: 16, color: Colors.red),
                                const SizedBox(width: 4),
                                Text('Esfuerzo: $nivelEsfuerzo/10',
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            final entrenamiento =
                                _buildEntrenamientoFromItem(item);
                            final nombrePaciente =
                                item['nombre_paciente']?.toString() ?? '';
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EntrenamientoPacientePlanFitDetailScreen(
                                  entrenamiento: entrenamiento,
                                  nombrePaciente: nombrePaciente.isNotEmpty
                                      ? nombrePaciente
                                      : null,
                                ),
                              ),
                            ).then((_) {
                              // Recargar lista al volver
                              setState(() {
                                _actividadesFuture = _loadActividades();
                              });
                            });
                          },
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('Ver detalles'),
                        ),
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
