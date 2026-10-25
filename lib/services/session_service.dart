import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SessionService {
  static Future<void> logout() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('access_token');
      await preferences.remove('session_lookup');
      await preferences.remove('session_role');
    } catch (error) {
      // Navigation to Login must remain available even if local storage is
      // temporarily unavailable on the device.
      debugPrint('[SESSION] Could not clear local session: $error');
    }
  }
}
