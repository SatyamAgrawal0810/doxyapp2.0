class MemoryService {
  static Map<String, dynamic> extract(List<dynamic> messages) {
    List<String> preferences = [];
    List<String> routines = [];
    Map<String, int> moods = {};

    for (var msg in messages) {
      if (msg["from"] != "user") continue;

      final text = msg["text"].toLowerCase();

      if (text.contains("i like") || text.contains("i love")) {
        preferences.add(msg["text"]);
      }

      if (text.contains("everyday") || text.contains("always")) {
        routines.add(msg["text"]);
      }

      final emo = msg["emotion"] ?? "neutral";
      moods[emo] = (moods[emo] ?? 0) + 1;
    }

    return {
      "preferences": preferences,
      "routines": routines,
      "emotions": moods,
    };
  }
}
