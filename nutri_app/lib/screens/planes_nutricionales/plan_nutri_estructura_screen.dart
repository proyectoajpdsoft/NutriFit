import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nutri_app/models/alimento.dart';
import 'package:nutri_app/models/alimento_grupo.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/plan_nutri_estructura.dart';
import 'package:nutri_app/models/plan_nutricional.dart';
import 'package:nutri_app/screens/planes_nutricionales/plan_nutri_reverse_builder_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/nutri_plan_settings_service.dart';
import 'package:nutri_app/services/plan_nutri_pdf_service.dart';
import 'package:nutri_app/services/plan_nutri_word_service.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _ItemAction { up, down, edit, delete }

class PlanNutriEstructuraScreen extends StatefulWidget {
  const PlanNutriEstructuraScreen({
    super.key,
    required this.plan,
    this.openQuickBuilderOnStart = false,
    this.openCalendarBuilderOnStart = false,
  });

  final PlanNutricional plan;
  final bool openQuickBuilderOnStart;
  final bool openCalendarBuilderOnStart;

  @override
  State<PlanNutriEstructuraScreen> createState() =>
      _PlanNutriEstructuraScreenState();
}

class _PlanNutriEstructuraScreenState extends State<PlanNutriEstructuraScreen> {
  static const List<String> _diasNombre = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  List<String> _ingestasTipo = List<String>.from(
    NutriPlanSettingsService.defaultMeals,
  );

  final ApiService _apiService = ApiService();
  bool _loading = true;
  bool _saving = false;
  List<Alimento> _alimentos = [];
  List<AlimentoGrupo> _grupos = [];
  List<Map<String, dynamic>> _recetasCatalogo = [];
  final TextEditingController _tituloCtrl = TextEditingController();
  final TextEditingController _objetivoCtrl = TextEditingController();
  final TextEditingController _recomendacionesCtrl = TextEditingController();
  final TextEditingController _desdeCtrl = TextEditingController();
  final TextEditingController _hastaCtrl = TextEditingController();
  PlanNutriEstructura? _estructura;
  Set<int> _recetasSeleccionadas = {};
  bool _hasChanges = false;
  bool _isInitializingData = true;
  bool _showAllWeeks = false;
  bool _reorderMode = false;
  static const String _showAllWeeksKey = 'plan_nutri_show_all_weeks';
  static const String _detailedWeekViewKey = 'plan_nutri_detailed_week_view';
  static const String _planViewStateKeyPrefix = 'plan_nutri_view_state';
  bool _detailedWeekView = true;
  bool _planDataCardExpanded = false;
  bool _patientRecommendationsCardExpanded = false;
  bool _recipesCardExpanded = false;
  int? _compactWeekIndex;
  int? _compactDayIndex;
  final Map<PlanNutriSemana, ExpansibleController> _semanaTileControllers = {};
  final Set<PlanNutriSemana> _expandedWeeks = {};
  final Set<String> _expandedDays = {};
  final Set<String> _expandedIngestas = {};
  Timer? _draftSaveDebounce;
  Timer? _draftCounterTicker;
  DateTime? _lastDraftSavedAt;
  bool _quickBuilderOpened = false;
  bool _calendarBuilderOpened = false;

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _formatDateShort(DateTime? date) {
    if (date == null) return '—';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  void _syncDateControllers() {
    _desdeCtrl.text = _formatDateShort(widget.plan.desde);
    _hastaCtrl.text = _formatDateShort(widget.plan.hasta);
  }

  Future<void> _pickPlanDate({required bool isStart}) async {
    final currentStart =
        widget.plan.desde == null ? null : _dateOnly(widget.plan.desde!);
    final currentEnd =
        widget.plan.hasta == null ? null : _dateOnly(widget.plan.hasta!);
    final today = _dateOnly(DateTime.now());
    final initialDate = isStart
        ? (currentStart ?? currentEnd ?? today)
        : (currentEnd ?? currentStart ?? today);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText:
          isStart ? 'Selecciona la fecha desde' : 'Selecciona la fecha hasta',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (picked == null) return;

    final normalized = _dateOnly(picked);
    setState(() {
      if (isStart) {
        widget.plan.desde = normalized;
        if (currentEnd != null && normalized.isAfter(currentEnd)) {
          widget.plan.hasta = normalized;
        }
      } else {
        widget.plan.hasta = normalized;
        if (currentStart != null && normalized.isBefore(currentStart)) {
          widget.plan.desde = normalized;
        }
      }
      _syncDateControllers();
    });
    _markDirty();
  }

  DateTime _firstMondayOnOrAfter(DateTime date) {
    final base = _dateOnly(date);
    final offset = (DateTime.monday - base.weekday + 7) % 7;
    return base.add(Duration(days: offset));
  }

  String _ingestaKey(int weekIndex, int dayIndex, int mealIndex) =>
      '$weekIndex-$dayIndex-$mealIndex';

  Widget _countBadge({
    required int count,
    required Color color,
  }) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── Harvard Plate compliance ───────────────────────────────────────────────

  // Categories to warn about (limit or avoid)
  static const _harvardEvitar = {'proteina_procesada', 'bebida_azucarada'};
  static const _harvardLimitar = {
    'proteina_roja',
    'grasa_no_saludable',
    'cereal_refinado',
    'lacteo'
  };

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

  String? _weeklyMealKey(String tipoIngesta) {
    final normalized = _normalizeMealType(tipoIngesta);
    if (normalized.contains('comida')) return 'comida';
    return null;
  }

  Map<String, List<PlanNutriItem>> _mainMealItemsByKey(PlanNutriDia dia) {
    final itemsByMeal = <String, List<PlanNutriItem>>{};
    for (final ingesta in dia.ingestas) {
      final key = _mainMealKey(ingesta.tipoIngesta);
      if (key == null) continue;
      itemsByMeal
          .putIfAbsent(key, () => <PlanNutriItem>[])
          .addAll(_resolveMealItemsOptimistically(ingesta.items));
    }
    return itemsByMeal;
  }

  Map<String, List<PlanNutriItem>> _weeklyMealItemsByKey(PlanNutriDia dia) {
    final itemsByMeal = <String, List<PlanNutriItem>>{};
    for (final ingesta in dia.ingestas) {
      final key = _weeklyMealKey(ingesta.tipoIngesta);
      if (key == null) continue;
      itemsByMeal
          .putIfAbsent(key, () => <PlanNutriItem>[])
          .addAll(_resolveMealItemsOptimistically(ingesta.items));
    }
    return itemsByMeal;
  }

  Map<String, dynamic> _computeHarvardComplianceCore(
    List<PlanNutriItem> items,
  ) {
    final allItems = List<PlanNutriItem>.from(items);
    final tagged =
        allItems.where((e) => (e.harvardCategoria ?? '').isNotEmpty).toList();

    final bySeccion = <String, int>{};
    final byCodigo = <String, int>{};
    final evitar = <String>{};
    final limitar = <String>{};

    for (final item in tagged) {
      final sec = item.harvardSeccion ?? 'otro';
      final cod = item.harvardCategoria ?? 'otro';
      bySeccion[sec] = (bySeccion[sec] ?? 0) + 1;
      byCodigo[cod] = (byCodigo[cod] ?? 0) + 1;
      if (_harvardEvitar.contains(cod)) evitar.add(cod);
      if (_harvardLimitar.contains(cod)) limitar.add(cod);
    }

    var score = 0;
    for (final item in tagged) {
      final itemScore = _harvardItemScore(item);
      if (itemScore > score) {
        score = itemScore;
      }
    }

    return {
      'totalItems': allItems.length,
      'taggedItems': tagged.length,
      'bySeccion': bySeccion,
      'byCodigo': byCodigo,
      'evitarCodigos': evitar,
      'limitarCodigos': limitar,
      'score': score,
    };
  }

  int _harvardItemScore(PlanNutriItem item) {
    final color = _harvardItemColor(item);
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

  /// Returns a map summarising Harvard Plate compliance for a day.
  ///
  /// Solo se considera la comida principal: Comida.
  /// Keys: taggedItems, bySeccion (Map<String,int>), byCodigo (Map<String,int>),
  ///       evitarCodigos (Set<String>), limitarCodigos (Set<String>),
  ///       score (0-4), byMainMeal (Map<String,Map<String,dynamic>>).
  Map<String, dynamic> _computeHarvardCompliance(PlanNutriDia dia) {
    final byMealItems = _mainMealItemsByKey(dia);
    final mainItems = byMealItems.values.expand((items) => items).toList();
    final dayCompliance = _computeHarvardComplianceFromItems(mainItems);

    final byMainMeal = <String, Map<String, dynamic>>{};
    byMealItems.forEach((key, mealItems) {
      byMainMeal[key] = _computeHarvardComplianceFromItems(mealItems);
    });

    return {
      ...dayCompliance,
      'byMainMeal': byMainMeal,
      'mainMealCount': byMainMeal.length,
    };
  }

  Map<String, dynamic> _computeHarvardWeekCompliance(PlanNutriSemana semana) {
    int totalMeals = 0;
    int samples = 0;
    int samplesWithTag = 0;
    int redFlagMeals = 0;
    double totalScore = 0;

    for (final dia in semana.dias) {
      final byMealItems = _weeklyMealItemsByKey(dia);
      for (final mealItems in byMealItems.values) {
        totalMeals++;
        final c = _computeHarvardComplianceFromItems(mealItems);
        final taggedItems = c['taggedItems'] as int;
        if (taggedItems == 0) {
          continue;
        }
        samples++;
        samplesWithTag++;
        totalScore += (c['score'] as int).toDouble();
        if ((c['evitarCodigos'] as Set<String>).isNotEmpty) {
          redFlagMeals++;
        }
      }
    }

    final avgScore = samples == 0 ? 0.0 : totalScore / samples;
    final avgPercent = samples == 0 ? 0 : ((avgScore / 4) * 100).round();

    return {
      'totalMeals': totalMeals,
      'samples': samples,
      'samplesWithTag': samplesWithTag,
      'redFlagMeals': redFlagMeals,
      'avgScore': avgScore,
      'avgPercent': avgPercent,
      'fulfilled': samples > 0 && avgScore >= 3.0,
    };
  }

  Widget _buildWeekHarvardSummary(
    Color weekColor,
    double avgScore,
    int avgPercent,
  ) {
    final progress = (avgScore / 4).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: weekColor.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: weekColor.withAlpha(70)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 66,
            height: 66,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 7,
                    backgroundColor: weekColor.withAlpha(40),
                    valueColor: AlwaysStoppedAnimation<Color>(weekColor),
                  ),
                ),
                Text(
                  '$avgPercent%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: weekColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Media semanal ${avgScore.toStringAsFixed(2)}/4 ($avgPercent%)',
              style: TextStyle(
                fontSize: 16,
                color: weekColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekHarvardHeaderSummary(
    Color weekColor,
    double avgScore,
    int avgPercent,
  ) {
    final progress = (avgScore / 4).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: weekColor.withAlpha(22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: weekColor.withAlpha(80)),
      ),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                backgroundColor: weekColor.withAlpha(35),
                valueColor: AlwaysStoppedAnimation<Color>(weekColor),
              ),
            ),
            Text(
              '$avgPercent%',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: weekColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactWeekChip(
    BuildContext context,
    int weekIdx,
    PlanNutriSemana semana, {
    required bool selected,
    VoidCallback? onLongPress,
  }) {
    final weekHarvard = _computeHarvardWeekCompliance(semana);
    final weekHarvardColor = _harvardWeekComplianceColor(weekHarvard);
    final avgScore = (weekHarvard['avgScore'] as double?) ?? 0.0;
    final avgPercent = (weekHarvard['avgPercent'] as int?) ?? 0;

    return InkWell(
      onTap: () {
        setState(() {
          _compactWeekIndex = weekIdx;
          _compactDayIndex = 0;
        });
        unawaited(_savePlanViewState());
      },
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: weekHarvardColor.withAlpha(selected ? 24 : 14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : weekHarvardColor.withAlpha(180),
            width: selected ? 2.2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withAlpha(65),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.check_circle,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            Text(
              'S${semana.numeroSemana}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: weekHarvardColor,
              ),
            ),
            const SizedBox(width: 8),
            _buildWeekHarvardHeaderSummary(
              weekHarvardColor,
              avgScore,
              avgPercent,
            ),
          ],
        ),
      ),
    );
  }

  Color _harvardWeekComplianceColor(Map<String, dynamic> weekCompliance) {
    final samples = weekCompliance['samples'] as int;
    if (samples == 0) return Colors.grey.shade400;
    final fulfilled = weekCompliance['fulfilled'] as bool;
    final redFlagMeals = weekCompliance['redFlagMeals'] as int;
    if (redFlagMeals > 0) return Colors.red.shade600;
    if (fulfilled) return Colors.green.shade600;
    final avgScore = weekCompliance['avgScore'] as double;
    if (avgScore >= 2.5) return Colors.lightGreen.shade600;
    if (avgScore >= 2.0) return Colors.orange.shade600;
    return Colors.deepOrange.shade600;
  }

  Color _harvardComplianceColor(Map<String, dynamic> compliance) {
    final tagged = compliance['taggedItems'] as int;
    if (tagged == 0) return Colors.grey.shade400;
    final score = compliance['score'] as int;
    final evitar = compliance['evitarCodigos'] as Set<String>;
    if (evitar.isNotEmpty) return Colors.red.shade600;
    if (score >= 4) return Colors.green.shade600;
    if (score >= 3) return Colors.lightGreen.shade600;
    if (score >= 2) return Colors.orange.shade600;
    return Colors.deepOrange.shade600;
  }

  Color? _harvardItemColor(PlanNutriItem item) {
    if ((item.harvardColor ?? '').isEmpty) return null;
    try {
      final hex = item.harvardColor!.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return null;
    }
  }

  static const _codigoLabels = {
    'verdura': ('🥦', 'Verduras y hortalizas'),
    'fruta': ('🍎', 'Frutas'),
    'cereal_integral': ('🌾', 'Cereal integral'),
    'cereal_refinado': ('🍞', 'Cereal refinado'),
    'proteina_vegetal': ('🫘', 'Proteína vegetal'),
    'proteina_blanca': ('🐟', 'Proteína blanca'),
    'proteina_roja': ('🥩', 'Carne roja'),
    'proteina_procesada': ('🌭', 'Proteína procesada'),
    'lacteo': ('🧀', 'Lácteos'),
    'grasa_saludable': ('🫒', 'Grasa saludable'),
    'grasa_no_saludable': ('🧈', 'Grasa no saludable'),
    'agua': ('💧', 'Agua/bebidas sanas'),
    'bebida_azucarada': ('🥤', 'Bebida azucarada'),
    'otro': ('❓', 'Sin clasificar'),
  };

  void _showHarvardComplianceDialog(
    BuildContext context,
    PlanNutriDia dia, {
    PlanNutriSemana? semana,
  }) {
    final compliance = _computeHarvardCompliance(dia);
    final color = _harvardComplianceColor(compliance);
    final taggedItems = compliance['taggedItems'] as int;
    final totalItems = compliance['totalItems'] as int;
    final byCodigo = compliance['byCodigo'] as Map<String, int>;
    final evitar = compliance['evitarCodigos'] as Set<String>;
    final limitar = compliance['limitarCodigos'] as Set<String>;
    final score = compliance['score'] as int;
    final byMainMealRaw = (compliance['byMainMeal'] as Map<String, dynamic>? ??
        <String, dynamic>{});
    final byMainMeal = byMainMealRaw.map(
      (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
    );
    final weekCompliance =
        semana == null ? null : _computeHarvardWeekCompliance(semana);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(
                child: Text('Plato de Harvard (Comida) — ${dia.nombreDia}',
                    style: const TextStyle(fontSize: 15))),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (taggedItems == 0) ...[
                  const Text(
                    'La Comida de este día no tiene alimentos con categoría del Plato de '
                    'Harvard asignada aún. Clasifica los alimentos en el catálogo.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ] else ...[
                  Text(
                    '$taggedItems de $totalItems alimentos clasificados (solo Comida)',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  if (byMainMeal.isNotEmpty) ...[
                    const Text('Comida del día:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    ...[
                      ('comida', '🍽️ Comida'),
                    ].map((meal) {
                      final mealKey = meal.$1;
                      final mealLabel = meal.$2;
                      final mealCompliance = byMainMeal[mealKey];
                      if (mealCompliance == null) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '$mealLabel: no definida en este día',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black45),
                          ),
                        );
                      }
                      final mealScore = (mealCompliance['score'] as int);
                      final mealTagged = (mealCompliance['taggedItems'] as int);
                      final mealColor = _harvardComplianceColor(mealCompliance);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: mealColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '$mealLabel: $mealScore/4${mealTagged == 0 ? ' (sin clasificar)' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                  ],
                  // Score chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _harvardScoreChip(
                          '🥗 Verduras/frutas',
                          (compliance['bySeccion']
                                  as Map<String, int>)['medio_plato'] ??
                              0),
                      _harvardScoreChip(
                          '🌾 Cereales',
                          (compliance['bySeccion']
                                  as Map<String, int>)['cuarto_cereales'] ??
                              0),
                      _harvardScoreChip(
                          '🫘 Proteínas',
                          (compliance['bySeccion']
                                  as Map<String, int>)['cuarto_proteinas'] ??
                              0),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Detailed breakdown by código
                  const Text('Detalle:',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  ...byCodigo.entries.map((e) {
                    final labels = _codigoLabels[e.key];
                    final emoji = labels?.$1 ?? '❓';
                    final name = labels?.$2 ?? e.key;
                    final isEvitar = evitar.contains(e.key);
                    final isLimitar = limitar.contains(e.key);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(name,
                                  style: const TextStyle(fontSize: 13))),
                          if (isEvitar)
                            const Text('⚠️ Evitar',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600))
                          else if (isLimitar)
                            const Text('⚠️ Limitar',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600))
                          else
                            Text('${e.value}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    );
                  }),
                  if (evitar.isNotEmpty || limitar.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (evitar.isNotEmpty)
                            const Text(
                                '• Contiene alimentos a evitar (proteína procesada, bebidas azucaradas).',
                                style: TextStyle(fontSize: 12)),
                          if (limitar.isNotEmpty)
                            const Text(
                                '• Contiene alimentos a limitar (carne roja, grasas no saludables, cereales refinados).',
                                style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Puntuación: $score/4 criterios del Plato de Harvard',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (weekCompliance != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Text(
                    'Semana ${semana!.numeroSemana} (media Comida):',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Builder(builder: (_) {
                    final fulfilled = weekCompliance['fulfilled'] as bool;
                    final samples = weekCompliance['samples'] as int;
                    final avgScore = weekCompliance['avgScore'] as double;
                    final avgPercent = weekCompliance['avgPercent'] as int;
                    final redFlagMeals = weekCompliance['redFlagMeals'] as int;
                    final totalMeals =
                        weekCompliance['totalMeals'] as int? ?? samples;
                    final weekColor = samples == 0
                        ? Colors.grey.shade600
                        : fulfilled
                            ? Colors.green.shade700
                            : Colors.orange.shade700;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          samples == 0
                              ? 'No hay Comidas para evaluar esta semana.'
                              : 'Media: ${avgScore.toStringAsFixed(2)}/4 ($avgPercent%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: weekColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (samples > 0)
                          Text(
                            fulfilled
                                ? 'Cumplimiento semanal Harvard: Sí'
                                : 'Cumplimiento semanal Harvard: No',
                            style: TextStyle(
                              fontSize: 12,
                              color: weekColor,
                            ),
                          ),
                        if (samples > 0)
                          Text(
                            'Comidas clasificadas: $samples (total comidas: $totalMeals, con evitar: $redFlagMeals)',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54),
                          ),
                      ],
                    );
                  }),
                ],
                const SizedBox(height: 4),
                const Text(
                  'Solo se contabilizan las Comidas, y solo alimentos con categoría Harvard asignada.',
                  style: TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showHarvardInfoDialog(context);
            },
            icon: const Icon(Icons.info_outline, size: 16),
            label: const Text('Plato Harvard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showHarvardWeekComplianceDialog(
    BuildContext context,
    PlanNutriSemana semana,
  ) {
    final weekCompliance = _computeHarvardWeekCompliance(semana);
    final weekColor = _harvardWeekComplianceColor(weekCompliance);
    final samples = weekCompliance['samples'] as int;
    final avgScore = weekCompliance['avgScore'] as double;
    final avgPercent = weekCompliance['avgPercent'] as int;
    final fulfilled = weekCompliance['fulfilled'] as bool;
    final redFlagMeals = weekCompliance['redFlagMeals'] as int;
    final totalMeals = weekCompliance['totalMeals'] as int? ?? samples;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 8),
              decoration:
                  BoxDecoration(color: weekColor, shape: BoxShape.circle),
            ),
            Expanded(
              child: Text(
                'Harvard - Semana ${semana.numeroSemana}',
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (samples == 0)
                  Text(
                    'Sin Comidas para evaluar en esta semana.',
                    style: TextStyle(
                      fontSize: 14,
                      color: weekColor,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  _buildWeekHarvardSummary(weekColor, avgScore, avgPercent),
                if (samples > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    fulfilled
                        ? 'Cumplimiento semanal Harvard: Sí'
                        : 'Cumplimiento semanal Harvard: No',
                    style: TextStyle(fontSize: 14, color: weekColor),
                  ),
                  Text(
                    'Comidas clasificadas: $samples (total comidas: $totalMeals, con evitar: $redFlagMeals)',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  const Text('Detalle por día y comida:',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 6),
                  ...semana.dias.map((dia) {
                    final meals = _weeklyMealItemsByKey(dia);
                    if (meals.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${dia.nombreDia}: sin Comida definida',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black45),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dia.nombreDia,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          ...[
                            ('comida', '🍽️ Comida'),
                          ].map((meal) {
                            final mealItems = meals[meal.$1];
                            if (mealItems == null) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(left: 8, bottom: 1),
                                child: Text(
                                  '${meal.$2}: no definida',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black45),
                                ),
                              );
                            }
                            final c =
                                _computeHarvardComplianceFromItems(mealItems);
                            final mealColor = _harvardComplianceColor(c);
                            final mealTagged = c['taggedItems'] as int;
                            final mealScore = c['score'] as int;
                            return Padding(
                              padding:
                                  const EdgeInsets.only(left: 8, bottom: 2),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: mealColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${meal.$2}: $mealScore/4${mealTagged == 0 ? ' (sin clasificar)' : ''}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Solo se contabilizan las Comidas, y solo alimentos con categoría Harvard asignada.',
                  style: TextStyle(fontSize: 12, color: Colors.black38),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showHarvardInfoDialog(context);
            },
            icon: const Icon(Icons.info_outline, size: 16),
            label: const Text('¿Qué es el Plato de Harvard?'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _harvardScoreChip(String label, int count) {
    final ok = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ok ? Colors.green.shade300 : Colors.red.shade200,
        ),
      ),
      child: Text(
        '$label${ok ? ' ✓' : ' ✗'}',
        style: TextStyle(
          fontSize: 12,
          color: ok ? Colors.green.shade800 : Colors.red.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showHarvardInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Text('🥗', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Expanded(
                child: Text('El Plato de Harvard',
                    style: TextStyle(fontSize: 16))),
          ],
        ),
        content: const SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'El Plato de Harvard, desarrollado por la Escuela de Salud Pública de Harvard, '
                  'es una guía visual para construir comidas equilibradas y saludables.',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 12),
                Text('Proporciones recomendadas:',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                _HarvardInfoRow(
                    emoji: '🥗',
                    seccion: '½ plato',
                    desc:
                        'Verduras y frutas variadas. Cuanto más variedad y color, mejor.'),
                _HarvardInfoRow(
                    emoji: '🌾',
                    seccion: '¼ plato',
                    desc:
                        'Cereales integrales: avena, arroz integral, pasta integral, pan integral.'),
                _HarvardInfoRow(
                    emoji: '🫘',
                    seccion: '¼ plato',
                    desc:
                        'Proteínas saludables: legumbres, pescado, pollo, huevos, frutos secos.'),
                _HarvardInfoRow(
                    emoji: '🫒',
                    seccion: 'Aceites',
                    desc:
                        'Grasas saludables como el aceite de oliva virgen extra. Evitar trans.'),
                _HarvardInfoRow(
                    emoji: '💧',
                    seccion: 'Bebidas',
                    desc:
                        'Agua como bebida principal. Infusiones y café sin azúcar.'),
                SizedBox(height: 12),
                Text('Lo que el plato recomienda limitar:',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                _HarvardInfoRow(
                    emoji: '🥩',
                    seccion: 'Limitar',
                    desc: 'Carne roja: máximo 1-2 veces por semana.'),
                _HarvardInfoRow(
                    emoji: '🌭',
                    seccion: 'Evitar',
                    desc:
                        'Carnes procesadas: embutidos, fiambres, salchichas.'),
                _HarvardInfoRow(
                    emoji: '🥤',
                    seccion: 'Evitar',
                    desc:
                        'Bebidas azucaradas: refrescos, zumos industriales, bebidas energéticas.'),
                _HarvardInfoRow(
                    emoji: '🍞',
                    seccion: 'Limitar',
                    desc:
                        'Cereales refinados: pan blanco, pasta blanca, arroz blanco.'),
                SizedBox(height: 10),
                Text(
                  'Nota: esta evaluación es orientativa y basada en el recuento de alimentos '
                  'clasificados. No tiene en cuenta cantidades ni gramajes.',
                  style: TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  _CalendarDayFillStatus _calendarDayFillStatus(PlanNutriDia dia) {
    if (dia.ingestas.isEmpty) {
      return _CalendarDayFillStatus.empty;
    }
    final withFoods = dia.ingestas.where((ingesta) => ingesta.items.isNotEmpty);
    final countWithFoods = withFoods.length;
    if (countWithFoods == 0) {
      return _CalendarDayFillStatus.empty;
    }
    if (countWithFoods == dia.ingestas.length) {
      return _CalendarDayFillStatus.full;
    }
    return _CalendarDayFillStatus.partial;
  }

  Map<DateTime, _CalendarDayTarget> _buildCalendarTargets(
    PlanNutriEstructura estructura,
  ) {
    final desde = widget.plan.desde;
    if (desde == null) return {};

    final firstMonday = _firstMondayOnOrAfter(desde);
    final hasta =
        widget.plan.hasta == null ? null : _dateOnly(widget.plan.hasta!);
    final targets = <DateTime, _CalendarDayTarget>{};

    for (var weekIndex = 0;
        weekIndex < estructura.semanas.length;
        weekIndex++) {
      final semana = estructura.semanas[weekIndex];
      final weekStart = firstMonday.add(Duration(days: weekIndex * 7));
      for (var dayIndex = 0; dayIndex < semana.dias.length; dayIndex++) {
        final dia = semana.dias[dayIndex];
        final rawDay = dia.diaSemana;
        final dayOffset =
            (rawDay >= 1 && rawDay <= 7) ? rawDay - 1 : dayIndex.clamp(0, 6);
        final date = _dateOnly(weekStart.add(Duration(days: dayOffset)));
        if (hasta != null && date.isAfter(hasta)) {
          continue;
        }
        targets[date] = _CalendarDayTarget(
          weekIndex: weekIndex,
          dayIndex: dayIndex,
          semanaNumero: semana.numeroSemana,
          diaNombre: dia.nombreDia,
          fillStatus: _calendarDayFillStatus(dia),
          weekCompleted: (semana.completada ?? 'N').toUpperCase() == 'S',
        );
      }
    }

    return targets;
  }

  void _markDirty() {
    if (_isInitializingData) return;
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
    _scheduleDraftSave();
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasChanges) return true;
    return showUnsavedChangesDialog(context);
  }

  Future<void> _handleBack() async {
    if (await _confirmDiscardChanges()) {
      if (_hasChanges) {
        await _clearDraft();
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<bool> _onWillPop() async {
    final canPop = await _confirmDiscardChanges();
    if (canPop && _hasChanges) {
      await _clearDraft();
    }
    return canPop;
  }

  Future<void> _showSaveErrorDialog(String errorText) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error al guardar'),
        content: SingleChildScrollView(child: SelectableText(errorText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _syncDateControllers();
    _draftCounterTicker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      if (_lastDraftSavedAt != null) {
        setState(() {});
      }
    });
    _load();
  }

  @override
  void dispose() {
    _draftSaveDebounce?.cancel();
    _draftCounterTicker?.cancel();
    _tituloCtrl.dispose();
    _objetivoCtrl.dispose();
    _recomendacionesCtrl.dispose();
    _desdeCtrl.dispose();
    _hastaCtrl.dispose();
    super.dispose();
  }

  int _parseWeekCount() {
    final raw = (widget.plan.totalSemanas?.toString() ??
            widget.plan.semanas?.toString() ??
            '')
        .trim();
    final direct = int.tryParse(raw);
    if (direct != null && direct > 0) return direct;
    final match = RegExp(r'\d+').firstMatch(raw);
    final parsed = int.tryParse(match?.group(0) ?? '');
    if (parsed != null && parsed > 0) return parsed;
    return 1;
  }

  String _nutriScope() {
    final authService = context.read<AuthService>();
    final userCode = (authService.userCode ?? '').trim();
    final userType = (authService.userType ?? '').trim();
    if (userCode.isEmpty || userType.isEmpty) {
      return 'default';
    }
    return '${userType}_$userCode';
  }

  String _draftStorageKey() {
    return 'plan_nutri_draft_${widget.plan.codigo}_${_nutriScope()}';
  }

  String _viewStateStorageKey() {
    return '${_planViewStateKeyPrefix}_${widget.plan.codigo}_${_nutriScope()}';
  }

  String _dayKey(int weekIndex, int dayIndex) => '$weekIndex-$dayIndex';

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  List<int> _expandedWeekIndices(PlanNutriEstructura estructura) {
    final result = <int>[];
    for (var i = 0; i < estructura.semanas.length; i++) {
      if (_expandedWeeks.contains(estructura.semanas[i])) {
        result.add(i);
      }
    }
    return result;
  }

  Set<String> _validExpandedDayKeys(PlanNutriEstructura estructura) {
    final result = <String>{};
    for (var weekIndex = 0;
        weekIndex < estructura.semanas.length;
        weekIndex++) {
      final semana = estructura.semanas[weekIndex];
      for (var dayIndex = 0; dayIndex < semana.dias.length; dayIndex++) {
        final key = _dayKey(weekIndex, dayIndex);
        if (_expandedDays.contains(key)) {
          result.add(key);
        }
      }
    }
    return result;
  }

  Set<String> _validExpandedIngestaKeys(PlanNutriEstructura estructura) {
    final result = <String>{};
    for (var weekIndex = 0;
        weekIndex < estructura.semanas.length;
        weekIndex++) {
      final semana = estructura.semanas[weekIndex];
      for (var dayIndex = 0; dayIndex < semana.dias.length; dayIndex++) {
        final dia = semana.dias[dayIndex];
        for (var ingestaIndex = 0;
            ingestaIndex < dia.ingestas.length;
            ingestaIndex++) {
          final key = _ingestaKey(weekIndex, dayIndex, ingestaIndex);
          if (_expandedIngestas.contains(key)) {
            result.add(key);
          }
        }
      }
    }
    return result;
  }

  void _restorePlanViewState(
    SharedPreferences prefs,
    PlanNutriEstructura estructura,
  ) {
    _expandedWeeks.clear();
    _expandedDays.clear();
    _expandedIngestas.clear();
    _planDataCardExpanded = false;
    _patientRecommendationsCardExpanded = false;
    _recipesCardExpanded = false;
    _compactWeekIndex = null;
    _compactDayIndex = null;

    final raw = prefs.getString(_viewStateStorageKey());
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded.cast<String, dynamic>());

      final restoredWeekIndices =
          ((data['expandedWeekIndices'] as List?) ?? const [])
              .map(_asInt)
              .whereType<int>();
      for (final weekIndex in restoredWeekIndices) {
        if (weekIndex >= 0 && weekIndex < estructura.semanas.length) {
          _expandedWeeks.add(estructura.semanas[weekIndex]);
        }
      }

      final restoredDayKeys = ((data['expandedDayKeys'] as List?) ?? const [])
          .map((item) => item.toString())
          .where((item) => RegExp(r'^\d+-\d+$').hasMatch(item));
      for (final key in restoredDayKeys) {
        final parts = key.split('-');
        final weekIndex = int.tryParse(parts[0]);
        final dayIndex = int.tryParse(parts[1]);
        if (weekIndex == null || dayIndex == null) continue;
        if (weekIndex < 0 || weekIndex >= estructura.semanas.length) continue;
        if (dayIndex < 0 ||
            dayIndex >= estructura.semanas[weekIndex].dias.length) {
          continue;
        }
        _expandedDays.add(key);
      }

      final restoredIngestaKeys =
          ((data['expandedIngestaKeys'] as List?) ?? const [])
              .map((item) => item.toString())
              .where((item) => RegExp(r'^\d+-\d+-\d+$').hasMatch(item));
      for (final key in restoredIngestaKeys) {
        final parts = key.split('-');
        final weekIndex = int.tryParse(parts[0]);
        final dayIndex = int.tryParse(parts[1]);
        final ingestaIndex = int.tryParse(parts[2]);
        if (weekIndex == null || dayIndex == null || ingestaIndex == null) {
          continue;
        }
        if (weekIndex < 0 || weekIndex >= estructura.semanas.length) continue;
        final semana = estructura.semanas[weekIndex];
        if (dayIndex < 0 || dayIndex >= semana.dias.length) continue;
        final dia = semana.dias[dayIndex];
        if (ingestaIndex < 0 || ingestaIndex >= dia.ingestas.length) continue;
        _expandedIngestas.add(key);
      }

      final compactWeekIndex = _asInt(data['compactWeekIndex']);
      if (compactWeekIndex != null &&
          compactWeekIndex >= 0 &&
          compactWeekIndex < estructura.semanas.length) {
        _compactWeekIndex = compactWeekIndex;
        final compactDayIndex = _asInt(data['compactDayIndex']);
        if (compactDayIndex != null &&
            compactDayIndex >= 0 &&
            compactDayIndex <
                estructura.semanas[compactWeekIndex].dias.length) {
          _compactDayIndex = compactDayIndex;
        }
      }

      _planDataCardExpanded = data['planDataCardExpanded'] == true;
      _patientRecommendationsCardExpanded =
          data['patientRecommendationsCardExpanded'] == true;
      _recipesCardExpanded = data['recipesCardExpanded'] == true;
    } catch (_) {}
  }

  Future<void> _savePlanViewState() async {
    final estructura = _estructura;
    if (estructura == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final compactWeekIndex = _compactWeekIndex;
      final validCompactWeekIndex = compactWeekIndex != null &&
              compactWeekIndex >= 0 &&
              compactWeekIndex < estructura.semanas.length
          ? compactWeekIndex
          : null;
      final compactDayIndex = _compactDayIndex;
      final validCompactDayIndex = validCompactWeekIndex != null &&
              compactDayIndex != null &&
              compactDayIndex >= 0 &&
              compactDayIndex <
                  estructura.semanas[validCompactWeekIndex].dias.length
          ? compactDayIndex
          : null;

      final payload = <String, dynamic>{
        'compactWeekIndex': validCompactWeekIndex,
        'compactDayIndex': validCompactDayIndex,
        'planDataCardExpanded': _planDataCardExpanded,
        'patientRecommendationsCardExpanded':
            _patientRecommendationsCardExpanded,
        'recipesCardExpanded': _recipesCardExpanded,
        'expandedWeekIndices': _expandedWeekIndices(estructura),
        'expandedDayKeys': _validExpandedDayKeys(estructura).toList(),
        'expandedIngestaKeys': _validExpandedIngestaKeys(estructura).toList(),
      };

      await prefs.setString(_viewStateStorageKey(), jsonEncode(payload));
    } catch (_) {}
  }

  void _scheduleDraftSave() {
    _draftSaveDebounce?.cancel();
    _draftSaveDebounce = Timer(const Duration(milliseconds: 800), () {
      _saveDraft();
    });
  }

  Future<void> _saveDraft() async {
    final estructura = _estructura;
    if (_isInitializingData || estructura == null) return;
    try {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'saved_at': now.toIso8601String(),
        'titulo': _tituloCtrl.text,
        'objetivo': _objetivoCtrl.text,
        'recomendaciones': _recomendacionesCtrl.text,
        'fecha_desde': widget.plan.desde?.toIso8601String(),
        'fecha_hasta': widget.plan.hasta?.toIso8601String(),
        'recetasSeleccionadas': _recetasSeleccionadas.toList(),
        'estructura': estructura.toJson(),
      };
      await prefs.setString(_draftStorageKey(), jsonEncode(payload));
      if (mounted) {
        setState(() {
          _lastDraftSavedAt = now;
        });
      }
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftStorageKey());
    if (mounted) {
      setState(() {
        _lastDraftSavedAt = null;
      });
    }
  }

  Future<Map<String, dynamic>?> _readDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftStorageKey());
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _maybeRestoreDraft() async {
    final draft = await _readDraft();
    if (!mounted || draft == null) return;

    final savedAt = DateTime.tryParse((draft['saved_at'] ?? '').toString());
    if (savedAt != null) {
      setState(() {
        _lastDraftSavedAt = savedAt;
      });
    }

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrador automático encontrado'),
        content: const Text(
          'Se encontró un borrador local sin guardar de esta estructura. ¿Quieres restaurarlo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Descartar borrador'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'restore'),
            child: const Text('Restaurar borrador'),
          ),
        ],
      ),
    );

    if (action == 'discard') {
      await _clearDraft();
      return;
    }
    if (action != 'restore') return;

    try {
      final rawEstructura = draft['estructura'];
      if (rawEstructura is! Map) return;
      final restaurada = PlanNutriEstructura.fromJson(
        Map<String, dynamic>.from(rawEstructura),
      );
      if (restaurada.codigoPlanNutricional != widget.plan.codigo) return;

      final recetasRaw = draft['recetasSeleccionadas'];
      final recetasSeleccionadas = recetasRaw is List
          ? recetasRaw
              .map((e) => int.tryParse(e.toString()) ?? 0)
              .where((e) => e > 0)
              .toSet()
          : restaurada.recetas.map((e) => e.codigoReceta).toSet();

      _tituloCtrl.text =
          (draft['titulo'] ?? restaurada.tituloPlan ?? '').toString();
      _objetivoCtrl.text =
          (draft['objetivo'] ?? restaurada.objetivoPlan ?? '').toString();
      _recomendacionesCtrl.text = (draft['recomendaciones'] ??
              restaurada.planIndicacionesVisibleUsuario ??
              '')
          .toString();
      final restoredDesde = DateTime.tryParse(
        (draft['fecha_desde'] ?? '').toString(),
      );
      final restoredHasta = DateTime.tryParse(
        (draft['fecha_hasta'] ?? '').toString(),
      );
      if (restoredDesde != null) {
        widget.plan.desde = _dateOnly(restoredDesde);
      }
      if (restoredHasta != null) {
        widget.plan.hasta = _dateOnly(restoredHasta);
      }
      _syncDateControllers();
      final prefs = await SharedPreferences.getInstance();
      _restorePlanViewState(prefs, restaurada);

      if (!mounted) return;
      setState(() {
        _estructura = restaurada;
        _recetasSeleccionadas = recetasSeleccionadas;
        _hasChanges = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Borrador restaurado'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      // Ignorar borradores dañados
    }
  }

  String _draftAgeText() {
    final last = _lastDraftSavedAt;
    if (last == null) return '';
    final diff = DateTime.now().difference(last);
    if (diff.inSeconds < 60) return 'hace ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    return 'hace ${diff.inHours} h';
  }

  void _renumberWeeks(PlanNutriEstructura estructura) {
    for (var i = 0; i < estructura.semanas.length; i++) {
      final week = estructura.semanas[i];
      week.numeroSemana = i + 1;
      week.orden = i + 1;
      final currentTitle = (week.titulo ?? '').trim();
      if (currentTitle.isEmpty ||
          RegExp(r'^Semana\s+\d+$').hasMatch(currentTitle)) {
        week.titulo = 'Semana ${i + 1}';
      }
    }
  }

  void _reorderSemanas(int oldIndex, int newIndex) {
    final estructura = _estructura;
    if (estructura == null) return;
    if (newIndex > oldIndex) newIndex--;
    final visibleList = estructura.semanas
        .where((s) => _showAllWeeks || !_isSemanaCompleted(s))
        .toList();
    if (oldIndex < 0 || oldIndex >= visibleList.length) return;
    if (newIndex < 0 || newIndex >= visibleList.length) return;
    final moving = visibleList[oldIndex];
    final target = visibleList[newIndex];
    final origOld = estructura.semanas.indexOf(moving);
    var origNew = estructura.semanas.indexOf(target);
    setState(() {
      final semana = estructura.semanas.removeAt(origOld);
      if (origOld < origNew) {
        origNew--;
      }
      estructura.semanas.insert(origNew, semana);
      for (var i = 0; i < estructura.semanas.length; i++) {
        estructura.semanas[i].orden = i + 1;
      }
    });
    _markDirty();
    unawaited(_savePlanViewState());
  }

  bool _isSemanaCompleted(PlanNutriSemana semana) {
    return (semana.completada ?? 'N').toUpperCase() == 'S';
  }

  Future<bool> _askCompletePreviousWeek(PlanNutriSemana previousWeek) async {
    if (_isSemanaCompleted(previousWeek)) return true;

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
        title: Row(
          children: [
            const Expanded(
              child: Text('Completar semana anterior'),
            ),
            IconButton(
              tooltip: 'Cancelar',
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
              ),
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: Text(
          'La semana ${previousWeek.numeroSemana} no está completada. ¿Quieres marcarla como completada antes de añadir una nueva?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'complete'),
            child: const Text('Completar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'skip'),
            child: const Text('No completar'),
          ),
        ],
      ),
    );

    if (action == null) return false;
    if (action == 'complete') {
      setState(() {
        previousWeek.completada = 'S';
      });
      _markDirty();
    }
    return true;
  }

  Future<void> _addSemana() async {
    final estructura = _estructura;
    if (estructura == null) return;

    if (estructura.semanas.isNotEmpty) {
      final previous = estructura.semanas.last;
      final canContinue = await _askCompletePreviousWeek(previous);
      if (!canContinue) return;
    }

    setState(() {
      final next = estructura.semanas.length + 1;
      estructura.semanas.addAll(
        _buildDefaultWeeks(1).map((w) {
          w.numeroSemana = next;
          w.titulo = 'Semana $next';
          w.orden = next;
          w.completada = 'N';
          return w;
        }),
      );
    });
    _markDirty();
  }

  PlanNutriSemana _cloneSemana(
    PlanNutriSemana source, {
    Set<int>? dayIds,
    Map<int, Set<String>>? mealsByDay,
  }) {
    final clonedDays = <PlanNutriDia>[];
    for (final day in source.dias) {
      if (dayIds != null && !dayIds.contains(day.diaSemana)) {
        continue;
      }
      final selectedMeals = mealsByDay?[day.diaSemana];
      final clonedMeals = <PlanNutriIngesta>[];
      for (final meal in day.ingestas) {
        if (selectedMeals != null &&
            !selectedMeals.contains(meal.tipoIngesta)) {
          continue;
        }
        final clonedItems = meal.items
            .map(
              (item) => PlanNutriItem(
                codigoAlimento: item.codigoAlimento,
                alimentoNombre: item.alimentoNombre,
                descripcionManual: item.descripcionManual,
                cantidad: item.cantidad,
                unidad: item.unidad,
                orden: item.orden,
                notas: item.notas,
              ),
            )
            .toList();

        clonedMeals.add(
          PlanNutriIngesta(
            tipoIngesta: meal.tipoIngesta,
            orden: meal.orden,
            observaciones: meal.observaciones,
            items: clonedItems,
          ),
        );
      }

      clonedDays.add(
        PlanNutriDia(
          diaSemana: day.diaSemana,
          nombreDia: day.nombreDia,
          observaciones: day.observaciones,
          ingestas: clonedMeals,
        ),
      );
    }

    return PlanNutriSemana(
      numeroSemana: source.numeroSemana,
      titulo: source.titulo,
      completada: source.completada,
      dias: clonedDays,
    );
  }

  PlanNutriDia _buildDefaultDay(int diaSemana) {
    final normalizedDay = diaSemana.clamp(1, _diasNombre.length);
    final dayIndex = normalizedDay - 1;
    final ingestas = List.generate(
      _ingestasTipo.length,
      (mealIndex) => PlanNutriIngesta(
        tipoIngesta: _ingestasTipo[mealIndex],
        orden: mealIndex + 1,
      ),
    );
    return PlanNutriDia(
      diaSemana: normalizedDay,
      nombreDia: _diasNombre[dayIndex],
      ingestas: ingestas,
    );
  }

  PlanNutriSemana _buildWeekFromDefaultsAndCopy(PlanNutriSemana sourceCopy) {
    final baseWeek = _buildDefaultWeeks(1).first
      ..titulo = sourceCopy.titulo
      ..completada = sourceCopy.completada;
    _mergeCopiedWeekIntoTarget(targetWeek: baseWeek, copiedWeek: sourceCopy);
    return baseWeek;
  }

  void _mergeCopiedWeekIntoTarget({
    required PlanNutriSemana targetWeek,
    required PlanNutriSemana copiedWeek,
  }) {
    for (final sourceDay in copiedWeek.dias) {
      final normalizedDay = sourceDay.diaSemana.clamp(1, _diasNombre.length);
      var targetDay = targetWeek.dias
          .where((d) => d.diaSemana == normalizedDay)
          .firstOrNull;

      if (targetDay == null) {
        targetDay = _buildDefaultDay(normalizedDay);
        targetWeek.dias.add(targetDay);
      }

      targetDay
        ..diaSemana = normalizedDay
        ..nombreDia = sourceDay.nombreDia
        ..observaciones = sourceDay.observaciones;

      for (final sourceMeal in sourceDay.ingestas) {
        final clonedItems = sourceMeal.items
            .map(
              (item) => PlanNutriItem(
                codigoAlimento: item.codigoAlimento,
                alimentoNombre: item.alimentoNombre,
                descripcionManual: item.descripcionManual,
                cantidad: item.cantidad,
                unidad: item.unidad,
                orden: item.orden,
                notas: item.notas,
              ),
            )
            .toList();

        final targetMeal = targetDay.ingestas
            .where((m) => m.tipoIngesta == sourceMeal.tipoIngesta)
            .firstOrNull;

        if (targetMeal != null) {
          targetMeal
            ..observaciones = sourceMeal.observaciones
            ..items = clonedItems;
        } else {
          targetDay.ingestas.add(
            PlanNutriIngesta(
              tipoIngesta: sourceMeal.tipoIngesta,
              orden: targetDay.ingestas.length + 1,
              observaciones: sourceMeal.observaciones,
              items: clonedItems,
            ),
          );
        }
      }

      targetDay.ingestas.sort((a, b) {
        final idxA = _ingestasTipo.indexOf(a.tipoIngesta);
        final idxB = _ingestasTipo.indexOf(b.tipoIngesta);
        if (idxA == -1 && idxB == -1) {
          return a.orden.compareTo(b.orden);
        }
        if (idxA == -1) return 1;
        if (idxB == -1) return -1;
        return idxA.compareTo(idxB);
      });
      for (var i = 0; i < targetDay.ingestas.length; i++) {
        targetDay.ingestas[i].orden = i + 1;
      }
    }

    targetWeek.dias.sort((a, b) => a.diaSemana.compareTo(b.diaSemana));
  }

  Future<String?> _pickCopyTargetOption() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'Copiar semana',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Cancelar',
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
              ),
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: const Text('Selecciona destino de la copia:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'same'),
            child: const Text('Mismo plan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'other'),
            child: const Text('Otro plan nutri'),
          ),
        ],
      ),
    );
  }

  Future<PlanNutricional?> _pickTargetPlanDialog() async {
    List<PlanNutricional> plans;
    Set<int> activePatientCodes;
    try {
      final results = await Future.wait<dynamic>([
        _apiService.getPlanes(null),
        _apiService.getPacientes(activo: 'S'),
      ]);
      plans = results[0] as List<PlanNutricional>;
      final activePatients = results[1] as List<Paciente>;
      activePatientCodes = activePatients.map((p) => p.codigo).toSet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron cargar planes/pacientes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    final filtered = plans.where((p) {
      if (p.codigo == widget.plan.codigo) return false;
      if ((p.completado ?? 'N').toUpperCase() == 'S') return false;
      final codigoPaciente = p.codigoPaciente;
      if (codigoPaciente == null) return false;
      return activePatientCodes.contains(codigoPaciente);
    }).toList();
    if (filtered.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay otros planes disponibles.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return null;
    }

    return showDialog<PlanNutricional>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'Selecciona plan destino',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Cancelar',
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
              ),
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final plan = filtered[index];
              final title = (plan.tituloPlan ?? '').trim().isEmpty
                  ? 'Plan #${plan.codigo}'
                  : '${plan.tituloPlan} (#${plan.codigo})';
              final subtitle = (plan.nombrePaciente ?? '').trim();
              return ListTile(
                title: Text(title),
                subtitle: subtitle.isEmpty ? null : Text(subtitle),
                onTap: () => Navigator.pop(context, plan),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _copySemanaToCurrentPlan(PlanNutriSemana clonedWeek) async {
    final estructura = _estructura;
    if (estructura == null) return;

    final destination = await _pickSamePlanWeekDestination(estructura);
    if (destination == null) return;

    var copiedToExisting = false;
    setState(() {
      if (destination == -1) {
        final newWeek = _buildWeekFromDefaultsAndCopy(clonedWeek);
        estructura.semanas.add(newWeek);
      } else if (destination >= 0 && destination < estructura.semanas.length) {
        final targetWeek = estructura.semanas[destination];
        copiedToExisting = true;
        _mergeCopiedWeekIntoTarget(
          targetWeek: targetWeek,
          copiedWeek: clonedWeek,
        );
      }
      _renumberWeeks(estructura);
    });
    _markDirty();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          copiedToExisting
              ? 'Semana copiada en semana existente'
              : 'Semana copiada en nueva semana',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<int?> _pickSamePlanWeekDestination(
      PlanNutriEstructura estructura) async {
    final mode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'En el mismo plan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Cancelar',
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
              ),
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Quieres copiar la semana en una nueva o sobre una existente?',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'existing'),
                    child: const Text('Existente'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, 'new'),
                    child: const Text('Nueva'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (mode == null) return null;
    if (mode == 'new') return -1;

    if (estructura.semanas.isEmpty) {
      return -1;
    }

    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'Semana de destino',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Cancelar',
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
              ),
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: estructura.semanas.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final semana = estructura.semanas[index];
              final titulo = (semana.titulo ?? '').trim().isEmpty
                  ? 'Semana ${semana.numeroSemana}'
                  : 'Semana ${semana.numeroSemana} · ${semana.titulo}';
              return ListTile(
                title: Text(titulo),
                onTap: () => Navigator.pop(context, index),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _copySemanaToOtherPlan(PlanNutriSemana clonedWeek) async {
    final target = await _pickTargetPlanDialog();
    if (target == null) return;

    try {
      PlanNutriEstructura targetEstructura;
      try {
        targetEstructura = await _apiService.getPlanNutriEstructura(
          target.codigo,
        );
      } catch (_) {
        targetEstructura = PlanNutriEstructura(
          codigoPlanNutricional: target.codigo,
          tituloPlan: target.tituloPlan,
          objetivoPlan: target.objetivoPlan,
          planIndicaciones: target.planIndicaciones,
          planIndicacionesVisibleUsuario: target.planIndicacionesVisibleUsuario,
          semanas: <PlanNutriSemana>[],
        );
      }

      final newWeek = _buildWeekFromDefaultsAndCopy(clonedWeek);
      targetEstructura.semanas.add(newWeek);
      _renumberWeeks(targetEstructura);

      final saved = await _apiService.savePlanNutriEstructura(targetEstructura);
      if (!saved) {
        throw Exception('No se pudo guardar en el plan destino.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Semana copiada al plan #${target.codigo}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al copiar semana: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _pickPartialCopyConfig(
    PlanNutriSemana week,
  ) async {
    final selectedDays = <int>{...week.dias.map((d) => d.diaSemana)};
    final selectedMealsByDay = <int, Set<String>>{
      for (final day in week.dias)
        day.diaSemana: day.ingestas.map((m) => m.tipoIngesta).toSet(),
    };
    final allMealTypes = week.dias
        .expand((d) => d.ingestas.map((m) => m.tipoIngesta))
        .where((m) => m.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) {
        final idxA = _ingestasTipo.indexOf(a);
        final idxB = _ingestasTipo.indexOf(b);
        if (idxA == -1 && idxB == -1) return a.compareTo(b);
        if (idxA == -1) return 1;
        if (idxB == -1) return -1;
        return idxA.compareTo(idxB);
      });

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Copiar semana sin...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Cancelar',
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                ),
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
          content: SizedBox(
            width: 540,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  'Acciones rápidas',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        setLocal(() {
                          selectedDays
                            ..clear()
                            ..addAll(week.dias.map((d) => d.diaSemana));
                          for (final day in week.dias) {
                            selectedMealsByDay[day.diaSemana] =
                                day.ingestas.map((m) => m.tipoIngesta).toSet();
                          }
                        });
                      },
                      icon: const Icon(Icons.select_all, size: 16),
                      label: const Text('Marcar todo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setLocal(() {
                          selectedDays.clear();
                        });
                      },
                      icon: const Icon(Icons.event_busy, size: 16),
                      label: const Text('Quitar todos los días'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setLocal(() {
                          for (final day in week.dias) {
                            selectedMealsByDay[day.diaSemana] = <String>{};
                          }
                        });
                      },
                      icon: const Icon(Icons.no_meals, size: 16),
                      label: const Text('Quitar todas las ingestas'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: week.dias
                      .map(
                        (day) => ActionChip(
                          avatar:
                              const Icon(Icons.remove_circle_outline, size: 16),
                          label: Text('Quitar ${day.nombreDia}'),
                          onPressed: () {
                            setLocal(() {
                              selectedDays.remove(day.diaSemana);
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                if (allMealTypes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allMealTypes
                        .map(
                          (mealType) => ActionChip(
                            avatar: const Icon(Icons.remove_circle_outline,
                                size: 16),
                            label: Text('Quitar $mealType'),
                            onPressed: () {
                              setLocal(() {
                                for (final day in week.dias) {
                                  final current =
                                      selectedMealsByDay[day.diaSemana] ??
                                          <String>{};
                                  current.remove(mealType);
                                  selectedMealsByDay[day.diaSemana] = current;
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                ...week.dias.map((day) {
                  final daySelected = selectedDays.contains(day.diaSemana);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      title: CheckboxListTile(
                        dense: true,
                        value: daySelected,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: Text(day.nombreDia),
                        onChanged: (v) {
                          setLocal(() {
                            if (v == true) {
                              selectedDays.add(day.diaSemana);
                            } else {
                              selectedDays.remove(day.diaSemana);
                            }
                          });
                        },
                      ),
                      children: day.ingestas.map((meal) {
                        final meals =
                            selectedMealsByDay[day.diaSemana] ?? <String>{};
                        final mealSelected = meals.contains(meal.tipoIngesta);
                        return CheckboxListTile(
                          dense: true,
                          value: mealSelected,
                          title: Text(meal.tipoIngesta),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: !daySelected
                              ? null
                              : (v) {
                                  setLocal(() {
                                    final targetSet =
                                        selectedMealsByDay[day.diaSemana] ??
                                            <String>{};
                                    if (v == true) {
                                      targetSet.add(meal.tipoIngesta);
                                    } else {
                                      targetSet.remove(meal.tipoIngesta);
                                    }
                                    selectedMealsByDay[day.diaSemana] =
                                        targetSet;
                                  });
                                },
                        );
                      }).toList(),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Copiar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return null;
    return {'days': selectedDays, 'mealsByDay': selectedMealsByDay};
  }

  Future<void> _handleCopySemana(
    PlanNutriSemana sourceWeek, {
    required bool partial,
  }) async {
    Set<int>? days;
    Map<int, Set<String>>? mealsByDay;

    if (partial) {
      final config = await _pickPartialCopyConfig(sourceWeek);
      if (config == null) return;
      days = (config['days'] as Set<int>?) ?? <int>{};
      mealsByDay = (config['mealsByDay'] as Map<int, Set<String>>?) ?? {};
      if (days.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecciona al menos un día para copiar.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    final cloned = _cloneSemana(
      sourceWeek,
      dayIds: days,
      mealsByDay: mealsByDay,
    );

    if (cloned.dias.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La selección no contiene días/ingestas válidos.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final targetOption = await _pickCopyTargetOption();
    if (targetOption == null) return;
    if (targetOption == 'same') {
      await _copySemanaToCurrentPlan(cloned);
    } else {
      await _copySemanaToOtherPlan(cloned);
    }
  }

  Future<void> _deleteSemana(int weekIndex) async {
    final estructura = _estructura;
    if (estructura == null) return;
    if (estructura.semanas.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe existir al menos una semana.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar semana'),
        content: const Text(
          'Se eliminará la semana completa con todos sus días e ingestas. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    setState(() {
      if (weekIndex >= 0 && weekIndex < estructura.semanas.length) {
        estructura.semanas.removeAt(weekIndex);
      }
      _renumberWeeks(estructura);
    });
    _markDirty();
    unawaited(_savePlanViewState());
  }

  Future<void> _editSemana(PlanNutriSemana semana) async {
    final numeroCtrl = TextEditingController(
      text: semana.numeroSemana.toString(),
    );
    final tituloCtrl = TextEditingController(text: semana.titulo ?? '');

    bool completada = _isSemanaCompleted(semana);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Editar semana'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numeroCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Número de semana',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tituloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título de semana',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: completada,
                onChanged: (v) => setLocal(() => completada = v ?? false),
                title: const Text('Completar semana'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final numero = int.tryParse(numeroCtrl.text.trim());
    if (numero == null || numero <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El número de semana debe ser mayor que 0.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      semana.numeroSemana = numero;
      semana.titulo = tituloCtrl.text.trim().isEmpty
          ? 'Semana $numero'
          : tituloCtrl.text.trim();
      semana.completada = completada ? 'S' : 'N';
    });
    _markDirty();
  }

  Future<void> _completeSemana(PlanNutriSemana semana) async {
    if (_isSemanaCompleted(semana)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Completar semana'),
        content: Text(
          '¿Marcar la semana ${semana.numeroSemana} como completada?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Completar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      semana.completada = 'S';
    });
    _markDirty();
  }

  Future<void> _onSemanaLongPress(int weekIndex, PlanNutriSemana semana) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar semana'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            if (!_isSemanaCompleted(semana))
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Completar semana'),
                onTap: () => Navigator.pop(context, 'complete'),
              ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('Copiar semana completa'),
              onTap: () => Navigator.pop(context, 'copy_full'),
            ),
            ListTile(
              leading: const Icon(Icons.content_copy_outlined),
              title: const Text('Copiar semana sin...'),
              onTap: () => Navigator.pop(context, 'copy_partial'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar semana'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'edit') {
      await _editSemana(semana);
    } else if (action == 'complete') {
      await _completeSemana(semana);
    } else if (action == 'copy_full') {
      await _handleCopySemana(semana, partial: false);
    } else if (action == 'copy_partial') {
      await _handleCopySemana(semana, partial: true);
    } else if (action == 'delete') {
      await _deleteSemana(weekIndex);
    }
  }

  List<PlanNutriSemana> _buildDefaultWeeks(
    int weekCount, {
    List<String>? ingestasTipo,
  }) {
    final mealTypes = ingestasTipo ?? _ingestasTipo;
    return List.generate(weekCount, (weekIndex) {
      final numeroSemana = weekIndex + 1;
      final dias = List.generate(_diasNombre.length, (dayIndex) {
        final ingestas = List.generate(
          mealTypes.length,
          (mealIndex) => PlanNutriIngesta(
            tipoIngesta: mealTypes[mealIndex],
            orden: mealIndex + 1,
          ),
        );
        return PlanNutriDia(
          diaSemana: dayIndex + 1,
          nombreDia: _diasNombre[dayIndex],
          ingestas: ingestas,
        );
      });
      return PlanNutriSemana(
        numeroSemana: numeroSemana,
        titulo: 'Semana $numeroSemana',
        completada: 'N',
        dias: dias,
      );
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    try {
      final futures = await Future.wait<dynamic>([
        _apiService.getAlimentos(soloActivos: true),
        _apiService.get('api/recetas.php'),
      ]);

      final alimentos = futures[0] as List<Alimento>;
      final recetasResponse = futures[1];

      // Cargar grupos de forma opcional
      List<AlimentoGrupo> grupos = [];
      try {
        grupos = await _apiService.getAlimentoGrupos();
      } catch (_) {
        // Continuar sin grupos si falla la carga
      }

      List<String> ingestasConfiguradas = List<String>.from(
        NutriPlanSettingsService.defaultMeals,
      );
      try {
        ingestasConfiguradas = await NutriPlanSettingsService.getEnabledMeals(
          _nutriScope(),
        );
      } catch (_) {
        // Mantener valores por defecto si falla la carga
      }
      if (ingestasConfiguradas.isEmpty) {
        ingestasConfiguradas = List<String>.from(
          NutriPlanSettingsService.defaultMeals,
        );
      }

      final List<dynamic> recetasJson = recetasResponse.statusCode == 200
          ? jsonDecode(recetasResponse.body) as List<dynamic>
          : <dynamic>[];
      final recetasCatalogo = recetasJson
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      PlanNutriEstructura estructura;
      try {
        estructura = await _apiService.getPlanNutriEstructura(
          widget.plan.codigo,
        );
      } catch (_) {
        estructura = PlanNutriEstructura(
          codigoPlanNutricional: widget.plan.codigo,
          tituloPlan: widget.plan.tituloPlan,
          objetivoPlan: widget.plan.objetivoPlan,
          planIndicaciones: widget.plan.planIndicaciones,
          planIndicacionesVisibleUsuario:
              widget.plan.planIndicacionesVisibleUsuario,
          semanas: _buildDefaultWeeks(
            _parseWeekCount(),
            ingestasTipo: ingestasConfiguradas,
          ),
        );
      }

      if (estructura.semanas.isEmpty) {
        estructura.semanas = _buildDefaultWeeks(
          _parseWeekCount(),
          ingestasTipo: ingestasConfiguradas,
        );
      }

      _tituloCtrl.text = estructura.tituloPlan ?? '';
      _objetivoCtrl.text = estructura.objetivoPlan ?? '';
      _recomendacionesCtrl.text =
          estructura.planIndicacionesVisibleUsuario ?? '';
      _syncDateControllers();

      final prefs = await SharedPreferences.getInstance();
      final savedShowAll = prefs.getBool(_showAllWeeksKey) ?? false;
      final savedDetailed = prefs.getBool(_detailedWeekViewKey) ?? true;
      _restorePlanViewState(prefs, estructura);

      if (!mounted) return;
      setState(() {
        _alimentos = alimentos;
        _grupos = grupos;
        _ingestasTipo = ingestasConfiguradas;
        _recetasCatalogo = recetasCatalogo;
        _estructura = estructura;
        _recetasSeleccionadas =
            estructura.recetas.map((e) => e.codigoReceta).toSet();
        _loading = false;
        _hasChanges = false;
        _isInitializingData = false;
        _showAllWeeks = savedShowAll;
        _detailedWeekView = savedDetailed;
      });

      await _maybeRestoreDraft();

      if (mounted &&
          widget.openCalendarBuilderOnStart &&
          !_calendarBuilderOpened) {
        _calendarBuilderOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _openCalendarBuilderMode();
          }
        });
      } else if (mounted &&
          widget.openQuickBuilderOnStart &&
          !_quickBuilderOpened) {
        _quickBuilderOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _openReverseBuilderMode();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _isInitializingData = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error cargando estructura: $e')));
    }
  }

  Future<void> _toggleShowAllWeeks() async {
    final next = !_showAllWeeks;
    setState(() => _showAllWeeks = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showAllWeeksKey, next);
  }

  Future<void> _toggleDetailedWeekView() async {
    final next = !_detailedWeekView;
    setState(() {
      _detailedWeekView = next;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_detailedWeekViewKey, next);
    await _savePlanViewState();
  }

  Set<String> _extractRecetaCategorias(Map<String, dynamic> receta) {
    final categorias = <String>{};

    final rawNombres = (receta['categorias_nombres'] ?? '').toString();
    if (rawNombres.trim().isNotEmpty) {
      categorias.addAll(
        rawNombres.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
      );
    }

    final rawCategorias = receta['categorias'];
    if (rawCategorias is List) {
      categorias.addAll(
        rawCategorias
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty),
      );
    }

    return categorias;
  }

  Future<void> _pickRecetas() async {
    final selected = Set<int>.from(_recetasSeleccionadas);
    final prefs = await SharedPreferences.getInstance();

    bool showSearch = prefs.getBool('plan_nutri_recetas_show_search') ?? true;
    bool showFilter = prefs.getBool('plan_nutri_recetas_show_filter') ?? true;
    final selectedCategorias =
        (prefs.getStringList('plan_nutri_recetas_selected_categories') ??
                <String>[])
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet();
    final searchController = TextEditingController(
      text: prefs.getString('plan_nutri_recetas_search_query') ?? '',
    );

    final allCategorias = _recetasCatalogo
        .map(_extractRecetaCategorias)
        .expand((cats) => cats)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Recetas',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              if (selectedCategorias.isNotEmpty)
                IconButton(
                  tooltip: 'Limpiar filtros',
                  onPressed: () => setLocal(() => selectedCategorias.clear()),
                  icon: const Icon(Icons.cleaning_services_outlined, size: 20),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              IconButton(
                tooltip: showSearch ? 'Ocultar búsqueda' : 'Mostrar búsqueda',
                onPressed: () => setLocal(() => showSearch = !showSearch),
                icon: Icon(
                  showSearch ? Icons.search_off : Icons.search,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: showFilter ? 'Ocultar filtro' : 'Mostrar filtro',
                onPressed: () => setLocal(() => showFilter = !showFilter),
                icon: Icon(
                  showFilter
                      ? Icons.filter_alt_off_outlined
                      : Icons.filter_alt_outlined,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cancelar',
                onPressed: () => Navigator.pop(context, false),
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
            width: 460,
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSearch) ...[
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por título o detalle',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setLocal(() {}),
                  ),
                ],
                if (showFilter && allCategorias.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: allCategorias
                                .map(
                                  (cat) => FilterChip(
                                    selected: selectedCategorias.contains(cat),
                                    label: Text(cat),
                                    onSelected: (v) {
                                      setLocal(() {
                                        if (v) {
                                          selectedCategorias.add(cat);
                                        } else {
                                          selectedCategorias.remove(cat);
                                        }
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Flexible(
                  child: Builder(
                    builder: (context) {
                      final query = searchController.text.trim().toLowerCase();
                      final filtered = _recetasCatalogo.where((receta) {
                        final titulo = (receta['titulo'] ?? '').toString();
                        final detalle =
                            ((receta['texto'] ?? receta['contenido']) ?? '')
                                .toString();
                        final cats = _extractRecetaCategorias(receta);

                        final matchQuery = query.isEmpty ||
                            titulo.toLowerCase().contains(query) ||
                            detalle.toLowerCase().contains(query);
                        final matchCats = selectedCategorias.isEmpty ||
                            cats.any(selectedCategorias.contains);

                        return matchQuery && matchCats;
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No hay recetas con ese filtro.'),
                          ),
                        );
                      }

                      return ListView(
                        shrinkWrap: true,
                        children: filtered.map((receta) {
                          final codigo = int.tryParse(
                                receta['codigo']?.toString() ?? '0',
                              ) ??
                              0;
                          final titulo = (receta['titulo'] ?? '').toString();

                          return CheckboxListTile(
                            value: selected.contains(codigo),
                            onChanged: (v) {
                              setLocal(() {
                                if (v == true) {
                                  selected.add(codigo);
                                } else {
                                  selected.remove(codigo);
                                }
                              });
                            },
                            title: Text(
                              titulo.isEmpty ? 'Receta $codigo' : titulo,
                              style: const TextStyle(fontSize: 12),
                            ),
                            dense: true,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => setLocal(() => selected.clear()),
              child: const Text('Limpiar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Aceptar'),
                  const SizedBox(width: 8),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: selected.isEmpty ? Colors.grey : Colors.green,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      selected.length.toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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

    await prefs.setBool('plan_nutri_recetas_show_search', showSearch);
    await prefs.setBool('plan_nutri_recetas_show_filter', showFilter);
    await prefs.setStringList(
      'plan_nutri_recetas_selected_categories',
      selectedCategorias.toList(),
    );
    await prefs.setString(
      'plan_nutri_recetas_search_query',
      searchController.text,
    );
    searchController.dispose();

    if (ok == true) {
      setState(() {
        _recetasSeleccionadas = selected;
      });
      _markDirty();
    }
  }

  Future<void> _addItem(PlanNutriDia dia, PlanNutriIngesta ingesta) async {
    List<Alimento> selectedAlimentos = [];
    final diaTrim = dia.nombreDia.trim();
    final diaCompleto = diaTrim.isEmpty ? '?' : diaTrim;
    final descripcionCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController(text: '1');
    final unidadCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    bool addToCatalog = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Añadir a $diaCompleto para ${ingesta.tipoIngesta}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cancelar',
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                ),
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            height: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () async {
                      final picked = await showDialog<List<Alimento>>(
                        context: context,
                        builder: (ctx) => _AlimentoCatalogPickerDialog(
                          alimentos: _alimentos,
                          grupos: _grupos,
                          allowMultiple: false,
                        ),
                      );
                      if (picked != null && picked.isNotEmpty) {
                        setLocal(() {
                          selectedAlimentos = picked;
                          if (descripcionCtrl.text.trim().isEmpty &&
                              selectedAlimentos.length == 1) {
                            descripcionCtrl.text =
                                selectedAlimentos.first.nombre;
                          }
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Alimento del catálogo',
                        border: const OutlineInputBorder(),
                        suffixIcon: selectedAlimentos.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () =>
                                    setLocal(() => selectedAlimentos = []),
                              )
                            : const Icon(Icons.search),
                      ),
                      child: Text(
                        selectedAlimentos.isEmpty
                            ? 'Toca para seleccionar...'
                            : (selectedAlimentos.length == 1
                                ? selectedAlimentos.first.nombre
                                : '${selectedAlimentos.length} alimentos seleccionados'),
                        style: TextStyle(
                          color: selectedAlimentos.isEmpty
                              ? Colors.grey.shade500
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descripcionCtrl,
                    minLines: 4,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descripción manual',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  if (selectedAlimentos.isEmpty &&
                      descripcionCtrl.text.trim().isNotEmpty)
                    CheckboxListTile(
                      value: addToCatalog,
                      onChanged: (v) =>
                          setLocal(() => addToCatalog = v ?? true),
                      title: const Text('Añadir al catálogo'),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cantidadCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Cantidad',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: unidadCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Unidad',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notasCtrl,
                    minLines: 3,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notas',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final selectedCodigos =
        selectedAlimentos.map((a) => a.codigo).whereType<int>().toSet();
    int? codigoAlimento =
        selectedAlimentos.length == 1 ? selectedAlimentos.first.codigo : null;
    if (codigoAlimento == null &&
        descripcionCtrl.text.trim().isNotEmpty &&
        addToCatalog) {
      final nombreNuevo = descripcionCtrl.text.trim();
      final existing = _alimentos.where(
        (a) => a.nombre.toLowerCase() == nombreNuevo.toLowerCase(),
      );
      if (existing.isNotEmpty) {
        codigoAlimento = existing.first.codigo;
      } else {
        try {
          final nuevoAlimento = Alimento(nombre: nombreNuevo, activo: 1);
          final saved = await _apiService.saveAlimento(nuevoAlimento);
          if (saved) {
            if (mounted) {
              try {
                final updated = await _apiService.getAlimentos(
                  soloActivos: true,
                );
                setState(() {
                  _alimentos = updated;
                });
                final created = updated.where(
                  (a) => a.nombre.toLowerCase() == nombreNuevo.toLowerCase(),
                );
                if (created.isNotEmpty) {
                  codigoAlimento = created.first.codigo;
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error recargando alimentos: $e'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No se pudo crear el alimento en el catálogo'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al crear alimento: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }

    final descripcionFinal = descripcionCtrl.text.trim().isEmpty
        ? null
        : descripcionCtrl.text.trim();

    int added = 0;
    int duplicates = 0;

    setState(() {
      if (selectedCodigos.length > 1) {
        for (final alimento in selectedAlimentos) {
          final codigo = alimento.codigo;
          if (codigo == null) continue;
          final itemDescripcion = descripcionFinal ?? alimento.nombre;
          if (_ingestaContainsDuplicateItem(
            ingesta: ingesta,
            codigoAlimento: codigo,
            descripcionManual: itemDescripcion,
          )) {
            duplicates++;
            continue;
          }
          ingesta.items.add(
            PlanNutriItem(
              codigoAlimento: codigo,
              descripcionManual: itemDescripcion,
              cantidad: cantidadCtrl.text.trim().isEmpty
                  ? null
                  : cantidadCtrl.text.trim(),
              unidad: unidadCtrl.text.trim().isEmpty
                  ? null
                  : unidadCtrl.text.trim(),
              notas:
                  notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
              orden: ingesta.items.length + 1,
            ),
          );
          added++;
        }
      } else {
        if (_ingestaContainsDuplicateItem(
          ingesta: ingesta,
          codigoAlimento: codigoAlimento,
          descripcionManual: descripcionFinal,
        )) {
          duplicates++;
        } else {
          ingesta.items.add(
            PlanNutriItem(
              codigoAlimento: codigoAlimento,
              descripcionManual: descripcionFinal,
              cantidad: cantidadCtrl.text.trim().isEmpty
                  ? null
                  : cantidadCtrl.text.trim(),
              unidad: unidadCtrl.text.trim().isEmpty
                  ? null
                  : unidadCtrl.text.trim(),
              notas:
                  notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
              orden: ingesta.items.length + 1,
            ),
          );
          added++;
        }
      }
      _reindexIngestaItems(ingesta);
    });

    if (added > 0) {
      _markDirty();
    }

    if (duplicates > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added > 0
                ? 'Se añadieron $added alimentos. $duplicates ya existían en esta ingesta.'
                : 'Los alimentos seleccionados ya existen en esta ingesta.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _addMultipleItems(
    PlanNutriDia dia,
    PlanNutriIngesta ingesta,
  ) async {
    final picked = await showDialog<List<Alimento>>(
      context: context,
      builder: (ctx) => _AlimentoCatalogPickerDialog(
        alimentos: _alimentos,
        grupos: _grupos,
        allowMultiple: true,
      ),
    );
    if (picked == null || picked.isEmpty) return;

    int added = 0;
    int duplicates = 0;
    setState(() {
      for (final alimento in picked) {
        if (_ingestaContainsDuplicateItem(
          ingesta: ingesta,
          codigoAlimento: alimento.codigo,
          descripcionManual: alimento.nombre,
        )) {
          duplicates++;
          continue;
        }
        ingesta.items.add(
          PlanNutriItem(
            codigoAlimento: alimento.codigo,
            descripcionManual: alimento.nombre,
            orden: ingesta.items.length + 1,
          ),
        );
        added++;
      }
      _reindexIngestaItems(ingesta);
    });

    if (added > 0) _markDirty();
    if (!mounted) return;

    if (added > 0 || duplicates > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added > 0 && duplicates > 0
                ? 'Añadidos $added alimentos. $duplicates ya existían.'
                : added > 0
                    ? 'Añadidos $added alimentos.'
                    : 'Los alimentos seleccionados ya existen en esta ingesta.',
          ),
          backgroundColor:
              duplicates > 0 && added == 0 ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  Future<void> _editItem(
    PlanNutriDia dia,
    PlanNutriIngesta ingesta,
    PlanNutriItem item,
  ) async {
    Alimento? selectedAlimento;
    if (item.codigoAlimento != null) {
      final found = _alimentos.where((a) => a.codigo == item.codigoAlimento);
      if (found.isNotEmpty) {
        selectedAlimento = found.first;
      }
    }

    final descripcionCtrl = TextEditingController(
      text: item.descripcionManual ?? '',
    );
    final cantidadCtrl = TextEditingController(text: item.cantidad ?? '');
    final unidadCtrl = TextEditingController(text: item.unidad ?? '');
    final notasCtrl = TextEditingController(text: item.notas ?? '');
    bool opcion = (item.opcion ?? '') == 'S';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
          title: Text(
            'Ingesta para ${ingesta.tipoIngesta} de ${dia.nombreDia}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDialog<List<Alimento>>(
                      context: context,
                      builder: (ctx) => _AlimentoCatalogPickerDialog(
                        alimentos: _alimentos,
                        grupos: _grupos,
                        allowMultiple: false,
                      ),
                    );
                    if (picked != null && picked.isNotEmpty) {
                      setLocal(() {
                        selectedAlimento = picked.first;
                        if (descripcionCtrl.text.trim().isEmpty) {
                          descripcionCtrl.text = picked.first.nombre;
                        }
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Alimento del catálogo',
                      border: const OutlineInputBorder(),
                      suffixIcon: selectedAlimento != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setLocal(() => selectedAlimento = null),
                            )
                          : const Icon(Icons.search),
                    ),
                    child: Text(
                      selectedAlimento?.nombre ?? 'Toca para seleccionar...',
                      style: TextStyle(
                        color: selectedAlimento == null
                            ? Colors.grey.shade500
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descripcionCtrl,
                  minLines: 4,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Descripción manual',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cantidadCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: unidadCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Unidad',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                SwitchListTile(
                  value: opcion,
                  onChanged: (v) => setLocal(() => opcion = v),
                  title: const Text('Opción'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final descripcionFinal = descripcionCtrl.text.trim().isEmpty
        ? null
        : descripcionCtrl.text.trim();

    if (_ingestaContainsDuplicateItem(
      ingesta: ingesta,
      codigoAlimento: selectedAlimento?.codigo,
      descripcionManual: descripcionFinal,
      ignoreItem: item,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ese alimento ya existe en esta ingesta.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      item.codigoAlimento = selectedAlimento?.codigo;
      item.descripcionManual = descripcionFinal;
      item.cantidad =
          cantidadCtrl.text.trim().isEmpty ? null : cantidadCtrl.text.trim();
      item.unidad =
          unidadCtrl.text.trim().isEmpty ? null : unidadCtrl.text.trim();
      item.notas = notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim();
      item.opcion = opcion ? 'S' : 'N';
      _reindexIngestaItems(ingesta);
    });
    _markDirty();
  }

  Future<void> _removeIngesta(PlanNutriDia dia, int ingestaIndex) async {
    if (ingestaIndex < 0 || ingestaIndex >= dia.ingestas.length) return;
    if (dia.ingestas.length <= 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se puede quitar la última ingesta del día.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final ingesta = dia.ingestas[ingestaIndex];
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar ingesta'),
        content: Text(
          'Se eliminará la ingesta ${ingesta.tipoIngesta} con todos sus alimentos. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() {
      dia.ingestas.removeAt(ingestaIndex);
      for (var i = 0; i < dia.ingestas.length; i++) {
        dia.ingestas[i].orden = i + 1;
      }
    });
    _markDirty();
  }

  Future<void> _addDiaToSemana(PlanNutriSemana semana) async {
    final existentes = semana.dias.map((d) => d.diaSemana).toSet();
    final faltantes = List<int>.generate(
      _diasNombre.length,
      (i) => i + 1,
    ).where((diaSemana) => !existentes.contains(diaSemana)).toList();

    if (faltantes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La semana ya tiene todos los días.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final selectedDiaSemana = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir día'),
        content: SizedBox(
          width: 320,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: faltantes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final diaSemana = faltantes[index];
              return ListTile(
                title: Text(_diasNombre[diaSemana - 1]),
                onTap: () => Navigator.pop(context, diaSemana),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (selectedDiaSemana == null) return;

    setState(() {
      semana.dias.add(
        PlanNutriDia(
          diaSemana: selectedDiaSemana,
          nombreDia: _diasNombre[selectedDiaSemana - 1],
          ingestas: List<PlanNutriIngesta>.generate(
            _ingestasTipo.length,
            (idx) => PlanNutriIngesta(
              tipoIngesta: _ingestasTipo[idx],
              orden: idx + 1,
            ),
          ),
        ),
      );
      semana.dias.sort((a, b) => a.diaSemana.compareTo(b.diaSemana));
    });
    _markDirty();
    unawaited(_savePlanViewState());
  }

  Future<void> _deleteDiaFromSemana(
    PlanNutriSemana semana,
    PlanNutriDia dia,
  ) async {
    if (semana.dias.length <= 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debe quedar al menos un día en la semana.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar día'),
        content: Text(
          'Se eliminará ${dia.nombreDia} con todas sus ingestas. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() {
      semana.dias.removeWhere((d) => d.diaSemana == dia.diaSemana);
      semana.dias.sort((a, b) => a.diaSemana.compareTo(b.diaSemana));
    });
    _markDirty();
    unawaited(_savePlanViewState());
  }

  Future<void> _copyDiaToOtherDays(
    PlanNutriSemana semana,
    PlanNutriDia sourceDia,
  ) async {
    if (sourceDia.ingestas.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este día no tiene ingestas para copiar.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final targetDays = semana.dias
        .where((d) => d.diaSemana != sourceDia.diaSemana)
        .toList()
      ..sort((a, b) => a.diaSemana.compareTo(b.diaSemana));

    if (targetDays.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay otros días en esta semana.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final sourceMeals = sourceDia.ingestas
        .map((i) => i.tipoIngesta)
        .where((m) => m.trim().isNotEmpty)
        .toList();
    final selectedDays = <int>{...targetDays.map((d) => d.diaSemana)};
    final mealsByDay = <int, Set<String>>{
      for (final day in targetDays) day.diaSemana: {...sourceMeals},
    };

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Copiar ${sourceDia.nombreDia}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cancelar',
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                ),
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setLocal(() {
                          selectedDays
                            ..clear()
                            ..addAll(targetDays.map((d) => d.diaSemana));
                          for (final day in targetDays) {
                            mealsByDay[day.diaSemana] = {...sourceMeals};
                          }
                        }),
                        child: const Text('Todos'),
                      ),
                      TextButton(
                        onPressed: () => setLocal(() {
                          selectedDays.clear();
                        }),
                        child: const Text('Ninguno'),
                      ),
                    ],
                  ),
                  ...targetDays.map((targetDay) {
                    final selected = selectedDays.contains(targetDay.diaSemana);
                    final selectedMeals =
                        mealsByDay[targetDay.diaSemana] ?? <String>{};
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        title: CheckboxListTile(
                          value: selected,
                          onChanged: (v) => setLocal(() {
                            if (v == true) {
                              selectedDays.add(targetDay.diaSemana);
                              mealsByDay[targetDay.diaSemana] = {
                                ...sourceMeals,
                              };
                            } else {
                              selectedDays.remove(targetDay.diaSemana);
                            }
                          }),
                          title: Text(targetDay.nombreDia),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        children: sourceMeals.map((meal) {
                          final mealSelected = selectedMeals.contains(meal);
                          return CheckboxListTile(
                            value: mealSelected,
                            onChanged: selected
                                ? (v) => setLocal(() {
                                      final set =
                                          mealsByDay[targetDay.diaSemana] ??
                                              <String>{};
                                      if (v == true) {
                                        set.add(meal);
                                      } else {
                                        set.remove(meal);
                                      }
                                      mealsByDay[targetDay.diaSemana] = set;
                                    })
                                : null,
                            title: Text(meal),
                            dense: true,
                            contentPadding: const EdgeInsets.only(
                              left: 16,
                              right: 8,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: selectedDays.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Copiar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || selectedDays.isEmpty) return;

    setState(() {
      for (final targetDay in targetDays) {
        if (!selectedDays.contains(targetDay.diaSemana)) continue;
        final selectedMeals = mealsByDay[targetDay.diaSemana] ?? <String>{};
        for (final sourceMeal in sourceDia.ingestas) {
          if (!selectedMeals.contains(sourceMeal.tipoIngesta)) continue;

          final clonedItems = sourceMeal.items
              .map(
                (item) => PlanNutriItem(
                  codigoAlimento: item.codigoAlimento,
                  alimentoNombre: item.alimentoNombre,
                  descripcionManual: item.descripcionManual,
                  cantidad: item.cantidad,
                  unidad: item.unidad,
                  orden: item.orden,
                  notas: item.notas,
                ),
              )
              .toList();

          final targetMeal = targetDay.ingestas
              .where((m) => m.tipoIngesta == sourceMeal.tipoIngesta)
              .firstOrNull;

          if (targetMeal != null) {
            targetMeal.observaciones = sourceMeal.observaciones;
            targetMeal.items = clonedItems;
          } else {
            targetDay.ingestas.add(
              PlanNutriIngesta(
                tipoIngesta: sourceMeal.tipoIngesta,
                orden: targetDay.ingestas.length + 1,
                observaciones: sourceMeal.observaciones,
                items: clonedItems,
              ),
            );
          }
        }

        targetDay.ingestas.sort((a, b) {
          final idxA = _ingestasTipo.indexOf(a.tipoIngesta);
          final idxB = _ingestasTipo.indexOf(b.tipoIngesta);
          if (idxA == -1 && idxB == -1) {
            return a.orden.compareTo(b.orden);
          }
          if (idxA == -1) return 1;
          if (idxB == -1) return -1;
          return idxA.compareTo(idxB);
        });
        for (var i = 0; i < targetDay.ingestas.length; i++) {
          targetDay.ingestas[i].orden = i + 1;
        }
      }
    });

    _markDirty();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${sourceDia.nombreDia} copiado a ${selectedDays.length} día${selectedDays.length == 1 ? '' : 's'}.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _itemLabel(PlanNutriItem item) {
    if ((item.descripcionManual ?? '').trim().isNotEmpty) {
      return item.descripcionManual!;
    }
    return 'Sin descripción';
  }

  String _normalizeTextKey(String value) {
    return value.trim().toLowerCase();
  }

  bool _ingestaContainsDuplicateItem({
    required PlanNutriIngesta ingesta,
    required int? codigoAlimento,
    required String? descripcionManual,
    PlanNutriItem? ignoreItem,
  }) {
    final normalizedDesc = _normalizeTextKey(descripcionManual ?? '');
    for (final existing in ingesta.items) {
      if (ignoreItem != null && identical(existing, ignoreItem)) {
        continue;
      }

      if (codigoAlimento != null && existing.codigoAlimento == codigoAlimento) {
        return true;
      }

      final existingDesc = _normalizeTextKey(
        existing.descripcionManual ?? existing.alimentoNombre ?? '',
      );
      if (codigoAlimento == null &&
          normalizedDesc.isNotEmpty &&
          existing.codigoAlimento == null &&
          existingDesc == normalizedDesc) {
        return true;
      }
    }
    return false;
  }

  void _reindexIngestaItems(PlanNutriIngesta ingesta) {
    for (var i = 0; i < ingesta.items.length; i++) {
      ingesta.items[i].orden = i + 1;
    }
  }

  void _moveItemInIngesta(PlanNutriIngesta ingesta, int index, int delta) {
    final newIndex = index + delta;
    if (index < 0 ||
        index >= ingesta.items.length ||
        newIndex < 0 ||
        newIndex >= ingesta.items.length) {
      return;
    }

    setState(() {
      final item = ingesta.items.removeAt(index);
      ingesta.items.insert(newIndex, item);
      _reindexIngestaItems(ingesta);
    });
    _markDirty();
  }

  Future<void> _copyIngestaToOtherDays(
    PlanNutriSemana semana,
    PlanNutriDia sourceDia,
    PlanNutriIngesta ingesta,
  ) async {
    if (ingesta.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta ingesta no tiene alimentos que copiar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final otherDays =
        semana.dias.where((d) => d.diaSemana != sourceDia.diaSemana).toList();
    if (otherDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay otros días en esta semana.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // All days selected by default
    final selected = <int>{...otherDays.map((d) => d.diaSemana)};

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Copiar ${ingesta.tipoIngesta}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Cancelar',
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                ),
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecciona los días donde copiar esta ingesta:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setLocal(
                        () => selected
                          ..clear()
                          ..addAll(otherDays.map((d) => d.diaSemana)),
                      ),
                      child: const Text('Todos'),
                    ),
                    TextButton(
                      onPressed: () => setLocal(() => selected.clear()),
                      child: const Text('Ninguno'),
                    ),
                  ],
                ),
                ...otherDays.map(
                  (day) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: selected.contains(day.diaSemana),
                    title: Text(day.nombreDia),
                    onChanged: (v) => setLocal(() {
                      if (v == true) {
                        selected.add(day.diaSemana);
                      } else {
                        selected.remove(day.diaSemana);
                      }
                    }),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed:
                  selected.isEmpty ? null : () => Navigator.pop(context, true),
              child: const Text('Copiar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || selected.isEmpty) return;

    setState(() {
      for (final targetDia in semana.dias) {
        if (!selected.contains(targetDia.diaSemana)) continue;
        final targetIngesta = targetDia.ingestas
            .where((ing) => ing.tipoIngesta == ingesta.tipoIngesta)
            .firstOrNull;
        if (targetIngesta == null) continue;
        targetIngesta.items = ingesta.items
            .map(
              (item) => PlanNutriItem(
                codigoAlimento: item.codigoAlimento,
                alimentoNombre: item.alimentoNombre,
                descripcionManual: item.descripcionManual,
                cantidad: item.cantidad,
                unidad: item.unidad,
                orden: item.orden,
                notas: item.notas,
              ),
            )
            .toList();
      }
    });
    _markDirty();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ingesta.tipoIngesta} copiada a ${selected.length} día${selected.length == 1 ? '' : 's'}.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ignore: unused_element
  Future<void> _generatePdf() async {
    final estructura = _estructura;
    if (estructura == null) return;

    if (_saving) return;

    if (_hasChanges) {
      final ok = await _saveQuiet();
      if (!ok) return;
    }

    if (!mounted) return;
    await PlanNutriPdfService.generateWithOptions(
      context: context,
      apiService: _apiService,
      plan: widget.plan,
      estructura: estructura,
      recetasCatalogo: _recetasCatalogo,
      recetasSeleccionadas: _recetasSeleccionadas,
      recomendaciones: _recomendacionesCtrl.text.trim(),
    );
  }

  // ignore: unused_element
  Future<void> _generateWord() async {
    final estructura = _estructura;
    if (estructura == null) return;

    if (_saving) return;

    if (_hasChanges) {
      final ok = await _saveQuiet();
      if (!ok) return;
    }

    if (!mounted) return;
    await PlanNutriWordService.generateWithOptions(
      context: context,
      apiService: _apiService,
      plan: widget.plan,
      estructura: estructura,
      recetasCatalogo: _recetasCatalogo,
      recetasSeleccionadas: _recetasSeleccionadas,
      recomendaciones: _recomendacionesCtrl.text.trim(),
    );
  }

  Future<void> _openReverseBuilderMode() async {
    final estructura = _estructura;
    if (estructura == null) return;

    estructura.tituloPlan = _tituloCtrl.text.trim();
    estructura.objetivoPlan = _objetivoCtrl.text.trim();
    estructura.planIndicacionesVisibleUsuario =
        _recomendacionesCtrl.text.trim();

    final updated = await Navigator.of(context).push<PlanNutriEstructura>(
      MaterialPageRoute(
        builder: (_) => PlanNutriReverseBuilderScreen(
          initialEstructura: estructura,
          alimentos: _alimentos,
          grupos: _grupos,
          planCodigo: widget.plan.codigo,
        ),
      ),
    );

    if (!mounted || updated == null) return;

    setState(() {
      _estructura = updated;
    });
    _markDirty();
  }

  Future<void> _openCalendarBuilderMode() async {
    final estructura = _estructura;
    if (estructura == null) return;

    if (widget.plan.desde == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Define la fecha de inicio del plan para usar calendario.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final targets = _buildCalendarTargets(estructura);
    if (targets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No hay días de semanas para mostrar en el calendario.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedDate = await showDialog<DateTime>(
      context: context,
      builder: (_) => _PlanNutriCalendarPickerDialog(
        targets: targets,
        initialMonth: targets.keys.first,
      ),
    );

    if (!mounted || selectedDate == null) return;

    final target = targets[_dateOnly(selectedDate)];
    if (target == null) return;

    final updated = await Navigator.of(context).push<PlanNutriEstructura>(
      MaterialPageRoute(
        builder: (_) => PlanNutriReverseBuilderScreen(
          initialEstructura: estructura,
          alimentos: _alimentos,
          grupos: _grupos,
          planCodigo: widget.plan.codigo,
          focusWeekIndex: target.weekIndex,
          focusDayIndex: target.dayIndex,
          focusDate: selectedDate,
        ),
      ),
    );

    if (!mounted || updated == null) return;

    setState(() {
      _estructura = updated;
    });
    _markDirty();
  }

  /// Saves the plan in place without navigating away (used before PDF generation).
  Future<bool> _saveQuiet() async {
    final estructura = _estructura;
    if (estructura == null) return false;

    setState(() {
      _saving = true;
    });

    estructura.tituloPlan = _tituloCtrl.text.trim();
    estructura.objetivoPlan = _objetivoCtrl.text.trim();
    estructura.planIndicacionesVisibleUsuario =
        _recomendacionesCtrl.text.trim();
    widget.plan.tituloPlan = estructura.tituloPlan;
    widget.plan.objetivoPlan = estructura.objetivoPlan;
    widget.plan.planIndicacionesVisibleUsuario =
        estructura.planIndicacionesVisibleUsuario;
    estructura.recetas = _recetasSeleccionadas.toList().asMap().entries.map((
      e,
    ) {
      final receta = _recetasCatalogo.firstWhere(
        (r) => int.tryParse(r['codigo']?.toString() ?? '0') == e.value,
        orElse: () => <String, dynamic>{},
      );
      return PlanNutriRecetaVinculada(
        codigoReceta: e.value,
        recetaTitulo: receta['titulo']?.toString(),
        orden: e.key + 1,
      );
    }).toList();

    bool success = false;
    try {
      final planUpdated = await _apiService.updatePlan(widget.plan, null);
      if (!planUpdated) {
        throw Exception(
            'La API no confirmó el guardado de los datos del plan.');
      }
      final saved = await _apiService.savePlanNutriEstructura(estructura);
      if (!saved) {
        throw Exception('La API no confirmó el guardado de la estructura.');
      }
      _draftSaveDebounce?.cancel();
      await _clearDraft();
      if (!mounted) return false;
      setState(() {
        _hasChanges = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estructura del plan guardada'),
          backgroundColor: Colors.green,
        ),
      );
      success = true;
    } catch (e) {
      if (!mounted) return false;
      final errorText = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorText), backgroundColor: Colors.red),
      );
      await _showSaveErrorDialog(errorText);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
    return success;
  }

  Future<void> _save() async {
    final estructura = _estructura;
    if (estructura == null) return;

    setState(() {
      _saving = true;
    });

    estructura.tituloPlan = _tituloCtrl.text.trim();
    estructura.objetivoPlan = _objetivoCtrl.text.trim();
    estructura.planIndicacionesVisibleUsuario =
        _recomendacionesCtrl.text.trim();
    widget.plan.tituloPlan = estructura.tituloPlan;
    widget.plan.objetivoPlan = estructura.objetivoPlan;
    widget.plan.planIndicacionesVisibleUsuario =
        estructura.planIndicacionesVisibleUsuario;
    estructura.recetas = _recetasSeleccionadas.toList().asMap().entries.map((
      e,
    ) {
      final receta = _recetasCatalogo.firstWhere(
        (r) => int.tryParse(r['codigo']?.toString() ?? '0') == e.value,
        orElse: () => <String, dynamic>{},
      );
      return PlanNutriRecetaVinculada(
        codigoReceta: e.value,
        recetaTitulo: receta['titulo']?.toString(),
        orden: e.key + 1,
      );
    }).toList();

    try {
      final planUpdated = await _apiService.updatePlan(widget.plan, null);
      if (!planUpdated) {
        throw Exception(
            'La API no confirmó el guardado de los datos del plan.');
      }
      final saved = await _apiService.savePlanNutriEstructura(estructura);
      if (!saved) {
        throw Exception('La API no confirmó el guardado de la estructura.');
      }
      _draftSaveDebounce?.cancel();
      await _clearDraft();
      _hasChanges = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estructura del plan guardada'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final errorText = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorText), backgroundColor: Colors.red),
      );
      await _showSaveErrorDialog(errorText);
    } finally {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
    }
  }

  String _recetaTituloByCodigo(int codigo) {
    final receta = _recetasCatalogo.firstWhere(
      (r) => int.tryParse(r['codigo']?.toString() ?? '0') == codigo,
      orElse: () => <String, dynamic>{},
    );
    return (receta['titulo'] ?? 'Receta $codigo').toString();
  }

  void _desvincularReceta(int codigo) {
    setState(() {
      _recetasSeleccionadas.remove(codigo);
    });
    _markDirty();
  }

  int _ingestasConAlimentos(PlanNutriDia dia) {
    return dia.ingestas.where((i) => i.items.isNotEmpty).length;
  }

  bool _isDiaCompleto(PlanNutriDia dia) {
    if (dia.ingestas.isEmpty) return false;
    return dia.ingestas.every((ingesta) => ingesta.items.isNotEmpty);
  }

  int _diasCompletos(PlanNutriSemana semana) {
    return semana.dias.where(_isDiaCompleto).length;
  }

  String _compactDayLabel(String dayName) {
    final normalized = dayName.trim().toLowerCase();
    if (normalized.startsWith('mi')) return 'X';
    if (normalized.startsWith('ju')) return 'J';
    if (normalized.isEmpty) return '?';
    return normalized.substring(0, 1).toUpperCase();
  }

  void _ensureCompactSelection(List<MapEntry<int, PlanNutriSemana>> weeks) {
    if (weeks.isEmpty) {
      _compactWeekIndex = null;
      _compactDayIndex = null;
      return;
    }

    final validWeek = weeks.any((w) => w.key == _compactWeekIndex);
    if (!validWeek) {
      _compactWeekIndex = weeks.first.key;
      _compactDayIndex = 0;
      return;
    }

    final selectedWeek = weeks.firstWhere((w) => w.key == _compactWeekIndex);
    final maxDay = selectedWeek.value.dias.length - 1;
    if (_compactDayIndex == null ||
        _compactDayIndex! < 0 ||
        _compactDayIndex! > maxDay) {
      _compactDayIndex = maxDay >= 0 ? 0 : null;
    }
  }

  Future<void> _onDiaLongPress(PlanNutriSemana semana, PlanNutriDia dia) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('Copiar día'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar día'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Añadir día'),
              onTap: () => Navigator.pop(context, 'add'),
            ),
          ],
        ),
      ),
    );

    if (action == 'copy') {
      await _copyDiaToOtherDays(semana, dia);
    } else if (action == 'delete') {
      await _deleteDiaFromSemana(semana, dia);
    } else if (action == 'add') {
      await _addDiaToSemana(semana);
    }
  }

  Widget _buildIngestaCard({
    required int weekIndex,
    required int dayIndex,
    required PlanNutriSemana semana,
    required PlanNutriDia dia,
    required PlanNutriIngesta ingesta,
    required int ingestaIndex,
  }) {
    final compactIngestaKey = _ingestaKey(weekIndex, dayIndex, ingestaIndex);
    final hasMultipleItems = ingesta.items.length > 1;
    final expanded = _expandedIngestas.contains(compactIngestaKey);

    Widget buildItemRow(PlanNutriItem item, int i) {
      return Dismissible(
        key: ValueKey('item_${compactIngestaKey}_$i'),
        direction: DismissDirection.startToEnd,
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        onDismissed: (_) {
          setState(() {
            ingesta.items.removeAt(i);
            _reindexIngestaItems(ingesta);
          });
          _markDirty();
        },
        child: ListTile(
          dense: true,
          minVerticalPadding: 0,
          visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
          contentPadding: EdgeInsets.zero,
          onTap: () => _editItem(dia, ingesta, item),
          title: Text(
            _itemLabel(item),
            style: const TextStyle(fontSize: 13),
          ),
          subtitle: ((item.cantidad ?? '').isNotEmpty ||
                  (item.unidad ?? '').isNotEmpty ||
                  (item.notas ?? '').isNotEmpty)
              ? Text(
                  [
                    if ((item.cantidad ?? '').isNotEmpty) item.cantidad!,
                    if ((item.unidad ?? '').isNotEmpty) item.unidad!,
                    if ((item.notas ?? '').isNotEmpty) item.notas!,
                  ].join(' • '),
                  style: const TextStyle(fontSize: 11),
                )
              : null,
          trailing: PopupMenuButton<_ItemAction>(
            icon: const Icon(Icons.more_vert, size: 18),
            tooltip: 'Acciones',
            onSelected: (action) {
              switch (action) {
                case _ItemAction.up:
                  _moveItemInIngesta(ingesta, i, -1);
                case _ItemAction.down:
                  _moveItemInIngesta(ingesta, i, 1);
                case _ItemAction.edit:
                  _editItem(dia, ingesta, item);
                case _ItemAction.delete:
                  setState(() {
                    ingesta.items.removeAt(i);
                    _reindexIngestaItems(ingesta);
                  });
                  _markDirty();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: _ItemAction.up,
                enabled: i > 0,
                child: const Row(
                  children: [
                    Icon(Icons.arrow_upward, size: 18),
                    SizedBox(width: 8),
                    Text('Subir'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _ItemAction.down,
                enabled: i < ingesta.items.length - 1,
                child: const Row(
                  children: [
                    Icon(Icons.arrow_downward, size: 18),
                    SizedBox(width: 8),
                    Text('Bajar'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _ItemAction.edit,
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Editar'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: _ItemAction.delete,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Eliminar'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final header = Row(
      children: [
        Text(
          ingesta.tipoIngesta,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.deepPurple.shade600,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 6),
        _countBadge(
          count: ingesta.items.length,
          color: ingesta.items.isEmpty ? Colors.grey.shade500 : Colors.green,
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Copiar a otros días',
          color: Colors.pink,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          onPressed: () => _copyIngestaToOtherDays(semana, dia, ingesta),
          icon: const Icon(Icons.copy_all_outlined, size: 18),
        ),
        IconButton(
          tooltip: 'Quitar ingesta',
          color: Colors.red,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          onPressed: () => _removeIngesta(dia, ingestaIndex),
          icon: const Icon(Icons.delete_outline, size: 18),
        ),
        IconButton(
          tooltip: 'Añadir alimento',
          color: Colors.green,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          onPressed: () => _addItem(dia, ingesta),
          icon: const Icon(Icons.add_circle_outline, size: 18),
        ),
        IconButton(
          tooltip: 'Añadir varios alimentos',
          color: const Color(0xFF1B5E20),
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          onPressed: () => _addMultipleItems(dia, ingesta),
          icon: const Icon(Icons.playlist_add, size: 18),
        ),
      ],
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasMultipleItems) header,
            if (hasMultipleItems)
              ExpansionTile(
                key: ValueKey('plan_nutri_compact_ingesta_$compactIngestaKey'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 4),
                dense: true,
                initiallyExpanded: expanded,
                onExpansionChanged: (value) {
                  setState(() {
                    if (value) {
                      _expandedIngestas.add(compactIngestaKey);
                    } else {
                      _expandedIngestas.remove(compactIngestaKey);
                    }
                  });
                  unawaited(_savePlanViewState());
                },
                title: header,
                children: ingesta.items
                    .asMap()
                    .entries
                    .map((entry) => buildItemRow(entry.value, entry.key))
                    .toList(),
              )
            else if (ingesta.items.isEmpty)
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4),
                  Text(
                    'Sin alimentos en esta ingesta',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              )
            else ...[
              const SizedBox(height: 4),
              buildItemRow(ingesta.items.first, 0),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final estructura = _estructura;
    if (estructura == null) {
      return const Scaffold(body: Center(child: Text('Sin estructura')));
    }

    final visibleWeekEntries = estructura.semanas
        .asMap()
        .entries
        .where((entry) => _showAllWeeks || !_isSemanaCompleted(entry.value))
        .toList();
    if (!_detailedWeekView) {
      _ensureCompactSelection(visibleWeekEntries);
    }

    final pacienteNombre = (widget.plan.nombrePaciente ?? '').trim();
    final pacienteLabel = pacienteNombre.isNotEmpty
        ? pacienteNombre
        : (widget.plan.codigoPaciente != null
            ? 'Paciente #${widget.plan.codigoPaciente}'
            : 'Paciente no disponible');
    final desdeResumen = _formatDateShort(widget.plan.desde);
    final hastaResumen = _formatDateShort(widget.plan.hasta);
    final planHeaderSummary =
        (desdeResumen.isNotEmpty || hastaResumen.isNotEmpty)
            ? '$desdeResumen - $hastaResumen'
            : '';

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: const Text('Estructurar plan nutri'),
          actions: [
            if (!_saving)
              IconButton(
                tooltip: 'Estructurar por calendario',
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: _openCalendarBuilderMode,
              ),
            if (!_saving)
              IconButton(
                tooltip: 'Estructurar rápido',
                icon: const Icon(Icons.ads_click_outlined),
                onPressed: _openReverseBuilderMode,
              ),
            IconButton(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withAlpha(120),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          pacienteLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  margin: EdgeInsets.zero,
                  child: ExpansionTile(
                    key: const ValueKey('plan_nutri_edit_card_datos'),
                    initiallyExpanded: _planDataCardExpanded,
                    onExpansionChanged: (expanded) {
                      if (_planDataCardExpanded == expanded) return;
                      setState(() {
                        _planDataCardExpanded = expanded;
                      });
                      unawaited(_savePlanViewState());
                    },
                    title: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Datos del plan',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (planHeaderSummary.isNotEmpty)
                          Expanded(
                            child: Text(
                              planHeaderSummary,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withAlpha(200),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                        child: Column(
                          children: [
                            TextField(
                              controller: _tituloCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Título',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setState(() {});
                                _markDirty();
                              },
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _objetivoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Objetivo',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setState(() {});
                                _markDirty();
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _desdeCtrl,
                                    readOnly: true,
                                    onTap: () => _pickPlanDate(isStart: true),
                                    decoration: InputDecoration(
                                      labelText: 'Fecha desde',
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        tooltip: 'Seleccionar fecha desde',
                                        onPressed: () =>
                                            _pickPlanDate(isStart: true),
                                        icon: const Icon(
                                          Icons.calendar_today_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _hastaCtrl,
                                    readOnly: true,
                                    onTap: () => _pickPlanDate(isStart: false),
                                    decoration: InputDecoration(
                                      labelText: 'Fecha hasta',
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        tooltip: 'Seleccionar fecha hasta',
                                        onPressed: () =>
                                            _pickPlanDate(isStart: false),
                                        icon: const Icon(
                                          Icons.calendar_today_outlined,
                                        ),
                                      ),
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
                ),
                const SizedBox(height: 10),
                Card(
                  margin: EdgeInsets.zero,
                  child: ExpansionTile(
                    key: const ValueKey('plan_nutri_edit_card_recomendaciones'),
                    initiallyExpanded: _patientRecommendationsCardExpanded,
                    onExpansionChanged: (expanded) {
                      if (_patientRecommendationsCardExpanded == expanded) {
                        return;
                      }
                      setState(() {
                        _patientRecommendationsCardExpanded = expanded;
                      });
                      unawaited(_savePlanViewState());
                    },
                    title: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Recomendaciones paciente',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: (_recomendacionesCtrl.text.trim().isEmpty
                                    ? Colors.red
                                    : Colors.green)
                                .withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_recomendacionesCtrl.text.length}',
                            style: TextStyle(
                              color: _recomendacionesCtrl.text.trim().isEmpty
                                  ? Colors.red
                                  : Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: TextField(
                            controller: _recomendacionesCtrl,
                            maxLines: 12,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              setState(() {});
                              _markDirty();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (_lastDraftSavedAt != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.save_as_outlined, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Borrador guardado ${_draftAgeText()}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                Card(
                  margin: EdgeInsets.zero,
                  child: ExpansionTile(
                    key: const ValueKey('plan_nutri_edit_card_recetas'),
                    initiallyExpanded: _recipesCardExpanded,
                    onExpansionChanged: (expanded) {
                      if (_recipesCardExpanded == expanded) return;
                      setState(() {
                        _recipesCardExpanded = expanded;
                      });
                      unawaited(_savePlanViewState());
                    },
                    title: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Recetas',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _recetasSeleccionadas.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Vincular recetas',
                          onPressed: _pickRecetas,
                          icon: const Icon(Icons.restaurant_menu),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Column(
                          children: [
                            if (_recetasSeleccionadas.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('No hay recetas seleccionadas.'),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _recetasSeleccionadas.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final codigo =
                                      _recetasSeleccionadas.elementAt(index);
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: Text(
                                      _recetaTituloByCodigo(codigo),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: IconButton(
                                      tooltip: 'Desvincular receta',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () =>
                                          _desvincularReceta(codigo),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _addSemana,
                        icon: const Icon(Icons.add),
                        label: const Text('Semana'),
                      ),
                      const Spacer(),
                      Tooltip(
                        message: _detailedWeekView
                            ? 'Vista detallada activa'
                            : 'Vista compacta activa',
                        child: IconButton(
                          icon: Icon(
                            _detailedWeekView
                                ? Icons.view_agenda_outlined
                                : Icons.view_week_outlined,
                            color: _detailedWeekView
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade600,
                          ),
                          style: _detailedWeekView
                              ? IconButton.styleFrom(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withAlpha(25),
                                  side: BorderSide(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    width: 1,
                                  ),
                                )
                              : null,
                          onPressed: _toggleDetailedWeekView,
                        ),
                      ),
                      Tooltip(
                        message: _reorderMode
                            ? 'Desactivar ordenar'
                            : 'Ordenar semanas',
                        child: IconButton(
                          icon: Icon(
                            Icons.swap_vert,
                            color: _reorderMode
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade600,
                          ),
                          style: _reorderMode
                              ? IconButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary.withAlpha(25),
                                  side: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    width: 1,
                                  ),
                                )
                              : null,
                          onPressed: () {
                            setState(() {
                              final activating = !_reorderMode;
                              _reorderMode = !_reorderMode;
                              if (activating && _detailedWeekView) {
                                _expandedWeeks.clear();
                                _expandedDays.clear();
                                for (final controller
                                    in _semanaTileControllers.values) {
                                  controller.collapse();
                                }
                              }
                            });
                            unawaited(_savePlanViewState());
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message:
                            _showAllWeeks ? 'Ocultar completadas' : 'Ver todas',
                        child: IconButton(
                          icon: Icon(
                            _showAllWeeks
                                ? Icons.filter_alt
                                : Icons.filter_alt_off,
                            size: 22,
                            color: _showAllWeeks
                                ? Colors.grey.shade600
                                : Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: _toggleShowAllWeeks,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (!_detailedWeekView)
                  Builder(
                    builder: (context) {
                      if (visibleWeekEntries.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('No hay semanas para mostrar.'),
                        );
                      }

                      final compactWeek = visibleWeekEntries.firstWhere(
                        (entry) => entry.key == _compactWeekIndex,
                        orElse: () => visibleWeekEntries.first,
                      );
                      final compactSemana = compactWeek.value;
                      final hasDays = compactSemana.dias.isNotEmpty;
                      final compactDayIdx = hasDays
                          ? (_compactDayIndex ?? 0)
                              .clamp(0, compactSemana.dias.length - 1)
                          : null;
                      final compactDia =
                          hasDays ? compactSemana.dias[compactDayIdx!] : null;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_reorderMode)
                            ReorderableListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              padding: EdgeInsets.zero,
                              onReorder: _reorderSemanas,
                              children: visibleWeekEntries
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final weekEntry = entry.value;
                                final weekIdx = weekEntry.key;
                                final semana = weekEntry.value;
                                final selected = _compactWeekIndex == weekIdx;
                                return ReorderableDelayedDragStartListener(
                                  key: ValueKey('compact-week-$weekIdx'),
                                  index: entry.key,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.drag_indicator),
                                    title: _buildCompactWeekChip(
                                      context,
                                      weekIdx,
                                      semana,
                                      selected: selected,
                                    ),
                                  ),
                                );
                              }).toList(),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: visibleWeekEntries.map((entry) {
                                final weekIdx = entry.key;
                                final semana = entry.value;
                                final selected = _compactWeekIndex == weekIdx;
                                return _buildCompactWeekChip(
                                  context,
                                  weekIdx,
                                  semana,
                                  selected: selected,
                                  onLongPress: () =>
                                      _onSemanaLongPress(weekIdx, semana),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                compactSemana.dias.asMap().entries.map((entry) {
                              final dayIdx = entry.key;
                              final dia = entry.value;
                              final dayTotal = dia.ingestas.length;
                              final dayWithFoods = _ingestasConAlimentos(dia);
                              final dayComplete =
                                  dayTotal > 0 && dayWithFoods == dayTotal;
                              final selected = compactDayIdx == dayIdx;

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _compactDayIndex = dayIdx;
                                  });
                                  unawaited(_savePlanViewState());
                                },
                                onLongPress: () =>
                                    _onDiaLongPress(compactSemana, dia),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (dayComplete
                                            ? Colors.green
                                            : Colors.red)
                                        .withAlpha(selected ? 45 : 20),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : (dayComplete
                                              ? Colors.green
                                              : Colors.red),
                                      width: selected ? 2.2 : 1,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withAlpha(65),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (selected)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 6),
                                          child: Icon(
                                            Icons.check_circle,
                                            size: 14,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      Text(
                                        _compactDayLabel(dia.nombreDia),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: dayComplete
                                              ? Colors.green.shade800
                                              : Colors.red.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          if (compactDia == null)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child:
                                  Text('La semana seleccionada no tiene días.'),
                            )
                          else
                            ...compactDia.ingestas.asMap().entries.map((entry) {
                              final ingestaIndex = entry.key;
                              final ingesta = entry.value;
                              return _buildIngestaCard(
                                weekIndex: compactWeek.key,
                                dayIndex: compactDayIdx!,
                                semana: compactSemana,
                                dia: compactDia,
                                ingesta: ingesta,
                                ingestaIndex: ingestaIndex,
                              );
                            }),
                        ],
                      );
                    },
                  ),
                if (_detailedWeekView)
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    padding: EdgeInsets.zero,
                    onReorder: _reorderSemanas,
                    proxyDecorator: (child, index, animation) => Material(
                      elevation: 8,
                      shadowColor: Colors.indigo.withAlpha(100),
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).cardColor,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 1,
                          end: 1.02,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    children: estructura.semanas
                        .where(
                          (semana) =>
                              _showAllWeeks || !_isSemanaCompleted(semana),
                        )
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                      final weekIndex = entry.key;
                      final semana = entry.value;
                      final diasCompletos = _diasCompletos(semana);
                      final totalDias = semana.dias.length;
                      final semanaCompleta =
                          totalDias > 0 && diasCompletos == totalDias;
                      final semanaMarcadaCompletada = _isSemanaCompleted(
                        semana,
                      );
                      final weekHarvard = _computeHarvardWeekCompliance(semana);
                      final weekHarvardColor =
                          _harvardWeekComplianceColor(weekHarvard);
                      final weekHarvardSamples = weekHarvard['samples'] as int;
                      final weekHarvardAvg = (weekHarvard['avgScore'] as double)
                          .toStringAsFixed(2);
                      final weekHarvardPercent =
                          weekHarvard['avgPercent'] as int;
                      final weekHarvardFulfilled =
                          weekHarvard['fulfilled'] as bool;
                      final originalWeekIndex = estructura.semanas.indexOf(
                        semana,
                      );
                      final tileController = _semanaTileControllers.putIfAbsent(
                          semana, () => ExpansibleController());

                      Widget cardWidget = GestureDetector(
                        onLongPress: _reorderMode
                            ? null
                            : () => _onSemanaLongPress(
                                  originalWeekIndex,
                                  semana,
                                ),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: semanaMarcadaCompletada
                              ? Colors.blueGrey.withAlpha(50)
                              : null,
                          child: ExpansionTile(
                            key: ValueKey('plan_nutri_week_$originalWeekIndex'),
                            controller: tileController,
                            initiallyExpanded: _expandedWeeks.contains(semana),
                            trailing: const SizedBox.shrink(),
                            onExpansionChanged: (expanded) {
                              setState(() {
                                if (expanded) {
                                  _expandedWeeks.add(semana);
                                } else {
                                  _expandedWeeks.remove(semana);
                                }
                              });
                              unawaited(_savePlanViewState());
                            },
                            collapsedIconColor: semanaMarcadaCompletada
                                ? Colors.blueGrey
                                : Colors.indigo.shade400,
                            iconColor: semanaMarcadaCompletada
                                ? Colors.blueGrey
                                : Colors.indigo.shade400,
                            title: Row(
                              children: [
                                if (_reorderMode)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(
                                      Icons.drag_indicator,
                                      size: 28,
                                      color: semanaMarcadaCompletada
                                          ? Colors.blueGrey.shade300
                                          : Colors.indigo.shade300,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    'Semana ${semana.numeroSemana}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: semanaMarcadaCompletada
                                          ? Colors.blueGrey.shade700
                                          : Colors.indigo.shade700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (semanaCompleta
                                            ? Colors.green
                                            : Colors.red)
                                        .withAlpha(25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$diasCompletos/$totalDias',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: semanaMarcadaCompletada
                                          ? Colors.blueGrey
                                          : semanaCompleta
                                              ? Colors.green
                                              : Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: weekHarvardSamples == 0
                                      ? 'Harvard semanal: sin datos'
                                      : 'Harvard: ${weekHarvardFulfilled ? 'cumple' : 'no cumple'} — media $weekHarvardAvg/4 ($weekHarvardPercent%)',
                                  child: InkWell(
                                    onTap: () =>
                                        _showHarvardWeekComplianceDialog(
                                      context,
                                      semana,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    child: _buildWeekHarvardHeaderSummary(
                                      weekHarvardColor,
                                      weekHarvard['avgScore'] as double,
                                      weekHarvardPercent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    tooltip: _expandedWeeks.contains(semana)
                                        ? 'Plegar'
                                        : 'Desplegar',
                                    icon: Icon(
                                      _expandedWeeks.contains(semana)
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 18,
                                      color: semanaMarcadaCompletada
                                          ? Colors.blueGrey
                                          : Colors.indigo.shade400,
                                    ),
                                    onPressed: () {
                                      if (_expandedWeeks.contains(semana)) {
                                        tileController.collapse();
                                      } else {
                                        tileController.expand();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(semana.titulo ?? ''),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 22,
                                      ),
                                      color: Colors.blue,
                                      tooltip: 'Editar semana',
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      onPressed: () => _editSemana(semana),
                                    ),
                                    if (!semanaMarcadaCompletada)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 22,
                                        ),
                                        color: Colors.green,
                                        tooltip: 'Marcar completada',
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36,
                                        ),
                                        onPressed: () =>
                                            _completeSemana(semana),
                                      ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.copy_all_outlined,
                                        size: 22,
                                      ),
                                      color: Colors.pink,
                                      tooltip: 'Copiar semana completa',
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      onPressed: () => _handleCopySemana(
                                        semana,
                                        partial: false,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.content_copy_outlined,
                                        size: 22,
                                      ),
                                      color: Colors.orange,
                                      tooltip: 'Copiar semana sin...',
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      onPressed: () => _handleCopySemana(
                                        semana,
                                        partial: true,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 22,
                                      ),
                                      color: Colors.red,
                                      tooltip: 'Eliminar semana',
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      onPressed: () =>
                                          _deleteSemana(originalWeekIndex),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            children:
                                semana.dias.asMap().entries.map((diaEntry) {
                              final dayIndex = diaEntry.key;
                              final dia = diaEntry.value;
                              final ingestasConAlimentos =
                                  _ingestasConAlimentos(dia);
                              final totalIngestas = dia.ingestas.length;
                              final diaCompleto = totalIngestas > 0 &&
                                  ingestasConAlimentos == totalIngestas;
                              return ExpansionTile(
                                key: ValueKey(
                                  'plan_nutri_day_${originalWeekIndex}_$dayIndex',
                                ),
                                initiallyExpanded: _expandedDays.contains(
                                  _dayKey(originalWeekIndex, dayIndex),
                                ),
                                onExpansionChanged: (expanded) {
                                  final dayKey = _dayKey(
                                    originalWeekIndex,
                                    dayIndex,
                                  );
                                  setState(() {
                                    if (expanded) {
                                      _expandedDays.add(dayKey);
                                    } else {
                                      _expandedDays.remove(dayKey);
                                    }
                                  });
                                  unawaited(_savePlanViewState());
                                },
                                collapsedIconColor: Colors.teal.shade600,
                                iconColor: Colors.teal.shade600,
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        dia.nombreDia,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.teal.shade700,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Copiar día',
                                      color: Colors.pink,
                                      visualDensity: VisualDensity.compact,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                        width: 28,
                                        height: 28,
                                      ),
                                      padding: EdgeInsets.zero,
                                      iconSize: 18,
                                      onPressed: () =>
                                          _copyDiaToOtherDays(semana, dia),
                                      icon: const Icon(
                                        Icons.copy_all_outlined,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar día',
                                      color: Colors.red,
                                      visualDensity: VisualDensity.compact,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                        width: 28,
                                        height: 28,
                                      ),
                                      padding: EdgeInsets.zero,
                                      iconSize: 18,
                                      onPressed: () =>
                                          _deleteDiaFromSemana(semana, dia),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                    IconButton(
                                      tooltip: 'Añadir día',
                                      color: Colors.blue,
                                      visualDensity: VisualDensity.compact,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                        width: 28,
                                        height: 28,
                                      ),
                                      padding: EdgeInsets.zero,
                                      iconSize: 18,
                                      onPressed: () => _addDiaToSemana(semana),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // Harvard compliance indicator
                                    Builder(builder: (ctx) {
                                      final c = _computeHarvardCompliance(dia);
                                      final tagged = c['taggedItems'] as int;
                                      final compColor =
                                          _harvardComplianceColor(c);
                                      return Tooltip(
                                        message: tagged == 0
                                            ? 'Plato de Harvard: sin alimentos clasificados'
                                            : 'Plato de Harvard — toca para ver el análisis',
                                        child: GestureDetector(
                                          onTap: () =>
                                              _showHarvardComplianceDialog(
                                            context,
                                            dia,
                                            semana: semana,
                                          ),
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            margin:
                                                const EdgeInsets.only(right: 4),
                                            decoration: BoxDecoration(
                                              color: compColor,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: Text('🥗',
                                                  style:
                                                      TextStyle(fontSize: 10)),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                    Text(
                                      '$ingestasConAlimentos/$totalIngestas',
                                      style: TextStyle(
                                        color: diaCompleto
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                children: dia.ingestas.asMap().entries.map((
                                  ingestaEntry,
                                ) {
                                  final ingestaIndex = ingestaEntry.key;
                                  final ingesta = ingestaEntry.value;
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                ingesta.tipoIngesta,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors
                                                      .deepPurple.shade600,
                                                ),
                                              ),
                                              const Spacer(),
                                              IconButton(
                                                tooltip: 'Copiar a otros días',
                                                color: Colors.pink,
                                                onPressed: () =>
                                                    _copyIngestaToOtherDays(
                                                  semana,
                                                  dia,
                                                  ingesta,
                                                ),
                                                icon: const Icon(
                                                  Icons.copy_all_outlined,
                                                  size: 20,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Quitar ingesta',
                                                color: Colors.red,
                                                onPressed: () => _removeIngesta(
                                                  dia,
                                                  ingestaIndex,
                                                ),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 20,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Añadir alimento',
                                                color: Colors.green,
                                                onPressed: () =>
                                                    _addItem(dia, ingesta),
                                                icon: const Icon(
                                                  Icons.add_circle_outline,
                                                  size: 20,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip:
                                                    'Añadir varios alimentos',
                                                color: const Color(0xFF1B5E20),
                                                onPressed: () =>
                                                    _addMultipleItems(
                                                        dia, ingesta),
                                                icon: const Icon(
                                                  Icons.playlist_add,
                                                  size: 20,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (ingesta.items.isEmpty)
                                            const Text(
                                              'Sin alimentos en esta ingesta',
                                            )
                                          else
                                            ...ingesta.items
                                                .asMap()
                                                .entries
                                                .map((
                                              entry,
                                            ) {
                                              final i = entry.key;
                                              final item = entry.value;
                                              // Harvard color indicator
                                              Color? hvColor;
                                              if ((item.harvardColor ?? '')
                                                  .isNotEmpty) {
                                                try {
                                                  final hex = item.harvardColor!
                                                      .replaceFirst('#', '');
                                                  hvColor = Color(int.parse(
                                                      'FF$hex',
                                                      radix: 16));
                                                } catch (_) {}
                                              }
                                              return ListTile(
                                                dense: true,
                                                contentPadding: EdgeInsets.zero,
                                                leading: hvColor != null
                                                    ? Tooltip(
                                                        message:
                                                            item.harvardCategoria ??
                                                                '',
                                                        child: Container(
                                                          width: 10,
                                                          height: 10,
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 4,
                                                                  top: 4),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: hvColor,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                        ),
                                                      )
                                                    : null,
                                                title: Text(_itemLabel(item)),
                                                subtitle: Text(
                                                  [
                                                    if ((item.cantidad ?? '')
                                                        .isNotEmpty)
                                                      item.cantidad!,
                                                    if ((item.unidad ?? '')
                                                        .isNotEmpty)
                                                      item.unidad!,
                                                    if ((item.notas ?? '')
                                                        .isNotEmpty)
                                                      item.notas!,
                                                  ].join(' • '),
                                                ),
                                                trailing: PopupMenuButton<
                                                    _ItemAction>(
                                                  icon: const Icon(
                                                    Icons.more_vert,
                                                    size: 20,
                                                  ),
                                                  tooltip: 'Acciones',
                                                  onSelected: (action) {
                                                    switch (action) {
                                                      case _ItemAction.up:
                                                        _moveItemInIngesta(
                                                          ingesta,
                                                          i,
                                                          -1,
                                                        );
                                                      case _ItemAction.down:
                                                        _moveItemInIngesta(
                                                          ingesta,
                                                          i,
                                                          1,
                                                        );
                                                      case _ItemAction.edit:
                                                        _editItem(
                                                          dia,
                                                          ingesta,
                                                          item,
                                                        );
                                                      case _ItemAction.delete:
                                                        setState(() {
                                                          ingesta.items
                                                              .removeAt(i);
                                                          _reindexIngestaItems(
                                                            ingesta,
                                                          );
                                                        });
                                                        _markDirty();
                                                    }
                                                  },
                                                  itemBuilder: (ctx) => [
                                                    PopupMenuItem(
                                                      value: _ItemAction.up,
                                                      enabled: i > 0,
                                                      child: const Row(
                                                        children: [
                                                          Icon(
                                                            Icons.arrow_upward,
                                                            size: 18,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text('Subir'),
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: _ItemAction.down,
                                                      enabled: i <
                                                          ingesta.items.length -
                                                              1,
                                                      child: const Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .arrow_downward,
                                                            size: 18,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text('Bajar'),
                                                        ],
                                                      ),
                                                    ),
                                                    const PopupMenuDivider(),
                                                    const PopupMenuItem(
                                                      value: _ItemAction.edit,
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.edit_outlined,
                                                            size: 18,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text('Editar'),
                                                        ],
                                                      ),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: _ItemAction.delete,
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .delete_outline,
                                                            size: 18,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text('Eliminar'),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            }).toList(),
                          ),
                        ),
                      );

                      return ReorderableDelayedDragStartListener(
                        key: ObjectKey(semana),
                        index: weekIndex,
                        enabled: _reorderMode,
                        child: cardWidget,
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alimento catalog picker dialog (filter by grupo + search by name)
// ---------------------------------------------------------------------------

class _AlimentoCatalogPickerDialog extends StatefulWidget {
  final List<Alimento> alimentos;
  final List<AlimentoGrupo> grupos;
  final bool allowMultiple;

  const _AlimentoCatalogPickerDialog({
    required this.alimentos,
    required this.grupos,
    this.allowMultiple = true,
  });

  @override
  State<_AlimentoCatalogPickerDialog> createState() =>
      _AlimentoCatalogPickerDialogState();
}

class _CalendarDayTarget {
  final int weekIndex;
  final int dayIndex;
  final int semanaNumero;
  final String diaNombre;
  final _CalendarDayFillStatus fillStatus;
  final bool weekCompleted;

  const _CalendarDayTarget({
    required this.weekIndex,
    required this.dayIndex,
    required this.semanaNumero,
    required this.diaNombre,
    required this.fillStatus,
    required this.weekCompleted,
  });
}

enum _CalendarDayFillStatus { empty, partial, full }

/// Simple row used inside the Harvard info dialog.
class _HarvardInfoRow extends StatelessWidget {
  final String emoji;
  final String seccion;
  final String desc;

  const _HarvardInfoRow({
    required this.emoji,
    required this.seccion,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(seccion,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(desc, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _PlanNutriCalendarPickerDialog extends StatefulWidget {
  final Map<DateTime, _CalendarDayTarget> targets;
  final DateTime initialMonth;

  const _PlanNutriCalendarPickerDialog({
    required this.targets,
    required this.initialMonth,
  });

  @override
  State<_PlanNutriCalendarPickerDialog> createState() =>
      _PlanNutriCalendarPickerDialogState();
}

class _PlanNutriCalendarPickerDialogState
    extends State<_PlanNutriCalendarPickerDialog> {
  late DateTime _visibleMonth;

  static const List<String> _weekDays = [
    'L',
    'M',
    'X',
    'J',
    'V',
    'S',
    'D',
  ];

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Color _tileBackgroundColor(_CalendarDayTarget? target) {
    if (target == null) return Colors.transparent;
    switch (target.fillStatus) {
      case _CalendarDayFillStatus.full:
        return const Color(0xFFE8F5E9);
      case _CalendarDayFillStatus.empty:
        return const Color(0xFFFFEBEE);
      case _CalendarDayFillStatus.partial:
        return const Color(0xFFFFF9C4);
    }
  }

  Color _tileBorderColor(_CalendarDayTarget? target) {
    if (target == null) return Colors.grey.shade300;
    switch (target.fillStatus) {
      case _CalendarDayFillStatus.full:
        return Colors.green.shade300;
      case _CalendarDayFillStatus.empty:
        return Colors.red.shade300;
      case _CalendarDayFillStatus.partial:
        return Colors.amber.shade300;
    }
  }

  @override
  void initState() {
    super.initState();
    _visibleMonth =
        DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
  }

  String _monthLabel(DateTime month) {
    const names = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${names[month.month - 1]} ${month.year}';
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final firstGridDay = firstDayOfMonth.subtract(
      Duration(days: (firstDayOfMonth.weekday - DateTime.monday) % 7),
    );

    return AlertDialog(
      content: SizedBox(
        width: 380,
        height: 560,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Plan',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Mes anterior',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _visibleMonth = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month - 1,
                        1,
                      );
                    });
                  },
                ),
                Text(
                  _monthLabel(_visibleMonth),
                  style: const TextStyle(fontSize: 12),
                ),
                IconButton(
                  tooltip: 'Mes siguiente',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _visibleMonth = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month + 1,
                        1,
                      );
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: _weekDays
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 0.80,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: 42,
                itemBuilder: (context, index) {
                  final date =
                      _dateOnly(firstGridDay.add(Duration(days: index)));
                  final inMonth = date.month == _visibleMonth.month;
                  final target = widget.targets[date];
                  final selectable = target != null;

                  return InkWell(
                    onTap:
                        selectable ? () => Navigator.pop(context, date) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _tileBackgroundColor(target),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _tileBorderColor(target),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: inMonth
                                  ? Colors.black87
                                  : Colors.grey.shade500,
                            ),
                          ),
                          if (target != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'S${target.semanaNumero}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.black54,
                                  ),
                                ),
                                if (target.weekCompleted) ...[
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.check_circle,
                                    size: 9,
                                    color: Colors.green,
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildLegendItem(const Color(0xFFE8F5E9), 'Completo'),
                const SizedBox(width: 10),
                _buildLegendItem(const Color(0xFFFFF9C4), 'Parcial'),
                const SizedBox(width: 10),
                _buildLegendItem(const Color(0xFFFFEBEE), 'Vacío'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.black26),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}

class _AlimentoCatalogPickerDialogState
    extends State<_AlimentoCatalogPickerDialog> {
  late final TextEditingController _searchController;
  final Set<int> _gruposSeleccionados = {};
  bool _showGroupFilter = true;
  bool _showSearchField = true;
  bool _groupDropdownExpanded = false;
  final Set<int> _selectedCodigos = {};

  String _selectedGroupsLabel() {
    if (_gruposSeleccionados.isEmpty) return 'Todos los grupos';
    final selectedNames = widget.grupos
        .where(
          (g) => g.codigo != null && _gruposSeleccionados.contains(g.codigo),
        )
        .map((g) => g.nombre)
        .toList();
    if (selectedNames.length <= 2) {
      return selectedNames.join(', ');
    }
    return '${selectedNames.length} grupos seleccionados';
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadUiState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final showFilter =
        prefs.getBool('alimento_picker_show_filter') ?? _showGroupFilter;
    final showSearch =
        prefs.getBool('alimento_picker_show_search') ?? _showSearchField;
    final storedGroups =
        prefs.getStringList('alimento_picker_selected_groups') ?? [];
    final validGroupIds = widget.grupos
        .where((g) => g.codigo != null)
        .map((g) => g.codigo!)
        .toSet();
    final restoredGroupIds = storedGroups
        .map((id) => int.tryParse(id) ?? 0)
        .where((id) => id > 0 && validGroupIds.contains(id));
    if (!mounted) return;
    setState(() {
      _showGroupFilter = showFilter;
      _showSearchField = showSearch;
      _gruposSeleccionados
        ..clear()
        ..addAll(restoredGroupIds);
    });
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alimento_picker_show_filter', _showGroupFilter);
    await prefs.setBool('alimento_picker_show_search', _showSearchField);
    await prefs.setStringList(
      'alimento_picker_selected_groups',
      _gruposSeleccionados.map((id) => id.toString()).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogHeight = (screenHeight * 0.75).clamp(460.0, 760.0);
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.alimentos.where((a) {
      if (_gruposSeleccionados.isNotEmpty) {
        final gruposAlimento = a.codigoGrupos.isNotEmpty
            ? a.codigoGrupos
            : (a.codigoGrupo != null ? <int>[a.codigoGrupo!] : <int>[]);
        final matchGrupo = gruposAlimento.any(_gruposSeleccionados.contains);
        if (!matchGrupo) return false;
      }
      if (query.isNotEmpty && !a.nombre.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();

    return WillPopScope(
      onWillPop: () async {
        await _saveUiState();
        return true;
      },
      child: AlertDialog(
        content: SizedBox(
          width: 500,
          height: dialogHeight,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Alimento',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip:
                        _showGroupFilter ? 'Ocultar filtro' : 'Mostrar filtro',
                    icon: Icon(
                      _showGroupFilter
                          ? Icons.filter_alt
                          : Icons.filter_alt_outlined,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        setState(() => _showGroupFilter = !_showGroupFilter),
                  ),
                  IconButton(
                    tooltip: _showSearchField
                        ? 'Ocultar búsqueda'
                        : 'Mostrar búsqueda',
                    icon: Icon(
                      _showSearchField ? Icons.search_off : Icons.search,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _showSearchField = !_showSearchField;
                        if (!_showSearchField) _searchController.clear();
                      });
                    },
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    style: IconButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () async {
                      await _saveUiState();
                      if (!context.mounted) return;
                      if (widget.allowMultiple) {
                        Navigator.pop(context);
                        return;
                      }
                      final selected = widget.alimentos
                          .where(
                            (a) =>
                                a.codigo != null &&
                                _selectedCodigos.contains(a.codigo),
                          )
                          .toList();
                      Navigator.pop(
                        context,
                        selected.isEmpty ? null : selected,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_showGroupFilter && widget.grupos.isNotEmpty) ...[
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Grupos',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _gruposSeleccionados.isEmpty
                                ? null
                                : () => setState(
                                      () => _gruposSeleccionados.clear(),
                                    ),
                            child: const Text('Todos'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(
                          () =>
                              _groupDropdownExpanded = !_groupDropdownExpanded,
                        ),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Seleccionar grupos',
                            border: OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                          child: Text(
                            _selectedGroupsLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (_groupDropdownExpanded) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 170,
                          child: ListView(
                            children: widget.grupos.map((g) {
                              final isSelected = _gruposSeleccionados.contains(
                                g.codigo,
                              );
                              return CheckboxListTile(
                                dense: true,
                                value: isSelected,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                title: Text(g.nombre),
                                onChanged: (selected) {
                                  setState(() {
                                    if (selected == true && g.codigo != null) {
                                      _gruposSeleccionados.add(g.codigo!);
                                    } else {
                                      _gruposSeleccionados.remove(g.codigo);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (_showSearchField) ...[
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por nombre',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No hay alimentos coincidentes'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final alimento = filtered[index];
                          final codigo = alimento.codigo;
                          final selected = codigo != null &&
                              _selectedCodigos.contains(codigo);
                          return ListTile(
                            dense: true,
                            minVerticalPadding: 0,
                            visualDensity: const VisualDensity(
                              horizontal: 0,
                              vertical: -2,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            title: Text(alimento.nombre),
                            titleTextStyle: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                            trailing: widget.allowMultiple
                                ? Checkbox(
                                    value: selected,
                                    onChanged: codigo == null
                                        ? null
                                        : (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedCodigos.add(codigo);
                                              } else {
                                                _selectedCodigos.remove(codigo);
                                              }
                                            });
                                          },
                                  )
                                : null,
                            onTap: () async {
                              if (codigo == null) return;
                              if (widget.allowMultiple) {
                                setState(() {
                                  if (selected) {
                                    _selectedCodigos.remove(codigo);
                                  } else {
                                    _selectedCodigos.add(codigo);
                                  }
                                });
                                return;
                              }
                              await _saveUiState();
                              if (context.mounted) {
                                Navigator.pop(context, [alimento]);
                              }
                            },
                          );
                        },
                      ),
              ),
              if (widget.allowMultiple) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await _saveUiState();
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await _saveUiState();
                          if (!context.mounted) return;
                          final selected = widget.alimentos
                              .where(
                                (a) =>
                                    a.codigo != null &&
                                    _selectedCodigos.contains(a.codigo),
                              )
                              .toList();
                          Navigator.pop(
                            context,
                            selected.isEmpty ? null : selected,
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Aplicar'),
                            const SizedBox(width: 8),
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _selectedCodigos.isEmpty
                                    ? Colors.grey
                                    : Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                _selectedCodigos.length.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
