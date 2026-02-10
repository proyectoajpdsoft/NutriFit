import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/revision.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:provider/provider.dart';

class RevisionEditScreen extends StatefulWidget {
  final Revision? revision;
  final Paciente?
      paciente; // Hacemos opcional para permitir la creación sin paciente pre-seleccionado

  const RevisionEditScreen({super.key, this.revision, this.paciente});

  @override
  _RevisionEditScreenState createState() => _RevisionEditScreenState();
}

class _RevisionEditScreenState extends State<RevisionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool get _isEditing => widget.revision != null;

  // Data for the form
  int? _selectedPacienteId;
  List<Paciente> _pacientes =
      []; // Para el desplegable cuando no hay paciente preseleccionado
  bool _isLoadingPacientes = true; // Para el desplegable

  // Controladores
  final _asuntoController = TextEditingController();
  final _semanasController = TextEditingController();
  final _modificacionDietaController = TextEditingController();
  final _pesoController = TextEditingController();

  // Otros campos
  DateTime? _fechaPrevista;
  DateTime? _fechaRealizacion;
  bool _completada = false;
  bool _online = false;
  bool _hasChanges = false;
  late ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();

    if (widget.paciente != null) {
      // Si se pasa un paciente, lo usamos directamente y no cargamos la lista completa
      _selectedPacienteId = widget.paciente!.codigo;
      _isLoadingPacientes = false;
    } else {
      // Si no se pasa un paciente, cargamos la lista para el desplegable
      _loadPacientes();
    }

    if (_isEditing) {
      final r = widget.revision!;
      _selectedPacienteId = r.codigoPaciente;
      _asuntoController.text = r.asunto;
      _semanasController.text = r.semanas;
      _modificacionDietaController.text = r.modificacionDieta ?? '';
      _pesoController.text = r.peso?.toString() ?? '';
      _fechaPrevista = r.fechaPrevista;
      _fechaRealizacion = r.fechaRealizacion;
      _completada = r.completada == 'S';
      _online = r.online == 'S';
    } else {
      // Nueva revisión: fecha prevista hoy y aplicar valores por defecto de configuración
      _fechaPrevista = DateTime.now();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDefaultValues();
      });
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

  void _loadDefaultValues() {
    final configService = Provider.of<ConfigService>(context, listen: false);
    setState(() {
      _completada = configService.defaultCompletadaRevision;
      _online = configService.defaultOnlineRevision;
    });
  }

  void _loadPacientes() async {
    setState(() {
      _isLoadingPacientes = true;
    });
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
    _asuntoController.dispose();
    _semanasController.dispose();
    _modificacionDietaController.dispose();
    _pesoController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context,
      {required bool isPrevista}) async {
    final initialDate = isPrevista
        ? (_fechaPrevista ?? DateTime.now())
        : (_fechaRealizacion ?? DateTime.now());

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('es', 'ES'),
      keyboardType: TextInputType.datetime,
      helpText: 'Introduzca la fecha (dd/mm/yyyy)',
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;

    setState(() {
      final newDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isPrevista) {
        _fechaPrevista = newDateTime;
      } else {
        _fechaRealizacion = newDateTime;
      }
    });
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final revisionData = Revision(
        codigo: widget.revision?.codigo ?? 0,
        codigoPaciente: _selectedPacienteId,
        asunto: _asuntoController.text,
        semanas: _semanasController.text,
        modificacionDieta: _modificacionDietaController.text,
        peso: double.tryParse(_pesoController.text),
        fechaPrevista: _fechaPrevista,
        fechaRealizacion: _fechaRealizacion,
        completada: _completada ? 'S' : 'N',
        online: _online ? 'S' : 'N',
      );

      try {
        bool success;
        if (widget.revision != null) {
          success = await _apiService.updateRevision(revisionData);
        } else {
          success = await _apiService.createRevision(revisionData);
        }

        if (success) {
          // Mostrar mensaje según sea alta o modificación
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.revision == null
                  ? 'Revisión añadida correctamente'
                  : 'Revisión modificada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
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
          title: Text(_isEditing ? 'Editar Revisión' : 'Nueva Revisión'),
          actions: [
            IconButton(icon: const Icon(Icons.save), onPressed: _submitForm)
          ],
        ),
        body: SafeArea(
          child: _isLoadingPacientes &&
                  widget.paciente ==
                      null // Show loading only if no patient is provided and still loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    onChanged: _markDirty,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.paciente !=
                            null) // Si el paciente viene del constructor, se muestra su nombre
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person),
                            title: Text(widget.paciente!.nombre,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Paciente'),
                          )
                        else // Si no viene, se muestra el desplegable para seleccionarlo
                          DropdownButtonFormField<int?>(
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
                        TextFormField(
                          controller: _asuntoController,
                          decoration:
                              const InputDecoration(labelText: 'Asunto'),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'El asunto es obligatorio'
                              : null,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              'Fecha Prevista: ${_fechaPrevista == null ? 'No seleccionada' : DateFormat('dd/MM/yyyy HH:mm').format(_fechaPrevista!)}'),
                          trailing: const Icon(Icons.calendar_month),
                          onTap: () =>
                              _selectDateTime(context, isPrevista: true),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              'Fecha Realización: ${_fechaRealizacion == null ? 'No seleccionada' : DateFormat('dd/MM/yyyy HH:mm').format(_fechaRealizacion!)}'),
                          trailing: const Icon(Icons.calendar_month),
                          onTap: () =>
                              _selectDateTime(context, isPrevista: false),
                        ),
                        SwitchListTile(
                          title: const Text('Completada'),
                          value: _completada,
                          onChanged: (value) =>
                              setState(() => _completada = value),
                        ),
                        SwitchListTile(
                          title: const Text('Online'),
                          value: _online,
                          onChanged: (value) => setState(() => _online = value),
                        ),
                        TextFormField(
                          controller: _semanasController,
                          decoration:
                              const InputDecoration(labelText: 'Semanas'),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Las semanas son obligatorias'
                              : null,
                        ),
                        TextFormField(
                          controller: _pesoController,
                          decoration:
                              const InputDecoration(labelText: 'Peso (Kg)'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'))
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _modificacionDietaController,
                          decoration: const InputDecoration(
                            labelText: 'Modificación de la dieta',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 5,
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
