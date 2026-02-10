import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:provider/provider.dart'; // <-- IMPORT AÑADIDO
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';

// Para acceder al ApiService
class PacienteEditScreen extends StatefulWidget {
  final Paciente? paciente;

  const PacienteEditScreen({super.key, this.paciente});

  @override
  State<PacienteEditScreen> createState() => _PacienteEditScreenState();
}

class _PacienteEditScreenState extends State<PacienteEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  bool _hasChanges = false;

  // --- CONTROLADORES PARA LOS CAMPOS DEL FORMULARIO ---
  late TextEditingController _nombreController;
  late TextEditingController _dniController;
  late TextEditingController _edadController;
  late TextEditingController _alturaController;
  late TextEditingController _pesoController;
  late TextEditingController _telefonoController;
  late TextEditingController _email1Controller;
  late TextEditingController _email2Controller;
  late TextEditingController _observacionController;

  // --- VARIABLES PARA OTROS DATOS ---
  DateTime? _fechaNacimiento;
  String? _sexo;
  bool _online = false;
  bool _activo = true; // Nuevo campo 'activo', por defecto true

  @override
  void initState() {
    super.initState();
    final p = widget.paciente;
    _nombreController = TextEditingController(text: p?.nombre);
    _dniController = TextEditingController(text: p?.dni);
    _edadController = TextEditingController(text: p?.edad?.toString());
    _alturaController = TextEditingController(text: p?.altura?.toString());
    _pesoController = TextEditingController(text: p?.peso?.toString());
    _telefonoController = TextEditingController(text: p?.telefono);
    _email1Controller = TextEditingController(text: p?.email1);
    _email2Controller = TextEditingController(text: p?.email2);
    _observacionController = TextEditingController(text: p?.observacion);

    _fechaNacimiento = p?.fechaNacimiento;
    _sexo = p?.sexo;
    _online = p?.online == 'S';
    _activo = p?.activo == 'S'; // Inicializar activo

    // Cargar valores por defecto si es un nuevo paciente
    if (p == null) {
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
    final configService = context.read<ConfigService>();
    setState(() {
      _online = configService.defaultOnlinePaciente;
      _activo = configService.defaultActivoPaciente;
      if (configService.defaultSexoPaciente != null) {
        _sexo = configService.defaultSexoPaciente;
      }
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _dniController.dispose();
    _edadController.dispose();
    _alturaController.dispose();
    _pesoController.dispose();
    _telefonoController.dispose();
    _email1Controller.dispose();
    _email2Controller.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _fechaNacimiento) {
      setState(() {
        _fechaNacimiento = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final pacienteData = Paciente(
        codigo: widget.paciente?.codigo ?? 0,
        nombre: _nombreController.text,
        // Se recogen el resto de datos de los controladores del formulario
        dni: _dniController.text,
        fechaNacimiento: _fechaNacimiento,
        sexo: _sexo,
        edad: int.tryParse(_edadController.text),
        altura: int.tryParse(_alturaController.text),
        peso: double.tryParse(_pesoController.text),
        telefono: _telefonoController.text,
        email1: _email1Controller.text,
        email2: _email2Controller.text,
        activo: _activo ? 'S' : 'N', // Enviar activo
        online: _online ? 'S' : 'N',
        observacion: _observacionController.text,
        // Se añaden los campos restantes, usando los valores originales si existen
        calle: widget.paciente?.calle,
        codigoPostal: widget.paciente?.codigoPostal,
        provincia: widget.paciente?.provincia,
        pais: widget.paciente?.pais,
      );

      // --- INICIO DEPURACIÓN ---
      // Imprimimos el JSON que se va a enviar a la API en la consola de depuración.
      //debugPrint("DEBUG: Enviando JSON a la API:");
      //debugPrint(jsonEncode(pacienteData.toJson()));
      // --- FIN DEPURACIÓN ---

      try {
        bool success;
        if (widget.paciente != null) {
          success = await _apiService.updatePaciente(pacienteData);
        } else {
          success = await _apiService.createPaciente(pacienteData);
        }

        if (success) {
          // Mostrar mensaje según sea alta o modificación
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.paciente == null
                  ? 'Paciente añadido correctamente'
                  : 'Paciente modificado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Devolver true para indicar éxito
        }
      } catch (e) {
        // --- LÓGICA DE ERROR DUAL (DEBUG/NORMAL) ---
        final configService = context.read<ConfigService>();

        if (configService.appMode == AppMode.debug) {
          // MODO DEBUG: Muestra un diálogo con el error completo.
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error Detallado de la API'),
              content: SingleChildScrollView(child: Text(e.toString())),
              actions: [
                TextButton(
                  child: const Text('Cerrar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        } else {
          // MODO NORMAL: Muestra un mensaje genérico.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Error al guardar el paciente'),
                backgroundColor: Colors.red),
          );
        }
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
          title: Text(
              widget.paciente == null ? 'Nuevo Paciente' : 'Editar Paciente'),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _submitForm,
            )
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                onChanged: _markDirty,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, introduce un nombre';
                        }
                        return null;
                      },
                    ),
                    // Campo conmutable para Sexo: Hombre/Mujer
                    const SizedBox(height: 12),
                    FormField<String>(
                      validator: (_) {
                        return _sexo == null ? 'Selecciona el sexo' : null;
                      },
                      builder: (state) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sexo'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('Hombre'),
                                  selected: _sexo == 'Hombre',
                                  onSelected: (selected) {
                                    setState(() {
                                      _sexo = selected ? 'Hombre' : null;
                                    });
                                    state.didChange(_sexo);
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('Mujer'),
                                  selected: _sexo == 'Mujer',
                                  onSelected: (selected) {
                                    setState(() {
                                      _sexo = selected ? 'Mujer' : null;
                                    });
                                    state.didChange(_sexo);
                                  },
                                ),
                              ],
                            ),
                            if (state.hasError)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  state.errorText ?? '',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    TextFormField(
                      controller: _edadController,
                      decoration: const InputDecoration(labelText: 'Edad'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final edad = int.tryParse(value);
                          if (edad == null || edad <= 0 || edad >= 110) {
                            return 'Edad no válida (1-109)';
                          }
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _alturaController,
                      decoration:
                          const InputDecoration(labelText: 'Altura (cm)'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,1}'))
                      ],
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final altura = double.tryParse(value);
                          if (altura == null || altura <= 50 || altura >= 230) {
                            return 'Altura no válida (50-230)';
                          }
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _pesoController,
                      decoration: const InputDecoration(labelText: 'Peso (kg)'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final peso = double.tryParse(value);
                          if (peso == null || peso <= 2 || peso >= 290) {
                            return 'Peso no válido (2-290)';
                          }
                        }
                        return null;
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          "Fecha de nacimiento: ${_fechaNacimiento == null ? 'No seleccionada' : '${_fechaNacimiento!.toLocal()}'.split(' ')[0]}"),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectDate(context),
                    ),
                    TextFormField(
                      controller: _telefonoController,
                      decoration: const InputDecoration(labelText: 'Teléfono'),
                      keyboardType: TextInputType.phone,
                    ),
                    TextFormField(
                      controller: _email1Controller,
                      decoration: const InputDecoration(labelText: 'Email 1'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null &&
                            value.isNotEmpty &&
                            !RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                          return 'Introduce un email válido';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _email2Controller,
                      decoration: const InputDecoration(labelText: 'Email 2'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null &&
                            value.isNotEmpty &&
                            !RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                          return 'Introduce un email válido';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _dniController,
                      decoration: const InputDecoration(labelText: 'DNI'),
                    ),
                    TextFormField(
                      controller: _observacionController,
                      decoration:
                          const InputDecoration(labelText: 'Observación'),
                      maxLines: 3,
                    ),
                    SwitchListTile(
                      title: const Text('Online'),
                      value: _online,
                      onChanged: (bool value) {
                        setState(() {
                          _online = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Activo'),
                      value: _activo,
                      onChanged: (bool value) {
                        setState(() {
                          _activo = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
