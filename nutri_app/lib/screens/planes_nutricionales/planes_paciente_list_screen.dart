import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/plan_nutricional.dart';
import 'package:nutri_app/services/adherencia_service.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/user_settings_service.dart';
import 'package:nutri_app/widgets/adherencia_calendar_view.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:nutri_app/widgets/adherencia_registro_bottom_sheet.dart';
import 'package:nutri_app/widgets/contact_nutricionista_dialog.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

class PlanesPacienteListScreen extends StatefulWidget {
  const PlanesPacienteListScreen({super.key});

  @override
  State<PlanesPacienteListScreen> createState() =>
      _PlanesPacienteListScreenState();
}

class _PlanesPacienteListScreenState extends State<PlanesPacienteListScreen> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');

  final ApiService _apiService = ApiService();
  final AdherenciaService _adherenciaService = AdherenciaService();
  late Future<List<PlanNutricional>> _planesFuture;
  String? _patientCode;
  String? _userCode;
  AdherenciaMetricaSemanal? _adherenciaNutri;
  bool _loadingAdherenciaNutri = false;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loadingAdherenciaCalendario = false;
  bool _hasPlanFit = false;
  String _calendarViewMode = 'month';
  Map<String, Map<AdherenciaTipo, AdherenciaEstado>> _adherenciaDias = {};

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _patientCode = authService.patientCode;
    _userCode = authService.userCode ?? authService.patientCode;

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
    _loadAdherenciaNutri();
    _loadPlanTypes();
    _loadAdherenciaCalendario();
    _loadCalendarViewMode();
  }

  DateTime _calendarRangeStart(DateTime anchor) {
    if (_calendarViewMode == 'month') {
      final monthStart = DateTime(anchor.year, anchor.month, 1);
      return monthStart.subtract(Duration(days: monthStart.weekday - 1));
    }
    final day = DateTime(anchor.year, anchor.month, anchor.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  int _calendarVisibleDays() {
    if (_calendarViewMode == 'week') return 7;
    if (_calendarViewMode == 'twoWeeks') return 14;
    return 42;
  }

  Future<void> _loadCalendarViewMode() async {
    final authService = context.read<AuthService>();
    final scope = UserSettingsService.buildScopeKey(
      isGuestMode: authService.isGuestMode,
      userCode: authService.userCode,
      patientCode: authService.patientCode,
      userType: authService.userType,
    );
    final mode = await UserSettingsService.getNutriAdherenceCalendarViewMode(
      scope,
    );
    if (!mounted) return;
    setState(() {
      _calendarViewMode = mode;
    });
    _loadAdherenciaCalendario();
  }

  String _dayKey(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  AdherenciaEstado? _parseEstado(dynamic raw) {
    final normalized = (raw ?? '').toString().trim().toLowerCase();
    if (normalized == 'cumplido') return AdherenciaEstado.cumplido;
    if (normalized == 'parcial') return AdherenciaEstado.parcial;
    if (normalized == 'no') return AdherenciaEstado.noRealizado;
    return null;
  }

  Future<void> _loadPlanTypes() async {
    final patientCode = _patientCode;
    if (patientCode == null || patientCode.isEmpty) return;
    final patientId = int.tryParse(patientCode);
    if (patientId == null) return;

    try {
      final planesFit = await _apiService.getPlanesFit(patientId);
      if (!mounted) return;
      setState(() {
        _hasPlanFit = planesFit.isNotEmpty;
      });
    } catch (_) {}
  }

  Future<void> _loadAdherenciaCalendario() async {
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty) return;

    final gridStart = _calendarRangeStart(_calendarMonth);
    final gridEnd = gridStart.add(Duration(days: _calendarVisibleDays() - 1));

    if (!mounted) return;
    setState(() {
      _loadingAdherenciaCalendario = true;
    });

    try {
      final records = await _apiService.getAdherenciaRegistros(
        fechaDesde: gridStart,
        fechaHasta: gridEnd,
      );
      final byDay = <String, Map<AdherenciaTipo, AdherenciaEstado>>{};

      for (final row in records) {
        final fechaRaw = (row['fecha'] ?? '').toString();
        if (fechaRaw.length < 10) continue;
        final key = fechaRaw.substring(0, 10);
        final tipoRaw = (row['tipo'] ?? '').toString().trim().toLowerCase();
        final estado = _parseEstado(row['estado']);
        if (estado == null) continue;

        final tipo = tipoRaw == 'fit'
            ? AdherenciaTipo.fit
            : tipoRaw == 'nutri'
                ? AdherenciaTipo.nutri
                : null;
        if (tipo == null) continue;

        final current = byDay[key] ?? <AdherenciaTipo, AdherenciaEstado>{};
        current[tipo] = estado;
        byDay[key] = current;
      }

      if (!mounted) return;
      setState(() {
        _adherenciaDias = byDay;
        _loadingAdherenciaCalendario = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _adherenciaDias = {};
        _loadingAdherenciaCalendario = false;
      });
    }
  }

  Future<void> _onCalendarDayTap(DateTime day) async {
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty) return;

    final estadosDia = _adherenciaDias[_dayKey(day)] ?? const {};
    final tipos = <AdherenciaTipo>[
      AdherenciaTipo.nutri,
      if (_hasPlanFit) AdherenciaTipo.fit,
    ];

    await showAdherenciaRegistroBottomSheet(
      context: context,
      userCode: userCode,
      tiposDisponibles: tipos,
      fechaObjetivo: day,
      solicitarMotivoEnIncumplimiento: true,
      estadoHoyInicial: {
        AdherenciaTipo.nutri: estadosDia[AdherenciaTipo.nutri],
        if (_hasPlanFit) AdherenciaTipo.fit: estadosDia[AdherenciaTipo.fit],
      },
      onSaved: () async {
        await _loadAdherenciaNutri();
        await _loadAdherenciaCalendario();
      },
    );
  }

  Widget _buildCalendarTab() {
    if (_loadingAdherenciaCalendario) {
      return const Center(child: CircularProgressIndicator());
    }

    return AdherenciaCalendarView(
      month: _calendarMonth,
      calendarViewMode: _calendarViewMode,
      onMonthChanged: (newMonth) {
        setState(() {
          _calendarMonth = newMonth;
        });
        _loadAdherenciaCalendario();
      },
      estadosPorDia: _adherenciaDias,
      showNutri: true,
      showFit: _hasPlanFit,
      onDayTap: _onCalendarDayTap,
    );
  }

  Future<void> _loadAdherenciaNutri() async {
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty) {
      if (!mounted) return;
      setState(() {
        _adherenciaNutri = null;
        _loadingAdherenciaNutri = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _loadingAdherenciaNutri = true;
    });

    final resumen = await _adherenciaService.getResumenSemanal(
      userCode: userCode,
      incluirNutri: true,
      incluirFit: false,
    );

    if (!mounted) return;
    setState(() {
      _adherenciaNutri = resumen.nutri;
      _loadingAdherenciaNutri = false;
    });
  }

  Color _adherenciaColorByPercent(int percent) {
    if (percent >= 75) return Colors.green;
    if (percent >= 50) return Colors.orange;
    return Colors.red;
  }

  Widget _buildCumplimientoCircle({
    required int percent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: (percent.clamp(0, 100)) / 100,
              strokeWidth: 4,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                _adherenciaColorByPercent(percent),
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdherenciaRegistroRapidoNutri() async {
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty) return;

    await showAdherenciaRegistroBottomSheet(
      context: context,
      userCode: userCode,
      tiposDisponibles: const [AdherenciaTipo.nutri],
      tipoInicial: AdherenciaTipo.nutri,
      solicitarMotivoEnIncumplimiento: true,
      estadoHoyInicial: {
        AdherenciaTipo.nutri: _adherenciaNutri?.estadoHoy,
      },
      onSaved: _loadAdherenciaNutri,
    );
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
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.description_outlined)),
                Tab(icon: Icon(Icons.calendar_month_outlined)),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  FutureBuilder<List<PlanNutricional>>(
                    future: _planesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                            child: Text(
                                'Error al cargar los planes: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                            child: Text('Aún no tienes planes asignados.'));
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
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text(
                                        'Cumplimiento',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(width: 8),
                                      _loadingAdherenciaNutri
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : _buildCumplimientoCircle(
                                              percent: _adherenciaNutri
                                                      ?.porcentaje ??
                                                  0,
                                              onTap:
                                                  _showAdherenciaRegistroRapidoNutri,
                                            ),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed:
                                            _showAdherenciaRegistroRapidoNutri,
                                        icon: const Icon(
                                            Icons.edit_calendar_outlined,
                                            size: 18),
                                        label: const Text('Registrar hoy'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Semanas (recuadro ancho)
                                  if (plan.semanas != null &&
                                      plan.semanas!.isNotEmpty)
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
                                          const Icon(Icons.calendar_today,
                                              size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child:
                                                Text('${plan.semanas} semanas'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (plan.semanas != null &&
                                      plan.semanas!.isNotEmpty)
                                    const SizedBox(height: 12),

                                  // Indicaciones (recuadro amarillo, sin label)
                                  if (plan.planIndicacionesVisibleUsuario !=
                                          null &&
                                      plan.planIndicacionesVisibleUsuario!
                                          .isNotEmpty) ...[
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],

                                  // Botones (URL + descarga en la misma linea)
                                  if ((plan.url != null &&
                                          plan.url!.isNotEmpty) ||
                                      (plan.planDocumentoNombre != null &&
                                          plan.planDocumentoNombre!.isNotEmpty))
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12.0),
                                      child: Row(
                                        children: [
                                          if (plan.url != null &&
                                              plan.url!.isNotEmpty)
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () =>
                                                    _launchUrlExternal(
                                                        plan.url ?? ''),
                                                icon: const Icon(
                                                    Icons.open_in_browser),
                                                label: const Text('Web'),
                                              ),
                                            ),
                                          if (plan.url != null &&
                                              plan.url!.isNotEmpty)
                                            const SizedBox(width: 12),
                                          if (plan.planDocumentoNombre !=
                                                  null &&
                                              plan.planDocumentoNombre!
                                                  .isNotEmpty)
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                icon: const Icon(
                                                  Icons
                                                      .download_for_offline_outlined,
                                                ),
                                                label: const Text('Descargar'),
                                                onPressed: () =>
                                                    _downloadAndOpenFile(
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
                  _buildCalendarTab(),
                ],
              ),
            ),
          ],
        ),
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
          const SnackBar(
            content: Text('No se pudo abrir el enlace'),
          ),
        );
      }
    }
  }
}
