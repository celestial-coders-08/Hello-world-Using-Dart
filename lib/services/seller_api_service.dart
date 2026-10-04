import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/api_config.dart';

class SellerApiService {
  static const Duration _timeout = Duration(seconds: 10);
  static final http.Client _client = http.Client();

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Future<List<Map<String, dynamic>>> fetchProducts(
    String sellerLookup, {
    String? listingType,
    String? animalType,
  }) async {
    final query = <String, String>{'lookup': sellerLookup};
    if (listingType != null && listingType != 'all') {
      query['listing_type'] = listingType;
    }
    if (animalType != null && animalType != 'all') {
      query['animal_type'] = animalType;
    }
    final uri = Uri.parse(
      '${ApiConfig.sellerBaseUrl}/seller/products',
    ).replace(queryParameters: query);
    final response = await _client.get(uri, headers: _headers).timeout(_timeout);
    return List<Map<String, dynamic>>.from(
      _decodeResponse(response) as List,
    );
  }

  static Future<Map<String, dynamic>> createListing({
    required String sellerLookup,
    required String listingType,
    required double price,
    required List<XFile> images,
    String name = '',
    String brand = '',
    String animalType = '',
    String breed = '',
    String description = '',
    List<String> suitableFor = const [],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.sellerBaseUrl}/seller/listings'),
    );
    request.fields.addAll({
      'seller_lookup': sellerLookup,
      'listing_type': listingType,
      'price': price.toString(),
      'name': name,
      'brand': brand,
      'animal_type': animalType,
      'breed': breed,
      'description': description,
      'suitable_for': jsonEncode(suitableFor),
    });
    for (final image in images) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'images',
          await image.readAsBytes(),
          filename: image.name,
        ),
      );
    }

    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);
    return Map<String, dynamic>.from(
      _decodeResponse(response) as Map<String, dynamic>,
    );
  }

  static Future<List<Map<String, dynamic>>> fetchOrders(
    String sellerLookup,
  ) async {
    final response = await _client
        .get(
          Uri.parse(
            '${ApiConfig.sellerBaseUrl}/seller/orders',
          ).replace(queryParameters: {'lookup': sellerLookup}),
          headers: _headers,
        )
        .timeout(_timeout);
    return List<Map<String, dynamic>>.from(
      _decodeResponse(response) as List,
    );
  }

  static Future<Map<String, dynamic>> updateOrderStatus({
    required String sellerLookup,
    required int orderId,
    required String status,
  }) async {
    final response = await _client
        .patch(
          Uri.parse(
            '${ApiConfig.sellerBaseUrl}/seller/orders/$orderId/status',
          ),
          headers: _headers,
          body: jsonEncode({
            'seller_lookup': sellerLookup,
            'order_status': status,
          }),
        )
        .timeout(_timeout);
    return Map<String, dynamic>.from(
      _decodeResponse(response) as Map<String, dynamic>,
    );
  }

  static Future<Map<String, dynamic>> fetchAnalytics(
    String sellerLookup,
  ) async {
    final response = await _client
        .get(
          Uri.parse(
            '${ApiConfig.sellerBaseUrl}/seller/analytics',
          ).replace(queryParameters: {'lookup': sellerLookup}),
          headers: _headers,
        )
        .timeout(_timeout);
    return Map<String, dynamic>.from(
      _decodeResponse(response) as Map<String, dynamic>,
    );
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
        detail ?? 'Seller API request failed (${response.statusCode}).',
      );
    }
    return decoded;
  }

  static String mediaUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '${ApiConfig.sellerBaseUrl}$path';
  }
}
