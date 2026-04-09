import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/entrenamiento.dart';
import 'package:nutri_app/models/entrenamiento_ejercicio.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/training_progress_pdf_service.dart';
import 'package:nutri_app/services/training_weight_progress_excel_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EntrenamientoWeightProgressChart extends StatefulWidget {
  const EntrenamientoWeightProgressChart({
    super.key,
    required this.entrenamientos,
    required this.loadEjercicios,
  });

  final List<Entrenamiento> entrenamientos;
  final Future<List<EntrenamientoEjercicio>> Function(int codigoEntrenamiento)
      loadEjercicios;

  @override
  State<EntrenamientoWeightProgressChart> createState() =>
      _EntrenamientoWeightProgressChartState();
}

class _EntrenamientoWeightProgressChartState
    extends State<EntrenamientoWeightProgressChart> {
  static const String _selectedSeriesPreferenceKey =
      'training_weight_progress_selected_series';
  static const String _selectionSearchVisiblePreferenceKey =
      'training_weight_progress_selection_search_visible';
  static const String _selectionSearchQueryPreferenceKey =
      'training_weight_progress_selection_search_query';

  static const List<Color> _seriesPalette = <Color>[
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFEF6C00),
    Color(0xFF6A1B9A),
    Color(0xFFC62828),
    Color(0xFF00838F),
    Color(0xFF5D4037),
    Color(0xFF283593),
    Color(0xFFAD1457),
    Color(0xFF558B2F),
    Color(0xFF0277BD),
    Color(0xFFF9A825),
    Color(0xFF7B1FA2),
    Color(0xFF00897B),
    Color(0xFFD84315),
  ];

  bool _isLoading = true;
  bool _analysisExpanded = true;
  bool _isExporting = false;
  bool _selectionSearchVisible = false;
  String _selectionSearchQuery = '';
  List<String>? _selectedSeriesKeys;
  List<_WeightActivityEntry> _activities = <_WeightActivityEntry>[];
  Map<String, _ExerciseWeightSeries> _seriesByKey =
      <String, _ExerciseWeightSeries>{};
  List<String> _orderedSeriesKeys = <String>[];
  final GlobalKey _chartCaptureKey = GlobalKey();

  String get _localeName => Localizations.localeOf(context).toString();

  @override
  void initState() {
    super.initState();
    _loadSelectedSeriesPreference();
    _loadChartData();
  }

  @override
  void didUpdateWidget(covariant EntrenamientoWeightProgressChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameEntrenamientos(oldWidget.entrenamientos, widget.entrenamientos)) {
      _loadChartData();
    }
  }

  Future<void> _loadSelectedSeriesPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedKeys = prefs.getStringList(_selectedSeriesPreferenceKey);
    final searchVisible =
        prefs.getBool(_selectionSearchVisiblePreferenceKey) ?? false;
    final searchQuery =
        prefs.getString(_selectionSearchQueryPreferenceKey) ?? '';
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedSeriesKeys = selectedKeys;
      _selectionSearchVisible = searchVisible;
      _selectionSearchQuery = searchQuery;
    });
  }

  Future<void> _saveSelectedSeriesPreference(List<String>? selectedKeys) async {
    final prefs = await SharedPreferences.getInstance();
    if (selectedKeys == null) {
      await prefs.remove(_selectedSeriesPreferenceKey);
    } else {
      await prefs.setStringList(_selectedSeriesPreferenceKey, selectedKeys);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedSeriesKeys = selectedKeys;
    });
  }

  Future<void> _saveSelectionSearchPreference({
    required bool visible,
    required String query,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmedQuery = query.trim();
    await prefs.setBool(_selectionSearchVisiblePreferenceKey, visible);
    if (trimmedQuery.isEmpty) {
      await prefs.remove(_selectionSearchQueryPreferenceKey);
    } else {
      await prefs.setString(_selectionSearchQueryPreferenceKey, trimmedQuery);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _selectionSearchVisible = visible;
      _selectionSearchQuery = trimmedQuery;
    });
  }

  bool _sameEntrenamientos(
    List<Entrenamiento> previous,
    List<Entrenamiento> current,
  ) {
    if (identical(previous, current)) {
      return true;
    }
    if (previous.length != current.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index++) {
      final prev = previous[index];
      final next = current[index];
      if (prev.codigo != next.codigo || prev.fecha != next.fecha) {
        return false;
      }
    }
    return true;
  }

  Future<void> _loadChartData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final sortedEntrenamientos = List<Entrenamiento>.from(widget.entrenamientos)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    final activities = <_WeightActivityEntry>[];
    final seriesByKey = <String, _ExerciseWeightSeries>{};

    for (final entrenamiento in sortedEntrenamientos) {
      final codigo = entrenamiento.codigo;
      if (codigo == null) {
        continue;
      }
      final ejercicios = await widget.loadEjercicios(codigo);
      final realizadosConPeso = ejercicios.where((ejercicio) {
        final kilos = ejercicio.kilosPlan ?? 0;
        return ejercicio.realizado == 'S' && kilos > 0;
      }).toList();
      if (realizadosConPeso.isEmpty) {
        continue;
      }

      final activityIndex = activities.length;
      activities.add(
        _WeightActivityEntry(
          index: activityIndex,
          codigoEntrenamiento: codigo,
          fecha: entrenamiento.fecha,
          titulo: (entrenamiento.titulo ?? '').trim().isNotEmpty
              ? entrenamiento.titulo!.trim()
              : entrenamiento.actividad,
        ),
      );

      for (final ejercicio in realizadosConPeso) {
        final key = _exerciseKey(ejercicio);
        final nombre = _exerciseDisplayName(ejercicio);
        final serie = seriesByKey.putIfAbsent(
          key,
          () => _ExerciseWeightSeries(key: key, name: nombre),
        );
        serie.points.add(
          _ExerciseWeightPoint(
            activityIndex: activityIndex,
            kilos: (ejercicio.kilosPlan ?? 0).toDouble(),
            fecha: entrenamiento.fecha,
            activityTitle: activities.last.titulo,
          ),
        );
      }
    }

    seriesByKey.removeWhere((_, serie) => serie.points.length < 2);

    final orderedKeys = seriesByKey.values.toList()
      ..sort((a, b) {
        final byChanges = b.changeScore.compareTo(a.changeScore);
        if (byChanges != 0) {
          return byChanges;
        }
        final byRange = b.weightRange.compareTo(a.weightRange);
        if (byRange != 0) {
          return byRange;
        }
        final byCount = b.points.length.compareTo(a.points.length);
        if (byCount != 0) {
          return byCount;
        }
        final byDate = b.lastFecha.compareTo(a.lastFecha);
        if (byDate != 0) {
          return byDate;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final orderedSeriesKeys = orderedKeys.map((serie) => serie.key).toList();

    if (!mounted) {
      return;
    }
    setState(() {
      _activities = activities;
      _seriesByKey = seriesByKey;
      _orderedSeriesKeys = orderedSeriesKeys;
      _isLoading = false;
    });
  }

  String _exerciseKey(EntrenamientoEjercicio ejercicio) {
    final catalogoId = ejercicio.codigoEjercicioCatalogo;
    if (catalogoId != null && catalogoId > 0) {
      return 'catalogo_$catalogoId';
    }
    return 'nombre_${_exerciseDisplayName(ejercicio).toLowerCase()}';
  }

  String _exerciseDisplayName(EntrenamientoEjercicio ejercicio) {
    final nombre = ejercicio.nombre.trim();
    return nombre.isEmpty ? 'Ejercicio' : nombre;
  }

  String _truncateExerciseName(String value, {int maxChars = 20}) {
    final text = value.trim();
    if (text.length <= maxChars) {
      return text;
    }
    return '${text.substring(0, maxChars)}...';
  }

  List<String> _visibleSeriesKeys() {
    final selectedKeys = _selectedSeriesKeys;
    if (selectedKeys == null) {
      return List<String>.from(_orderedSeriesKeys);
    }
    final selectedSet = selectedKeys.toSet();
    return _orderedSeriesKeys.where(selectedSet.contains).toList();
  }

  String _visibleSeriesLabel() {
    final visibleCount = _visibleSeriesKeys().length;
    if (_orderedSeriesKeys.isEmpty) {
      return 'Sin ejercicios seleccionables';
    }
    if (_selectedSeriesKeys == null) {
      return 'Ejercicios seleccionados: todos ($visibleCount)';
    }
    return 'Ejercicios seleccionados: $visibleCount de ${_orderedSeriesKeys.length}';
  }

  String _selectionSubtitle(_ExerciseWeightSeries series) {
    final firstKg = series.points.first.kilos;
    final lastKg = series.points.last.kilos;
    return '${series.points.length} actividades · ${_formatKg(firstKg)} kg → ${_formatKg(lastKg)} kg';
  }

  List<String> _filterSeriesKeys(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return List<String>.from(_orderedSeriesKeys);
    }
    return _orderedSeriesKeys.where((key) {
      final series = _seriesByKey[key];
      if (series == null) {
        return false;
      }
      return series.name.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  Future<void> _showExerciseSelectionDialog() async {
    if (_orderedSeriesKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay ejercicios disponibles para seleccionar.'),
        ),
      );
      return;
    }

    final selectedKeys = <String>{..._visibleSeriesKeys()};
    final searchController = TextEditingController(text: _selectionSearchQuery);
    var searchVisible = _selectionSearchVisible;
    var searchQuery = _selectionSearchQuery;

    final result = await showDialog<Set<String>?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredKeys = _filterSeriesKeys(searchQuery);
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ejercicios visibles',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: searchVisible
                        ? 'Ocultar búsqueda'
                        : 'Buscar ejercicios',
                    onPressed: () {
                      setDialogState(() {
                        searchVisible = !searchVisible;
                        if (!searchVisible) {
                          FocusScope.of(context).unfocus();
                        }
                      });
                      _saveSelectionSearchPreference(
                        visible: searchVisible,
                        query: searchQuery,
                      );
                    },
                    icon: Icon(
                      searchVisible || searchQuery.trim().isNotEmpty
                          ? Icons.search_off_rounded
                          : Icons.search_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: IconButton.styleFrom(
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (searchVisible) ...[
                      TextField(
                        controller: searchController,
                        autofocus: searchQuery.trim().isEmpty,
                        decoration: InputDecoration(
                          hintText: 'Buscar ejercicio',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: searchQuery.trim().isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpiar búsqueda',
                                  onPressed: () {
                                    searchController.clear();
                                    setDialogState(() {
                                      searchQuery = '';
                                    });
                                    _saveSelectionSearchPreference(
                                      visible: searchVisible,
                                      query: searchQuery,
                                    );
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            searchQuery = value;
                          });
                          _saveSelectionSearchPreference(
                            visible: searchVisible,
                            query: value,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'Selecciona los ejercicios con peso realizados más de una vez dentro del período actual. Seleccionados: ${selectedKeys.length} de ${_orderedSeriesKeys.length}${searchQuery.trim().isEmpty ? '' : ' · ${filteredKeys.length} coinciden con la búsqueda'}.',
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filteredKeys.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Text(
                                  'No hay ejercicios que coincidan con la búsqueda.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.grey[700]),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredKeys.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final key = filteredKeys[index];
                                final series = _seriesByKey[key]!;
                                final isSelected = selectedKeys.contains(key);
                                return CheckboxListTile(
                                  value: isSelected,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(series.name),
                                  subtitle: Text(_selectionSubtitle(series)),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        selectedKeys.add(key);
                                      } else {
                                        selectedKeys.remove(key);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      selectedKeys.clear();
                    });
                  },
                  child: const Text('Limpiar'),
                ),
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      selectedKeys
                        ..clear()
                        ..addAll(_orderedSeriesKeys);
                    });
                  },
                  child: const Text('Mostrar todos'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext)
                        .pop(Set<String>.from(selectedKeys));
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Aplicar'),
                      const SizedBox(width: 8),
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selectedKeys.isEmpty
                              ? Colors.grey.shade500
                              : Colors.green.shade600,
                        ),
                        child: Text(
                          '${selectedKeys.length}',
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
              ],
            );
          },
        );
      },
    );
    searchController.dispose();

    if (result == null) {
      return;
    }

    if (result.length >= _orderedSeriesKeys.length) {
      await _saveSelectedSeriesPreference(null);
    } else {
      final orderedSelection =
          _orderedSeriesKeys.where(result.contains).toList();
      await _saveSelectedSeriesPreference(orderedSelection);
    }

    if (!mounted) {
      return;
    }

    final message = result.isEmpty
        ? 'No se mostrará ningún ejercicio.'
        : result.length >= _orderedSeriesKeys.length
            ? 'Se mostrarán todos los ejercicios.'
            : 'Se mostrarán ${result.length} ejercicios seleccionados.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleChartMenuSelection(
    String value,
    List<_ExerciseTrendSummary> summaries,
  ) async {
    if (value == 'share') {
      await _shareChartImage(summaries);
      return;
    }
    if (value == 'pdf') {
      await _generateProgressPdf(summaries);
      return;
    }
    if (value == 'select_exercises') {
      await _showExerciseSelectionDialog();
      return;
    }
    if (value == 'show_all') {
      await _saveSelectedSeriesPreference(null);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se mostrarán todos los ejercicios.')),
      );
    }
  }

  Future<void> _handleAnalysisMenuSelection(
    String value,
    List<_ExerciseTrendSummary> summaries,
  ) async {
    if (value == 'excel') {
      await _exportAnalysisToExcel(summaries);
      return;
    }
    await _handleChartMenuSelection(value, summaries);
  }

  Color _colorForSeries(String key) {
    final index = _orderedSeriesKeys.indexOf(key);
    final paletteIndex = index < 0 ? 0 : index % _seriesPalette.length;
    return _seriesPalette[paletteIndex];
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  String _formatBottomLabel(_WeightActivityEntry activity) {
    return '${_formatDate(activity.fecha)}\n#${activity.index + 1}';
  }

  String _formatInteger(num value) {
    return NumberFormat.decimalPattern(_localeName).format(value);
  }

  String _formatNumber(num value, {required int decimals}) {
    return NumberFormat.decimalPatternDigits(
      locale: _localeName,
      decimalDigits: decimals,
    ).format(value);
  }

  String _formatKg(double value) {
    final decimals = value % 1 == 0 ? 0 : 1;
    return _formatNumber(value, decimals: decimals);
  }

  String _formatDelta(double value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${_formatKg(value)} kg';
  }

  String _buildAnalysisPeriodLabel() {
    if (_activities.isEmpty) {
      return 'Sin actividades';
    }
    return '${_formatDate(_activities.first.fecha)} - ${_formatDate(_activities.last.fecha)}';
  }

  int _bottomLabelStep() {
    if (_activities.length <= 9) {
      return 1;
    }
    return math.max(1, ((_activities.length - 1) / 8).ceil());
  }

  bool _shouldShowBottomLabel(int index) {
    if (_activities.isEmpty) {
      return false;
    }
    if (index == 0 || index == _activities.length - 1) {
      return true;
    }
    return index % _bottomLabelStep() == 0;
  }

  List<_ExerciseTrendSummary> _buildTrendSummaries(Iterable<String> keys) {
    final groupedPoints = <String, List<_ExerciseWeightPoint>>{};
    final groupedNames = <String, String>{};

    for (final key in keys) {
      final serie = _seriesByKey[key];
      if (serie == null) {
        continue;
      }
      final groupKey = serie.name.trim().toLowerCase();
      groupedNames.putIfAbsent(groupKey, () => serie.name.trim());
      groupedPoints.putIfAbsent(groupKey, () => <_ExerciseWeightPoint>[])
        ..addAll(serie.points);
    }

    final summaries = groupedPoints.entries.map((entry) {
      final points = List<_ExerciseWeightPoint>.from(entry.value)
        ..sort((a, b) {
          final byDate = a.fecha.compareTo(b.fecha);
          if (byDate != 0) {
            return byDate;
          }
          return a.activityIndex.compareTo(b.activityIndex);
        });
      final total = points.fold<double>(0, (sum, point) => sum + point.kilos);
      final firstKg = points.first.kilos;
      final lastKg = points.last.kilos;
      final averageKg = total / points.length;
      final deltaKg = lastKg - firstKg;
      final double percentChange =
          firstKg <= 0 ? 0.0 : (deltaKg / firstKg) * 100.0;

      return _ExerciseTrendSummary(
        exerciseName: groupedNames[entry.key] ?? 'Ejercicio',
        activitiesCount: points.length,
        averageKg: averageKg,
        firstKg: firstKg,
        lastKg: lastKg,
        deltaKg: deltaKg,
        percentChange: percentChange,
        points: points,
      );
    }).toList();

    summaries.sort((a, b) {
      final byTrend = b.deltaKg.abs().compareTo(a.deltaKg.abs());
      if (byTrend != 0) {
        return byTrend;
      }
      final byCount = b.activitiesCount.compareTo(a.activitiesCount);
      if (byCount != 0) {
        return byCount;
      }
      return a.exerciseName
          .toLowerCase()
          .compareTo(b.exerciseName.toLowerCase());
    });

    return summaries;
  }

  Color _trendColor(_WeightTrend trend) {
    switch (trend) {
      case _WeightTrend.up:
        return Colors.green.shade700;
      case _WeightTrend.down:
        return Colors.red.shade700;
      case _WeightTrend.stable:
        return Colors.amber.shade800;
    }
  }

  String _trendLabel(_WeightTrend trend) {
    switch (trend) {
      case _WeightTrend.up:
        return 'Subiendo';
      case _WeightTrend.down:
        return 'Bajando';
      case _WeightTrend.stable:
        return 'Estable';
    }
  }

  String _trendEmoji(_WeightTrend trend) {
    switch (trend) {
      case _WeightTrend.up:
        return '📈';
      case _WeightTrend.down:
        return '📉';
      case _WeightTrend.stable:
        return '➖';
    }
  }

  String _trendPdfIndicator(_WeightTrend trend) {
    switch (trend) {
      case _WeightTrend.up:
        return '↑ Subiendo';
      case _WeightTrend.down:
        return '↓ Bajando';
      case _WeightTrend.stable:
        return '- Estable';
    }
  }

  Future<void> _exportAnalysisToExcel(
    List<_ExerciseTrendSummary> summaries,
  ) async {
    if (summaries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay análisis para exportar.'),
        ),
      );
      return;
    }

    final rows = summaries
        .map(
          (summary) => <String>[
            _trendEmoji(summary.trend),
            _trendLabel(summary.trend),
            summary.exerciseName,
            _formatInteger(summary.activitiesCount),
            '${_formatKg(summary.averageKg)} kg',
            '${_formatKg(summary.firstKg)} kg',
            '${_formatKg(summary.lastKg)} kg',
            _formatDelta(summary.deltaKg),
            '${summary.percentChange >= 0 ? '+' : ''}${_formatNumber(summary.percentChange, decimals: 1)}%',
          ],
        )
        .toList();

    await TrainingWeightProgressExcelService.exportAnalysis(
      context: context,
      title: 'Analisis de evolucion de pesos',
      periodLabel: _buildAnalysisPeriodLabel(),
      headers: const <String>[
        'Emoji',
        'Tendencia',
        'Ejercicio',
        'Actividades',
        'Media',
        'Inicio',
        'Final',
        'Cambio',
        '% Cambio',
      ],
      rows: rows,
    );
  }

  Future<Uint8List?> _captureChartImageBytes() async {
    final boundaryContext = _chartCaptureKey.currentContext;
    if (boundaryContext == null) {
      return null;
    }
    final renderObject = boundaryContext.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return null;
    }

    final image = await renderObject.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return null;
    }
    return byteData.buffer.asUint8List();
  }

  String _buildShareSummaryText(List<_ExerciseTrendSummary> summaries) {
    final names = summaries
        .take(5)
        .map((item) => _truncateExerciseName(item.exerciseName))
        .join(', ');
    return 'Evolución de pesos\nPeriodo: ${_buildAnalysisPeriodLabel()}\nEjercicios: $names';
  }

  Future<void> _shareChartImage(List<_ExerciseTrendSummary> summaries) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final bytes = await _captureChartImageBytes();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo capturar la grafica.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final fileName =
          'grafica_pesos_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: _buildShareSummaryText(summaries),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al compartir: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _generateProgressPdf(
    List<_ExerciseTrendSummary> summaries,
  ) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final chartBytes = await _captureChartImageBytes();
      if (chartBytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo capturar la grafica para el PDF.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final apiService = context.read<ApiService>();
      final nutricionistaParam =
          await apiService.getParametro('nutricionista_nombre');
      final nutricionistaNombre =
          nutricionistaParam?['valor']?.toString() ?? 'Nutricionista';
      final nutricionistaSubtitulo =
          nutricionistaParam?['valor2']?.toString() ?? '';

      final logoParam =
          await apiService.getParametro('logotipo_dietista_documentos');
      final logoBytes = TrainingProgressPdfService.decodeBase64Image(
        logoParam?['valor']?.toString() ?? '',
      );
      final logoSizeStr = logoParam?['valor2']?.toString() ?? '';

      final accentColorParam =
          await apiService.getParametro('color_fondo_banda_encabezado_pie_pdf');
      final accentColorStr = accentColorParam?['valor']?.toString() ?? '';
      final nutricionistaEmail =
          (await apiService.getParametro('nutricionista_email'))?['valor']
                  ?.toString() ??
              '';
      final nutricionistaTelegram = (await apiService
                  .getParametro('nutricionista_usuario_telegram'))?['valor']
              ?.toString() ??
          '';
      final nutricionistaWebParam =
          await apiService.getParametro('nutricionista_web');
      final nutricionistaInstagramParam =
          await apiService.getParametro('nutricionista_url_instagram');
      final nutricionistaFacebookParam =
          await apiService.getParametro('nutricionista_url_facebook');

      await TrainingProgressPdfService.generateProgressPdf(
        context: context,
        nutricionistaNombre: nutricionistaNombre,
        nutricionistaSubtitulo: nutricionistaSubtitulo,
        logoBytes: logoBytes,
        logoSizeStr: logoSizeStr,
        accentColorStr: accentColorStr,
        title: 'Evolución de pesos',
        periodLabel: _buildAnalysisPeriodLabel(),
        chartImageBytes: chartBytes,
        nutricionistaEmail: nutricionistaEmail,
        nutricionistaTelegram: nutricionistaTelegram,
        nutricionistaWebUrl: nutricionistaWebParam?['valor']?.toString() ?? '',
        nutricionistaWebLabel:
            nutricionistaWebParam?['valor2']?.toString() ?? '',
        nutricionistaInstagramUrl:
            nutricionistaInstagramParam?['valor']?.toString() ?? '',
        nutricionistaInstagramLabel:
            nutricionistaInstagramParam?['valor2']?.toString() ?? '',
        nutricionistaFacebookUrl:
            nutricionistaFacebookParam?['valor']?.toString() ?? '',
        nutricionistaFacebookLabel:
            nutricionistaFacebookParam?['valor2']?.toString() ?? '',
        headers: const <String>[
          'Tendencia',
          'Ejercicio',
          'Act.',
          'Media',
          'Inicio',
          'Final',
          'Cambio',
        ],
        rows: summaries
            .map(
              (summary) => <String>[
                _trendPdfIndicator(summary.trend),
                summary.exerciseName,
                _formatInteger(summary.activitiesCount),
                '${_formatKg(summary.averageKg)} kg',
                '${_formatKg(summary.firstKg)} kg',
                '${_formatKg(summary.lastKg)} kg',
                '${_formatDelta(summary.deltaKg)} (${summary.percentChange >= 0 ? '+' : ''}${_formatNumber(summary.percentChange, decimals: 1)}%)',
              ],
            )
            .toList(),
        rowAccentColorValues: summaries
            .map((summary) => _trendColor(summary.trend).value)
            .toList(),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Widget _buildMetricTag({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityDetailCard(_ExerciseWeightPoint point, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.fitness_center_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.activityTitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(point.fecha),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.18)),
            ),
            child: Text(
              '${_formatKg(point.kilos)} kg',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExerciseDetailDialog(
    _ExerciseTrendSummary summary,
  ) async {
    final trendColor = _trendColor(summary.trend);
    final changeText =
        '${_formatDelta(summary.deltaKg)} (${summary.percentChange >= 0 ? '+' : ''}${_formatNumber(summary.percentChange, decimals: 1)}%)';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          summary.exerciseName,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: trendColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: trendColor.withOpacity(0.18)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _trendEmoji(summary.trend),
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _trendLabel(summary.trend),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: trendColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              changeText,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: trendColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildMetricTag(
                      icon: Icons.event_note_rounded,
                      label: 'Actividades',
                      value: _formatInteger(summary.activitiesCount),
                      color: const Color(0xFF1565C0),
                    ),
                    _buildMetricTag(
                      icon: Icons.balance_rounded,
                      label: 'Media',
                      value: '${_formatKg(summary.averageKg)} kg',
                      color: const Color(0xFF00897B),
                    ),
                    _buildMetricTag(
                      icon: Icons.play_arrow_rounded,
                      label: 'Inicio',
                      value: '${_formatKg(summary.firstKg)} kg',
                      color: const Color(0xFF5E35B1),
                    ),
                    _buildMetricTag(
                      icon: Icons.flag_rounded,
                      label: 'Final',
                      value: '${_formatKg(summary.lastKg)} kg',
                      color: const Color(0xFFEF6C00),
                    ),
                    _buildMetricTag(
                      icon: Icons.trending_up_rounded,
                      label: 'Cambio',
                      value: changeText,
                      color: trendColor,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Detalle por actividad',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                ...summary.points.map(
                  (point) => _buildActivityDetailCard(point, trendColor),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  double _calculateYInterval(double maxValue) {
    if (maxValue <= 0) {
      return 5;
    }
    const targetTicks = 6.0;
    final roughInterval = maxValue / targetTicks;
    final magnitude =
        math.pow(10, (math.log(roughInterval) / math.ln10).floor());
    final normalized = roughInterval / magnitude;

    double niceNormalized;
    if (normalized <= 1) {
      niceNormalized = 1;
    } else if (normalized <= 2) {
      niceNormalized = 2;
    } else if (normalized <= 5) {
      niceNormalized = 5;
    } else {
      niceNormalized = 10;
    }
    return niceNormalized * magnitude;
  }

  LineChartData _buildChartData(
    List<_ExerciseWeightSeries> visibleSeries,
    List<String> visibleKeys,
  ) {
    final maxY = visibleSeries
        .expand((serie) => serie.points)
        .map((point) => point.kilos)
        .fold<double>(0, math.max);
    final yInterval = _calculateYInterval(maxY);
    final chartMaxY =
        math.max(yInterval, (maxY / yInterval).ceil() * yInterval);
    return LineChartData(
      minX: 0,
      maxX: math.max((_activities.length - 1).toDouble(), 1),
      minY: 0,
      maxY: chartMaxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.shade300,
          strokeWidth: 1,
        ),
        getDrawingVerticalLine: (value) => FlLine(
          color: Colors.grey.shade300,
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(color: Colors.grey.shade400),
          bottom: BorderSide(color: Colors.grey.shade400),
          right: const BorderSide(color: Colors.transparent),
          top: const BorderSide(color: Colors.transparent),
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          axisNameSize: 32,
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Peso (kg)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 54,
            interval: yInterval,
            getTitlesWidget: (value, meta) => SideTitleWidget(
              meta: meta,
              space: 8,
              child: Text(
                _formatNumber(value, decimals: value % 1 == 0 ? 0 : 1),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          axisNameSize: 34,
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Actividades del periodo',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 56,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= _activities.length) {
                return const SizedBox.shrink();
              }
              if (!_shouldShowBottomLabel(index)) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                space: 10,
                child: Text(
                  _formatBottomLabel(_activities[index]),
                  style: const TextStyle(fontSize: 9),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((touchedSpot) {
              final series = visibleSeries[touchedSpot.barIndex];
              final point = series.points.firstWhere(
                (item) => item.activityIndex == touchedSpot.x.toInt(),
              );
              return LineTooltipItem(
                '${series.name}\n${_formatKg(point.kilos)} kg\n${_formatDate(point.fecha)} • ${point.activityTitle}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: visibleKeys.map((key) {
        final series = _seriesByKey[key]!;
        final color = _colorForSeries(key);
        return LineChartBarData(
          spots: series.points
              .map((point) =>
                  FlSpot(point.activityIndex.toDouble(), point.kilos))
              .toList(),
          isCurved: true,
          color: color,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 3.4,
              color: color,
              strokeWidth: 1.2,
              strokeColor: Colors.white,
            ),
          ),
          belowBarData: BarAreaData(show: false),
        );
      }).toList(),
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
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _truncateExerciseName(label),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildTrendChip(_ExerciseTrendSummary summary) {
    final color = _trendColor(summary.trend);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        switch (summary.trend) {
          _WeightTrend.up => '⬆',
          _WeightTrend.down => '⬇',
          _WeightTrend.stable => '=',
        },
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(List<_ExerciseTrendSummary> summaries) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
              bottom: Radius.circular(12),
            ),
            onTap: () {
              setState(() {
                _analysisExpanded = !_analysisExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tabla de evolución de pesos',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tendencia, peso medio, inicial, final de ejercicios.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[700],
                                    height: 1.35,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Más opciones',
                    onSelected: (value) =>
                        _handleAnalysisMenuSelection(value, summaries),
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'share',
                        child: ListTile(
                          leading: Icon(Icons.ios_share_outlined),
                          title: Text('Compartir'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'pdf',
                        child: ListTile(
                          leading: Icon(Icons.picture_as_pdf_outlined),
                          title: Text('Generar PDF'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem<String>(
                        value: 'select_exercises',
                        child: ListTile(
                          leading: Icon(Icons.checklist_rounded),
                          title: Text('Elegir ejercicios'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'show_all',
                        child: ListTile(
                          leading: Icon(Icons.unfold_more_rounded),
                          title: Text('Mostrar todos'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem<String>(
                        value: 'excel',
                        child: ListTile(
                          leading: Icon(Icons.table_view_outlined),
                          title: Text('Exportar a Excel'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.more_vert),
                    ),
                  ),
                  IconButton(
                    onPressed: summaries.isEmpty
                        ? null
                        : () => _exportAnalysisToExcel(summaries),
                    icon: const Icon(Icons.table_view_outlined),
                    tooltip: 'Exportar a Excel',
                  ),
                  Icon(
                    _analysisExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.grey[700],
                  ),
                ],
              ),
            ),
          ),
          if (_analysisExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: summaries.isEmpty
                  ? Text(
                      'No hay ejercicios repetidos en varias actividades para analizar.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Periodo analizado: ${_buildAnalysisPeriodLabel()} · ${summaries.length} ejercicios',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _visibleSeriesLabel(),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 42,
                            dataRowMinHeight: 58,
                            dataRowMaxHeight: 66,
                            columns: const [
                              DataColumn(label: Text('Ejercicio')),
                              DataColumn(label: Text('Tend.')),
                              DataColumn(label: Text('Inicio')),
                              DataColumn(label: Text('Final')),
                              DataColumn(label: Text('Media')),
                              DataColumn(label: Text('Cambio')),
                            ],
                            rows: summaries.map((summary) {
                              final color = _trendColor(summary.trend);
                              return DataRow(
                                color: MaterialStatePropertyAll<Color?>(
                                  color.withOpacity(0.05),
                                ),
                                cells: [
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minWidth: 180,
                                        maxWidth: 260,
                                      ),
                                      child: InkWell(
                                        onTap: () =>
                                            _showExerciseDetailDialog(summary),
                                        child: Text(
                                          _truncateExerciseName(
                                            summary.exerciseName,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(_buildTrendChip(summary)),
                                  DataCell(
                                      Text('${_formatKg(summary.firstKg)} kg')),
                                  DataCell(
                                      Text('${_formatKg(summary.lastKg)} kg')),
                                  DataCell(Text(
                                      '${_formatKg(summary.averageKg)} kg')),
                                  DataCell(
                                    Text(
                                      '${_formatDelta(summary.deltaKg)} (${summary.percentChange >= 0 ? '+' : ''}${_formatNumber(summary.percentChange, decimals: 1)}%)',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏋️', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_orderedSeriesKeys.isEmpty || _activities.isEmpty) {
      return _buildEmptyState(
        title: 'Sin pesos para representar',
        subtitle:
            'En este periodo no hay ejercicios realizados con peso mayor que 0.',
      );
    }

    final visibleKeys = _visibleSeriesKeys();
    final visibleSeries = visibleKeys
        .map((key) => _seriesByKey[key])
        .whereType<_ExerciseWeightSeries>()
        .toList();
    final trendSummaries = _buildTrendSummaries(visibleKeys);

    if (visibleSeries.isEmpty) {
      return _buildEmptyState(
        title: 'Sin ejercicios seleccionados',
        subtitle:
            'Selecciona ejercicios desde el menú para mostrarlos en la gráfica y en la tabla.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RepaintBoundary(
            key: _chartCaptureKey,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Evolución de pesos',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Más opciones',
                          onSelected: (value) =>
                              _handleChartMenuSelection(value, trendSummaries),
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'share',
                              child: ListTile(
                                leading: Icon(Icons.ios_share_outlined),
                                title: Text('Compartir'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'pdf',
                              child: ListTile(
                                leading: Icon(Icons.picture_as_pdf_outlined),
                                title: Text('Generar PDF'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuDivider(),
                            PopupMenuItem<String>(
                              value: 'select_exercises',
                              child: ListTile(
                                leading: Icon(Icons.checklist_rounded),
                                title: Text('Elegir ejercicios'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'show_all',
                              child: ListTile(
                                leading: Icon(Icons.unfold_more_rounded),
                                title: Text('Mostrar todos'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _visibleSeriesLabel(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: visibleKeys
                          .map(
                            (key) => _buildLegendItem(
                              _colorForSeries(key),
                              _seriesByKey[key]!.name,
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 10, 8),
                      child: SizedBox(
                        height: 368,
                        child: LineChart(
                          _buildChartData(visibleSeries, visibleKeys),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildAnalysisCard(trendSummaries),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _WeightActivityEntry {
  const _WeightActivityEntry({
    required this.index,
    required this.codigoEntrenamiento,
    required this.fecha,
    required this.titulo,
  });

  final int index;
  final int codigoEntrenamiento;
  final DateTime fecha;
  final String titulo;
}

enum _WeightTrend { up, down, stable }

class _ExerciseTrendSummary {
  const _ExerciseTrendSummary({
    required this.exerciseName,
    required this.activitiesCount,
    required this.averageKg,
    required this.firstKg,
    required this.lastKg,
    required this.deltaKg,
    required this.percentChange,
    required this.points,
  });

  final String exerciseName;
  final int activitiesCount;
  final double averageKg;
  final double firstKg;
  final double lastKg;
  final double deltaKg;
  final double percentChange;
  final List<_ExerciseWeightPoint> points;

  _WeightTrend get trend {
    if (deltaKg > 0.5) {
      return _WeightTrend.up;
    }
    if (deltaKg < -0.5) {
      return _WeightTrend.down;
    }
    return _WeightTrend.stable;
  }
}

class _ExerciseWeightSeries {
  _ExerciseWeightSeries({required this.key, required this.name});

  final String key;
  final String name;
  final List<_ExerciseWeightPoint> points = <_ExerciseWeightPoint>[];

  int get changeScore {
    if (points.length < 2) return 0;
    var changes = 0;
    for (var index = 1; index < points.length; index++) {
      if (points[index].kilos != points[index - 1].kilos) {
        changes += 1;
      }
    }
    return changes;
  }

  double get weightRange {
    if (points.isEmpty) return 0;
    final values = points.map((point) => point.kilos);
    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    return max - min;
  }

  DateTime get lastFecha => points.isEmpty
      ? DateTime.fromMillisecondsSinceEpoch(0)
      : points.last.fecha;
}

class _ExerciseWeightPoint {
  const _ExerciseWeightPoint({
    required this.activityIndex,
    required this.kilos,
    required this.fecha,
    required this.activityTitle,
  });

  final int activityIndex;
  final double kilos;
  final DateTime fecha;
  final String activityTitle;
}
