import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/mixins/auth_error_handler_mixin.dart';
import 'package:nutri_app/models/todo_item.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/user_settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen>
    with SingleTickerProviderStateMixin, AuthErrorHandlerMixin {
  static const _viewPrefsKey = 'todo_list_default_view';

  late final TabController _tabController;
  final ApiService _apiService = ApiService();

  List<TodoItem> _items = [];
  bool _isLoading = true;
  bool _isCalendarView = false;
  String _settingsScope = 'guest';

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  CalendarFormat _modeToCalendarFormat(String mode) {
    switch (mode) {
      case 'week':
        return CalendarFormat.week;
      case 'twoWeeks':
        return CalendarFormat.twoWeeks;
      case 'month':
      default:
        return CalendarFormat.month;
    }
  }

  String _calendarFormatToMode(CalendarFormat format) {
    switch (format) {
      case CalendarFormat.week:
        return 'week';
      case CalendarFormat.twoWeeks:
        return 'twoWeeks';
      case CalendarFormat.month:
        return 'month';
    }
  }

  Future<void> _saveTasksCalendarViewMode(CalendarFormat format) async {
    await UserSettingsService.setTasksCalendarViewMode(
      _settingsScope,
      _calendarFormatToMode(format),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        return;
      }
      final isGuest = context.read<AuthService>().isGuestMode;
      if (isGuest) {
        return;
      }
      _loadItems();
    });
    _loadUiStateAndData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUiStateAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultView = prefs.getString(_viewPrefsKey) ?? 'list';
    final authService = context.read<AuthService>();
    final isGuest = authService.isGuestMode;
    final scope = UserSettingsService.buildScopeKey(
      isGuestMode: authService.isGuestMode,
      userCode: authService.userCode,
      patientCode: authService.patientCode,
      userType: authService.userType,
    );
    final selectedCalendarMode =
        await UserSettingsService.getTasksCalendarViewMode(scope);

    if (!mounted) {
      return;
    }

    setState(() {
      _settingsScope = scope;
      _isCalendarView = defaultView == 'calendar';
      _calendarFormat = _modeToCalendarFormat(selectedCalendarMode);
      if (isGuest) {
        _isLoading = false;
      }
    });

    if (isGuest) {
      return;
    }

    await _loadItems();
  }

  Future<void> _saveViewState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewPrefsKey, _isCalendarView ? 'calendar' : 'list');
  }

  String? _estadoFiltroActual() {
    switch (_tabController.index) {
      case 0:
        return 'P';
      case 1:
        return 'R';
      default:
        return null;
    }
  }

  Future<void> _loadItems() async {
    if (!mounted) {
      return;
    }

    final isGuest = context.read<AuthService>().isGuestMode;
    if (isGuest) {
      setState(() {
        _isLoading = false;
        _items = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final items =
          await _apiService.getTodoItems(estado: _estadoFiltroActual());

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      if (!handleAuthError(e)) {
        final message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.isEmpty
                ? 'No se pudieron cargar las tareas.'
                : message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<TodoItem> _itemsForDay(DateTime day) {
    return _items
        .where((item) =>
            item.fechaTarea != null && _sameDay(item.fechaTarea!, day))
        .toList();
  }

  Future<void> _toggleEstado(TodoItem item) async {
    try {
      final updated = await _apiService.updateTodoItem({
        'codigo': item.codigo,
        'estado': item.isResuelta ? 'P' : 'R',
      });

      if (!mounted) {
        return;
      }

      setState(() {
        final index = _items.indexWhere((it) => it.codigo == updated.codigo);
        if (index >= 0) {
          _items[index] = updated;
        }
      });

      await _loadItems();
    } catch (e) {
      if (!mounted) {
        return;
      }
      if (!handleAuthError(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteItem(TodoItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Deseas eliminar la tarea "${item.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (!(confirm ?? false)) {
      return;
    }

    try {
      await _apiService.deleteTodoItem(item.codigo);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarea eliminada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadItems();
    } catch (e) {
      if (!mounted) {
        return;
      }
      if (!handleAuthError(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTaskTile(TodoItem item, {bool showStatusTag = true}) {
    final dateLabel = item.fechaTarea == null
        ? 'Sin fecha'
        : DateFormat('dd/MM/yyyy').format(item.fechaTarea!);
    final statusColor = item.isResuelta ? Colors.green : Colors.orange;
    final statusLabel = item.isResuelta ? 'R' : 'P';
    final description = (item.descripcion ?? '').trim();
    final prioridad = item.prioridad.toUpperCase();
    final bool prioridadAlta = prioridad == 'A';
    final bool prioridadBaja = prioridad == 'B';
    final priorityLetter = prioridadAlta
        ? 'A'
        : prioridadBaja
            ? 'B'
            : 'M';
    final priorityColor = prioridadAlta
        ? Colors.red
        : prioridadBaja
            ? Colors.green
            : Colors.orange;
    final priorityTooltip = prioridadAlta
        ? 'Prioridad Alta'
        : prioridadBaja
            ? 'Prioridad Baja'
            : 'Prioridad Media';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.titulo,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: item.isResuelta ? TextDecoration.lineThrough : null,
                color: item.isResuelta ? Colors.grey.shade700 : null,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showStatusTag)
                  Tooltip(
                    message:
                        item.isResuelta ? 'Realizada (R)' : 'Pendiente (P)',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                Tooltip(
                  message: priorityTooltip,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: priorityColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      priorityLetter,
                      style: TextStyle(
                        color: priorityColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.45)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: IconButton(
                    onPressed: () => _toggleEstado(item),
                    tooltip: item.isResuelta
                        ? 'Marcar pendiente'
                        : 'Marcar resuelta',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    icon: Icon(
                      item.isResuelta
                          ? Icons.radio_button_unchecked
                          : Icons.check_circle,
                      color: statusColor,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: IconButton(
                    onPressed: () => _showTodoDialog(item: item),
                    tooltip: 'Editar',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: IconButton(
                    onPressed: () => _deleteItem(item),
                    tooltip: 'Eliminar',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTodoDialog(
      {TodoItem? item, DateTime? preselectedDay}) async {
    final isEditing = item != null;

    final titleController = TextEditingController(text: item?.titulo ?? '');
    final descriptionController =
        TextEditingController(text: item?.descripcion ?? '');
    var estado = item?.estado.toUpperCase() ?? 'P';
    var prioridad = item?.prioridad.toUpperCase() ?? 'M';
    final today = DateTime.now();
    DateTime? fechaTarea = item?.fechaTarea ??
        preselectedDay ??
        (!isEditing ? DateTime(today.year, today.month, today.day) : null);

    final formKey = GlobalKey<FormState>();

    final save = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final fechaTexto = fechaTarea == null
                ? 'Sin fecha'
                : DateFormat('dd/MM/yyyy').format(fechaTarea!);

            return AlertDialog(
              title: Text(isEditing ? 'Editar tarea' : 'Nueva tarea'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Título',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'El título es obligatorio';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Descripción (opcional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<String>(
                                initialValue: prioridad,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Prioridad',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'A', child: Text('Alta')),
                                  DropdownMenuItem(
                                      value: 'M', child: Text('Media')),
                                  DropdownMenuItem(
                                      value: 'B', child: Text('Baja')),
                                ],
                                onChanged: (value) {
                                  setDialogState(() {
                                    prioridad = value ?? 'M';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 6,
                              child: DropdownButtonFormField<String>(
                                initialValue: estado,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Estado',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'P', child: Text('Pendiente')),
                                  DropdownMenuItem(
                                      value: 'R', child: Text('Resuelta')),
                                ],
                                onChanged: (value) {
                                  setDialogState(() {
                                    estado = value ?? 'P';
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: fechaTarea ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked == null) {
                                  return;
                                }
                                setDialogState(() {
                                  fechaTarea = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                  );
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(40, 40),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              child: const Icon(Icons.calendar_month),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: fechaTarea == null
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        fechaTarea = null;
                                      });
                                    },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(40, 40),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              child: const Icon(Icons.clear),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(fechaTexto)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!(save ?? false)) {
      return;
    }

    final payload = <String, dynamic>{
      'titulo': titleController.text.trim(),
      'descripcion': descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      'estado': estado,
      'prioridad': prioridad,
      'fecha_tarea': fechaTarea == null
          ? null
          : DateFormat('yyyy-MM-dd').format(fechaTarea!),
    };

    if (isEditing) {
      payload['codigo'] = item.codigo;
    }

    try {
      if (isEditing) {
        await _apiService.updateTodoItem(payload);
      } else {
        await _apiService.createTodoItem(payload);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing
              ? 'Tarea actualizada correctamente'
              : 'Tarea creada correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadItems();
    } catch (e) {
      if (!mounted) {
        return;
      }

      if (!handleAuthError(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildGuestContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 54,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Registro requerido',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Para poder usar Tareas, debes registrarte (es gratis).',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    icon: const Icon(Icons.app_registration),
                    label: const Text('Iniciar registro'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarMarkers(DateTime day) {
    final items = _itemsForDay(day);
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasPending = items.any((element) => !element.isResuelta);
    final hasResolved = items.any((element) => element.isResuelta);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasPending)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange,
            ),
          ),
        if (hasResolved)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green,
            ),
          ),
      ],
    );
  }

  Widget _buildCalendarView() {
    final selectedItems = _itemsForDay(_selectedDay);
    final showStatusTag = _tabController.index == 2;

    return Column(
      children: [
        TableCalendar<TodoItem>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2100, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: _itemsForDay,
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
            _saveTasksCalendarViewMode(format);
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onDayLongPressed: (selectedDay, focusedDay) async {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            await _showTodoDialog(preselectedDay: selectedDay);
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              return _buildCalendarMarkers(day);
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              const Icon(Icons.event_note),
              const SizedBox(width: 8),
              Text(
                'Tareas del ${DateFormat('dd/MM/yyyy').format(_selectedDay)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showTodoDialog(preselectedDay: _selectedDay),
                icon: const Icon(Icons.add),
                label: const Text('Nueva'),
              ),
            ],
          ),
        ),
        Expanded(
          child: selectedItems.isEmpty
              ? const Center(
                  child: Text('No hay tareas para el día seleccionado.'),
                )
              : ListView.builder(
                  itemCount: selectedItems.length,
                  itemBuilder: (context, index) {
                    final item = selectedItems[index];
                    return _buildTaskTile(item, showStatusTag: showStatusTag);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildListContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return const Center(child: Text('No hay tareas para mostrar.'));
    }

    final showStatusTag = _tabController.index == 2;

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) =>
          _buildTaskTile(_items[index], showStatusTag: showStatusTag),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isGuest = authService.isGuestMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tareas'),
        bottom: isGuest
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Pendientes'),
                  Tab(text: 'Resueltas'),
                  Tab(text: 'Todas'),
                ],
              ),
        actions: [
          if (!isGuest)
            IconButton(
              tooltip: _isCalendarView ? 'Ver lista' : 'Ver calendario',
              onPressed: () async {
                setState(() {
                  _isCalendarView = !_isCalendarView;
                });
                await _saveViewState();
              },
              icon: Icon(
                _isCalendarView
                    ? Icons.view_list_outlined
                    : Icons.calendar_month,
              ),
            ),
        ],
      ),
      body: isGuest
          ? _buildGuestContent()
          : _isCalendarView
              ? _buildCalendarView()
              : _buildListContent(),
      floatingActionButton: isGuest
          ? null
          : FloatingActionButton(
              onPressed: () => _showTodoDialog(
                preselectedDay: _isCalendarView ? _selectedDay : null,
              ),
              child: const Icon(Icons.add),
            ),
    );
  }
}
