import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:nutri_app/models/session.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:nutri_app/screens/usuarios/usuario_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:nutri_app/mixins/auth_error_handler_mixin.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsuariosListScreen extends StatefulWidget {
  const UsuariosListScreen({super.key});

  @override
  State<UsuariosListScreen> createState() => _UsuariosListScreenState();
}

class _UsuariosListScreenState extends State<UsuariosListScreen>
    with AuthErrorHandlerMixin {
  final ApiService _apiService = ApiService();
  final ScrollController _sesionesScrollController = ScrollController();
  static const int _sesionesPageSize = 20;
  late Future<List<Usuario>> _usuariosFuture;
  List<SessionLog> _sesionesItems = [];
  bool _sesionesLoading = false;
  bool _sesionesLoadingMore = false;
  bool _sesionesHasMore = true;
  int _sesionesOffset = 0;
  int _sesionesTotalFiltrado = 0;
  String? _sesionesError;
  List<Usuario> _usuariosCatalogo = [];
  String _searchQuery = '';
  bool _filterTodos = true;
  bool _filterActivos = false;
  bool _filterAccesoWeb = false;
  bool _filterPaciente = false;
  bool _filterNutricionista = false;
  bool _filterUsuarioSinPaciente = false;
  bool _showFilters = false;
  int? _sesionesUsuarioFiltro;
  DateTime? _sesionesDesde;
  DateTime? _sesionesHasta;
  final TextEditingController _searchController = TextEditingController();

  Widget _buildTag(String text, Color backgroundColor,
      {Color textColor = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildUserTags(Usuario usuario) {
    final isActivo = usuario.activo.toUpperCase() == 'S';
    final hasWeb = usuario.accesoweb.toUpperCase() == 'S';
    final tipo = usuario.tipo ?? 'Sin tipo';

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _buildTag(isActivo ? 'Activo' : 'Inactivo',
            isActivo ? Colors.green : Colors.grey),
        _buildTag(hasWeb ? 'Acceso web' : 'Sin acceso web',
            hasWeb ? Colors.blue : Colors.grey),
        _buildTag(tipo, Colors.purple),
      ],
    );
  }

  Widget _buildUserAvatar(Usuario usuario) {
    // Si tiene imagen de perfil, mostrar la imagen
    if (usuario.imgPerfil != null && usuario.imgPerfil!.isNotEmpty) {
      try {
        // debugPrint('Intentando decodificar imagen de usuario: ${usuario.nick}');
        // debugPrint('Tamaño base64: ${usuario.imgPerfil!.length} caracteres');
        // debugPrint(
        //     'Primeros 100 caracteres: ${usuario.imgPerfil!.substring(0, math.min(100, usuario.imgPerfil!.length))}');

        final imageBytes = base64Decode(usuario.imgPerfil!);
        // debugPrint(
        //     'Imagen decodificada exitosamente: ${imageBytes.length} bytes');

        return CircleAvatar(
          radius: 24,
          backgroundImage: MemoryImage(imageBytes),
          onBackgroundImageError: (exception, stackTrace) {
            // debugPrint('Error al mostrar imagen: $exception');
          },
        );
      } catch (e) {
        // Si hay error decodificando, mostrar icono genérico
        // debugPrint('Error decodificando base64 para ${usuario.nick}: $e');
        return const CircleAvatar(
          radius: 24,
          child: Icon(Icons.person, size: 28, color: Colors.white),
        );
      }
    }

    // Si no tiene imagen, mostrar icono genérico
    return const CircleAvatar(
      radius: 24,
      child: Icon(Icons.person, size: 28, color: Colors.white),
    );
  }

  @override
  void initState() {
    super.initState();
    _usuariosFuture = Future.value(const <Usuario>[]);
    _loadUiState();
    _sesionesScrollController.addListener(() {
      if (!_sesionesScrollController.hasClients) return;
      final pos = _sesionesScrollController.position;
      if (pos.pixels >= (pos.maxScrollExtent - 240)) {
        _loadMoreSesiones();
      }
    });
    _resetAndLoadSesiones();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sesionesScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final showFilters = prefs.getBool('usuarios_show_filters') ?? false;
    final filterTodos = prefs.getBool('usuarios_filter_todos') ?? true;
    final filterActivos = prefs.getBool('usuarios_filter_activos') ?? false;
    final filterAccesoWeb =
        prefs.getBool('usuarios_filter_acceso_web') ?? false;
    final filterPaciente = prefs.getBool('usuarios_filter_paciente') ?? false;
    final filterNutricionista =
        prefs.getBool('usuarios_filter_nutricionista') ?? false;
    final filterUsuarioSinPaciente =
        prefs.getBool('usuarios_filter_usuario_sin_paciente') ?? false;
    if (!mounted) return;
    setState(() {
      _showFilters = showFilters;
      _filterTodos = filterTodos;
      _filterActivos = filterActivos;
      _filterAccesoWeb = filterAccesoWeb;
      _filterPaciente = filterPaciente;
      _filterNutricionista = filterNutricionista;
      _filterUsuarioSinPaciente = filterUsuarioSinPaciente;
    });
    _refreshUsuarios();
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('usuarios_show_filters', _showFilters);
    await prefs.setBool('usuarios_filter_todos', _filterTodos);
    await prefs.setBool('usuarios_filter_activos', _filterActivos);
    await prefs.setBool('usuarios_filter_acceso_web', _filterAccesoWeb);
    await prefs.setBool('usuarios_filter_paciente', _filterPaciente);
    await prefs.setBool('usuarios_filter_nutricionista', _filterNutricionista);
    await prefs.setBool(
      'usuarios_filter_usuario_sin_paciente',
      _filterUsuarioSinPaciente,
    );
  }

  void _refreshUsuarios() {
    final future = _apiService.getUsuarios();
    setState(() {
      _usuariosFuture = future;
    });
    future.then((list) {
      if (!mounted) return;
      setState(() {
        _usuariosCatalogo = list;
      });
    }).catchError((_) {});
  }

  Future<void> _resetAndLoadSesiones() async {
    setState(() {
      _sesionesItems = [];
      _sesionesOffset = 0;
      _sesionesHasMore = true;
      _sesionesError = null;
      _sesionesTotalFiltrado = 0;
    });
    await _loadMoreSesiones(reset: true);
  }

  Future<void> _loadMoreSesiones({bool reset = false}) async {
    if (_sesionesLoading || _sesionesLoadingMore || !_sesionesHasMore) {
      return;
    }

    if (!mounted) return;
    setState(() {
      if (reset || _sesionesOffset == 0) {
        _sesionesLoading = true;
      } else {
        _sesionesLoadingMore = true;
      }
      _sesionesError = null;
    });

    try {
      final page = await _apiService.getAllSessionLogsPaged(
        limit: _sesionesPageSize,
        offset: _sesionesOffset,
        codigoUsuario: _sesionesUsuarioFiltro,
        desde: _sesionesDesde,
        hasta: _sesionesHasta,
      );

      if (!mounted) return;
      setState(() {
        _sesionesItems = [..._sesionesItems, ...page.sesiones];
        _sesionesOffset = _sesionesItems.length;
        _sesionesTotalFiltrado = page.totalFiltrado;
        _sesionesHasMore = page.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sesionesError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _sesionesLoading = false;
        _sesionesLoadingMore = false;
      });
    }
  }

  void _navigateToEditScreen([Usuario? usuario]) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => UsuarioEditScreen(usuario: usuario),
          ),
        )
        .then((_) => _refreshUsuarios());
  }

  Future<void> _deleteUsuarioCascade(int codigo) async {
    try {
      final success = await _apiService.deleteUsuarioCascade(codigo);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Usuario y todos sus registros eliminados'),
                backgroundColor: Colors.green),
          );
          _refreshUsuarios();
        }
      }
    } catch (e) {
      if (!handleAuthError(e)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showMoveUsuarioDialog(int codigoOrigen) async {
    // Cargar lista de usuarios para seleccionar el destino
    try {
      final response = await _apiService.get('/usuarios.php');
      if (response.statusCode == 200) {
        final List<dynamic> usuarios = jsonDecode(response.body);
        final usuariosList = List<Map<String, dynamic>>.from(
          usuarios.map((item) => Map<String, dynamic>.from(item as Map)),
        );

        // Filtrar el usuario actual (no puede mover a sí mismo)
        usuariosList.removeWhere(
          (u) =>
              (int.tryParse(u['codigo']?.toString() ?? '') ?? 0) ==
              codigoOrigen,
        );

        if (!mounted) return;

        int? usuarioDestino;
        await showDialog(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: const Text('Seleccionar usuario destino'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Seleccione a qué usuario desea mover los registros:',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: usuarioDestino,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Usuario destino',
                        ),
                        items: usuariosList
                            .map((usuario) {
                              final codigo = int.tryParse(
                                  usuario['codigo']?.toString() ?? '');
                              if (codigo == null) {
                                return null;
                              }
                              return DropdownMenuItem<int>(
                                value: codigo,
                                child: Text(
                                    usuario['nombre'] ?? 'Usuario desconocido'),
                              );
                            })
                            .whereType<DropdownMenuItem<int>>()
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            usuarioDestino = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancelar'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  TextButton(
                    child: const Text('Mover'),
                    onPressed: () {
                      if (usuarioDestino == null) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Selecciona un usuario destino primero.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          },
        );

        if (usuarioDestino != null && mounted) {
          await _moveUsuarioData(codigoOrigen, usuarioDestino!);
        }
      }
    } catch (e) {
      if (!handleAuthError(e)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showTransferPacienteDialog({
    required Usuario usuario,
    required Map<String, dynamic>? pacienteAsociado,
    required List<Map<String, dynamic>> usuariosDestino,
  }) async {
    if (!mounted) return;

    int? selectedDestino;
    bool busy = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Mover a otro paciente'),
              content: busy
                  ? const SizedBox(
                      height: 90,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paciente asociado: ${pacienteAsociado?['nombre'] ?? 'Sin nombre'} (código ${pacienteAsociado?['codigo'] ?? '-'})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Selecciona el usuario destino para transferir el paciente:',
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: selectedDestino,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Usuario destino',
                          ),
                          items: usuariosDestino
                              .map(
                                (u) => DropdownMenuItem<int>(
                                  value: int.tryParse(
                                      u['codigo']?.toString() ?? ''),
                                  child: Text(
                                    '${u['nombre'] ?? u['nick'] ?? 'Usuario'} (${u['nick'] ?? ''})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .where(
                                (item) => item.value != null && item.value! > 0,
                              )
                              .cast<DropdownMenuItem<int>>()
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedDestino = value;
                            });
                          },
                        ),
                        if (usuariosDestino.isEmpty) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'No hay usuarios activos disponibles sin paciente asociado.',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ],
                    ),
              actions: [
                TextButton(
                  onPressed:
                      busy ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: busy || usuariosDestino.isEmpty
                      ? null
                      : () async {
                          if (selectedDestino == null || selectedDestino == 0) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Selecciona un usuario destino para transferir el paciente.',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            busy = true;
                          });

                          try {
                            await _apiService.transferUsuarioPacienteAsociado(
                              usuario.codigo,
                              selectedDestino!,
                            );
                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Paciente asociado transferido correctamente.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _refreshUsuarios();
                          } catch (e) {
                            setDialogState(() {
                              busy = false;
                            });
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'No se pudo transferir el paciente: $e',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: const Text('Transferir paciente'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _moveUsuarioData(int codigoOrigen, int codigoDestino) async {
    try {
      final success =
          await _apiService.moveUsuarioData(codigoOrigen, codigoDestino);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Datos movidos y usuario eliminado correctamente'),
                backgroundColor: Colors.green),
          );
          _refreshUsuarios();
        }
      }
    } catch (e) {
      if (!handleAuthError(e)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _revokeToken(Usuario usuario) async {
    try {
      final success = await _apiService.revokeUserToken(usuario.codigo);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Token revocado para ${usuario.nick}'),
                backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (!handleAuthError(e)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error al revocar token: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deactivateUser(Usuario usuario) async {
    try {
      final success = await _apiService.deactivateUser(usuario.codigo);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Usuario ${usuario.nick} desactivado'),
                backgroundColor: Colors.green),
          );
          _refreshUsuarios();
        }
      }
    } catch (e) {
      if (!handleAuthError(e)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error al desactivar: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  String _tableLabel(String tableName) {
    switch (tableName) {
      case 'nu_adherencia_diaria':
        return 'nu_adherencia_diaria';
      case 'nu_consejo_usuario':
        return 'nu_consejo_usuario';
      case 'nu_entrenamientos':
        return 'nu_entrenamientos';
      case 'nu_entrenamientos_actividad_custom':
        return 'nu_entrenamientos_actividad_custom';
      case 'nu_entrenamientos_imagenes':
        return 'nu_entrenamientos_imagenes';
      case 'nu_lista_compra':
        return 'nu_lista_compra';
      case 'nu_receta_usuario':
        return 'nu_receta_usuario';
      case 'nu_todo_list':
        return 'nu_todo_list';
      case 'usuario_push_dispositivo':
        return 'usuario_push_dispositivo';
      case 'usuario':
        return 'usuario';
      default:
        return tableName;
    }
  }

  Future<void> _runDeleteWizard(Usuario usuario) async {
    Map<String, dynamic> flowInfo;
    try {
      flowInfo = await _apiService.getUsuarioDeleteFlowInfo(usuario.codigo);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      return;
    }

    final hasPacienteAsociado = flowInfo['has_paciente_asociado'] == true;
    final pacienteAsociado = flowInfo['paciente_asociado'] is Map
        ? Map<String, dynamic>.from(flowInfo['paciente_asociado'] as Map)
        : null;
    final dependencies = flowInfo['dependencies'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(flowInfo['dependencies'])
        : <String, dynamic>{};
    final usuariosDestino =
        (flowInfo['usuarios_destino_disponibles'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    if (!mounted) return;

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Eliminar usuario: ${usuario.nick}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Este usuario tiene los siguientes registros en otras tablas:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (dependencies.isEmpty)
                const Text('No se encontraron registros asociados.')
              else
                ...dependencies.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      '• ${_tableLabel(entry.key)}: ${entry.value} registros',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              if (hasPacienteAsociado) ...[
                const SizedBox(height: 12),
                Text(
                  'Paciente asociado: ${pacienteAsociado?['nombre'] ?? 'Sin nombre'} (código ${pacienteAsociado?['codigo'] ?? '-'})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Seleccione una opción:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
          ),
          TextButton(
            child: const Text('Eliminar completo'),
            onPressed: () => Navigator.pop(dialogContext, 'delete'),
          ),
          TextButton(
            child: const Text('Mover a otro usuario'),
            onPressed: () => Navigator.pop(dialogContext, 'move_user'),
          ),
          if (hasPacienteAsociado)
            TextButton(
              child: const Text('Mover a otro paciente'),
              onPressed: () => Navigator.pop(dialogContext, 'move_patient'),
            ),
        ],
      ),
    );

    if (action == 'delete') {
      await _deleteUsuarioCascade(usuario.codigo);
      return;
    }

    if (action == 'move_user') {
      await _showMoveUsuarioDialog(usuario.codigo);
      return;
    }

    if (action == 'move_patient') {
      await _showTransferPacienteDialog(
        usuario: usuario,
        pacienteAsociado: pacienteAsociado,
        usuariosDestino: usuariosDestino,
      );
    }
  }

  String _sessionUserLabel(SessionLog s) {
    final nombre = (s.usuarioNombre ?? '').trim();
    final nick = (s.usuarioNick ?? '').trim();
    if (nombre.isNotEmpty && nick.isNotEmpty) {
      return '$nombre ($nick)';
    }
    if (nombre.isNotEmpty) return nombre;
    if (nick.isNotEmpty) return nick;
    return 'Usuario ${s.codigousuario}';
  }

  Future<void> _pickSessionDateTime({required bool isDesde}) async {
    final initial = isDesde
        ? (_sesionesDesde ?? DateTime.now())
        : (_sesionesHasta ?? DateTime.now());
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isDesde) {
        _sesionesDesde = combined;
      } else {
        _sesionesHasta = combined;
      }
    });
    await _resetAndLoadSesiones();
  }

  Widget _buildSesionesTab() {
    final usuariosFiltro = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Todos los usuarios'),
      ),
      ..._usuariosCatalogo
          .map(
            (u) => DropdownMenuItem<int?>(
              value: u.codigo,
              child: Text(
                (u.nombre ?? '').trim().isNotEmpty
                    ? '${u.nombre} (${u.nick})'
                    : u.nick,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: DropdownButtonFormField<int?>(
            initialValue: _sesionesUsuarioFiltro,
            decoration: const InputDecoration(
              labelText: 'Filtrar por usuario',
              border: OutlineInputBorder(),
            ),
            items: usuariosFiltro,
            onChanged: (value) async {
              setState(() {
                _sesionesUsuarioFiltro = value;
              });
              await _resetAndLoadSesiones();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickSessionDateTime(isDesde: true),
                icon: const Icon(Icons.event_available),
                label: Text(
                  _sesionesDesde == null
                      ? 'Desde'
                      : 'Desde: ${_sesionesDesde!.toLocal()}'.split('.').first,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickSessionDateTime(isDesde: false),
                icon: const Icon(Icons.event_busy),
                label: Text(
                  _sesionesHasta == null
                      ? 'Hasta'
                      : 'Hasta: ${_sesionesHasta!.toLocal()}'.split('.').first,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  setState(() {
                    _sesionesDesde = null;
                    _sesionesHasta = null;
                  });
                  await _resetAndLoadSesiones();
                },
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Limpiar fechas'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _sesionesLoading && _sesionesItems.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _sesionesError != null && _sesionesItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child:
                            Text('Error al cargar sesiones: $_sesionesError'),
                      ),
                    )
                  : _sesionesItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay sesiones para los filtros seleccionados.',
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _resetAndLoadSesiones,
                          child: ListView.builder(
                            controller: _sesionesScrollController,
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: _sesionesItems.length +
                                (_sesionesLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _sesionesItems.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final s = _sesionesItems[index];
                              final fechaHora =
                                  '${s.fecha}${(s.hora ?? '').trim().isNotEmpty ? ' ${s.hora}' : ''}';
                              final ipPublica = (s.ipPublica ?? '').trim();

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.login),
                                  title: Text(_sessionUserLabel(s)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Fecha/Hora: $fechaHora'),
                                      Text(
                                        'IP pública: ${ipPublica.isEmpty ? '-' : ipPublica}',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final configService =
        context.watch<ConfigService>(); // Se necesita para el modo debug
    final authService = context.watch<AuthService>();
    final isAdminUser = authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';
    final isNutricionista =
        (authService.userType ?? '').trim().toLowerCase() == 'nutricionista';

    final usuariosBody = FutureBuilder<List<Usuario>>(
      future: _usuariosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          // --- LÓGICA DE ERROR DUAL (DEBUG/NORMAL) ---
          final errorMessage = snapshot.error.toString();
          if (configService.appMode == AppMode.debug) {
            // MODO DEBUG: Muestra el error técnico completo.
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText(errorMessage),
              ),
            );
          } else {
            // MODO NORMAL: Muestra un mensaje genérico.
            return const Center(
                child:
                    Text("Error al cargar los usuarios. Revise su conexión."));
          }
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No se encontraron usuarios."));
        }

        final usuarios = snapshot.data!;
        final query = _searchQuery.trim().toLowerCase();
        final filteredUsuarios = usuarios.where((usuario) {
          final matchesSearch = query.isEmpty ||
              usuario.nick.toLowerCase().contains(query) ||
              (usuario.nombre ?? '').toLowerCase().contains(query) ||
              (usuario.email ?? '').toLowerCase().contains(query) ||
              (usuario.tipo ?? '').toLowerCase().contains(query);

          if (_filterTodos) {
            return matchesSearch;
          }

          final matchesActivos =
              !_filterActivos || usuario.activo.toUpperCase() == 'S';
          final matchesAcceso =
              !_filterAccesoWeb || usuario.accesoweb.toUpperCase() == 'S';
          final tipoLower = (usuario.tipo ?? '').toLowerCase();
          final matchesNutricionista =
              !_filterNutricionista || tipoLower.contains('nutricionista');

          final hasPacienteAsignado = (usuario.codigoPaciente ?? 0) > 0;
          final matchesPaciente = !_filterPaciente || hasPacienteAsignado;
          final matchesUsuarioSinPaciente =
              !_filterUsuarioSinPaciente || !hasPacienteAsignado;

          final bothPacienteFiltersSelected =
              _filterPaciente && _filterUsuarioSinPaciente;
          final matchesPacienteDimension = bothPacienteFiltersSelected
              ? true
              : (matchesPaciente && matchesUsuarioSinPaciente);

          return matchesSearch &&
              matchesActivos &&
              matchesAcceso &&
              matchesNutricionista &&
              matchesPacienteDimension;
        }).toList();

        return Column(
          children: [
            if (_showFilters) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar usuario',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Todos'),
                        selected: _filterTodos,
                        onSelected: (_) {
                          setState(() {
                            _filterTodos = true;
                            _filterActivos = false;
                            _filterAccesoWeb = false;
                            _filterPaciente = false;
                            _filterNutricionista = false;
                            _filterUsuarioSinPaciente = false;
                          });
                          _saveUiState();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Activos'),
                        selected: _filterActivos,
                        onSelected: (selected) {
                          setState(() {
                            _filterActivos = selected;
                            _filterTodos = false;
                            if (!_filterActivos &&
                                !_filterAccesoWeb &&
                                !_filterPaciente &&
                                !_filterNutricionista &&
                                !_filterUsuarioSinPaciente) {
                              _filterTodos = true;
                            }
                          });
                          _saveUiState();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Acceso web'),
                        selected: _filterAccesoWeb,
                        onSelected: (selected) {
                          setState(() {
                            _filterAccesoWeb = selected;
                            _filterTodos = false;
                            if (!_filterActivos &&
                                !_filterAccesoWeb &&
                                !_filterPaciente &&
                                !_filterNutricionista &&
                                !_filterUsuarioSinPaciente) {
                              _filterTodos = true;
                            }
                          });
                          _saveUiState();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Paciente'),
                        selected: _filterPaciente,
                        onSelected: (selected) {
                          setState(() {
                            _filterPaciente = selected;
                            _filterTodos = false;
                            if (!_filterActivos &&
                                !_filterAccesoWeb &&
                                !_filterPaciente &&
                                !_filterNutricionista &&
                                !_filterUsuarioSinPaciente) {
                              _filterTodos = true;
                            }
                          });
                          _saveUiState();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Nutricionista'),
                        selected: _filterNutricionista,
                        onSelected: (selected) {
                          setState(() {
                            _filterNutricionista = selected;
                            _filterTodos = false;
                            if (!_filterActivos &&
                                !_filterAccesoWeb &&
                                !_filterPaciente &&
                                !_filterNutricionista &&
                                !_filterUsuarioSinPaciente) {
                              _filterTodos = true;
                            }
                          });
                          _saveUiState();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Usuario'),
                        selected: _filterUsuarioSinPaciente,
                        onSelected: (selected) {
                          setState(() {
                            _filterUsuarioSinPaciente = selected;
                            _filterTodos = false;
                            if (!_filterActivos &&
                                !_filterAccesoWeb &&
                                !_filterPaciente &&
                                !_filterNutricionista &&
                                !_filterUsuarioSinPaciente) {
                              _filterTodos = true;
                            }
                          });
                          _saveUiState();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
            ],
            Expanded(
              child: filteredUsuarios.isEmpty
                  ? const Center(child: Text('No se encontraron usuarios.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: filteredUsuarios.length,
                      itemBuilder: (context, index) {
                        final usuario = filteredUsuarios[index];
                        final actionsRow = Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.logout,
                                  color: Colors.orange),
                              tooltip: 'Revocar token',
                              onPressed: () =>
                                  _showRevokeTokenConfirmation(usuario),
                            ),
                            IconButton(
                              icon: const Icon(Icons.block, color: Colors.red),
                              tooltip: 'Desactivar usuario',
                              onPressed: () =>
                                  _showDeactivateConfirmation(usuario),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Editar usuario',
                              onPressed: () => _navigateToEditScreen(usuario),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Eliminar usuario',
                              onPressed: () => _showDeleteConfirmation(usuario),
                            ),
                          ],
                        );

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          elevation: 2,
                          child: ListTile(
                            leading: _buildUserAvatar(usuario),
                            title: Text(usuario.nick),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildUserTags(usuario),
                                if (isAdminUser) ...[
                                  const SizedBox(height: 4),
                                  actionsRow,
                                ],
                              ],
                            ),
                            trailing: isAdminUser
                                ? null
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: actionsRow.children,
                                  ),
                            onTap: () => _navigateToEditScreen(usuario),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Usuarios'),
        actions: [
          IconButton(
            icon: Icon(
                _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
            tooltip: _showFilters ? 'Ocultar filtro' : 'Mostrar filtro',
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
              _saveUiState();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refreshUsuarios();
              if (isNutricionista) {
                _resetAndLoadSesiones();
              }
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: isNutricionista
          ? DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      const Tab(icon: Icon(Icons.people), text: 'Usuarios'),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.history),
                                    SizedBox(width: 6),
                                    Text('Sesiones'),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$_sesionesTotalFiltrado',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        usuariosBody,
                        _buildSesionesTab(),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : usuariosBody,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditScreen(),
        tooltip: 'Añadir Usuario',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteConfirmation(Usuario usuario) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
              '¿Seguro que quieres eliminar al usuario "${usuario.nick}"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _runDeleteWizard(usuario);
              },
            ),
          ],
        );
      },
    );
  }

  void _showRevokeTokenConfirmation(Usuario usuario) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Revocar Token'),
          content: Text(
              '¿Quieres forzar la desconexión del usuario "${usuario.nick}"?\n\nEsto cerrará su sesión actual y deberá volver a iniciar sesión.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child:
                  const Text('Revocar', style: TextStyle(color: Colors.orange)),
              onPressed: () {
                Navigator.of(context).pop();
                _revokeToken(usuario);
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeactivateConfirmation(Usuario usuario) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Desactivar Usuario'),
          content: Text(
              '¿Seguro que quieres desactivar al usuario "${usuario.nick}"?\n\nNo podrá acceder a la aplicación hasta que sea reactivado.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child:
                  const Text('Desactivar', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deactivateUser(usuario);
              },
            ),
          ],
        );
      },
    );
  }
}
