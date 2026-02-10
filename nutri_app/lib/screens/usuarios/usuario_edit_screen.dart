import 'package:flutter/material.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/widgets/profile_image_picker.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';

class UsuarioEditScreen extends StatefulWidget {
  final Usuario? usuario;

  const UsuarioEditScreen({super.key, this.usuario});

  @override
  _UsuarioEditScreenState createState() => _UsuarioEditScreenState();
}

class _UsuarioEditScreenState extends State<UsuarioEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  late Future<List<Paciente>> _pacientesFuture;
  bool _isLoadingDefaults = true;
  bool _hasChanges = false;

  // Controllers
  late String _nick = '';
  late String _password = '';
  String? _nombre;
  String? _email;
  String? _tipo;
  int? _codigoPaciente;
  bool _activo = true;
  bool _accesoWeb = true;
  String? _imageBase64;

  final List<String> _tiposUsuario = ['Usuario', 'Paciente', 'Nutricionista'];

  @override
  void initState() {
    super.initState();
    _pacientesFuture = _apiService.getPacientes();

    if (widget.usuario != null) {
      final u = widget.usuario!;
      _nick = u.nick;
      _nombre = u.nombre;
      _email = u.email;
      _tipo = u.tipo;
      _codigoPaciente = u.codigoPaciente;
      _activo = u.activo == 'S';
      _accesoWeb = u.accesoweb == 'S';
      _imageBase64 = u.imgPerfil;
      _isLoadingDefaults = false;
    } else {
      // Si es nuevo usuario, cargar valores por defecto locales
      _loadDefaults();
    }
  }

  void _loadDefaults() {
    final configService = context.read<ConfigService>();
    _tipo = configService.defaultTipoUsuario;
    _activo = configService.defaultActivoUsuario;
    _accesoWeb = configService.defaultAccesoUsuario;
    setState(() => _isLoadingDefaults = false);
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

  void _handleImageChanged(String? newImage) {
    setState(() {
      _imageBase64 = newImage;
    });
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Si se asocia un paciente y el tipo no es Nutricionista, cambiar a Paciente
      if (_codigoPaciente != null && _tipo != 'Nutricionista') {
        _tipo = 'Paciente';
      }

      // Calcular automáticamente si es administrador según el tipo
      final isAdmin =
          (_tipo == 'Nutricionista') ? 'S' : 'N'; // Solo Nutricionista es admin

      Map<String, dynamic> usuarioData = {
        'codigo': widget.usuario?.codigo.toString(),
        'nick': _nick,
        'nombre': _nombre,
        'email': _email,
        'tipo': _tipo,
        'codigo_paciente': _codigoPaciente,
        'activo': _activo ? 'S' : 'N',
        'accesoweb': _accesoWeb ? 'S' : 'N',
        'administrador': isAdmin,
        'img_perfil': _imageBase64,
      };

      try {
        bool success;
        if (widget.usuario != null) {
          // Update
          if (_password.isNotEmpty) {
            usuarioData['contrasena'] = _password;
          }
          success = await _apiService.updateUsuario(usuarioData);
        } else {
          // Create
          usuarioData['contrasena'] = _password;
          success = await _apiService.createUsuario(usuarioData);
        }

        if (success) {
          // Mostrar mensaje según sea alta o modificación
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.usuario == null
                  ? 'Usuario añadido correctamente'
                  : 'Usuario modificado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        final configService = context.read<ConfigService>();
        if (configService.appMode == AppMode.debug) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error Detallado de la API'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Datos enviados:'),
                    Text(
                        'activo: ${usuarioData['activo']} (tipo: ${usuarioData['activo'].runtimeType})'),
                    Text(
                        'accesoweb: ${usuarioData['accesoweb']} (tipo: ${usuarioData['accesoweb'].runtimeType})'),
                    const SizedBox(height: 16),
                    const Text('Error:'),
                    Text(e.toString()),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cerrar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Error al guardar el usuario'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDefaults) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Nuevo Usuario'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title:
              Text(widget.usuario == null ? 'Nuevo Usuario' : 'Editar Usuario'),
          actions: [
            IconButton(icon: const Icon(Icons.save), onPressed: _submitForm)
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
            child: Form(
              key: _formKey,
              onChanged: _markDirty,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar de perfil
                  Center(
                    child: ProfileImagePicker(
                      initialBase64Image: _imageBase64,
                      onImageChanged: _handleImageChanged,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    initialValue: widget.usuario?.nick,
                    decoration:
                        const InputDecoration(labelText: 'Nick / Usuario'),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'El nick es obligatorio'
                        : null,
                    onSaved: (value) => _nick = value!,
                  ),
                  TextFormField(
                    initialValue: widget.usuario?.nombre ?? '',
                    decoration:
                        const InputDecoration(labelText: 'Nombre Completo'),
                    onSaved: (value) => _nombre = value,
                  ),
                  TextFormField(
                    initialValue: widget.usuario?.email ?? '',
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    onSaved: (value) => _email = value,
                  ),
                  TextFormField(
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: widget.usuario != null
                            ? 'Nueva Contraseña (dejar en blanco para no cambiar)'
                            : 'Contraseña'),
                    validator: (value) {
                      final configService = context.read<ConfigService>();

                      // Solo obligatorio al crear nuevo usuario
                      if (widget.usuario == null &&
                          (value == null || value.isEmpty)) {
                        return 'La contraseña es obligatoria';
                      }

                      // Si hay contraseña (nueva o creación), validar políticas
                      if (value != null && value.isNotEmpty) {
                        return configService.validatePassword(value);
                      }

                      return null;
                    },
                    onSaved: (value) => _password = value ?? '',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _tipo,
                    decoration:
                        const InputDecoration(labelText: 'Tipo de Usuario'),
                    items: _tiposUsuario
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'El tipo de usuario es obligatorio'
                        : null,
                    onChanged: (value) => setState(() => _tipo = value),
                    onSaved: (value) => _tipo = value,
                  ),
                  if (_tipo == 'Paciente') _buildPacientesDropdown(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Nutricionista = Administrador (control total)\nPaciente = Usuario con paciente asociado\nUsuario = Usuario registrado sin paciente',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Activo'),
                    value: _activo,
                    onChanged: (value) => setState(() => _activo = value),
                  ),
                  SwitchListTile(
                    title: const Text('Permitir Acceso'),
                    value: _accesoWeb,
                    onChanged: (value) => setState(() => _accesoWeb = value),
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
          initialValue: _codigoPaciente,
          decoration: const InputDecoration(
              labelText: 'Asociar a Paciente',
              helperText:
                  'Si se asocia un paciente, el tipo cambiará automáticamente a "Paciente"',
              helperMaxLines: 2),
          items: snapshot.data!
              .map((paciente) => DropdownMenuItem(
                  value: paciente.codigo, child: Text(paciente.nombre)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _codigoPaciente = value;
              // Cambiar tipo automáticamente si se asocia paciente (solo si no es Nutricionista)
              if (value != null && _tipo != 'Nutricionista') {
                _tipo = 'Paciente';
              }
            });
          },
        );
      },
    );
  }
}
