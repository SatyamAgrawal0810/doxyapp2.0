// lib/models/chat_message.dart

class ChatMessage {
  final String id;
  final String text;
  final String sender; // 'user' or 'assistant'
  final String emotion;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    this.emotion = 'neutral',
    required this.timestamp,
  });

  // Convert to Map for sending to backend
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'from': sender,
      'emotion': emotion,
      'timestamp': timestamp.toIso8601String(),
      'createdAt': timestamp.toIso8601String(),
    };
  }

  // Create from backend response
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    // Handle different possible field names from backend
    final from = map['from'] ?? map['sender'] ?? map['role'] ?? 'assistant';
    final text = map['text'] ?? map['message'] ?? map['content'] ?? '';
    final timestamp = map['timestamp'] ??
        map['createdAt'] ??
        DateTime.now().toIso8601String();

    return ChatMessage(
      id: map['id'] ??
          map['_id'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      sender: from == 'user' || from == 'human' ? 'user' : 'assistant',
      emotion: map['emotion'] ?? 'neutral',
      timestamp: DateTime.tryParse(timestamp.toString()) ?? DateTime.now(),
    );
  }

  ChatMessage copyWith({
    String? id,
    String? text,
    String? sender,
    String? emotion,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      emotion: emotion ?? this.emotion,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
