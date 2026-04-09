import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ReminderService {
  final String baseUrl;
  final AuthService auth;

  ReminderService({
    required this.baseUrl,
    required this.auth,
  });

  // Build headers with auth
  Map<String, String> _headers() {
    final token = auth.token ?? '';
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Safe JSON decode
  dynamic _safeDecodeBody(http.Response res) {
    final ct = res.headers['content-type'] ?? '';
    final body = res.body;

    if (body.isEmpty) return {};

    if (ct.contains('application/json') ||
        ct.contains('text/json') ||
        body.trim().startsWith('{') ||
        body.trim().startsWith('[')) {
      try {
        return jsonDecode(body);
      } catch (e) {
        return {'__raw_body__': body};
      }
    }

    try {
      return jsonDecode(body);
    } catch (_) {
      return {'__raw_body__': body};
    }
  }

  // Wrap response
  Map<String, dynamic> _wrapResponse(http.Response res) {
    return {
      'status': res.statusCode,
      'body': _safeDecodeBody(res),
    };
  }

  // GET /reminders - Get all reminders
  Future<List<dynamic>> getReminders() async {
    final uri = Uri.parse('$baseUrl/reminders');
    final res = await http.get(uri, headers: _headers());
    final wrapped = _wrapResponse(res);

    if (res.statusCode == 200) {
      final body = wrapped['body'];

      if (body is Map) {
        if (body['reminders'] is List) return List.from(body['reminders']);
        if (body['data'] is List) return List.from(body['data']);
        if (body['data'] is Map && body['data']['reminders'] is List)
          return List.from(body['data']['reminders']);
      } else if (body is List) {
        return List.from(body);
      }

      return [];
    }

    throw Exception(
        'Failed to fetch reminders (${res.statusCode}): ${wrapped['body']}');
  }

  // GET /reminders/today - Get today's reminders
  Future<List<dynamic>> getTodayReminders() async {
    final uri = Uri.parse('$baseUrl/reminders/today');
    final res = await http.get(uri, headers: _headers());
    final wrapped = _wrapResponse(res);

    if (res.statusCode == 200) {
      final body = wrapped['body'];

      if (body is Map && body['reminders'] is List)
        return List.from(body['reminders']);
      if (body is Map && body['data'] is List) return List.from(body['data']);
      if (body is List) return List.from(body);

      return [];
    }

    throw Exception(
        'Failed to fetch today reminders (${res.statusCode}): ${wrapped['body']}');
  }

  // GET /reminders?type=event - Get reminders by type
  Future<List<dynamic>> getRemindersByType(String type) async {
    final uri = Uri.parse('$baseUrl/reminders')
        .replace(queryParameters: {'type': type});
    final res = await http.get(uri, headers: _headers());
    final wrapped = _wrapResponse(res);

    if (res.statusCode == 200) {
      final body = wrapped['body'];

      if (body is Map && body['reminders'] is List)
        return List.from(body['reminders']);
      if (body is Map && body['data'] is List) return List.from(body['data']);
      if (body is List) return List.from(body);

      return [];
    }

    throw Exception(
        'Failed to fetch reminders by type (${res.statusCode}): ${wrapped['body']}');
  }

  // GET /reminders/:id - Get reminder by ID
  Future<Map<String, dynamic>> getReminderById(String id) async {
    final uri = Uri.parse('$baseUrl/reminders/$id');
    final res = await http.get(uri, headers: _headers());
    final wrapped = _wrapResponse(res);

    if (res.statusCode == 200) {
      final body = wrapped['body'];

      if (body is Map && body['reminder'] is Map)
        return Map<String, dynamic>.from(body['reminder']);
      if (body is Map && body['data'] is Map)
        return Map<String, dynamic>.from(body['data']);
      if (body is Map) {
        return Map<String, dynamic>.from(body);
      }
    }

    throw Exception(
        'Failed to fetch reminder (${res.statusCode}): ${wrapped['body']}');
  }

  // POST /reminders - Create a new reminder
  Future<Map<String, dynamic>> createReminder(
      Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/reminders');

    final data = <String, dynamic>{};
    data['title'] = payload['title'] ?? '';
    data['description'] = payload['description'] ?? '';
    data['type'] = payload['type'] ?? 'task';
    data['priority'] = payload['priority'] ?? 'medium';
    data['status'] = payload['status'] ?? 'pending';

    // Handle reminderTime
    final rt = payload['reminderTime'] ?? payload['time'];
    data['reminderTime'] = rt is DateTime ? rt.toUtc().toIso8601String() : rt;

    // Notification methods
    data['notificationMethods'] = payload['notificationMethods'] ??
        {
          'push': true,
          'voice': false,
          'email': false,
        };

    // Voice settings
    data['voiceSettings'] = payload['voiceSettings'] ??
        {
          'enabled': false,
          'tone': 'friendly',
          'customMessage': '',
        };

    // Tags
    data['tags'] = payload['tags'] ?? [];

    // Recurrence
    if (payload['recurrence'] != null) {
      data['recurrence'] = payload['recurrence'];
    }

    final res = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    );

    return _wrapResponse(res);
  }

  // PUT /reminders/:id - Update a reminder
  Future<Map<String, dynamic>> updateReminder(
      String id, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/reminders/$id');

    final data = Map<String, dynamic>.from(payload);

    // Handle time field conversion
    if (data.containsKey('time')) {
      final t = data.remove('time');
      data['reminderTime'] = t is DateTime ? t.toUtc().toIso8601String() : t;
    }

    final res = await http.put(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    );

    return _wrapResponse(res);
  }

  // DELETE /reminders/:id - Delete a reminder
  Future<bool> deleteReminder(String id) async {
    if (id.isEmpty || id == 'null' || id == 'undefined') {
      throw Exception('Invalid reminder ID');
    }

    final uri = Uri.parse('$baseUrl/reminders/$id');
    final res = await http.delete(uri, headers: _headers());

    return res.statusCode == 200 || res.statusCode == 204;
  }

  // POST /reminders/:id/complete - Mark reminder as completed
  Future<bool> completeReminder(String id) async {
    final uri = Uri.parse('$baseUrl/reminders/$id/complete');
    final res = await http.post(uri, headers: _headers());

    return res.statusCode == 200;
  }

  // POST /reminders/:id/snooze - Snooze a reminder
  Future<Map<String, dynamic>> snoozeReminder(String id, int minutes) async {
    final uri = Uri.parse('$baseUrl/reminders/$id/snooze');
    final res = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'minutes': minutes}),
    );

    return _wrapResponse(res);
  }

  // Helper methods
  String formatDateTimeForAPI(DateTime dt) => dt.toUtc().toIso8601String();

  DateTime? parseDateTimeFromAPI(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (e) {
      return null;
    }
  }
}
