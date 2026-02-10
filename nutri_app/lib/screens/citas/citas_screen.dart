import 'package:flutter/material.dart';
import 'package:nutri_app/screens/citas/citas_calendar_screen.dart';
import 'package:nutri_app/screens/citas/citas_list_screen.dart';

class CitasScreen extends StatelessWidget {
  const CitasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Citas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Vista de Calendario',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CitasCalendarScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: const CitasListScreen(),
      // El FloatingActionButton ahora está dentro de CitasListScreen
    );
  }
}
