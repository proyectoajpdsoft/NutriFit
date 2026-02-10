import 'package:flutter/material.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:nutri_app/screens/usuarios/usuario_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:nutri_app/mixins/auth_error_handler_mixin.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/services/auth_service.dart';

class UsuariosListScreen extends StatefulWidget {
  const UsuariosListScreen({super.key});

  @override
  State<UsuariosListScreen> createState() => _UsuariosListScreenState();
}

class _UsuariosListScreenState extends State<UsuariosListScreen>
    with AuthErrorHandlerMixin {
  final ApiService _apiService = ApiService();
  late Future<List<Usuario>> _usuariosFuture;
  String _searchQuery = '';
  bool _filterTodos = true;
  bool _filterActivos = false;
  bool _filterAccesoWeb = false;

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

  @override
  void initState() {
    super.initState();
    _refreshUsuarios();
  }

  void _refreshUsuarios() {
    setState(() {
      _usuariosFuture = _apiService.getUsuarios();
    });
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

  Future<void> _deleteUsuario(int codigo) async {
    try {
      final success = await _apiService.deleteUsuario(codigo);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Usuario eliminado'),
              backgroundColor: Colors.green),
        );
        _refreshUsuarios();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al eliminar'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!handleAuthError(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
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

  @override
  Widget build(BuildContext context) {
    final configService =
        context.watch<ConfigService>(); // Se necesita para el modo debug
    final authService = context.watch<AuthService>();
    final isAdminUser = authService.userType == 'Nutricionista' ||
        authService.userType == 'Administrador';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Usuarios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshUsuarios,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: FutureBuilder<List<Usuario>>(
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
                  child: Text(
                      "Error al cargar los usuarios. Revise su conexión."));
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

            return matchesSearch && matchesActivos && matchesAcceso;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar usuario',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Todos'),
                          selected: _filterTodos,
                          onSelected: (selected) {
                            setState(() {
                              _filterTodos = selected;
                              if (selected) {
                                _filterActivos = false;
                                _filterAccesoWeb = false;
                              } else if (!_filterActivos && !_filterAccesoWeb) {
                                _filterTodos = true;
                              }
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('Activos'),
                          selected: _filterActivos,
                          onSelected: (selected) {
                            setState(() {
                              _filterActivos = selected;
                              if (selected) {
                                _filterTodos = false;
                              } else if (!_filterAccesoWeb) {
                                _filterTodos = true;
                              }
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('Acceso web'),
                          selected: _filterAccesoWeb,
                          onSelected: (selected) {
                            setState(() {
                              _filterAccesoWeb = selected;
                              if (selected) {
                                _filterTodos = false;
                              } else if (!_filterActivos) {
                                _filterTodos = true;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filteredUsuarios.isEmpty
                    ? const Center(child: Text('No se encontraron usuarios.'))
                    : ListView.builder(
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
                                icon:
                                    const Icon(Icons.block, color: Colors.red),
                                tooltip: 'Desactivar usuario',
                                onPressed: () =>
                                    _showDeactivateConfirmation(usuario),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                tooltip: 'Editar usuario',
                                onPressed: () => _navigateToEditScreen(usuario),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Eliminar usuario',
                                onPressed: () =>
                                    _showDeleteConfirmation(usuario),
                              ),
                            ],
                          );

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                  child: Text(usuario.nick[0].toUpperCase())),
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
      ),
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
                _deleteUsuario(usuario.codigo);
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
