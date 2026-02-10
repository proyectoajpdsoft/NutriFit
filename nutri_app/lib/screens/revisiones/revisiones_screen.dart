import 'package:flutter/material.dart';
import 'package:nutri_app/screens/revisiones/revisiones_list_screen.dart';
import 'package:nutri_app/screens/revisiones/revision_edit_screen.dart';

class RevisionesScreen extends StatelessWidget {
  const RevisionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Revisiones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // La lista se refrescará automáticamente al volver de la edición
              // o se puede añadir un GlobalKey para un control más fino.
              // Por ahora, solo indicamos que se refrescará.
            },
          ),
        ],
      ),
      body: const RevisionesListScreen(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const RevisionEditScreen(
                  paciente: null), // Pasa null para que muestre el desplegable
            ),
          );
        },
        tooltip: 'Añadir Revisión',
        child: const Icon(Icons.add),
      ),
    );
  }
}
