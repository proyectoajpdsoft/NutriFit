import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/plan_fit.dart';
import 'package:nutri_app/models/plan_fit_dia.dart';
import 'package:nutri_app/models/plan_fit_ejercicio.dart';
import 'package:nutri_app/services/adherencia_service.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/user_settings_service.dart';
import 'package:nutri_app/services/plan_fit_pdf_service.dart';
import 'package:nutri_app/widgets/adherencia_calendar_view.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:nutri_app/widgets/adherencia_registro_bottom_sheet.dart';
import 'package:nutri_app/widgets/contact_nutricionista_dialog.dart';
import 'package:nutri_app/widgets/image_viewer_dialog.dart';
import 'package:nutri_app/screens/entrenamiento_edit_screen.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';

class _PlanFitPdfOptions {
  final bool fichaPorDias;
  final bool showMiniThumbs;
  final bool showConsejos;
  final bool showRecomendaciones;

  const _PlanFitPdfOptions({
    required this.fichaPorDias,
    required this.showMiniThumbs,
    required this.showConsejos,
    required this.showRecomendaciones,
  });
}

class PlanesFitPacienteListScreen extends StatefulWidget {
  const PlanesFitPacienteListScreen({super.key});

  @override
  State<PlanesFitPacienteListScreen> createState() =>
      _PlanesFitPacienteListScreenState();
}

class _PlanesFitPacienteListScreenState
    extends State<PlanesFitPacienteListScreen> {
  static const MethodChannel _externalUrlChannel = MethodChannel(
    'nutri_app/external_url',
  );
  static const _pdfFullPrefix = 'plan_fit_pdf_full';
  static const _pdfResumenPrefix = 'plan_fit_pdf_resumen';

  final ApiService _apiService = ApiService();
  final AdherenciaService _adherenciaService = AdherenciaService();
  late Future<List<PlanFit>> _planesFuture;
  String? _patientCode;
  String? _userCode;
  AdherenciaMetricaSemanal? _adherenciaFit;
  bool _loadingAdherenciaFit = false;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loadingAdherenciaCalendario = false;
  bool _hasPlanNutri = false;
  String _calendarViewMode = 'month';
  Map<String, Map<AdherenciaTipo, AdherenciaEstado>> _adherenciaDias = {};
  final Map<int, bool> _mostrarEjercicios = {};
  final Map<int, Future<List<PlanFitEjercicio>>> _ejerciciosFutures = {};
  final Map<int, Future<List<PlanFitDia>>> _diasFutures = {};
  final Map<String, bool> _diasExpandidos = {};

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
    _loadAdherenciaFit();
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
    final mode = await UserSettingsService.getFitAdherenceCalendarViewMode(
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
      final planesNutri = await _apiService.getPlanes(patientId);
      if (!mounted) return;
      setState(() {
        _hasPlanNutri = planesNutri.isNotEmpty;
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

  String _shortInstructionText(String text, {int maxChars = 45}) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars)}...';
  }

  Future<void> _onCalendarDayTap(DateTime day) async {
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty) return;

    final estadosDia = _adherenciaDias[_dayKey(day)] ?? const {};
    final tipos = <AdherenciaTipo>[
      if (_hasPlanNutri) AdherenciaTipo.nutri,
      AdherenciaTipo.fit,
    ];

    await showAdherenciaRegistroBottomSheet(
      context: context,
      userCode: userCode,
      tiposDisponibles: tipos,
      fechaObjetivo: day,
      solicitarMotivoEnIncumplimiento: true,
      estadoHoyInicial: {
        if (_hasPlanNutri)
          AdherenciaTipo.nutri: estadosDia[AdherenciaTipo.nutri],
        AdherenciaTipo.fit: estadosDia[AdherenciaTipo.fit],
      },
      onSaved: () async {
        await _loadAdherenciaFit();
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
      showNutri: _hasPlanNutri,
      showFit: true,
      onDayTap: _onCalendarDayTap,
    );
  }

  Future<void> _loadAdherenciaFit() async {
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty) {
      if (!mounted) return;
      setState(() {
        _adherenciaFit = null;
        _loadingAdherenciaFit = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _loadingAdherenciaFit = true;
    });

    final resumen = await _adherenciaService.getResumenSemanal(
      userCode: userCode,
      incluirNutri: false,
      incluirFit: true,
    );

    if (!mounted) return;
    setState(() {
      _adherenciaFit = resumen.fit;
      _loadingAdherenciaFit = false;
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
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdherenciaRegistroRapidoFit() async {
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty) return;

    await showAdherenciaRegistroBottomSheet(
      context: context,
      userCode: userCode,
      tiposDisponibles: const [AdherenciaTipo.fit],
      tipoInicial: AdherenciaTipo.fit,
      solicitarMotivoEnIncumplimiento: true,
      estadoHoyInicial: {AdherenciaTipo.fit: _adherenciaFit?.estadoHoy},
      onSaved: _loadAdherenciaFit,
    );
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Descargando $fileName...')));
    try {
      final filePath = await _apiService.downloadPlanFit(codigo, fileName);
      if (filePath != null) {
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo abrir el fichero: ${result.message}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al descargar plan. $errorMessage'),
          backgroundColor: Colors.red,
        ),
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

  String _buildPdfFileName(PlanFit plan) {
    final pacienteNombre = (plan.nombrePaciente ?? '').trim();
    final primeraPalabra = pacienteNombre.isNotEmpty
        ? pacienteNombre.split(' ').first
        : (_patientCode?.isNotEmpty == true
            ? 'Paciente_$_patientCode'
            : 'Paciente');
    final semanas = (plan.semanas ?? 'SinSemanas').replaceAll(' ', '');
    final desdeStr = plan.desde != null
        ? DateFormat('dd-MM-yyyy').format(plan.desde!)
        : 'SinFecha';
    final hastaStr = plan.hasta != null
        ? DateFormat('dd-MM-yyyy').format(plan.hasta!)
        : 'SinFecha';
    return 'PlanFit_${primeraPalabra}_${semanas}_Del_${desdeStr}_al_$hastaStr.pdf';
  }

  Future<_PlanFitPdfOptions?> _showPlanFitPdfOptionsDialog({
    required bool showFichaOptions,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final modePrefix = showFichaOptions ? _pdfFullPrefix : _pdfResumenPrefix;
    String key(String suffix) => '${modePrefix}_$suffix';

    var fichaPorDias = prefs.getBool(key('ficha_por_dias')) ?? true;
    var showMiniThumbs = prefs.getBool(key('show_mini_thumbs')) ?? false;
    var showConsejos = prefs.getBool(key('show_consejos')) ?? true;
    var showRecomendaciones =
        prefs.getBool(key('show_recomendaciones')) ?? true;

    return showDialog<_PlanFitPdfOptions>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Opciones del PDF'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showFichaOptions) ...[
                    RadioListTile<bool>(
                      value: true,
                      groupValue: fichaPorDias,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => fichaPorDias = value);
                      },
                      title: const Text('Ficha por días'),
                    ),
                    RadioListTile<bool>(
                      value: false,
                      groupValue: fichaPorDias,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => fichaPorDias = value);
                      },
                      title: const Text('Ficha únicos'),
                    ),
                  ],
                  SwitchListTile(
                    value: showMiniThumbs,
                    onChanged: (value) {
                      setState(() => showMiniThumbs = value);
                    },
                    title: const Text('Mostrar miniatura'),
                  ),
                  SwitchListTile(
                    value: showConsejos,
                    onChanged: (value) {
                      setState(() => showConsejos = value);
                    },
                    title: const Text('Mostrar consejos'),
                  ),
                  SwitchListTile(
                    value: showRecomendaciones,
                    onChanged: (value) {
                      setState(() => showRecomendaciones = value);
                    },
                    title: const Text('Mostrar recomendaciones'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    prefs.setBool(key('ficha_por_dias'), fichaPorDias);
                    prefs.setBool(key('show_mini_thumbs'), showMiniThumbs);
                    prefs.setBool(key('show_consejos'), showConsejos);
                    prefs.setBool(
                      key('show_recomendaciones'),
                      showRecomendaciones,
                    );
                    Navigator.of(dialogContext).pop(
                      _PlanFitPdfOptions(
                        fichaPorDias: fichaPorDias,
                        showMiniThumbs: showMiniThumbs,
                        showConsejos: showConsejos,
                        showRecomendaciones: showRecomendaciones,
                      ),
                    );
                  },
                  child: const Text('Generar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generatePlanFitPdf(PlanFit plan) async {
    final options = await _showPlanFitPdfOptionsDialog(showFichaOptions: true);
    if (options == null) return;

    await PlanFitPdfService.generatePlanFitPdf(
      context: context,
      apiService: _apiService,
      plan: plan,
      fileName: _buildPdfFileName(plan),
      fichaPorDias: options.fichaPorDias,
      showMiniThumbs: options.showMiniThumbs,
      showConsejos: options.showConsejos,
      showRecomendaciones: options.showRecomendaciones,
    );
  }

  Future<void> _generatePlanFitPdfResumen(PlanFit plan) async {
    final options = await _showPlanFitPdfOptionsDialog(showFichaOptions: false);
    if (options == null) return;

    await PlanFitPdfService.generatePlanFitPdf(
      context: context,
      apiService: _apiService,
      plan: plan,
      fileName: _buildPdfFileName(plan),
      resumen: true,
      showMiniThumbs: options.showMiniThumbs,
      showConsejos: options.showConsejos,
      showRecomendaciones: options.showRecomendaciones,
    );
  }

  Future<List<PlanFitEjercicio>> _getEjerciciosPlan(int codigoPlan) {
    return _ejerciciosFutures.putIfAbsent(
      codigoPlan,
      () => _apiService.getPlanFitEjercicios(codigoPlan),
    );
  }

  Future<List<PlanFitDia>> _getDiasPlan(int codigoPlan) {
    return _diasFutures.putIfAbsent(
      codigoPlan,
      () => _apiService.getDiasPlanFit(codigoPlan),
    );
  }

  String _buildDiaNombre(PlanFitDia dia) {
    final titulo = (dia.titulo ?? '').trim();
    if (titulo.isNotEmpty) {
      return titulo;
    }
    return 'Día ${dia.numeroDia}';
  }

  Uint8List? _tryDecodeBase64Image(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  // ignore: unused_element
  Widget _buildMetaTag({required IconData icon, required String label}) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  List<String> _extractInstructionTags(String rawText) {
    final normalized = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('•', '\n')
        .replaceAll('·', '\n');

    List<String> parts = normalized
        .split(RegExp(r'\n|;'))
        .map(
          (part) =>
              part.trim().replaceFirst(RegExp(r'^[-*\d\s.)]+'), '').trim(),
        )
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.length <= 1) {
      parts = normalized
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map(
            (part) =>
                part.trim().replaceFirst(RegExp(r'^[-*\d\s.)]+'), '').trim(),
          )
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
    }

    if (parts.isEmpty && normalized.trim().isNotEmpty) {
      return <String>[normalized.trim()];
    }

    return parts;
  }

  Widget _buildPremiumMetricCard({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[color.withValues(alpha: 0.16), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
              color: color.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortInstructionCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF5D8A6)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5F4A24),
        ),
      ),
    );
  }

  Widget _buildInstructionTag(String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE0E5F2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          height: 1.25,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showEjercicioImage(PlanFitEjercicio ejercicio) {
    final imageBase64 = (ejercicio.fotoBase64 ?? '').trim().isNotEmpty
        ? ejercicio.fotoBase64!.trim()
        : (ejercicio.fotoMiniatura ?? '').trim();
    if (imageBase64.isEmpty) return;

    showImageViewerDialog(
      context: context,
      base64Image: imageBase64,
      title: ejercicio.nombre,
    );
  }

  Future<String> _buildNutriFitClipboardSignature() async {
    try {
      final param = await _apiService.getParametro('nutricionista_nombre');
      final nutricionistaNombre = (param?['valor'] ?? '').toString().trim();
      if (nutricionistaNombre.isNotEmpty) {
        return 'App NutriFit $nutricionistaNombre';
      }
    } catch (_) {}
    return 'App NutriFit';
  }

  Future<void> _copyHowToText(String rawText) async {
    final normalized = rawText.trim();
    if (normalized.isEmpty) return;
    final signature = await _buildNutriFitClipboardSignature();
    await Clipboard.setData(
      ClipboardData(text: '$normalized\n\n$signature'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Texto copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showEjercicioDetailDialog(PlanFitEjercicio ejercicio) async {
    PlanFitEjercicio? catalogDetalle;
    final codigoCatalogo = ejercicio.codigoEjercicioCatalogo;
    if (codigoCatalogo != null && codigoCatalogo > 0) {
      try {
        catalogDetalle = await _apiService
            .getPlanFitEjercicioCatalogWithFoto(codigoCatalogo);
      } catch (_) {}
    }

    final shortInstructions = (ejercicio.instrucciones ?? '').trim().isNotEmpty
        ? (ejercicio.instrucciones ?? '').trim()
        : (catalogDetalle?.instrucciones ?? '').trim();
    final detailedInstructions =
        (ejercicio.instruccionesDetalladas ?? '').trim().isNotEmpty
            ? (ejercicio.instruccionesDetalladas ?? '').trim()
            : (catalogDetalle?.instruccionesDetalladas ?? '').trim();
    final instructionTags = _extractInstructionTags(detailedInstructions);
    final hasDetailedInstructions = detailedInstructions.isNotEmpty;
    final hasVideo =
        ejercicio.urlVideo != null && ejercicio.urlVideo!.trim().isNotEmpty;

    const coverSubtitleMaxChars = 50;
    final coverSubtitle = shortInstructions.isNotEmpty
        ? (shortInstructions.length > coverSubtitleMaxChars
            ? '${shortInstructions.substring(0, coverSubtitleMaxChars)}...'
            : shortInstructions)
        : 'Movimiento premium listo para incorporar a tu rutina.';
    final showReadMoreLink = shortInstructions.length > coverSubtitleMaxChars &&
        (hasDetailedInstructions || shortInstructions.isNotEmpty);

    final imageBase64 = (catalogDetalle?.fotoBase64 ?? '').trim().isNotEmpty
        ? (catalogDetalle?.fotoBase64 ?? '').trim()
        : (ejercicio.fotoBase64 ?? '').trim().isNotEmpty
            ? (ejercicio.fotoBase64 ?? '').trim()
            : (catalogDetalle?.fotoMiniatura ?? '').trim().isNotEmpty
                ? (catalogDetalle?.fotoMiniatura ?? '').trim()
                : (ejercicio.fotoMiniatura ?? '').trim();
    final hasImage = imageBase64.isNotEmpty;

    final metricCards = <Widget>[
      if ((ejercicio.tiempo ?? 0) > 0)
        _buildPremiumMetricCard(
          icon: Icons.schedule_rounded,
          value: '${ejercicio.tiempo}s',
          color: const Color(0xFFFF8A3D),
        ),
      if ((ejercicio.repeticiones ?? 0) > 0)
        _buildPremiumMetricCard(
          icon: Icons.repeat_rounded,
          value: '${ejercicio.repeticiones}',
          color: const Color(0xFF4F7CFF),
        ),
      if ((ejercicio.kilos ?? 0) > 0)
        _buildPremiumMetricCard(
          icon: Icons.fitness_center_rounded,
          value: '${ejercicio.kilos} kg',
          color: const Color(0xFF13A57A),
        ),
      if ((ejercicio.descanso ?? 0) > 0)
        _buildPremiumMetricCard(
          icon: Icons.airline_seat_individual_suite_rounded,
          value: '${ejercicio.descanso}s',
          color: const Color(0xFF8E59FF),
        ),
    ];

    showDialog<void>(
      context: context,
      builder: (context) {
        bool expandHowTo = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 760, maxHeight: 860),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFFFFFCF7), Color(0xFFF5F8FF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x2A000000),
                        blurRadius: 30,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            height: hasImage ? 250 : 160,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  Color(0xFFFFB06A),
                                  Color(0xFFFFDFA5),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: hasImage
                                  ? () => showImageViewerDialog(
                                        context: context,
                                        base64Image: imageBase64,
                                        title: ejercicio.nombre,
                                      )
                                  : null,
                              child: Stack(
                                fit: StackFit.expand,
                                children: <Widget>[
                                  if (hasImage)
                                    Opacity(
                                      opacity: 0.24,
                                      child: Image.memory(
                                        base64Decode(imageBase64),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: <Color>[
                                          Colors.black.withValues(alpha: 0.05),
                                          Colors.black.withValues(alpha: 0.22),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 14,
                                    right: 14,
                                    child: IconButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.22),
                                      ),
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                      ),
                                      tooltip: 'Cerrar',
                                    ),
                                  ),
                                  if (hasImage)
                                    Positioned(
                                      top: 16,
                                      left: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.22),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.28),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Icon(
                                              Icons.zoom_in,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Toca para ampliar',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    left: 22,
                                    right: 22,
                                    bottom: 22,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          ejercicio.nombre,
                                          style: const TextStyle(
                                            color: Color(0xFF2E1D12),
                                            fontSize: 21,
                                            height: 1.1,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        RichText(
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          text: TextSpan(
                                            style: TextStyle(
                                              color: const Color(0xFF4A321E)
                                                  .withValues(alpha: 0.95),
                                              fontSize: 14,
                                              height: 1.35,
                                            ),
                                            children: [
                                              TextSpan(text: coverSubtitle),
                                              if (showReadMoreLink)
                                                WidgetSpan(
                                                  alignment:
                                                      PlaceholderAlignment
                                                          .baseline,
                                                  baseline:
                                                      TextBaseline.alphabetic,
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setStateDialog(() {
                                                        expandHowTo = true;
                                                      });
                                                    },
                                                    child: Text(
                                                      ' Leer más',
                                                      style: const TextStyle(
                                                        color:
                                                            Color(0xFF2F2014),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                      ),
                                                    ),
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
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                if (metricCards.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: metricCards,
                                  ),
                                if (hasDetailedInstructions ||
                                    shortInstructions.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 16),
                                  Card(
                                    margin: EdgeInsets.zero,
                                    elevation: 0,
                                    color: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(22),
                                        gradient: const LinearGradient(
                                          colors: <Color>[
                                            Color(0xFFEAF2FF),
                                            Color(0xFFF4F8FF),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFBFD3FF),
                                        ),
                                        boxShadow: const <BoxShadow>[
                                          BoxShadow(
                                            color: Color(0x16000000),
                                            blurRadius: 14,
                                            offset: Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          dividerColor: Colors.transparent,
                                        ),
                                        child: ExpansionTile(
                                          key: ValueKey<bool>(expandHowTo),
                                          initiallyExpanded: expandHowTo,
                                          onExpansionChanged: (expanded) {
                                            setStateDialog(() {
                                              expandHowTo = expanded;
                                            });
                                          },
                                          tilePadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 6,
                                          ),
                                          leading: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4F7CFF)
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.auto_awesome_rounded,
                                              size: 18,
                                              color: Color(0xFF2F5FE5),
                                            ),
                                          ),
                                          childrenPadding:
                                              const EdgeInsets.fromLTRB(
                                            18,
                                            0,
                                            18,
                                            18,
                                          ),
                                          title: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onLongPress: () => _copyHowToText(
                                              hasDetailedInstructions
                                                  ? detailedInstructions
                                                  : shortInstructions,
                                            ),
                                            child: const Text(
                                              'Cómo se hace...',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF1D3266),
                                              ),
                                            ),
                                          ),
                                          children: <Widget>[
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: [
                                                if (shortInstructions
                                                    .isNotEmpty)
                                                  _buildShortInstructionCard(
                                                    shortInstructions,
                                                  ),
                                                ...instructionTags
                                                    .map(_buildInstructionTag)
                                                    .toList(growable: false),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.amber.shade300,
                                    ),
                                  ),
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'Aviso importante... ',
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const TextSpan(
                                          text:
                                              'Antes de realizar este ejercicio, contacta con tu entrenador, para que te guie y lo personalice acorde a tus necesidades.',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) =>
                                            const ContactNutricionistaDialog(),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.support_agent,
                                      size: 18,
                                    ),
                                    label:
                                        const Text('Contactar con entrenador'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.orange.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                if (hasVideo) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _launchUrlExternal(
                                        ejercicio.urlVideo ?? '',
                                      ),
                                      icon: const Icon(
                                        Icons.play_circle_fill,
                                        size: 18,
                                      ),
                                      label: const Text('Ver vídeo'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue.shade700,
                                        side: BorderSide(
                                          color: Colors.blue.shade300,
                                        ),
                                        backgroundColor: Colors.blue.shade50,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEjercicioCard(PlanFitEjercicio ejercicio) {
    final hasReps = (ejercicio.repeticiones ?? 0) > 0;
    final hasRest = (ejercicio.descanso ?? 0) > 0;
    final hasTime = (ejercicio.tiempo ?? 0) > 0;
    final hasKilos = (ejercicio.kilos ?? 0) > 0;
    final hasInstructions =
        ejercicio.instrucciones != null && ejercicio.instrucciones!.isNotEmpty;
    final hasVideo =
        ejercicio.urlVideo != null && ejercicio.urlVideo!.trim().isNotEmpty;

    final thumbnailBytes = _tryDecodeBase64Image(ejercicio.fotoMiniatura);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showEjercicioDetailDialog(ejercicio),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (thumbnailBytes != null)
              Container(
                height: 100,
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                color: Colors.grey[100],
                child: Image.memory(
                  thumbnailBytes,
                  width: double.infinity,
                  height: 92,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 92,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.broken_image,
                      size: 32,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 100,
                width: double.infinity,
                color: Colors.grey[300],
                child: const Icon(
                  Icons.fitness_center,
                  size: 32,
                  color: Colors.grey,
                ),
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
                  if (hasKilos)
                    Row(
                      children: [
                        const Icon(Icons.fitness_center, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${ejercicio.kilos} kg',
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
      ),
    );
  }

  Widget _buildEjerciciosPorDias(
    PlanFit plan,
    List<PlanFitDia> dias,
    List<PlanFitEjercicio> ejercicios,
  ) {
    final diasOrdenados = [...dias]..sort((a, b) {
        final ordenA = a.orden ?? a.numeroDia;
        final ordenB = b.orden ?? b.numeroDia;
        return ordenA.compareTo(ordenB);
      });

    final ejerciciosPorDia = <int, List<PlanFitEjercicio>>{};
    for (final ejercicio in ejercicios) {
      final codigoDia = ejercicio.codigoDia;
      if (codigoDia == null) continue;
      ejerciciosPorDia.putIfAbsent(codigoDia, () => <PlanFitEjercicio>[]);
      ejerciciosPorDia[codigoDia]!.add(ejercicio);
    }

    for (final entry in ejerciciosPorDia.entries) {
      entry.value.sort((a, b) {
        final ordenA = a.orden ?? 0;
        final ordenB = b.orden ?? 0;
        if (ordenA == ordenB) {
          return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
        }
        return ordenA.compareTo(ordenB);
      });
    }

    return Column(
      children: diasOrdenados.map((dia) {
        final key = '${plan.codigo}_${dia.codigo}';
        final expanded = _diasExpandidos[key] ?? false;
        final ejerciciosDia = ejerciciosPorDia[dia.codigo] ?? [];
        final ejerciciosCount = ejerciciosDia.length;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            key: PageStorageKey<String>(key),
            initiallyExpanded: expanded,
            onExpansionChanged: (value) {
              setState(() {
                _diasExpandidos[key] = value;
              });
            },
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    _buildDiaNombre(dia),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2F6BFF),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$ejerciciosCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            childrenPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            children: ejerciciosDia.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('Sin ejercicios en este día.'),
                    ),
                  ]
                : [
                    _buildEjerciciosTwoColumns(ejerciciosDia),
                  ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEjerciciosSinDias(List<PlanFitEjercicio> ejercicios) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: _buildEjerciciosTwoColumns(ejercicios),
    );
  }

  Widget _buildEjerciciosTwoColumns(List<PlanFitEjercicio> ejercicios) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        const minCardWidth = 165.0;
        final columns =
            ((constraints.maxWidth + spacing) / (minCardWidth + spacing))
                .floor()
                .clamp(1, 2);
        final totalSpacing = spacing * (columns - 1);
        final itemWidth = (constraints.maxWidth - totalSpacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: ejercicios
              .map(
                (ejercicio) => SizedBox(
                  width: itemWidth,
                  child: _buildEjercicioCard(ejercicio),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildPlanActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
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
                  FutureBuilder<List<PlanFit>>(
                    future: _planesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error al cargar los planes: ${snapshot.error}',
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text('Aún no tienes planes asignados.'),
                        );
                      }

                      final planes = snapshot.data!;
                      return ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          12,
                          12,
                          28 + MediaQuery.of(context).padding.bottom,
                        ),
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
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _loadingAdherenciaFit
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : _buildCumplimientoCircle(
                                              percent:
                                                  _adherenciaFit?.porcentaje ??
                                                      0,
                                              onTap:
                                                  _showAdherenciaRegistroRapidoFit,
                                            ),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed:
                                            _showAdherenciaRegistroRapidoFit,
                                        icon: const Icon(
                                          Icons.edit_calendar_outlined,
                                          size: 18,
                                        ),
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
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${plan.semanas} semanas',
                                            ),
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
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],

                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildPlanActionButton(
                                          icon: Icons.open_in_browser,
                                          label: 'Web',
                                          onPressed:
                                              (plan.url ?? '').trim().isEmpty
                                                  ? null
                                                  : () => _launchUrlExternal(
                                                        plan.url!.trim(),
                                                      ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildPlanActionButton(
                                          icon: Icons
                                              .download_for_offline_outlined,
                                          label: 'Descargar',
                                          onPressed:
                                              (plan.planDocumentoNombre ?? '')
                                                      .trim()
                                                      .isEmpty
                                                  ? null
                                                  : () => _downloadAndOpenFile(
                                                        plan.codigo,
                                                        plan.planDocumentoNombre!,
                                                      ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildPlanActionButton(
                                          icon: Icons.picture_as_pdf,
                                          label: 'PDF plan',
                                          onPressed: () =>
                                              _generatePlanFitPdf(plan),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildPlanActionButton(
                                          icon: Icons.summarize,
                                          label: 'PDF plan resumido',
                                          onPressed: () =>
                                              _generatePlanFitPdfResumen(plan),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildPlanActionButton(
                                          icon: Icons.add_circle_outline,
                                          label: 'Actividad',
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
                                        child: _buildPlanActionButton(
                                          icon: Icons.fitness_center,
                                          label: 'Ejercicios',
                                          onPressed: () {
                                            setState(() {
                                              final current =
                                                  _mostrarEjercicios[
                                                          plan.codigo] ??
                                                      false;
                                              _mostrarEjercicios[plan.codigo] =
                                                  !current;
                                            });
                                            if ((_mostrarEjercicios[
                                                        plan.codigo] ??
                                                    false) &&
                                                !_ejerciciosFutures.containsKey(
                                                  plan.codigo,
                                                )) {
                                              _getEjerciciosPlan(plan.codigo);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_mostrarEjercicios[plan.codigo] ??
                                      false) ...[
                                    const SizedBox(height: 16),
                                    FutureBuilder<List<PlanFitEjercicio>>(
                                      future: _getEjerciciosPlan(plan.codigo),
                                      builder: (context, ejerciciosSnapshot) {
                                        if (ejerciciosSnapshot
                                                .connectionState ==
                                            ConnectionState.waiting) {
                                          return const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        }
                                        if (ejerciciosSnapshot.hasError) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            child: Text(
                                              'Error al cargar ejercicios: ${ejerciciosSnapshot.error}',
                                              style: const TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          );
                                        }
                                        final ejercicios =
                                            ejerciciosSnapshot.data ??
                                                <PlanFitEjercicio>[];
                                        if (ejercicios.isEmpty) {
                                          return const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            child: Text(
                                              'Este plan no tiene ejercicios.',
                                            ),
                                          );
                                        }
                                        return FutureBuilder<List<PlanFitDia>>(
                                          future: _getDiasPlan(plan.codigo),
                                          builder: (context, diasSnapshot) {
                                            if (diasSnapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 12,
                                                ),
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              );
                                            }

                                            final dias = diasSnapshot.data ??
                                                <PlanFitDia>[];

                                            if (dias.isEmpty) {
                                              return _buildEjerciciosSinDias(
                                                ejercicios,
                                              );
                                            }

                                            return _buildEjerciciosPorDias(
                                              plan,
                                              dias,
                                              ejercicios,
                                            );
                                          },
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
          SnackBar(content: Text('No se pudo abrir el enlace: $url')),
        );
      }
    }
  }
}
