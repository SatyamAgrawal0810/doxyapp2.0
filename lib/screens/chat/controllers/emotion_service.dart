// lib/screens/chat/controllers/emotion_service.dart
class EmotionService {
  static String detect(String text) {
    if (text.trim().isEmpty) return 'neutral';
    final t = text.toLowerCase();

    final keywords = {
      "happy": [
        "happy",
        "great",
        "awesome",
        "love",
        "good",
        "amazing",
        "fantastic"
      ],
      "sad": ["sad", "down", "unhappy", "sorry", "miss", "tear"],
      "angry": ["angry", "mad", "furious", "hate", "annoyed", "frustrated"],
      "calm": ["calm", "relaxed", "peace", "fine", "ok", "okay"],
      "excited": ["excited", "thrilled", "pumped", "stoked"],
      "anxious": ["anxious", "worried", "nervous", "scared", "stressed"]
    };

    Map<String, int> scores = {
      "happy": 0,
      "sad": 0,
      "angry": 0,
      "calm": 0,
      "excited": 0,
      "anxious": 0
    };

    keywords.forEach((emotion, list) {
      for (var w in list) {
        if (t.contains(w)) scores[emotion] = scores[emotion]! + 1;
      }
    });

    String best = 'neutral';
    int max = 0;
    scores.forEach((k, v) {
      if (v > max) {
        max = v;
        best = k;
      }
    });
    return best;
  }
}
