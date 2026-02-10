import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/entrevista.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:provider/provider.dart';

class EntrevistaEditScreen extends StatefulWidget {
  final Entrevista? entrevista;
  final Paciente paciente;

  const EntrevistaEditScreen(
      {super.key, this.entrevista, required this.paciente});

  @override
  _EntrevistaEditScreenState createState() => _EntrevistaEditScreenState();
}

class _EntrevistaEditScreenState extends State<EntrevistaEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool get _isEditing => widget.entrevista != null;

  // Controladores para todos los campos
  final Map<String, TextEditingController> _controllers = {};

  // Estado de los campos que no son de texto
  DateTime? _fechaPrevista;
  DateTime? _fechaRealizacion;
  bool _completada = false;
  bool _online = false;
  bool _hasChanges = false;
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
    } else {
      // Es una nueva entrevista, aplicamos valores por defecto.
      _fechaPrevista = DateTime.now();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDefaultValues();
      });
    }
  }

  void _loadDefaultValues() {
    final configService = Provider.of<ConfigService>(context, listen: false);
    setState(() {
      _completada = configService.defaultCompletadaEntrevista;
      _online = configService.defaultOnlineEntrevista;
    });
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
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final entrevistaData = Entrevista(
        codigo: widget.entrevista?.codigo ?? 0,
        codigoPaciente: widget.paciente.codigo,
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
          // Mostrar mensaje según sea alta o modificación
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.entrevista == null
                  ? 'Entrevista añadida correctamente'
                  : 'Entrevista modificada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
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
          title: Text(_isEditing ? 'Editar Entrevista' : 'Nueva Entrevista'),
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
                    label: 'Fecha Prevista',
                    date: _fechaPrevista,
                    onChanged: (newDate) =>
                        setState(() => _fechaPrevista = newDate),
                  ),
                  _buildDateTimePicker(
                    label: 'Fecha Realización',
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
                  TextFormField(
                    controller: _controllers['peso'],
                    decoration: const InputDecoration(labelText: 'Peso (Kg)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildAccordion('ACERCA DE LA CONSULTA', [
                    _buildMemoField('motivo', 'Motivo'),
                    _buildMemoField('objetivos', 'Objetivos'),
                    _buildMemoField('dietas_anteriores',
                        '¿Ha realizado dietas anteriormente? ¿Cómo le ha ido?'),
                  ]),
                  _buildAccordion('ESTILO DE VIDA', [
                    _buildMemoField('ocupacion_horario',
                        'Ocupación: ¿Qué horario ocupa tu trabajo?'),
                    _buildMemoField('deporte_frecuencia',
                        '¿Realiza algún tipo de deporte? ¿Con qué frecuencia?'),
                    _buildMemoField('actividad_fisica',
                        '¿Cómo se considera en su día a día?'),
                    _buildMemoField(
                        'fumador', '¿Es fumador? ¿Cuántos cigarrillos al día?'),
                    _buildMemoField('alcohol',
                        '¿Suele beber alcohol? ¿Con qué frecuencia?'),
                    _buildMemoField(
                        'sueno', '¿Cómo describiría la calidad de su sueño?'),
                    _buildMemoField('horario_laboral_comidas',
                        '¿Influye su horario laboral a la hora de organizarse sus comidas?'),
                  ]),
                  _buildAccordion('HÁBITOS ALIMENTARIOS', [
                    _buildMemoField(
                        'comidas_dia', '¿Cuántas comidas realiza al día?'),
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
                  ]),
                  _buildAccordion('INDICADORES CLÍNICOS', [
                    _buildMemoField('patologia', '¿Sufre de alguna patología?'),
                    _buildMemoField('antecedentes_enfermedades',
                        'Antecedentes personales o familiares significativos'),
                    _buildMemoField(
                        'tipo_medicacion', '¿Toma algún tipo de medicación?'),
                    _buildMemoField('tipo_suplemento',
                        '¿Toma algún tipo de suplemento alimentario?'),
                    _buildMemoField('intolerancia_alergia',
                        '¿Sufre alguna intolerancia o alergia alimentaria?'),
                    _buildMemoField(
                        'hambre_emocional', '¿Suele sentir hambre emocional?'),
                    _buildMemoField(
                        'estres_ansiedad', '¿Sufre de estrés o ansiedad?'),
                    _buildMemoField('relacion_comida',
                        '¿Cómo definiría su relación con la comida?'),
                  ]),
                  _buildAccordion('SALUD FEMENINA', [
                    _buildMemoField(
                        'ciclo_menstrual', '¿Cómo es tu ciclo menstrual?'),
                    _buildMemoField(
                        'lactancia', '¿Está en período de lactancia?'),
                  ]),
                  _buildAccordion('RECUENTO DE 24 HORAS', [
                    _buildMemoField('24_horas_desayuno', 'Desayuno'),
                    _buildMemoField('24_horas_almuerzo', 'Almuerzo'),
                    _buildMemoField('24_horas_comida', 'Comida'),
                    _buildMemoField('24_horas_merienda', 'Merienda'),
                    _buildMemoField('24_horas_cena', 'Cena'),
                    _buildMemoField('24_horas_recena', 'Recena'),
                  ]),
                  _buildAccordion('PREFERENCIAS', [
                    _buildMemoField(
                        'pesar_alimentos', '¿Quiere pesarse los alimentos?'),
                    _buildMemoField('resultados_bascula',
                        '¿Quieres ver resultados mediante la báscula?'),
                    _buildMemoField('gusta_cocinar', '¿Le gusta cocinar?'),
                    _buildMemoField('establecimiento_compra',
                        '¿Dónde en que establecimiento sueles hacer la compra?'),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccordion(String title, List<Widget> children) {
    return ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: children,
    );
  }

  Widget _buildMemoField(String key, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: TextFormField(
        controller: _controllers[key],
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
