import 'dart:convert'; // <-- IMPORT AÑADIDO
import 'package:flutter/material.dart';
import 'package:nutri_app/models/entrevista.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/plan_nutricional.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PlanEditScreen extends StatefulWidget {
  // Ahora el paciente puede ser nulo, si se crea un plan desde cero
  final Paciente? paciente;
  final PlanNutricional? plan;

  const PlanEditScreen({super.key, this.paciente, this.plan});

  @override
  _PlanEditScreenState createState() => _PlanEditScreenState();
}

class _PlanEditScreenState extends State<PlanEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  Future<List<Entrevista>>? _entrevistasFuture;
  late Future<List<Paciente>> _pacientesFuture;
  DateTime? _desde;
  DateTime? _hasta;
  int? _codigoEntrevista;
  String _indicaciones = '';
  String _indicacionesUsuario = '';
  String _url = '';
  PlatformFile? _pickedFile;
  bool _completado = false;
  bool _hasChanges = false;
  // Ahora _selectedPacienteId puede ser nulo si el campo en la BD lo permite
  int? _selectedPacienteId;
  late TextEditingController _semanasController;

  bool get _isEditing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    _pacientesFuture = _apiService.getPacientes();

    // Inicializar el controlador de semanas
    _semanasController = TextEditingController(text: widget.plan?.semanas);

    if (_isEditing) {
      final p = widget.plan!;
      _selectedPacienteId = p.codigoPaciente;
      _desde = p.desde;
      _hasta = p.hasta;
      _codigoEntrevista = p.codigoEntrevista;
      _indicaciones = p.planIndicaciones ?? '';
      _indicacionesUsuario = p.planIndicacionesVisibleUsuario ?? '';
      _url = p.url ?? '';
      _completado = p.completado == 'S';
      // Solo cargar entrevistas si hay paciente seleccionado
      if (_selectedPacienteId != null) {
        _entrevistasFuture = _apiService.getEntrevistas(_selectedPacienteId!);
      }
    } else {
      _selectedPacienteId = widget.paciente?.codigo;
      _desde = null; // No son obligatorios inicialmente
      _hasta = null; // No son obligatorios inicialmente
      _loadDefaultValues();
      // Solo cargar entrevistas si ya viene con un paciente
      if (_selectedPacienteId != null) {
        _entrevistasFuture = _apiService.getEntrevistas(_selectedPacienteId!);
      }
    }
  }

  void _loadDefaultValues() {
    final configService = context.read<ConfigService>();
    setState(() {
      _completado = configService.defaultCompletadaPlan;
      _semanasController.text = configService.defaultSemanasPlan ?? '';
    });
  }

  @override
  void dispose() {
    _semanasController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Validar que se seleccione un paciente
      if (_selectedPacienteId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Debes seleccionar un paciente'),
            backgroundColor: Colors.red));
        return;
      }

      // --- SOLUCIÓN PARA NULL CHECK OPERATOR Y CAMPOS NULOS ---
      // codigoPaciente, desde, hasta, completado pueden ser nulos según la BD
      final planData = PlanNutricional(
        codigo: _isEditing ? widget.plan!.codigo : 0,
        codigoPaciente: _selectedPacienteId, // Ahora puede ser nulo
        desde: _desde,
        hasta: _hasta,
        semanas: _semanasController.text,
        codigoEntrevista: _codigoEntrevista,
        planIndicaciones: _indicaciones,
        planIndicacionesVisibleUsuario: _indicacionesUsuario,
        url: _url,
        planDocumentoNombre:
            _pickedFile?.name ?? widget.plan?.planDocumentoNombre,
        completado: _completado ? 'S' : 'N',
      );

      // --- INICIO DEPURACIÓN ---
      debugPrint("DEBUG PLAN: Enviando JSON a la API:");
      debugPrint(jsonEncode(planData.toJson()));
      // --- FIN DEPURACIÓN ---

      try {
        bool success;
        if (_isEditing) {
          success = await _apiService.updatePlan(planData, _pickedFile?.path);
        } else {
          success = await _apiService.createPlan(planData, _pickedFile?.path);
        }
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isEditing
                    ? 'Plan modificado correctamente'
                    : 'Plan añadido correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Error al guardar el plan'),
              backgroundColor: Colors.red));
        }
      } catch (e) {
        // --- LÓGICA DE ERROR DUAL (DEBUG/NORMAL) ---
        // (Esta parte ya es correcta y no necesita cambios)
        // ...
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
          title: Text(_isEditing ? 'Editar Plan' : 'Nuevo Plan'),
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
                  _buildPacientesDropdown(),
                  const SizedBox(height: 16),
                  _buildDatePicker(
                    label: 'Desde',
                    selectedDate: _desde,
                    onChanged: (newDate) {
                      setState(() => _desde = newDate);
                    },
                    // --- FECHAS YA NO SON OBLIGATORIAS SEGÚN LA BD ---
                    // validator: (date) => date == null ? 'La fecha de inicio es obligatoria' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildDatePicker(
                    label: 'Hasta',
                    selectedDate: _hasta,
                    onChanged: (newDate) {
                      setState(() => _hasta = newDate);
                    },
                    // --- FECHAS YA NO SON OBLIGATORIAS SEGÚN LA BD ---
                    // validator: (date) => date == null ? 'La fecha de fin es obligatoria' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _semanasController,
                    decoration: const InputDecoration(
                        labelText: 'Semanas', border: OutlineInputBorder()),
                    onSaved: (value) => _semanasController.text = value ?? '',
                  ),
                  const SizedBox(height: 16),
                  _buildEntrevistasDropdown(),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _indicaciones,
                    decoration: const InputDecoration(
                        labelText: 'Indicaciones (para el profesional)',
                        border: OutlineInputBorder()),
                    maxLines: 3,
                    onSaved: (value) => _indicaciones = value ?? '',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _indicacionesUsuario,
                    decoration: const InputDecoration(
                        labelText: 'Indicaciones (visibles para el usuario)',
                        border: OutlineInputBorder()),
                    maxLines: 3,
                    onSaved: (value) => _indicacionesUsuario = value ?? '',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _url,
                    decoration: const InputDecoration(
                        labelText: 'URL', border: OutlineInputBorder()),
                    onSaved: (value) => _url = value ?? '',
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Completado'),
                    value: _completado,
                    onChanged: (value) => setState(() => _completado = value),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text('Archivo del Plan',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Seleccionar'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _pickedFile?.name ??
                              widget.plan?.planDocumentoNombre ??
                              'Ningún archivo seleccionado',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPacientesDropdown() {
    return FutureBuilder<List<Paciente>>(
      future: _pacientesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text("Error al cargar pacientes: ${snapshot.error}");
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text("No hay pacientes disponibles.");
        }

        final pacientes = snapshot.data!;
        return DropdownButtonFormField<int>(
          initialValue: _selectedPacienteId,
          decoration: const InputDecoration(labelText: 'Paciente'),
          items: pacientes
              .map((paciente) => DropdownMenuItem(
                  value: paciente.codigo, child: Text(paciente.nombre)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedPacienteId = value;
              // Cargar entrevistas del paciente seleccionado
              if (value != null) {
                _entrevistasFuture = _apiService.getEntrevistas(value);
                _codigoEntrevista = null; // Reset entrevista seleccionada
              } else {
                _entrevistasFuture = null;
                _codigoEntrevista = null;
              }
            });
          },
          validator: (value) => value == null ? 'Selecciona un paciente' : null,
        );
      },
    );
  }

  Widget _buildEntrevistasDropdown() {
    // Si no hay paciente seleccionado, mostrar dropdown deshabilitado
    if (_selectedPacienteId == null || _entrevistasFuture == null) {
      return DropdownButtonFormField<int?>(
        initialValue: null,
        decoration: const InputDecoration(
          labelText: 'Entrevista Relacionada (opcional)',
          hintText: 'Selecciona primero un paciente',
        ),
        items: const [DropdownMenuItem(value: null, child: Text('Ninguna'))],
        onChanged: null, // Deshabilitado
      );
    }

    return FutureBuilder<List<Entrevista>>(
      future: _entrevistasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          // --- REPORTE DE ERROR MEJORADO PARA EL DESPLEGABLE DE ENTREVISTAS ---
          return DropdownButtonFormField<int?>(
            initialValue: null,
            decoration: const InputDecoration(
              labelText: 'Entrevista Relacionada (opcional)',
              errorText: 'Error al cargar entrevistas',
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('Ninguna'))
            ],
            onChanged: (value) => setState(() => _codigoEntrevista = value),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Si no hay entrevistas, o el paciente seleccionado no tiene, no es un error.
          // Simplemente ofrecemos la opción de 'Ninguna'.
          return DropdownButtonFormField<int?>(
            initialValue: _codigoEntrevista,
            decoration: const InputDecoration(
                labelText: 'Entrevista Relacionada (opcional)'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Ninguna'))
            ],
            onChanged: (value) => setState(() => _codigoEntrevista = value),
          );
        }

        final todasLasEntrevistas = snapshot.data!;
        // Ya no es necesario filtrar por paciente, ya que la API devuelve solo las del paciente seleccionado

        return DropdownButtonFormField<int?>(
          initialValue: _codigoEntrevista,
          decoration: const InputDecoration(
              labelText: 'Entrevista Relacionada (opcional)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Ninguna')),
            ...todasLasEntrevistas
                .map((entrevista) => DropdownMenuItem(
                    value: entrevista.codigo,
                    child: Text(
                        'Entrevista ${DateFormat('dd/MM/yyyy').format(entrevista.fechaRealizacion ?? DateTime.now())}')))
                .toList(),
          ],
          onChanged: (value) => setState(() => _codigoEntrevista = value),
        );
      },
    );
  }

  // El _buildDatePicker se modifica para aceptar un validador
  Widget _buildDatePicker({
    required String label,
    required DateTime? selectedDate,
    required ValueChanged<DateTime?> onChanged, // Añadido
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
          '$label: ${selectedDate != null ? DateFormat('dd/MM/yyyy').format(selectedDate) : 'No establecida'}'),
      trailing: const Icon(Icons.calendar_month),
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
          locale: const Locale('es', 'ES'),
          keyboardType: TextInputType.datetime,
          helpText: 'Introduzca la fecha (dd/mm/yyyy)',
        );
        onChanged(pickedDate);
      },
    );
  }
}
