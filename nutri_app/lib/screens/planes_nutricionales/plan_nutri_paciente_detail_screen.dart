import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/models/plan_nutri_estructura.dart';
import 'package:nutri_app/models/plan_nutricional.dart';
import 'package:nutri_app/models/receta.dart';
import 'package:nutri_app/screens/recetas_paciente_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/plan_nutri_pdf_service.dart';
import 'package:provider/provider.dart';

class PlanNutriPacienteDetailScreen extends StatefulWidget {
  const PlanNutriPacienteDetailScreen({super.key, required this.plan});

  final PlanNutricional plan;

  @override
  State<PlanNutriPacienteDetailScreen> createState() =>
      _PlanNutriPacienteDetailScreenState();
}

class _PlanNutriPacienteDetailScreenState
    extends State<PlanNutriPacienteDetailScreen> {
  final ApiService _apiService = ApiService();
  late Future<PlanNutriEstructura> _future;
  bool _detailedWeekView = true;
  int? _compactWeekIndex;
  int? _compactDayIndex;
  final Set<String> _expandedIngestas = {};
  final Set<int> _expandedSemanas = {};
  final Set<String> _expandedDias = {}; // "$semanaNum-$diaNombre"
  final Set<String> _expandedIngestasNormal =
      {}; // "$semanaNum-$diaNombre-$ingestaIdx"
  int _expandVersion = 0;

  @override
  void initState() {
    super.initState();
    _future = _apiService.getPlanNutriEstructura(widget.plan.codigo);
  }

  String _ingestaKey(int weekIndex, int dayIndex, int mealIndex) =>
      '$weekIndex-$dayIndex-$mealIndex';

  void _toggleDetailedWeekView() {
    setState(() {
      _detailedWeekView = !_detailedWeekView;
    });
  }

  // --- Helpers ----------------------------------------------------------------

  String _itemTitulo(PlanNutriItem item) {
    if ((item.alimentoNombre ?? '').trim().isNotEmpty) {
      return item.alimentoNombre!;
    }
    if ((item.descripcionManual ?? '').trim().isNotEmpty) {
      return item.descripcionManual!;
    }
    return 'Item';
  }

  String? _cantidadDisplay(String? rawCantidad) {
    final raw = (rawCantidad ?? '').trim();
    if (raw.isEmpty) return null;

    final normalized = raw.replaceAll(',', '.');
    final parsed = num.tryParse(normalized);

    if (parsed != null) {
      if (parsed <= 1) return null;
      final valueText = parsed % 1 == 0 ? parsed.toInt().toString() : raw;
      return 'Cantidad: $valueText';
    }

    return 'Cantidad: $raw';
  }

  ({IconData icon, Color color, Color textColor}) _ingestaStyle(String tipo) {
    final lower = tipo.toLowerCase();
    if (lower.contains('desayuno')) {
      return (
        icon: Icons.free_breakfast_outlined,
        color: const Color(0xFF1976D2),
        textColor: Colors.white
      );
    }
    if (lower.contains('almuerzo') || lower.contains('comida')) {
      return (
        icon: Icons.lunch_dining_outlined,
        color: const Color(0xFF1976D2),
        textColor: Colors.white
      );
    }
    if (lower.contains('merienda') || lower.contains('media ma')) {
      return (
        icon: Icons.coffee_outlined,
        color: const Color(0xFF1976D2),
        textColor: Colors.white
      );
    }
    if (lower.contains('cena') || lower.contains('noche')) {
      return (
        icon: Icons.nightlight_outlined,
        color: const Color(0xFF1976D2),
        textColor: Colors.white
      );
    }
    if (lower.contains('snack') || lower.contains('tentempie')) {
      return (
        icon: Icons.local_cafe_outlined,
        color: const Color(0xFF1976D2),
        textColor: Colors.white
      );
    }
    return (
      icon: Icons.restaurant_outlined,
      color: const Color(0xFF1976D2),
      textColor: Colors.white
    );
  }

  int _ingestasConAlimentos(PlanNutriDia dia) {
    return dia.ingestas.where((ingesta) => ingesta.items.isNotEmpty).length;
  }

  // ignore: unused_element
  int _diasCompletos(PlanNutriSemana semana) {
    return semana.dias.where((dia) {
      final total = dia.ingestas.length;
      if (total == 0) return false;
      return _ingestasConAlimentos(dia) == total;
    }).length;
  }

  bool _semanaTieneAlimentos(PlanNutriSemana semana) {
    for (final dia in semana.dias) {
      for (final ingesta in dia.ingestas) {
        if (ingesta.items.isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  String _buildWindowTitle(PlanNutriEstructura data) {
    return widget.plan.tituloPlan ?? 'Plan';
  }

  String _compactDayLabel(String dayName) {
    switch (dayName.trim().toLowerCase()) {
      case 'lunes':
        return 'L';
      case 'martes':
        return 'M';
      case 'miércoles':
      case 'miercoles':
        return 'X';
      case 'jueves':
        return 'J';
      case 'viernes':
        return 'V';
      case 'sábado':
      case 'sabado':
        return 'S';
      case 'domingo':
        return 'D';
      default:
        return dayName.isEmpty ? '?' : dayName.characters.first.toUpperCase();
    }
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

  void _selectCompactWeek(int weekIndex) {
    setState(() {
      _compactWeekIndex = weekIndex;
      _compactDayIndex = 0;
    });
  }

  void _selectCompactDay(int dayIndex) {
    setState(() {
      _compactDayIndex = dayIndex;
    });
  }

  // --- Harvard Plate compliance ----------------------------------------------

  static const _harvardEvitar = {'proteina_procesada', 'bebida_azucarada'};
  static const _harvardLimitar = {
    'proteina_roja',
    'grasa_no_saludable',
    'cereal_refinado',
    'lacteo'
  };

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
  }) {
    final weekHarvard = _computeHarvardWeekCompliance(semana);
    final weekHarvardColor = _harvardWeekComplianceColor(weekHarvard);
    final avgScore = (weekHarvard['avgScore'] as double?) ?? 0.0;
    final avgPercent = (weekHarvard['avgPercent'] as int?) ?? 0;

    return InkWell(
      onTap: () => _selectCompactWeek(weekIdx),
      onLongPress: () => _showHarvardWeekComplianceDialog(context, semana),
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
                    'Harvard asignada aún.',
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

  // --- Actions ----------------------------------------------------------------

  Future<void> _openReceta(int codigoReceta) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final resp = await apiService.get('api/recetas.php?codigo=$codigoReceta');
      if (!mounted) return;
      Navigator.of(context).pop();
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map<String, dynamic>) {
          final receta = Receta.fromJson(data);
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => RecetaDetailScreen(receta: receta)),
          );
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cargar la receta')),
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar la receta')),
        );
      }
    }
  }

  void _showRecomendacionesDialog(String recomendaciones) {
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
                  content: Text('Recomendaciones copiadas al portapapeles'),
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
                apiService: _apiService,
                recomendaciones: recomendaciones,
                tituloPlan: widget.plan.tituloPlan ?? 'Plan nutricional',
                pacienteNombre: widget.plan.nombrePaciente,
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

  // --- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<PlanNutriEstructura>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Text(_buildWindowTitle(snapshot.data!));
            }
            return const Text('Plan');
          },
        ),
        actions: [
          FutureBuilder<PlanNutriEstructura>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              // Mostrar PDF solo si tiene estructura con ingestas
              final hasStructure = snapshot.data!.semanas.isNotEmpty &&
                  snapshot.data!.semanas.any(_semanaTieneAlimentos);
              if (!hasStructure) return const SizedBox.shrink();
              final hasHarvardData = _hasHarvardRatings(snapshot.data!);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasHarvardData)
                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      tooltip: 'Cumplimiento Harvard',
                      onPressed: () => _showHarvardInfoDialog(context),
                    ),
                  IconButton(
                    icon: Icon(
                      _detailedWeekView
                          ? Icons.view_agenda_outlined
                          : Icons.view_week_outlined,
                    ),
                    tooltip: _detailedWeekView
                        ? 'Vista compacta'
                        : 'Vista detallada',
                    onPressed: _toggleDetailedWeekView,
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'Generar PDF',
                    onPressed: () => PlanNutriPdfService.generateWithOptions(
                      context: context,
                      apiService: _apiService,
                      plan: widget.plan,
                      estructura: snapshot.data,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<PlanNutriEstructura>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('No hay estructura disponible.'));
          }
          return _buildContent(data);
        },
      ),
    );
  }

  Widget _buildContent(PlanNutriEstructura data) {
    final recomendaciones = (data.planIndicacionesVisibleUsuario ?? '').trim();
    // Filtrar semanas que tengan al menos un día con ingestas que contengan alimentos
    final semanasConAlimentos =
        data.semanas.where(_semanaTieneAlimentos).toList();
    final visibleWeekEntries = semanasConAlimentos.asMap().entries.toList();
    _ensureCompactSelection(visibleWeekEntries);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      children: [
        // Plan header
        _buildHeaderCard(data),

        const SizedBox(height: 2),

        // Expand/collapse shortcuts
        _buildExpandCollapseButtons(data),

        const SizedBox(height: 4),

        // Semanas
        if (_detailedWeekView)
          ...semanasConAlimentos.map(_buildSemanaCard)
        else
          _buildCompactStructure(visibleWeekEntries),

        // Recomendaciones
        if (recomendaciones.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildRecomendacionesCard(recomendaciones),
        ],

        // Recetas
        if (data.recetas.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildRecetasCard(data.recetas),
        ],
      ],
    );
  }

  Widget _buildCompactStructure(List<MapEntry<int, PlanNutriSemana>> weeks) {
    if (weeks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No hay semanas para mostrar.'),
      );
    }

    final compactWeek = weeks.firstWhere(
      (entry) => entry.key == _compactWeekIndex,
      orElse: () => weeks.first,
    );
    final compactSemana = compactWeek.value;
    final hasDays = compactSemana.dias.isNotEmpty;
    final compactDayIdx = hasDays
        ? (_compactDayIndex ?? 0).clamp(0, compactSemana.dias.length - 1)
        : null;
    final compactDia = hasDays ? compactSemana.dias[compactDayIdx!] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: weeks.map((entry) {
            final weekIdx = entry.key;
            final semana = entry.value;
            final selected = _compactWeekIndex == weekIdx;

            return _buildCompactWeekChip(
              context,
              weekIdx,
              semana,
              selected: selected,
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        if (compactDia != null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: compactSemana.dias.asMap().entries.map((entry) {
              final dayIdx = entry.key;
              final dia = entry.value;
              final selected = compactDayIdx == dayIdx;

              return InkWell(
                onTap: () => _selectCompactDay(dayIdx),
                onLongPress: () => _showHarvardComplianceDialog(
                  context,
                  dia,
                  semana: compactSemana,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(selected ? 45 : 20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.blue,
                      width: selected ? 2.2 : 1,
                    ),
                  ),
                  child: Text(
                    _compactDayLabel(dia.nombreDia),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        if (compactDia != null) const SizedBox(height: 8),
        if (compactDia == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('La semana seleccionada no tiene días.'),
          )
        else
          ...compactDia.ingestas
              .asMap()
              .entries
              .where((entry) => entry.value.items.isNotEmpty)
              .map((entry) {
            return _buildCompactIngestaCard(
              weekIndex: compactWeek.key,
              dayIndex: compactDayIdx!,
              ingestaIndex: entry.key,
              ingesta: entry.value,
            );
          }),
      ],
    );
  }

  Widget _buildCompactIngestaCard({
    required int weekIndex,
    required int dayIndex,
    required int ingestaIndex,
    required PlanNutriIngesta ingesta,
  }) {
    if (ingesta.items.isEmpty) {
      return const SizedBox.shrink();
    }

    // Pre-compute ordinal prefixes for option items
    const ords = [
      '1\u00aa',
      '2\u00aa',
      '3\u00aa',
      '4\u00aa',
      '5\u00aa',
      '6\u00aa'
    ];
    var opcionIdx = 0;
    final itemPrefixes = ingesta.items.map((item) {
      if ((item.opcion ?? '') == 'S') {
        final ord = opcionIdx < ords.length
            ? ords[opcionIdx]
            : '${opcionIdx + 1}\u00aa';
        opcionIdx++;
        return '\u2714 $ord opci\u00f3n: ';
      }
      return null;
    }).toList();

    Widget buildItemRow(int index, PlanNutriItem item) {
      final rawTitulo = _itemTitulo(item);
      final titulo = itemPrefixes[index] != null
          ? '${itemPrefixes[index]}$rawTitulo'
          : rawTitulo;
      final cantidad = _cantidadDisplay(item.cantidad);
      final meta = [
        if (cantidad != null) cantidad,
        if ((item.unidad ?? '').isNotEmpty) item.unidad!,
        if ((item.notas ?? '').isNotEmpty) item.notas!,
      ].join(' \u2022 ');
      return Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '• ',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                      color: Colors.black87, fontSize: 14, height: 1.4),
                  children: [
                    TextSpan(text: titulo),
                    if (meta.isNotEmpty)
                      TextSpan(
                        text: '  $meta',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final header = Row(
      children: [
        Text(
          ingesta.tipoIngesta,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.blue.shade700,
            fontSize: 14,
          ),
        ),
      ],
    );

    final ingestaK = _ingestaKey(weekIndex, dayIndex, ingestaIndex);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ExpansionTile(
        key: ValueKey('compact-$ingestaK-$_expandVersion'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        dense: true,
        initiallyExpanded: _expandedIngestas.contains(ingestaK),
        onExpansionChanged: (exp) {
          setState(() {
            if (exp) {
              _expandedIngestas.add(ingestaK);
            } else {
              _expandedIngestas.remove(ingestaK);
            }
          });
        },
        title: header,
        children: ingesta.items
            .asMap()
            .entries
            .map((e) => buildItemRow(e.key, e.value))
            .toList(),
      ),
    );
  }

  Widget _buildHeaderCard(PlanNutriEstructura data) {
    final semanas = (widget.plan.semanas ?? '').trim();
    final desde = _formatDate(widget.plan.desde);
    final hasta = _formatDate(widget.plan.hasta);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan semanas ${semanas.isEmpty ? '-' : semanas}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Desde ${desde.isEmpty ? '-' : desde} hasta ${hasta.isEmpty ? '-' : hasta}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanInfoCard(PlanNutriEstructura data) {
    final hasStructure =
        data.semanas.isNotEmpty && data.semanas.any(_semanaTieneAlimentos);
    final hasDocument =
        (widget.plan.planDocumentoNombre ?? '').trim().isNotEmpty;
    final isCompleted = widget.plan.completado == 'S';
    final hasHarvardData = _hasHarvardRatings(data);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fechas desde/hasta
            if (widget.plan.desde != null || widget.plan.hasta != null)
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatDateRange(widget.plan.desde, widget.plan.hasta),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            if ((widget.plan.desde != null || widget.plan.hasta != null) &&
                (widget.plan.semanas ?? '').isNotEmpty)
              const SizedBox(height: 8),

            // Semanas
            if ((widget.plan.semanas ?? '').isNotEmpty)
              Row(
                children: [
                  Icon(Icons.calendar_view_week,
                      size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Semanas: ${widget.plan.semanas}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            if ((widget.plan.semanas ?? '').isNotEmpty)
              const SizedBox(height: 8),

            // Estado de completado / Cumplimiento hoy
            Row(
              children: [
                if (isCompleted)
                  Icon(Icons.check_circle,
                      size: 16, color: Colors.green.shade700)
                else
                  Icon(Icons.radio_button_unchecked,
                      size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCompleted ? 'Completado' : 'Cto. hoy',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hasDocument)
              ElevatedButton.icon(
                onPressed: () => _downloadDocument(),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Descargar'),
              ),
          ],
        ),
      ),
    );
  }

  bool _hasHarvardRatings(PlanNutriEstructura data) {
    for (final semana in data.semanas) {
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

  String _formatDateRange(DateTime? desde, DateTime? hasta) {
    if (desde == null && hasta == null) return '';
    if (desde == null) return 'Hasta: ${_formatDate(hasta)}';
    if (hasta == null) return 'Desde: ${_formatDate(desde)}';
    return 'Desde: ${_formatDate(desde)} - Hasta: ${_formatDate(hasta)}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _downloadDocument() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Descargando documento...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    // TODO: Implementar descarga de documento cuando esté disponible en la API
  }

  // --- Expand / collapse actions -------------------------------------------

  void _collapseAll() {
    setState(() {
      _expandedSemanas.clear();
      _expandedDias.clear();
      _expandedIngestasNormal.clear();
      _expandedIngestas.clear();
      _expandVersion++;
    });
  }

  void _expandAll(PlanNutriEstructura data) {
    final sems = data.semanas.where(_semanaTieneAlimentos).toList();
    setState(() {
      _expandedSemanas.clear();
      _expandedDias.clear();
      _expandedIngestasNormal.clear();
      _expandedIngestas.clear();
      for (int wIdx = 0; wIdx < sems.length; wIdx++) {
        final semana = sems[wIdx];
        _expandedSemanas.add(semana.numeroSemana);
        for (int dIdx = 0; dIdx < semana.dias.length; dIdx++) {
          final dia = semana.dias[dIdx];
          _expandedDias.add('${semana.numeroSemana}-${dia.nombreDia}');
          for (int iIdx = 0; iIdx < dia.ingestas.length; iIdx++) {
            if (dia.ingestas[iIdx].items.isNotEmpty) {
              _expandedIngestasNormal
                  .add('${semana.numeroSemana}-${dia.nombreDia}-$iIdx');
              _expandedIngestas.add(_ingestaKey(wIdx, dIdx, iIdx));
            }
          }
        }
      }
      _expandVersion++;
    });
  }

  void _expandToday(PlanNutriEstructura data) {
    final today = DateTime.now();
    final desde = widget.plan.desde;
    final sems = data.semanas.where(_semanaTieneAlimentos).toList();
    if (sems.isEmpty) return;

    PlanNutriSemana? targetSemana;
    if (desde != null) {
      final startDate = DateTime(desde.year, desde.month, desde.day);
      final todayDate = DateTime(today.year, today.month, today.day);
      final diff = todayDate.difference(startDate).inDays;
      if (diff >= 0) {
        final weekNum = (diff ~/ 7) + 1;
        try {
          targetSemana = sems.firstWhere((s) => s.numeroSemana == weekNum);
        } catch (_) {
          // Cyclic fallback when plan has elapsed
          final modIdx = (diff ~/ 7) % sems.length;
          targetSemana = sems[modIdx];
        }
      }
    }

    const dayNames = [
      '',
      'Lunes',
      'Martes',
      'Mi\u00e9rcoles',
      'Jueves',
      'Viernes',
      'S\u00e1bado',
      'Domingo'
    ];
    final todayName = dayNames[today.weekday];

    targetSemana ??= sems.firstWhere(
      (s) => s.dias
          .any((d) => d.nombreDia.toLowerCase() == todayName.toLowerCase()),
      orElse: () => sems.first,
    );

    PlanNutriDia? todayDia;
    try {
      todayDia = targetSemana.dias.firstWhere(
        (d) => d.nombreDia.toLowerCase() == todayName.toLowerCase(),
      );
    } catch (_) {}

    final semIdx = sems.indexOf(targetSemana);
    final dayIdx = todayDia != null ? targetSemana.dias.indexOf(todayDia) : 0;

    setState(() {
      _expandedSemanas.clear();
      _expandedDias.clear();
      _expandedIngestasNormal.clear();
      _expandedIngestas.clear();

      _expandedSemanas.add(targetSemana!.numeroSemana);
      if (todayDia != null) {
        _expandedDias.add('${targetSemana.numeroSemana}-${todayDia.nombreDia}');
        for (int iIdx = 0; iIdx < todayDia.ingestas.length; iIdx++) {
          if (todayDia.ingestas[iIdx].items.isNotEmpty) {
            _expandedIngestasNormal.add(
                '${targetSemana.numeroSemana}-${todayDia.nombreDia}-$iIdx');
            _expandedIngestas.add(_ingestaKey(semIdx, dayIdx, iIdx));
          }
        }
      }
      // Navigate compact view to today
      _compactWeekIndex = semIdx;
      _compactDayIndex = dayIdx;
      _expandVersion++;
    });
  }

  Widget _buildExpandCollapseButtons(PlanNutriEstructura data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: _collapseAll,
          icon: const Icon(Icons.unfold_less, size: 16),
          label: const Text('Plegar todos', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        TextButton.icon(
          onPressed: () => _expandAll(data),
          icon: const Icon(Icons.unfold_more, size: 16),
          label: const Text('Desplegar todos', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        TextButton.icon(
          onPressed: () => _expandToday(data),
          icon: const Icon(Icons.today_outlined, size: 16),
          label: const Text('Hoy', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildSemanaCard(PlanNutriSemana semana) {
    final weekHarvard = _computeHarvardWeekCompliance(semana);
    final weekHarvardColor = _harvardWeekComplianceColor(weekHarvard);
    final weekHarvardSamples = weekHarvard['samples'] as int;
    final weekHarvardAvg =
        (weekHarvard['avgScore'] as double).toStringAsFixed(2);
    final weekHarvardPercent = weekHarvard['avgPercent'] as int;
    final weekHarvardFulfilled = weekHarvard['fulfilled'] as bool;
    // Filtrar días que tengan al menos una ingesta con alimentos
    final diasConAlimentos = semana.dias
        .where((dia) => dia.ingestas.any((ingesta) => ingesta.items.isNotEmpty))
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.calendar_view_week_outlined,
                color: Colors.blue.shade700, size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Semana ${semana.numeroSemana}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              Tooltip(
                message: weekHarvardSamples == 0
                    ? 'Harvard semanal: sin datos'
                    : 'Harvard semanal: ${weekHarvardFulfilled ? 'cumple' : 'no cumple'} — media $weekHarvardAvg/4 ($weekHarvardPercent%)',
                child: InkWell(
                  onTap: () =>
                      _showHarvardWeekComplianceDialog(context, semana),
                  borderRadius: BorderRadius.circular(16),
                  child: _buildWeekHarvardHeaderSummary(
                    weekHarvardColor,
                    weekHarvard['avgScore'] as double,
                    weekHarvardPercent,
                  ),
                ),
              ),
            ],
          ),
          key: ValueKey('semana-${semana.numeroSemana}-$_expandVersion'),
          initiallyExpanded: _expandedSemanas.contains(semana.numeroSemana),
          onExpansionChanged: (exp) {
            setState(() {
              if (exp) {
                _expandedSemanas.add(semana.numeroSemana);
              } else {
                _expandedSemanas.remove(semana.numeroSemana);
              }
            });
          },
          children: diasConAlimentos
              .map((dia) => _buildDiaCard(dia, semana: semana))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDiaCard(PlanNutriDia dia, {required PlanNutriSemana semana}) {
    final compliance = _computeHarvardCompliance(dia);
    final dayColor = _harvardComplianceColor(compliance);
    final tagged = compliance['taggedItems'] as int;
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 4, bottom: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.lightBlue.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.today_outlined,
                color: Colors.lightBlue.shade700, size: 18),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  dia.nombreDia,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Tooltip(
                message: tagged == 0
                    ? 'Plato de Harvard: sin alimentos clasificados'
                    : 'Plato de Harvard — toca para ver el análisis',
                child: InkWell(
                  onTap: () => _showHarvardComplianceDialog(
                    context,
                    dia,
                    semana: semana,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: dayColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text('🥗', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ),
            ],
          ),
          key: ValueKey(
              'dia-${semana.numeroSemana}-${dia.nombreDia}-$_expandVersion'),
          initiallyExpanded:
              _expandedDias.contains('${semana.numeroSemana}-${dia.nombreDia}'),
          onExpansionChanged: (exp) {
            final k = '${semana.numeroSemana}-${dia.nombreDia}';
            setState(() {
              if (exp) {
                _expandedDias.add(k);
              } else {
                _expandedDias.remove(k);
              }
            });
          },
          children: dia.ingestas
              .asMap()
              .entries
              .map((e) => _buildIngestaSection(
                    e.value,
                    keyBase: '${semana.numeroSemana}-${dia.nombreDia}-${e.key}',
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildIngestaSection(PlanNutriIngesta ingesta,
      {required String keyBase}) {
    final style = _ingestaStyle(ingesta.tipoIngesta);
    final hasItems = ingesta.items.isNotEmpty;
    if (!hasItems) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 10, 8),
      child: ExpansionTile(
        key: ValueKey('ingesta-$keyBase-$_expandVersion'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        initiallyExpanded: _expandedIngestasNormal.contains(keyBase),
        onExpansionChanged: (exp) {
          setState(() {
            if (exp) {
              _expandedIngestasNormal.add(keyBase);
            } else {
              _expandedIngestasNormal.remove(keyBase);
            }
          });
        },
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: style.color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(style.icon, size: 15, color: style.textColor),
              const SizedBox(width: 6),
              Text(
                ingesta.tipoIngesta,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: style.textColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        children: ingesta.items.map(_buildItemRow).toList(),
      ),
    );
  }

  Widget _buildItemRow(PlanNutriItem item) {
    final titulo = _itemTitulo(item);
    final cantidad = _cantidadDisplay(item.cantidad);
    final meta = [
      if (cantidad != null) cantidad,
      if ((item.unidad ?? '').isNotEmpty) item.unidad!,
    ].join(' ');
    final hvColor = _harvardItemColor(item);
    final hvLabel = _codigoLabels[item.harvardCategoria ?? '']?.$2;
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: Colors.black87, fontSize: 14, height: 1.4),
                children: [
                  TextSpan(text: titulo),
                  if (meta.isNotEmpty)
                    TextSpan(
                      text: '  $meta',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
          if (hvColor != null)
            Tooltip(
              message: hvLabel ?? (item.harvardCategoria ?? 'Harvard'),
              child: Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4, left: 6),
                decoration: BoxDecoration(
                  color: hvColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecomendacionesCard(String recomendaciones) {
    final truncated = recomendaciones.length > 30
        ? '${recomendaciones.substring(0, 30)}\u2026'
        : recomendaciones;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outlined,
                  color: Colors.amber.shade800, size: 17),
              const SizedBox(width: 6),
              Text(
                'Recomendaciones',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.amber.shade900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(truncated, style: const TextStyle(fontSize: 13, height: 1.4)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.read_more_outlined, size: 16),
              label: const Text('Leer mas', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _showRecomendacionesDialog(recomendaciones),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecetasCard(List<PlanNutriRecetaVinculada> recetas) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        initiallyExpanded: false,
        title: Row(
          children: [
            Icon(Icons.menu_book_outlined,
                color: Colors.green.shade800, size: 17),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Recetas del plan',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade900,
                  fontSize: 13,
                ),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${recetas.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        children: recetas.map((r) {
          final titulo = (r.recetaTitulo ?? 'Receta ${r.codigoReceta}').trim();
          return ListTile(
            dense: true,
            visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
            leading: Icon(Icons.open_in_new_outlined,
                size: 16, color: Colors.green.shade700),
            title: Text(
              titulo,
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
            onTap: () => _openReceta(r.codigoReceta),
          );
        }).toList(),
      ),
    );
  }
}

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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$seccion: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
