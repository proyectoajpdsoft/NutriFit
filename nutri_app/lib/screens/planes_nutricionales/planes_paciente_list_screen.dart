import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/plan_nutricional.dart';
import 'package:nutri_app/models/plan_nutri_estructura.dart';
import 'package:nutri_app/screens/planes_nutricionales/plan_nutri_paciente_detail_screen.dart';
import 'package:nutri_app/services/adherencia_service.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/plan_nutri_pdf_service.dart';
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
  final Map<int, Future<bool>> _planHasVisibleStructureCache = {};
  final Map<int, Future<_PlanHarvardSummary?>> _planHarvardSummaryCache = {};
  bool _isNutricionista = false;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _patientCode = authService.patientCode;
    _userCode = authService.userCode ?? authService.patientCode;
    _isNutricionista =
        (authService.userType ?? '').trim().toLowerCase() == 'nutricionista';

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

  String _truncateRecomendaciones(String text, {int maxChars = 30}) {
    final normalized = text.trim();
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars)}\u2026';
  }

  void _showRecomendacionesDialog(
    String recomendaciones,
    PlanNutricional plan,
  ) {
    final apiService = ApiService();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lightbulb_outlined,
                color: Colors.amber.shade700, size: 20),
            const SizedBox(width: 8),
            const Text('Recomendaciones'),
          ],
        ),
        content: SizedBox(
          width: 360,
          height: 320,
          child: SingleChildScrollView(
            child: SelectableText(
              recomendaciones,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: const Text('Copiar'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: recomendaciones));
              Navigator.of(dialogCtx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Recomendaciones copiadas'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('PDF'),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              PlanNutriPdfService.generateRecomendacionesPdf(
                context: context,
                apiService: apiService,
                recomendaciones: recomendaciones,
                tituloPlan: plan.tituloPlan ?? 'Plan nutricional',
                pacienteNombre: plan.nombrePaciente,
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
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
    bool isEnabled = true,
  }) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isEnabled ? onTap : null,
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
    _planHasVisibleStructureCache.clear();
    _planHarvardSummaryCache.clear();
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

  bool _hasVisibleStructure(PlanNutriEstructura estructura) {
    if (estructura.semanas.isEmpty) return false;
    for (final semana in estructura.semanas) {
      for (final dia in semana.dias) {
        for (final ingesta in dia.ingestas) {
          if (ingesta.items.isNotEmpty) {
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<bool> _loadPlanHasVisibleStructure(int planCodigo) async {
    try {
      final estructura = await _apiService.getPlanNutriEstructura(planCodigo);
      return _hasVisibleStructure(estructura);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _planHasVisibleStructure(int planCodigo) {
    return _planHasVisibleStructureCache.putIfAbsent(
      planCodigo,
      () => _loadPlanHasVisibleStructure(planCodigo),
    );
  }

  String _normalizeMealType(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }

  String? _mainMealKey(String tipoIngesta) {
    final normalized = _normalizeMealType(tipoIngesta);
    if (normalized.contains('comida')) return 'comida';
    return null;
  }

  Widget _buildHarvardCircularSummary(
    _PlanHarvardSummary summary,
    Color color,
  ) {
    final progress = (summary.avgScore / 4).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 54,
          height: 54,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: color.withAlpha(40),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Text(
                '${summary.avgPercent}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Media semanal ${summary.avgScore.toStringAsFixed(2)}/4 (${summary.avgPercent}%)',
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  static const _harvardEvitar = {'proteina_procesada', 'bebida_azucarada'};

  Map<String, dynamic> _computeHarvardComplianceCore(
    List<PlanNutriItem> items,
  ) {
    final tagged =
        items.where((e) => (e.harvardCategoria ?? '').isNotEmpty).toList();
    final bySeccion = <String, int>{};
    final evitar = <String>{};

    for (final item in tagged) {
      final sec = item.harvardSeccion ?? 'otro';
      final cod = item.harvardCategoria ?? 'otro';
      bySeccion[sec] = (bySeccion[sec] ?? 0) + 1;
      if (_harvardEvitar.contains(cod)) evitar.add(cod);
    }

    var score = 0;
    for (final item in tagged) {
      final itemScore = _harvardItemScore(item);
      if (itemScore > score) {
        score = itemScore;
      }
    }

    return {
      'taggedItems': tagged.length,
      'evitarCodigos': evitar,
      'score': score,
    };
  }

  Color? _parseHarvardItemColor(PlanNutriItem item) {
    if ((item.harvardColor ?? '').isEmpty) return null;
    try {
      final hex = item.harvardColor!.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return null;
    }
  }

  int _harvardItemScore(PlanNutriItem item) {
    final color = _parseHarvardItemColor(item);
    if (color != null) {
      final hsl = HSLColor.fromColor(color);
      final hue = hsl.hue;
      final saturation = hsl.saturation;
      final lightness = hsl.lightness;

      if (saturation < 0.1) return 0;
      if (hue >= 85 && hue <= 160) return 4;
      if (hue > 55 && hue < 85) return 3;
      if (hue >= 25 && hue <= 55) return 2;
      if (hue < 25 || hue >= 345) return 1;
      if (lightness > 0.72) return 3;
    }

    final section = (item.harvardSeccion ?? '').trim().toLowerCase();
    if (section == 'medio_plato') return 4;
    if (section == 'cuarto_proteinas') return 3;
    if (section == 'cuarto_cereales') return 2;
    return (item.harvardCategoria ?? '').isNotEmpty ? 1 : 0;
  }

  List<PlanNutriItem> _resolveMealItemsOptimistically(
      List<PlanNutriItem> items) {
    final fixedItems = items
        .where((e) => (e.opcion ?? '').trim().toUpperCase() != 'S')
        .toList();
    final optionalItems = items
        .where((e) => (e.opcion ?? '').trim().toUpperCase() == 'S')
        .toList();

    if (optionalItems.isEmpty) {
      return items;
    }

    PlanNutriItem? bestOption;
    Map<String, dynamic>? bestCompliance;

    for (final candidate in optionalItems) {
      final compliance =
          _computeHarvardComplianceCore([...fixedItems, candidate]);
      if (bestCompliance == null) {
        bestOption = candidate;
        bestCompliance = compliance;
        continue;
      }

      final candidateScore = compliance['score'] as int;
      final bestScore = bestCompliance['score'] as int;
      final candidateTagged = compliance['taggedItems'] as int;
      final bestTagged = bestCompliance['taggedItems'] as int;
      final candidateEvitar =
          (compliance['evitarCodigos'] as Set<String>).length;
      final bestEvitar =
          (bestCompliance['evitarCodigos'] as Set<String>).length;

      final isBetter = candidateScore > bestScore ||
          (candidateScore == bestScore && candidateEvitar < bestEvitar) ||
          (candidateScore == bestScore &&
              candidateEvitar == bestEvitar &&
              candidateTagged > bestTagged);

      if (isBetter) {
        bestOption = candidate;
        bestCompliance = compliance;
      }
    }

    return [
      ...fixedItems,
      if (bestOption != null) bestOption,
    ];
  }

  Map<String, dynamic> _computeHarvardComplianceFromItems(
    List<PlanNutriItem> items,
  ) {
    return _computeHarvardComplianceCore(items);
  }

  Future<_PlanHarvardSummary?> _loadPlanHarvardSummary(int planCodigo) async {
    try {
      final estructura = await _apiService.getPlanNutriEstructura(planCodigo);
      final hasVisibleStructure = _hasVisibleStructure(estructura);
      if (!hasVisibleStructure) {
        return const _PlanHarvardSummary(
          hasVisibleStructure: false,
          samples: 0,
          samplesWithTag: 0,
          totalMeals: 0,
          totalTaggedItems: 0,
          redFlagMeals: 0,
          avgScore: 0,
          avgPercent: 0,
          fulfilled: false,
        );
      }

      int samples = 0;
      int samplesWithTag = 0;
      int totalTaggedItems = 0;
      int redFlagMeals = 0;
      double totalScore = 0;

      for (final semana in estructura.semanas) {
        for (final dia in semana.dias) {
          final itemsByMeal = <String, List<PlanNutriItem>>{};
          for (final ingesta in dia.ingestas) {
            final mealKey = _mainMealKey(ingesta.tipoIngesta);
            if (mealKey == null) continue;
            itemsByMeal.putIfAbsent(mealKey, () => <PlanNutriItem>[]).addAll(
                  _resolveMealItemsOptimistically(ingesta.items),
                );
          }

          for (final mealItems in itemsByMeal.values) {
            final compliance = _computeHarvardComplianceFromItems(mealItems);
            samples++;
            totalScore += (compliance['score'] as int).toDouble();
            final mealTaggedItems = compliance['taggedItems'] as int;
            totalTaggedItems += mealTaggedItems;
            if (mealTaggedItems > 0) {
              samplesWithTag++;
            }
            if ((compliance['evitarCodigos'] as Set<String>).isNotEmpty) {
              redFlagMeals++;
            }
          }
        }
      }

      final avgScore = samples == 0 ? 0.0 : totalScore / samples;
      final avgPercent = samples == 0 ? 0 : ((avgScore / 4) * 100).round();
      final fulfilled = samples > 0 && avgScore >= 3.0;

      return _PlanHarvardSummary(
        hasVisibleStructure: true,
        samples: samples,
        samplesWithTag: samplesWithTag,
        totalMeals: samples,
        totalTaggedItems: totalTaggedItems,
        redFlagMeals: redFlagMeals,
        avgScore: avgScore,
        avgPercent: avgPercent,
        fulfilled: fulfilled,
      );
    } catch (_) {
      return null;
    }
  }

  Future<_PlanHarvardSummary?> _planHarvardSummary(int planCodigo) {
    return _planHarvardSummaryCache.putIfAbsent(
      planCodigo,
      () => _loadPlanHarvardSummary(planCodigo),
    );
  }

  Color _harvardSummaryColor(_PlanHarvardSummary summary) {
    if (summary.samples == 0) return Colors.grey.shade400;
    if (summary.redFlagMeals > 0) return Colors.red.shade600;
    if (summary.fulfilled) return Colors.green.shade600;
    if (summary.avgScore >= 2.5) return Colors.lightGreen.shade600;
    if (summary.avgScore >= 2.0) return Colors.orange.shade600;
    return Colors.deepOrange.shade600;
  }

  void _showHarvardPlanSummaryDialog(
    _PlanHarvardSummary summary,
    PlanNutricional plan,
  ) {
    final color = _harvardSummaryColor(summary);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(
              child: Text(
                'Harvard del plan',
                style: const TextStyle(fontSize: 15),
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close, size: 18),
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (summary.samples == 0)
                Text(
                  'Este plan no tiene Comidas evaluables todavía.',
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                _buildHarvardCircularSummary(summary, color),
              if (summary.samples > 0) ...[
                const SizedBox(height: 10),
                if (_isNutricionista)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• Comidas clasificadas: ${summary.samples} (total comidas: ${summary.totalMeals}, con evitar: ${summary.redFlagMeals})',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Alimentos con categorización Harvard: ${summary.totalTaggedItems}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Text(
                  'Solo se contabilizan las Comidas, y solo alimentos con categoría Harvard asignada.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PlanNutriPacienteDetailScreen(
                    plan: plan,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Ver detalle'),
          ),
        ],
      ),
    );
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
                      final bottomSafePadding =
                          MediaQuery.of(context).padding.bottom;
                      return ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          8,
                          12,
                          28 + bottomSafePadding + 24,
                        ),
                        itemCount: planes.length,
                        itemBuilder: (context, index) {
                          final plan = planes[index];
                          final isMobileDevice = Theme.of(context).platform ==
                                  TargetPlatform.iOS ||
                              Theme.of(context).platform ==
                                  TargetPlatform.android;

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
                                  if (plan.semanas != null &&
                                      plan.semanas!.isNotEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.blue[200]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.calendar_today,
                                              size: 14),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              '${plan.semanas} semanas',
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (plan.semanas != null &&
                                      plan.semanas!.isNotEmpty)
                                    const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text(
                                        'Cto.',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(width: 8),
                                      () {
                                        final isPlanExpired = plan.hasta !=
                                                null &&
                                            DateTime.now().isAfter(plan.hasta!);
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            _loadingAdherenciaNutri
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                : _buildCumplimientoCircle(
                                                    percent: _adherenciaNutri
                                                            ?.porcentaje ??
                                                        0,
                                                    onTap:
                                                        _showAdherenciaRegistroRapidoNutri,
                                                    isEnabled: !isPlanExpired,
                                                  ),
                                          ],
                                        );
                                      }(),
                                      const Spacer(),
                                      if (!(plan.hasta != null &&
                                          DateTime.now().isAfter(plan.hasta!)))
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

                                  // Indicaciones (recuadro amarillo, con leer mas)
                                  if (!isMobileDevice &&
                                      plan.planIndicacionesVisibleUsuario !=
                                          null &&
                                      plan.planIndicacionesVisibleUsuario!
                                          .isNotEmpty) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.fromLTRB(
                                          12, 8, 12, 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.amber[300]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.lightbulb_outlined,
                                                color: Colors.amber.shade800,
                                                size: 15,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Recomendaciones',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.amber.shade900,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _truncateRecomendaciones(
                                              plan.planIndicacionesVisibleUsuario!,
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton.icon(
                                              icon: const Icon(
                                                Icons.read_more_outlined,
                                                size: 14,
                                              ),
                                              label: const Text(
                                                'Leer mas',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 0,
                                                ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              onPressed: () =>
                                                  _showRecomendacionesDialog(
                                                plan.planIndicacionesVisibleUsuario!,
                                                plan,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  // Botón Web (si existe URL)
                                  if (plan.url != null && plan.url!.isNotEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12.0),
                                      child: Row(
                                        children: [
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
                                        ],
                                      ),
                                    ),
                                  FutureBuilder<_PlanHarvardSummary?>(
                                    future: _planHarvardSummary(plan.codigo),
                                    builder: (context, structureSnapshot) {
                                      final summary = structureSnapshot.data;
                                      final canShowPlanActions =
                                          summary?.hasVisibleStructure ?? false;
                                      final showHarvardChip = summary != null &&
                                          summary.hasVisibleStructure &&
                                          summary.totalTaggedItems >= 2;
                                      final harvardColor = summary == null
                                          ? Colors.grey.shade400
                                          : _harvardSummaryColor(summary);

                                      return Column(
                                        children: [
                                          if (showHarvardChip)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Tooltip(
                                                message: summary.samples == 0
                                                    ? 'Harvard del plan: sin datos para evaluar'
                                                    : 'Harvard del plan: ${summary.fulfilled ? 'cumple' : 'no cumple'} — media ${summary.avgScore.toStringAsFixed(2)}/4 (${summary.avgPercent}%)',
                                                child: InkWell(
                                                  onTap: () =>
                                                      _showHarvardPlanSummaryDialog(
                                                    summary,
                                                    plan,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  child: Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            bottom: 8),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: harvardColor
                                                          .withAlpha(30),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              14),
                                                      border: Border.all(
                                                        color: harvardColor,
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      '🥗 Harvard',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (canShowPlanActions)
                                            SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton.icon(
                                                icon: const Icon(
                                                  Icons.table_view_outlined,
                                                  size: 18,
                                                ),
                                                label: const Text('Ver plan'),
                                                onPressed: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          PlanNutriPacienteDetailScreen(
                                                        plan: plan,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          if (canShowPlanActions)
                                            const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              if (canShowPlanActions)
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    icon: const Icon(
                                                      Icons
                                                          .picture_as_pdf_outlined,
                                                      size: 18,
                                                    ),
                                                    label: const Text('PDF'),
                                                    onPressed: () =>
                                                        PlanNutriPdfService
                                                            .generateWithOptions(
                                                      context: context,
                                                      apiService: _apiService,
                                                      plan: plan,
                                                    ),
                                                  ),
                                                ),
                                              if (canShowPlanActions &&
                                                  plan.planDocumentoNombre !=
                                                      null &&
                                                  plan.planDocumentoNombre!
                                                      .isNotEmpty)
                                                const SizedBox(width: 8),
                                              if (plan.planDocumentoNombre !=
                                                      null &&
                                                  plan.planDocumentoNombre!
                                                      .isNotEmpty)
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    icon: const Icon(
                                                      Icons
                                                          .download_for_offline_outlined,
                                                      size: 18,
                                                    ),
                                                    label:
                                                        const Text('Descargar'),
                                                    onPressed: () =>
                                                        _downloadAndOpenFile(
                                                      plan.codigo,
                                                      plan.planDocumentoNombre!,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
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

class _PlanHarvardSummary {
  const _PlanHarvardSummary({
    required this.hasVisibleStructure,
    required this.samples,
    required this.samplesWithTag,
    required this.totalMeals,
    required this.totalTaggedItems,
    required this.redFlagMeals,
    required this.avgScore,
    required this.avgPercent,
    required this.fulfilled,
  });

  final bool hasVisibleStructure;
  final int samples;
  final int samplesWithTag;
  final int totalMeals;
  final int totalTaggedItems;
  final int redFlagMeals;
  final double avgScore;
  final int avgPercent;
  final bool fulfilled;
}
