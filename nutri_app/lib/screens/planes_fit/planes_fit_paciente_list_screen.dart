import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/plan_fit.dart';
import 'package:nutri_app/models/plan_fit_ejercicio.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:nutri_app/widgets/contact_nutricionista_dialog.dart';
import 'package:nutri_app/screens/entrenamiento_edit_screen.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class PlanesFitPacienteListScreen extends StatefulWidget {
  const PlanesFitPacienteListScreen({super.key});

  @override
  State<PlanesFitPacienteListScreen> createState() =>
      _PlanesFitPacienteListScreenState();
}

class _PlanesFitPacienteListScreenState
    extends State<PlanesFitPacienteListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<PlanFit>> _planesFuture;
  String? _patientCode;
  final Map<int, bool> _mostrarEjercicios = {};
  final Map<int, Future<List<PlanFitEjercicio>>> _ejerciciosFutures = {};

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _patientCode = authService.patientCode;

    // Si es modo guest, mostrar diálogo después de que se construya el widget
    if (authService.isGuestMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => const ContactNutricionistaDialog(),
        );
      });
    }

    _refreshPlanes();
  }

  void _refreshPlanes() {
    setState(() {
      if (_patientCode != null && _patientCode!.isNotEmpty) {
        try {
          final patientId = int.parse(_patientCode!);
          _planesFuture = _apiService.getPlanesFit(patientId);
        } catch (e) {
          _planesFuture = Future.value([]);
        }
      } else {
        _planesFuture = Future.value([]);
      }
    });
  }

  Future<void> _downloadAndOpenFile(int codigo, String fileName) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Descargando $fileName...')),
    );
    try {
      final filePath = await _apiService.downloadPlanFit(codigo, fileName);
      if (filePath != null) {
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('No se pudo abrir el fichero: ${result.message}'),
                backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error en la descarga: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '';
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _buildPlanTitle(DateTime? desde, DateTime? hasta) {
    final desdeStr = _formatDate(desde);
    final hastaStr = _formatDate(hasta);
    if (desdeStr.isNotEmpty && hastaStr.isNotEmpty) {
      return 'Plan del $desdeStr al $hastaStr';
    }
    if (desdeStr.isNotEmpty) {
      return 'Plan del $desdeStr';
    }
    if (hastaStr.isNotEmpty) {
      return 'Plan del $hastaStr';
    }
    return 'Plan sin fecha';
  }

  Future<List<PlanFitEjercicio>> _getEjerciciosPlan(int codigoPlan) {
    return _ejerciciosFutures.putIfAbsent(
      codigoPlan,
      () => _apiService.getPlanFitEjercicios(codigoPlan),
    );
  }

  Widget _buildEjercicioTag({required IconData icon, required String label}) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildEjercicioCard(PlanFitEjercicio ejercicio) {
    final hasReps = (ejercicio.repeticiones ?? 0) > 0;
    final hasRest = (ejercicio.descanso ?? 0) > 0;
    final hasTime = (ejercicio.tiempo ?? 0) > 0;
    final hasInstructions =
        ejercicio.instrucciones != null && ejercicio.instrucciones!.isNotEmpty;
    final hasVideo =
        ejercicio.urlVideo != null && ejercicio.urlVideo!.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ejercicio.fotoBase64 != null && ejercicio.fotoBase64!.isNotEmpty)
            Image.memory(
              base64Decode(ejercicio.fotoBase64!),
              height: 220,
              width: double.infinity,
              fit: BoxFit.contain,
            )
          else
            Container(
              height: 220,
              width: double.infinity,
              color: Colors.grey[300],
              child: const Icon(Icons.fitness_center,
                  size: 64, color: Colors.grey),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ejercicio.nombre,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (hasReps || hasRest || hasTime)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (hasReps)
                        _buildEjercicioTag(
                          icon: Icons.repeat,
                          label: '${ejercicio.repeticiones} repeticiones',
                        ),
                      if (hasRest)
                        _buildEjercicioTag(
                          icon: Icons.pause_circle_filled,
                          label: '${ejercicio.descanso}s descanso',
                        ),
                      if (hasTime)
                        _buildEjercicioTag(
                          icon: Icons.timer,
                          label: '${ejercicio.tiempo}s tiempo',
                        ),
                    ],
                  ),
                if (hasReps || hasRest || hasTime) const SizedBox(height: 8),
                if (hasInstructions)
                  Text(
                    ejercicio.instrucciones!,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                if (hasVideo) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      try {
                        String urlString = ejercicio.urlVideo!.trim();
                        if (!urlString.startsWith('http://') &&
                            !urlString.startsWith('https://')) {
                          urlString = 'https://$urlString';
                        }
                        await launchUrl(
                          Uri.parse(urlString),
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo abrir el video.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(
                          Icons.play_circle_fill,
                          size: 18,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Cómo se hace...',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Planes Fit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _refreshPlanes,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: FutureBuilder<List<PlanFit>>(
        future: _planesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error al cargar los planes: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aún no tienes planes asignados.'));
          }

          final planes = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: planes.length,
            itemBuilder: (context, index) {
              final plan = planes[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12.0),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _buildPlanTitle(plan.desde, plan.hasta),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (plan.planIndicacionesVisibleUsuario != null &&
                          plan.planIndicacionesVisibleUsuario!.isNotEmpty) ...[
                        Text(
                          'Indicaciones:',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(plan.planIndicacionesVisibleUsuario!),
                        const SizedBox(height: 12),
                      ],
                      if (plan.url != null && plan.url!.isNotEmpty) ...[
                        InkWell(
                          onTap: () async {
                            try {
                              String urlString = plan.url!.trim();
                              // Asegurarse de que la URL tenga un esquema
                              if (!urlString.startsWith('http://') &&
                                  !urlString.startsWith('https://')) {
                                urlString = 'https://$urlString';
                              }
                              final Uri url = Uri.parse(urlString);
                              await launchUrl(url,
                                  mode: LaunchMode.externalApplication);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'No se pudo abrir la URL: ${plan.url}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Row(
                            children: [
                              const Icon(
                                Icons.open_in_browser,
                                size: 16,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Ver en el navegador web',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (plan.planDocumentoNombre != null &&
                              plan.planDocumentoNombre!.isNotEmpty)
                            ElevatedButton.icon(
                              icon: const Icon(
                                  Icons.download_for_offline_outlined),
                              label: const Text('Descargar plan'),
                              onPressed: () => _downloadAndOpenFile(
                                  plan.codigo, plan.planDocumentoNombre!),
                            ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Añadir actividad'),
                            onPressed: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          EntrenamientoEditScreen(
                                        planFitId: plan.codigo,
                                      ),
                                    ),
                                  )
                                  .then((_) => _refreshPlanes());
                            },
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.fitness_center),
                            label: Text(
                              (_mostrarEjercicios[plan.codigo] ?? false)
                                  ? 'Ocultar ejercicios'
                                  : 'Mostrar ejercicios',
                            ),
                            onPressed: () {
                              setState(() {
                                final current =
                                    _mostrarEjercicios[plan.codigo] ?? false;
                                _mostrarEjercicios[plan.codigo] = !current;
                              });
                              if ((_mostrarEjercicios[plan.codigo] ?? false) &&
                                  !_ejerciciosFutures
                                      .containsKey(plan.codigo)) {
                                _getEjerciciosPlan(plan.codigo);
                              }
                            },
                          ),
                        ],
                      ),
                      if (_mostrarEjercicios[plan.codigo] ?? false) ...[
                        const SizedBox(height: 16),
                        FutureBuilder<List<PlanFitEjercicio>>(
                          future: _getEjerciciosPlan(plan.codigo),
                          builder: (context, ejerciciosSnapshot) {
                            if (ejerciciosSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }
                            if (ejerciciosSnapshot.hasError) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Error al cargar ejercicios: ${ejerciciosSnapshot.error}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              );
                            }
                            final ejercicios =
                                ejerciciosSnapshot.data ?? <PlanFitEjercicio>[];
                            if (ejercicios.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text('Este plan no tiene ejercicios.'),
                              );
                            }
                            return Column(
                              children: ejercicios
                                  .map((e) => _buildEjercicioCard(e))
                                  .toList(),
                            );
                          },
                        ),
                      ],
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
