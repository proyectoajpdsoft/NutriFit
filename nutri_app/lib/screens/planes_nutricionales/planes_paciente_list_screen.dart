import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/plan_nutricional.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:nutri_app/widgets/contact_nutricionista_dialog.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
// import 'package:url_launcher/url_launcher.dart';

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

                      // Botones (URL + descarga en la misma linea)
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
                                    onPressed:
                                        null, // () => _launchUrlExternal(plan.url ?? ''),
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

  // Future<void> _launchUrlExternal(String url) async {
  //   final trimmed = url.trim();
  //   if (trimmed.isEmpty) return;
  //   Uri? uri = Uri.tryParse(trimmed);
  //   if (uri == null) return;
  //   if (uri.scheme.isEmpty) {
  //     uri = Uri.tryParse('https://$trimmed');
  //   }
  //   if (uri == null) return;
  //   final launched = await launchUrl(
  //     uri,
  //     mode: LaunchMode.externalApplication,
  //   );
  //   if (!launched && mounted) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('No se pudo abrir el enlace'),
  //       ),
  //     );
  //   }
  // }
}
