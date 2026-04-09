import 'dart:convert';

import 'package:nutri_app/services/api_service.dart';

class MenuEntryConfig {
  const MenuEntryConfig({
    required this.visible,
    required this.premium,
  });

  final bool visible;
  final bool premium;

  MenuEntryConfig copyWith({
    bool? visible,
    bool? premium,
  }) {
    return MenuEntryConfig(
      visible: visible ?? this.visible,
      premium: premium ?? this.premium,
    );
  }
}

class MenuVisibilityPremiumService {
  static const String parametroNombre = 'menu_visible_premium';

  static const String recomendaciones = 'recomendaciones';
  static const String consejos = 'consejos';
  static const String videosEjercicios = 'videos_ejercicios';
  static const String catalogoEjercicios = 'catalogo_ejercicios';
  static const String sustitucionesSaludables = 'sustituciones_saludables';
  static const String charlasSeminarios = 'charlas_seminarios';
  static const String suplementos = 'suplementos';
  static const String aditivosAlimentarios = 'aditivos_alimentarios';
  static const String planesNutri = 'planes_nutri';
  static const String planesFit = 'planes_fit';
  static const String recetas = 'recetas';
  static const String actividades = 'actividades';
  static const String controlPeso = 'control_peso';
  static const String listaCompra = 'lista_compra';
  static const String escaner = 'escaner';
  static const String tareas = 'tareas';

  static Future<Map<String, MenuEntryConfig>>? _cache;

  static Map<String, MenuEntryConfig> defaultConfig() {
    return <String, MenuEntryConfig>{
      recomendaciones: const MenuEntryConfig(visible: true, premium: false),
      consejos: const MenuEntryConfig(visible: true, premium: false),
      videosEjercicios: const MenuEntryConfig(visible: true, premium: true),
      catalogoEjercicios: const MenuEntryConfig(visible: true, premium: true),
      sustitucionesSaludables:
          const MenuEntryConfig(visible: true, premium: true),
      charlasSeminarios: const MenuEntryConfig(visible: true, premium: true),
      suplementos: const MenuEntryConfig(visible: true, premium: true),
      aditivosAlimentarios: const MenuEntryConfig(visible: true, premium: true),
      planesNutri: const MenuEntryConfig(visible: true, premium: false),
      planesFit: const MenuEntryConfig(visible: true, premium: false),
      recetas: const MenuEntryConfig(visible: true, premium: false),
      actividades: const MenuEntryConfig(visible: true, premium: false),
      controlPeso: const MenuEntryConfig(visible: true, premium: false),
      listaCompra: const MenuEntryConfig(visible: true, premium: false),
      escaner: const MenuEntryConfig(visible: true, premium: false),
      tareas: const MenuEntryConfig(visible: true, premium: false),
    };
  }

  static Future<Map<String, MenuEntryConfig>> loadConfig({
    ApiService? apiService,
    bool forceRefresh = false,
  }) {
    if (!forceRefresh && _cache != null) {
      return _cache!;
    }

    _cache = _fetchConfig(apiService ?? ApiService());
    return _cache!;
  }

  static bool isVisible(Map<String, MenuEntryConfig> config, String key) {
    final resolved = config[key] ?? defaultConfig()[key];
    return resolved?.visible ?? true;
  }

  static bool isPremium(Map<String, MenuEntryConfig> config, String key) {
    final resolved = config[key] ?? defaultConfig()[key];
    return resolved?.premium ?? false;
  }

  static bool isPrivilegedUserType(String? userType) {
    final normalized = (userType ?? '').trim().toLowerCase();
    return normalized == 'nutricionista' || normalized == 'administrador';
  }

  static bool canAccessPremiumMarkedEntry({
    required Map<String, MenuEntryConfig> config,
    required String key,
    required bool isPremiumUser,
    required String? userType,
  }) {
    if (!isPremium(config, key)) {
      return true;
    }

    if (isPremiumUser) {
      return true;
    }

    return isPrivilegedUserType(userType);
  }

  static Future<Map<String, MenuEntryConfig>> _fetchConfig(
    ApiService apiService,
  ) async {
    final fallback = defaultConfig();

    try {
      final raw = await apiService.getParametroValor(parametroNombre);
      if ((raw ?? '').trim().isEmpty) {
        return fallback;
      }

      final decoded = json.decode(raw!);
      if (decoded is! Map<String, dynamic>) {
        return fallback;
      }

      final resolved = <String, MenuEntryConfig>{...fallback};
      for (final entry in decoded.entries) {
        final key = entry.key.trim().toLowerCase();
        final current = resolved[key];
        if (current == null || entry.value is! Map) {
          continue;
        }

        final value = Map<String, dynamic>.from(entry.value as Map);
        resolved[key] = current.copyWith(
          visible: _parseBool(value['visible'], current.visible),
          premium: _parseBool(value['premium'], current.premium),
        );
      }

      return resolved;
    } catch (_) {
      return fallback;
    }
  }

  static bool _parseBool(dynamic value, bool fallback) {
    if (value is bool) {
      return value;
    }

    final normalized = (value ?? '').toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 's') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'n') {
      return false;
    }

    return fallback;
  }
}
