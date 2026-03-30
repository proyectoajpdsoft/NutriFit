import 'package:flutter/material.dart';

import '../screens/contacto_nutricionista_screen.dart';

int? _normalizePeligrosidad(int? value) {
  if (value == null) return null;
  if (value < 1 || value > 5) return null;
  return value;
}

Future<void> showAditivoPeligrosidadDialog(
  BuildContext context, {
  required int? peligrosidad,
  required String titulo,
}) async {
  final normalized = _normalizePeligrosidad(peligrosidad);

  final peligrosidadData = {
    1: {
      'label': 'Seguro',
      'descripcion':
          'Aditivo bien tolerado y seguro para el consumo general. No se han documentado efectos adversos a las dosis habituales.',
      'advertencia':
          'No requiere restriccion. Puedes consumirlo sin preocupacion.',
      'color': Colors.green.shade700,
    },
    2: {
      'label': 'Atencion',
      'descripcion':
          'Aditivo que requiere moderacion. Algunas personas pueden presentar sensibilidad o efectos secundarios menores. Se recomienda limitar su consumo.',
      'advertencia':
          'Moderacion recomendada. Limita su consumo, especialmente en menores o personas sensibles.',
      'color': Colors.amber.shade800,
    },
    3: {
      'label': 'Alto',
      'descripcion':
          'Aditivo con potencial para efectos adversos en consumo frecuente. Personas sensibles, embarazadas o con alergias deben evitarlo. Consulta con tu dietista.',
      'advertencia':
          'Potencial riesgo. Evitalo si eres sensible, embarazada o tienes alergias. Consulta con tu dietista.',
      'color': Colors.orange.shade700,
    },
    4: {
      'label': 'Restringido',
      'descripcion':
          'Aditivo que debe evitarse o consumirse unicamente bajo supervision profesional. Vinculado a problemas de salud en estudios cientificos.',
      'advertencia':
          'Alto riesgo. Evita su consumo o consulta con tu profesional de salud antes de consumirlo.',
      'color': Colors.red.shade600,
    },
    5: {
      'label': 'Prohibido',
      'descripcion':
          'Aditivo prohibido o muy restringido en muchos paises. Conocido por efectos adversos significativos para la salud. Evitar completamente en la medida de lo posible.',
      'advertencia':
          'Riesgo severo. Evitar completamente. Este aditivo esta prohibido en muchos paises por sus efectos adversos.',
      'color': Colors.red.shade800,
    },
  };

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tabla de Peligrosidad',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aditivo: $titulo',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(dialogContext),
            tooltip: 'Cerrar',
            style: IconButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Clasificacion de niveles:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              ...List<int>.from([1, 2, 3, 4, 5]).map((nivel) {
                final data = peligrosidadData[nivel]!;
                final isSelected = normalized == nivel;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: (data['color'] as Color).withValues(alpha: 0.08),
                    border: Border.all(
                      color: isSelected
                          ? (data['color'] as Color)
                          : (data['color'] as Color).withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: data['color'] as Color,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              nivel.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['label'] as String,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: data['color'] as Color,
                                      ),
                                ),
                                if (isSelected)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (data['color'] as Color)
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Este aditivo',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: data['color'] as Color,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['descripcion'] as String,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              (data['color'] as Color).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              nivel >= 3
                                  ? Icons.warning_rounded
                                  : Icons.info_rounded,
                              size: 18,
                              color: data['color'] as Color,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data['advertencia'] as String,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: data['color'] as Color,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aviso Importante',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Esta informacion es orientativa. Para una valoracion personalizada, consulta siempre con tu profesional dietista.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.amber.shade900,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      actions: [
        Center(
          child: FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => const ContactoNutricionistaScreen(),
                ),
              );
            },
            icon: const Icon(Icons.mail_outline),
            label: const Text('Contactar con Dietista'),
          ),
        ),
      ],
    ),
  );
}
