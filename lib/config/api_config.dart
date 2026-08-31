import 'package:flutter/foundation.dart';

/// Centralized API Configuration for PawStay application.
/// Automatically resolves the correct backend host depending on target platform:
/// - Physical Android device (wireless debug): uses [deviceIp] (your laptop's LAN IP)
/// - Android emulator: http://10.0.2.2:8000 / :8001
/// - Web / Windows Desktop / macOS / Linux: http://127.0.0.1:8000 / :8001
class ApiConfig {
  static const int port = 8000;
  static const int messagePort = 8001;

  /// ── IMPORTANT ─────────────────────────────────────────────────────────────
  /// Set this to your laptop's local network IP address (e.g. 192.168.1.5).
  /// Find it by running `ipconfig` in PowerShell and looking for
  /// "IPv4 Address" under your Wi-Fi adapter.
  /// This is used when running on a physical Android device via wireless debug.
  /// ──────────────────────────────────────────────────────────────────────────
  static const String deviceIp =
      '192.168.1.103'; // Your laptop's LAN IP (run `ipconfig` to verify)

  /// Whether we are running on a real physical Android device.
  /// On a physical device, [isAndroid] is true but [10.0.2.2] does NOT work.
  /// We detect this by checking that we are not on an emulator via a flag we
  /// cannot set at compile-time, so instead we always try [deviceIp] as the
  /// primary address for Android and fall back to emulator address.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$port';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Physical device uses the laptop's real LAN IP; emulator uses 10.0.2.2.
      // We return the real IP — emulator also works with the real IP if both
      // the laptop and emulator are on the same virtual network segment,
      // but most setups use 10.0.2.2 for emulator. The _candidateBaseUrls
      // fallback in profile_screen.dart handles both cases automatically.
      return 'http://$deviceIp:$port';
    }
    return 'http://127.0.0.1:$port';
  }

  /// URL for the PawStay Message Microservice (port 8001).
  static String get messageBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$messagePort';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://$deviceIp:$messagePort';
    }
    return 'http://127.0.0.1:$messagePort';
  }
}
