import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/cita.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:provider/provider.dart';

class CitaEditScreen extends StatefulWidget {
  final Cita? cita;
  final DateTime? selectedDate;
  final Paciente? paciente;

  const CitaEditScreen(
      {super.key, this.cita, this.selectedDate, this.paciente});

  @override
  _CitaEditScreenState createState() => _CitaEditScreenState();
}

class _CitaEditScreenState extends State<CitaEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // Datos del formulario
  int? _selectedPacienteId;
  DateTime _comienzo = DateTime.now();
  DateTime _fin = DateTime.now().add(const Duration(hours: 1));
  String? _tipo;
  bool _isOnline = false;
  bool _hasChanges = false;
  String? _estado;
  final _asuntoController = TextEditingController();
  final _citaController = TextEditingController();
  final _ubicacionController = TextEditingController();

  // Listas para desplegables
  List<String> _tiposCita = [];
  bool _isLoadingTipos = true;
  String?
      _tipoOriginalCita; // Guardar el tipo original de la cita para buscarlo después

  final List<String> _estadosCita = [
    "Pendiente",
    "Realizada",
    "Anulada",
    "Aplazada"
  ];

  // Pacientes para el desplegable
  List<Paciente> _pacientes = [];
  bool _isLoadingPacientes = true;

  late ApiService _apiService;

  bool get _isEditing => widget.cita != null;
  bool get _isForSpecificPaciente => widget.paciente != null;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    // Cargar tipos de citas desde la base de datos
    _loadTiposCita();
    // No cargamos pacientes si ya tenemos uno específico
    if (!_isForSpecificPaciente) {
      _loadPacientes();
    } else {
      _isLoadingPacientes = false;
    }

    if (_isEditing) {
      final cita = widget.cita!;
      _selectedPacienteId = cita.codigoPaciente;
      _comienzo = cita.comienzo ?? _comienzo;
      _fin = cita.fin ?? _fin;
      // Guardar el tipo original para buscarlo después cuando se carguen los tipos
      _tipoOriginalCita = (cita.tipo ?? '').replaceAll('"', '');
      _tipo = null; // No asignar hasta que estén cargados los tipos
      _isOnline = cita.online == 'S';
      _estado = _estadosCita.contains(cita.estado) ? cita.estado : null;
      _asuntoController.text = cita.asunto;
      _citaController.text = cita.descripcion ?? '';
      _ubicacionController.text = cita.ubicacion ?? '';
    } else {
      // --- Lógica unificada para NUEVA CITA ---
      // 1. Asignar paciente si viene preseleccionado
      if (_isForSpecificPaciente) {
        _selectedPacienteId = widget.paciente!.codigo;
      }

      // 2. Asignar fecha si viene del calendario
      if (widget.selectedDate != null) {
        _comienzo = widget.selectedDate!;
        _fin = widget.selectedDate!.add(const Duration(hours: 1));
      }

      // 3. Cargar valores por defecto de la configuración
      // Se hace en el primer frame para tener el 'context' disponible.
      _loadDefaultValues();
    }
  }

  void _loadDefaultValues() {
    final configService = Provider.of<ConfigService>(context, listen: false);
    setState(() {
      _tipo = configService.defaultTipoCita;
      _estado = configService.defaultEstadoCita;
      _isOnline = configService.defaultOnlineCita;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Se elimina la lógica de aquí para evitar múltiples llamadas
  }

  Future<void> _loadTiposCita() async {
    try {
      final tiposStr = await _apiService.getParametroValor('tipos_de_citas');
      if (tiposStr != null && tiposStr.isNotEmpty) {
        setState(() {
          // Parsear el string separado por puntos y comas
          // Remover comillas dobles y espacios en blanco
          _tiposCita = tiposStr
              .split(';')
              .map((tipo) => tipo.trim().replaceAll('"', ''))
              .toList();
          _isLoadingTipos = false;

          // Si estamos editando y tenemos un tipo original guardado, buscarlo en la lista cargada
          if (_isEditing &&
              _tipoOriginalCita != null &&
              _tipoOriginalCita!.isNotEmpty) {
            _tipo = _tiposCita.contains(_tipoOriginalCita)
                ? _tipoOriginalCita
                : null;
          }
        });
      } else {
        // Si no hay datos, usar los valores por defecto
        _setDefaultTipos();
      }
    } catch (e) {
      // debugPrint('Error al cargar tipos de citas: $e');
      // Usar valores por defecto en caso de error
      _setDefaultTipos();
    }
  }

  void _setDefaultTipos() {
    setState(() {
      _tiposCita = [
        "Entrevista Nutri",
        "Entrevista Fit",
        "Revisión Nutri",
        "Revisión Fit",
        "Asistencia/Dudas",
        "Charla",
        "Medición",
        "Otro"
      ];
      _isLoadingTipos = false;
    });
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
    _asuntoController.dispose();
    _citaController.dispose();
    _ubicacionController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context, bool isComienzo) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: isComienzo ? _comienzo : _fin,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('es', 'ES'),
      keyboardType: TextInputType.datetime,
      helpText: 'Introduzca la fecha (dd/mm/yyyy)',
    );
    if (date == null) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isComienzo ? _comienzo : _fin),
    );
    if (time == null) return;

    setState(() {
      final newDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isComienzo) {
        _comienzo = newDateTime;
        // Opcional: ajustar automáticamente la hora de fin
        if (_comienzo.isAfter(_fin)) {
          _fin = _comienzo.add(const Duration(hours: 1));
        }
      } else {
        _fin = newDateTime;
      }
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final citaData = Cita(
        codigo: widget.cita?.codigo ?? 0,
        codigoPaciente: _selectedPacienteId,
        comienzo: _comienzo,
        fin: _fin,
        tipo: _tipo,
        online: _isOnline ? 'S' : 'N',
        estado: _estado,
        asunto: _asuntoController.text,
        descripcion: _citaController.text,
        ubicacion: _ubicacionController.text,
      );

      try {
        bool success;
        if (widget.cita != null) {
          success = await _apiService.updateCita(citaData);
        } else {
          success = await _apiService.createCita(citaData);
        }

        if (success) {
          // Mostrar mensaje según sea alta o modificación
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.cita == null
                  ? 'Cita añadida correctamente'
                  : 'Cita modificada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Volver al calendario
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Error al guardar la cita'),
                backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error de conexión: $e'),
              backgroundColor: Colors.red),
        );
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
          title: Text(_isEditing ? 'Editar Cita' : 'Nueva Cita'),
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
                        // Se simplifica esta lógica: o mostramos el nombre o el desplegable
                        if (_isForSpecificPaciente)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person),
                            title: Text(widget.paciente!.nombre,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Paciente'),
                          )
                        else if (_isLoadingPacientes)
                          const Center(child: CircularProgressIndicator())
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
                              'Empieza: ${DateFormat('dd/MM/yyyy HH:mm').format(_comienzo)}'),
                          trailing: const Icon(Icons.calendar_month),
                          onTap: () => _selectDateTime(context, true),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              'Acaba:    ${DateFormat('dd/MM/yyyy HH:mm').format(_fin)}'),
                          trailing: const Icon(Icons.calendar_month),
                          onTap: () => _selectDateTime(context, false),
                        ),
                        DropdownButtonFormField<String>(
                          // Usamos 'value' en lugar de 'initialValue' para que el widget se reconstruya
                          // cuando el estado (_tipo) cambie por los valores por defecto.
                          initialValue: _tipo,
                          decoration: InputDecoration(
                            labelText: 'Tipo',
                            helperText:
                                _isLoadingTipos ? 'Cargando tipos...' : null,
                          ),
                          items: _tiposCita
                              .map((tipo) => DropdownMenuItem(
                                  value: tipo, child: Text(tipo)))
                              .toList(),
                          onChanged: _isLoadingTipos
                              ? null
                              : (value) => setState(() => _tipo = value),
                          validator: (value) =>
                              value == null ? 'Selecciona un tipo' : null,
                        ),
                        SwitchListTile(
                          title: const Text('Online'),
                          value: _isOnline,
                          onChanged: (value) =>
                              setState(() => _isOnline = value),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _estado,
                          decoration:
                              const InputDecoration(labelText: 'Estado'),
                          items: _estadosCita
                              .map((estado) => DropdownMenuItem(
                                  value: estado, child: Text(estado)))
                              .toList(),
                          onChanged: (value) => setState(() => _estado = value),
                          validator: (value) =>
                              value == null ? 'Selecciona un estado' : null,
                        ),
                        TextFormField(
                          controller: _asuntoController,
                          decoration:
                              const InputDecoration(labelText: 'Asunto'),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Introduce un asunto'
                              : null,
                        ),
                        TextFormField(
                          controller: _citaController,
                          decoration: const InputDecoration(
                              labelText: 'Cita (Descripción)'),
                          maxLines: 4,
                        ),
                        TextFormField(
                          controller: _ubicacionController,
                          decoration:
                              const InputDecoration(labelText: 'Ubicación'),
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
