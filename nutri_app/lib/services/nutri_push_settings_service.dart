import 'package:shared_preferences/shared_preferences.dart';

class NutriPushSettingsService {
  static const String _chatUnreadPushPrefix = 'nutri_push_chat_unread_enabled_';

  static String _chatUnreadKey(String scope) => '$_chatUnreadPushPrefix$scope';

  static Future<bool> getChatUnreadPushEnabled(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chatUnreadKey(scope)) ?? true;
  }

  static Future<void> setChatUnreadPushEnabled(
    String scope,
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chatUnreadKey(scope), enabled);
  }
}
