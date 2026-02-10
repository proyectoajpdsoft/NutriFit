import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/cliente.dart';
import 'package:nutri_app/models/cobro.dart';
import 'package:nutri_app/models/paciente.dart';
import '../../widgets/unsaved_changes_dialog.dart';
import 'package:nutri_app/services/api_service.dart';

enum OrigenCobro { paciente, cliente }

class CobroEditScreen extends StatefulWidget {
  final Cobro? cobro;
  final Paciente? paciente;

  const CobroEditScreen({super.key, this.cobro, this.paciente});

  @override
  _CobroEditScreenState createState() => _CobroEditScreenState();
}

class _CobroEditScreenState extends State<CobroEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  bool _hasChanges = false;

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

  late Future<List<Paciente>> _pacientesFuture;
  late Future<List<Cliente>> _clientesFuture;
  late FocusNode _importeFocusNode;

  bool get _isEditing => widget.cobro != null;

  // Controllers
  final _importeController = TextEditingController();
  final _descripcionController = TextEditingController();

  // Form data
  DateTime _fecha = DateTime.now();
  OrigenCobro _origen = OrigenCobro.paciente;
  int? _selectedPacienteId;
  int? _selectedClienteId;

  @override
  void initState() {
    super.initState();
    _importeFocusNode = FocusNode();
    _pacientesFuture = _apiService.getPacientes();
    _clientesFuture = _apiService.getClientes();

    if (_isEditing) {
      final c = widget.cobro!;
      _fecha = c.fecha;
      _importeController.text = c.importe.toString();
      _descripcionController.text = c.descripcion ?? '';
      if (c.codigoPaciente != null) {
        _origen = OrigenCobro.paciente;
        _selectedPacienteId = c.codigoPaciente;
      } else if (c.codigoCliente != null) {
        _origen = OrigenCobro.cliente;
        _selectedClienteId = c.codigoCliente;
      }
    } else if (widget.paciente != null) {
      // Si es un nuevo cobro y viene con un paciente preseleccionado
      _origen = OrigenCobro.paciente;
      _selectedPacienteId = widget.paciente!.codigo;
      // Enfocar el campo de importe después de que se construya la UI
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _importeFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _importeController.dispose();
    _descripcionController.dispose();
    _importeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final cobroData = Cobro(
        codigo: widget.cobro?.codigo ?? 0,
        fecha: _fecha,
        importe: double.parse(_importeController.text),
        descripcion: _descripcionController.text,
        codigoPaciente:
            _origen == OrigenCobro.paciente ? _selectedPacienteId : null,
        codigoCliente:
            _origen == OrigenCobro.cliente ? _selectedClienteId : null,
      );

      try {
        bool success;
        if (_isEditing) {
          success = await _apiService.updateCobro(cobroData);
        } else {
          success = await _apiService.createCobro(cobroData);
        }
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isEditing
                    ? 'Cobro modificado correctamente'
                    : 'Cobro añadido correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true);
          }
        } else {
          // Si el servidor indica que no fue exitoso pero no lanzó una excepción, manejamos aquí.
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Error al guardar el cobro'),
              backgroundColor: Colors.red));
        }
      } catch (e) {
        // Aquí capturamos la excepción que ahora contiene el response.body del servidor PHP
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al guardar el cobro: ${e.toString()}'),
            backgroundColor: Colors.red));
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
          title: Text(_isEditing ? 'Editar Cobro' : 'Nuevo Cobro'),
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
                          lastDate: DateTime(2101));
                      if (pickedDate != null) {
                        setState(() => _fecha = pickedDate);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Origen del Cobro',
                      style: Theme.of(context).textTheme.titleMedium),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<OrigenCobro>(
                          title: const Text('Paciente'),
                          value: OrigenCobro.paciente,
                          groupValue: _origen,
                          onChanged: (value) => setState(() {
                            _origen = value!;
                            _selectedClienteId = null;
                          }),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<OrigenCobro>(
                          title: const Text('Cliente'),
                          value: OrigenCobro.cliente,
                          groupValue: _origen,
                          onChanged: (value) => setState(() {
                            _origen = value!;
                            _selectedPacienteId = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  if (_origen == OrigenCobro.paciente)
                    _buildPacientesDropdown(),
                  if (_origen == OrigenCobro.cliente) _buildClientesDropdown(),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _importeController,
                    focusNode: _importeFocusNode,
                    decoration: const InputDecoration(labelText: 'Importe (€)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'El importe es obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descripcionController,
                    decoration: const InputDecoration(
                        labelText: 'Descripción', border: OutlineInputBorder()),
                    maxLines: 3,
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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return DropdownButtonFormField<int>(
          initialValue: _selectedPacienteId,
          decoration: const InputDecoration(labelText: 'Seleccionar Paciente'),
          items: snapshot.data!
              .map((paciente) => DropdownMenuItem(
                  value: paciente.codigo, child: Text(paciente.nombre)))
              .toList(),
          onChanged: (value) => setState(() => _selectedPacienteId = value),
          validator: (value) => value == null ? 'Selecciona un paciente' : null,
        );
      },
    );
  }

  Widget _buildClientesDropdown() {
    return FutureBuilder<List<Cliente>>(
      future: _clientesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return DropdownButtonFormField<int>(
          initialValue: _selectedClienteId,
          decoration: const InputDecoration(labelText: 'Seleccionar Cliente'),
          items: snapshot.data!
              .map((cliente) => DropdownMenuItem(
                  value: cliente.codigo, child: Text(cliente.nombre)))
              .toList(),
          onChanged: (value) => setState(() => _selectedClienteId = value),
          validator: (value) => value == null ? 'Selecciona un cliente' : null,
        );
      },
    );
  }
}
