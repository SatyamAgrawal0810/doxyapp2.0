// lib/services/routine_service.dart
// ⚙️ Month 4 — Routine Execution Service
// Fetches routines from backend, executes steps: TTS, music, health nudges, notifications

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

enum RoutineStepType { voice, music, notification, health, wait, custom }

class RoutineStep {
  final RoutineStepType type;
  final String? text;
  final String? audioUrl;
  final String? notificationTitle;
  final String? notificationBody;
  final Duration? waitDuration;
  final Map<String, dynamic> raw;

  RoutineStep({
    required this.type,
    required this.raw,
    this.text,
    this.audioUrl,
    this.notificationTitle,
    this.notificationBody,
    this.waitDuration,
  });

  factory RoutineStep.fromJson(Map<String, dynamic> json) {
    final type = _parseType(json['type'] as String? ?? '');
    return RoutineStep(
      type: type,
      raw: json,
      text: json['text'] as String?,
      audioUrl: json['audioUrl'] as String?,
      notificationTitle: json['title'] as String?,
      notificationBody: json['body'] as String?,
      waitDuration: json['waitSeconds'] != null
          ? Duration(seconds: (json['waitSeconds'] as num).toInt())
          : null,
    );
  }

  static RoutineStepType _parseType(String s) {
    switch (s.toLowerCase()) {
      case 'voice':
      case 'tts':
        return RoutineStepType.voice;
      case 'music':
      case 'audio':
        return RoutineStepType.music;
      case 'notification':
      case 'push':
        return RoutineStepType.notification;
      case 'health':
      case 'steps':
        return RoutineStepType.health;
      case 'wait':
      case 'delay':
        return RoutineStepType.wait;
      default:
        return RoutineStepType.custom;
    }
  }
}

class Routine {
  final String id;
  final String name;
  final String? description;
  final String? triggerTime;
  final List<RoutineStep> steps;
  final bool isActive;

  Routine({
    required this.id,
    required this.name,
    required this.steps,
    this.description,
    this.triggerTime,
    this.isActive = true,
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    final rawSteps = (json['steps'] as List? ?? []);
    return Routine(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Routine',
      description: json['description'] as String?,
      triggerTime: json['triggerTime'] as String?,
      steps: rawSteps
          .cast<Map<String, dynamic>>()
          .map(RoutineStep.fromJson)
          .toList(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class RoutineService {
  final AuthService auth;
  static const String _baseUrl = 'https://doxy-bh96.onrender.com/api/routines';

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _running = false;
  bool get isRunning => _running;

  RoutineService({required this.auth}) {
    _initTTS();
  }

  Future<void> _initTTS() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.05);
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${auth.token ?? ''}',
        'Content-Type': 'application/json',
      };

  // ── Fetch All Routines ────────────────────────────────────────────────────
  Future<List<Routine>> getRoutines() async {
    try {
      final res = await http
          .get(Uri.parse(_baseUrl), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body['routines'] as List? ?? body['data'] as List? ?? [];
        return list.cast<Map<String, dynamic>>().map(Routine.fromJson).toList();
      }
    } catch (e) {
      debugPrint('❌ Get routines error: $e');
    }
    return [];
  }

  // ── Execute a Routine ─────────────────────────────────────────────────────
  Future<void> executeRoutine(
    Routine routine, {
    void Function(String stepName)? onStepStart,
    void Function()? onComplete,
    void Function(String error)? onError,
  }) async {
    if (_running) {
      onError?.call('A routine is already running');
      return;
    }

    _running = true;
    debugPrint('▶️ Starting routine: ${routine.name}');

    try {
      // Log start to backend (non-blocking)
      _logRoutineExecution(routine.id, 'started');

      for (int i = 0; i < routine.steps.length; i++) {
        final step = routine.steps[i];
        onStepStart?.call('Step ${i + 1}/${routine.steps.length}');

        await _executeStep(step);

        // Small gap between steps
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Log completion
      _logRoutineExecution(routine.id, 'completed');
      onComplete?.call();
      debugPrint('✅ Routine completed: ${routine.name}');
    } catch (e) {
      _logRoutineExecution(routine.id, 'error');
      onError?.call('Routine failed: $e');
      debugPrint('❌ Routine error: $e');
    } finally {
      _running = false;
    }
  }

  // ── Execute a Single Step ─────────────────────────────────────────────────
  Future<void> _executeStep(RoutineStep step) async {
    switch (step.type) {
      case RoutineStepType.voice:
        await _executeVoiceStep(step);
        break;
      case RoutineStepType.music:
        await _executeMusicStep(step);
        break;
      case RoutineStepType.wait:
        final dur = step.waitDuration ?? const Duration(seconds: 2);
        await Future.delayed(dur);
        break;
      case RoutineStepType.notification:
        // Notification is handled by backend push — just log
        debugPrint('📬 Notification step: ${step.notificationTitle}');
        break;
      case RoutineStepType.health:
        debugPrint('🏃 Health step: sync triggered');
        await _triggerHealthSync();
        break;
      case RoutineStepType.custom:
        debugPrint('⚙️ Custom step: ${step.raw}');
        break;
    }
  }

  // ── Voice Step: speak text or play audioUrl ────────────────────────────
  Future<void> _executeVoiceStep(RoutineStep step) async {
    try {
      if (step.audioUrl != null && step.audioUrl!.isNotEmpty) {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(step.audioUrl!));
        // Wait for playback to finish
        await _audioPlayer.onPlayerComplete.first.timeout(
          const Duration(seconds: 60),
        );
      } else if (step.text != null && step.text!.isNotEmpty) {
        await _tts.awaitSpeakCompletion(true);
        await _tts.speak(step.text!);
      }
    } catch (e) {
      debugPrint('⚠️ Voice step error: $e');
      // Try TTS fallback
      if (step.text != null) {
        try {
          await _tts.speak(step.text!);
        } catch (_) {}
      }
    }
  }

  // ── Music Step: play audio URL ─────────────────────────────────────────
  Future<void> _executeMusicStep(RoutineStep step) async {
    if (step.audioUrl == null || step.audioUrl!.isEmpty) return;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(step.audioUrl!));
      // Play for configured duration or until next step
      final waitDur = step.waitDuration ?? const Duration(seconds: 30);
      await Future.delayed(waitDur);
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('⚠️ Music step error: $e');
    }
  }

  // ── Health sync trigger ───────────────────────────────────────────────────
  Future<void> _triggerHealthSync() async {
    try {
      await http
          .post(
            Uri.parse('https://doxy-bh96.onrender.com/api/health/sync'),
            headers: _headers,
            body: jsonEncode({'date': DateTime.now().toIso8601String()}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  // ── Log execution to backend ──────────────────────────────────────────────
  void _logRoutineExecution(String routineId, String status) {
    http
        .post(
          Uri.parse('$_baseUrl/$routineId/log'),
          headers: _headers,
          body: jsonEncode({
            'status': status,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        )
        .catchError((_) {});
  }

  // ── Stop running routine ──────────────────────────────────────────────────
  Future<void> stop() async {
    _running = false;
    await _tts.stop();
    await _audioPlayer.stop();
  }

  void dispose() {
    stop();
    _audioPlayer.dispose();
  }
}
