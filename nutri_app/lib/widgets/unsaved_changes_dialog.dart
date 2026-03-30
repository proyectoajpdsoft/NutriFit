import 'package:flutter/material.dart';

Future<bool> showUnsavedChangesDialog(
  BuildContext context, {
  Future<bool> Function()? onSave,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(10, 8, 12, 0),
      title: Row(
        children: [
          const Expanded(
            child: Text(
              'Cambios sin guardar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Cancelar',
            style: IconButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
            ),
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ],
      ),
      content: const Text(
        'Tienes cambios sin guardar. Si sales ahora, se perderán.',
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Volver'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Salir sin guardar'),
        ),
      ],
    ),
  );
  return result ?? false;
}
