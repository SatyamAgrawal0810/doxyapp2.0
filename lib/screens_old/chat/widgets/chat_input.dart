// lib/screens/chat/widgets/chat_input.dart
import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;

  const ChatInput({
    Key? key,
    required this.controller,
    required this.onSend,
    this.isSending = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              minLines: 1,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.newline,
            ),
          ),
          IconButton(
            icon: isSending
                ? const CircularProgressIndicator(color: Color(0xFFFF6A00))
                : const Icon(Icons.send, color: Color(0xFFFF6A00)),
            onPressed: isSending ? null : onSend,
          )
        ],
      ),
    );
  }
}
