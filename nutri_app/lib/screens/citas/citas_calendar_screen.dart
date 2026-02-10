import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/cita.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:nutri_app/screens/citas/cita_edit_screen.dart';

class CitasCalendarScreen extends StatefulWidget {
  final Paciente? paciente;
  const CitasCalendarScreen({super.key, this.paciente});

  @override
  State<CitasCalendarScreen> createState() => _CitasCalendarScreenState();
}

class _CitasCalendarScreenState extends State<CitasCalendarScreen> {
  late LinkedHashMap<DateTime, List<Cita>> _events;
  late final ValueNotifier<List<Cita>> _selectedEvents;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _isLoading = true;
  String _filtroEstado = "Pendiente"; // Filtro inicial
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _events = LinkedHashMap<DateTime, List<Cita>>(
      equals: isSameDay,
      hashCode: getHashCode,
    );
    _selectedEvents = ValueNotifier([]);
    _loadCitasForMonth(_focusedDay.year, _focusedDay.month);
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  int getHashCode(DateTime key) {
    return key.day * 1000000 + key.month * 10000 + key.year;
  }

  List<Cita> _getEventsForDay(DateTime day) {
    return _events[day] ?? [];
  }

  Future<void> _loadCitasForMonth(int year, int month) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      // Usamos el nuevo método flexible del ApiService
      final citas = await _apiService.getCitas(
          year: year,
          month: month,
          estado: _filtroEstado == "Todas" ? null : _filtroEstado,
          codigoPaciente: widget.paciente?.codigo);
      final newEvents = LinkedHashMap<DateTime, List<Cita>>(
        equals: isSameDay,
        hashCode: getHashCode,
      );
      for (var cita in citas) {
        if (cita.comienzo != null) {
          final day = cita.comienzo!;
          if (newEvents[day] == null) {
            newEvents[day] = [];
          }
          newEvents[day]!.add(cita);
        }
      }
      if (!mounted) return;
      setState(() {
        _events = newEvents;
        _isLoading = false;
        if (_selectedDay != null) {
          _selectedEvents.value = _getEventsForDay(_selectedDay!);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al cargar citas: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _selectedEvents.value = _getEventsForDay(selectedDay);

      // Mostrar ventana emergente si hay citas para este día
      final citasDelDia = _getEventsForDay(selectedDay);
      if (citasDelDia.isNotEmpty) {
        _showCitasDialog(selectedDay, citasDelDia);
      } else {
        // Si no hay citas, preguntar si quiere añadir una
        _showAddCitaDialog(selectedDay);
      }
    }
  }

  void _showAddCitaDialog(DateTime day) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No hay citas'),
        content: Text(
          'No hay citas para ${_formatDateInSpanish(day)}. ¿Deseas añadir una cita para este día?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToEditScreen(selectedDate: day);
            },
            child: const Text('Añadir Cita'),
          ),
        ],
      ),
    );
  }

  void _showCitasDialog(DateTime day, List<Cita> citas) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_formatDateInSpanish(day)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: citas.length,
            itemBuilder: (context, index) {
              final cita = citas[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(cita.asunto),
                  subtitle: Text(
                    '${cita.nombrePaciente ?? "Paciente no asignado"}\n${DateFormat.Hm().format(cita.comienzo!)} - ${DateFormat.Hm().format(cita.fin!)}',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _navigateToEditScreen(cita: cita);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _formatDateInSpanish(DateTime date) {
    const diasSemana = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    final diaSemana = diasSemana[date.weekday - 1];
    final mes = meses[date.month - 1];
    return '$diaSemana, ${date.day} de $mes de ${date.year}';
  }

  void _navigateToEditScreen({Cita? cita, DateTime? selectedDate}) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) =>
            CitaEditScreen(cita: cita, selectedDate: selectedDate),
      ),
    )
        .then((_) {
      // Recargar los eventos para el mes actual
      _loadCitasForMonth(_focusedDay.year, _focusedDay.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Calendario de Citas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'Ver en listado',
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                _loadCitasForMonth(_focusedDay.year, _focusedDay.month),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtro de estado
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Center(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: "Pendiente", label: Text('Pendientes')),
                  ButtonSegment(value: "Todas", label: Text('Todas')),
                ],
                selected: {_filtroEstado},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _filtroEstado = newSelection.first;
                    _loadCitasForMonth(_focusedDay.year, _focusedDay.month);
                  });
                },
              ),
            ),
          ),
          TableCalendar<Cita>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _loadCitasForMonth(focusedDay.year, focusedDay.month);
            },
            calendarStyle: CalendarStyle(
              defaultDecoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              weekendDecoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              selectedDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              todayDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.secondary,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              markersMaxCount: 1,
              markerDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              markerSize: 6,
              outsideDecoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekendStyle:
                  TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final hasEvents = _getEventsForDay(day).isNotEmpty;
                if (hasEvents) {
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context)
                          .colorScheme
                          .tertiary
                          .withOpacity(0.6),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.tertiary,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        day.day.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ValueListenableBuilder<List<Cita>>(
                    valueListenable: _selectedEvents,
                    builder: (context, value, _) {
                      if (value.isEmpty) {
                        return Center(
                          child: Text(
                            'No hay citas para ${DateFormat('dd/MM/yyyy').format(_selectedDay ?? DateTime.now())}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: value.length,
                        itemBuilder: (context, index) {
                          final cita = value[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 4.0),
                            child: ListTile(
                              title: Text(cita.asunto),
                              subtitle: Text(
                                  '${cita.nombrePaciente ?? "Paciente no asignado"}\n${DateFormat.Hm().format(cita.comienzo!)} - ${DateFormat.Hm().format(cita.fin!)}'),
                              onTap: () => _navigateToEditScreen(cita: cita),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditScreen(selectedDate: _selectedDay),
        tooltip: 'Añadir Cita',
        child: const Icon(Icons.add),
      ),
    );
  }
}
