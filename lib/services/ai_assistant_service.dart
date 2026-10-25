import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class AiAssistantService {
  static const Duration _timeout = Duration(seconds: 55);
  static final http.Client _client = http.Client();

  static Future<List<Map<String, dynamic>>> fetchHistory({
    required String role,
    required String userId,
  }) async {
    final session = await _session(userId);
    final uri = Uri.parse(
      '${ApiConfig.aiBaseUrl}/assistant/history',
    ).replace(queryParameters: {'role': role, 'user_id': session.userId});
    final response = await _client
        .get(uri, headers: session.headers)
        .timeout(_timeout);
    final payload = _decodeResponse(response);
    if (payload is! List) {
      throw const FormatException('AI history response was invalid.');
    }
    return payload.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static Future<Map<String, String>> sendMessage({
    required String role,
    required String userId,
    required String message,
  }) async {
    final session = await _session(userId);
    final response = await _client
        .post(
          Uri.parse('${ApiConfig.aiBaseUrl}/assistant/chat'),
          headers: session.headers,
          body: jsonEncode({
            'role': role,
            'user_id': session.userId,
            'message': message,
          }),
        )
        .timeout(_timeout);
    final payload = _decodeResponse(response);
    if (payload is! Map<String, dynamic> ||
        payload['reply'] is! String ||
        payload['model'] is! String) {
      throw const FormatException('AI response was invalid.');
    }
    return {
      'reply': payload['reply'] as String,
      'model': payload['model'] as String,
    };
  }

  static Future<_AssistantSession> _session(String fallbackUserId) async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('access_token')?.trim();
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in to use PawStay AI.');
    }
    final userId = fallbackUserId.trim().isNotEmpty
        ? fallbackUserId.trim()
        : preferences.getString('session_lookup')?.trim() ?? '';
    if (userId.isEmpty) {
      throw Exception('Your PawStay account could not be identified.');
    }
    return _AssistantSession(userId, {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });
  }

  static dynamic _decodeResponse(http.Response response) {
    final dynamic body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      throw Exception(
        'AI service returned an unreadable response '
        '(HTTP ${response.statusCode}).',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = body is Map<String, dynamic>
          ? body['detail']?.toString()
          : null;
      throw Exception(
        detail ?? 'AI service request failed (HTTP ${response.statusCode}).',
      );
    }
    return body;
  }
}

class _AssistantSession {
  const _AssistantSession(this.userId, this.headers);

  final String userId;
  final Map<String, String> headers;
}
