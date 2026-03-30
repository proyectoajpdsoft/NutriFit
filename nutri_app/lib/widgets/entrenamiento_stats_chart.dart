import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nutri_app/models/entrenamiento_ejercicio.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/entrenamiento_stats_pdf_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/entrenamiento.dart';

class EntrenamientoStatsChart extends StatefulWidget {
  final List<Entrenamiento> entrenamientos;

  const EntrenamientoStatsChart({
    Key? key,
    required this.entrenamientos,
  }) : super(key: key);

  @override
  State<EntrenamientoStatsChart> createState() =>
      _EntrenamientoStatsChartState();
}

class _EntrenamientoStatsChartState extends State<EntrenamientoStatsChart> {
  static const String _prefsShowActividadesKey = 'stats_chart_show_actividades';
  static const String _prefsShowKilometrosKey = 'stats_chart_show_kilometros';
  static const String _prefsShowDesnivelKey = 'stats_chart_show_desnivel';
  static const String _prefsShowMinutosKey = 'stats_chart_show_minutos';
  static const String _prefsShowPesoKey = 'stats_chart_show_peso';

  final GlobalKey _chartCaptureKey = GlobalKey();
  bool _showActividades = true;
  bool _showKilometros = true;
  bool _showDesnivel = true;
  bool _showMinutos = true;
  bool _showPeso = true;
  bool _isExporting = false;
  final Map<int, double> _pesoEntrenamientoKg = <int, double>{};
  final Map<int, int> _ejerciciosEntrenamiento = <int, int>{};

  @override
  void initState() {
    super.initState();
    _loadSeriesVisibilityPreferences();
    _refreshEntrenamientoMetrics();
  }

  @override
  void didUpdateWidget(covariant EntrenamientoStatsChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldCodigos = oldWidget.entrenamientos
        .where((e) => e.codigo != null)
        .map((e) => e.codigo!)
        .toSet();
    final newCodigos = widget.entrenamientos
        .where((e) => e.codigo != null)
        .map((e) => e.codigo!)
        .toSet();
    if (oldCodigos.length != newCodigos.length ||
        !oldCodigos.containsAll(newCodigos)) {
      _refreshEntrenamientoMetrics();
    }
  }

  Future<void> _loadSeriesVisibilityPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showActividades = prefs.getBool(_prefsShowActividadesKey) ?? true;
      _showKilometros = prefs.getBool(_prefsShowKilometrosKey) ?? true;
      _showDesnivel = prefs.getBool(_prefsShowDesnivelKey) ?? true;
      _showMinutos = prefs.getBool(_prefsShowMinutosKey) ?? true;
      _showPeso = prefs.getBool(_prefsShowPesoKey) ?? true;
    });
  }

  Future<void> _saveSeriesVisibilityPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsShowActividadesKey, _showActividades);
    await prefs.setBool(_prefsShowKilometrosKey, _showKilometros);
    await prefs.setBool(_prefsShowDesnivelKey, _showDesnivel);
    await prefs.setBool(_prefsShowMinutosKey, _showMinutos);
    await prefs.setBool(_prefsShowPesoKey, _showPeso);
  }

  Future<void> _refreshEntrenamientoMetrics() async {
    final codigos = widget.entrenamientos
        .where((e) => e.codigo != null)
        .map((e) => e.codigo!)
        .toList();
    if (codigos.isEmpty) return;

    final apiService = context.read<ApiService>();
    var changed = false;

    for (final codigo in codigos) {
      if (_pesoEntrenamientoKg.containsKey(codigo) &&
          _ejerciciosEntrenamiento.containsKey(codigo)) {
        continue;
      }

      try {
        final ejercicios = await apiService.getEntrenamientoEjercicios(codigo);
        final totalKg = _sumPesoKg(ejercicios);
        _pesoEntrenamientoKg[codigo] = totalKg;
        _ejerciciosEntrenamiento[codigo] = ejercicios.length;
      } catch (_) {
        _pesoEntrenamientoKg[codigo] = 0;
        _ejerciciosEntrenamiento[codigo] = 0;
      }
      changed = true;
    }

    if (changed && mounted) {
      setState(() {});
    }
  }

  double _sumPesoKg(List<EntrenamientoEjercicio> ejercicios) {
    var total = 0.0;
    for (final ejercicio in ejercicios) {
      if (ejercicio.realizado != 'S') continue;
      final kilos = (ejercicio.kilosPlan ?? 0).toDouble();
      if (kilos <= 0) continue;
      final repeticiones =
          ejercicio.repeticionesRealizadas ?? ejercicio.repeticionesPlan ?? 0;
      if (repeticiones <= 0) continue;
      total += kilos * repeticiones;
    }
    return total;
  }

  Map<String, dynamic> _procesarDatos() {
    final entrenamientosFiltrados =
        List<Entrenamiento>.from(widget.entrenamientos)
          ..sort((a, b) => a.fecha.compareTo(b.fecha));

    int intervaloAgrupacion = 7;
    if (entrenamientosFiltrados.length >= 2) {
      final fechaMin = entrenamientosFiltrados.first.fecha;
      final fechaMax = entrenamientosFiltrados.last.fecha;
      final rangoDias = fechaMax.difference(fechaMin).inDays.abs();

      if (rangoDias <= 14) {
        intervaloAgrupacion = 1;
      } else if (rangoDias <= 90) {
        intervaloAgrupacion = 7;
      } else if (rangoDias <= 365) {
        intervaloAgrupacion = 14;
      } else {
        intervaloAgrupacion = 30;
      }
    }

    // Agrupar por intervalo
    Map<String, ChartData> datosAcumulados = {};

    for (var entrenamiento in entrenamientosFiltrados) {
      final fechaKey = _getFechaKey(entrenamiento.fecha, intervaloAgrupacion);

      if (!datosAcumulados.containsKey(fechaKey)) {
        datosAcumulados[fechaKey] = ChartData(
          fecha: entrenamiento.fecha,
          fechaKey: fechaKey,
          actividades: 0,
          kilometros: 0.0,
          desnivel: 0.0,
          minutos: 0,
          pesoKg: 0.0,
          ejercicios: 0,
        );
      }

      datosAcumulados[fechaKey]!.actividades++;
      datosAcumulados[fechaKey]!.kilometros +=
          entrenamiento.duracionKilometros ?? 0;
      datosAcumulados[fechaKey]!.desnivel +=
          entrenamiento.desnivelAcumulado ?? 0;
      datosAcumulados[fechaKey]!.minutos +=
          (entrenamiento.duracionHoras * 60) + entrenamiento.duracionMinutos;
      final codigo = entrenamiento.codigo;
      if (codigo != null) {
        datosAcumulados[fechaKey]!.pesoKg += _pesoEntrenamientoKg[codigo] ?? 0;
        datosAcumulados[fechaKey]!.ejercicios +=
            _ejerciciosEntrenamiento[codigo] ??
                entrenamiento.ejerciciosTotal ??
                0;
      } else {
        datosAcumulados[fechaKey]!.ejercicios +=
            entrenamiento.ejerciciosTotal ?? 0;
      }
    }

    // Convertir a lista ordenada
    final datos = datosAcumulados.values.toList();
    datos.sort((a, b) => a.fecha.compareTo(b.fecha));

    return {
      'datos': datos,
      'intervalo': intervaloAgrupacion,
    };
  }

  String _getFechaKey(DateTime date, int intervalo) {
    // Redondear la fecha al intervalo mas cercano
    final daysSinceEpoch = date.difference(DateTime(2000, 1, 1)).inDays;
    final intervalIndex = (daysSinceEpoch / intervalo).floor();
    return 'interval_$intervalIndex';
  }

  String _formatFecha(DateTime fecha, int intervaloAgrupacion) {
    if (intervaloAgrupacion == 1) {
      final dias = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];
      return '${dias[fecha.weekday - 1]}\n${fecha.day}';
    }

    if (intervaloAgrupacion >= 30) {
      final meses = [
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic'
      ];
      return meses[fecha.month - 1];
    }

    return '${fecha.day}/${fecha.month}';
  }

  @override
  Widget build(BuildContext context) {
    final datosMap = _procesarDatos();
    final datos = (datosMap['datos'] as List<ChartData>);
    final intervaloAgrupacion = (datosMap['intervalo'] as int?) ?? 7;

    if (datos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '📊',
                style: TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 16),
              Text(
                'Sin datos para mostrar',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'No hay actividades en el periodo seleccionado',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grafica
          GestureDetector(
            onLongPress: () =>
                _showGraphOptionsMenu(datos, intervaloAgrupacion),
            child: RepaintBoundary(
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
                            child: Text(
                              'Estadisticas del periodo',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (_isExporting)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              tooltip: 'Opciones de grafica',
                              icon: const Icon(Icons.more_horiz, size: 20),
                              onPressed: () => _showGraphOptionsMenu(
                                datos,
                                intervaloAgrupacion,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 16),
                        child: Wrap(
                          spacing: 24,
                          runSpacing: 8,
                          children: [
                            if (_showActividades)
                              _buildLegendaItem(
                                color: Colors.blue,
                                label: 'Actividades',
                              ),
                            if (_showKilometros)
                              _buildLegendaItem(
                                color: Colors.green,
                                label: 'Km',
                              ),
                            if (_showDesnivel)
                              _buildLegendaItem(
                                color: Colors.brown,
                                label: 'Subida',
                              ),
                            if (_showMinutos)
                              _buildLegendaItem(
                                color: Colors.orange,
                                label: 'Minutos',
                              ),
                            if (_showPeso)
                              _buildLegendaItem(
                                color: Colors.purple,
                                label: 'Peso',
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 300,
                        child: LineChart(
                          _buildLineChartData(datos, intervaloAgrupacion),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Resumen del periodo
          _buildResumenCard(datos, intervaloAgrupacion),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildLegendaItem({required Color color, required String label}) {
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
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  LineChartData _buildLineChartData(
    List<ChartData> datos,
    int intervaloAgrupacion,
  ) {
    final maxActividades = _showActividades
        ? datos.map((d) => d.actividades).reduce((a, b) => a > b ? a : b)
        : 0;
    final double maxKilometros = _showKilometros
        ? datos.map((d) => d.kilometros).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final double maxDesnivel = _showDesnivel
        ? datos.map((d) => d.desnivel).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final int maxMinutos = _showMinutos
        ? datos.map((d) => d.minutos).reduce((a, b) => a > b ? a : b)
        : 0;
    final double maxPesoKg = _showPeso
        ? datos.map((d) => d.pesoKg).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final double maxYValue = [
      maxActividades.toDouble(),
      maxKilometros,
      maxDesnivel,
      maxMinutos.toDouble(),
      maxPesoKg,
      1.0,
    ].reduce((a, b) => a > b ? a : b);
    final double chartScaleMax = maxYValue;
    final yInterval = _calcularIntervaloEjeY(chartScaleMax);
    final yMax = _calcularMaxEjeY(chartScaleMax, yInterval);

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: null,
        verticalInterval: null,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey[300],
            strokeWidth: 1,
          );
        },
        getDrawingVerticalLine: (value) {
          return FlLine(
            color: Colors.grey[300],
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval:
                datos.length > 10 ? (datos.length / 6).ceil().toDouble() : 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= datos.length) {
                return const Text('');
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _formatFecha(datos[index].fecha, intervaloAgrupacion),
                  style: const TextStyle(fontSize: 9),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            interval: yInterval,
            getTitlesWidget: (value, meta) {
              return Text(
                _formatYAxisLabel(value, yInterval),
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[400]!,
            width: 1,
          ),
          left: BorderSide(
            color: Colors.grey[400]!,
            width: 1,
          ),
          right: const BorderSide(
            color: Colors.transparent,
          ),
          top: const BorderSide(
            color: Colors.transparent,
          ),
        ),
      ),
      minX: 0,
      maxX: (datos.length - 1).toDouble(),
      minY: 0,
      maxY: yMax,
      lineBarsData: [
        // Línea de actividades (azul)
        if (_showActividades)
          LineChartBarData(
            spots: datos
                .asMap()
                .entries
                .map((e) => FlSpot(
                      e.key.toDouble(),
                      e.value.actividades.toDouble(),
                    ))
                .toList(),
            isCurved: true,
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blue.shade700],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.1),
                  Colors.blue.withOpacity(0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        // Línea de kilómetros (verde)
        if (_showKilometros)
          LineChartBarData(
            spots: datos.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.kilometros);
            }).toList(),
            isCurved: true,
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade700],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: false,
            ),
          ),
        // Línea de desnivel acumulado (marrón)
        if (_showDesnivel)
          LineChartBarData(
            spots: datos.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.desnivel);
            }).toList(),
            isCurved: true,
            gradient: LinearGradient(
              colors: [Colors.brown.shade300, Colors.brown.shade700],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: false,
            ),
          ),
        // Línea de minutos (naranja)
        if (_showMinutos)
          LineChartBarData(
            spots: datos.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.minutos.toDouble());
            }).toList(),
            isCurved: true,
            gradient: LinearGradient(
              colors: [Colors.orange.shade400, Colors.orange.shade700],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: false,
            ),
          ),
        if (_showPeso)
          LineChartBarData(
            spots: datos.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.pesoKg);
            }).toList(),
            isCurved: true,
            gradient: LinearGradient(
              colors: [Colors.purple.shade300, Colors.purple.shade700],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
      ],
    );
  }

  double _calcularIntervaloEjeY(double maxValue) {
    if (maxValue <= 0) return 1;

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

  double _calcularMaxEjeY(double maxValue, double interval) {
    if (interval <= 0) return maxValue;
    return (maxValue / interval).ceil() * interval;
  }

  String _formatYAxisLabel(double value, double interval) {
    if (interval >= 1) {
      return value.toStringAsFixed(0);
    }
    if (interval >= 0.1) {
      return value.toStringAsFixed(1);
    }
    return value.toStringAsFixed(2);
  }

  Widget _buildResumenCard(List<ChartData> datos, int intervaloAgrupacion) {
    int totalActividades = 0;
    double totalKilometros = 0;
    double totalDesnivel = 0;
    int totalMinutos = 0;
    double totalPesoKg = 0;
    int totalEjercicios = 0;

    for (var dato in datos) {
      totalActividades += dato.actividades;
      totalKilometros += dato.kilometros;
      totalDesnivel += dato.desnivel;
      totalMinutos += dato.minutos;
      totalPesoKg += dato.pesoKg;
      totalEjercicios += dato.ejercicios;
    }

    final double promActividades =
        datos.isNotEmpty ? totalActividades / datos.length : 0.0;
    final double promKilometros =
        datos.isNotEmpty ? totalKilometros / datos.length : 0.0;
    final double promDesnivel =
        datos.isNotEmpty ? totalDesnivel / datos.length : 0.0;
    final double promMinutos =
        datos.isNotEmpty ? totalMinutos / datos.length : 0.0;
    final double promPesoKg =
        datos.isNotEmpty ? totalPesoKg / datos.length : 0.0;
    final double promEjercicios =
        datos.isNotEmpty ? totalEjercicios / datos.length : 0.0;

    final horas = totalMinutos ~/ 60;
    final minutos = totalMinutos % 60;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen del período',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildResumenItem(
                  '💪',
                  totalActividades.toString(),
                  'Actividades',
                ),
                _buildResumenItem(
                  '📍',
                  totalKilometros.toStringAsFixed(1),
                  'Km',
                ),
                _buildResumenItem(
                  '⛰️',
                  totalDesnivel.toStringAsFixed(0),
                  'Subida (m)',
                ),
                _buildResumenItem(
                  '⏱️',
                  '${horas}h ${minutos}m',
                  'Tiempo',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildResumenItem(
                  '🏋️',
                  totalPesoKg.toStringAsFixed(1),
                  'Peso (kg)',
                ),
                _buildResumenItem(
                  '🔢',
                  totalEjercicios.toString(),
                  'Ejercicios',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              intervaloAgrupacion == 1
                  ? 'Promedio por dia'
                  : 'Promedio por periodo',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildResumenItem(
                  '💪',
                  promActividades.toStringAsFixed(1),
                  'Actividades',
                ),
                _buildResumenItem(
                  '📍',
                  promKilometros.toStringAsFixed(1),
                  'Km',
                ),
                _buildResumenItem(
                  '⛰️',
                  promDesnivel.toStringAsFixed(0),
                  'Subida (m)',
                ),
                _buildResumenItem(
                  '⏱️',
                  '${(promMinutos ~/ 60).toStringAsFixed(0)}m',
                  'Tiempo',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildResumenItem(
                  '🏋️',
                  promPesoKg.toStringAsFixed(1),
                  'Peso (kg)',
                ),
                _buildResumenItem(
                  '🔢',
                  promEjercicios.toStringAsFixed(1),
                  'Ejercicios',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenItem(String emoji, String valor, String label) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 6),
        Text(
          valor,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Future<void> _showGraphOptionsMenu(
    List<ChartData> datos,
    int intervaloAgrupacion,
  ) async {
    if (_isExporting) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  _showActividades
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                ),
                title: const Text('Mostrar actividades'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _toggleSerie('actividades');
                },
              ),
              ListTile(
                leading: Icon(
                  _showKilometros
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                ),
                title: const Text('Mostrar kilometros'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _toggleSerie('kilometros');
                },
              ),
              ListTile(
                leading: Icon(
                  _showMinutos
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                ),
                title: const Text('Mostrar minutos'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _toggleSerie('minutos');
                },
              ),
              ListTile(
                leading: Icon(
                  _showDesnivel
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                ),
                title: const Text('Mostrar desnivel acumulado'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _toggleSerie('desnivel');
                },
              ),
              ListTile(
                leading: Icon(
                  _showPeso ? Icons.check_box : Icons.check_box_outline_blank,
                ),
                title: const Text('Mostrar peso'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _toggleSerie('peso');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.ios_share_outlined),
                title: const Text('Compartir'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _shareChartImage(datos, intervaloAgrupacion);
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Generar PDF'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _generateStatsPdf(datos, intervaloAgrupacion);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _toggleSerie(String serie) {
    final activeCount = (_showActividades ? 1 : 0) +
        (_showKilometros ? 1 : 0) +
        (_showDesnivel ? 1 : 0) +
        (_showMinutos ? 1 : 0) +
        (_showPeso ? 1 : 0);

    bool nextActividades = _showActividades;
    bool nextKilometros = _showKilometros;
    bool nextDesnivel = _showDesnivel;
    bool nextMinutos = _showMinutos;
    bool nextPeso = _showPeso;

    if (serie == 'actividades') {
      nextActividades = !_showActividades;
    } else if (serie == 'kilometros') {
      nextKilometros = !_showKilometros;
    } else if (serie == 'desnivel') {
      nextDesnivel = !_showDesnivel;
    } else if (serie == 'minutos') {
      nextMinutos = !_showMinutos;
    } else if (serie == 'peso') {
      nextPeso = !_showPeso;
    }

    final nextCount = (nextActividades ? 1 : 0) +
        (nextKilometros ? 1 : 0) +
        (nextDesnivel ? 1 : 0) +
        (nextMinutos ? 1 : 0) +
        (nextPeso ? 1 : 0);

    if (activeCount > 0 && nextCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe quedar al menos una serie visible.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _showActividades = nextActividades;
      _showKilometros = nextKilometros;
      _showDesnivel = nextDesnivel;
      _showMinutos = nextMinutos;
      _showPeso = nextPeso;
    });
    _saveSeriesVisibilityPreferences();
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
    if (byteData == null) return null;
    return byteData.buffer.asUint8List();
  }

  Future<void> _shareChartImage(
    List<ChartData> datos,
    int intervaloAgrupacion,
  ) async {
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
          'grafica_actividad_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      final resumen = _buildResumenPdfData(datos, intervaloAgrupacion);
      final periodoLabel = _buildPeriodoLabel(datos, intervaloAgrupacion);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: _buildShareSummaryText(periodoLabel, resumen),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al compartir: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _generateStatsPdf(
    List<ChartData> datos,
    int intervaloAgrupacion,
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

      final resumen = _buildResumenPdfData(datos, intervaloAgrupacion);
      final periodoLabel = _buildPeriodoLabel(datos, intervaloAgrupacion);

      final apiService = context.read<ApiService>();
      final nutricionistaParam =
          await apiService.getParametro('nutricionista_nombre');
      final nutricionistaNombre =
          nutricionistaParam?['valor']?.toString() ?? 'Nutricionista';
      final nutricionistaSubtitulo =
          nutricionistaParam?['valor2']?.toString() ?? '';

      final logoParam =
          await apiService.getParametro('logotipo_dietista_documentos');
      final logoBytes =
          _decodeBase64Image(logoParam?['valor']?.toString() ?? '');
      final logoSizeStr = logoParam?['valor2']?.toString() ?? '';

      final accentColorParam =
          await apiService.getParametro('color_fondo_banda_encabezado_pie_pdf');
      final accentColorStr = accentColorParam?['valor']?.toString() ?? '';

      if (!mounted) return;
      await EntrenamientoStatsPdfService.generateStatsPdf(
        context: context,
        nutricionistaNombre: nutricionistaNombre,
        nutricionistaSubtitulo: nutricionistaSubtitulo,
        logoBytes: logoBytes,
        logoSizeStr: logoSizeStr,
        accentColorStr: accentColorStr,
        chartImageBytes: chartBytes,
        periodoLabel: periodoLabel,
        resumen: resumen,
        showActividades: _showActividades,
        showKilometros: _showKilometros,
        showDesnivel: _showDesnivel,
        showMinutos: _showMinutos,
        showPeso: _showPeso,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  EntrenamientoStatsPdfResumen _buildResumenPdfData(
    List<ChartData> datos,
    int intervaloAgrupacion,
  ) {
    int totalActividades = 0;
    double totalKilometros = 0;
    double totalDesnivel = 0;
    int totalMinutos = 0;
    double totalPesoKg = 0;
    int totalEjercicios = 0;

    for (final dato in datos) {
      totalActividades += dato.actividades;
      totalKilometros += dato.kilometros;
      totalDesnivel += dato.desnivel;
      totalMinutos += dato.minutos;
      totalPesoKg += dato.pesoKg;
      totalEjercicios += dato.ejercicios;
    }

    final double promActividades =
        datos.isNotEmpty ? totalActividades / datos.length : 0.0;
    final double promKilometros =
        datos.isNotEmpty ? totalKilometros / datos.length : 0.0;
    final double promDesnivel =
        datos.isNotEmpty ? totalDesnivel / datos.length : 0.0;
    final double promMinutos =
        datos.isNotEmpty ? totalMinutos / datos.length : 0.0;
    final double promPesoKg =
        datos.isNotEmpty ? totalPesoKg / datos.length : 0.0;
    final double promEjercicios =
        datos.isNotEmpty ? totalEjercicios / datos.length : 0.0;

    return EntrenamientoStatsPdfResumen(
      totalActividades: totalActividades,
      totalKilometros: totalKilometros,
      totalDesnivel: totalDesnivel,
      totalMinutos: totalMinutos,
      totalPesoKg: totalPesoKg,
      totalEjercicios: totalEjercicios,
      promedioActividades: promActividades,
      promedioKilometros: promKilometros,
      promedioDesnivel: promDesnivel,
      promedioMinutos: promMinutos,
      promedioPesoKg: promPesoKg,
      promedioEjercicios: promEjercicios,
      promedioPorDia: intervaloAgrupacion == 1,
    );
  }

  String _buildShareSummaryText(
    String periodoLabel,
    EntrenamientoStatsPdfResumen resumen,
  ) {
    final horas = resumen.totalMinutos ~/ 60;
    final minutos = resumen.totalMinutos % 60;
    return 'Grafica de estadisticas de actividad\n'
        'Periodo: $periodoLabel\n'
        'Actividades: ${resumen.totalActividades}\n'
        'Kilometros: ${resumen.totalKilometros.toStringAsFixed(1)}\n'
        'Subida: ${resumen.totalDesnivel.toStringAsFixed(0)} m\n'
        'Tiempo: ${horas}h ${minutos}m\n'
        'Peso: ${resumen.totalPesoKg.toStringAsFixed(1)} kg\n'
        'Ejercicios: ${resumen.totalEjercicios}';
  }

  String _buildPeriodoLabel(List<ChartData> datos, int intervaloAgrupacion) {
    if (datos.isEmpty) return 'Sin datos';

    final start = datos.first.fecha;
    final end = datos.last.fecha;
    final startStr = _formatDate(start);
    final endStr = _formatDate(end);
    final tipo = intervaloAgrupacion == 1 ? 'diario' : 'agrupado';
    return '$startStr - $endStr ($tipo)';
  }

  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = date.year.toString();
    return '$dd/$mm/$yy';
  }

  Uint8List? _decodeBase64Image(String base64String) {
    var data = base64String.trim();
    if (data.isEmpty) {
      return null;
    }
    const marker = 'base64,';
    final index = data.indexOf(marker);
    if (index >= 0) {
      data = data.substring(index + marker.length);
    }
    while (data.length % 4 != 0) {
      data += '=';
    }
    try {
      return Uint8List.fromList(base64Decode(data));
    } catch (_) {
      return null;
    }
  }
}

class ChartData {
  final DateTime fecha;
  final String fechaKey;
  int actividades;
  double kilometros;
  double desnivel;
  int minutos;
  double pesoKg;
  int ejercicios;

  ChartData({
    required this.fecha,
    required this.fechaKey,
    required this.actividades,
    required this.kilometros,
    required this.desnivel,
    required this.minutos,
    required this.pesoKg,
    required this.ejercicios,
  });
}
