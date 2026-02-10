import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  String _selectedPeriodo =
      'mes'; // 'semana', 'mes', 'trimestre', 'semestre', 'año', 'todo', 'ultimo_año', 'ultimos_6', 'ultimos_3'
  final ScrollController _periodoScrollController = ScrollController();

  @override
  void dispose() {
    _periodoScrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _procesarDatos() {
    final ahora = DateTime.now();
    DateTime fechaInicio;
    int intervaloAgrupacion; // dias

    // Determinar fecha de inicio y agrupacion segun el periodo
    switch (_selectedPeriodo) {
      case 'semana':
        fechaInicio = ahora.subtract(const Duration(days: 7));
        intervaloAgrupacion = 1; // agrupar por dia
        break;
      case 'mes':
        fechaInicio = ahora.subtract(const Duration(days: 30));
        intervaloAgrupacion = 7; // agrupar por semana
        break;
      case 'mes_pasado':
        final primerDiaMesAnterior =
            DateTime(ahora.year, ahora.month - 1 < 1 ? 12 : ahora.month - 1, 1);
        fechaInicio = ahora.month == 1
            ? DateTime(ahora.year - 1, 12, 1)
            : primerDiaMesAnterior;
        intervaloAgrupacion = 7; // agrupar por semana
        break;
      case 'trimestre':
        fechaInicio = ahora.subtract(const Duration(days: 90));
        intervaloAgrupacion = 7; // agrupar por semana
        break;
      case 'trimestre_pasado':
        fechaInicio = ahora.subtract(const Duration(days: 180));
        intervaloAgrupacion = 7; // agrupar por semana
        break;
      case 'semestre':
        fechaInicio = ahora.subtract(const Duration(days: 180));
        intervaloAgrupacion = 14; // agrupar cada 2 semanas
        break;
      case 'año':
        fechaInicio = DateTime(ahora.year, 1, 1);
        intervaloAgrupacion = 30; // agrupar por mes
        break;
      case 'año_pasado':
        fechaInicio = DateTime(ahora.year - 1, 1, 1);
        intervaloAgrupacion = 30; // agrupar por mes
        break;
      case 'todo':
        fechaInicio = DateTime(1970, 1, 1);
        intervaloAgrupacion = 30; // agrupar por mes
        break;
      case 'ultimo_año':
        fechaInicio = ahora.subtract(const Duration(days: 365));
        intervaloAgrupacion = 30; // agrupar por mes
        break;
      case 'ultimos_6':
        fechaInicio = ahora.subtract(const Duration(days: 180));
        intervaloAgrupacion = 14; // agrupar cada 2 semanas
        break;
      case 'ultimos_3':
        fechaInicio = ahora.subtract(const Duration(days: 90));
        intervaloAgrupacion = 7; // agrupar por semana
        break;
      default:
        fechaInicio = ahora.subtract(const Duration(days: 30));
        intervaloAgrupacion = 7; // agrupar por semana
    }

    // Filtrar por rango de fechas si es necesario
    DateTime? fechaFin;
    if (_selectedPeriodo == 'año_pasado') {
      fechaFin = DateTime(ahora.year, 1, 1).subtract(const Duration(days: 1));
    } else if (_selectedPeriodo == 'mes_pasado') {
      fechaFin = DateTime(ahora.year, ahora.month < 1 ? 12 : ahora.month, 1)
          .subtract(const Duration(days: 1));
    } else if (_selectedPeriodo == 'trimestre_pasado') {
      fechaFin = ahora;
    }

    // Filtrar entrenamientos por fecha
    final entrenamientosFiltrados = widget.entrenamientos.where((e) {
      final estaEnRango = e.fecha.isAfter(fechaInicio);
      if (fechaFin != null) {
        return estaEnRango && e.fecha.isBefore(fechaFin);
      }
      return estaEnRango;
    }).toList();

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
          minutos: 0,
        );
      }

      datosAcumulados[fechaKey]!.actividades++;
      datosAcumulados[fechaKey]!.kilometros +=
          entrenamiento.duracionKilometros ?? 0;
      datosAcumulados[fechaKey]!.minutos +=
          (entrenamiento.duracionHoras * 60) + entrenamiento.duracionMinutos;
    }

    // Convertir a lista ordenada
    final datos = datosAcumulados.values.toList();
    datos.sort((a, b) => a.fecha.compareTo(b.fecha));

    return {
      'datos': datos,
    };
  }

  String _getFechaKey(DateTime date, int intervalo) {
    // Redondear la fecha al intervalo mas cercano
    final daysSinceEpoch = date.difference(DateTime(2000, 1, 1)).inDays;
    final intervalIndex = (daysSinceEpoch / intervalo).floor();
    return 'interval_$intervalIndex';
  }

  String _formatFecha(DateTime fecha) {
    switch (_selectedPeriodo) {
      case 'semana':
        // Mostrar dia de la semana y dia
        final dias = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];
        return '${dias[fecha.weekday - 1]}\n${fecha.day}';
      case 'mes':
      case 'mes_pasado':
      case 'ultimos_3':
        // Mostrar dia/mes
        return '${fecha.day}/${fecha.month}';
      case 'trimestre':
      case 'trimestre_pasado':
      case 'semestre':
      case 'ultimos_6':
        // Mostrar dia/mes
        return '${fecha.day}/${fecha.month}';
      case 'año':
      case 'año_pasado':
      case 'ultimo_año':
      case 'todo':
        // Mostrar mes/año
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
      default:
        return '${fecha.day}/${fecha.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final datosMap = _procesarDatos();
    final datos = (datosMap['datos'] as List<ChartData>);

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
          // Selector de periodo
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Periodo',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Scrollbar(
                    controller: _periodoScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _periodoScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPeriodoButton('semana', 'Semana'),
                          const SizedBox(width: 8),
                          _buildPeriodoButton('mes', 'Este mes'),
                          const SizedBox(width: 8),
                          _buildPeriodoButton('mes_pasado', 'Mes pasado'),
                          const SizedBox(width: 8),
                          _buildPeriodoButton('trimestre', 'Trimestre'),
                          const SizedBox(width: 8),
                          _buildPeriodoButton(
                              'trimestre_pasado', 'Trimestre pasado'),
                          const SizedBox(width: 8),
                          _buildPeriodoButton('semestre', 'Semestre'),
                          const SizedBox(width: 8),
                          _buildPeriodoButton('año', 'Año'),
                          const SizedBox(width: 8),
                          _buildPeriodoButton('año_pasado', 'Año pasado'),
                          const SizedBox(width: 8),
                          _buildPeriodoButton('ultimos_3', 'Ultimos 3m'),
                          const SizedBox(width: 8),
                          _buildPeriodoButton('ultimos_6', 'Ultimos 6m'),
                          const SizedBox(width: 8),
                          _buildPeriodoButton('ultimo_año', 'Ultimo año'),
                          const SizedBox(width: 8),
                          _buildPeriodoButton('todo', 'Todo'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Grafica
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estadisticas del periodo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  // Leyenda
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 16),
                    child: Row(
                      children: [
                        _buildLegendaItem(
                          color: Colors.blue,
                          label: 'Actividades',
                        ),
                        const SizedBox(width: 24),
                        _buildLegendaItem(
                          color: Colors.green,
                          label: 'Kilometros',
                        ),
                        const SizedBox(width: 24),
                        _buildLegendaItem(
                          color: Colors.orange,
                          label: 'Minutos',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 300,
                    child: LineChart(
                      _buildLineChartData(datos),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Resumen del periodo
          _buildResumenCard(datos),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildPeriodoButton(String value, String label) {
    final isSelected = _selectedPeriodo == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPeriodo = value;
        });
      },
      backgroundColor:
          isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[200],
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

  LineChartData _buildLineChartData(List<ChartData> datos) {
    final maxActividades =
        datos.map((d) => d.actividades).reduce((a, b) => a > b ? a : b);
    final maxKilometros =
        datos.map((d) => d.kilometros).reduce((a, b) => a > b ? a : b);
    final maxMinutos =
        datos.map((d) => d.minutos).reduce((a, b) => a > b ? a : b);

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
                  _formatFecha(datos[index].fecha),
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
            interval: _calcularIntervalo(maxActividades),
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
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
      maxY: maxActividades.toDouble() * 1.2,
      lineBarsData: [
        // Línea de actividades (azul)
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
        LineChartBarData(
          spots: datos.asMap().entries.map((e) {
            final normalizado = (e.value.kilometros / maxKilometros) *
                (maxActividades.toDouble() * 1.2);
            return FlSpot(e.key.toDouble(), normalizado);
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
        // Línea de minutos (naranja)
        LineChartBarData(
          spots: datos.asMap().entries.map((e) {
            final normalizado = (e.value.minutos / maxMinutos) *
                (maxActividades.toDouble() * 1.2);
            return FlSpot(e.key.toDouble(), normalizado);
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
      ],
    );
  }

  double _calcularIntervalo(int maxValue) {
    if (maxValue <= 5) return 1;
    if (maxValue <= 10) return 2;
    if (maxValue <= 20) return 5;
    return 10;
  }

  Widget _buildResumenCard(List<ChartData> datos) {
    int totalActividades = 0;
    double totalKilometros = 0;
    int totalMinutos = 0;

    for (var dato in datos) {
      totalActividades += dato.actividades;
      totalKilometros += dato.kilometros;
      totalMinutos += dato.minutos;
    }

    final promActividades =
        datos.isNotEmpty ? totalActividades / datos.length : 0;
    final promKilometros =
        datos.isNotEmpty ? totalKilometros / datos.length : 0;
    final promMinutos = datos.isNotEmpty ? totalMinutos / datos.length : 0;

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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                  '⏱️',
                  '${horas}h ${minutos}m',
                  'Tiempo',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _selectedPeriodo == 'semana'
                  ? 'Promedio por dia'
                  : 'Promedio por periodo',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                  '⏱️',
                  '${(promMinutos ~/ 60).toStringAsFixed(0)}m',
                  'Tiempo',
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
}

class ChartData {
  final DateTime fecha;
  final String fechaKey;
  int actividades;
  double kilometros;
  int minutos;

  ChartData({
    required this.fecha,
    required this.fechaKey,
    required this.actividades,
    required this.kilometros,
    required this.minutos,
  });
}
