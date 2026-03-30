import 'package:flutter/material.dart';
import 'package:nutri_app/models/cliente.dart';
import 'package:nutri_app/screens/clientes/cliente_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/services/config_service.dart';

class ClientesListScreen extends StatefulWidget {
  const ClientesListScreen({super.key});

  @override
  State<ClientesListScreen> createState() => _ClientesListScreenState();
}

class _ClientesListScreenState extends State<ClientesListScreen> {
  final ApiService _apiService = ApiService();
  Future<List<Cliente>>? _clientesFuture;

  @override
  void initState() {
    super.initState();
    context
        .read<ConfigService>()
        .loadDeleteSwipePercentageFromDatabase(_apiService);
    _refreshClientes();
  }

  void _refreshClientes() {
    setState(() {
      _clientesFuture = _apiService.getClientes();
    });
  }

  void _navigateToEditScreen([Cliente? cliente]) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => ClienteEditScreen(cliente: cliente),
          ),
        )
        .then((_) => _refreshClientes());
  }

  Future<void> _deleteCliente(int codigo) async {
    try {
      final success = await _apiService.deleteCliente(codigo);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Cliente eliminado correctamente'),
              backgroundColor: Colors.green),
        );
        _refreshClientes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al eliminar cliente'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openClienteMenu(Cliente cliente) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'edit') {
      _navigateToEditScreen(cliente);
    } else if (action == 'delete') {
      _showDeleteConfirmation(cliente);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _refreshClientes,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: FutureBuilder<List<Cliente>>(
        future: _clientesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            final errorMessage = snapshot.error.toString();
            if (configService.appMode == AppMode.debug) {
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SelectableText(errorMessage)));
            } else {
              return const Center(child: Text("Error al cargar los clientes."));
            }
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No se encontraron clientes."));
          }

          final clientes = snapshot.data!;
          return ListView.builder(
            itemCount: clientes.length,
            itemBuilder: (context, index) {
              final cliente = clientes[index];
              return Dismissible(
                key: ValueKey('cliente_${cliente.codigo}_$index'),
                direction: DismissDirection.startToEnd,
                dismissThresholds: {
                  DismissDirection.startToEnd: context
                      .watch<ConfigService>()
                      .deleteSwipeDismissThreshold,
                },
                background: Container(
                  color: Colors.red.shade600,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Eliminar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                confirmDismiss: (_) async {
                  _showDeleteConfirmation(cliente);
                  return false;
                },
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                        child: Text(cliente.nombre.isNotEmpty
                            ? cliente.nombre[0].toUpperCase()
                            : '?')),
                    title: Text(cliente.nombre),
                    subtitle: Text(cliente.email ?? 'Sin email'),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'Más opciones',
                      onPressed: () => _openClienteMenu(cliente),
                    ),
                    onTap: () => _navigateToEditScreen(cliente),
                    onLongPress: () => _openClienteMenu(cliente),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditScreen(),
        tooltip: 'Añadir Cliente',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteConfirmation(Cliente cliente) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Desactivación'),
          content: Text(
              '¿Seguro que quieres desactivar a "${cliente.nombre}"? No se borrará permanentemente.'),
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
                _deleteCliente(cliente.codigo);
              },
            ),
          ],
        );
      },
    );
  }
}
