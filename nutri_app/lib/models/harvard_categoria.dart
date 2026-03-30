import 'package:flutter/material.dart';

class HarvardCategoria {
  final String codigo;
  final String nombre;
  final String? descripcion;
  final String seccionPlato;
  final bool esRecomendado;
  final String colorHex;
  final String iconoEmoji;
  final int ordenDisplay;

  const HarvardCategoria({
    required this.codigo,
    required this.nombre,
    this.descripcion,
    required this.seccionPlato,
    required this.esRecomendado,
    required this.colorHex,
    required this.iconoEmoji,
    required this.ordenDisplay,
  });

  factory HarvardCategoria.fromJson(Map<String, dynamic> json) {
    return HarvardCategoria(
      codigo: json['codigo']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      descripcion: json['descripcion']?.toString(),
      seccionPlato: json['seccion_plato']?.toString() ?? 'otro',
      esRecomendado: (json['es_recomendado']?.toString() ?? '1') == '1',
      colorHex: json['color_hex']?.toString() ?? '#9E9E9E',
      iconoEmoji: json['icono_emoji']?.toString() ?? '',
      ordenDisplay: int.tryParse(json['orden_display']?.toString() ?? '0') ?? 0,
    );
  }

  /// Parses colorHex (#RRGGBB) into a Flutter [Color].
  Color get color {
    try {
      final hex = colorHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  /// Human-readable label for the plate section.
  static String seccionLabel(String seccion) {
    switch (seccion) {
      case 'medio_plato':
        return 'Medio plato (verduras/frutas)';
      case 'cuarto_cereales':
        return '¼ cereales';
      case 'cuarto_proteinas':
        return '¼ proteínas';
      case 'aceites':
        return 'Aceites y lácteos';
      case 'bebidas':
        return 'Bebidas';
      default:
        return 'Otros';
    }
  }
}
