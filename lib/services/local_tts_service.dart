import 'package:flutter_tts/flutter_tts.dart';

class LocalTTS {
  static final FlutterTts _tts = FlutterTts();

  static Future init() async {
    await _tts.setLanguage("en-IN");
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
  }

  static Future speak(String text) async {
    await LocalTTS.init();
    await _tts.speak(text);
  }
}
