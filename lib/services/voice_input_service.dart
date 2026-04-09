// lib/services/voice_input_service.dart
// 🎤 Month 3 — Voice Input Service (Speech-to-Text)
// Uses speech_to_text package — works on both Android and iOS

import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:flutter/foundation.dart';

typedef OnTranscriptUpdate = void Function(String partial);
typedef OnFinalTranscript = void Function(String text);
typedef OnVoiceError = void Function(String error);

class VoiceInputService {
  final SpeechToText _stt = SpeechToText();

  bool _available = false;
  bool _listening = false;

  bool get isListening => _listening;
  bool get isAvailable => _available;

  // ── Initialize ────────────────────────────────────────────────────────────
  Future<bool> init() async {
    try {
      _available = await _stt.initialize(
        onError: (error) => debugPrint('🎤 STT error: ${error.errorMsg}'),
        onStatus: (status) => debugPrint('🎤 STT status: $status'),
      );
      debugPrint('🎤 STT available: $_available');
      return _available;
    } catch (e) {
      debugPrint('❌ STT init error: $e');
      return false;
    }
  }

  // ── Start Listening ───────────────────────────────────────────────────────
  Future<void> startListening({
    required OnTranscriptUpdate onPartial,
    required OnFinalTranscript onFinal,
    OnVoiceError? onError,
    String localeId = 'en_US',
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!_available) {
      final ok = await init();
      if (!ok) {
        onError?.call('Microphone not available');
        return;
      }
    }

    if (_listening) await stopListening();

    try {
      _listening = true;

      await _stt.listen(
        onResult: (SpeechRecognitionResult result) {
          final words = result.recognizedWords;
          if (result.finalResult) {
            _listening = false;
            onFinal(words);
          } else {
            onPartial(words);
          }
        },
        listenFor: listenFor,
        pauseFor: pauseFor,
        partialResults: true,
        localeId: localeId,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
    } catch (e) {
      _listening = false;
      onError?.call('Failed to start listening: $e');
    }
  }

  // ── Stop Listening ────────────────────────────────────────────────────────
  Future<void> stopListening() async {
    if (_listening) {
      await _stt.stop();
      _listening = false;
    }
  }

  // ── Cancel ────────────────────────────────────────────────────────────────
  Future<void> cancel() async {
    if (_listening) {
      await _stt.cancel();
      _listening = false;
    }
  }

  // ── Get Available Locales ─────────────────────────────────────────────────
  Future<List<LocaleName>> getLocales() async {
    if (!_available) await init();
    return await _stt.locales();
  }

  // ── Sound level (0.0 → 1.0) ───────────────────────────────────────────────
  double get soundLevel => _stt.lastSoundLevel.clamp(0.0, 1.0);

  void dispose() {
    _stt.cancel();
  }
}
