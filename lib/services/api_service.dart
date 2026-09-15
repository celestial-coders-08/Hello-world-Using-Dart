import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Centralized API Service for all PawStay full-stack operations.
class ApiService {
  static final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 10);

  static String get _providerBaseUrl => ApiConfig.providerBaseUrl;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ---------------------------------------------------------------------------
  // SERVICES (CUSTOMER & PROVIDER)
  // ---------------------------------------------------------------------------

  /// Fetch active services for Customer Dashboard & Search
  static Future<List<Map<String, dynamic>>> fetchActiveServices({
    String? query,
    String? city,
    String? petType,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (query != null && query.trim().isNotEmpty) {
        queryParams['q'] = query.trim();
      }
      if (city != null && city.trim().isNotEmpty) {
        queryParams['city'] = city.trim();
      }
      if (petType != null && petType.trim().isNotEmpty) {
        queryParams['pet_type'] = petType.trim();
      }

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/services',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint('[API ERROR] fetchActiveServices: $e');
    }
    return [];
  }

  /// Fetch single service details
  static Future<Map<String, dynamic>?> fetchServiceDetails(
    int serviceId,
  ) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/services/$serviceId');
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('[API ERROR] fetchServiceDetails: $e');
    }
    return null;
  }

  /// Fetch all services for Provider Dashboard (Active & Paused)
  static Future<List<Map<String, dynamic>>> fetchProviderServices({
    String? providerLookup,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (providerLookup != null && providerLookup.trim().isNotEmpty) {
        queryParams['provider_lookup'] = providerLookup.trim();
      }

      final uri = Uri.parse(
        '$_providerBaseUrl/provider/services',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint('[API ERROR] fetchProviderServices: $e');
    }
    return [];
  }

  /// Create a new Service (Phase 1: Add Service)
  static Future<Map<String, dynamic>?> createService(
    Map<String, dynamic> payload,
  ) async {
    try {
      final uri = Uri.parse('$_providerBaseUrl/provider/services');
      final response = await _client
          .post(uri, headers: _headers, body: jsonEncode(payload))
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('[API ERROR] createService: $e');
    }
    return null;
  }

  /// Update an existing Service (Phase 1: Edit Service)
  static Future<Map<String, dynamic>?> updateService(
    int serviceId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final uri = Uri.parse('$_providerBaseUrl/provider/services/$serviceId');
      final response = await _client
          .put(uri, headers: _headers, body: jsonEncode(payload))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('[API ERROR] updateService: $e');
    }
    return null;
  }

  /// Pause / Resume Service (Phase 1)
  static Future<bool> updateServiceStatus(int serviceId, String status) async {
    try {
      final uri = Uri.parse(
        '$_providerBaseUrl/provider/services/$serviceId/status',
      );
      final response = await _client
          .patch(uri, headers: _headers, body: jsonEncode({'status': status}))
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[API ERROR] updateServiceStatus: $e');
      return false;
    }
  }

  /// Soft Delete Service (Phase 1)
  static Future<bool> deleteService(int serviceId) async {
    try {
      final uri = Uri.parse('$_providerBaseUrl/provider/services/$serviceId');
      final response = await _client
          .delete(uri, headers: _headers)
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[API ERROR] deleteService: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // PROVIDER DASHBOARD & ANALYTICS
  // ---------------------------------------------------------------------------

  /// Fetch live dynamic statistics from MySQL
  static Future<Map<String, dynamic>?> fetchDashboardStats({
    String? providerLookup,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (providerLookup != null && providerLookup.trim().isNotEmpty) {
        queryParams['provider_lookup'] = providerLookup.trim();
      }

      final uri = Uri.parse(
        '$_providerBaseUrl/provider/dashboard-stats',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('[API ERROR] fetchDashboardStats: $e');
    }
    return null;
  }

  /// Toggle Online/Offline host status
  static Future<bool> updateProviderOnlineStatus(
    bool isOnline, {
    String? providerLookup,
  }) async {
    try {
      final uri = Uri.parse('$_providerBaseUrl/provider/status');
      final response = await _client
          .patch(
            uri,
            headers: _headers,
            body: jsonEncode({'is_online': isOnline, 'lookup': providerLookup}),
          )
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[API ERROR] updateProviderOnlineStatus: $e');
      return false;
    }
  }

  static List<String> get _candidateProviderUrls => [
    _providerBaseUrl,
    'http://127.0.0.1:8002',
    'http://${ApiConfig.deviceIp}:8002',
    'http://10.0.2.2:8002',
    'http://localhost:8002',
    'http://127.0.0.1:8000',
    'http://${ApiConfig.deviceIp}:8000',
    'http://10.0.2.2:8000',
    'http://localhost:8000',
  ];

  /// Fetch the provider's editable service profile and verified identity fields.
  static Future<Map<String, dynamic>?> fetchProviderProfile({
    required String providerLookup,
  }) async {
    Map<String, dynamic> result = {};

    // First try identity profile from main backend
    for (final baseUrl in [
      ApiConfig.baseUrl,
      'http://127.0.0.1:8000',
      'http://${ApiConfig.deviceIp}:8000',
      'http://10.0.2.2:8000',
      'http://localhost:8000',
    ]) {
      try {
        final identityUri = Uri.parse(
          '$baseUrl/profile',
        ).replace(queryParameters: {'lookup': providerLookup});
        final res = await _client
            .get(identityUri, headers: _headers)
            .timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          result.addAll(Map<String, dynamic>.from(jsonDecode(res.body)));
          break;
        }
      } catch (_) {}
    }

    try {
      final reviewProfileUri = Uri.parse(
        '${ApiConfig.baseUrl}/provider/profile',
      ).replace(queryParameters: {'lookup': providerLookup});
      final res = await _client
          .get(reviewProfileUri, headers: _headers)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final reviewProfile = Map<String, dynamic>.from(jsonDecode(res.body));
        if (reviewProfile.containsKey('average_rating')) {
          result['average_rating'] = reviewProfile['average_rating'];
        }
        if (reviewProfile.containsKey('review_count')) {
          result['review_count'] = reviewProfile['review_count'];
        }
      }
    } catch (_) {}

    // Now try provider specific profile charges & description
    for (final baseUrl in _candidateProviderUrls) {
      try {
        final providerUri = Uri.parse(
          '$baseUrl/provider/profile',
        ).replace(queryParameters: {'lookup': providerLookup});
        final res = await _client
            .get(providerUri, headers: _headers)
            .timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          result.addAll(Map<String, dynamic>.from(jsonDecode(res.body)));
          return result;
        }
      } catch (_) {}
    }

    return result.isNotEmpty ? result : null;
  }

  /// Save provider pricing and description while keeping identity read-only.
  static Future<bool> updateProviderProfile({
    required String providerLookup,
    required int walkingCharge,
    required int daycareCharge,
    required int daycareFoodCharge,
    required String description,
  }) async {
    final payload = jsonEncode({
      'lookup': providerLookup,
      'walking_charge': walkingCharge,
      'daycare_charge': daycareCharge,
      'daycare_food_charge': daycareFoodCharge,
      'provider_description': description,
    });

    for (final baseUrl in _candidateProviderUrls) {
      try {
        final uri = Uri.parse('$baseUrl/provider/profile');
        final response = await _client
            .put(uri, headers: _headers, body: payload)
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200 || response.statusCode == 201) {
          return true;
        }
      } catch (e) {
        debugPrint('[API ERROR] updateProviderProfile on $baseUrl: $e');
      }
    }
    return false;
  }

  /// Upload provider profile photo
  static Future<bool> uploadProfilePhoto({
    required String providerLookup,
    required String base64Image,
  }) async {
    final payload = jsonEncode({
      'lookup': providerLookup,
      'profile_image': base64Image,
    });

    for (final baseUrl in [
      ApiConfig.baseUrl,
      'http://127.0.0.1:8000',
      'http://${ApiConfig.deviceIp}:8000',
      'http://10.0.2.2:8000',
      'http://localhost:8000',
      'http://127.0.0.1:8002',
      'http://${ApiConfig.deviceIp}:8002',
      'http://10.0.2.2:8002',
    ]) {
      try {
        final uri = Uri.parse('$baseUrl/profile/photo');
        final response = await _client
            .post(uri, headers: _headers, body: payload)
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 || response.statusCode == 201) {
          return true;
        }
      } catch (e) {
        debugPrint('[API ERROR] uploadProfilePhoto on $baseUrl: $e');
      }
    }
    return false;
  }

  /// Delete an account after the main backend verifies its password.
  static Future<Map<String, dynamic>> deleteAccount({
    required String lookup,
    required String password,
  }) async {
    final payload = jsonEncode({'lookup': lookup, 'password': password});
    Object? lastError;

    for (final baseUrl in [
      ApiConfig.baseUrl,
      'http://127.0.0.1:8000',
      'http://${ApiConfig.deviceIp}:8000',
      'http://10.0.2.2:8000',
      'http://localhost:8000',
    ]) {
      try {
        final response = await _client
            .post(
              Uri.parse('$baseUrl/delete-account'),
              headers: _headers,
              body: payload,
            )
            .timeout(const Duration(seconds: 10));
        final decoded = jsonDecode(response.body);
        return {
          'success': response.statusCode == 200,
          'message': decoded['message'] ?? decoded['detail'],
        };
      } catch (e) {
        lastError = e;
      }
    }

    debugPrint('[API ERROR] deleteAccount: $lastError');
    return {'success': false, 'message': 'Could not connect to server.'};
  }

  // ---------------------------------------------------------------------------
  // BOOKINGS & CALENDAR
  // ---------------------------------------------------------------------------

  /// Customer creates a booking
  static Future<Map<String, dynamic>?> createBooking(
    Map<String, dynamic> payload,
  ) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/bookings');
      final response = await _client
          .post(uri, headers: _headers, body: jsonEncode(payload))
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('[API ERROR] createBooking: $e');
    }
    return null;
  }

  /// Provider fetches bookings
  static Future<List<Map<String, dynamic>>> fetchProviderBookings({
    String? providerLookup,
    String? statusFilter,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (providerLookup != null && providerLookup.trim().isNotEmpty) {
        queryParams['provider_lookup'] = providerLookup.trim();
      }
      if (statusFilter != null && statusFilter.trim().isNotEmpty) {
        queryParams['status_filter'] = statusFilter.trim();
      }

      final uri = Uri.parse(
        '$_providerBaseUrl/provider/bookings',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint('[API ERROR] fetchProviderBookings: $e');
    }
    return [];
  }

  /// Provider updates booking status (Accept / Reject / Complete / Cancel)
  static Future<bool> updateBookingStatus(int bookingId, String status) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/bookings/$bookingId/status');
      final response = await _client
          .patch(uri, headers: _headers, body: jsonEncode({'status': status}))
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[API ERROR] updateBookingStatus: $e');
      return false;
    }
  }

  /// Provider calendar bookings
  static Future<Map<String, dynamic>?> fetchProviderCalendar({
    String? providerLookup,
    String filterType = 'all',
  }) async {
    try {
      final uri = Uri.parse(
        '$_providerBaseUrl/provider/calendar?filter_type=$filterType'
        '${providerLookup != null ? "&provider_lookup=$providerLookup" : ""}',
      );
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('[API ERROR] fetchProviderCalendar: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // REVIEWS
  // ---------------------------------------------------------------------------

  /// Fetch reviews for a provider
  static Future<List<Map<String, dynamic>>> fetchProviderReviews({
    String? providerLookup,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/reviews'
        '${providerLookup != null ? "?provider_lookup=$providerLookup" : ""}',
      );
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint('[API ERROR] fetchProviderReviews: $e');
    }
    return [];
  }

  /// Customer submits review
  static Future<Map<String, dynamic>?> submitReview(
    Map<String, dynamic> payload,
  ) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/reviews');
      final response = await _client
          .post(uri, headers: _headers, body: jsonEncode(payload))
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('[API ERROR] submitReview: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // PAYMENTS & EARNINGS
  // ---------------------------------------------------------------------------

  /// Process payment
  static Future<Map<String, dynamic>?> processPayment(
    Map<String, dynamic> payload,
  ) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/payments');
      final response = await _client
          .post(uri, headers: _headers, body: jsonEncode(payload))
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('[API ERROR] processPayment: $e');
    }
    return null;
  }

  /// Fetch provider earnings
  static Future<Map<String, dynamic>?> fetchProviderEarnings({
    String? providerLookup,
  }) async {
    try {
      final uri = Uri.parse(
        '$_providerBaseUrl/provider/earnings'
        '${providerLookup != null ? "?provider_lookup=$providerLookup" : ""}',
      );
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('[API ERROR] fetchProviderEarnings: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATIONS
  // ---------------------------------------------------------------------------

  /// Fetch notifications with unread count
  static Future<Map<String, dynamic>?> fetchNotifications({
    String? userLookup,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/notifications'
        '${userLookup != null ? "?user_lookup=$userLookup" : ""}',
      );
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('[API ERROR] fetchNotifications: $e');
    }
    return null;
  }

  /// Mark notifications read
  static Future<bool> markNotificationsRead({String? userLookup}) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/notifications/mark-read');
      final response = await _client
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({'user_lookup': userLookup}),
          )
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[API ERROR] markNotificationsRead: $e');
      return false;
    }
  }
}
