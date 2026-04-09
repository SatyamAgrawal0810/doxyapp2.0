// lib/services/chat_service.dart

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ChatService {
  final String baseUrl;
  final AuthService auth;

  ChatService({
    required this.baseUrl,
    required this.auth,
  });

  Map<String, String> _headers() {
    final token = auth.token ?? '';
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _safeDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (e) {
      print('❌ JSON decode error: $e');
      return null;
    }
  }

  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'session_${timestamp}_$random';
  }

  Future<List<dynamic>> getSessions() async {
    try {
      final url = Uri.parse('$baseUrl/sessions');
      print('📡 GET $url');

      final res = await http
          .get(url, headers: _headers())
          .timeout(Duration(seconds: 30));

      print('📥 Status: ${res.statusCode}');
      print('📥 Body: ${res.body}');

      if (res.statusCode == 200) {
        final data = _safeDecode(res.body);

        if (data != null && data['success'] == true) {
          final sessions = data['sessions'] as List<dynamic>? ?? [];
          print('✅ Loaded ${sessions.length} sessions');
          return sessions;
        }
      }

      throw Exception('Failed to fetch sessions: ${res.statusCode}');
    } catch (e) {
      print('❌ getSessions error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createSession(
      Map<String, dynamic> payload) async {
    try {
      // ✅ CRITICAL: Generate sessionId
      final sessionId = _generateSessionId();

      final modifiedPayload = {
        'sessionId': sessionId,
        'title': payload['title'] ?? 'New Chat',
      };

      final url = Uri.parse('$baseUrl/sessions');
      print('📡 POST $url');
      print('📤 Payload: ${jsonEncode(modifiedPayload)}');

      final res = await http
          .post(
            url,
            headers: _headers(),
            body: jsonEncode(modifiedPayload),
          )
          .timeout(Duration(seconds: 30));

      print('📥 Status: ${res.statusCode}');
      print('📥 Body: ${res.body}');

      final data = _safeDecode(res.body);

      if ((res.statusCode == 201 || res.statusCode == 200) &&
          data != null &&
          data['success'] == true) {
        print('✅ Session created successfully');

        return {
          'status': res.statusCode,
          'ok': true,
          'success': true,
          'session': data['session'],
          'id': data['session']?['_id'] ?? sessionId,
        };
      }

      print('❌ Create session failed: ${data?['message']}');

      return {
        'status': res.statusCode,
        'ok': false,
        'success': false,
        'message': data?['message'] ?? 'Failed to create session',
      };
    } catch (e) {
      print('❌ createSession error: $e');
      return {
        'status': 500,
        'ok': false,
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> getSession(String id) async {
    try {
      final url = Uri.parse('$baseUrl/sessions/$id');
      print('📡 GET $url');

      final res = await http
          .get(url, headers: _headers())
          .timeout(Duration(seconds: 30));

      print('📥 Status: ${res.statusCode}');

      if (res.statusCode == 200) {
        final data = _safeDecode(res.body);

        if (data != null && data['success'] == true) {
          return data['session'] as Map<String, dynamic>;
        }
      }

      throw Exception('Failed to fetch session');
    } catch (e) {
      print('❌ getSession error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateSession(
      String id, Map<String, dynamic> payload) async {
    try {
      final url = Uri.parse('$baseUrl/sessions/$id');
      print('📡 PUT $url');
      print('📤 Payload: ${jsonEncode(payload)}');

      final res = await http
          .put(
            url,
            headers: _headers(),
            body: jsonEncode(payload),
          )
          .timeout(Duration(seconds: 30));

      print('📥 Status: ${res.statusCode}');
      print('📥 Body: ${res.body}');

      if (res.statusCode == 200) {
        final data = _safeDecode(res.body);

        if (data != null && data['success'] == true) {
          return {
            'status': res.statusCode,
            'ok': true,
            'messages': data['session']?['messages'] ?? [],
          };
        }
      }

      return {
        'status': res.statusCode,
        'ok': false,
      };
    } catch (e) {
      print('❌ updateSession error: $e');
      return {
        'status': 500,
        'ok': false,
      };
    }
  }

  Future<bool> deleteSession(String id) async {
    try {
      final url = Uri.parse('$baseUrl/sessions/$id');
      print('📡 DELETE $url');

      final res = await http
          .delete(url, headers: _headers())
          .timeout(Duration(seconds: 30));

      print('📥 Status: ${res.statusCode}');

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      print('❌ deleteSession error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> clearSession(String id) async {
    try {
      final url = Uri.parse('$baseUrl/sessions/$id/clear');
      print('📡 POST $url');

      final res = await http
          .post(url, headers: _headers())
          .timeout(Duration(seconds: 30));

      print('📥 Status: ${res.statusCode}');

      if (res.statusCode == 200) {
        final data = _safeDecode(res.body);
        if (data != null) {
          return data as Map<String, dynamic>;
        }
      }

      return {
        'status': res.statusCode,
        'ok': res.statusCode == 200,
      };
    } catch (e) {
      print('❌ clearSession error: $e');
      return {
        'status': 500,
        'ok': false,
      };
    }
  }
}
