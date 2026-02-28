import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/plan_fit.dart';
import 'package:nutri_app/models/plan_fit_ejercicio.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:nutri_app/widgets/contact_nutricionista_dialog.dart';
import 'package:nutri_app/widgets/image_viewer_dialog.dart';
import 'package:nutri_app/screens/entrenamiento_edit_screen.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

class PlanesFitPacienteListScreen extends StatefulWidget {
  const PlanesFitPacienteListScreen({super.key});

  @override
  State<PlanesFitPacienteListScreen> createState() =>
      _PlanesFitPacienteListScreenState();
}

class _PlanesFitPacienteListScreenState
    extends State<PlanesFitPacienteListScreen> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');

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
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al descargar plan. $errorMessage'),
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

  Widget _buildMetaTag({required IconData icon, required String label}) {
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ejercicio.fotoMiniatura != null &&
              ejercicio.fotoMiniatura!.isNotEmpty)
            InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => ImageViewerDialog(
                    base64Image: ejercicio.fotoMiniatura!,
                    title: ejercicio.nombre,
                  ),
                );
              },
              child: Image.memory(
                base64Decode(ejercicio.fotoMiniatura!),
                height: 80,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 80,
              width: double.infinity,
              color: Colors.grey[300],
              child: const Icon(Icons.fitness_center,
                  size: 32, color: Colors.grey),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ejercicio.nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                if (hasReps)
                  Row(
                    children: [
                      const Icon(Icons.repeat, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${ejercicio.repeticiones} reps',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                if (hasRest)
                  Row(
                    children: [
                      const Icon(Icons.pause_circle_filled, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${ejercicio.descanso}s',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                if (hasTime)
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${ejercicio.tiempo}s',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                if (hasInstructions) ...[
                  const SizedBox(height: 4),
                  Text(
                    ejercicio.instrucciones!,
                    style: TextStyle(color: Colors.grey[700], fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (hasVideo) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _launchUrlExternal(ejercicio.urlVideo ?? ''),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_circle_fill,
                          size: 14,
                          color: Colors.blue,
                        ),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Ver video',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
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
                      // Título del plan
                      Text(
                        _buildPlanTitle(plan.desde, plan.hasta),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      // Semanas (recuadro ancho)
                      if (plan.semanas != null && plan.semanas!.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue[200]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('${plan.semanas} semanas'),
                              ),
                            ],
                          ),
                        ),
                      if (plan.semanas != null && plan.semanas!.isNotEmpty)
                        const SizedBox(height: 12),

                      // Indicaciones (recuadro amarillo, sin label)
                      if (plan.planIndicacionesVisibleUsuario != null &&
                          plan.planIndicacionesVisibleUsuario!.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Colors.amber[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.amber[300]!,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            plan.planIndicacionesVisibleUsuario!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Botones URL + descarga (misma linea)
                      if ((plan.url != null && plan.url!.isNotEmpty) ||
                          (plan.planDocumentoNombre != null &&
                              plan.planDocumentoNombre!.isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              if (plan.url != null && plan.url!.isNotEmpty)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _launchUrlExternal(plan.url ?? ''),
                                    icon: const Icon(Icons.open_in_browser),
                                    label: const Text('Web'),
                                  ),
                                ),
                              if (plan.url != null && plan.url!.isNotEmpty)
                                const SizedBox(width: 12),
                              if (plan.planDocumentoNombre != null &&
                                  plan.planDocumentoNombre!.isNotEmpty)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.download_for_offline_outlined,
                                    ),
                                    label: const Text('Descargar'),
                                    onPressed: () => _downloadAndOpenFile(
                                      plan.codigo,
                                      plan.planDocumentoNombre!,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                      // Botones de accion
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Actividad'),
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
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.fitness_center),
                              label: const Text('Ejercicios'),
                              onPressed: () {
                                setState(() {
                                  final current =
                                      _mostrarEjercicios[plan.codigo] ?? false;
                                  _mostrarEjercicios[plan.codigo] = !current;
                                });
                                if ((_mostrarEjercicios[plan.codigo] ??
                                        false) &&
                                    !_ejerciciosFutures
                                        .containsKey(plan.codigo)) {
                                  _getEjerciciosPlan(plan.codigo);
                                }
                              },
                            ),
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
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 4.0),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.65,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: ejercicios.length,
                                itemBuilder: (context, index) {
                                  return _buildEjercicioCard(ejercicios[index]);
                                },
                              ),
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

  Future<void> _launchUrlExternal(String url) async {
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        await _externalUrlChannel.invokeMethod('openUrl', {'url': url});
        return;
      }
      rethrow;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir el enlace: $url'),
          ),
        );
      }
    }
  }
}
