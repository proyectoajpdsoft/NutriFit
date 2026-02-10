import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/models/cliente.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:provider/provider.dart';

class ClienteEditScreen extends StatefulWidget {
  final Cliente? cliente;

  const ClienteEditScreen({super.key, this.cliente});

  @override
  _ClienteEditScreenState createState() => _ClienteEditScreenState();
}

class _ClienteEditScreenState extends State<ClienteEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  bool _hasChanges = false;
  late String _nombre;
  late String _cif;
  late String _telefono;
  late String _email;
  late String _direccion;
  late String _poblacion;
  late String _provincia;
  late int _cp;
  late String _personaContacto;
  late String _web;
  late String _observacion;

  bool get _isEditing => widget.cliente != null;

  // Controllers
  final _nombreController = TextEditingController();
  final _cifController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _direccionController = TextEditingController();
  final _poblacionController = TextEditingController();
  final _provinciaController = TextEditingController();
  final _cpController = TextEditingController();
  final _personaContactoController = TextEditingController();
  final _webController = TextEditingController();
  final _observacionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final c = widget.cliente!;
      _nombreController.text = c.nombre;
      _cifController.text = c.cif ?? '';
      _telefonoController.text = c.telefono ?? '';
      _emailController.text = c.email ?? '';
      _direccionController.text = c.direccion ?? '';
      _poblacionController.text = c.poblacion ?? '';
      _provinciaController.text = c.provincia ?? '';
      _cpController.text = c.cp?.toString() ?? '';
      _personaContactoController.text = c.personacontacto ?? '';
      _webController.text = c.web ?? '';
      _observacionController.text = c.observacion ?? '';
    } else {
      // Es un nuevo cliente, aplicamos valores por defecto.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDefaultValues();
      });
    }
  }

  void _loadDefaultValues() {
    final configService = Provider.of<ConfigService>(context, listen: false);
    setState(() {
      _poblacionController.text = configService.defaultPoblacionCliente ?? '';
      _provinciaController.text = configService.defaultProvinciaCliente ?? '';
      _cpController.text = configService.defaultCPCliente ?? '';
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _cifController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _direccionController.dispose();
    _poblacionController.dispose();
    _provinciaController.dispose();
    _cpController.dispose();
    _personaContactoController.dispose();
    _webController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final clienteData = Cliente(
        codigo: widget.cliente?.codigo ?? 0,
        nombre: _nombre,
        cif: _cif,
        telefono: _telefono,
        email: _email,
        direccion: _direccion,
        poblacion: _poblacion,
        provincia: _provincia,
        cp: _cp,
        personacontacto: _personaContacto,
        web: _web,
        observacion: _observacion,
      );
      bool success;
      if (widget.cliente != null) {
        success = await _apiService.updateCliente(clienteData);
      } else {
        success = await _apiService.createCliente(clienteData);
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing
                  ? 'Cliente modificado correctamente'
                  : 'Cliente añadido correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar el cliente'),
            backgroundColor: Colors.red,
          ),
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
          title: Text(_isEditing ? 'Editar Cliente' : 'Nuevo Cliente'),
          actions: [
            IconButton(icon: const Icon(Icons.save), onPressed: _submitForm)
          ],
        ),
        body: SingleChildScrollView(
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
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'El nombre es obligatorio'
                      : null,
                  onSaved: (value) => _nombre = value!,
                ),
                TextFormField(
                  controller: _cifController,
                  decoration: const InputDecoration(labelText: 'CIF/DNI'),
                  onSaved: (value) => _cif = value!,
                ),
                TextFormField(
                  controller: _telefonoController,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  keyboardType: TextInputType.phone,
                  onSaved: (value) => _telefono = value!,
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  onSaved: (value) => _email = value!,
                ),
                TextFormField(
                  controller: _direccionController,
                  decoration: const InputDecoration(labelText: 'Dirección'),
                  onSaved: (value) => _direccion = value!,
                ),
                TextFormField(
                  controller: _poblacionController,
                  decoration: const InputDecoration(labelText: 'Población'),
                  onSaved: (value) => _poblacion = value!,
                ),
                TextFormField(
                  controller: _provinciaController,
                  decoration: const InputDecoration(labelText: 'Provincia'),
                  onSaved: (value) => _provincia = value!,
                ),
                TextFormField(
                  controller: _cpController,
                  decoration: const InputDecoration(labelText: 'Código Postal'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSaved: (value) => _cp = int.parse(value!),
                ),
                TextFormField(
                  controller: _personaContactoController,
                  decoration:
                      const InputDecoration(labelText: 'Persona de Contacto'),
                  onSaved: (value) => _personaContacto = value!,
                ),
                TextFormField(
                  controller: _webController,
                  decoration: const InputDecoration(labelText: 'Página Web'),
                  keyboardType: TextInputType.url,
                  onSaved: (value) => _web = value!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _observacionController,
                  decoration: const InputDecoration(
                    labelText: 'Observación',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  onSaved: (value) => _observacion = value!,
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
