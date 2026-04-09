import 'dart:convert';
import 'dart:io';

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/mixins/auth_error_handler_mixin.dart';
import 'package:nutri_app/models/todo_item.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/menu_visibility_premium_service.dart';
import 'package:nutri_app/services/user_settings_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nutri_app/widgets/premium_feature_dialog_helper.dart';
import 'package:nutri_app/widgets/premium_upsell_card.dart';
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
  static const _defaultNonPremiumTaskLimit = 3;
  static const _todoSearchVisibleKey = 'todo_list_search_visible';
  static const _todoFilterVisibleKey = 'todo_list_filter_visible';
  static const _todoSortModeKey = 'todo_list_sort_mode';
  static const _todoSortAscendingKey = 'todo_list_sort_ascending';
  static const _todoDialogPriorityExpandedKey = 'todo_dialog_priority_expanded';
  static const _todoDialogStatusExpandedKey = 'todo_dialog_status_expanded';
  static const _todoDialogDescriptionExpandedKey =
      'todo_dialog_description_expanded';

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();

  List<TodoItem> _items = [];
  bool _isLoading = true;
  bool _isCalendarView = false;
  String _settingsScope = 'guest';
  bool _isMenuPremiumEnabled = false;
  int _nonPremiumTaskLimit = _defaultNonPremiumTaskLimit;
  bool _isSearchVisible = false;
  bool _isFilterVisible = false;
  String _searchQuery = '';
  final Set<String> _selectedStatusFilters = <String>{};
  final Set<String> _selectedPriorityFilters = <String>{};
  String _sortMode = 'fecha';
  bool _sortAscending = false;

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

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  String _icsDateTime(DateTime dateTime) {
    final utc = dateTime.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}'
        'T'
        '${utc.hour.toString().padLeft(2, '0')}'
        '${utc.minute.toString().padLeft(2, '0')}'
        '${utc.second.toString().padLeft(2, '0')}'
        'Z';
  }

  String _icsEscape(String text) => text
      .replaceAll('\\', '\\\\')
      .replaceAll('\n', '\\n')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;');

  String _calendarDescriptionForTask(TodoItem item) {
    final l10n = AppLocalizations.of(context)!;
    final description = (item.descripcion ?? '').trim();
    final prioridad = switch (item.prioridad.toUpperCase()) {
      'A' => l10n.todoPriorityHigh,
      'B' => l10n.todoPriorityLow,
      _ => l10n.todoPriorityMedium,
    };
    final estado =
        item.isResuelta ? l10n.todoStatusResolved : l10n.todoStatusPending;

    final lines = <String>[
      if (description.isNotEmpty) description,
      l10n.todoCalendarPriority(prioridad),
      l10n.todoCalendarStatus(estado),
    ];

    return lines.join('\n');
  }

  Future<void> _exportarTareaIcs(TodoItem item) async {
    final fecha = item.fechaTarea;
    if (fecha == null) {
      return;
    }

    final inicio = DateTime(fecha.year, fecha.month, fecha.day, 9);
    final fin = inicio.add(const Duration(hours: 1));
    final uid = 'tarea-${item.codigo}@nutrifit';
    final stamp = _icsDateTime(DateTime.now());
    final descripcion = _calendarDescriptionForTask(item);

    final ics = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//NutriFit//NutriFit App//ES')
      ..writeln('CALSCALE:GREGORIAN')
      ..writeln('METHOD:PUBLISH')
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:$uid')
      ..writeln('DTSTAMP:$stamp')
      ..writeln('DTSTART:${_icsDateTime(inicio)}')
      ..writeln('DTEND:${_icsDateTime(fin)}')
      ..writeln('SUMMARY:${_icsEscape(item.titulo)}')
      ..writeln('DESCRIPTION:${_icsEscape(descripcion)}')
      ..writeln('END:VEVENT')
      ..writeln('END:VCALENDAR');

    try {
      final dir = await getTemporaryDirectory();
      final fileName =
          'tarea_${item.codigo}_${DateFormat('yyyyMMdd').format(fecha)}.ics';
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(ics.toString(), encoding: utf8);
      final result = await OpenFilex.open(file.path, type: 'text/calendar');
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo abrir el fichero .ics (${result.message}). Guardado en: ${file.path}',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.todoExportError(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addTaskToDeviceCalendar(TodoItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final fecha = item.fechaTarea;
    if (fecha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.todoDateRequiredForCalendar),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isDesktop) {
      await _exportarTareaIcs(item);
      return;
    }

    final inicio = DateTime(fecha.year, fecha.month, fecha.day, 9);
    final fin = inicio.add(const Duration(hours: 1));
    final event = Event(
      title: item.titulo,
      description: _calendarDescriptionForTask(item),
      startDate: inicio,
      endDate: fin,
      allDay: false,
    );

    try {
      await Add2Calendar.addEvent2Cal(event);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.todoAddToCalendarError(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    _loadMenuPremiumConfig();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUiStateAndData() async {
    final authService = context.read<AuthService>();
    final prefs = await SharedPreferences.getInstance();
    final defaultView = prefs.getString(_viewPrefsKey) ?? 'list';
    final searchVisible = prefs.getBool(_todoSearchVisibleKey) ?? false;
    final filterVisible = prefs.getBool(_todoFilterVisibleKey) ?? false;
    final sortMode = prefs.getString(_todoSortModeKey) ?? 'fecha';
    final sortAscending = prefs.getBool(_todoSortAscendingKey) ?? false;
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
      _isSearchVisible = searchVisible;
      _isFilterVisible = filterVisible;
      _sortMode = sortMode;
      _sortAscending = sortAscending;
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

  bool get _canAccessFullTasks {
    final authService = context.read<AuthService>();
    if (!_isMenuPremiumEnabled) {
      return true;
    }
    return authService.isPremium ||
        MenuVisibilityPremiumService.isPrivilegedUserType(
          authService.userType,
        );
  }

  bool get _isPreviewMode => !_canAccessFullTasks;

  int get _effectiveNonPremiumTaskLimit {
    return _nonPremiumTaskLimit > 0
        ? _nonPremiumTaskLimit
        : _defaultNonPremiumTaskLimit;
  }

  Future<void> _loadMenuPremiumConfig() async {
    try {
      final apiService = context.read<ApiService>();
      final config = await MenuVisibilityPremiumService.loadConfig(
        apiService: apiService,
        forceRefresh: true,
      );
      final taskLimitRaw = await apiService.getParametroValor(
        'numero_tareas_no_premium',
      );
      final parsedTaskLimit = int.tryParse((taskLimitRaw ?? '').trim());
      final taskLimit = parsedTaskLimit != null && parsedTaskLimit > 0
          ? parsedTaskLimit
          : _defaultNonPremiumTaskLimit;
      final premiumEnabled = MenuVisibilityPremiumService.isPremium(
        config,
        MenuVisibilityPremiumService.tareas,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isMenuPremiumEnabled = premiumEnabled;
        _nonPremiumTaskLimit = taskLimit;
      });
      if (!context.read<AuthService>().isGuestMode) {
        await _loadItems();
      }
    } catch (_) {}
  }

  Future<void> _showTasksPremiumLimitMessage() {
    final limit = _effectiveNonPremiumTaskLimit;
    final l10n = AppLocalizations.of(context)!;
    return PremiumFeatureDialogHelper.show(
      context,
      message: l10n.todoPremiumLimitMessage(limit),
    );
  }

  String _priorityLabel(String value) {
    final l10n = AppLocalizations.of(context)!;
    switch (value.toUpperCase()) {
      case 'A':
        return l10n.todoPriorityHigh;
      case 'B':
        return l10n.todoPriorityLow;
      case 'M':
      default:
        return l10n.todoPriorityMedium;
    }
  }

  Color _priorityColor(BuildContext context, String value) {
    switch (value.toUpperCase()) {
      case 'A':
        return Colors.red.shade600;
      case 'B':
        return Colors.green.shade700;
      case 'M':
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _statusLabel(String value) {
    final l10n = AppLocalizations.of(context)!;
    return value.toUpperCase() == 'R'
        ? l10n.todoStatusResolved
        : l10n.todoStatusPending;
  }

  Color _statusColor(BuildContext context, String value) {
    return value.toUpperCase() == 'R'
        ? Colors.green.shade700
        : Theme.of(context).colorScheme.secondary;
  }

  String _nextPriorityValue(String current) {
    switch (current.toUpperCase()) {
      case 'B':
        return 'M';
      case 'M':
        return 'A';
      case 'A':
      default:
        return 'B';
    }
  }

  String _nextStatusValue(String current) {
    return current.toUpperCase() == 'R' ? 'P' : 'R';
  }

  Future<void> _saveToolbarState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_todoSearchVisibleKey, _isSearchVisible);
    await prefs.setBool(_todoFilterVisibleKey, _isFilterVisible);
    await prefs.setString(_todoSortModeKey, _sortMode);
    await prefs.setBool(_todoSortAscendingKey, _sortAscending);
  }

  void _toggleSearchVisibility() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
    _saveToolbarState();
  }

  void _toggleFilterVisibility() {
    setState(() {
      _isFilterVisible = !_isFilterVisible;
    });
    _saveToolbarState();
  }

  int get _activeFilterCount =>
      _selectedStatusFilters.length + _selectedPriorityFilters.length;

  bool _matchesTodoSearch(TodoItem item) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }

    return item.titulo.toLowerCase().contains(query) ||
        (item.descripcion ?? '').toLowerCase().contains(query);
  }

  bool _matchesTodoFilter(TodoItem item) {
    final statusMatches = _selectedStatusFilters.isEmpty ||
        _selectedStatusFilters.contains(item.estado.toUpperCase());
    final priorityMatches = _selectedPriorityFilters.isEmpty ||
        _selectedPriorityFilters.contains(item.prioridad.toUpperCase());
    return statusMatches && priorityMatches;
  }

  int _priorityWeight(String value) {
    switch (value.toUpperCase()) {
      case 'A':
        return 3;
      case 'M':
        return 2;
      case 'B':
      default:
        return 1;
    }
  }

  List<TodoItem> _applySearchFilterSort(List<TodoItem> source) {
    final items = source
        .where(_matchesTodoSearch)
        .where(_matchesTodoFilter)
        .toList(growable: false);

    final sorted = List<TodoItem>.from(items);
    sorted.sort((a, b) {
      switch (_sortMode) {
        case 'titulo':
          final titleCompare =
              a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
          if (titleCompare != 0) {
            return _sortAscending ? titleCompare : -titleCompare;
          }
          break;
        case 'prioridad':
          final priorityCompare = _priorityWeight(a.prioridad)
              .compareTo(_priorityWeight(b.prioridad));
          if (priorityCompare != 0) {
            return _sortAscending ? priorityCompare : -priorityCompare;
          }
          break;
        case 'fecha':
        default:
          final dateA = a.fechaTarea ?? a.fecham ?? a.fechaa ?? DateTime(1970);
          final dateB = b.fechaTarea ?? b.fecham ?? b.fechaa ?? DateTime(1970);
          final dateCompare = dateA.compareTo(dateB);
          if (dateCompare != 0) {
            return _sortAscending ? dateCompare : -dateCompare;
          }
          break;
      }

      return a.codigo.compareTo(b.codigo);
    });

    return sorted;
  }

  void _applySortSelection(String mode) {
    setState(() {
      if (_sortMode == mode) {
        _sortAscending = !_sortAscending;
      } else {
        _sortMode = mode;
        _sortAscending = mode == 'titulo';
      }
    });
    _saveToolbarState();
  }

  Future<void> _handleAppBarMenuAction(String action) async {
    switch (action) {
      case 'search':
        _toggleSearchVisibility();
        break;
      case 'filter':
        _toggleFilterVisibility();
        break;
      case 'refresh':
        await _loadItems();
        break;
      case 'sort_title':
        _applySortSelection('titulo');
        break;
      case 'sort_date':
        _applySortSelection('fecha');
        break;
      case 'sort_priority':
        _applySortSelection('prioridad');
        break;
    }
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
      final items = await _apiService.getTodoItems(
        estado: _isPreviewMode ? null : _estadoFiltroActual(),
      );

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
    return _applySearchFilterSort(_items)
        .where((item) =>
            item.fechaTarea != null && _sameDay(item.fechaTarea!, day))
        .toList();
  }

  void _toggleStatusFilter(String status) {
    setState(() {
      if (_selectedStatusFilters.contains(status)) {
        _selectedStatusFilters.remove(status);
      } else {
        _selectedStatusFilters.add(status);
      }
    });
  }

  void _togglePriorityFilter(String priority) {
    setState(() {
      if (_selectedPriorityFilters.contains(priority)) {
        _selectedPriorityFilters.remove(priority);
      } else {
        _selectedPriorityFilters.add(priority);
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedStatusFilters.clear();
      _selectedPriorityFilters.clear();
    });
  }

  Widget _buildFilterCountBadge({
    required int count,
    double minSize = 18,
    double fontSize = 10,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
  }) {
    return Container(
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
      padding: padding,
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMenuLeadingIcon(IconData icon, {int? badgeCount}) {
    if (badgeCount == null || badgeCount <= 0) {
      return Icon(icon, size: 18);
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        const SizedBox(width: 18, height: 18),
        Icon(icon, size: 18),
        Positioned(
          right: -2,
          top: -2,
          child: _buildFilterCountBadge(
            count: badgeCount,
            minSize: 14,
            fontSize: 8,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem({
    required String value,
    required IconData icon,
    required String label,
    bool checked = false,
    bool? ascending,
    int? badgeCount,
  }) {
    Widget trailing = const SizedBox.shrink();
    if (checked) {
      trailing = Icon(
        ascending == true ? Icons.arrow_upward : Icons.arrow_downward,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      );
    }

    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          _buildMenuLeadingIcon(icon, badgeCount: badgeCount),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          trailing,
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    final l10n = AppLocalizations.of(context)!;
    if (!_isSearchVisible) {
      return const SizedBox.shrink();
    }

    if (_searchController.text != _searchQuery) {
      _searchController.value = TextEditingValue(
        text: _searchQuery,
        selection: TextSelection.collapsed(offset: _searchQuery.length),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              prefixIcon: IconButton(
                tooltip: _searchQuery.isEmpty
                    ? l10n.commonSearch
                    : l10n.todoClearSearch,
                icon: Icon(
                  _searchQuery.isEmpty ? Icons.search : Icons.clear,
                ),
                onPressed: _searchQuery.isEmpty
                    ? null
                    : () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
              ),
              hintText: l10n.todoSearchHint,
              border: InputBorder.none,
              suffixIcon: IconButton(
                tooltip: l10n.commonHideSearch,
                onPressed: _toggleSearchVisibility,
                icon: const Icon(Icons.visibility_off_outlined),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    final l10n = AppLocalizations.of(context)!;
    if (!_isFilterVisible) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l10n.commonFilter,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  if (_activeFilterCount > 0)
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off, size: 18),
                      label: Text(l10n.commonClear),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.todoStatusTitle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: Text(l10n.todoStatusPending),
                    selected: _selectedStatusFilters.contains('P'),
                    onSelected: (_) => _toggleStatusFilter('P'),
                  ),
                  FilterChip(
                    label: Text(l10n.todoStatusResolved),
                    selected: _selectedStatusFilters.contains('R'),
                    onSelected: (_) => _toggleStatusFilter('R'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.todoPriorityTitle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: Text(l10n.todoPriorityHigh),
                    selected: _selectedPriorityFilters.contains('A'),
                    onSelected: (_) => _togglePriorityFilter('A'),
                  ),
                  FilterChip(
                    label: Text(l10n.todoPriorityMedium),
                    selected: _selectedPriorityFilters.contains('M'),
                    onSelected: (_) => _togglePriorityFilter('M'),
                  ),
                  FilterChip(
                    label: Text(l10n.todoPriorityLow),
                    selected: _selectedPriorityFilters.contains('B'),
                    onSelected: (_) => _togglePriorityFilter('B'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentWithToolbar(Widget child) {
    return Column(
      children: [
        _buildSearchPanel(),
        _buildFilterPanel(),
        Expanded(child: child),
      ],
    );
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
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.todoDeleteTitle),
        content: Text(l10n.todoDeleteConfirm(item.titulo)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.commonDelete,
              style: const TextStyle(color: Colors.red),
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
        SnackBar(
          content: Text(l10n.todoDeletedSuccess),
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

  Widget _buildTaskDescription(String description) {
    final textStyle = TextStyle(
      fontSize: 12,
      color: Colors.grey.shade700,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth <= 0) {
          return Text(description, style: textStyle, maxLines: 3);
        }

        final painter = TextPainter(
          text: TextSpan(text: description, style: textStyle),
          textDirection: Directionality.of(context),
          maxLines: 3,
        )..layout(maxWidth: maxWidth);

        if (!painter.didExceedMaxLines) {
          return Text(
            description,
            maxLines: 3,
            style: textStyle,
          );
        }

        var low = 0;
        var high = description.length;
        var best = '...';

        while (low <= high) {
          final mid = (low + high) ~/ 2;
          final candidate = '${description.substring(0, mid).trimRight()}...';
          painter
            ..text = TextSpan(text: candidate, style: textStyle)
            ..layout(maxWidth: maxWidth);

          if (painter.didExceedMaxLines) {
            high = mid - 1;
          } else {
            best = candidate;
            low = mid + 1;
          }
        }

        return Text(
          best,
          maxLines: 3,
          overflow: TextOverflow.clip,
          style: textStyle,
        );
      },
    );
  }

  Widget _buildTaskTile(TodoItem item, {bool showStatusTag = true}) {
    final l10n = AppLocalizations.of(context)!;
    final dateLabel = item.fechaTarea == null
        ? l10n.todoNoDate
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
        ? l10n.todoPriorityHighTooltip
        : prioridadBaja
            ? l10n.todoPriorityLowTooltip
            : l10n.todoPriorityMediumTooltip;

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
              _buildTaskDescription(description),
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
                    message: item.isResuelta
                        ? l10n.todoStatusResolvedShort
                        : l10n.todoStatusPendingShort,
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
                        ? l10n.todoMarkPending
                        : l10n.todoMarkResolved,
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
                    border: Border.all(color: Colors.teal.shade200),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: IconButton(
                    onPressed: item.fechaTarea == null
                        ? null
                        : () => _addTaskToDeviceCalendar(item),
                    tooltip: l10n.todoAddToDeviceCalendar,
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    icon: const Icon(
                      Icons.event_available_outlined,
                      color: Colors.teal,
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
                    tooltip: l10n.todoEditAction,
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
                    tooltip: l10n.commonDelete,
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

    if (!isEditing && _isPreviewMode) {
      final allItems = await _apiService.getTodoItems();
      if (allItems.length >= _effectiveNonPremiumTaskLimit) {
        if (!mounted) {
          return;
        }
        await _showTasksPremiumLimitMessage();
        return;
      }
    }

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
    final prefs = await SharedPreferences.getInstance();
    var priorityExpanded =
        prefs.getBool(_todoDialogPriorityExpandedKey) ?? true;
    var statusExpanded = prefs.getBool(_todoDialogStatusExpandedKey) ?? true;
    var descriptionExpanded =
        prefs.getBool(_todoDialogDescriptionExpandedKey) ?? true;

    if (!mounted) {
      return;
    }

    final save = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> setExpandedState(String key, bool value) async {
              await prefs.setBool(key, value);
            }

            final fechaTexto = fechaTarea == null
                ? l10n.todoNoDate
                : DateFormat('dd/MM/yyyy').format(fechaTarea!);
            final prioridadTexto = _priorityLabel(prioridad);
            final prioridadChipColor = _priorityColor(context, prioridad);
            final estadoTexto = _statusLabel(estado);
            final estadoChipColor = _statusColor(context, estado);

            Widget buildSummaryChip(
              String text,
              Color color, {
              VoidCallback? onTap,
            }) {
              final chip = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              );

              if (onTap == null) {
                return chip;
              }

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onTap,
                  child: chip,
                ),
              );
            }

            Widget buildExpandableCard({
              required String title,
              required bool expanded,
              required VoidCallback onToggle,
              required Widget child,
              Widget? summary,
              Widget? titleSuffix,
              List<Widget> headerActions = const [],
            }) {
              return Card(
                margin: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(8)),
                              onTap: onToggle,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (titleSuffix != null) ...[
                                      const SizedBox(width: 6),
                                      titleSuffix,
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          ...headerActions,
                          if (summary != null) ...[
                            const SizedBox(width: 8),
                            summary,
                          ],
                          IconButton(
                            onPressed: onToggle,
                            tooltip: expanded ? 'Plegar' : 'Desplegar',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              expanded ? Icons.expand_less : Icons.expand_more,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (expanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: child,
                      ),
                  ],
                ),
              );
            }

            final descriptionLength = descriptionController.text.trim().length;
            final descriptionIndicatorColor = descriptionLength > 0
                ? Colors.green.shade700
                : Colors.grey.shade500;
            final descriptionIndicator = Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: descriptionIndicatorColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: descriptionIndicatorColor.withValues(alpha: 0.35),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Text(
                    '$descriptionLength',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: descriptionIndicatorColor,
                    ),
                  ),
                ),
              ),
            );

            Widget buildDateCard() {
              return Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fechaTexto,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: fechaTarea == null
                                        ? null
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
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
                        tooltip: l10n.todoSelectDate,
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        icon: const Icon(Icons.calendar_month),
                      ),
                      IconButton(
                        onPressed: fechaTarea == null
                            ? null
                            : () {
                                setDialogState(() {
                                  fechaTarea = null;
                                });
                              },
                        tooltip: l10n.todoRemoveDate,
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        icon: const Icon(Icons.clear),
                      ),
                    ],
                  ),
                ),
              );
            }

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 10, 0),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing
                          ? l10n.todoEditTaskTitle
                          : l10n.todoNewTaskTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context, false),
                    tooltip: l10n.commonCancel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
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
                          decoration: InputDecoration(
                            labelText: l10n.todoTitleLabel,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return l10n.todoTitleRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        buildExpandableCard(
                          title: l10n.todoDescriptionTitle,
                          titleSuffix: descriptionIndicator,
                          expanded: descriptionExpanded,
                          onToggle: () {
                            setDialogState(() {
                              descriptionExpanded = !descriptionExpanded;
                            });
                            setExpandedState(
                              _todoDialogDescriptionExpandedKey,
                              descriptionExpanded,
                            );
                          },
                          child: TextFormField(
                            controller: descriptionController,
                            maxLines: 4,
                            onChanged: (_) => setDialogState(() {}),
                            decoration: InputDecoration(
                              labelText: l10n.todoDescriptionOptionalLabel,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        buildExpandableCard(
                          title: l10n.todoPriorityTitle,
                          expanded: priorityExpanded,
                          onToggle: () {
                            setDialogState(() {
                              priorityExpanded = !priorityExpanded;
                            });
                            setExpandedState(
                              _todoDialogPriorityExpandedKey,
                              priorityExpanded,
                            );
                          },
                          summary: buildSummaryChip(
                            prioridadTexto,
                            prioridadChipColor,
                            onTap: () {
                              setDialogState(() {
                                prioridad = _nextPriorityValue(prioridad);
                              });
                            },
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: Text(l10n.todoPriorityHigh),
                                selected: prioridad == 'A',
                                onSelected: (_) {
                                  setDialogState(() {
                                    prioridad = 'A';
                                  });
                                },
                              ),
                              ChoiceChip(
                                label: Text(l10n.todoPriorityMedium),
                                selected: prioridad == 'M',
                                onSelected: (_) {
                                  setDialogState(() {
                                    prioridad = 'M';
                                  });
                                },
                              ),
                              ChoiceChip(
                                label: Text(l10n.todoPriorityLow),
                                selected: prioridad == 'B',
                                onSelected: (_) {
                                  setDialogState(() {
                                    prioridad = 'B';
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        buildExpandableCard(
                          title: l10n.todoStatusTitle,
                          expanded: statusExpanded,
                          onToggle: () {
                            setDialogState(() {
                              statusExpanded = !statusExpanded;
                            });
                            setExpandedState(
                              _todoDialogStatusExpandedKey,
                              statusExpanded,
                            );
                          },
                          summary: buildSummaryChip(
                            estadoTexto,
                            estadoChipColor,
                            onTap: () {
                              setDialogState(() {
                                estado = _nextStatusValue(estado);
                              });
                            },
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: Text(l10n.todoStatusPending),
                                selected: estado == 'P',
                                onSelected: (_) {
                                  setDialogState(() {
                                    estado = 'P';
                                  });
                                },
                              ),
                              ChoiceChip(
                                label: Text(l10n.todoStatusResolved),
                                selected: estado == 'R',
                                onSelected: (_) {
                                  setDialogState(() {
                                    estado = 'R';
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        buildDateCard(),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                ElevatedButton.icon(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  icon: const Icon(Icons.save),
                  label: Text(l10n.commonSave),
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
                  Text(
                    l10n.todoGuestTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.todoGuestBody,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    icon: const Icon(Icons.app_registration),
                    label: Text(l10n.navStartRegistration),
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
                label: Text(l10n.todoNewShort),
              ),
            ],
          ),
        ),
        Expanded(
          child: selectedItems.isEmpty
              ? Center(
                  child: Text(l10n.todoNoTasksSelectedDay),
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
    final visibleItems = _applySearchFilterSort(_items);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (visibleItems.isEmpty) {
      return Center(child: Text(l10n.todoNoTasksToShow));
    }

    final showStatusTag = _tabController.index == 2;

    return ListView.builder(
      itemCount: visibleItems.length,
      itemBuilder: (context, index) =>
          _buildTaskTile(visibleItems[index], showStatusTag: showStatusTag),
    );
  }

  List<TodoItem> _buildPreviewItems() {
    final preview = _applySearchFilterSort(_items);
    return preview.take(_effectiveNonPremiumTaskLimit).toList(growable: false);
  }

  Widget _buildPreviewContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final previewItems = _buildPreviewItems();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemCount: previewItems.length + 1,
      itemBuilder: (context, index) {
        if (index == previewItems.length) {
          final limit = _effectiveNonPremiumTaskLimit;
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: PremiumUpsellCard(
              title: l10n.todoPremiumTitle,
              subtitle: l10n.todoPremiumPreviewSubtitle(limit),
              subtitleHighlight: _items.length > limit
                  ? l10n.todoPremiumPreviewHighlight(_items.length)
                  : null,
              subtitleHighlightColor: Colors.pink.shade700,
              onPressed: () => Navigator.pushNamed(context, '/premium_info'),
            ),
          );
        }

        if (previewItems.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Center(
              child: Text(
                'Todavía no tienes tareas registradas.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          );
        }

        return _buildTaskTile(previewItems[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isGuest = authService.isGuestMode;
    final isPreviewMode = _isPreviewMode;

    final body = isGuest
        ? _buildGuestContent()
        : isPreviewMode
            ? _buildPreviewContent()
            : _isCalendarView
                ? _buildCalendarView()
                : _buildListContent();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.todoScreenTitle),
        bottom: isGuest || isPreviewMode
            ? null
            : TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: l10n.todoTabPending),
                  Tab(text: l10n.todoTabResolved),
                  Tab(text: l10n.todoTabAll),
                ],
              ),
        actions: [
          if (!isGuest)
            IconButton(
              tooltip:
                  _isSearchVisible ? l10n.commonHideSearch : l10n.commonSearch,
              onPressed: _toggleSearchVisibility,
              icon: Icon(
                _isSearchVisible ? Icons.search_off : Icons.search,
              ),
            ),
          if (!isGuest)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: _isFilterVisible
                      ? l10n.todoHideFilters
                      : l10n.commonFilter,
                  onPressed: _toggleFilterVisibility,
                  icon: const Icon(Icons.filter_alt),
                ),
                if (_activeFilterCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: _buildFilterCountBadge(
                      count: _activeFilterCount,
                    ),
                  ),
              ],
            ),
          if (!isGuest && !isPreviewMode)
            IconButton(
              tooltip:
                  _isCalendarView ? l10n.todoViewList : l10n.todoViewCalendar,
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
          if (!isGuest)
            PopupMenuButton<String>(
              tooltip: l10n.commonMoreOptions,
              onSelected: (value) => _handleAppBarMenuAction(value),
              itemBuilder: (context) => [
                _buildMenuItem(
                  value: 'search',
                  icon: _isSearchVisible ? Icons.search_off : Icons.search,
                  label: l10n.commonSearch,
                ),
                _buildMenuItem(
                  value: 'filter',
                  icon: Icons.filter_alt,
                  label: l10n.commonFilter,
                  badgeCount: _activeFilterCount,
                ),
                _buildMenuItem(
                  value: 'refresh',
                  icon: Icons.refresh,
                  label: l10n.commonRefresh,
                ),
                const PopupMenuDivider(),
                _buildMenuItem(
                  value: 'sort_title',
                  icon: Icons.sort_by_alpha,
                  label: l10n.commonSortByTitle,
                  checked: _sortMode == 'titulo',
                  ascending: _sortAscending,
                ),
                _buildMenuItem(
                  value: 'sort_date',
                  icon: Icons.event,
                  label: l10n.todoSortByDate,
                  checked: _sortMode == 'fecha',
                  ascending: _sortAscending,
                ),
                _buildMenuItem(
                  value: 'sort_priority',
                  icon: Icons.flag_outlined,
                  label: l10n.todoSortByPriority,
                  checked: _sortMode == 'prioridad',
                  ascending: _sortAscending,
                ),
              ],
            ),
        ],
      ),
      body: isGuest ? body : _buildContentWithToolbar(body),
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
