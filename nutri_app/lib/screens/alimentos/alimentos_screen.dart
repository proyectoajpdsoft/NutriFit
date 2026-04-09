import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nutri_app/models/alimento.dart';
import 'package:nutri_app/models/alimento_grupo.dart';
import 'package:nutri_app/models/harvard_categoria.dart';
import 'package:nutri_app/models/plan_nutricional.dart';
import 'package:nutri_app/screens/alimentos/alimento_grupos_screen.dart';
import 'package:nutri_app/screens/planes_nutricionales/plan_nutri_estructura_screen.dart';
import 'package:nutri_app/services/alimentos_catalog_pdf_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _OrdenAlimentos { nombre, fechaAlta, usos, categoria }

class AlimentosScreen extends StatefulWidget {
  const AlimentosScreen({super.key});

  @override
  State<AlimentosScreen> createState() => _AlimentosScreenState();
}

class _AlimentosScreenState extends State<AlimentosScreen> {
  final ApiService _apiService = ApiService();
  final AlimentoGruposController _gruposController = AlimentoGruposController();
  final TextEditingController _searchCtrl = TextEditingController();
  static const String _showFiltersKey = 'alimentos_show_filters';
  static const String _searchQueryKey = 'alimentos_search_query';
  static const String _selectedGruposKey = 'alimentos_selected_grupos';
  static const String _showCategorySearchKey = 'alimentos_show_category_search';
  static const String _filtroActivoKey = 'alimentos_filtro_activo';
  static const String _filtroOpcionKey = 'alimentos_filtro_opcion';
  static const String _ordenAlimentosKey = 'alimentos_orden';
  static const String _ordenAlimentosAscKey = 'alimentos_orden_asc';
  late Future<List<Alimento>> _future;
  List<AlimentoGrupo> _grupos = [];
  String _search = '';
  final Set<int> _codigoGruposFiltro = {};
  bool _showFilters = true;
  bool _showCategorySearch = false;
  bool _showChartView = false;
  bool? _filtroActivoSolo;
  bool? _filtroConOpcion;
  _OrdenAlimentos _ordenAlimentos = _OrdenAlimentos.usos;
  bool _ordenAscendente = false;
  List<HarvardCategoria> _harvardCategorias = [];
  List<Alimento> _harvardLearningAlimentos = [];

  @override
  void initState() {
    super.initState();
    context
        .read<ConfigService>()
        .loadDeleteSwipePercentageFromDatabase(_apiService);
    _loadUiState();
    _loadGrupos();
    _loadHarvardCategorias();
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_selectedGruposKey) ?? const <String>[];
    final storedSearchQuery = prefs.getString(_searchQueryKey) ?? '';
    // -1 = null (todos), 0 = false, 1 = true
    final storedActivo = prefs.getInt(_filtroActivoKey);
    final storedOpcion = prefs.getInt(_filtroOpcionKey);
    final storedOrden = prefs.getInt(_ordenAlimentosKey);
    final storedOrdenAsc = prefs.getBool(_ordenAlimentosAscKey);
    if (!mounted) return;
    setState(() {
      _showFilters = prefs.getBool(_showFiltersKey) ?? true;
      _search = storedSearchQuery;
      _searchCtrl.text = storedSearchQuery;
      _showCategorySearch = prefs.getBool(_showCategorySearchKey) ?? false;
      _codigoGruposFiltro
        ..clear()
        ..addAll(
          stored.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0),
        );
      _filtroActivoSolo =
          storedActivo == null || storedActivo == -1 ? null : storedActivo == 1;
      _filtroConOpcion =
          storedOpcion == null || storedOpcion == -1 ? null : storedOpcion == 1;
      _ordenAlimentos = storedOrden != null &&
              storedOrden >= 0 &&
              storedOrden < _OrdenAlimentos.values.length
          ? _OrdenAlimentos.values[storedOrden]
          : _OrdenAlimentos.usos;
      _ordenAscendente = storedOrdenAsc ?? false;
    });
    _reload();
  }

  Future<void> _saveFiltroEstado() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_filtroActivoKey,
        _filtroActivoSolo == null ? -1 : (_filtroActivoSolo! ? 1 : 0));
    await prefs.setInt(_filtroOpcionKey,
        _filtroConOpcion == null ? -1 : (_filtroConOpcion! ? 1 : 0));
    await prefs.setInt(_ordenAlimentosKey, _ordenAlimentos.index);
    await prefs.setBool(_ordenAlimentosAscKey, _ordenAscendente);
  }

  Future<void> _saveFiltroGrupos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _selectedGruposKey,
      _codigoGruposFiltro.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _saveSearchState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showFiltersKey, _showFilters);
    await prefs.setString(_searchQueryKey, _search);
  }

  String _gruposFiltroLabel() {
    if (_codigoGruposFiltro.isEmpty) return 'Categorías: todas';
    final names = _grupos
        .where(
            (g) => g.codigo != null && _codigoGruposFiltro.contains(g.codigo))
        .map((g) => g.nombre)
        .toList();
    if (names.length <= 2) return 'Categorías: ${names.join(', ')}';
    return 'Categorías: ${names.length} seleccionadas';
  }

  String _gruposAlimentoLabel(Alimento alimento) {
    final names = alimento.nombreGrupos;
    if (names.isNotEmpty) {
      return names.join(', ');
    }
    if ((alimento.nombreGrupo ?? '').trim().isNotEmpty) {
      return alimento.nombreGrupo!.trim();
    }
    return 'Sin categoría';
  }

  // ── Harvard helpers ────────────────────────────────────────────────────────

  /// Returns the [HarvardCategoria] matching [codigo], or null.
  HarvardCategoria? _harvardByCode(String? codigo) {
    if (codigo == null || codigo.isEmpty) return null;
    try {
      return _harvardCategorias.firstWhere((c) => c.codigo == codigo);
    } catch (_) {
      return null;
    }
  }

  List<String> _harvardAssignedCodes(Alimento alimento) {
    if (alimento.harvardCategorias.isNotEmpty) {
      return alimento.harvardCategorias;
    }
    if ((alimento.harvardCategoria ?? '').trim().isNotEmpty) {
      return [alimento.harvardCategoria!.trim()];
    }
    return const <String>[];
  }

  String _normalizeForHarvardMatch(String text) {
    var value = text.toLowerCase().trim();
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    replacements.forEach((from, to) {
      value = value.replaceAll(from, to);
    });
    value = value
        .replaceAll(RegExp(r'[^a-z0-9\s\+]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return value;
  }

  Set<String> _harvardMeaningfulTokens(String rawName) {
    final normalized = _normalizeForHarvardMatch(rawName);
    if (normalized.isEmpty) return <String>{};

    const stopwords = {
      'de',
      'del',
      'la',
      'el',
      'los',
      'las',
      'y',
      'o',
      'con',
      'sin',
      'al',
      'a',
      'en',
      'para',
      'por',
      'un',
      'una',
      'unos',
      'unas',
      'tipo',
      'fuente',
      'varios',
      'varias',
      'mas',
      'menos',
    };

    return normalized
        .split(RegExp(r'\s+|\+'))
        .map((e) => e.trim())
        .where((e) => e.length >= 3 && !stopwords.contains(e))
        .toSet();
  }

  Future<List<Alimento>> _getHarvardLearningAlimentos() async {
    if (_harvardLearningAlimentos.isNotEmpty) {
      return _harvardLearningAlimentos;
    }
    final items = await _apiService.getAlimentos();
    _harvardLearningAlimentos = items;
    return items;
  }

  Set<String> _inferHarvardCategoriasFromLearning(
    String rawName,
    List<Alimento> knownFoods,
  ) {
    final targetTokens = _harvardMeaningfulTokens(rawName);
    if (targetTokens.isEmpty) return <String>{};

    final scores = <String, int>{};
    final normalizedTarget = _normalizeForHarvardMatch(rawName);

    for (final food in knownFoods) {
      final categories = _harvardAssignedCodes(food);
      if (categories.isEmpty) continue;

      final knownTokens = _harvardMeaningfulTokens(food.nombre);
      if (knownTokens.isEmpty) continue;

      final overlap = targetTokens.intersection(knownTokens).length;
      if (overlap == 0) continue;

      var weight = overlap;
      final normalizedKnown = _normalizeForHarvardMatch(food.nombre);
      if (normalizedKnown == normalizedTarget) {
        weight += 4;
      } else if (normalizedKnown.contains(normalizedTarget) ||
          normalizedTarget.contains(normalizedKnown)) {
        weight += 2;
      }

      for (final category in categories) {
        scores[category] = (scores[category] ?? 0) + weight;
      }
    }

    if (scores.isEmpty) return <String>{};
    final maxScore = scores.values.reduce((a, b) => a > b ? a : b);
    final minScore = maxScore >= 4 ? maxScore - 2 : 1;

    return scores.entries
        .where((entry) => entry.value >= minScore)
        .map((entry) => entry.key)
        .toSet();
  }

  Set<String> _inferHarvardCategoriasFromName(String rawName) {
    final text = _normalizeForHarvardMatch(rawName);
    if (text.isEmpty) return <String>{};

    final isPlainTortilla = text == 'tortilla' || text.startsWith('tortilla ');
    final isGrainTortilla = isPlainTortilla &&
        (text.contains('trigo') ||
            text.contains('wrap') ||
            text.contains('mexicana') ||
            text.contains('integral') ||
            text.contains('maiz'));

    bool hasAny(List<String> keywords) {
      return keywords.any((k) => text.contains(k));
    }

    final isBocadillo = text == 'bocadillo' || text.startsWith('bocadillo ');
    final isIntegralBocadillo =
        isBocadillo && (text.contains('integral') || text.contains('centeno'));
    final isVegetableBurger = text.contains('hamburguesa') &&
        hasAny([
          'vegetal',
          'vegana',
          'vegano',
          'lenteja',
          'garbanzo',
          'alubia',
          'judia',
          'soja',
          'tofu',
          'tempeh',
        ]);
    final isWhiteFilete = text.contains('filete') &&
        hasAny([
          'pollo',
          'pavo',
          'conejo',
          'pescado',
          'atun',
          'salmon',
          'merluza',
          'bacalao',
          'lenguado',
          'rape',
          'dorada',
          'lubina',
        ]);
    final isRedFilete = text.contains('filete') &&
        !isWhiteFilete &&
        !hasAny(['tofu', 'tempeh', 'soja', 'vegetal', 'vegano', 'vegana']);
    final isSavoryCrema = (text == 'crema' || text.startsWith('crema ')) &&
        !hasAny([
          'cacao',
          'chocolate',
          'cacahuete',
          'avellana',
          'almendra',
          'nata',
          'pastelera',
          'dulce',
        ]);

    final inferred = <String>{};

    if (hasAny([
          'verdura',
          'verduras',
          'hortaliza',
          'hortalizas',
          'ensalada',
          'brocoli',
          'espinaca',
          'calabacin',
          'calabaza',
          'zanahoria',
          'tomate',
          'pimiento',
          'cebolla',
          'coliflor',
          'berenjena',
          'berengena',
          'judia verde',
          'judias verdes',
          'guisante',
          'guisantes',
          'pepino',
          'seta',
          'champinon',
          'champiñon',
          'champiñones',
          'esparrago',
          'acelga',
          'col',
          'kale',
          'lechuga',
        ]) ||
        isSavoryCrema) {
      inferred.add('verdura');
    }

    if (hasAny([
      'fruta',
      'frutas',
      'manzana',
      'platano',
      'banana',
      'pera',
      'naranja',
      'mandarina',
      'uva',
      'melon',
      'sandia',
      'kiwi',
      'fresa',
      'frambuesa',
      'mango',
      'papaya',
      'pina',
      'cereza',
      'ciruela',
      'albaricoque',
      'melocoton',
      'nectarina',
      'higo',
      'granada',
      'arandano',
    ])) {
      inferred.add('fruta');
    }

    if (hasAny([
          'integral',
          'cereal integral',
          'cereales integrales',
          'pasta integral',
          'arroz integral',
          'pan integral',
          'avena',
          'quinoa',
          'centeno',
          'espelta',
          'bulgur',
          'mijo',
          'trigo sarraceno',
        ]) ||
        (isGrainTortilla &&
            (text.contains('integral') || text.contains('maiz'))) ||
        isIntegralBocadillo) {
      inferred.add('cereal_integral');
    }

    if (hasAny([
          'pan blanco',
          'pasta blanca',
          'arroz blanco',
          'paella',
          'cereal refinado',
          'cereales refinados',
          'harina refinada',
          'galleta',
          'bolleria',
          'croissant',
          'donut',
        ]) ||
        (isGrainTortilla &&
            (text.contains('trigo') ||
                text.contains('wrap') ||
                text.contains('mexicana'))) ||
        (isBocadillo && !isIntegralBocadillo)) {
      inferred.add('cereal_refinado');
    }

    if (hasAny([
      'legumbre',
      'legumbres',
      'lenteja',
      'garbanzo',
      'alubia',
      'judia',
      'soja',
      'tofu',
      'tempeh',
      'hummus',
      'proteina vegetal',
      'proteina',
    ])) {
      inferred.add('proteina_vegetal');
    }

    if (hasAny([
          'pescado',
          'atun',
          'salmon',
          'merluza',
          'bacalao',
          'sardina',
          'boqueron',
          'caballa',
          'trucha',
          'dorada',
          'lubina',
          'rape',
          'rodaballo',
          'lenguado',
          'pulpo',
          'calamar',
          'sepia',
          'marisco',
          'mariscos',
          'molusco',
          'moluscos',
          'gamba',
          'gambas',
          'camaron',
          'camaron',
          'camarones',
          'langostino',
          'langostinos',
          'cigala',
          'cigalas',
          'navaja',
          'navajas',
          'vieira',
          'vieiras',
          'mejillon',
          'mejillones',
          'almeja',
          'almejas',
          'ostra',
          'ostras',
          'pollo',
          'pavo',
          'conejo',
          'huevo',
          'huevos',
          'carne',
          'tortilla',
        ]) &&
        !isGrainTortilla) {
      inferred.add('proteina_blanca');
    }

    if (hasAny([
              'ternera',
              'vacuno',
              'buey',
              'cordero',
              'cerdo',
              'carne roja',
              'hamburguesa',
              'chuleta',
              'entrecot',
              'solomillo',
            ]) &&
            !isVegetableBurger ||
        isRedFilete) {
      inferred.add('proteina_roja');
    }

    if (hasAny([
      'embutido',
      'salchicha',
      'fiambre',
      'chorizo',
      'salami',
      'mortadela',
      'bacon',
      'beicon',
      'jamon cocido',
      'jamon york',
      'carne procesada',
      'nugget',
    ])) {
      inferred.add('proteina_procesada');
    }

    if (hasAny([
      'leche',
      'yogur',
      'yogurt',
      'queso',
      'kefir',
      'cuajada',
      'requeson',
      'lacteo',
      'lacteos',
    ])) {
      inferred.add('lacteo');
    }

    if (hasAny([
      'aceite',
      'aceite de oliva',
      'oliva',
      'aguacate',
      'nuez',
      'almendra',
      'avellana',
      'pistacho',
      'cacahuete',
      'semilla',
      'chia',
      'linaza',
      'sesamo',
    ])) {
      inferred.add('grasa_saludable');
    }

    if (hasAny([
      'mantequilla',
      'margarina',
      'grasa trans',
      'palma',
      'frito',
      'fritura',
      'mayonesa',
    ])) {
      inferred.add('grasa_no_saludable');
    }

    if (hasAny([
      'agua',
      'infusion',
      'te',
      'cafe',
      'cafe solo',
      'cafe americano',
    ])) {
      inferred.add('agua');
    }

    if (hasAny([
      'refresco',
      'cola',
      'bebida azucarada',
      'zumo industrial',
      'energy drink',
      'energetica',
      'batido azucarado',
    ])) {
      inferred.add('bebida_azucarada');
    }

    return inferred;
  }

  /// Small colored indicator shown in the list row subtitle.
  Widget _harvardSubtitleChip(Alimento item) {
    final selectedCodes = item.harvardCategorias.isNotEmpty
        ? item.harvardCategorias
        : (item.harvardCategoria != null
            ? [item.harvardCategoria!]
            : <String>[]);
    if (selectedCodes.isEmpty) {
      return const SizedBox.shrink();
    }
    final cat = _harvardByCode(selectedCodes.first);
    final nombre =
        cat?.nombre ?? item.harvardNombre ?? item.harvardCategoria ?? '';
    final emoji = cat?.iconoEmoji ?? '';
    final extra =
        selectedCodes.length > 1 ? ' +${selectedCodes.length - 1}' : '';
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: (cat?.color ?? Colors.grey.shade400).withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (cat?.color ?? Colors.grey.shade400).withOpacity(0.5),
          width: 0.8,
        ),
      ),
      child: Text(
        '${emoji.isNotEmpty ? '$emoji $nombre' : nombre}$extra',
        style: TextStyle(
          fontSize: 10,
          color: cat?.color ?? Colors.grey.shade700,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _harvardSelectionLabel(Set<String> selected) {
    if (selected.isEmpty) return 'Sin clasificar';
    final names = _harvardCategorias
        .where((c) => selected.contains(c.codigo))
        .map((c) => c.nombre)
        .toList();
    if (names.isEmpty) return '${selected.length} categorías';
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  Future<Set<String>?> _showSelectHarvardDialog(Set<String> initial) async {
    final selected = Set<String>.from(initial);
    return showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Categorías Harvard',
                  style: TextStyle(fontSize: 15),
                ),
              ),
              IconButton(
                tooltip: 'Cancelar',
                onPressed: () => Navigator.pop(ctx),
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
            width: 380,
            height: 360,
            child: ListView(
              children: [
                CheckboxListTile(
                  dense: true,
                  title: const Text('Sin clasificar'),
                  value: selected.isEmpty,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (_) => setLocal(() => selected.clear()),
                ),
                const Divider(height: 1),
                ..._harvardCategorias.map((cat) {
                  return CheckboxListTile(
                    dense: true,
                    value: selected.contains(cat.codigo),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: cat.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            cat.iconoEmoji.isNotEmpty
                                ? '${cat.iconoEmoji} ${cat.nombre}'
                                : cat.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!cat.esRecomendado)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Text('⚠️', style: TextStyle(fontSize: 11)),
                          ),
                      ],
                    ),
                    onChanged: (checked) {
                      setLocal(() {
                        if (checked == true) {
                          selected.add(cat.codigo);
                        } else {
                          selected.remove(cat.codigo);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setLocal(() => selected.clear()),
              child: const Text('Limpiar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Aplicar'),
                  const SizedBox(width: 8),
                  _countBadge(
                    selected.length,
                    activeColor: Colors.green.shade600,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHarvardSelector(
    Set<String> selected,
    bool initiallyExpanded,
    ValueChanged<bool> onExpansionChanged,
    ValueChanged<Set<String>> onChanged,
    VoidCallback onAutoDiscover,
  ) {
    final cats = _harvardCategorias;
    // Badge color: gray=none, red=any 'evitar', green=all recommended
    final Color harvardBadgeColor;
    if (selected.isEmpty) {
      harvardBadgeColor = Colors.grey.shade400;
    } else {
      final selectedCats =
          cats.where((c) => selected.contains(c.codigo)).toList();
      harvardBadgeColor = selectedCats.any((c) => !c.esRecomendado)
          ? Colors.red.shade600
          : Colors.green.shade600;
    }
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.green.shade300),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        onExpansionChanged: onExpansionChanged,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        title: Row(
          children: [
            Text(
              'Harvard',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Ver información sobre el Plato de Harvard',
              child: InkWell(
                onTap: () => _showHarvardInfoDialog(context),
                borderRadius: BorderRadius.circular(999),
                child: _countBadge(selected.length,
                    activeColor: harvardBadgeColor),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: onAutoDiscover,
              tooltip: 'Autodescubrir categorías Harvard por nombre',
              icon: Icon(Icons.auto_awesome,
                  size: 16, color: Colors.amber.shade700),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () async {
                final picked = await _showSelectHarvardDialog(selected);
                if (picked != null) onChanged(picked);
              },
              tooltip: 'Seleccionar categorías Harvard',
              icon: Icon(Icons.restaurant_menu_outlined,
                  size: 16, color: Colors.green.shade700),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              height: 110,
              width: double.infinity,
              child: selected.isEmpty
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sin categorías Harvard',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: cats
                              .where((c) => selected.contains(c.codigo))
                              .map(
                                (c) => Chip(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: c.color.withOpacity(0.14),
                                  side: BorderSide(
                                      color: c.color.withOpacity(0.4)),
                                  label: Text(
                                    c.iconoEmoji.isNotEmpty
                                        ? '${c.iconoEmoji} ${c.nombre}'
                                        : c.nombre,
                                    style: TextStyle(
                                      color: c.color.withOpacity(0.95),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
            ),
          ),
        ],
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
              child: Text(
                'El Plato de Harvard',
                style: TextStyle(fontSize: 16),
              ),
            ),
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
                Text(
                  'Proporciones recomendadas:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                _HarvardInfoRow(
                  emoji: '🥗',
                  seccion: '½ plato',
                  desc:
                      'Verduras y frutas variadas. Cuanto más variedad y color, mejor.',
                ),
                _HarvardInfoRow(
                  emoji: '🌾',
                  seccion: '¼ plato',
                  desc:
                      'Cereales integrales: avena, arroz integral, pasta integral, pan integral.',
                ),
                _HarvardInfoRow(
                  emoji: '🫘',
                  seccion: '¼ plato',
                  desc:
                      'Proteínas saludables: legumbres, pescado, pollo, huevos, frutos secos.',
                ),
                _HarvardInfoRow(
                  emoji: '🫒',
                  seccion: 'Aceites',
                  desc:
                      'Grasas saludables como el aceite de oliva virgen extra. Evitar trans.',
                ),
                _HarvardInfoRow(
                  emoji: '💧',
                  seccion: 'Bebidas',
                  desc:
                      'Agua como bebida principal. Infusiones y café sin azúcar.',
                ),
                SizedBox(height: 12),
                Text(
                  'Lo que el plato recomienda limitar:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                _HarvardInfoRow(
                  emoji: '🥩',
                  seccion: 'Limitar',
                  desc: 'Carne roja: máximo 1-2 veces por semana.',
                ),
                _HarvardInfoRow(
                  emoji: '🌭',
                  seccion: 'Evitar',
                  desc: 'Carnes procesadas: embutidos, fiambres, salchichas.',
                ),
                _HarvardInfoRow(
                  emoji: '🥤',
                  seccion: 'Evitar',
                  desc:
                      'Bebidas azucaradas: refrescos, zumos industriales, bebidas energéticas.',
                ),
                _HarvardInfoRow(
                  emoji: '🍞',
                  seccion: 'Limitar',
                  desc:
                      'Cereales refinados: pan blanco, pasta blanca, arroz blanco.',
                ),
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

  Color _usageBadgeColor(int value, int maxValue) {
    if (value <= 0) return Colors.grey.shade500;
    if (maxValue <= 1) return Colors.blue.shade200;

    final ratio = (value / maxValue).clamp(0.0, 1.0);
    if (ratio <= 0.15) return Colors.blue.shade100;
    if (ratio <= 0.30) return Colors.blue.shade200;
    if (ratio <= 0.45) return Colors.blue.shade300;
    if (ratio <= 0.60) return Colors.blue.shade500;
    if (ratio <= 0.75) return Colors.blue.shade600;
    if (ratio <= 0.90) return Colors.blue.shade700;
    return Colors.blue.shade900;
  }

  Color _usageBadgeTextColor(Color badgeColor) {
    return badgeColor.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
  }

  Widget _countBadge(int count, {required Color activeColor}) {
    final color = count == 0 ? Colors.grey.shade400 : activeColor;
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _smallStatusTag({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(120), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _activeOptionTag({
    required String label,
    required bool active,
    VoidCallback? onTap,
  }) {
    final tag = Container(
      width: 24,
      height: 22,
      decoration: BoxDecoration(
        color: active ? Colors.green : Colors.grey,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    if (onTap == null) return tag;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: tag,
      ),
    );
  }

  bool _canShowUsageChart(BuildContext context) {
    final userType =
        (context.watch<AuthService>().userType ?? '').toLowerCase();
    return userType == 'nutricionista' || userType == 'administrador';
  }

  List<Alimento> _topUsedFoods(List<Alimento> items, {int limit = 10}) {
    final list = items.where((a) => a.totalIngestas > 0).toList()
      ..sort((a, b) {
        final cmp = b.totalIngestas.compareTo(a.totalIngestas);
        if (cmp != 0) return cmp;
        return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });
    if (list.length <= limit) return list;
    return list.sublist(0, limit);
  }

  static const List<Color> _chartPalette = [
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFFE53935),
    Color(0xFF00897B),
    Color(0xFF6D4C41),
    Color(0xFF3949AB),
    Color(0xFFFDD835),
    Color(0xFF00ACC1),
  ];

  Color _pieColorByIndex(int index, int total) {
    if (_chartPalette.isEmpty) return Colors.blue.shade600;
    return _chartPalette[index % _chartPalette.length];
  }

  String _truncateLegendFoodName(String name, {int maxChars = 65}) {
    final clean = name.trim();
    if (clean.length <= maxChars) return clean;
    return '${clean.substring(0, maxChars).trimRight()}...';
  }

  String _truncateDialogFoodName(String name, {int maxChars = 30}) {
    final clean = name.trim();
    if (clean.length <= maxChars) return clean;
    return '${clean.substring(0, maxChars).trimRight()}...';
  }

  String _formatDateShort(DateTime? date) {
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _planDateRangeLabel(PlanNutricional plan) {
    final desde = _formatDateShort(plan.desde);
    final hasta = _formatDateShort(plan.hasta);
    if (desde.isNotEmpty && hasta.isNotEmpty) {
      return '$desde - $hasta';
    }
    return desde.isNotEmpty ? desde : hasta;
  }

  String _planWeeksOrDateLabel(PlanNutricional plan) {
    final semanasRaw = (plan.semanas ?? '').trim();
    final desde = _formatDateShort(plan.desde);
    final hasta = _formatDateShort(plan.hasta);
    final hasBothDates = desde.isNotEmpty && hasta.isNotEmpty;
    final dateLabel = _planDateRangeLabel(plan);

    final semanasLimpias = semanasRaw
        .replaceFirst(
          RegExp(
            r'^\s*plan\s+nutricional\s+para\s+semanas\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceFirst(RegExp(r'^[:\-\s]+'), '')
        .trim();

    final semanas = semanasLimpias.isNotEmpty ? semanasLimpias : semanasRaw;

    if (semanas.isNotEmpty && hasBothDates) {
      return '$semanas ($desde - $hasta)';
    }

    if (semanas.isEmpty && dateLabel.isNotEmpty) {
      return dateLabel;
    }

    if (semanasRaw.isNotEmpty) {
      return semanas;
    }

    return 'Plan código ${plan.codigo}';
  }

  Widget _metricTag({
    required String text,
    required Color color,
    bool emphasized = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(emphasized ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
          color: color.computeLuminance() > 0.55 ? Colors.black87 : color,
        ),
      ),
    );
  }

  Future<void> _openPlanStructure(PlanNutricional plan) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PlanNutriEstructuraScreen(plan: plan),
      ),
    );
    if (changed == true && mounted) {
      _reload();
    }
  }

  Future<void> _showPlanesForAlimento(Alimento alimento) async {
    final codigo = alimento.codigo;
    if (codigo == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Planes que usan ${_truncateDialogFoodName(alimento.nombre)}',
                style: const TextStyle(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(dialogContext).pop(),
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
          width: 440,
          child: FutureBuilder<List<PlanNutricional>>(
            future: _apiService.getPlanesForAlimento(codigo),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  'No se pudieron cargar los planes. ${snapshot.error.toString().replaceFirst('Exception: ', '')}',
                  style: const TextStyle(color: Colors.red),
                );
              }

              final plans = snapshot.data ?? const <PlanNutricional>[];
              if (plans.isEmpty) {
                return const Text(
                  'Este alimento no aparece en ningún plan nutricional en este momento.',
                );
              }

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    final headerText = _planWeeksOrDateLabel(plan);
                    final patientName = (plan.nombrePaciente ?? '').trim();
                    final isCompleted =
                        (plan.completado ?? '').toUpperCase() == 'S';

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        headerText.isNotEmpty
                            ? headerText
                            : 'Plan #${plan.codigo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Row(
                        children: [
                          Expanded(
                            child: Text(
                              patientName.isNotEmpty
                                  ? patientName
                                  : 'Sin paciente',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Tooltip(
                            message:
                                isCompleted ? 'Completado' : 'No completado',
                            child: Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? Colors.red.shade50
                                    : Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isCompleted
                                      ? Colors.red.shade300
                                      : Colors.blueGrey.shade300,
                                ),
                              ),
                              child: Text(
                                isCompleted ? 'C' : 'NC',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isCompleted
                                      ? Colors.red.shade700
                                      : Colors.blueGrey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () async {
                        Navigator.of(dialogContext).pop();
                        await _openPlanStructure(plan);
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopUsedFoodsChart(List<Alimento> items) {
    final top = _topUsedFoods(items, limit: 10);
    if (top.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child:
              Text('No hay suficientes datos de uso para mostrar el gráfico.'),
        ),
      );
    }

    final total = top.fold<int>(0, (sum, a) => sum + a.totalIngestas);
    final sections = top.asMap().entries.map((entry) {
      final i = entry.key;
      final food = entry.value;
      final pct = total == 0 ? 0 : ((food.totalIngestas / total) * 100).round();
      final showPctLabel = i < 5;
      return PieChartSectionData(
        color: _pieColorByIndex(i, top.length),
        value: food.totalIngestas.toDouble(),
        radius: 58,
        title: showPctLabel ? '$pct%' : '',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      );
    }).toList();

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top 10 alimentos más utilizados en planes',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'El gráfico respeta los filtros actuales aplicados en el catálogo. Pulsa los usos de cada alimento para ver los planes.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final stacked = availableWidth < 760;
                // Chart fills window: in side-by-side mode it takes 40% of available width
                final chartWidth = stacked
                    ? availableWidth
                    : (availableWidth * 0.40).clamp(220.0, 400.0);
                final chartHeight = stacked
                    ? (availableWidth * 0.65).clamp(200.0, 340.0)
                    : 300.0;

                final chart = SizedBox(
                  height: chartHeight,
                  width: chartWidth,
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      sectionsSpace: 1.2,
                      centerSpaceRadius: 32,
                    ),
                  ),
                );

                final legend = Wrap(
                  runSpacing: 8,
                  children: top.asMap().entries.map((entry) {
                    final i = entry.key;
                    final food = entry.value;
                    final color = _pieColorByIndex(i, top.length);
                    final pct = total == 0
                        ? 0
                        : ((food.totalIngestas / total) * 100).round();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(top: 3),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                Text(
                                  '${i + 1}. ${_truncateLegendFoodName(food.nombre)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Tooltip(
                                  message: 'Ver planes que usan este alimento',
                                  child: InkWell(
                                    onTap: () => _showPlanesForAlimento(food),
                                    borderRadius: BorderRadius.circular(999),
                                    child: _metricTag(
                                      text: '${food.totalIngestas} usos',
                                      color: color,
                                    ),
                                  ),
                                ),
                                _metricTag(
                                  text: '$pct%',
                                  color: color,
                                  emphasized: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );

                if (stacked) {
                  return Column(
                    children: [
                      chart,
                      const SizedBox(height: 12),
                      legend,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    chart,
                    const SizedBox(width: 16),
                    Expanded(child: legend),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool? _nextTriState(bool? value) {
    if (value == null) return true;
    if (value == true) return false;
    return null;
  }

  String _activeFilterLabel() {
    if (_filtroActivoSolo == null) return 'Activo';
    if (_filtroActivoSolo == true) return 'No activos';
    return 'Todos';
  }

  String _optionFilterLabel() {
    if (_filtroConOpcion == null) return 'Opción';
    if (_filtroConOpcion == true) return 'Sin opción';
    return 'Todas';
  }

  Widget _buildFiltersPanel() {
    return const SizedBox.shrink();
  }

  Widget _buildToggleFilterTag({
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withAlpha(120)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  bool _passesStateFilters(Alimento item) {
    final isActive = item.activo == 1;
    final hasOption = (item.opcion ?? '').toUpperCase() == 'S';

    final activeOk = _filtroActivoSolo == null
        ? true
        : (_filtroActivoSolo! ? isActive : !isActive);

    final optionOk = _filtroConOpcion == null
        ? true
        : (_filtroConOpcion! ? hasOption : !hasOption);

    return activeOk && optionOk;
  }

  Future<void> _showFiltrarAlimentosDialog() async {
    final tempGrupos = Set<int>.from(_codigoGruposFiltro);
    bool? tempActivo = _filtroActivoSolo;
    bool? tempOpcion = _filtroConOpcion;
    String searchQuery = '';
    bool showSearch = _showCategorySearch;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          final filtered = _grupos
              .where((g) =>
                  g.codigo != null &&
                  (searchQuery.isEmpty ||
                      g.nombre
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase())))
              .toList();

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Filtrar alimentos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: Icon(showSearch ? Icons.search_off : Icons.search),
                  tooltip: showSearch ? 'Ocultar buscar' : 'Mostrar buscar',
                  onPressed: () async {
                    showSearch = !showSearch;
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(_showCategorySearchKey, showSearch);
                    setDialog(() {});
                  },
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor:
                        showSearch ? Colors.blue.shade50 : Colors.grey.shade200,
                    foregroundColor:
                        showSearch ? Colors.blue.shade700 : Colors.black87,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Estado filter
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Activos'),
                        selected: tempActivo == true,
                        onSelected: (selected) {
                          setDialog(() {
                            tempActivo = selected ? true : null;
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Inactivos'),
                        selected: tempActivo == false,
                        onSelected: (selected) {
                          setDialog(() {
                            tempActivo = selected ? false : null;
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Opción'),
                        selected: tempOpcion == true,
                        onSelected: (selected) {
                          setDialog(() {
                            tempOpcion = selected ? true : null;
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('No opción'),
                        selected: tempOpcion == false,
                        onSelected: (selected) {
                          setDialog(() {
                            tempOpcion = selected ? false : null;
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Categorías section
                  if (showSearch) ...[
                    TextField(
                      onChanged: (value) {
                        setDialog(() {
                          searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar categoría...',
                        prefixIcon: IconButton(
                          tooltip: searchQuery.isNotEmpty
                              ? 'Limpiar búsqueda'
                              : 'Buscar',
                          onPressed: searchQuery.isNotEmpty
                              ? () {
                                  setDialog(() {
                                    searchQuery = '';
                                  });
                                }
                              : null,
                          icon: Icon(
                            searchQuery.isNotEmpty ? Icons.clear : Icons.search,
                            size: 20,
                          ),
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Ocultar búsqueda',
                          onPressed: () async {
                            showSearch = false;
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(
                                _showCategorySearchKey, showSearch);
                            setDialog(() {});
                          },
                          icon: const Icon(Icons.visibility_off_outlined,
                              size: 20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: filtered
                            .map(
                              (g) => CheckboxListTile(
                                dense: true,
                                value: tempGrupos.contains(g.codigo),
                                title: Text(g.nombre),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (checked) {
                                  setDialog(() {
                                    if (checked == true && g.codigo != null) {
                                      tempGrupos.add(g.codigo!);
                                    } else {
                                      tempGrupos.remove(g.codigo);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialog(() {
                    tempActivo = null;
                    tempOpcion = null;
                    tempGrupos.clear();
                  });
                },
                child: const Text('Limpiar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Aplicar'),
                    const SizedBox(width: 6),
                    if (tempGrupos.isNotEmpty)
                      Container(
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${tempGrupos.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    if (!mounted || result != true) return;

    setState(() {
      _filtroActivoSolo = tempActivo;
      _filtroConOpcion = tempOpcion;
      _codigoGruposFiltro
        ..clear()
        ..addAll(tempGrupos);
    });

    await _saveFiltroEstado();
    await _saveFiltroGrupos();
    _reload();
  }

  Future<Set<int>?> _showSelectCategoriasDialog(
      Set<int> initialSelected) async {
    final temp = Set<int>.from(initialSelected);
    String searchQuery = '';
    bool showSearch = _showCategorySearch;

    final picked = await showDialog<Set<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          final filtered = _grupos
              .where((g) =>
                  g.codigo != null &&
                  (searchQuery.isEmpty ||
                      g.nombre
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase())))
              .toList();

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Seleccionar categorías',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: Icon(showSearch ? Icons.search_off : Icons.search),
                  tooltip: showSearch ? 'Ocultar buscar' : 'Mostrar buscar',
                  onPressed: () async {
                    showSearch = !showSearch;
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(_showCategorySearchKey, showSearch);
                    setDialog(() {});
                  },
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor:
                        showSearch ? Colors.blue.shade50 : Colors.grey.shade200,
                    foregroundColor:
                        showSearch ? Colors.blue.shade700 : Colors.black87,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSearch) ...[
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) {
                        setDialog(() {
                          searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar categoría...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  setDialog(() {
                                    searchQuery = '';
                                  });
                                },
                                child: const Icon(Icons.clear, size: 20),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: filtered
                            .map(
                              (g) => CheckboxListTile(
                                dense: true,
                                value: temp.contains(g.codigo),
                                title: Text(g.nombre),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (checked) {
                                  setDialog(() {
                                    if (checked == true && g.codigo != null) {
                                      temp.add(g.codigo!);
                                    } else {
                                      temp.remove(g.codigo);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialog(() {
                    temp.clear();
                  });
                },
                child: const Text('Limpiar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, temp),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Aplicar'),
                    const SizedBox(width: 6),
                    _countBadge(
                      temp.length,
                      activeColor: Colors.green.shade600,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    return picked;
  }

  Future<void> _pickFiltroGrupos() async {
    await _showFiltrarAlimentosDialog();
  }

  Future<void> _toggleFiltersVisibility() async {
    await _showFiltrarAlimentosDialog();
  }

  Future<void> _loadGrupos() async {
    try {
      final grupos = await _apiService.getAlimentoGrupos();
      if (!mounted) return;
      setState(() {
        _grupos = grupos;
      });
    } catch (_) {}
  }

  Future<void> _loadHarvardCategorias() async {
    try {
      final cats = await _apiService.getHarvardCategorias();
      if (!mounted) return;
      setState(() {
        _harvardCategorias = cats;
      });
    } catch (_) {}
  }

  void _applySortSelection(_OrdenAlimentos orden) {
    setState(() {
      if (_ordenAlimentos == orden) {
        _ordenAscendente = !_ordenAscendente;
      } else {
        _ordenAlimentos = orden;
        _ordenAscendente = orden == _OrdenAlimentos.nombre ||
            orden == _OrdenAlimentos.categoria;
      }
    });
    _saveFiltroEstado();
  }

  List<Alimento> _sortAlimentos(List<Alimento> items) {
    final sorted = List<Alimento>.from(items);
    final compareNombre = (Alimento a, Alimento b) =>
        a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());

    switch (_ordenAlimentos) {
      case _OrdenAlimentos.nombre:
        sorted.sort((a, b) =>
            _ordenAscendente ? compareNombre(a, b) : compareNombre(b, a));
        break;
      case _OrdenAlimentos.fechaAlta:
        sorted.sort((a, b) {
          final codigoA = a.codigo ?? 0;
          final codigoB = b.codigo ?? 0;
          final byCodigo = _ordenAscendente
              ? codigoA.compareTo(codigoB)
              : codigoB.compareTo(codigoA);
          if (byCodigo != 0) return byCodigo;
          return compareNombre(a, b);
        });
        break;
      case _OrdenAlimentos.usos:
        sorted.sort((a, b) {
          final byUsos = _ordenAscendente
              ? a.totalIngestas.compareTo(b.totalIngestas)
              : b.totalIngestas.compareTo(a.totalIngestas);
          if (byUsos != 0) return byUsos;
          return compareNombre(a, b);
        });
        break;
      case _OrdenAlimentos.categoria:
        sorted.sort((a, b) {
          final catA = a.nombreGrupos.isNotEmpty
              ? a.nombreGrupos.first.toLowerCase()
              : (a.nombreGrupo ?? '').toLowerCase();
          final catB = b.nombreGrupos.isNotEmpty
              ? b.nombreGrupos.first.toLowerCase()
              : (b.nombreGrupo ?? '').toLowerCase();
          final byCat =
              _ordenAscendente ? catA.compareTo(catB) : catB.compareTo(catA);
          if (byCat != 0) return byCat;
          return compareNombre(a, b);
        });
        break;
    }
    return sorted;
  }

  void _reload() {
    setState(() {
      _future = _apiService.getAlimentos(
        search: _search,
        codigoGrupos: _codigoGruposFiltro.toList(),
      );
    });
    _future.then((items) {
      _harvardLearningAlimentos = items;
    }).catchError((_) {});
  }

  String _buildPdfFilterSummary() {
    final parts = <String>[];
    final search = _search.trim();
    if (search.isNotEmpty) {
      parts.add('Buscar: "$search"');
    }
    if (_codigoGruposFiltro.isNotEmpty) {
      parts.add(_gruposFiltroLabel());
    }
    if (_filtroActivoSolo != null) {
      parts.add('Activo: ${_filtroActivoSolo! ? 'Sí' : 'No'}');
    }
    if (_filtroConOpcion != null) {
      parts.add('Opción: ${_filtroConOpcion! ? 'Sí' : 'No'}');
    }
    if (parts.isEmpty) {
      return 'Sin filtros adicionales';
    }
    return parts.join(' | ');
  }

  Uint8List? _decodeBase64Image(String? base64String) {
    var data = (base64String ?? '').trim();
    if (data.isEmpty) return null;
    const marker = 'base64,';
    final index = data.indexOf(marker);
    if (index >= 0) {
      data = data.substring(index + marker.length);
    }
    while (data.length % 4 != 0) {
      data += '=';
    }
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _generateCatalogPdf() async {
    try {
      final loaded = await _future;
      final alimentos = loaded.where(_passesStateFilters).toList();

      if (alimentos.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay alimentos para exportar.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final nutricionistaParam =
          await _apiService.getParametro('nutricionista_nombre');
      final nutricionistaNombre =
          nutricionistaParam?['valor']?.toString() ?? 'Nutricionista';
      final nutricionistaSubtitulo =
          nutricionistaParam?['valor2']?.toString() ?? '';

      final logoParam =
          await _apiService.getParametro('logotipo_dietista_documentos');
      final logoBase64 = logoParam?['valor']?.toString() ?? '';
      final logoSizeStr = logoParam?['valor2']?.toString() ?? '';
      final logoBytes = _decodeBase64Image(logoBase64);

      final accentColorParam = await _apiService
          .getParametro('color_fondo_banda_encabezado_pie_pdf');
      final accentColorStr = accentColorParam?['valor']?.toString() ?? '';

      if (!mounted) return;

      await AlimentosCatalogPdfService.generateCatalogPdf(
        context: context,
        nutricionistaNombre: nutricionistaNombre,
        nutricionistaSubtitulo: nutricionistaSubtitulo,
        logoBytes: logoBytes,
        logoSizeStr: logoSizeStr,
        accentColorStr: accentColorStr,
        alimentos: alimentos,
        harvardCategorias: _harvardCategorias,
        filtroResumen: _buildPdfFilterSummary(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _search = '';
    _saveSearchState();
    _reload();
  }

  Future<void> _toggleSearchVisibility() async {
    setState(() {
      _showFilters = !_showFilters;
      if (!_showFilters) {
        _searchCtrl.clear();
        _search = '';
      }
    });
    await _saveSearchState();
    _reload();
  }

  void _toggleChartView() {
    setState(() {
      _showChartView = !_showChartView;
    });
  }

  /// Shows a floating toast above all dialogs using the Navigator overlay.
  void _showOverlayToast(
    BuildContext ctx,
    String message, {
    Color bgColor = const Color(0xFF323232),
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(ctx);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 32,
        left: 24,
        right: 24,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          color: bgColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(duration, () {
      if (entry.mounted) entry.remove();
    });
  }

  Widget _buildSearchField() {
    final hasSearch = _search.trim().isNotEmpty;
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Buscar alimento',
        prefixIcon: IconButton(
          tooltip: hasSearch ? 'Limpiar búsqueda' : 'Buscar',
          onPressed: hasSearch ? _clearSearch : null,
          icon: Icon(hasSearch ? Icons.clear : Icons.search),
        ),
        suffixIcon: IconButton(
          tooltip: 'Ocultar búsqueda',
          onPressed: () async {
            setState(() {
              _searchCtrl.clear();
              _search = '';
              _showFilters = false;
            });
            await _saveSearchState();
            _reload();
          },
          icon: const Icon(Icons.visibility_off_outlined),
        ),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) {
        setState(() {
          _search = v.trim();
        });
        _saveSearchState();
        _reload();
      },
    );
  }

  Future<void> _openEditor({Alimento? alimento}) async {
    List<AlimentoGrupo> grupos = List.of(_grupos);
    if (grupos.isEmpty) {
      try {
        grupos = await _apiService.getAlimentoGrupos();
        if (mounted) setState(() => _grupos = grupos);
      } catch (_) {}
    }
    List<HarvardCategoria> harvardCategorias = List.of(_harvardCategorias);
    if (harvardCategorias.isEmpty) {
      try {
        harvardCategorias = await _apiService.getHarvardCategorias();
        if (mounted) setState(() => _harvardCategorias = harvardCategorias);
      } catch (_) {}
    }
    if (!mounted) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => _AlimentoEditScreen(
          alimento: alimento,
          grupos: grupos,
          harvardCategorias: harvardCategorias,
        ),
      ),
    );

    if (ok != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alimento guardado'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _harvardLearningAlimentos = [];
    _reload();
    _loadGrupos();
    _loadHarvardCategorias();
  }

  Future<void> _delete(Alimento alimento) async {
    if (alimento.codigo == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar alimento'),
        content: Text('¿Seguro que quieres eliminar "${alimento.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _apiService.deleteAlimento(alimento.codigo!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alimento eliminado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;

      // Detectar si el error es porque el alimento está en planes
      final errorMsg = e.toString();
      if (errorMsg.contains('está incluido en uno o más planes')) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 32),
            title: const Text('No se puede eliminar'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${alimento.nombre} está incluido en uno o más planes nutricionales.'),
                const SizedBox(height: 12),
                const Text(
                  'Para eliminar este alimento, primero debes:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text('• Acceder a los planes nutricionales afectados'),
                const Text(
                    '• Reemplazar o eliminar este alimento de las ingestas'),
                const Text('• Guardar los cambios'),
                const SizedBox(height: 12),
                const Text(
                  'Si solo quieres que no aparezca en las listas de selección, puedes desactivarlo.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg.replaceFirst('Exception: ', ''),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleActivo(Alimento alimento) async {
    if (alimento.codigo == null) return;

    final actualizado = Alimento(
      codigo: alimento.codigo,
      nombre: alimento.nombre,
      codigoGrupo: alimento.codigoGrupo,
      codigoGrupos: alimento.codigoGrupos,
      activo: alimento.activo == 1 ? 0 : 1,
      observacion: alimento.observacion,
      opcion: alimento.opcion,
    );

    try {
      await _apiService.saveAlimento(actualizado);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            actualizado.activo == 1
                ? 'Alimento activado'
                : 'Alimento desactivado',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openRowMenu(Alimento alimento) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                alimento.activo == 1
                    ? Icons.cancel_outlined
                    : Icons.check_circle_outline,
              ),
              title: Text(
                alimento.activo == 1
                    ? 'Desactivar alimento'
                    : 'Activar alimento',
              ),
              onTap: () => Navigator.pop(context, 'toggle'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'toggle') {
      await _toggleActivo(alimento);
    } else if (action == 'edit') {
      await _openEditor(alimento: alimento);
    } else if (action == 'delete') {
      await _delete(alimento);
    }
  }

  Future<void> _openGruposDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'Categorías',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14),
              ),
            ),
            IconButton(
              onPressed: _gruposController.openNewGroup,
              icon: const Icon(Icons.add),
              tooltip: 'Nueva categoríao grupo',
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _gruposController.showSearchNotifier,
              builder: (context, showSearch, _) => IconButton(
                onPressed: _gruposController.toggleSearch,
                icon: Icon(showSearch ? Icons.search_off : Icons.search),
                tooltip: showSearch ? 'Ocultar buscar' : 'Mostrar buscar',
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              tooltip: 'Cerrar',
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          height: 480,
          child: AlimentoGruposScreen(
            embedded: true,
            controller: _gruposController,
            onChanged: () {
              _loadGrupos();
              _reload();
            },
          ),
        ),
      ),
    );
    if (!mounted) return;
    _loadGrupos();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final canShowUsageChart = _canShowUsageChart(context);
    final platform = Theme.of(context).platform;
    final isMobilePlatform =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<List<Alimento>>(
          future: _future,
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            final badge = Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
            final canToggle = canShowUsageChart;
            final badgeWidget = canToggle
                ? Tooltip(
                    message: _showChartView
                        ? 'Volver al listado'
                        : 'Ver gráfico de uso',
                    child: InkWell(
                      onTap: _toggleChartView,
                      borderRadius: BorderRadius.circular(999),
                      child: badge,
                    ),
                  )
                : badge;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Alimentos'),
                const SizedBox(width: 8),
                badgeWidget,
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.search_off : Icons.search,
            ),
            tooltip: _showFilters ? 'Ocultar buscar' : 'Buscar',
            onPressed: _toggleSearchVisibility,
          ),
          // Botón Filtrar
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_alt),
                tooltip: 'Filtrar alimentos',
                onPressed: _toggleFiltersVisibility,
              ),
              if (_codigoGruposFiltro.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${_codigoGruposFiltro.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Menú de opciones
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            onSelected: (value) {
              switch (value) {
                case 'search':
                  _toggleSearchVisibility();
                  break;
                case 'filter':
                  _toggleFiltersVisibility();
                  break;
                case 'categories':
                  _openGruposDialog();
                  break;
                case 'pdf':
                  _generateCatalogPdf();
                  break;
                case 'chart':
                  _toggleChartView();
                  break;
                case 'refresh':
                  _reload();
                  break;
                case 'sort_usos':
                  _applySortSelection(_OrdenAlimentos.usos);
                  break;
                case 'sort_nombre':
                  _applySortSelection(_OrdenAlimentos.nombre);
                  break;
                case 'sort_fecha':
                  _applySortSelection(_OrdenAlimentos.fechaAlta);
                  break;
                case 'sort_categoria':
                  _applySortSelection(_OrdenAlimentos.categoria);
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(
                      _showFilters ? Icons.search_off : Icons.search,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(_showFilters ? 'Ocultar buscar' : 'Buscar'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'filter',
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox(width: 18, height: 18),
                        const Icon(Icons.filter_alt, size: 18),
                        if (_codigoGruposFiltro.isNotEmpty)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              constraints: const BoxConstraints(
                                  minWidth: 14, minHeight: 14),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 3, vertical: 1),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${_codigoGruposFiltro.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    const Text('Filtrar'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'categories',
                child: Row(
                  children: [
                    Icon(Icons.category, size: 18),
                    SizedBox(width: 10),
                    Text('Categorías'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Generar PDF'),
                  ],
                ),
              ),
              if (canShowUsageChart)
                PopupMenuItem(
                  value: 'chart',
                  child: Row(
                    children: [
                      Icon(
                        _showChartView
                            ? Icons.view_list_outlined
                            : Icons.pie_chart_outline,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _showChartView ? 'Mostrar listado' : 'Mostrar gráfico',
                      ),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 10),
                    Text('Actualizar'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                value: 'sort_usos',
                checked: _ordenAlimentos == _OrdenAlimentos.usos,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar usos')),
                    if (_ordenAlimentos == _OrdenAlimentos.usos)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem(
                value: 'sort_nombre',
                checked: _ordenAlimentos == _OrdenAlimentos.nombre,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Nombre')),
                    if (_ordenAlimentos == _OrdenAlimentos.nombre)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem(
                value: 'sort_fecha',
                checked: _ordenAlimentos == _OrdenAlimentos.fechaAlta,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar Recientes')),
                    if (_ordenAlimentos == _OrdenAlimentos.fechaAlta)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
              CheckedPopupMenuItem(
                value: 'sort_categoria',
                checked: _ordenAlimentos == _OrdenAlimentos.categoria,
                child: Row(
                  children: [
                    const Expanded(child: Text('Ordenar categoría')),
                    if (_ordenAlimentos == _OrdenAlimentos.categoria)
                      Icon(
                        _ordenAscendente
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (_showFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  _buildSearchField(),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Alimento>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final items = (snapshot.data ?? const [])
                    .where(_passesStateFilters)
                    .toList();
                final sortedItems = _sortAlimentos(items);
                final maxIngestas = sortedItems.fold<int>(
                  0,
                  (maxValue, e) =>
                      e.totalIngestas > maxValue ? e.totalIngestas : maxValue,
                );
                if (sortedItems.isEmpty) {
                  return const Center(child: Text('No hay alimentos.'));
                }
                final listWidget = ListView.separated(
                  itemCount: sortedItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = sortedItems[index];
                    final usageColor =
                        _usageBadgeColor(item.totalIngestas, maxIngestas);
                    final usageTextColor = _usageBadgeTextColor(usageColor);
                    final isInactive = item.activo != 1;
                    final isOptionS = (item.opcion ?? '').toUpperCase() == 'S';
                    return Dismissible(
                      key: ValueKey(
                          'alimento_${item.codigo ?? item.nombre}_$index'),
                      direction: DismissDirection.startToEnd,
                      dismissThresholds: {
                        DismissDirection.startToEnd: context
                            .watch<ConfigService>()
                            .deleteSwipeDismissThreshold,
                      },
                      background: Container(
                        color: Colors.red.shade600,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Row(
                          children: [
                            Icon(Icons.delete_outline,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      confirmDismiss: (_) async {
                        await _delete(item);
                        return false;
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _openEditor(alimento: item),
                                onLongPress: () => _openRowMenu(item),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        item.nombre,
                                        style: TextStyle(
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (!isMobilePlatform)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _gruposAlimentoLabel(item),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.black54,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (item.harvardCategoria != null)
                                              _harvardSubtitleChip(item),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (isOptionS) ...[
                              _smallStatusTag(
                                label: 'OP',
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (isInactive) ...[
                              _smallStatusTag(
                                label: 'AC',
                                color: Colors.red.shade600,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Tooltip(
                              message: item.totalIngestas > 0
                                  ? 'Ver planes donde aparece este alimento'
                                  : 'Este alimento aún no aparece en planes',
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: item.totalIngestas > 0
                                      ? () => _showPlanesForAlimento(item)
                                      : null,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                        minWidth: 24, minHeight: 24),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: usageColor,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${item.totalIngestas}',
                                      style: TextStyle(
                                        color: usageTextColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.more_vert, size: 20),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              tooltip: 'Más opciones',
                              onPressed: () => _openRowMenu(item),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    );
                  },
                );

                if (canShowUsageChart && _showChartView) {
                  return SingleChildScrollView(
                    child: _buildTopUsedFoodsChart(items),
                  );
                }

                return listWidget;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AlimentoEditScreen extends StatefulWidget {
  const _AlimentoEditScreen({
    required this.alimento,
    required this.grupos,
    required this.harvardCategorias,
  });

  final Alimento? alimento;
  final List<AlimentoGrupo> grupos;
  final List<HarvardCategoria> harvardCategorias;

  @override
  State<_AlimentoEditScreen> createState() => _AlimentoEditScreenState();
}

class _AlimentoEditScreenState extends State<_AlimentoEditScreen> {
  static const String _cardPrefsPrefix = 'alimento_card_';

  final ApiService _apiService = ApiService();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _obsCtrl;

  late final String _initialNombre;
  late final String _initialObs;
  late final bool _initialActivo;
  late final bool _initialOpcion;
  late final Set<int> _initialGrupos;
  late final Set<String> _initialHarvard;

  final List<Alimento> _harvardLearningAlimentos = <Alimento>[];
  late Set<int> _selectedGrupos;
  late Set<String> _selectedHarvardCategorias;
  late bool _activo;
  late bool _opcion;

  bool _saving = false;
  bool _categoriasExpanded = false;
  bool _harvardExpanded = false;
  bool _activoOpcionExpanded = false;
  bool _observacionExpanded = false;

  bool get _isEditing => widget.alimento != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.alimento?.nombre ?? '');
    _obsCtrl = TextEditingController(text: widget.alimento?.observacion ?? '');

    _selectedGrupos = (widget.alimento?.codigoGrupos ?? const <int>[])
        .where((id) => widget.grupos.any((g) => g.codigo == id))
        .toSet();
    if (_selectedGrupos.isEmpty && widget.alimento?.codigoGrupo != null) {
      final legacy = widget.alimento!.codigoGrupo!;
      if (widget.grupos.any((g) => g.codigo == legacy)) {
        _selectedGrupos.add(legacy);
      }
    }

    _selectedHarvardCategorias = Set<String>.from(
      widget.alimento?.harvardCategorias.isNotEmpty == true
          ? widget.alimento!.harvardCategorias
          : (widget.alimento?.harvardCategoria != null
              ? <String>[widget.alimento!.harvardCategoria!]
              : const <String>[]),
    );

    _activo = (widget.alimento?.activo ?? 1) == 1;
    _opcion = (widget.alimento?.opcion ?? '') == 'S';

    _initialNombre = (widget.alimento?.nombre ?? '').trim();
    _initialObs = (widget.alimento?.observacion ?? '').trim();
    _initialActivo = _activo;
    _initialOpcion = _opcion;
    _initialGrupos = Set<int>.from(_selectedGrupos);
    _initialHarvard = Set<String>.from(_selectedHarvardCategorias);

    _loadExpansionPrefs();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExpansionPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _observacionExpanded =
          prefs.getBool('${_cardPrefsPrefix}observacion') ?? false;
      _categoriasExpanded =
          prefs.getBool('${_cardPrefsPrefix}categorias') ?? false;
      _activoOpcionExpanded =
          prefs.getBool('${_cardPrefsPrefix}activo_opcion') ?? false;
      _harvardExpanded = prefs.getBool('${_cardPrefsPrefix}harvard') ?? false;
    });
  }

  Future<void> _saveExpandedPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_cardPrefsPrefix}$key', value);
  }

  bool _sameIntSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b) && b.containsAll(a);

  bool _sameStringSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b) && b.containsAll(a);

  bool _hasPendingChanges() {
    return _nombreCtrl.text.trim() != _initialNombre ||
        _obsCtrl.text.trim() != _initialObs ||
        _activo != _initialActivo ||
        _opcion != _initialOpcion ||
        !_sameIntSet(_selectedGrupos, _initialGrupos) ||
        !_sameStringSet(_selectedHarvardCategorias, _initialHarvard);
  }

  Future<void> _handleClose() async {
    if (_hasPendingChanges()) {
      final canClose = await showUnsavedChangesDialog(context);
      if (!canClose || !mounted) return;
    }
    Navigator.pop(context, false);
  }

  Future<void> _save() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre es obligatorio.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final payload = Alimento(
      codigo: widget.alimento?.codigo,
      nombre: nombre,
      codigoGrupo: _selectedGrupos.isNotEmpty ? _selectedGrupos.first : null,
      codigoGrupos: _selectedGrupos.toList(),
      activo: _activo ? 1 : 0,
      observacion: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      opcion: _opcion ? 'S' : 'N',
      harvardCategoria: _selectedHarvardCategorias.isNotEmpty
          ? _selectedHarvardCategorias.first
          : null,
      harvardCategorias: _selectedHarvardCategorias.toList(),
    );

    try {
      await _apiService.saveAlimento(payload);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _saving = false;
      });
    }
  }

  String _normalizeForHarvardMatch(String text) {
    var value = text.toLowerCase().trim();
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    replacements.forEach((from, to) {
      value = value.replaceAll(from, to);
    });
    value = value
        .replaceAll(RegExp(r'[^a-z0-9\s\+]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return value;
  }

  Set<String> _harvardMeaningfulTokens(String rawName) {
    final normalized = _normalizeForHarvardMatch(rawName);
    if (normalized.isEmpty) return <String>{};

    const stopwords = {
      'de',
      'del',
      'la',
      'el',
      'los',
      'las',
      'y',
      'o',
      'con',
      'sin',
      'al',
      'a',
      'en',
      'para',
      'por',
      'un',
      'una',
      'unos',
      'unas',
      'tipo',
      'fuente',
      'varios',
      'varias',
      'mas',
      'menos',
    };

    return normalized
        .split(RegExp(r'\s+|\+'))
        .map((e) => e.trim())
        .where((e) => e.length >= 3 && !stopwords.contains(e))
        .toSet();
  }

  List<String> _harvardAssignedCodes(Alimento alimento) {
    if (alimento.harvardCategorias.isNotEmpty) {
      return alimento.harvardCategorias;
    }
    if ((alimento.harvardCategoria ?? '').trim().isNotEmpty) {
      return [alimento.harvardCategoria!.trim()];
    }
    return const <String>[];
  }

  Future<List<Alimento>> _getHarvardLearningAlimentos() async {
    if (_harvardLearningAlimentos.isNotEmpty) {
      return _harvardLearningAlimentos;
    }
    final items = await _apiService.getAlimentos();
    _harvardLearningAlimentos
      ..clear()
      ..addAll(items);
    return _harvardLearningAlimentos;
  }

  Set<String> _inferHarvardCategoriasFromLearning(
    String rawName,
    List<Alimento> knownFoods,
  ) {
    final targetTokens = _harvardMeaningfulTokens(rawName);
    if (targetTokens.isEmpty) return <String>{};

    final scores = <String, int>{};
    final normalizedTarget = _normalizeForHarvardMatch(rawName);

    for (final food in knownFoods) {
      final categories = _harvardAssignedCodes(food);
      if (categories.isEmpty) continue;

      final knownTokens = _harvardMeaningfulTokens(food.nombre);
      if (knownTokens.isEmpty) continue;

      final overlap = targetTokens.intersection(knownTokens).length;
      if (overlap == 0) continue;

      var weight = overlap;
      final normalizedKnown = _normalizeForHarvardMatch(food.nombre);
      if (normalizedKnown == normalizedTarget) {
        weight += 4;
      } else if (normalizedKnown.contains(normalizedTarget) ||
          normalizedTarget.contains(normalizedKnown)) {
        weight += 2;
      }

      for (final category in categories) {
        scores[category] = (scores[category] ?? 0) + weight;
      }
    }

    if (scores.isEmpty) return <String>{};
    final maxScore = scores.values.reduce((a, b) => a > b ? a : b);
    final minScore = maxScore >= 4 ? maxScore - 2 : 1;

    return scores.entries
        .where((entry) => entry.value >= minScore)
        .map((entry) => entry.key)
        .toSet();
  }

  Set<String> _inferHarvardCategoriasFromName(String rawName) {
    final text = _normalizeForHarvardMatch(rawName);
    if (text.isEmpty) return <String>{};

    final isPlainTortilla = text == 'tortilla' || text.startsWith('tortilla ');
    final isGrainTortilla = isPlainTortilla &&
        (text.contains('trigo') ||
            text.contains('wrap') ||
            text.contains('mexicana') ||
            text.contains('integral') ||
            text.contains('maiz'));

    bool hasAny(List<String> keywords) {
      return keywords.any((k) => text.contains(k));
    }

    final isBocadillo = text == 'bocadillo' || text.startsWith('bocadillo ');
    final isIntegralBocadillo =
        isBocadillo && (text.contains('integral') || text.contains('centeno'));
    final isVegetableBurger = text.contains('hamburguesa') &&
        hasAny([
          'vegetal',
          'vegana',
          'vegano',
          'lenteja',
          'garbanzo',
          'alubia',
          'judia',
          'soja',
          'tofu',
          'tempeh',
        ]);
    final isWhiteFilete = text.contains('filete') &&
        hasAny([
          'pollo',
          'pavo',
          'conejo',
          'pescado',
          'atun',
          'salmon',
          'merluza',
          'bacalao',
          'lenguado',
          'rape',
          'dorada',
          'lubina',
        ]);
    final isRedFilete = text.contains('filete') &&
        !isWhiteFilete &&
        !hasAny(['tofu', 'tempeh', 'soja', 'vegetal', 'vegano', 'vegana']);
    final isSavoryCrema = (text == 'crema' || text.startsWith('crema ')) &&
        !hasAny([
          'cacao',
          'chocolate',
          'cacahuete',
          'avellana',
          'almendra',
          'nata',
          'pastelera',
          'dulce',
        ]);

    final inferred = <String>{};

    if (hasAny([
          'verdura',
          'verduras',
          'hortaliza',
          'hortalizas',
          'ensalada',
          'brocoli',
          'espinaca',
          'calabacin',
          'calabaza',
          'zanahoria',
          'tomate',
          'pimiento',
          'cebolla',
          'coliflor',
          'berenjena',
          'berengena',
          'judia verde',
          'judias verdes',
          'guisante',
          'guisantes',
          'pepino',
          'seta',
          'champinon',
          'champiñon',
          'champiñones',
          'esparrago',
          'acelga',
          'col',
          'kale',
          'lechuga',
        ]) ||
        isSavoryCrema) {
      inferred.add('verdura');
    }

    if (hasAny([
      'fruta',
      'frutas',
      'manzana',
      'platano',
      'banana',
      'pera',
      'naranja',
      'mandarina',
      'uva',
      'melon',
      'sandia',
      'kiwi',
      'fresa',
      'frambuesa',
      'mango',
      'papaya',
      'pina',
      'cereza',
      'ciruela',
      'albaricoque',
      'melocoton',
      'nectarina',
      'higo',
      'granada',
      'arandano',
    ])) {
      inferred.add('fruta');
    }

    if (hasAny([
          'integral',
          'cereal integral',
          'cereales integrales',
          'pasta integral',
          'arroz integral',
          'pan integral',
          'avena',
          'quinoa',
          'centeno',
          'espelta',
          'bulgur',
          'mijo',
          'trigo sarraceno',
        ]) ||
        (isGrainTortilla &&
            (text.contains('integral') || text.contains('maiz'))) ||
        isIntegralBocadillo) {
      inferred.add('cereal_integral');
    }

    if (hasAny([
          'pan blanco',
          'pasta blanca',
          'arroz blanco',
          'paella',
          'cereal refinado',
          'cereales refinados',
          'harina refinada',
          'galleta',
          'bolleria',
          'croissant',
          'donut',
        ]) ||
        (isGrainTortilla &&
            (text.contains('trigo') ||
                text.contains('wrap') ||
                text.contains('mexicana'))) ||
        (isBocadillo && !isIntegralBocadillo)) {
      inferred.add('cereal_refinado');
    }

    if (hasAny([
      'legumbre',
      'legumbres',
      'lenteja',
      'garbanzo',
      'alubia',
      'judia',
      'soja',
      'tofu',
      'tempeh',
      'hummus',
      'proteina vegetal',
      'proteina',
    ])) {
      inferred.add('proteina_vegetal');
    }

    if (hasAny([
          'pescado',
          'atun',
          'salmon',
          'merluza',
          'bacalao',
          'sardina',
          'boqueron',
          'caballa',
          'trucha',
          'dorada',
          'lubina',
          'rape',
          'rodaballo',
          'lenguado',
          'pulpo',
          'calamar',
          'sepia',
          'marisco',
          'mariscos',
          'molusco',
          'moluscos',
          'gamba',
          'gambas',
          'camaron',
          'camarones',
          'langostino',
          'langostinos',
          'cigala',
          'cigalas',
          'navaja',
          'navajas',
          'vieira',
          'vieiras',
          'mejillon',
          'mejillones',
          'almeja',
          'almejas',
          'ostra',
          'ostras',
          'pollo',
          'pavo',
          'conejo',
          'huevo',
          'huevos',
          'carne',
          'tortilla',
        ]) &&
        !isGrainTortilla) {
      inferred.add('proteina_blanca');
    }

    if (hasAny([
              'ternera',
              'vacuno',
              'buey',
              'cordero',
              'cerdo',
              'carne roja',
              'hamburguesa',
              'chuleta',
              'entrecot',
              'solomillo',
            ]) &&
            !isVegetableBurger ||
        isRedFilete) {
      inferred.add('proteina_roja');
    }

    if (hasAny([
      'embutido',
      'salchicha',
      'fiambre',
      'chorizo',
      'salami',
      'mortadela',
      'bacon',
      'beicon',
      'jamon cocido',
      'jamon york',
      'carne procesada',
      'nugget',
    ])) {
      inferred.add('proteina_procesada');
    }

    if (hasAny([
      'leche',
      'yogur',
      'yogurt',
      'queso',
      'kefir',
      'cuajada',
      'requeson',
      'lacteo',
      'lacteos',
    ])) {
      inferred.add('lacteo');
    }

    if (hasAny([
      'aceite',
      'aceite de oliva',
      'oliva',
      'aguacate',
      'nuez',
      'almendra',
      'avellana',
      'pistacho',
      'cacahuete',
      'semilla',
      'chia',
      'linaza',
      'sesamo',
    ])) {
      inferred.add('grasa_saludable');
    }

    if (hasAny([
      'mantequilla',
      'margarina',
      'grasa trans',
      'palma',
      'frito',
      'fritura',
      'mayonesa',
    ])) {
      inferred.add('grasa_no_saludable');
    }

    if (hasAny([
      'agua',
      'infusion',
      'te',
      'cafe',
      'cafe solo',
      'cafe americano',
    ])) {
      inferred.add('agua');
    }

    if (hasAny([
      'refresco',
      'cola',
      'bebida azucarada',
      'zumo industrial',
      'energy drink',
      'energetica',
      'batido azucarado',
    ])) {
      inferred.add('bebida_azucarada');
    }

    return inferred;
  }

  Widget _countBadge(int count, {required Color activeColor}) {
    final color = count == 0 ? Colors.grey.shade400 : activeColor;
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _activeOptionTag({
    required String label,
    required bool active,
    VoidCallback? onTap,
  }) {
    final tag = Container(
      width: 24,
      height: 22,
      decoration: BoxDecoration(
        color: active ? Colors.green : Colors.grey,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    if (onTap == null) return tag;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: tag,
      ),
    );
  }

  Future<Set<int>?> _showSelectCategoriasDialog(
      Set<int> initialSelected) async {
    final temp = Set<int>.from(initialSelected);
    String searchQuery = '';
    bool showSearch = false;

    return showDialog<Set<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          final filtered = widget.grupos
              .where(
                (g) =>
                    g.codigo != null &&
                    (searchQuery.isEmpty ||
                        g.nombre
                            .toLowerCase()
                            .contains(searchQuery.toLowerCase())),
              )
              .toList();

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Seleccionar categorías',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: Icon(showSearch ? Icons.search_off : Icons.search),
                  tooltip: showSearch ? 'Ocultar buscar' : 'Mostrar buscar',
                  onPressed: () {
                    setDialog(() {
                      showSearch = !showSearch;
                      if (!showSearch) {
                        searchQuery = '';
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSearch) ...[
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) {
                        setDialog(() {
                          searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar categoría...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  setDialog(() {
                                    searchQuery = '';
                                  });
                                },
                                child: const Icon(Icons.clear, size: 20),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: filtered
                            .map(
                              (g) => CheckboxListTile(
                                dense: true,
                                value: temp.contains(g.codigo),
                                title: Text(g.nombre),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (checked) {
                                  setDialog(() {
                                    if (checked == true && g.codigo != null) {
                                      temp.add(g.codigo!);
                                    } else {
                                      temp.remove(g.codigo);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialog(() {
                    temp.clear();
                  });
                },
                child: const Text('Limpiar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, temp),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Aplicar'),
                    const SizedBox(width: 6),
                    _countBadge(temp.length,
                        activeColor: Colors.green.shade600),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Set<String>?> _showSelectHarvardDialog(Set<String> initial) async {
    final selected = Set<String>.from(initial);
    return showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Categorías Harvard',
                  style: TextStyle(fontSize: 15),
                ),
              ),
              IconButton(
                tooltip: 'Cancelar',
                onPressed: () => Navigator.pop(ctx),
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
            width: 380,
            height: 360,
            child: ListView(
              children: [
                CheckboxListTile(
                  dense: true,
                  title: const Text('Sin clasificar'),
                  value: selected.isEmpty,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (_) => setLocal(() => selected.clear()),
                ),
                const Divider(height: 1),
                ...widget.harvardCategorias.map((cat) {
                  return CheckboxListTile(
                    dense: true,
                    value: selected.contains(cat.codigo),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: cat.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            cat.iconoEmoji.isNotEmpty
                                ? '${cat.iconoEmoji} ${cat.nombre}'
                                : cat.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!cat.esRecomendado)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Text('⚠️', style: TextStyle(fontSize: 11)),
                          ),
                      ],
                    ),
                    onChanged: (checked) {
                      setLocal(() {
                        if (checked == true) {
                          selected.add(cat.codigo);
                        } else {
                          selected.remove(cat.codigo);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setLocal(() => selected.clear()),
              child: const Text('Limpiar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Aplicar'),
                  const SizedBox(width: 8),
                  _countBadge(selected.length,
                      activeColor: Colors.green.shade600),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHarvardSelector() {
    final selected = _selectedHarvardCategorias;
    final cats = widget.harvardCategorias;
    final Color harvardBadgeColor;
    if (selected.isEmpty) {
      harvardBadgeColor = Colors.grey.shade400;
    } else {
      final selectedCats =
          cats.where((c) => selected.contains(c.codigo)).toList();
      harvardBadgeColor = selectedCats.any((c) => !c.esRecomendado)
          ? Colors.red.shade600
          : Colors.green.shade600;
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.green.shade300),
      ),
      child: ExpansionTile(
        initiallyExpanded: _harvardExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _harvardExpanded = expanded;
          });
          _saveExpandedPref('harvard', expanded);
        },
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        title: Row(
          children: [
            Text(
              'Harvard',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Ver información sobre el Plato de Harvard',
              child: InkWell(
                onTap: () => _showHarvardInfoDialog(context),
                borderRadius: BorderRadius.circular(999),
                child: _countBadge(selected.length,
                    activeColor: harvardBadgeColor),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () async {
                final catalogFoods = await _getHarvardLearningAlimentos();
                final inferred = {
                  ..._inferHarvardCategoriasFromName(_nombreCtrl.text),
                  ..._inferHarvardCategoriasFromLearning(
                    _nombreCtrl.text,
                    catalogFoods.where((food) {
                      if (widget.alimento?.codigo == null ||
                          food.codigo == null) {
                        return true;
                      }
                      return food.codigo != widget.alimento!.codigo;
                    }).toList(),
                  ),
                }
                    .where((code) =>
                        widget.harvardCategorias.any((c) => c.codigo == code))
                    .toSet();

                if (!mounted) return;
                setState(() {
                  _selectedHarvardCategorias
                    ..clear()
                    ..addAll(inferred);
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      inferred.isEmpty
                          ? 'No se detectaron categorías Harvard automáticamente'
                          : '${inferred.length} categoría(s) Harvard sugerida(s) automáticamente',
                    ),
                    backgroundColor: inferred.isEmpty
                        ? Colors.grey.shade700
                        : Colors.green.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              tooltip: 'Autodescubrir categorías Harvard por nombre',
              icon: Icon(Icons.auto_awesome,
                  size: 16, color: Colors.amber.shade700),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () async {
                final picked = await _showSelectHarvardDialog(selected);
                if (picked == null) return;
                setState(() {
                  _selectedHarvardCategorias
                    ..clear()
                    ..addAll(picked);
                });
              },
              tooltip: 'Seleccionar categorías Harvard',
              icon: Icon(Icons.restaurant_menu_outlined,
                  size: 16, color: Colors.green.shade700),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              height: 110,
              width: double.infinity,
              child: selected.isEmpty
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sin categorías Harvard',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: cats
                              .where((c) => selected.contains(c.codigo))
                              .map(
                                (c) => Chip(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: c.color.withOpacity(0.14),
                                  side: BorderSide(
                                      color: c.color.withOpacity(0.4)),
                                  label: Text(
                                    c.iconoEmoji.isNotEmpty
                                        ? '${c.iconoEmoji} ${c.nombre}'
                                        : c.nombre,
                                    style: TextStyle(
                                      color: c.color.withOpacity(0.95),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
            ),
          ),
        ],
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
              child: Text(
                'El Plato de Harvard',
                style: TextStyle(fontSize: 16),
              ),
            ),
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
                  'El Plato de Harvard, desarrollado por la Escuela de Salud Pública de Harvard, es una guía visual para construir comidas equilibradas y saludables.',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 12),
                Text(
                  'Proporciones recomendadas:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                _HarvardInfoRow(
                  emoji: '🥗',
                  seccion: '½ plato',
                  desc:
                      'Verduras y frutas variadas. Cuanto más variedad y color, mejor.',
                ),
                _HarvardInfoRow(
                  emoji: '🌾',
                  seccion: '¼ plato',
                  desc:
                      'Cereales integrales: avena, arroz integral, pasta integral, pan integral.',
                ),
                _HarvardInfoRow(
                  emoji: '🫘',
                  seccion: '¼ plato',
                  desc:
                      'Proteínas saludables: legumbres, pescado, pollo, huevos, frutos secos.',
                ),
                _HarvardInfoRow(
                  emoji: '🫒',
                  seccion: 'Aceites',
                  desc:
                      'Grasas saludables como el aceite de oliva virgen extra. Evitar trans.',
                ),
                _HarvardInfoRow(
                  emoji: '💧',
                  seccion: 'Bebidas',
                  desc:
                      'Agua como bebida principal. Infusiones y café sin azúcar.',
                ),
                SizedBox(height: 12),
                Text(
                  'Lo que el plato recomienda limitar:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                _HarvardInfoRow(
                  emoji: '🥩',
                  seccion: 'Limitar',
                  desc: 'Carne roja: máximo 1-2 veces por semana.',
                ),
                _HarvardInfoRow(
                  emoji: '🌭',
                  seccion: 'Evitar',
                  desc: 'Carnes procesadas: embutidos, fiambres, salchichas.',
                ),
                _HarvardInfoRow(
                  emoji: '🥤',
                  seccion: 'Evitar',
                  desc:
                      'Bebidas azucaradas: refrescos, zumos industriales, bebidas energéticas.',
                ),
                _HarvardInfoRow(
                  emoji: '🍞',
                  seccion: 'Limitar',
                  desc:
                      'Cereales refinados: pan blanco, pasta blanca, arroz blanco.',
                ),
                SizedBox(height: 10),
                Text(
                  'Nota: esta evaluación es orientativa y basada en el recuento de alimentos clasificados. No tiene en cuenta cantidades ni gramajes.',
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleClose();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleClose,
          ),
          title: Text(_isEditing ? 'Editar alimento' : 'Nuevo alimento'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _nombreCtrl,
                    minLines: 3,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: _categoriasExpanded,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          _categoriasExpanded = expanded;
                        });
                        _saveExpandedPref('categorias', expanded);
                      },
                      shape: const Border(),
                      collapsedShape: const Border(),
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      title: Row(
                        children: [
                          const Text(
                            'Categorías',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          _countBadge(
                            _selectedGrupos.length,
                            activeColor: Colors.green.shade600,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () async {
                              final picked = await _showSelectCategoriasDialog(
                                Set<int>.from(_selectedGrupos),
                              );
                              if (picked == null) return;
                              setState(() {
                                _selectedGrupos
                                  ..clear()
                                  ..addAll(picked);
                              });
                            },
                            tooltip: 'Seleccionar categorías',
                            icon: const Icon(Icons.category_outlined, size: 18),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 24, minHeight: 24),
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: SizedBox(
                            height: 104,
                            width: double.infinity,
                            child: _selectedGrupos.isEmpty
                                ? const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('Sin categorías'),
                                  )
                                : Scrollbar(
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: widget.grupos
                                            .where(
                                              (g) =>
                                                  g.codigo != null &&
                                                  _selectedGrupos
                                                      .contains(g.codigo),
                                            )
                                            .map(
                                              (g) => Chip(
                                                label: Text(g.nombre),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.harvardCategorias.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildHarvardSelector(),
                  ],
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: ExpansionTile(
                      initiallyExpanded: _activoOpcionExpanded,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          _activoOpcionExpanded = expanded;
                        });
                        _saveExpandedPref('activo_opcion', expanded);
                      },
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      title: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Activo/Opción',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          _activeOptionTag(
                            label: 'A',
                            active: _activo,
                            onTap: () => setState(() => _activo = !_activo),
                          ),
                          const SizedBox(width: 6),
                          _activeOptionTag(
                            label: 'O',
                            active: _opcion,
                            onTap: () => setState(() => _opcion = !_opcion),
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Column(
                            children: [
                              SwitchListTile(
                                value: _activo,
                                onChanged: (v) => setState(() => _activo = v),
                                title: const Text('Activo'),
                                contentPadding: EdgeInsets.zero,
                              ),
                              SwitchListTile(
                                value: _opcion,
                                onChanged: (v) => setState(() => _opcion = v),
                                title: const Text('Opción'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: ExpansionTile(
                      initiallyExpanded: _observacionExpanded,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          _observacionExpanded = expanded;
                        });
                        _saveExpandedPref('observacion', expanded);
                      },
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      title: Row(
                        children: [
                          const Text(
                            'Observación',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          _countBadge(
                            _obsCtrl.text.trim().length,
                            activeColor: Colors.green.shade600,
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: TextField(
                            controller: _obsCtrl,
                            maxLines: 4,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style:
                    DefaultTextStyle.of(context).style.copyWith(fontSize: 12),
                children: [
                  TextSpan(
                    text: '$seccion: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
