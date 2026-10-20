import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('access_token');
    await preferences.remove('session_lookup');
    await preferences.remove('session_role');
  }
}
