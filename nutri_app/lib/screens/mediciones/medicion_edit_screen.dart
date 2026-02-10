import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/medicion.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';

class MedicionEditScreen extends StatefulWidget {
  final Medicion? medicion;
  final Paciente? paciente;

  const MedicionEditScreen({super.key, this.medicion, this.paciente});

  @override
  _MedicionEditScreenState createState() => _MedicionEditScreenState();
}

class _MedicionEditScreenState extends State<MedicionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool get _isEditing => widget.medicion != null;
  bool get _isForSpecificPaciente => widget.paciente != null;

  // Controladores
  final _pesoController = TextEditingController();
  final _caderaController = TextEditingController();
  final _cinturaController = TextEditingController();
  final _musloController = TextEditingController();
  final _brazoController = TextEditingController();
  final _pliegueAbdominalController = TextEditingController();
  final _pliegueCuadricipitalController = TextEditingController();
  final _plieguePeronealController = TextEditingController();
  final _pliegueSubescapularController = TextEditingController();
  final _pliegueTricipitalController = TextEditingController();
  final _pliegueSuprailiacoController = TextEditingController();
  final _observacionController = TextEditingController();

  // Otros campos
  DateTime _fecha = DateTime.now();
  String? _actividadFisica;
  int? _selectedPacienteId;
  bool _expandPliegues = false;
  bool _hasChanges = false;

  // Pacientes para el desplegable
  List<Paciente> _pacientes = [];
  bool _isLoadingPacientes = true;

  // Valores para el desplegable de actividad física
  final List<String> _tiposActividad = [
    "Sedentaria",
    "Ligera",
    "Moderada",
    "Intensa",
    "Muy Intensa"
  ];

  late ApiService _apiService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    //  _apiService = Provider.of<ApiService>(context);
  }

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    if (!_isForSpecificPaciente) {
      _loadPacientes();
    } else {
      _isLoadingPacientes = false;
      _selectedPacienteId = widget.paciente!.codigo;
    }

    if (_isEditing) {
      final m = widget.medicion!;
      _selectedPacienteId = m.codigoPaciente;
      _fecha = m.fecha;
      _pesoController.text = m.peso?.toString() ?? '';
      _caderaController.text = m.cadera?.toString() ?? '';
      _cinturaController.text = m.cintura?.toString() ?? '';
      _musloController.text = m.muslo?.toString() ?? '';
      _brazoController.text = m.brazo?.toString() ?? '';
      _actividadFisica = _tiposActividad.contains(m.actividadFisica)
          ? m.actividadFisica
          : null;
      _pliegueAbdominalController.text = m.pliegueAbdominal?.toString() ?? '';
      _pliegueCuadricipitalController.text =
          m.pliegueCuadricipital?.toString() ?? '';
      _plieguePeronealController.text = m.plieguePeroneal?.toString() ?? '';
      _pliegueSubescapularController.text =
          m.pliegueSubescapular?.toString() ?? '';
      _pliegueTricipitalController.text = m.pligueTricipital?.toString() ?? '';
      _pliegueSuprailiacoController.text =
          m.pliegueSuprailiaco?.toString() ?? '';
      _observacionController.text = m.observacion ?? '';
    }
  }

  void _loadPacientes() async {
    try {
      final pacientes = await _apiService.getPacientes();
      if (mounted) {
        setState(() {
          _pacientes = pacientes;
          _isLoadingPacientes = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingPacientes = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error al cargar pacientes: $e"),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  void dispose() {
    _pesoController.dispose();
    _caderaController.dispose();
    _cinturaController.dispose();
    _musloController.dispose();
    _brazoController.dispose();
    _pliegueAbdominalController.dispose();
    _pliegueCuadricipitalController.dispose();
    _plieguePeronealController.dispose();
    _pliegueSubescapularController.dispose();
    _pliegueTricipitalController.dispose();
    _pliegueSuprailiacoController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final medicionData = Medicion(
        codigo: widget.medicion?.codigo ?? 0,
        codigoPaciente: _selectedPacienteId!,
        fecha: _fecha,
        peso: double.tryParse(_pesoController.text),
        cadera: double.tryParse(_caderaController.text),
        cintura: double.tryParse(_cinturaController.text),
        muslo: double.tryParse(_musloController.text),
        brazo: double.tryParse(_brazoController.text),
        actividadFisica: _actividadFisica,
        pliegueAbdominal: double.tryParse(_pliegueAbdominalController.text),
        pliegueCuadricipital:
            double.tryParse(_pliegueCuadricipitalController.text),
        plieguePeroneal: double.tryParse(_plieguePeronealController.text),
        pliegueSubescapular:
            double.tryParse(_pliegueSubescapularController.text),
        pligueTricipital: double.tryParse(_pliegueTricipitalController.text),
        pliegueSuprailiaco: double.tryParse(_pliegueSuprailiacoController.text),
        observacion: _observacionController.text,
      );

      try {
        bool success;
        if (widget.medicion != null) {
          success = await _apiService.updateMedicion(medicionData);
        } else {
          success = await _apiService.createMedicion(medicionData);
        }

        if (success) {
          // Mostrar mensaje según sea alta o modificación
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.medicion == null
                  ? 'Medición añadida correctamente'
                  : 'Medición modificada correctamente'),
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

  Widget _buildNumericField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
      ],
    );
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
          title: Text(_isEditing ? 'Editar Medición' : 'Nueva Medición'),
          actions: [
            IconButton(icon: const Icon(Icons.save), onPressed: _submitForm)
          ],
        ),
        body: SafeArea(
          child: _isLoadingPacientes
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    onChanged: _markDirty,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isForSpecificPaciente)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person),
                            title: Text(widget.paciente!.nombre,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Paciente'),
                          )
                        else
                          DropdownButtonFormField<int>(
                            initialValue: _selectedPacienteId,
                            decoration:
                                const InputDecoration(labelText: 'Paciente'),
                            items: _pacientes.map((paciente) {
                              return DropdownMenuItem<int>(
                                value: paciente.codigo,
                                child: Text(paciente.nombre),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedPacienteId = value;
                              });
                            },
                            validator: (value) =>
                                value == null ? 'Selecciona un paciente' : null,
                          ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              'Fecha: ${DateFormat('dd/MM/yyyy').format(_fecha)}'),
                          trailing: const Icon(Icons.calendar_month),
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _fecha,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                _fecha = pickedDate;
                              });
                            }
                          },
                        ),
                        _buildNumericField(_pesoController, 'Peso (kg)'),
                        DropdownButtonFormField<String>(
                          initialValue: _actividadFisica,
                          decoration: const InputDecoration(
                              labelText: 'Actividad Física'),
                          items: _tiposActividad
                              .map((actividad) => DropdownMenuItem(
                                  value: actividad, child: Text(actividad)))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _actividadFisica = value),
                          validator: (value) => value == null
                              ? 'Selecciona un nivel de actividad'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text("Medidas Corporales (cm)",
                            style: Theme.of(context).textTheme.titleMedium),
                        _buildNumericField(_caderaController, 'Cadera (cm)'),
                        _buildNumericField(_cinturaController, 'Cintura (cm)'),
                        _buildNumericField(_musloController, 'Muslo (cm)'),
                        _buildNumericField(_brazoController, 'Brazo (cm)'),
                        const SizedBox(height: 20),
                        ExpansionTile(
                          title: Text("Pliegues Cutáneos (mm)",
                              style: Theme.of(context).textTheme.titleMedium),
                          initiallyExpanded: _expandPliegues,
                          onExpansionChanged: (expanded) {
                            setState(() => _expandPliegues = expanded);
                          },
                          children: [
                            _buildNumericField(_pliegueAbdominalController,
                                'Pliegue abdominal'),
                            _buildNumericField(_pliegueCuadricipitalController,
                                'Pliegue cuadricipital'),
                            _buildNumericField(
                                _plieguePeronealController, 'Pliegue peroneal'),
                            _buildNumericField(_pliegueSubescapularController,
                                'Pliegue subescapular'),
                            _buildNumericField(_pliegueTricipitalController,
                                'Pliegue tricipital'),
                            _buildNumericField(_pliegueSuprailiacoController,
                                'Pliegue suprailíaco'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _observacionController,
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
