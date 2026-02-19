import 'package:flutter/material.dart';

class ActividadesCatalogScreen extends StatelessWidget {
  const ActividadesCatalogScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividades'),
      ),
      body: const Center(
        child: Text('Catálogo de actividades'),
      ),
    );
  }
}
