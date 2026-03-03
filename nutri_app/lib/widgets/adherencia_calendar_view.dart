import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/services/adherencia_service.dart';

typedef AdherenciaDayTap = Future<void> Function(DateTime day);

class AdherenciaCalendarView extends StatelessWidget {
  const AdherenciaCalendarView({
    super.key,
    required this.month,
    required this.onMonthChanged,
    required this.estadosPorDia,
    required this.showNutri,
    required this.showFit,
    required this.onDayTap,
  });

  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;
  final Map<String, Map<AdherenciaTipo, AdherenciaEstado>> estadosPorDia;
  final bool showNutri;
  final bool showFit;
  final AdherenciaDayTap onDayTap;

  String _dayKey(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  Color _estadoColor(AdherenciaEstado? estado) {
    switch (estado) {
      case AdherenciaEstado.cumplido:
        return Colors.green.shade400;
      case AdherenciaEstado.parcial:
        return Colors.orange.shade400;
      case AdherenciaEstado.noRealizado:
        return Colors.red.shade400;
      case null:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(month.year, month.month, 1);
    final gridStart =
        monthStart.subtract(Duration(days: monthStart.weekday - 1));
    final monthTitle = DateFormat('MMMM yyyy', 'es_ES').format(monthStart);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => onMonthChanged(
                  DateTime(month.year, month.month - 1, 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${monthTitle[0].toUpperCase()}${monthTitle.substring(1)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onMonthChanged(
                  DateTime(month.year, month.month + 1, 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Expanded(child: Center(child: Text('L'))),
              Expanded(child: Center(child: Text('M'))),
              Expanded(child: Center(child: Text('X'))),
              Expanded(child: Center(child: Text('J'))),
              Expanded(child: Center(child: Text('V'))),
              Expanded(child: Center(child: Text('S'))),
              Expanded(child: Center(child: Text('D'))),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: 42,
              itemBuilder: (context, index) {
                final day = gridStart.add(Duration(days: index));
                final inCurrentMonth = day.month == month.month;
                final dayStates = estadosPorDia[_dayKey(day)] ?? const {};
                final nutri = dayStates[AdherenciaTipo.nutri];
                final fit = dayStates[AdherenciaTipo.fit];

                Widget background;
                if (showNutri && showFit) {
                  background = Column(
                    children: [
                      Expanded(
                        child: Container(color: _estadoColor(nutri)),
                      ),
                      Expanded(
                        child: Container(color: _estadoColor(fit)),
                      ),
                    ],
                  );
                } else if (showNutri) {
                  background = Container(color: _estadoColor(nutri));
                } else {
                  background = Container(color: _estadoColor(fit));
                }

                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: inCurrentMonth ? () => onDayTap(day) : null,
                  child: Opacity(
                    opacity: inCurrentMonth ? 1 : 0.35,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Positioned.fill(child: background),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black12),
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              '${day.day}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _legend(Colors.green.shade400, 'Cumplido'),
              _legend(Colors.orange.shade400, 'Parcial'),
              _legend(Colors.red.shade400, 'No realizado'),
              _legend(Colors.grey.shade300, 'Sin registro'),
              if (showNutri && showFit)
                const Text('Mitad superior: Nutri · inferior: Fit'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
