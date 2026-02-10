import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/plan_nutricional.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:nutri_app/widgets/contact_nutricionista_dialog.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class PlanesPacienteListScreen extends StatefulWidget {
  const PlanesPacienteListScreen({super.key});

  @override
  State<PlanesPacienteListScreen> createState() =>
      _PlanesPacienteListScreenState();
}

class _PlanesPacienteListScreenState extends State<PlanesPacienteListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<PlanNutricional>> _planesFuture;
  String? _patientCode;

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
          _planesFuture = _apiService.getPlanes(patientId);
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
      final filePath = await _apiService.downloadPlan(codigo, fileName);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Planes Nutri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _refreshPlanes,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: FutureBuilder<List<PlanNutricional>>(
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
                      if (plan.planDocumentoNombre != null &&
                          plan.planDocumentoNombre!.isNotEmpty)
                        Center(
                          child: ElevatedButton.icon(
                            icon:
                                const Icon(Icons.download_for_offline_outlined),
                            label: const Text('Descargar plan'),
                            onPressed: () => _downloadAndOpenFile(
                                plan.codigo, plan.planDocumentoNombre!),
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
