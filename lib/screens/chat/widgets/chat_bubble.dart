// lib/screens/chat/widgets/chat_bubble.dart — Blue Theme

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({Key? key, required this.message}) : super(key: key);

  Color _getBackgroundColor(bool isUser) {
    if (isUser) return const Color(0xFF2979FF);
    switch (message.emotion) {
      case 'happy':
        return const Color(0xFF111125);
      case 'sad':
        return const Color(0xFF0D1A2E);
      case 'angry':
        return const Color(0xFF2A0D0D);
      case 'calm':
        return const Color(0xFF0D2A1A);
      default:
        return const Color(0xFF111125);
    }
  }

  IconData _getEmotionIcon() {
    switch (message.emotion) {
      case 'happy':
        return Icons.sentiment_satisfied_alt;
      case 'sad':
        return Icons.sentiment_dissatisfied;
      case 'angry':
        return Icons.sentiment_very_dissatisfied;
      case 'calm':
        return Icons.self_improvement;
      default:
        return Icons.sentiment_neutral;
    }
  }

  Color _getEmotionColor() {
    switch (message.emotion) {
      case 'happy':
        return Colors.yellow;
      case 'sad':
        return Colors.blue;
      case 'angry':
        return Colors.red;
      case 'calm':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Avatar
            if (!isUser) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF2979FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child:
                    const Icon(Icons.smart_toy, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
            ],

            // Bubble
            Flexible(
              child: GestureDetector(
                onLongPress: () => _showMessageOptions(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _getBackgroundColor(isUser),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isUser ? 16 : 4),
                      topRight: Radius.circular(isUser ? 4 : 16),
                      bottomLeft: const Radius.circular(16),
                      bottomRight: const Radius.circular(16),
                    ),
                    border: !isUser
                        ? Border.all(color: const Color(0xFF1E1E38), width: 0.8)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: isUser
                            ? const Color(0xFF2979FF).withOpacity(0.25)
                            : Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        message.text,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15, height: 1.4),
                      ),
                      const SizedBox(height: 6),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        if (!isUser && message.emotion != 'neutral') ...[
                          Icon(_getEmotionIcon(),
                              size: 14, color: _getEmotionColor()),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            color: isUser
                                ? Colors.white.withOpacity(0.65)
                                : Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                        if (isUser) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.done_all,
                              size: 14, color: Colors.white.withOpacity(0.65)),
                        ],
                      ]),
                    ],
                  ),
                ),
              ),
            ),

            // User Avatar
            if (isUser) ...[
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF141428),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF2979FF), width: 2),
                ),
                child: const Icon(Icons.person,
                    color: Color(0xFF2979FF), size: 20),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111125),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.copy, color: Color(0xFF2979FF)),
            title:
                const Text('Copy Text', style: TextStyle(color: Colors.white)),
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.text));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Message copied to clipboard'),
                backgroundColor: Color(0xFF2979FF),
                duration: Duration(seconds: 2),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.blue),
            title: const Text('Message Info',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _showMessageInfo(context);
            },
          ),
        ]),
      ),
    );
  }

  void _showMessageInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111125),
        title:
            const Text('Message Info', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Sender', message.sender),
            _infoRow('Time', _formatTime(message.timestamp)),
            _infoRow('Emotion', message.emotion),
            _infoRow('ID', message.id),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Close', style: TextStyle(color: Color(0xFF2979FF))),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 80,
            child: Text('$label:',
                style: const TextStyle(color: Colors.grey, fontSize: 14))),
        Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 14))),
      ]),
    );
  }
}
