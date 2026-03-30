import 'package:shared_preferences/shared_preferences.dart';

class NutriPlanSettingsService {
  static const String _enabledMealsPrefix = 'nutri_plan_enabled_meals_';

  static const List<String> defaultMeals = [
    'Desayuno',
    'Almuerzo',
    'Comida',
    'Merienda',
    'Cena',
  ];

  static String _enabledMealsKey(String scope) => '$_enabledMealsPrefix$scope';

  static Future<List<String>> getEnabledMeals(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_enabledMealsKey(scope));
    if (stored == null || stored.isEmpty) {
      return List<String>.from(defaultMeals);
    }

    final normalized = defaultMeals.where(stored.contains).toList();
    if (normalized.isEmpty) {
      return List<String>.from(defaultMeals);
    }
    return normalized;
  }

  static Future<void> setEnabledMeals(String scope, List<String> meals) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = defaultMeals.where(meals.contains).toList();
    await prefs.setStringList(
      _enabledMealsKey(scope),
      normalized.isEmpty ? List<String>.from(defaultMeals) : normalized,
    );
  }
}
