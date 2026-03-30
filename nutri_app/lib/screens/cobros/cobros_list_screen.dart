import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/cobro.dart';
import 'package:nutri_app/screens/cobros/cobro_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/models/paciente.dart';

class CobrosListScreen extends StatefulWidget {
  final Paciente? paciente;
  const CobrosListScreen({super.key, this.paciente});

  @override
  State<CobrosListScreen> createState() => _CobrosListScreenState();
}

class _CobrosListScreenState extends State<CobrosListScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _amountFormat = NumberFormat('#,##0.00', 'es_ES');
  Future<List<Cobro>>? _cobrosFuture;
  String _evolutionRange = '3m';

  @override
  void initState() {
    super.initState();
    context
        .read<ConfigService>()
        .loadDeleteSwipePercentageFromDatabase(_apiService);
    _refreshCobros();
  }

  void _refreshCobros() {
    setState(() {
      _cobrosFuture =
          _apiService.getCobros(codigoPaciente: widget.paciente?.codigo);
    });
  }

  void _navigateToEditScreen([Cobro? cobro]) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => CobroEditScreen(
              cobro: cobro,
              paciente: widget.paciente,
            ),
          ),
        )
        .then((_) => _refreshCobros());
  }

  Future<void> _deleteCobro(int codigo) async {
    try {
      final success = await _apiService.deleteCobro(codigo);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Cobro eliminado'), backgroundColor: Colors.green),
        );
        _refreshCobros();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al eliminar'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showDeleteConfirmation(Cobro cobro) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
              '¿Seguro que quieres eliminar el cobro de ${cobro.importe}€ de ${cobro.pagadorNombre}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteCobro(cobro.codigo);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCobroMenu(Cobro cobro) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

    if (action == 'edit') {
      _navigateToEditScreen(cobro);
    } else if (action == 'delete') {
      _showDeleteConfirmation(cobro);
    }
  }

  double _sumSince(List<Cobro> cobros, DateTime fromDate) {
    return cobros
        .where(
            (c) => !DateTime(c.fecha.year, c.fecha.month, c.fecha.day).isBefore(
                  DateTime(fromDate.year, fromDate.month, fromDate.day),
                ))
        .fold<double>(0, (sum, item) => sum + item.importe);
  }

  String _formatAmount(double amount) {
    return '${_amountFormat.format(amount)}€';
  }

  List<MapEntry<DateTime, double>> _buildDailyTotals(List<Cobro> cobros) {
    final Map<DateTime, double> grouped = {};

    for (final cobro in cobros) {
      final day =
          DateTime(cobro.fecha.year, cobro.fecha.month, cobro.fecha.day);
      grouped.update(day, (value) => value + cobro.importe,
          ifAbsent: () => cobro.importe);
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  DateTime _rangeStartDate(String range) {
    final now = DateTime.now();
    switch (range) {
      case 'all':
        return DateTime.fromMillisecondsSinceEpoch(0);
      case '1m':
        return DateTime(now.year, now.month - 1, now.day);
      case '6m':
        return DateTime(now.year, now.month - 6, now.day);
      case '1y':
        return DateTime(now.year - 1, now.month, now.day);
      case '3m':
      default:
        return DateTime(now.year, now.month - 3, now.day);
    }
  }

  void _showEvolutionRangeHint(String hint) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(hint),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Widget _buildRangeTagLabel(String shortLabel, String hint) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showEvolutionRangeHint(hint),
      child: Text(shortLabel),
    );
  }

  Widget _buildEvolutionRangeSelector() {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: '1m',
          label: _buildRangeTagLabel('1M', 'Último mes'),
        ),
        ButtonSegment(
          value: '3m',
          label: _buildRangeTagLabel('3M', 'Últimos tres meses'),
        ),
        ButtonSegment(
          value: '6m',
          label: _buildRangeTagLabel('6M', 'Últimos 6 meses'),
        ),
        ButtonSegment(
          value: '1y',
          label: _buildRangeTagLabel('1A', 'Último año'),
        ),
        ButtonSegment(
          value: 'all',
          label: _buildRangeTagLabel('S', 'Siempre'),
        ),
      ],
      selected: {_evolutionRange},
      onSelectionChanged: (selection) {
        setState(() {
          _evolutionRange = selection.first;
        });
      },
    );
  }

  Widget _buildCobrosList(List<Cobro> cobros) {
    if (cobros.isEmpty) {
      return const Center(child: Text('No se encontraron cobros.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: cobros.length,
      itemBuilder: (context, index) {
        final cobro = cobros[index];
        return Dismissible(
          key: ValueKey('cobro_${cobro.codigo}_$index'),
          direction: DismissDirection.startToEnd,
          dismissThresholds: {
            DismissDirection.startToEnd:
                context.watch<ConfigService>().deleteSwipeDismissThreshold,
          },
          background: Container(
            color: Colors.red.shade600,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Eliminar', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          confirmDismiss: (_) async {
            _showDeleteConfirmation(cobro);
            return false;
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            elevation: 2,
            child: ListTile(
              title: Text(
                '${_formatAmount(cobro.importe)} - ${cobro.nombrePaciente ?? cobro.nombreCliente ?? '-'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                DateFormat('dd/MM/yyyy').format(cobro.fecha),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Más opciones',
                onPressed: () => _openCobroMenu(cobro),
              ),
              onTap: () => _navigateToEditScreen(cobro),
              onLongPress: () => _openCobroMenu(cobro),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTotalsTab(List<Cobro> cobros) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfYear = DateTime(now.year, 1, 1);
    final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    final startOfQuarter = DateTime(now.year, quarterStartMonth, 1);

    final totalEsteMes = _sumSince(cobros, startOfMonth);
    final totalEsteAnio = _sumSince(cobros, startOfYear);
    final totalEsteTrimestre = _sumSince(cobros, startOfQuarter);
    final totalUltimos30Dias =
        _sumSince(cobros, now.subtract(const Duration(days: 30)));
    final totalUltimos90Dias =
        _sumSince(cobros, now.subtract(const Duration(days: 90)));
    final totalUltimos180Dias =
        _sumSince(cobros, now.subtract(const Duration(days: 180)));
    final totalUltimos365Dias =
        _sumSince(cobros, now.subtract(const Duration(days: 365)));
    final totalSiempre =
        cobros.fold<double>(0, (sum, item) => sum + item.importe);

    const Color colorVerdeSuave = Color(0xFFE8F5E9);
    const Color colorAzulSuave = Color(0xFFE3F2FD);
    const Color colorTurquesaSuave = Color(0xFFE0F7FA);

    final items = [
      ('Este mes', totalEsteMes, colorVerdeSuave),
      ('Este año', totalEsteAnio, colorVerdeSuave),
      ('Este trimestre', totalEsteTrimestre, colorVerdeSuave),
      ('Último mes', totalUltimos30Dias, colorAzulSuave),
      ('Últimos tres meses', totalUltimos90Dias, colorAzulSuave),
      ('Últimos 6 meses', totalUltimos180Dias, colorAzulSuave),
      ('Último año', totalUltimos365Dias, colorAzulSuave),
      ('Siempre', totalSiempre, colorTurquesaSuave),
    ];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final item in items)
          Card(
            color: item.$3,
            child: ListTile(
              title: Text(item.$1),
              trailing: Text(
                _formatAmount(item.$2),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEvolutionChart(List<Cobro> cobros) {
    final fromDate = _rangeStartDate(_evolutionRange);
    final filteredCobros = cobros
        .where(
            (c) => !DateTime(c.fecha.year, c.fecha.month, c.fecha.day).isBefore(
                  DateTime(fromDate.year, fromDate.month, fromDate.day),
                ))
        .toList();

    final dailyTotals = _buildDailyTotals(filteredCobros);
    if (dailyTotals.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: _buildEvolutionRangeSelector(),
          ),
          const Expanded(
            child: Center(child: Text('Sin datos para mostrar evolución.')),
          ),
        ],
      );
    }

    final spots = List.generate(
      dailyTotals.length,
      (index) => FlSpot(index.toDouble(), dailyTotals[index].value),
    );

    final maxY = dailyTotals.fold<double>(
      0,
      (maxValue, entry) => math.max(maxValue, entry.value),
    );
    final interval =
        dailyTotals.length <= 4 ? 1 : (dailyTotals.length / 4).ceil();

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: _buildEvolutionRangeSelector(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY <= 0 ? 10 : (maxY * 1.2),
                gridData: const FlGridData(show: true),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final date = dailyTotals[idx].key;
                        final dateLabel = DateFormat('dd/MM/yyyy').format(date);
                        return LineTooltipItem(
                          '$dateLabel\n${spot.y.toStringAsFixed(2)} €',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 46),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= dailyTotals.length) {
                          return const SizedBox.shrink();
                        }

                        final isEdge =
                            idx == 0 || idx == dailyTotals.length - 1;
                        final shouldShow = isEdge || idx % interval == 0;
                        if (!shouldShow) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('dd/MM').format(dailyTotals[idx].key),
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    color: colorScheme.primary,
                    barWidth: 3,
                    isCurved: false,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: colorScheme.primary,
                          strokeWidth: 1,
                          strokeColor: colorScheme.onPrimary,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabbedContent(List<Cobro> cobros) {
    return Column(
      children: [
        const TabBar(
          tabs: [
            Tab(text: 'Listado'),
            Tab(text: 'Totales'),
            Tab(text: 'Evolución'),
          ],
        ),
        Expanded(
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildCobrosList(cobros),
              _buildTotalsTab(cobros),
              _buildEvolutionChart(cobros),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String appBarTitle = widget.paciente != null
        ? 'Cobros de ${widget.paciente!.nombre}'
        : 'Cobros';

    final configService = context.watch<ConfigService>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(appBarTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshCobros,
            ),
          ],
        ),
        drawer: widget.paciente == null ? const AppDrawer() : null,
        body: SafeArea(
          child: FutureBuilder<List<Cobro>>(
            future: _cobrosFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                final errorMessage = snapshot.error.toString();
                if (configService.appMode == AppMode.debug) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SelectableText(errorMessage),
                    ),
                  );
                } else {
                  return const Center(
                      child: Text('Error al cargar los cobros.'));
                }
              }

              final cobros = snapshot.data ?? [];
              return _buildTabbedContent(cobros);
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _navigateToEditScreen(),
          tooltip: 'Añadir Cobro',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
