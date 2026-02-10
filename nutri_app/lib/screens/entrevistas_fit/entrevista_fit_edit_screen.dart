import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/entrevista_fit.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';

class EntrevistaFitEditScreen extends StatefulWidget {
  final EntrevistaFit? entrevista;
  final Paciente paciente;

  const EntrevistaFitEditScreen(
      {super.key, this.entrevista, required this.paciente});

  @override
  State<EntrevistaFitEditScreen> createState() =>
      _EntrevistaFitEditScreenState();
}

class _EntrevistaFitEditScreenState extends State<EntrevistaFitEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool get _isEditing => widget.entrevista != null;

  // Controladores para campos de texto
  final Map<String, TextEditingController> _controllers = {};

  // Fechas y switches
  DateTime? _fechaPrevista;
  DateTime? _fechaRealizacion;
  bool _completada = false;
  bool _online = false;
  bool _hasChanges = false;

  // Switches de encuesta
  bool _enfermedadCorazon = false;
  bool _notaDolorPracticaActividad = false;
  bool _notaDolorReposo = false;
  bool _perdidaEquilibrio = false;
  bool _problemaHuesosArticulaciones = false;
  bool _prescipcionMedicacionArterial = false;
  bool _razonImpedimentoEjercicio = false;

  late ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
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
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final entrevistaData = EntrevistaFit(
        codigo: widget.entrevista?.codigo ?? 0,
        codigoPaciente: widget.paciente.codigo,
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
          // Mostrar mensaje según sea alta o modificación
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.entrevista == null
                  ? 'Entrevista añadida correctamente'
                  : 'Entrevista modificada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Error al guardar'), backgroundColor: Colors.red));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _markDirty() {
    if (_hasChanges) return;
    setState(() {
      _hasChanges = true;
    });
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasChanges) return true;
    return showUnsavedChangesDialog(context);
  }

  Future<void> _handleBack() async {
    if (await _confirmDiscardChanges()) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
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

  Widget _buildAccordion(String title, List<Widget> children) {
    return ExpansionTile(
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      initiallyExpanded: false,
      children: children,
    );
  }

  Widget _buildMemoField(String key, String label) {
    return TextFormField(
      controller: _controllers[key],
      decoration: InputDecoration(labelText: label),
      maxLines: 3,
    );
  }

  Widget _buildYesNoSwitch(
      String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              onChanged: _markDirty,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Paciente: ${widget.paciente.nombre}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _buildDateTimePicker(
                    label: 'Fecha prevista',
                    date: _fechaPrevista,
                    onChanged: (newDate) =>
                        setState(() => _fechaPrevista = newDate),
                  ),
                  _buildDateTimePicker(
                    label: 'Fecha realización',
                    date: _fechaRealizacion,
                    onChanged: (newDate) =>
                        setState(() => _fechaRealizacion = newDate),
                  ),
                  SwitchListTile(
                    title: const Text('Completada'),
                    value: _completada,
                    onChanged: (value) => setState(() => _completada = value),
                  ),
                  SwitchListTile(
                    title: const Text('Online'),
                    value: _online,
                    onChanged: (value) => setState(() => _online = value),
                  ),
                  const SizedBox(height: 12),
                  _buildAccordion('ACERCA DE LA CONSULTA', [
                    _buildMemoField('motivo', 'Motivaciones'),
                    _buildMemoField('objetivos', 'Objetivos'),
                  ]),
                  _buildAccordion('ENCUESTA', [
                    _buildYesNoSwitch(
                      '¿Le ha dicho alguna vez un médico que tiene una enfermedad del corazón y le ha recomendado realizar actividad física solamente con supervisión médica?',
                      _enfermedadCorazon,
                      (value) => setState(() => _enfermedadCorazon = value),
                    ),
                    _buildYesNoSwitch(
                      '¿Nota dolo en el pecho cuando practica alguna actividad física?',
                      _notaDolorPracticaActividad,
                      (value) =>
                          setState(() => _notaDolorPracticaActividad = value),
                    ),
                    _buildYesNoSwitch(
                      '¿Ha notado dolor en el pecho en reposo durante el último mes?',
                      _notaDolorReposo,
                      (value) => setState(() => _notaDolorReposo = value),
                    ),
                    _buildYesNoSwitch(
                      '¿Ha perdido el equilibrio o la consciencia después de notar sensación de mareo?',
                      _perdidaEquilibrio,
                      (value) => setState(() => _perdidaEquilibrio = value),
                    ),
                    _buildYesNoSwitch(
                      '¿Tiene algún problema en los huesos o articulaciones que podría empeorar a causa de la actividad física que se propone realizar?',
                      _problemaHuesosArticulaciones,
                      (value) =>
                          setState(() => _problemaHuesosArticulaciones = value),
                    ),
                    _buildYesNoSwitch(
                      '¿Le ha prescrito su médico medicación arterial o para algún problema de corazón?',
                      _prescipcionMedicacionArterial,
                      (value) => setState(
                          () => _prescipcionMedicacionArterial = value),
                    ),
                    _buildYesNoSwitch(
                      '¿Está al corriente, ya sea por su propia experiencia o por indicación de un médico, de cualquier otra razón que le impida hacer ejercicio sin supervisión médica?',
                      _razonImpedimentoEjercicio,
                      (value) =>
                          setState(() => _razonImpedimentoEjercicio = value),
                    ),
                  ]),
                  _buildAccordion('Historial deportivo y actividad', [
                    _buildMemoField('historial_deportivo',
                        'Historial deportivo, ¿qué deporte haces normalmente?'),
                    _buildMemoField('actividad_diaria', 'Actividad diaria'),
                  ]),
                  _buildAccordion('Profesión, disponibilidad, Hábitos', [
                    _buildMemoField('profesion', 'Profesión'),
                    _buildMemoField('disponibilidad_horaria',
                        'Disponibilidad horaria, ¿cuánto y cuándo dispones para hacer ejercicio?'),
                    _buildMemoField('disponibilidad_instalaciones',
                        'Disponibilidad de instalaciones, ¿lo harás en casa o en el gimnasio?'),
                    _buildMemoField(
                        'habitos_alimentarios', 'Hábitos alimentarios'),
                  ]),
                  _buildAccordion('Preguntas sobre el futuro', [
                    _buildMemoField('futuro_seguir_ritmo',
                        '¿Te ves capaz de seguir con este rirmo?'),
                    _buildMemoField('futuro_logros_proximas_semanas',
                        '¿Qué te gustaría lograr en las próximas semanas?'),
                    _buildMemoField('futuro_probar_nuevos_ejercicios',
                        '¿Te motiva probar nuevos ejercicios o rutinas?'),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _controllers['observacion'],
                    decoration: const InputDecoration(
                      labelText: 'Observación',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
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
