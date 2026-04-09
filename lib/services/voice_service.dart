import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class VoiceService {
  final String baseUrl;
  final AuthService auth;

  VoiceService({required this.baseUrl, required this.auth});

  Map<String, String> _headers() {
    final token = auth.token ?? '';
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> generateReminderVoice(String reminderId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/voice/reminder/$reminderId'),
      headers: _headers(),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> generateCustomVoice(String text,
      {String tone = 'friendly'}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/voice/custom'),
      headers: _headers(),
      body: jsonEncode({'text': text, 'voiceTone': tone}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> testVoice(String message) async {
    final res = await http.post(
      Uri.parse('$baseUrl/voice/test'),
      headers: _headers(),
      body: jsonEncode({'customMessage': message}),
    );
    return jsonDecode(res.body);
  }

  Future<bool> cleanupAudioFiles() async {
    final res = await http.post(Uri.parse('$baseUrl/voice/cleanup'),
        headers: _headers());
    return res.statusCode == 200;
  }
}
