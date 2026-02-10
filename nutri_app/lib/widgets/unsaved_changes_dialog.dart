import 'package:flutter/material.dart';

Future<bool> showUnsavedChangesDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cambios sin guardar'),
      content: const Text(
        'Tienes cambios sin guardar. Si sales ahora, se perderan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Salir sin guardar'),
        ),
      ],
    ),
  );
  return result ?? false;
}
