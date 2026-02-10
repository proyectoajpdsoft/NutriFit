import 'package:flutter/material.dart';

/// Widget para seleccionar icono de deporte
class SportIconPicker extends StatefulWidget {
  final String? selectedIcon;
  final ValueChanged<String> onIconSelected;

  const SportIconPicker({
    Key? key,
    this.selectedIcon,
    required this.onIconSelected,
  }) : super(key: key);

  @override
  State<SportIconPicker> createState() => _SportIconPickerState();
}

class _SportIconPickerState extends State<SportIconPicker> {
  static const List<String> _sportIcons = [
    '🏃', // Carrera
    '🚶', // Caminata
    '🚴', // Ciclismo
    '🏊', // Natación
    '🚣', // Remo
    '🏋️', // Pesas
    '🪜', // Escaleras
    '⚡', // Crossfit
    '🧘', // Yoga
    '⚽', // Fútbol
    '🎾', // Tenis/Pádel
    '⛰️', // Alpinismo
    '🤸', // Pilates
    '🛹', // Skateboard
    '🏂', // Snowboard
    '🧗', // Escalada
    '⛷️', // Esquí
    '🏐', // Voleibol
    '🏑', // Hockey
    '🥊', // Boxeo
    '🥋', // Artes marciales
    '🤺', // Esgrima
    '🏇', // Equitación
    '🚣‍♀️', // Piragüismo
    '🏄', // Surf
    '⛵', // Vela
    '🤽', // Buceo
    '🚴‍♀️', // Mtb
    '🧗‍♀️', // Climbing
    '🏃‍♀️', // Trail
    '💪', // Genérico
  ];

  String _selectedIcon = '💪';

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.selectedIcon ?? '💪';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar Icono'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: _sportIcons.length,
          itemBuilder: (context, index) {
            final icon = _sportIcons[index];
            final isSelected = icon == _selectedIcon;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIcon = icon;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300]!,
                    width: isSelected ? 3 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onIconSelected(_selectedIcon);
            Navigator.pop(context, _selectedIcon);
          },
          child: const Text('Seleccionar'),
        ),
      ],
    );
  }
}

/// Función helper para mostrar el picker
Future<String?> showSportIconPicker(
  BuildContext context, {
  String? initialIcon,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) => SportIconPicker(
      selectedIcon: initialIcon,
      onIconSelected: (_) {},
    ),
  );
}
