import 'package:shared_preferences/shared_preferences.dart';

class UserSettingsService {
  static const String _nutriNotifPrefix =
      'user_settings_notif_incumplimiento_nutri';
  static const String _fitNotifPrefix =
      'user_settings_notif_incumplimiento_fit';
  static const String _chatUnreadPushPrefix =
      'user_settings_chat_unread_push_enabled';
  static const String _legendPerimetersPrefix =
      'user_settings_legend_perimeters';
  static const String _legendWeightCalendarPrefix =
      'user_settings_legend_weight_calendar';
  static const String _legendTasksCalendarPrefix =
      'user_settings_legend_tasks_calendar';
  static const String _calendarTasksViewPrefix =
      'user_settings_calendar_tasks_view';
  static const String _calendarWeightControlViewPrefix =
      'user_settings_calendar_weight_control_view';
  static const String _calendarNutriAdherenceViewPrefix =
      'user_settings_calendar_nutri_adherence_view';
  static const String _calendarFitAdherenceViewPrefix =
      'user_settings_calendar_fit_adherence_view';

  static String buildScopeKey({
    required bool isGuestMode,
    String? userCode,
    String? patientCode,
    String? userType,
  }) {
    final normalizedUserCode = (userCode ?? '').trim();
    final normalizedPatientCode = (patientCode ?? '').trim();
    final normalizedUserType = (userType ?? '').trim().toLowerCase();

    if (isGuestMode || normalizedUserCode.isEmpty) {
      return 'guest';
    }

    if (normalizedPatientCode.isNotEmpty) {
      return 'registered_with_patient_${normalizedUserType}_${normalizedUserCode}_$normalizedPatientCode';
    }

    return 'registered_${normalizedUserType}_$normalizedUserCode';
  }

  static String _nutriNotifKey(String scope) => '${_nutriNotifPrefix}_$scope';
  static String _fitNotifKey(String scope) => '${_fitNotifPrefix}_$scope';
  static String _chatUnreadPushKey(String scope) =>
      '${_chatUnreadPushPrefix}_$scope';
  static String _legendPerimetersKey(String scope) =>
      '${_legendPerimetersPrefix}_$scope';
  static String _legendWeightCalendarKey(String scope) =>
      '${_legendWeightCalendarPrefix}_$scope';
  static String _legendTasksCalendarKey(String scope) =>
      '${_legendTasksCalendarPrefix}_$scope';
  static String _calendarTasksViewKey(String scope) =>
      '${_calendarTasksViewPrefix}_$scope';
  static String _calendarWeightControlViewKey(String scope) =>
      '${_calendarWeightControlViewPrefix}_$scope';
  static String _calendarNutriAdherenceViewKey(String scope) =>
      '${_calendarNutriAdherenceViewPrefix}_$scope';
  static String _calendarFitAdherenceViewKey(String scope) =>
      '${_calendarFitAdherenceViewPrefix}_$scope';

  static String _normalizeCalendarViewMode(String? mode) {
    switch (mode) {
      case 'week':
      case 'twoWeeks':
      case 'month':
        return mode!;
      default:
        return 'month';
    }
  }

  static Future<bool> getNutriPlanBreachNotificationEnabled(
      String scope) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_nutriNotifKey(scope)) ?? true;
  }

  static Future<bool> getFitPlanBreachNotificationEnabled(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_fitNotifKey(scope)) ?? true;
  }

  static Future<bool> getChatUnreadPushEnabled(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chatUnreadPushKey(scope)) ?? true;
  }

  static Future<bool> getPerimetersLegendEnabled(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_legendPerimetersKey(scope)) ?? true;
  }

  static Future<bool> getWeightCalendarLegendEnabled(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_legendWeightCalendarKey(scope)) ?? true;
  }

  static Future<bool> getTasksCalendarLegendEnabled(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_legendTasksCalendarKey(scope)) ?? true;
  }

  static Future<String> getTasksCalendarViewMode(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    return _normalizeCalendarViewMode(
      prefs.getString(_calendarTasksViewKey(scope)),
    );
  }

  static Future<String> getWeightControlCalendarViewMode(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    return _normalizeCalendarViewMode(
      prefs.getString(_calendarWeightControlViewKey(scope)),
    );
  }

  static Future<String> getNutriAdherenceCalendarViewMode(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    return _normalizeCalendarViewMode(
      prefs.getString(_calendarNutriAdherenceViewKey(scope)),
    );
  }

  static Future<String> getFitAdherenceCalendarViewMode(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    return _normalizeCalendarViewMode(
      prefs.getString(_calendarFitAdherenceViewKey(scope)),
    );
  }

  static Future<void> setNutriPlanBreachNotificationEnabled(
    String scope,
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_nutriNotifKey(scope), enabled);
  }

  static Future<void> setFitPlanBreachNotificationEnabled(
    String scope,
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fitNotifKey(scope), enabled);
  }

  static Future<void> setChatUnreadPushEnabled(
    String scope,
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chatUnreadPushKey(scope), enabled);
  }

  static Future<void> setPerimetersLegendEnabled(
    String scope,
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_legendPerimetersKey(scope), enabled);
  }

  static Future<void> setWeightCalendarLegendEnabled(
    String scope,
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_legendWeightCalendarKey(scope), enabled);
  }

  static Future<void> setTasksCalendarLegendEnabled(
    String scope,
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_legendTasksCalendarKey(scope), enabled);
  }

  static Future<void> setTasksCalendarViewMode(
    String scope,
    String mode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _calendarTasksViewKey(scope),
      _normalizeCalendarViewMode(mode),
    );
  }

  static Future<void> setWeightControlCalendarViewMode(
    String scope,
    String mode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _calendarWeightControlViewKey(scope),
      _normalizeCalendarViewMode(mode),
    );
  }

  static Future<void> setNutriAdherenceCalendarViewMode(
    String scope,
    String mode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _calendarNutriAdherenceViewKey(scope),
      _normalizeCalendarViewMode(mode),
    );
  }

  static Future<void> setFitAdherenceCalendarViewMode(
    String scope,
    String mode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _calendarFitAdherenceViewKey(scope),
      _normalizeCalendarViewMode(mode),
    );
  }
}
