import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class PaymentApiService {
  static const Duration _timeout = Duration(seconds: 15);
  static final http.Client _client = http.Client();

  static Future<List<Map<String, dynamic>>> fetchMarketplaceProducts() async {
    final response = await _client
        .get(
          Uri.parse('${ApiConfig.paymentBaseUrl}/shop/products'),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(_timeout);
    final decoded = _decodeResponse(response);
    return List<Map<String, dynamic>>.from(decoded as List);
  }

  static Future<Map<String, dynamic>> createCheckoutOrder(int productId) async {
    return _createCheckoutOrder({'product_id': productId});
  }

  static Future<Map<String, dynamic>?> fetchBuyerAddress() async {
    final response = await _client
        .get(
          Uri.parse('${ApiConfig.paymentBaseUrl}/payments/address'),
          headers: await _authenticatedHeaders(),
        )
        .timeout(_timeout);
    final decoded = _decodeResponse(response);
    return decoded == null ? null : Map<String, dynamic>.from(decoded as Map);
  }

  static Future<Map<String, dynamic>> saveBuyerAddress({
    required String apartmentFlat,
    required String streetAddress,
    required String state,
    required String city,
    required String postalCode,
  }) async {
    final response = await _client
        .put(
          Uri.parse('${ApiConfig.paymentBaseUrl}/payments/address'),
          headers: await _authenticatedHeaders(),
          body: jsonEncode({
            'apartment_flat': apartmentFlat,
            'street_address': streetAddress,
            'state': state,
            'city': city,
            'postal_code': postalCode,
          }),
        )
        .timeout(_timeout);
    return Map<String, dynamic>.from(_decodeResponse(response) as Map);
  }

  static Future<Map<String, dynamic>> createCartCheckoutOrder(
    List<Map<String, int>> items,
  ) async {
    if (items.isEmpty) {
      throw ArgumentError.value(
        items,
        'items',
        'A checkout cart cannot be empty.',
      );
    }
    return _createCheckoutOrder({'items': items});
  }

  static Future<Map<String, dynamic>> _createCheckoutOrder(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client
        .post(
          Uri.parse('${ApiConfig.paymentBaseUrl}/payments/orders'),
          headers: await _authenticatedHeaders(),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);
    return Map<String, dynamic>.from(_decodeResponse(response) as Map);
  }

  static Future<Map<String, dynamic>> verifyCheckoutPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final response = await _client
        .post(
          Uri.parse('${ApiConfig.paymentBaseUrl}/payments/verify'),
          headers: await _authenticatedHeaders(),
          body: jsonEncode({
            'razorpay_order_id': razorpayOrderId,
            'razorpay_payment_id': razorpayPaymentId,
            'razorpay_signature': razorpaySignature,
          }),
        )
        .timeout(_timeout);
    return Map<String, dynamic>.from(_decodeResponse(response) as Map);
  }

  static Future<List<Map<String, dynamic>>> fetchOrders() async {
    final response = await _client
        .get(
          Uri.parse('${ApiConfig.paymentBaseUrl}/payments/orders'),
          headers: await _authenticatedHeaders(),
        )
        .timeout(_timeout);
    final decoded = _decodeResponse(response);
    return List<Map<String, dynamic>>.from(decoded as List);
  }

  static Future<Map<String, String>> _authenticatedHeaders() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('access_token');
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in again before placing or viewing orders.');
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static dynamic _decodeResponse(http.Response response) {
    final dynamic decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic>
          ? decoded['detail']?.toString()
          : null;
      throw Exception(
        detail ?? 'Marketplace request failed (${response.statusCode}).',
      );
    }
    return decoded;
  }
}
