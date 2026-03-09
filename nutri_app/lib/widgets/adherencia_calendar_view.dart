import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/services/adherencia_service.dart';

typedef AdherenciaDayTap = Future<void> Function(DateTime day);

class AdherenciaCalendarView extends StatelessWidget {
  const AdherenciaCalendarView({
    super.key,
    required this.month,
    required this.calendarViewMode,
    required this.onMonthChanged,
    required this.estadosPorDia,
    required this.showNutri,
    required this.showFit,
    required this.onDayTap,
  });

  final DateTime month;
  final String calendarViewMode;
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

  DateTime _monthGridStart(DateTime anchor) {
    final monthStart = DateTime(anchor.year, anchor.month, 1);
    return monthStart.subtract(Duration(days: monthStart.weekday - 1));
  }

  DateTime _weekStart(DateTime anchor) {
    final day = DateTime(anchor.year, anchor.month, anchor.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  int _visibleDays(String mode) {
    switch (mode) {
      case 'week':
        return 7;
      case 'twoWeeks':
        return 14;
      case 'month':
      default:
        return 42;
    }
  }

  DateTime _rangeStart(DateTime anchor, String mode) {
    switch (mode) {
      case 'week':
      case 'twoWeeks':
        return _weekStart(anchor);
      case 'month':
      default:
        return _monthGridStart(anchor);
    }
  }

  DateTime _previousAnchor(DateTime anchor, String mode) {
    switch (mode) {
      case 'week':
        return anchor.subtract(const Duration(days: 7));
      case 'twoWeeks':
        return anchor.subtract(const Duration(days: 14));
      case 'month':
      default:
        return DateTime(anchor.year, anchor.month - 1, 1);
    }
  }

  DateTime _nextAnchor(DateTime anchor, String mode) {
    switch (mode) {
      case 'week':
        return anchor.add(const Duration(days: 7));
      case 'twoWeeks':
        return anchor.add(const Duration(days: 14));
      case 'month':
      default:
        return DateTime(anchor.year, anchor.month + 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(month.year, month.month, 1);
    final gridStart = _rangeStart(month, calendarViewMode);
    final visibleDays = _visibleDays(calendarViewMode);
    final gridEnd = gridStart.add(Duration(days: visibleDays - 1));
    final now = DateTime.now();
    final todayDayOnly = DateTime(now.year, now.month, now.day);
    final monthTitle = DateFormat('MMMM yyyy', 'es_ES').format(monthStart);
    final headerTitle = calendarViewMode == 'month'
        ? '${monthTitle[0].toUpperCase()}${monthTitle.substring(1)}'
        : '${DateFormat('dd/MM/yyyy').format(gridStart)} - ${DateFormat('dd/MM/yyyy').format(gridEnd)}';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => onMonthChanged(
                    _previousAnchor(month, calendarViewMode),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      headerTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => onMonthChanged(
                    _nextAnchor(month, calendarViewMode),
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
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: visibleDays,
              itemBuilder: (context, index) {
                final day = gridStart.add(Duration(days: index));
                final inCurrentMonth = calendarViewMode == 'month'
                    ? day.month == month.month
                    : true;
                final isToday = day.year == now.year &&
                    day.month == now.month &&
                    day.day == now.day;
                final dayOnly = DateTime(day.year, day.month, day.day);
                final isFutureDay = dayOnly.isAfter(todayDayOnly);
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
                  onTap: (inCurrentMonth && !isFutureDay)
                      ? () => onDayTap(day)
                      : null,
                  child: Opacity(
                    opacity: inCurrentMonth ? (isFutureDay ? 0.55 : 1) : 0.35,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Positioned.fill(child: background),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isToday
                                      ? Colors.blue.shade700
                                      : Colors.black12,
                                  width: isToday ? 1.8 : 1.0,
                                ),
                                color: isToday
                                    ? Colors.lightBlueAccent.withValues(
                                        alpha: 0.12,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          if (showNutri && nutri != null)
                            Positioned(
                              top: 3,
                              left: 4,
                              child: Text(
                                'N',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.blueGrey.shade900,
                                ),
                              ),
                            ),
                          if (showFit && fit != null)
                            Positioned(
                              right: 4,
                              bottom: 3,
                              child: Text(
                                'F',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.blueGrey.shade900,
                                ),
                              ),
                            ),
                          Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isToday ? Colors.blue.shade900 : null,
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _legend(Colors.green.shade400, 'Cumplido'),
                _legend(Colors.orange.shade400, 'Parcial'),
                _legend(Colors.red.shade400, 'No realizado'),
                _legend(Colors.grey.shade300, 'Sin registro'),
                _legend(Colors.lightBlueAccent.withValues(alpha: 0.35), 'Hoy'),
                if (showNutri && showFit)
                  const Text(
                      'Superior: Plan Nutri (N)  ~  Inferior: Plan Fit (F)'),
              ],
            ),
          ],
        ),
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
