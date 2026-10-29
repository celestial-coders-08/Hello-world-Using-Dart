import 'package:flutter/foundation.dart';

/// Centralized API Configuration for PawStay application.
/// Automatically resolves the correct backend host depending on target platform:
/// - Physical Android device: uses [androidHost] (your laptop's LAN IP)
/// - Android emulator: override PAWSTAY_API_HOST with 10.0.2.2
/// - Web / Windows Desktop / macOS / Linux: http://127.0.0.1:8000 / :8001
class ApiConfig {
  static const int port = 8000;
  static const int messagePort = 8001;
  static const int providerPort = 8002;
  static const int sellerPort = 8003;
  static const int paymentPort = 8004;
  static const int adminPort = 8005;
  static const int aiPort = 8006;

  /// ── IMPORTANT ─────────────────────────────────────────────────────────────
  /// Fallback laptop LAN IP for a physical Android device. Override at build/run
  /// time with `--dart-define=PAWSTAY_API_HOST=host`; use 10.0.2.2 on emulator.
  /// ──────────────────────────────────────────────────────────────────────────
  static const String deviceIp = String.fromEnvironment(
    'PAWSTAY_API_HOST',
    defaultValue: '192.168.137.236',
  );
  static const String androidHost = deviceIp;

  /// Whether we are running on a real physical Android device.
  /// Android uses [androidHost] for both physical devices and emulators; set
  /// PAWSTAY_API_HOST to the appropriate host when building for an emulator.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$port';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://$androidHost:$port';
    }
    return 'http://127.0.0.1:$port';
  }

  /// URL for the PawStay Message Microservice (port 8001).
  static String get messageBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$messagePort';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://$androidHost:$messagePort';
    }
    return 'http://127.0.0.1:$messagePort';
  }

  /// URL for the independent Service Provider API server.
  static String get providerBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$providerPort';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://$androidHost:$providerPort';
    }
    return 'http://127.0.0.1:$providerPort';
  }

  /// URL for the independent Seller API server.
  static String get sellerBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$sellerPort';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://$androidHost:$sellerPort';
    }
    return 'http://127.0.0.1:$sellerPort';
  }

  /// URL for the independent marketplace payment API.
  static String get paymentBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$paymentPort';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://$androidHost:$paymentPort';
    }
    return 'http://127.0.0.1:$paymentPort';
  }

  /// URL for the dedicated admin reporting and seller review API.
  static String get adminBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$adminPort';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://$androidHost:$adminPort';
    }
    return 'http://127.0.0.1:$adminPort';
  }

  /// URL for the role-aware PawStay AI assistant service.
  static String get aiBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$aiPort';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://$androidHost:$aiPort';
    }
    return 'http://127.0.0.1:$aiPort';
  }
}
