import 'package:flutter/material.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/widgets/profile_image_picker.dart';
import 'package:nutri_app/screens/register_screen.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:provider/provider.dart';

class PacienteProfileEditScreen extends StatefulWidget {
  final Usuario? usuario;

  const PacienteProfileEditScreen({super.key, this.usuario});

  @override
  _PacienteProfileEditScreenState createState() =>
      _PacienteProfileEditScreenState();
}

class _PacienteProfileEditScreenState extends State<PacienteProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final TextEditingController _nickController = TextEditingController();

  // Controladores
  late String _nick = '';
  late String _newPassword = '';
  late String _confirmPassword = '';
  String? _imageBase64;
  Usuario? _fullUsuario;
  bool _isLoading = true;
  bool _hasChanges = false;

  // Estado de validación de contraseña
  late ConfigService _configService;
  bool _showPasswordRequirements = false;

  @override
  void initState() {
    super.initState();
    _configService = context.read<ConfigService>();
    _loadUserData();
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
  void dispose() {
    _nickController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.usuario != null) {
        // Si el nick está vacío, necesitamos cargar el usuario completo desde el API
        if (widget.usuario!.nick.isEmpty && widget.usuario!.codigo > 0) {
          try {
            // Intentar cargar el usuario específico desde el servidor
            final usuario =
                await _apiService.getUsuario(widget.usuario!.codigo);
            setState(() {
              _fullUsuario = usuario;
              _nick = usuario.nick;
              _nickController.text = usuario.nick;
              _imageBase64 = usuario.imgPerfil;
              _isLoading = false;
            });
          } catch (e) {
            // Si falla (permisos), usar datos locales
            setState(() {
              _fullUsuario = widget.usuario;
              _nick = widget.usuario!.nick;
              _nickController.text = widget.usuario!.nick;
              _imageBase64 = widget.usuario!.imgPerfil;
              _isLoading = false;
            });
          }
        } else {
          // Usar los datos del usuario que ya tenemos
          setState(() {
            _fullUsuario = widget.usuario;
            _nick = widget.usuario!.nick;
            _nickController.text = widget.usuario!.nick;
            _imageBase64 = widget.usuario!.imgPerfil;
            _isLoading = false;
          });
        }
      } else {
        // Nuevo usuario - no hay datos que cargar
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos del usuario: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleImageChanged(String? newImage) {
    setState(() {
      _imageBase64 = newImage;
    });
  }

  String? _getPasswordValidationError(String password) {
    if (password.isEmpty) return null;

    final minLength = _configService.passwordMinLength;
    final requireUpperLower = _configService.passwordRequireUpperLower;
    final requireNumbers = _configService.passwordRequireNumbers;
    final requireSpecialChars = _configService.passwordRequireSpecialChars;

    if (password.length < minLength) {
      return 'Mínimo $minLength caracteres';
    }
    if (requireUpperLower) {
      final hasUpper = password.contains(RegExp(r'[A-Z]'));
      final hasLower = password.contains(RegExp(r'[a-z]'));
      if (!hasUpper || !hasLower) {
        return 'Debe contener mayúsculas y minúsculas';
      }
    }
    if (requireNumbers && !password.contains(RegExp(r'[0-9]'))) {
      return 'Debe contener números';
    }
    if (requireSpecialChars &&
        !password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Debe contener caracteres especiales';
    }

    return null;
  }

  Widget _buildPasswordRequirementsList() {
    final minLength = _configService.passwordMinLength;
    final requireUpperLower = _configService.passwordRequireUpperLower;
    final requireNumbers = _configService.passwordRequireNumbers;
    final requireSpecialChars = _configService.passwordRequireSpecialChars;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requisitos de contraseña:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 8),
          if (minLength > 0)
            _buildRequirement('Mínimo $minLength caracteres',
                _newPassword.length >= minLength),
          if (requireUpperLower)
            _buildRequirement(
                'Mayúsculas y minúsculas',
                _newPassword.contains(RegExp(r'[A-Z]')) &&
                    _newPassword.contains(RegExp(r'[a-z]'))),
          if (requireNumbers)
            _buildRequirement(
                'Contener números', _newPassword.contains(RegExp(r'[0-9]'))),
          if (requireSpecialChars)
            _buildRequirement('Caracteres especiales (!@#\$%^&*...)',
                _newPassword.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.green : Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Validar que las contraseñas coincidan si se proporciona una nueva
      if (_newPassword.isNotEmpty && _newPassword != _confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Las contraseñas no coinciden'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validar que el nick no exista (si ha cambiado)
      if (_nick != _fullUsuario?.nick) {
        try {
          final usuarios = await _apiService.getUsuarios();
          final nickExists = usuarios.any((u) =>
              u.nick.toLowerCase() == _nick.toLowerCase() &&
              u.codigo != _fullUsuario?.codigo);

          if (nickExists) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Este nick ya está en uso. Por favor, elija otro.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al validar el nick: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      Map<String, dynamic> usuarioData = {
        'codigo': _fullUsuario?.codigo.toString(),
        'nick': _nick,
        'nombre': _fullUsuario?.nombre,
        'email': _fullUsuario?.email,
        'tipo': _fullUsuario?.tipo,
        'codigo_paciente': _fullUsuario?.codigoPaciente,
        'activo': _fullUsuario?.activo,
        'accesoweb': _fullUsuario?.accesoweb,
        'administrador': _fullUsuario?.administrador,
        'img_perfil': _imageBase64,
      };

      // Solo incluir contraseña si se proporciona una nueva
      if (_newPassword.isNotEmpty) {
        usuarioData['contrasena'] = _newPassword;
      }

      try {
        final success = await _apiService.updateUsuario(usuarioData);
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Perfil actualizado correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar el perfil: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Editar Perfil'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final isGuest = authService.isGuestMode;

    if (isGuest) {
      return const RegisterScreen();
    }

    return _buildEditScreen();
  }

  /// Construye la pantalla de edición para usuarios registrados
  Widget _buildEditScreen() {
    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: const Text('Editar Perfil'),
          actions: [
            IconButton(icon: const Icon(Icons.save), onPressed: _submitForm)
          ],
        ),
        body: SingleChildScrollView(
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

                // Nick
                TextFormField(
                  controller: _nickController,
                  decoration: const InputDecoration(
                    labelText: 'Nick / Usuario',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'El nick es obligatorio'
                      : null,
                  onSaved: (value) => _nick = value!,
                ),
                const SizedBox(height: 16),

                // Etiqueta de Nueva Contraseña
                const Text(
                  'Nueva Contraseña',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dejar en blanco para no cambiar',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),

                // Campo de Nueva Contraseña
                TextFormField(
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return null; // Opcional
                    }
                    final error = _getPasswordValidationError(value);
                    return error;
                  },
                  onChanged: (value) {
                    setState(() {
                      _newPassword = value;
                      if (value.isNotEmpty && !_showPasswordRequirements) {
                        _showPasswordRequirements = true;
                      } else if (value.isEmpty) {
                        _showPasswordRequirements = false;
                      }
                    });
                  },
                  onSaved: (value) => _newPassword = value ?? '',
                ),
                const SizedBox(height: 16),

                // Mostrar requisitos si hay contraseña
                if (_showPasswordRequirements) ...[
                  _buildPasswordRequirementsList(),
                  const SizedBox(height: 16),
                ],

                // Confirmar Contraseña
                if (_newPassword.isNotEmpty)
                  TextFormField(
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar Contraseña',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_newPassword.isNotEmpty &&
                          (value == null || value.isEmpty)) {
                        return 'Debes confirmar la contraseña';
                      }
                      if (value != null && value != _newPassword) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                    onSaved: (value) => _confirmPassword = value ?? '',
                  ),
                const SizedBox(height: 24),

                // Botón de guardar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    child: const Text('Guardar Cambios'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final authService =
                          Provider.of<AuthService>(context, listen: false);
                      await authService.logout();
                      if (mounted) {
                        Navigator.of(context).pushReplacementNamed('login');
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
