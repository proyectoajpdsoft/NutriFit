import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/cobro.dart';
import 'package:nutri_app/screens/cobros/cobro_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/models/paciente.dart';

class CobrosListScreen extends StatefulWidget {
  final Paciente? paciente;
  const CobrosListScreen({super.key, this.paciente});

  @override
  State<CobrosListScreen> createState() => _CobrosListScreenState();
}

class _CobrosListScreenState extends State<CobrosListScreen> {
  final ApiService _apiService = ApiService();
  Future<List<Cobro>>? _cobrosFuture;

  @override
  void initState() {
    super.initState();
    _refreshCobros();
  }

  void _refreshCobros() {
    setState(() {
      _cobrosFuture =
          _apiService.getCobros(codigoPaciente: widget.paciente?.codigo);
    });
  }

  void _navigateToEditScreen([Cobro? cobro]) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => CobroEditScreen(
              cobro: cobro,
              paciente: widget.paciente,
            ),
          ),
        )
        .then((_) => _refreshCobros());
  }

  Future<void> _deleteCobro(int codigo) async {
    try {
      final success = await _apiService.deleteCobro(codigo);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Cobro eliminado'), backgroundColor: Colors.green),
        );
        _refreshCobros();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al eliminar'), backgroundColor: Colors.red),
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
    // Determine the title based on whether a patient was passed
    final String appBarTitle = widget.paciente != null
        ? 'Cobros de ${widget.paciente!.nombre}'
        : 'Cobros';

    final configService = context.watch<ConfigService>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(appBarTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshCobros,
          ),
        ],
      ),
      drawer: widget.paciente == null
          ? const AppDrawer()
          : null, // Show drawer only if no patient
      body: SafeArea(
        child: FutureBuilder<List<Cobro>>(
          future: _cobrosFuture,
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
                return const Center(child: Text("Error al cargar los cobros."));
              }
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No se encontraron cobros."));
            }

            final cobros = snapshot.data!;
            return ListView.builder(
              itemCount: cobros.length,
              itemBuilder: (context, index) {
                final cobro = cobros[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: 2,
                  child: ListTile(
                    title: Text(
                        '${cobro.importe.toStringAsFixed(2)} € - ${cobro.nombrePaciente ?? cobro.nombreCliente ?? '-'}'),
                    subtitle:
                        Text(DateFormat('dd/MM/yyyy').format(cobro.fecha)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _navigateToEditScreen(cobro),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _showDeleteConfirmation(cobro),
                        ),
                      ],
                    ),
                    onTap: () => _navigateToEditScreen(cobro),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditScreen(),
        tooltip: 'Añadir Cobro',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteConfirmation(Cobro cobro) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
              '¿Seguro que quieres eliminar el cobro de ${cobro.importe}€ de ${cobro.pagadorNombre}?'),
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
                _deleteCobro(cobro.codigo);
              },
            ),
          ],
        );
      },
    );
  }
}
