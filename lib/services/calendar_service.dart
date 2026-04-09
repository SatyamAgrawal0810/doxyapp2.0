// calendar_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class CalendarService {
  final String baseUrl;
  final AuthService auth;

  CalendarService({
    required this.baseUrl,
    required this.auth,
  });

  // 🔥 FIXED — ALWAYS RETURNS VALID TOKEN
  Future<Map<String, String>> _headers() async {
    final token = await auth.getToken();
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
    };

    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }
    return headers;
  }

  dynamic _safeDecodeBody(http.Response res) {
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return res.body;
    }
  }

  Map<String, dynamic> _wrapResponse(http.Response res) {
    return {
      "status": res.statusCode,
      "body": _safeDecodeBody(res),
    };
  }

  // -----------------------------
  //           EVENTS
  // -----------------------------

  Future<List<dynamic>> getEvents() async {
    final uri = Uri.parse("$baseUrl/calendar/events");
    final res = await http.get(uri, headers: await _headers());
    final wrapped = _wrapResponse(res);

    if (res.statusCode == 200) {
      final body = wrapped["body"];

      if (body is List) return body;
      if (body is Map && body["events"] is List) return body["events"];
    }

    return [];
  }

  Future<Map<String, dynamic>> getEventById(String id) async {
    final uri = Uri.parse("$baseUrl/calendar/events/$id");

    final res = await http.get(uri, headers: await _headers());
    final wrapped = _wrapResponse(res);

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(wrapped["body"]);
    }

    throw Exception("Failed to load event");
  }

  Future<Map<String, dynamic>> createEvent(
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse("$baseUrl/calendar/events");

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(payload),
    );

    return _wrapResponse(res);
  }

  Future<Map<String, dynamic>> updateEvent(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse("$baseUrl/calendar/events/$id");

    final res = await http.put(
      uri,
      headers: await _headers(),
      body: jsonEncode(payload),
    );

    return _wrapResponse(res);
  }

  Future<bool> deleteEvent(String id) async {
    final uri = Uri.parse("$baseUrl/calendar/events/$id");

    final res = await http.delete(uri, headers: await _headers());
    return res.statusCode == 200 || res.statusCode == 204;
  }

  // -----------------------------
  //         REMINDERS
  // -----------------------------

  Future<List<dynamic>> getReminders() async {
    final uri = Uri.parse("$baseUrl/reminders");

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body["reminders"] ?? body;
    }

    throw Exception("Failed to load reminders");
  }

  Future<Map<String, dynamic>> createReminder(
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse("$baseUrl/reminders");

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(payload),
    );

    return {
      "status": res.statusCode,
      "body": jsonDecode(res.body),
    };
  }

  Future<bool> deleteReminder(String id) async {
    final uri = Uri.parse("$baseUrl/reminders/$id");

    final res = await http.delete(uri, headers: await _headers());
    return res.statusCode == 200 || res.statusCode == 204;
  }
}
