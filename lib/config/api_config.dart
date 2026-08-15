import 'package:flutter/foundation.dart';

/// Centralized API Configuration for PawStay application.
/// Automatically resolves the correct backend host depending on target platform:
/// - Android emulator: http://10.0.2.2:8000
/// - Web / Windows Desktop / macOS / Linux: http://127.0.0.1:8000
class ApiConfig {
  static const int port = 8000;

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$port';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$port';
    }
    return 'http://127.0.0.1:$port';
  }
}
