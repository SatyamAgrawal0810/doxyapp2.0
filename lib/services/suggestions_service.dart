// lib/services/suggestions_service.dart
// 🎯 Connects to the REAL GET /api/suggestions backend endpoint.
// The controller (suggestionsController.js) already analyses habits, routines,
// health, calendar, and analytics — we just fetch, parse, and display.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

// ── Data Models ───────────────────────────────────────────────────────────────

enum SuggestionCategory {
  habit,
  routine,
  health,
  wellness,
  fitness,
  productivity,
  planning,
  motivation,
  opportunity,
  feature,
  growth,
  unknown,
}

class SuggestionAction {
  final String label;
  final String route;

  const SuggestionAction({required this.label, required this.route});

  factory SuggestionAction.fromJson(Map<String, dynamic> json) {
    return SuggestionAction(
      label: json['label'] as String? ?? 'View',
      route: json['route'] as String? ?? '/',
    );
  }
}

class Suggestion {
  final String type;
  final String title;
  final String message;
  final SuggestionCategory category;
  final int priority;
  final Map<String, dynamic> data;
  final SuggestionAction? action;

  const Suggestion({
    required this.type,
    required this.title,
    required this.message,
    required this.category,
    required this.priority,
    required this.data,
    this.action,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      type: json['type'] as String? ?? 'unknown',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      category: _parseCategory(json['category'] as String? ?? ''),
      priority: (json['priority'] as num? ?? 0).toInt(),
      data: json['data'] as Map<String, dynamic>? ?? {},
      action: json['action'] != null
          ? SuggestionAction.fromJson(json['action'] as Map<String, dynamic>)
          : null,
    );
  }

  static SuggestionCategory _parseCategory(String s) {
    switch (s.toLowerCase()) {
      case 'general':
      case 'habit':
        return SuggestionCategory.habit;
      case 'routine':
        return SuggestionCategory.routine;
      case 'health':
        return SuggestionCategory.health;
      case 'wellness':
        return SuggestionCategory.wellness;
      case 'fitness':
        return SuggestionCategory.fitness;
      case 'productivity':
        return SuggestionCategory.productivity;
      case 'planning':
        return SuggestionCategory.planning;
      case 'motivation':
        return SuggestionCategory.motivation;
      case 'opportunity':
        return SuggestionCategory.opportunity;
      case 'feature':
        return SuggestionCategory.feature;
      case 'growth':
        return SuggestionCategory.growth;
      default:
        return SuggestionCategory.unknown;
    }
  }

  /// UI helpers
  String get emoji {
    switch (category) {
      case SuggestionCategory.habit:
        return '🔥';
      case SuggestionCategory.routine:
        return '📅';
      case SuggestionCategory.health:
        return '💪';
      case SuggestionCategory.wellness:
        return '😴';
      case SuggestionCategory.fitness:
        return '🏃';
      case SuggestionCategory.productivity:
        return '⚡';
      case SuggestionCategory.planning:
        return '📋';
      case SuggestionCategory.motivation:
        return '🌟';
      case SuggestionCategory.opportunity:
        return '⏱️';
      case SuggestionCategory.feature:
        return '✨';
      case SuggestionCategory.growth:
        return '🌱';
      default:
        return '💡';
    }
  }

  bool get isHighPriority => priority >= 8;
  bool get isMediumPriority => priority >= 5 && priority < 8;
}

// ── Service ───────────────────────────────────────────────────────────────────

class SuggestionsService {
  final AuthService auth;
  static const String _baseUrl =
      'https://doxy-bh96.onrender.com/api/suggestions';

  SuggestionsService({required this.auth});

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${auth.token ?? ''}',
        'Content-Type': 'application/json',
      };

  // ── GET /api/suggestions ────────────────────────────────────────────────
  // Returns ALL suggestions sorted by priority (habits, routines, health,
  // calendar, analytics). This is the primary endpoint.
  Future<List<Suggestion>> getAllSuggestions() async {
    try {
      final res = await http
          .get(Uri.parse(_baseUrl), headers: _headers)
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          final list = body['data'] as List? ?? [];
          final suggestions = list
              .cast<Map<String, dynamic>>()
              .map(Suggestion.fromJson)
              .toList();

          debugPrint(
              '🎯 Loaded ${suggestions.length} suggestions from backend');
          return suggestions;
        }
      }
    } catch (e) {
      debugPrint('❌ Suggestions fetch error: $e');
    }
    return [];
  }

  // ── GET top-priority suggestion for home screen card ─────────────────────
  Future<Suggestion?> getTopSuggestion() async {
    final all = await getAllSuggestions();
    if (all.isEmpty) return null;
    // Already sorted by priority desc from backend
    return all.first;
  }

  // ── GET suggestions filtered by category ─────────────────────────────────
  Future<List<Suggestion>> getSuggestionsByCategory(
      SuggestionCategory category) async {
    final all = await getAllSuggestions();
    return all.where((s) => s.category == category).toList();
  }

  // ── POST /api/suggestions/:type/dismiss ──────────────────────────────────
  // Dismissed suggestions are stored in AI memory with 30-day expiry.
  Future<bool> dismissSuggestion(
    String type, {
    String? habitId,
    String? routineId,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/$type/dismiss'),
            headers: _headers,
            body: jsonEncode({
              if (habitId != null) 'habitId': habitId,
              if (routineId != null) 'routineId': routineId,
            }),
          )
          .timeout(const Duration(seconds: 8));

      final ok = res.statusCode == 200;
      debugPrint(ok
          ? '✅ Dismissed suggestion: $type'
          : '⚠️ Dismiss failed: ${res.statusCode}');
      return ok;
    } catch (e) {
      debugPrint('❌ Dismiss error: $e');
      return false;
    }
  }

  // ── POST /api/suggestions/:type/action ───────────────────────────────────
  // Logged in AI memory + analytics when user taps the action button.
  Future<bool> logAction(
    String type, {
    Map<String, dynamic> extraData = const {},
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/$type/action'),
            headers: _headers,
            body: jsonEncode(extraData),
          )
          .timeout(const Duration(seconds: 8));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Log action error: $e');
      return false;
    }
  }

  // ── Convenience: get top suggestion message string ────────────────────────
  // Used by HomeScreen's proactive suggestion card.
  Future<String> getTopSuggestionMessage() async {
    final s = await getTopSuggestion();
    return s?.message ?? _timeFallback();
  }

  String _timeFallback() {
    final h = DateTime.now().hour;
    if (h < 9) return 'Start your day with a glass of water 🌅';
    if (h < 12) return 'How\'s your morning going? Take a moment to breathe ☀️';
    if (h < 15) return 'A short walk after lunch boosts focus and energy 🚶';
    if (h < 18) return 'Afternoon slump? Try 5 deep breaths to reset 🌬️';
    if (h < 21) return 'Great time to log your mood and reflect on today 📝';
    return 'Wind down with a calm routine — great sleep shapes tomorrow 🌙';
  }
}
