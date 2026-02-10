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
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                      child: Text(cliente.nombre.isNotEmpty
                          ? cliente.nombre[0].toUpperCase()
                          : '?')),
                  title: Text(cliente.nombre),
                  subtitle: Text(cliente.email ?? 'Sin email'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _navigateToEditScreen(cliente),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteConfirmation(cliente),
                      ),
                    ],
                  ),
                  onTap: () => _navigateToEditScreen(cliente),
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
