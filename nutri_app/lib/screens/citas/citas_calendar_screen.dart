import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/cita.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:nutri_app/screens/citas/cita_edit_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CitasCalendarScreen extends StatefulWidget {
  final Paciente? paciente;
  final bool fromListView;
  const CitasCalendarScreen(
      {super.key, this.paciente, this.fromListView = false});

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
  bool _showFilterCitas = false; // Estado del filtro (mostrar/ocultar)
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
    _loadUiState();
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

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showFilterCitas = prefs.getBool('citas_calendar_show_filter') ?? false;
    });
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('citas_calendar_show_filter', _showFilterCitas);
  }

  Future<void> _loadCitasForMonth(int year, int month) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
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
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al cargar citas. $errorMessage'),
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

      final citasDelDia = _getEventsForDay(selectedDay);
      if (citasDelDia.isEmpty) {
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

  void _showRealizarCitaDialog(Cita cita) {
    final TextEditingController descController = TextEditingController();
    if (cita.descripcion != null && cita.descripcion!.isNotEmpty) {
      descController.text = cita.descripcion!;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Realizar Cita'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Descripción de la cita:'),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 4,
                minLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Resultado de la cita...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _realizarCita(cita, descController.text);
              },
              icon: const Icon(Icons.check),
              label: const Text('Realizar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _realizarCita(Cita cita, String descripcion) async {
    try {
      final apiService = context.read<ApiService>();
      final authService = context.read<AuthService>();
      final codusuario = authService.userCode;
      final ahora = DateTime.now();

      final datosActualizacion = {
        'codigo': cita.codigo,
        'codigo_paciente': cita.codigoPaciente,
        'estado': 'Realizada',
        'descripcion': descripcion,
        'fecham': ahora.toIso8601String(),
        'codusuariom': codusuario,
      };

      await apiService.updateCitaData(datosActualizacion);
      _loadCitasForMonth(_focusedDay.year, _focusedDay.month);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita realizada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        leading: widget.fromListView
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : IconButton(
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
            icon: Icon(_showFilterCitas
                ? Icons.filter_alt
                : Icons.filter_alt_outlined),
            tooltip: _showFilterCitas ? 'Ocultar filtro' : 'Mostrar filtro',
            onPressed: () {
              setState(() {
                _showFilterCitas = !_showFilterCitas;
              });
              _saveUiState();
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
          // Filtro de estado (condicional)
          if (_showFilterCitas)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Center(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: "Pendiente", label: Text('Pend.')),
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
              todayBuilder: (context, day, focusedDay) {
                final events = _getEventsForDay(day);
                Color backgroundColor;

                // Día de hoy siempre tiene fondo azul claro
                backgroundColor = Colors.blue.shade100;

                // Si tiene citas, ajustamos el tono
                if (events.length == 1) {
                  backgroundColor = Colors.lightBlue.shade200;
                } else if (events.length > 1) {
                  backgroundColor = Colors.lightBlue.shade300;
                }

                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: backgroundColor,
                    border: Border.all(
                      color: Colors.blue.shade700,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      day.day.toString(),
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
              defaultBuilder: (context, day, focusedDay) {
                final events = _getEventsForDay(day);

                if (events.isEmpty) {
                  return null; // Usar estilo por defecto
                }

                // Determinar color según número de citas
                Color backgroundColor;
                if (events.length == 1) {
                  backgroundColor = Colors.green.shade100;
                } else {
                  backgroundColor = Colors.green.shade300;
                }

                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: backgroundColor,
                  ),
                  child: Center(
                    child: Text(
                      day.day.toString(),
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
              selectedBuilder: (context, day, focusedDay) {
                final events = _getEventsForDay(day);
                final isToday = isSameDay(day, DateTime.now());

                Color backgroundColor;
                Color borderColor;
                Color textColor;

                if (isToday) {
                  // Día seleccionado que es hoy
                  if (events.length == 1) {
                    backgroundColor = Colors.lightBlue.shade200;
                  } else if (events.length > 1) {
                    backgroundColor = Colors.lightBlue.shade300;
                  } else {
                    backgroundColor = Colors.blue.shade100;
                  }
                  borderColor = Colors.blue.shade700;
                  textColor = Colors.blue.shade900;
                } else if (events.isNotEmpty) {
                  // Día seleccionado con citas
                  if (events.length == 1) {
                    backgroundColor = Colors.green.shade100;
                  } else {
                    backgroundColor = Colors.green.shade300;
                  }
                  borderColor = Theme.of(context).colorScheme.primary;
                  textColor = Colors.green.shade900;
                } else {
                  // Día seleccionado sin citas
                  backgroundColor = Theme.of(context).colorScheme.primary;
                  borderColor = Theme.of(context).colorScheme.primary;
                  textColor = Colors.white;
                }

                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: backgroundColor,
                    border: Border.all(
                      color: borderColor,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      day.day.toString(),
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
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
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cita.nombrePaciente ??
                                        'Paciente no asignado',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          if (cita.comienzo != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green[50],
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: Colors.green[200]!,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                      Icons.play_circle_outline,
                                                      size: 14,
                                                      color: Colors.green),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    DateFormat.Hm()
                                                        .format(cita.comienzo!),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.green[700],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (cita.fin != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: Colors.red[200]!,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                      Icons
                                                          .stop_circle_outlined,
                                                      size: 14,
                                                      color: Colors.red),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    DateFormat.Hm()
                                                        .format(cita.fin!),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.red[700],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        onPressed: () =>
                                            _navigateToEditScreen(cita: cita),
                                        icon: const Icon(Icons.edit),
                                        color: Colors.blue,
                                        iconSize: 28,
                                        tooltip: 'Editar',
                                      ),
                                      if (cita.estado == 'Pendiente')
                                        IconButton(
                                          onPressed: () =>
                                              _showRealizarCitaDialog(cita),
                                          icon: const Icon(Icons.check),
                                          color: Colors.green,
                                          iconSize: 28,
                                          tooltip: 'Realizar',
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber[100],
                                      borderRadius: BorderRadius.circular(6),
                                      border:
                                          Border.all(color: Colors.amber[300]!),
                                    ),
                                    child: Text(
                                      cita.asunto,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
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
