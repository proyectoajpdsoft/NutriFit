import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/entrevista_fit.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EntrevistaFitEditScreen extends StatefulWidget {
  final EntrevistaFit? entrevista;
  final Paciente? paciente;

  const EntrevistaFitEditScreen({super.key, this.entrevista, this.paciente});

  @override
  State<EntrevistaFitEditScreen> createState() =>
      _EntrevistaFitEditScreenState();
}

class _EntrevistaFitEditScreenState extends State<EntrevistaFitEditScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  bool get _isEditing => widget.entrevista != null;
  final Map<String, GlobalKey> _fieldKeys = {};
  final Map<String, FocusNode> _fieldFocusNodes = {};

  // Controladores para campos de texto
  final Map<String, TextEditingController> _controllers = {};

  // Fechas y switches
  DateTime? _fechaPrevista;
  DateTime? _fechaRealizacion;
  bool _completada = false;
  bool _online = false;
  bool _hasChanges = false;
  bool _cardStateReady = false;

  // Switches de encuesta
  bool _enfermedadCorazon = false;
  bool _notaDolorPracticaActividad = false;
  bool _notaDolorReposo = false;
  bool _perdidaEquilibrio = false;
  bool _problemaHuesosArticulaciones = false;
  bool _prescipcionMedicacionArterial = false;
  bool _razonImpedimentoEjercicio = false;

  late ApiService _apiService = ApiService();
  late Future<List<Paciente>> _pacientesFuture;
  final Map<String, bool> _cardExpanded = {
    'paciente': false,
    'datos_entrevista': true,
    'acerca_consulta': false,
    'encuesta': false,
    'historial_actividad': false,
    'profesion_habitos': false,
    'preguntas_futuro': false,
    'observacion': false,
  };
  int? _selectedPacienteId;
  String _selectedPacienteNombre = '';

  static const String _cardStateStorageKey =
      'entrevista_fit_edit_card_expanded_state';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apiService = ApiService();
    _pacientesFuture = _apiService.getPacientes();
    _selectedPacienteId =
        widget.paciente?.codigo ?? widget.entrevista?.codigoPaciente;
    _selectedPacienteNombre =
        (widget.paciente?.nombre ?? widget.entrevista?.nombrePaciente ?? '')
            .trim();
    _initializeControllers();

    if (_isEditing) {
      final e = widget.entrevista!;
      _fechaPrevista = e.fechaPrevista;
      _fechaRealizacion = e.fechaRealizacion;
      _completada = e.completada == 'S';
      _online = e.online == 'S';
      _enfermedadCorazon = e.enfermedadCorazon == 'S';
      _notaDolorPracticaActividad = e.notaDolorPracticaActividad == 'S';
      _notaDolorReposo = e.notaDolorReposo == 'S';
      _perdidaEquilibrio = e.perdidaEquilibrio == 'S';
      _problemaHuesosArticulaciones = e.problemaHuesosArticulaciones == 'S';
      _prescipcionMedicacionArterial = e.prescipcionMedicacionArterial == 'S';
      _razonImpedimentoEjercicio = e.razonImpedimentoEjercicio == 'S';
    } else {
      _fechaPrevista = DateTime.now();
    }

    _loadCardExpandedState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveCardExpandedState();
    }
  }

  Future<void> _loadCardExpandedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cardStateStorageKey);
    final nextState = Map<String, bool>.from(_cardExpanded);

    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final savedState = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        for (final entry in savedState.entries) {
          if (nextState.containsKey(entry.key) && entry.value is bool) {
            nextState[entry.key] = entry.value as bool;
          }
        }
      } catch (_) {
        await prefs.remove(_cardStateStorageKey);
      }
    }

    if (!mounted) return;

    setState(() {
      _cardExpanded
        ..clear()
        ..addAll(nextState);
      _cardStateReady = true;
    });
  }

  Future<void> _saveCardExpandedState() async {
    if (!_cardStateReady) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cardStateStorageKey,
      jsonEncode(_cardExpanded),
    );
  }

  void _updateCardExpandedState(String cardKey, bool expanded) {
    if (_cardExpanded[cardKey] == expanded) return;
    setState(() => _cardExpanded[cardKey] = expanded);
    _saveCardExpandedState();
  }

  void _expandCard(String cardKey) {
    _updateCardExpandedState(cardKey, true);
  }

  void _initializeControllers() {
    final e = widget.entrevista;
    _controllers['motivo'] = TextEditingController(text: e?.motivo ?? '');
    _controllers['objetivos'] = TextEditingController(text: e?.objetivos ?? '');
    _controllers['historial_deportivo'] =
        TextEditingController(text: e?.historialDeportivo ?? '');
    _controllers['actividad_diaria'] =
        TextEditingController(text: e?.actividadDiaria ?? '');
    _controllers['profesion'] = TextEditingController(text: e?.profesion ?? '');
    _controllers['disponibilidad_horaria'] =
        TextEditingController(text: e?.disponibilidadHoraria ?? '');
    _controllers['disponibilidad_instalaciones'] =
        TextEditingController(text: e?.disponibilidadInstalaciones ?? '');
    _controllers['habitos_alimentarios'] =
        TextEditingController(text: e?.habitosAlimentarios ?? '');
    _controllers['futuro_seguir_ritmo'] =
        TextEditingController(text: e?.futuroSeguirRitmo ?? '');
    _controllers['futuro_logros_proximas_semanas'] =
        TextEditingController(text: e?.futuroLogrosProximasSemanas ?? '');
    _controllers['futuro_probar_nuevos_ejercicios'] =
        TextEditingController(text: e?.futuroProbarNuevosEjercicios ?? '');
    _controllers['observacion'] =
        TextEditingController(text: e?.observacion ?? '');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveCardExpandedState();
    _controllers.forEach((_, controller) => controller.dispose());
    _fieldFocusNodes.forEach((_, focusNode) => focusNode.dispose());
    super.dispose();
  }

  GlobalKey _getFieldKey(String key) {
    return _fieldKeys.putIfAbsent(key, () => GlobalKey());
  }

  FocusNode _getFieldFocusNode(String key) {
    return _fieldFocusNodes.putIfAbsent(key, () => FocusNode());
  }

  void _submitForm() {
    _saveForm(closeOnSuccess: true);
  }

  Future<bool> _saveForm({required bool closeOnSuccess}) async {
    if (_formKey.currentState!.validate()) {
      if (_selectedPacienteId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes seleccionar un paciente'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }

      final entrevistaData = EntrevistaFit(
        codigo: widget.entrevista?.codigo ?? 0,
        codigoPaciente: _selectedPacienteId!,
        fechaPrevista: _fechaPrevista,
        fechaRealizacion: _fechaRealizacion,
        completada: _completada ? 'S' : 'N',
        online: _online ? 'S' : 'N',
        motivo: _controllers['motivo']!.text,
        objetivos: _controllers['objetivos']!.text,
        enfermedadCorazon: _enfermedadCorazon ? 'S' : 'N',
        notaDolorPracticaActividad: _notaDolorPracticaActividad ? 'S' : 'N',
        notaDolorReposo: _notaDolorReposo ? 'S' : 'N',
        perdidaEquilibrio: _perdidaEquilibrio ? 'S' : 'N',
        problemaHuesosArticulaciones: _problemaHuesosArticulaciones ? 'S' : 'N',
        prescipcionMedicacionArterial:
            _prescipcionMedicacionArterial ? 'S' : 'N',
        razonImpedimentoEjercicio: _razonImpedimentoEjercicio ? 'S' : 'N',
        historialDeportivo: _controllers['historial_deportivo']!.text,
        actividadDiaria: _controllers['actividad_diaria']!.text,
        profesion: _controllers['profesion']!.text,
        disponibilidadHoraria: _controllers['disponibilidad_horaria']!.text,
        disponibilidadInstalaciones:
            _controllers['disponibilidad_instalaciones']!.text,
        habitosAlimentarios: _controllers['habitos_alimentarios']!.text,
        futuroSeguirRitmo: _controllers['futuro_seguir_ritmo']!.text,
        futuroLogrosProximasSemanas:
            _controllers['futuro_logros_proximas_semanas']!.text,
        futuroProbarNuevosEjercicios:
            _controllers['futuro_probar_nuevos_ejercicios']!.text,
        observacion: _controllers['observacion']!.text,
      );

      try {
        bool success;
        if (widget.entrevista != null) {
          success = await _apiService.updateEntrevistaFit(entrevistaData);
        } else {
          success = await _apiService.createEntrevistaFit(entrevistaData);
        }

        if (success) {
          _hasChanges = false;
          // Mostrar mensaje según sea alta o modificación
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.entrevista == null
                  ? 'Entrevista añadida correctamente'
                  : 'Entrevista modificada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          if (closeOnSuccess && mounted) {
            Navigator.of(context).pop(true);
          }
          return true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Error al guardar'), backgroundColor: Colors.red));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    return false;
  }

  void _markDirty() {
    if (_hasChanges) {
      setState(() {});
      return;
    }
    setState(() {
      _hasChanges = true;
    });
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasChanges) return true;
    return showUnsavedChangesDialog(
      context,
      onSave: () => _saveForm(closeOnSuccess: false),
    );
  }

  Future<void> _handleBack() async {
    if (await _confirmDiscardChanges()) {
      await _saveCardExpandedState();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _focusFieldFromTag(String cardKey, String fieldKey) async {
    final wasCollapsed = !(_cardExpanded[cardKey] ?? false);

    if (wasCollapsed) {
      _expandCard(cardKey);
    }

    await Future<void>.delayed(
      Duration(milliseconds: wasCollapsed ? 280 : 40),
    );

    if (!mounted) return;

    final fieldContext = _getFieldKey(fieldKey).currentContext;
    if (fieldContext != null) {
      await Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        alignment: 0.12,
      );
    }

    if (!mounted) return;
    _getFieldFocusNode(fieldKey).requestFocus();
  }

  Widget _buildExpandableCard({
    required String title,
    required String cardKey,
    String? subtitle,
    Widget? subtitleWidget,
    required Widget child,
    List<Widget> titleBadges = const [],
    List<Widget> titleActions = const [],
  }) {
    final effectiveInitiallyExpanded = _cardExpanded[cardKey] ?? false;
    return Card(
      child: ExpansionTile(
        key: PageStorageKey('entrevista_fit_edit_card_$cardKey'),
        initiallyExpanded: effectiveInitiallyExpanded,
        maintainState: true,
        onExpansionChanged: (expanded) =>
            _updateCardExpandedState(cardKey, expanded),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (titleBadges.isNotEmpty) const SizedBox(width: 6),
                ...titleBadges,
              ],
            ),
            if (subtitleWidget != null)
              subtitleWidget
            else if ((subtitle ?? '').trim().isNotEmpty)
              Text(
                subtitle!.trim(),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...titleActions,
            const SizedBox(width: 4),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: child,
          ),
        ],
      ),
    );
  }

  void _toggleDatosEntrevistaOnline() {
    setState(() => _online = !_online);
    _markDirty();
  }

  void _toggleDatosEntrevistaCompletada() {
    setState(() => _completada = !_completada);
    _markDirty();
  }

  Widget _buildEstadoTag(String label, bool activo, {VoidCallback? onTap}) {
    final color = activo ? Colors.green : Colors.grey;
    final tag = Container(
      width: 24,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    if (onTap == null) return tag;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: tag,
      ),
    );
  }

  Widget _buildCountCircleBadge(int count) {
    final color = count > 0 ? Colors.green : Colors.grey;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildFieldCountTag(
    String label,
    String key, {
    VoidCallback? onTap,
  }) {
    final count = _controllers[key]?.text.trim().length ?? 0;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          _buildCountCircleBadge(count),
        ],
      ),
    );

    if (onTap == null) return chip;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: chip,
      ),
    );
  }

  Widget _buildAcercaConsultaSubtitle() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildFieldCountTag(
          'Mot.',
          'motivo',
          onTap: () => _focusFieldFromTag('acerca_consulta', 'motivo'),
        ),
        _buildFieldCountTag(
          'Obj.',
          'objetivos',
          onTap: () => _focusFieldFromTag('acerca_consulta', 'objetivos'),
        ),
      ],
    );
  }

  Widget _buildHistorialActividadSubtitle() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildFieldCountTag(
          'Dep.',
          'historial_deportivo',
          onTap: () =>
              _focusFieldFromTag('historial_actividad', 'historial_deportivo'),
        ),
        _buildFieldCountTag(
          'Act.',
          'actividad_diaria',
          onTap: () =>
              _focusFieldFromTag('historial_actividad', 'actividad_diaria'),
        ),
      ],
    );
  }

  Widget _buildProfesionHabitosSubtitle() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildFieldCountTag(
          'Prof.',
          'profesion',
          onTap: () => _focusFieldFromTag('profesion_habitos', 'profesion'),
        ),
        _buildFieldCountTag(
          'Hor.',
          'disponibilidad_horaria',
          onTap: () => _focusFieldFromTag(
            'profesion_habitos',
            'disponibilidad_horaria',
          ),
        ),
        _buildFieldCountTag(
          'Ins.',
          'disponibilidad_instalaciones',
          onTap: () => _focusFieldFromTag(
            'profesion_habitos',
            'disponibilidad_instalaciones',
          ),
        ),
        _buildFieldCountTag(
          'Háb.',
          'habitos_alimentarios',
          onTap: () => _focusFieldFromTag(
            'profesion_habitos',
            'habitos_alimentarios',
          ),
        ),
      ],
    );
  }

  Widget _buildPreguntasFuturoSubtitle() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildFieldCountTag(
          'Rit.',
          'futuro_seguir_ritmo',
          onTap: () =>
              _focusFieldFromTag('preguntas_futuro', 'futuro_seguir_ritmo'),
        ),
        _buildFieldCountTag(
          'Próx.',
          'futuro_logros_proximas_semanas',
          onTap: () => _focusFieldFromTag(
            'preguntas_futuro',
            'futuro_logros_proximas_semanas',
          ),
        ),
        _buildFieldCountTag(
          'Mot.',
          'futuro_probar_nuevos_ejercicios',
          onTap: () => _focusFieldFromTag(
            'preguntas_futuro',
            'futuro_probar_nuevos_ejercicios',
          ),
        ),
      ],
    );
  }

  String _formatResumenFecha(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Widget _buildDatosEntrevistaSubtitle() {
    final prev = _formatResumenFecha(_fechaPrevista);
    final real = _formatResumenFecha(_fechaRealizacion);

    final items = <Widget>[];
    if (prev.isNotEmpty) {
      items.add(
        Text(
          'Prev: $prev',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      );
    }
    if (real.isNotEmpty) {
      if (items.isNotEmpty) {
        items.add(Text('  ·  ', style: TextStyle(color: Colors.grey.shade600)));
      }
      items.add(
        Text(
          'Real: $real',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      );
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items,
    );
  }

  Widget _buildDatosEntrevistaCard() {
    return _buildExpandableCard(
      title: 'Datos entrevista',
      cardKey: 'datos_entrevista',
      subtitleWidget: _buildDatosEntrevistaSubtitle(),
      titleActions: [
        _buildEstadoTag('O', _online, onTap: _toggleDatosEntrevistaOnline),
        const SizedBox(width: 6),
        _buildEstadoTag(
          'C',
          _completada,
          onTap: _toggleDatosEntrevistaCompletada,
        ),
      ],
      child: Column(
        children: [
          _buildDateTimePicker(
            label: 'Fecha prevista',
            date: _fechaPrevista,
            onChanged: (newDate) {
              setState(() => _fechaPrevista = newDate);
              _markDirty();
            },
          ),
          _buildDateTimePicker(
            label: 'Fecha realización',
            date: _fechaRealizacion,
            onChanged: (newDate) {
              setState(() => _fechaRealizacion = newDate);
              _markDirty();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Completada'),
            value: _completada,
            onChanged: (value) {
              setState(() => _completada = value);
              _markDirty();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Online'),
            value: _online,
            onChanged: (value) {
              setState(() => _online = value);
              _markDirty();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showPacienteSelectorDialog(List<Paciente> pacientes) async {
    int? tempSelected = _selectedPacienteId;
    final searchController = TextEditingController();

    final selected = await showDialog<int?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final query = searchController.text.trim().toLowerCase();
          final filtered = pacientes.where((p) {
            if (query.isEmpty) return true;
            return p.nombre.toLowerCase().contains(query);
          }).toList();

          return AlertDialog(
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Seleccionar paciente',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(dialogContext),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar paciente...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setStateDialog(() {}),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 380),
                    child: filtered.isEmpty
                        ? const Center(child: Text('Sin resultados'))
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final paciente = filtered[index];
                              return ListTile(
                                dense: true,
                                onTap: () => setStateDialog(
                                  () => tempSelected = paciente.codigo,
                                ),
                                leading: Radio<int>(
                                  value: paciente.codigo,
                                  groupValue: tempSelected,
                                  onChanged: (value) => setStateDialog(
                                    () => tempSelected = value,
                                  ),
                                ),
                                title: Text(paciente.nombre),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, tempSelected),
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );

    if (!mounted || selected == null) return;
    final pacienteSeleccionado =
        pacientes.where((p) => p.codigo == selected).firstOrNull;
    setState(() {
      _selectedPacienteId = selected;
      _selectedPacienteNombre = pacienteSeleccionado?.nombre ?? '';
      _hasChanges = true;
    });
  }

  Widget _buildPacienteCard() {
    return FutureBuilder<List<Paciente>>(
      future: _pacientesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Error al cargar pacientes: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No hay pacientes disponibles.');
        }

        final pacientes = snapshot.data!;
        Paciente? selectedPaciente;
        for (final paciente in pacientes) {
          if (paciente.codigo == _selectedPacienteId) {
            selectedPaciente = paciente;
            break;
          }
        }
        final selectedName =
            selectedPaciente?.nombre ?? _selectedPacienteNombre;

        return _buildExpandableCard(
          title: 'Paciente',
          cardKey: 'paciente',
          subtitle: selectedName,
          titleActions: [
            IconButton(
              tooltip: 'Seleccionar paciente',
              icon: const Icon(Icons.person_search),
              visualDensity: VisualDensity.compact,
              onPressed: () => _showPacienteSelectorDialog(pacientes),
            ),
          ],
          child: _buildPacienteTags(selectedPaciente),
        );
      },
    );
  }

  int? _calcularEdadPaciente(Paciente paciente) {
    if (paciente.edad != null && paciente.edad! > 0) return paciente.edad;
    final nacimiento = paciente.fechaNacimiento;
    if (nacimiento == null) return null;
    final hoy = DateTime.now();
    var edad = hoy.year - nacimiento.year;
    final noCumplido = (hoy.month < nacimiento.month) ||
        (hoy.month == nacimiento.month && hoy.day < nacimiento.day);
    if (noCumplido) edad--;
    return edad >= 0 ? edad : null;
  }

  double? _calcularImcPaciente(Paciente paciente) {
    final peso = paciente.peso;
    final alturaCm = paciente.altura;
    if (peso == null || peso <= 0 || alturaCm == null || alturaCm <= 0) {
      return null;
    }
    final alturaM = alturaCm / 100.0;
    return peso / (alturaM * alturaM);
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 16.0) return 'Infrapeso: Delgadez Severa';
    if (bmi < 17.0) return 'Infrapeso: Delgadez moderada';
    if (bmi < 18.5) return 'Infrapeso: Delgadez aceptable';
    if (bmi < 25.0) return 'Peso Normal';
    if (bmi < 30.0) return 'Sobrepeso';
    if (bmi < 35.0) return 'Obeso: Tipo I';
    if (bmi < 40.0) return 'Obeso: Tipo II';
    return 'Obeso: Tipo III';
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 16.0) return Colors.red.shade800;
    if (bmi < 17.0) return Colors.deepOrange;
    if (bmi < 18.5) return Colors.orange;
    if (bmi < 25.0) return Colors.green;
    if (bmi < 30.0) return Colors.lime.shade700;
    if (bmi < 35.0) return Colors.deepOrange;
    if (bmi < 40.0) return Colors.red;
    return Colors.red.shade800;
  }

  void _showBmiInfoDialog(double bmi) {
    final bmiColor = _getBmiColor(bmi);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IMC (OMS)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bmiColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: bmiColor.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monitor_weight, size: 18, color: bmiColor),
                  const SizedBox(width: 6),
                  Text(
                    'IMC ${bmi.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: bmiColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getBmiCategory(bmi),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text('Tipos:'),
            const SizedBox(height: 6),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('- Infrapeso: Delgadez Severa'),
                Text('- Infrapeso: Delgadez moderada'),
                Text('- Infrapeso: Delgadez aceptable'),
                Text('- Peso Normal'),
                Text('- Sobrepeso'),
                Text('- Obeso: Tipo I'),
                Text('- Obeso: Tipo II'),
                Text('- Obeso: Tipo III'),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text('IMC = peso (kg) / altura (m)²'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildPacienteInfoTag({
    required IconData icon,
    required String value,
    VoidCallback? onTap,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade900),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: chip,
    );
  }

  Widget _buildPacienteTags(Paciente? paciente) {
    if (paciente == null) {
      return const Text(
        'Selecciona un paciente',
        style: TextStyle(color: Colors.black54),
      );
    }

    final edad = _calcularEdadPaciente(paciente);
    final peso = paciente.peso;
    final altura = paciente.altura;
    final imc = _calcularImcPaciente(paciente);

    final tags = <Widget>[
      _buildPacienteInfoTag(icon: Icons.person, value: paciente.nombre),
      if (edad != null) _buildPacienteInfoTag(icon: Icons.cake, value: '$edad'),
      if (peso != null && peso > 0)
        _buildPacienteInfoTag(
          icon: Icons.scale,
          value: peso.toStringAsFixed(1),
        ),
      if (altura != null && altura > 0)
        _buildPacienteInfoTag(icon: Icons.height, value: '$altura'),
      if (imc != null)
        _buildPacienteInfoTag(
          icon: Icons.analytics,
          value: imc.toStringAsFixed(1),
          onTap: () => _showBmiInfoDialog(imc),
        ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags,
    );
  }

  Widget _buildDateTimePicker({
    required String label,
    required DateTime? date,
    required ValueChanged<DateTime?> onChanged,
  }) {
    final text = date == null
        ? 'Sin fecha'
        : DateFormat('dd/MM/yyyy HH:mm').format(date);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('$label: $text'),
      trailing: const Icon(Icons.calendar_month),
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (pickedDate != null) {
          final pickedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(date ?? DateTime.now()),
          );
          if (pickedTime != null) {
            final newDate = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
            onChanged(newDate);
          }
        }
      },
    );
  }

  Widget _buildMemoField(String key, String label) {
    return Padding(
      key: _getFieldKey(key),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: _controllers[key],
        focusNode: _getFieldFocusNode(key),
        onChanged: (_) => _markDirty(),
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
        ),
        maxLines: 4,
      ),
    );
  }

  Widget _buildYesNoSwitch(
      String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: (newValue) {
        onChanged(newValue);
        _markDirty();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final canLeave = await _confirmDiscardChanges();
        if (canLeave) {
          await _saveCardExpandedState();
        }
        return canLeave;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Text(
              _isEditing ? 'Editar Entrevista Fit' : 'Nueva Entrevista Fit'),
          actions: [
            IconButton(icon: const Icon(Icons.save), onPressed: _submitForm)
          ],
        ),
        body: SafeArea(
          child: !_cardStateReady
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    onChanged: _markDirty,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPacienteCard(),
                        const SizedBox(height: 16),
                        _buildDatosEntrevistaCard(),
                        const SizedBox(height: 8),
                        _buildExpandableCard(
                          title: 'Acerca de la consulta',
                          cardKey: 'acerca_consulta',
                          subtitleWidget: _buildAcercaConsultaSubtitle(),
                          child: Column(
                            children: [
                              _buildMemoField('motivo', 'Motivaciones'),
                              _buildMemoField('objetivos', 'Objetivos'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildExpandableCard(
                          title: 'Encuesta',
                          cardKey: 'encuesta',
                          child: Column(
                            children: [
                              _buildYesNoSwitch(
                                '¿Le ha dicho alguna vez un médico que tiene una enfermedad del corazón y le ha recomendado realizar actividad física solamente con supervisión médica?',
                                _enfermedadCorazon,
                                (value) =>
                                    setState(() => _enfermedadCorazon = value),
                              ),
                              _buildYesNoSwitch(
                                '¿Nota dolo en el pecho cuando practica alguna actividad física?',
                                _notaDolorPracticaActividad,
                                (value) => setState(
                                    () => _notaDolorPracticaActividad = value),
                              ),
                              _buildYesNoSwitch(
                                '¿Ha notado dolor en el pecho en reposo durante el último mes?',
                                _notaDolorReposo,
                                (value) =>
                                    setState(() => _notaDolorReposo = value),
                              ),
                              _buildYesNoSwitch(
                                '¿Ha perdido el equilibrio o la consciencia después de notar sensación de mareo?',
                                _perdidaEquilibrio,
                                (value) =>
                                    setState(() => _perdidaEquilibrio = value),
                              ),
                              _buildYesNoSwitch(
                                '¿Tiene algún problema en los huesos o articulaciones que podría empeorar a causa de la actividad física que se propone realizar?',
                                _problemaHuesosArticulaciones,
                                (value) => setState(() =>
                                    _problemaHuesosArticulaciones = value),
                              ),
                              _buildYesNoSwitch(
                                '¿Le ha prescrito su médico medicación arterial o para algún problema de corazón?',
                                _prescipcionMedicacionArterial,
                                (value) => setState(() =>
                                    _prescipcionMedicacionArterial = value),
                              ),
                              _buildYesNoSwitch(
                                '¿Está al corriente, ya sea por su propia experiencia o por indicación de un médico, de cualquier otra razón que le impida hacer ejercicio sin supervisión médica?',
                                _razonImpedimentoEjercicio,
                                (value) => setState(
                                    () => _razonImpedimentoEjercicio = value),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildExpandableCard(
                          title: 'Historial deportivo y actividad',
                          cardKey: 'historial_actividad',
                          subtitleWidget: _buildHistorialActividadSubtitle(),
                          child: Column(
                            children: [
                              _buildMemoField('historial_deportivo',
                                  'Historial deportivo, ¿qué deporte haces normalmente?'),
                              _buildMemoField(
                                  'actividad_diaria', 'Actividad diaria'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildExpandableCard(
                          title: 'Profesión, disponibilidad, hábitos',
                          cardKey: 'profesion_habitos',
                          subtitleWidget: _buildProfesionHabitosSubtitle(),
                          child: Column(
                            children: [
                              _buildMemoField('profesion', 'Profesión'),
                              _buildMemoField('disponibilidad_horaria',
                                  'Disponibilidad horaria, ¿cuánto y cuándo dispones para hacer ejercicio?'),
                              _buildMemoField('disponibilidad_instalaciones',
                                  'Disponibilidad de instalaciones, ¿lo harás en casa o en el gimnasio?'),
                              _buildMemoField('habitos_alimentarios',
                                  'Hábitos alimentarios'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildExpandableCard(
                          title: 'Preguntas sobre el futuro',
                          cardKey: 'preguntas_futuro',
                          subtitleWidget: _buildPreguntasFuturoSubtitle(),
                          child: Column(
                            children: [
                              _buildMemoField('futuro_seguir_ritmo',
                                  '¿Te ves capaz de seguir con este ritmo?'),
                              _buildMemoField('futuro_logros_proximas_semanas',
                                  '¿Qué te gustaría lograr en las próximas semanas?'),
                              _buildMemoField('futuro_probar_nuevos_ejercicios',
                                  '¿Te motiva probar nuevos ejercicios o rutinas?'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildExpandableCard(
                          title: 'Observación',
                          cardKey: 'observacion',
                          titleBadges: [
                            _buildCountCircleBadge(
                              _controllers['observacion']?.text.trim().length ??
                                  0,
                            ),
                          ],
                          child: Column(
                            children: [
                              _buildMemoField('observacion', 'Observación'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
