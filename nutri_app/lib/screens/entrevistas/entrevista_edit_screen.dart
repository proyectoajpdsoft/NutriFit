import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/entrevista.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EntrevistaEditScreen extends StatefulWidget {
  final Entrevista? entrevista;
  final Paciente? paciente;

  const EntrevistaEditScreen({super.key, this.entrevista, this.paciente});

  @override
  _EntrevistaEditScreenState createState() => _EntrevistaEditScreenState();
}

class _EntrevistaEditScreenState extends State<EntrevistaEditScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  bool get _isEditing => widget.entrevista != null;
  final Map<String, GlobalKey> _fieldKeys = {};
  final Map<String, FocusNode> _fieldFocusNodes = {};
  Timer? _draftSaveTimer;
  bool _isRestoringDraft = false;

  // Controladores para todos los campos
  final Map<String, TextEditingController> _controllers = {};

  // Estado de los campos que no son de texto
  DateTime? _fechaPrevista;
  DateTime? _fechaRealizacion;
  bool _completada = false;
  bool _online = false;
  bool _hasChanges = false;
  bool _cardStateReady = false;
  late ApiService _apiService = ApiService();
  late Future<List<Paciente>> _pacientesFuture;
  final Map<String, bool> _cardExpanded = {
    'paciente': false,
    'datos_entrevista': true,
    'acerca_consulta': false,
    'estilo_vida': false,
    'habitos_alimentarios': false,
    'indicadores_clinicos': false,
    'salud_femenina': false,
    'recuento_24h': false,
    'preferencias': false,
    'observacion': false,
  };
  int? _selectedPacienteId;
  String _selectedPacienteNombre = '';

  String get _draftStorageKey {
    final scope = _isEditing
        ? 'edit_${widget.entrevista!.codigo}'
        : 'new_${widget.paciente?.codigo ?? 'none'}';
    return 'entrevista_edit_draft_$scope';
  }

  static const String _cardStateStorageKey =
      'entrevista_edit_card_expanded_state';

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
    } else {
      _fechaPrevista = DateTime.now();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadCardExpandedState();
      if (!_isEditing) {
        _loadDefaultValues();
      }
      await _restoreDraftIfAny();
      if (!mounted) return;
      setState(() {
        _cardStateReady = true;
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _persistDraft();
      _saveCardExpandedState();
    }
  }

  void _loadDefaultValues() {
    final configService = Provider.of<ConfigService>(context, listen: false);
    setState(() {
      _completada = configService.defaultCompletadaEntrevista;
      _online = configService.defaultOnlineEntrevista;
    });
  }

  Future<void> _loadCardExpandedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cardStateStorageKey);
    if (raw == null || raw.trim().isEmpty || !mounted) return;

    try {
      final savedState = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      setState(() {
        for (final entry in savedState.entries) {
          if (_cardExpanded.containsKey(entry.key) && entry.value is bool) {
            _cardExpanded[entry.key] = entry.value as bool;
          }
        }
      });
    } catch (_) {
      await prefs.remove(_cardStateStorageKey);
    }
  }

  Future<void> _saveCardExpandedState() async {
    if (!_cardStateReady) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cardStateStorageKey,
      jsonEncode(_cardExpanded),
    );
  }

  void _initializeControllers() {
    final e = widget.entrevista;
    _controllers['peso'] =
        TextEditingController(text: e?.peso?.toString() ?? '');
    _controllers['motivo'] = TextEditingController(text: e?.motivo ?? '');
    _controllers['objetivos'] = TextEditingController(text: e?.objetivos ?? '');
    _controllers['dietas_anteriores'] =
        TextEditingController(text: e?.dietasAnteriores ?? '');
    _controllers['ocupacion_horario'] =
        TextEditingController(text: e?.ocupacionHorario ?? '');
    _controllers['deporte_frecuencia'] =
        TextEditingController(text: e?.deporteFrecuencia ?? '');
    _controllers['actividad_fisica'] =
        TextEditingController(text: e?.actividadFisica ?? '');
    _controllers['fumador'] = TextEditingController(text: e?.fumador ?? '');
    _controllers['alcohol'] = TextEditingController(text: e?.alcohol ?? '');
    _controllers['sueno'] = TextEditingController(text: e?.sueno ?? '');
    _controllers['horario_laboral_comidas'] =
        TextEditingController(text: e?.horarioLaboralComidas ?? '');
    _controllers['comidas_dia'] =
        TextEditingController(text: e?.comidasDia ?? '');
    _controllers['horario_comidas_regular'] =
        TextEditingController(text: e?.horarioComidasRegular ?? '');
    _controllers['lugar_comidas'] =
        TextEditingController(text: e?.lugarComidas ?? '');
    _controllers['quien_compra_casa'] =
        TextEditingController(text: e?.quienCompraCasa ?? '');
    _controllers['bebida_comida'] =
        TextEditingController(text: e?.bebidaComida ?? '');
    _controllers['preferencias_alimentarias'] =
        TextEditingController(text: e?.preferenciasAlimentarias ?? '');
    _controllers['alimentos_rechazo'] =
        TextEditingController(text: e?.alimentosRechazo ?? '');
    _controllers['tipo_dieta_preferencia'] =
        TextEditingController(text: e?.tipoDietaPreferencia ?? '');
    _controllers['cantidad_agua_diaria'] =
        TextEditingController(text: e?.cantidadAguaDiaria ?? '');
    _controllers['picar_entre_horas'] =
        TextEditingController(text: e?.picarEntreHoras ?? '');
    _controllers['hora_dia_mas_apetito'] =
        TextEditingController(text: e?.horaDiaMasApetito ?? '');
    _controllers['antojo_dulce_salado'] =
        TextEditingController(text: e?.antojoDulceSalado ?? '');
    _controllers['patologia'] = TextEditingController(text: e?.patologia ?? '');
    _controllers['antecedentes_enfermedades'] =
        TextEditingController(text: e?.antecedentesEnfermedades ?? '');
    _controllers['tipo_medicacion'] =
        TextEditingController(text: e?.tipoMedicacion ?? '');
    _controllers['tipo_suplemento'] =
        TextEditingController(text: e?.tipoSuplemento ?? '');
    _controllers['intolerancia_alergia'] =
        TextEditingController(text: e?.intoleranciaAlergia ?? '');
    _controllers['hambre_emocional'] =
        TextEditingController(text: e?.hambreEmocional ?? '');
    _controllers['estres_ansiedad'] =
        TextEditingController(text: e?.estresAnsiedad ?? '');
    _controllers['relacion_comida'] =
        TextEditingController(text: e?.relacionComida ?? '');
    _controllers['ciclo_menstrual'] =
        TextEditingController(text: e?.cicloMenstrual ?? '');
    _controllers['lactancia'] = TextEditingController(text: e?.lactancia ?? '');
    _controllers['24_horas_desayuno'] =
        TextEditingController(text: e?.h24Desayuno ?? '');
    _controllers['24_horas_almuerzo'] =
        TextEditingController(text: e?.h24Almuerzo ?? '');
    _controllers['24_horas_comida'] =
        TextEditingController(text: e?.h24Comida ?? '');
    _controllers['24_horas_merienda'] =
        TextEditingController(text: e?.h24Merienda ?? '');
    _controllers['24_horas_cena'] =
        TextEditingController(text: e?.h24Cena ?? '');
    _controllers['24_horas_recena'] =
        TextEditingController(text: e?.h24Recena ?? '');
    _controllers['pesar_alimentos'] =
        TextEditingController(text: e?.pesarAlimentos ?? '');
    _controllers['resultados_bascula'] =
        TextEditingController(text: e?.resultadosBascula ?? '');
    _controllers['gusta_cocinar'] =
        TextEditingController(text: e?.gustaCocinar ?? '');
    _controllers['establecimiento_compra'] =
        TextEditingController(text: e?.establecimientoCompra ?? '');
    _controllers['observacion'] =
        TextEditingController(text: e?.observacion ?? '');
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _controllers.forEach((_, controller) => controller.dispose());
    _fieldFocusNodes.forEach((_, focusNode) => focusNode.dispose());
    WidgetsBinding.instance.removeObserver(this);
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

  Map<String, dynamic> _buildDraftPayload() {
    return {
      'selectedPacienteId': _selectedPacienteId,
      'selectedPacienteNombre': _selectedPacienteNombre,
      'fechaPrevista': _fechaPrevista?.toIso8601String(),
      'fechaRealizacion': _fechaRealizacion?.toIso8601String(),
      'completada': _completada,
      'online': _online,
      'controllers':
          _controllers.map((key, controller) => MapEntry(key, controller.text)),
      'cardExpanded': Map<String, bool>.from(_cardExpanded),
      'savedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _persistDraft() async {
    if (_isRestoringDraft || !_hasChanges) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftStorageKey, jsonEncode(_buildDraftPayload()));
  }

  void _scheduleDraftSave() {
    if (_isRestoringDraft) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(seconds: 2), () {
      _persistDraft();
    });
  }

  Future<void> _clearDraft() async {
    _draftSaveTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftStorageKey);
  }

  Future<void> _restoreDraftIfAny() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftStorageKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final draft = jsonDecode(raw) as Map<String, dynamic>;
      final controllers = Map<String, dynamic>.from(
        (draft['controllers'] as Map?) ?? const {},
      );
      final cardExpanded = Map<String, dynamic>.from(
        (draft['cardExpanded'] as Map?) ?? const {},
      );

      _isRestoringDraft = true;
      if (!mounted) return;

      setState(() {
        _selectedPacienteId = draft['selectedPacienteId'] as int?;
        _selectedPacienteNombre =
            (draft['selectedPacienteNombre'] as String? ?? '').trim();
        _fechaPrevista = _parseDraftDate(draft['fechaPrevista']);
        _fechaRealizacion = _parseDraftDate(draft['fechaRealizacion']);
        _completada = draft['completada'] as bool? ?? _completada;
        _online = draft['online'] as bool? ?? _online;

        for (final entry in controllers.entries) {
          if (_controllers.containsKey(entry.key)) {
            _controllers[entry.key]!.text = '${entry.value ?? ''}';
          }
        }

        for (final entry in cardExpanded.entries) {
          if (_cardExpanded.containsKey(entry.key) && entry.value is bool) {
            _cardExpanded[entry.key] = entry.value as bool;
          }
        }

        _hasChanges = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Borrador restaurado automáticamente'),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    } catch (_) {
      await _clearDraft();
    } finally {
      _isRestoringDraft = false;
    }
  }

  DateTime? _parseDraftDate(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
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

      final entrevistaData = Entrevista(
        codigo: widget.entrevista?.codigo ?? 0,
        codigoPaciente: _selectedPacienteId!,
        fechaPrevista: _fechaPrevista,
        fechaRealizacion: _fechaRealizacion,
        completada: _completada ? 'S' : 'N',
        online: _online ? 'S' : 'N',
        peso: double.tryParse(_controllers['peso']!.text),
        motivo: _controllers['motivo']!.text,
        objetivos: _controllers['objetivos']!.text,
        dietasAnteriores: _controllers['dietas_anteriores']!.text,
        ocupacionHorario: _controllers['ocupacion_horario']!.text,
        deporteFrecuencia: _controllers['deporte_frecuencia']!.text,
        actividadFisica: _controllers['actividad_fisica']!.text,
        fumador: _controllers['fumador']!.text,
        alcohol: _controllers['alcohol']!.text,
        sueno: _controllers['sueno']!.text,
        horarioLaboralComidas: _controllers['horario_laboral_comidas']!.text,
        comidasDia: _controllers['comidas_dia']!.text,
        horarioComidasRegular: _controllers['horario_comidas_regular']!.text,
        lugarComidas: _controllers['lugar_comidas']!.text,
        quienCompraCasa: _controllers['quien_compra_casa']!.text,
        bebidaComida: _controllers['bebida_comida']!.text,
        preferenciasAlimentarias:
            _controllers['preferencias_alimentarias']!.text,
        alimentosRechazo: _controllers['alimentos_rechazo']!.text,
        tipoDietaPreferencia: _controllers['tipo_dieta_preferencia']!.text,
        cantidadAguaDiaria: _controllers['cantidad_agua_diaria']!.text,
        picarEntreHoras: _controllers['picar_entre_horas']!.text,
        horaDiaMasApetito: _controllers['hora_dia_mas_apetito']!.text,
        antojoDulceSalado: _controllers['antojo_dulce_salado']!.text,
        patologia: _controllers['patologia']!.text,
        antecedentesEnfermedades:
            _controllers['antecedentes_enfermedades']!.text,
        tipoMedicacion: _controllers['tipo_medicacion']!.text,
        tipoSuplemento: _controllers['tipo_suplemento']!.text,
        intoleranciaAlergia: _controllers['intolerancia_alergia']!.text,
        hambreEmocional: _controllers['hambre_emocional']!.text,
        estresAnsiedad: _controllers['estres_ansiedad']!.text,
        relacionComida: _controllers['relacion_comida']!.text,
        cicloMenstrual: _controllers['ciclo_menstrual']!.text,
        lactancia: _controllers['lactancia']!.text,
        h24Desayuno: _controllers['24_horas_desayuno']!.text,
        h24Almuerzo: _controllers['24_horas_almuerzo']!.text,
        h24Comida: _controllers['24_horas_comida']!.text,
        h24Merienda: _controllers['24_horas_merienda']!.text,
        h24Cena: _controllers['24_horas_cena']!.text,
        h24Recena: _controllers['24_horas_recena']!.text,
        pesarAlimentos: _controllers['pesar_alimentos']!.text,
        resultadosBascula: _controllers['resultados_bascula']!.text,
        gustaCocinar: _controllers['gusta_cocinar']!.text,
        establecimientoCompra: _controllers['establecimiento_compra']!.text,
      );

      try {
        bool success;
        if (widget.entrevista != null) {
          success = await _apiService.updateEntrevista(entrevistaData);
        } else {
          success = await _apiService.createEntrevista(entrevistaData);
        }

        if (success) {
          _hasChanges = false;
          await _clearDraft();
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
            content: Text('Error al guardar'),
            backgroundColor: Colors.red,
          ));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    return false;
  }

  void _markDirty() {
    _scheduleDraftSave();
    if (_hasChanges) return;
    setState(() {
      _hasChanges = true;
    });
  }

  Future<void> _focusFieldFromTag(String cardKey, String fieldKey) async {
    final wasCollapsed = !(_cardExpanded[cardKey] ?? false);

    if (wasCollapsed) {
      setState(() {
        _cardExpanded[cardKey] = true;
      });
      _saveCardExpandedState();
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
      await _clearDraft();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
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
        key: PageStorageKey('entrevista_edit_card_$cardKey'),
        initiallyExpanded: effectiveInitiallyExpanded,
        maintainState: true,
        onExpansionChanged: (expanded) {
          setState(() => _cardExpanded[cardKey] = expanded);
          _saveCardExpandedState();
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (titleBadges.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ...titleBadges,
                ],
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

  int _getFieldCharCount(String key) {
    return _controllers[key]?.text.trim().length ?? 0;
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
    final count = _getFieldCharCount(key);
    final color = count > 0 ? Colors.green : Colors.grey;

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
          Container(
            width: 20,
            height: 20,
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
          ),
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

  Widget _buildSectionCountersSubtitle(
    String cardKey,
    List<MapEntry<String, String>> fields,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: fields
          .map(
            (field) => _buildFieldCountTag(
              field.key,
              field.value,
              onTap: () => _focusFieldFromTag(cardKey, field.value),
            ),
          )
          .toList(),
    );
  }

  String _formatResumenFecha(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Widget _buildDatosEntrevistaSubtitle() {
    final prev = _formatResumenFecha(_fechaPrevista);
    final real = _formatResumenFecha(_fechaRealizacion);
    final pesoRaw = _controllers['peso']?.text.trim() ?? '';

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
    if (pesoRaw.isNotEmpty) {
      if (items.isNotEmpty) {
        items.add(Text('  ·  ', style: TextStyle(color: Colors.grey.shade600)));
      }
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.scale, size: 12, color: Colors.grey.shade700),
            const SizedBox(width: 3),
            Text(
              pesoRaw,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
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
            label: 'Fecha Prevista',
            date: _fechaPrevista,
            onChanged: (newDate) {
              setState(() => _fechaPrevista = newDate);
              _markDirty();
            },
          ),
          _buildDateTimePicker(
            label: 'Fecha Realización',
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
          TextFormField(
            controller: _controllers['peso'],
            decoration: const InputDecoration(labelText: 'Peso (Kg)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
          ),
        ],
      ),
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
          title: Text(_isEditing ? 'Editar Entrevista' : 'Nueva Entrevista'),
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
                          subtitleWidget:
                              _buildSectionCountersSubtitle('acerca_consulta', [
                            const MapEntry('Mot.', 'motivo'),
                            const MapEntry('Obj.', 'objetivos'),
                            const MapEntry('Diet.', 'dietas_anteriores'),
                          ]),
                          child: Column(
                            children: [
                              _buildMemoField('motivo', 'Motivo'),
                              _buildMemoField('objetivos', 'Objetivos'),
                              _buildMemoField('dietas_anteriores',
                                  '¿Ha realizado dietas anteriormente? ¿Cómo le ha ido?'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildExpandableCard(
                          title: 'Estilo de vida',
                          cardKey: 'estilo_vida',
                          subtitleWidget:
                              _buildSectionCountersSubtitle('estilo_vida', [
                            const MapEntry('Ocu.', 'ocupacion_horario'),
                            const MapEntry('Dep.', 'deporte_frecuencia'),
                            const MapEntry('Día', 'actividad_fisica'),
                            const MapEntry('Fum.', 'fumador'),
                            const MapEntry('Alc.', 'alcohol'),
                            const MapEntry('Sue.', 'sueno'),
                            const MapEntry('Hor.', 'horario_laboral_comidas'),
                          ]),
                          child: Column(
                            children: [
                              _buildMemoField('ocupacion_horario',
                                  'Ocupación: ¿Qué horario ocupa tu trabajo?'),
                              _buildMemoField('deporte_frecuencia',
                                  '¿Realiza algún tipo de deporte? ¿Con qué frecuencia?'),
                              _buildMemoField('actividad_fisica',
                                  '¿Cómo se considera en su día a día?'),
                              _buildMemoField('fumador',
                                  '¿Es fumador? ¿Cuántos cigarrillos al día?'),
                              _buildMemoField('alcohol',
                                  '¿Suele beber alcohol? ¿Con qué frecuencia?'),
                              _buildMemoField('sueno',
                                  '¿Cómo describiría la calidad de su sueño?'),
                              _buildMemoField('horario_laboral_comidas',
                                  '¿Influye su horario laboral a la hora de organizarse sus comidas?'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildExpandableCard(
                          title: 'Hábitos alimentarios',
                          cardKey: 'habitos_alimentarios',
                          subtitleWidget: _buildSectionCountersSubtitle(
                              'habitos_alimentarios', [
                            const MapEntry('Com.', 'comidas_dia'),
                            const MapEntry('Hor.', 'horario_comidas_regular'),
                            const MapEntry('Lug.', 'lugar_comidas'),
                            const MapEntry('Quién', 'quien_compra_casa'),
                            const MapEntry('Agua', 'cantidad_agua_diaria'),
                            const MapEntry(
                                'Pref.', 'preferencias_alimentarias'),
                            const MapEntry('Rech.', 'alimentos_rechazo'),
                            const MapEntry('Diet.', 'tipo_dieta_preferencia'),
                            const MapEntry('Pica', 'picar_entre_horas'),
                            const MapEntry('Apet.', 'hora_dia_mas_apetito'),
                            const MapEntry('Ant.', 'antojo_dulce_salado'),
                          ]),
                          child: Column(
                            children: [
                              _buildMemoField('comidas_dia',
                                  '¿Cuántas comidas realiza al día?'),
                              _buildMemoField('horario_comidas_regular',
                                  '¿Cuál suele ser su horario habitual de comidas?'),
                              _buildMemoField('lugar_comidas',
                                  '¿Dónde suele realizar las comidas normalmente?'),
                              _buildMemoField('quien_compra_casa',
                                  '¿Quién se encarga de cocinar y realizar la compra en casa?'),
                              _buildMemoField('bebida_comida',
                                  '¿Sueles beber durante la comida otra cosa que no sea agua?'),
                              _buildMemoField('preferencias_alimentarias',
                                  'Preferencias alimentarias'),
                              _buildMemoField(
                                  'alimentos_rechazo', 'Alimentos que rechaza'),
                              _buildMemoField('tipo_dieta_preferencia',
                                  '¿Sigue algún tipo de dieta específica?'),
                              _buildMemoField('cantidad_agua_diaria',
                                  '¿Cuánta cantidad de agua bebe al día?'),
                              _buildMemoField('picar_entre_horas',
                                  '¿Tiene tendencia a picar entre horas?'),
                              _buildMemoField('hora_dia_mas_apetito',
                                  '¿A qué hora del día suele sentir más apetito?'),
                              _buildMemoField('antojo_dulce_salado',
                                  'Ante un antojo, ¿suele preferir dulce o salado?'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildExpandableCard(
                          title: 'Indicadores clínicos',
                          cardKey: 'indicadores_clinicos',
                          subtitleWidget: _buildSectionCountersSubtitle(
                              'indicadores_clinicos', [
                            const MapEntry('Pat.', 'patologia'),
                            const MapEntry('Ant.', 'antecedentes_enfermedades'),
                            const MapEntry('Med.', 'tipo_medicacion'),
                            const MapEntry('Sup.', 'tipo_suplemento'),
                            const MapEntry('Int.', 'intolerancia_alergia'),
                            const MapEntry('Ham.', 'hambre_emocional'),
                            const MapEntry('Est.', 'estres_ansiedad'),
                            const MapEntry('Rel.', 'relacion_comida'),
                          ]),
                          child: Column(
                            children: [
                              _buildMemoField(
                                  'patologia', '¿Sufre de alguna patología?'),
                              _buildMemoField('antecedentes_enfermedades',
                                  'Antecedentes personales o familiares significativos'),
                              _buildMemoField('tipo_medicacion',
                                  '¿Toma algún tipo de medicación?'),
                              _buildMemoField('tipo_suplemento',
                                  '¿Toma algún tipo de suplemento alimentario?'),
                              _buildMemoField('intolerancia_alergia',
                                  '¿Sufre alguna intolerancia o alergia alimentaria?'),
                              _buildMemoField('hambre_emocional',
                                  '¿Suele sentir hambre emocional?'),
                              _buildMemoField('estres_ansiedad',
                                  '¿Sufre de estrés o ansiedad?'),
                              _buildMemoField('relacion_comida',
                                  '¿Cómo definiría su relación con la comida?'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildExpandableCard(
                          title: 'Salud femenina',
                          cardKey: 'salud_femenina',
                          subtitleWidget:
                              _buildSectionCountersSubtitle('salud_femenina', [
                            const MapEntry('Ciclo', 'ciclo_menstrual'),
                            const MapEntry('Lactancia', 'lactancia'),
                          ]),
                          child: Column(
                            children: [
                              _buildMemoField('ciclo_menstrual',
                                  '¿Cómo es tu ciclo menstrual?'),
                              _buildMemoField('lactancia',
                                  '¿Está en período de lactancia?'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildExpandableCard(
                          title: 'Recuento de 24 horas',
                          cardKey: 'recuento_24h',
                          subtitleWidget:
                              _buildSectionCountersSubtitle('recuento_24h', [
                            const MapEntry('Des.', '24_horas_desayuno'),
                            const MapEntry('Alm.', '24_horas_almuerzo'),
                            const MapEntry('Com.', '24_horas_comida'),
                            const MapEntry('Mer.', '24_horas_merienda'),
                            const MapEntry('Cen.', '24_horas_cena'),
                            const MapEntry('Rec.', '24_horas_recena'),
                          ]),
                          child: Column(
                            children: [
                              _buildMemoField('24_horas_desayuno', 'Desayuno'),
                              _buildMemoField('24_horas_almuerzo', 'Almuerzo'),
                              _buildMemoField('24_horas_comida', 'Comida'),
                              _buildMemoField('24_horas_merienda', 'Merienda'),
                              _buildMemoField('24_horas_cena', 'Cena'),
                              _buildMemoField('24_horas_recena', 'Recena'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildExpandableCard(
                          title: 'Preferencias',
                          cardKey: 'preferencias',
                          subtitleWidget:
                              _buildSectionCountersSubtitle('preferencias', [
                            const MapEntry('Pesar', 'pesar_alimentos'),
                            const MapEntry('Básc.', 'resultados_bascula'),
                            const MapEntry('Gusta', 'gusta_cocinar'),
                            const MapEntry('Estab.', 'establecimiento_compra'),
                          ]),
                          child: Column(
                            children: [
                              _buildMemoField('pesar_alimentos',
                                  '¿Quiere pesarse los alimentos?'),
                              _buildMemoField('resultados_bascula',
                                  '¿Quieres ver resultados mediante la báscula?'),
                              _buildMemoField(
                                  'gusta_cocinar', '¿Le gusta cocinar?'),
                              _buildMemoField('establecimiento_compra',
                                  '¿Dónde en que establecimiento sueles hacer la compra?'),
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

  Widget _buildMemoField(String key, String label) {
    return Padding(
      key: _getFieldKey(key),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: _controllers[key],
        focusNode: _getFieldFocusNode(key),
        onChanged: (_) {
          if (!_hasChanges) {
            _markDirty();
            return;
          }
          setState(() {});
        },
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
        ),
        maxLines: 4,
      ),
    );
  }

  Widget _buildDateTimePicker({
    required String label,
    required DateTime? date,
    required ValueChanged<DateTime> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
          '$label: ${date == null ? 'No seleccionada' : DateFormat('dd/MM/yyyy HH:mm').format(date)}'),
      trailing: const Icon(Icons.calendar_month),
      onTap: () async {
        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (pickedDate == null) return;

        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(date ?? DateTime.now()),
        );
        if (pickedTime == null) return;

        onChanged(DateTime(pickedDate.year, pickedDate.month, pickedDate.day,
            pickedTime.hour, pickedTime.minute));
      },
    );
  }
}
