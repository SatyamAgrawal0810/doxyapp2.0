// lib/services/proactive_service.dart
// 🧠 Month 4 — Proactive AI Suggestions Service
// Fetches context-aware suggestions from backend based on health, habits, time

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ProactiveService {
  final AuthService auth;
  static const String _baseUrl = 'https://doxy-bh96.onrender.com/api';

  ProactiveService({required this.auth});

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${auth.token ?? ''}',
        'Content-Type': 'application/json',
      };

  // ── Today's Proactive Suggestion (shown on home screen) ──────────────────
  Future<String> getTodaySuggestion() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/suggestions/today'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['suggestion']?['message'] as String? ??
            _fallbackSuggestion();
      }
    } catch (e) {
      debugPrint('⚠️ Proactive suggestion error: $e');
    }
    return _fallbackSuggestion();
  }

  // ── Morning Summary ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMorningSummary() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/suggestions/morning-summary'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          return body['summary'] as Map<String, dynamic>? ?? {};
        }
      }
    } catch (e) {
      debugPrint('⚠️ Morning summary error: $e');
    }
    return {};
  }

  // ── Habit-based Nudge ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getHabitNudges() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/habits/nudges'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final nudges = body['nudges'] as List? ?? [];
        return nudges.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('⚠️ Habit nudges error: $e');
    }
    return [];
  }

  // ── Mood-based Suggestion ─────────────────────────────────────────────────
  Future<String> getMoodSuggestion(String moodLevel) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/suggestions/mood'),
            headers: _headers,
            body: jsonEncode({'mood': moodLevel}),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['suggestion'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('⚠️ Mood suggestion error: $e');
    }
    return '';
  }

  // ── Routine Reminder Text ─────────────────────────────────────────────────
  Future<String> getRoutineReminder(String routineId) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/routines/$routineId/reminder'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['message'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('⚠️ Routine reminder error: $e');
    }
    return '';
  }

  // ── All Proactive Cards (for dashboard section) ───────────────────────────
  Future<List<ProactiveCard>> getProactiveCards() async {
    final cards = <ProactiveCard>[];

    try {
      // Suggestion
      final suggestion = await getTodaySuggestion();
      if (suggestion.isNotEmpty) {
        cards.add(ProactiveCard(
          type: ProactiveType.suggestion,
          title: 'Doxy\'s Tip',
          message: suggestion,
          icon: '💡',
          priority: 1,
        ));
      }

      // Nudges
      final nudges = await getHabitNudges();
      for (final nudge in nudges.take(2)) {
        cards.add(ProactiveCard(
          type: ProactiveType.habitNudge,
          title: nudge['habit'] as String? ?? 'Habit',
          message: nudge['message'] as String? ?? '',
          icon: nudge['icon'] as String? ?? '🔔',
          priority: nudge['priority'] == 'high' ? 0 : 2,
        ));
      }

      cards.sort((a, b) => a.priority.compareTo(b.priority));
    } catch (e) {
      debugPrint('⚠️ Proactive cards error: $e');
    }

    return cards;
  }

  // ── Time-based fallback ───────────────────────────────────────────────────
  String _fallbackSuggestion() {
    final hour = DateTime.now().hour;
    if (hour < 9) {
      return 'Start your day with a glass of water and 5 minutes of stretching! 🌅';
    } else if (hour < 12) {
      return 'How are you feeling this morning? Don\'t forget your morning routine! ☀️';
    } else if (hour < 15) {
      return 'Time for a short walk to refresh your focus. Even 10 minutes helps! 🚶';
    } else if (hour < 18) {
      return 'Afternoon slump? Try deep breathing for 2 minutes to re-energise! 🌬️';
    } else if (hour < 21) {
      return 'Great time to log your mood and reflect on today\'s wins! 📝';
    } else {
      return 'Wind down with a calm routine — good sleep boosts tomorrow\'s energy! 🌙';
    }
  }
}

// ── Data model ────────────────────────────────────────────────────────────────
enum ProactiveType { suggestion, habitNudge, moodNudge, routine }

class ProactiveCard {
  final ProactiveType type;
  final String title;
  final String message;
  final String icon;
  final int priority;

  const ProactiveCard({
    required this.type,
    required this.title,
    required this.message,
    required this.icon,
    required this.priority,
  });
}
