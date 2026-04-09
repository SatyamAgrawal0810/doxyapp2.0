// lib/controllers/chat_controller.dart - FIXED VERSION

import 'package:flutter/material.dart';
import '../../../models/chat_message.dart';
import '../../../services/chat_service.dart';

class ChatController extends ChangeNotifier {
  final ChatService service;

  // State
  List<dynamic> sessions = [];
  Map<String, List<ChatMessage>> sessionMessages = {};
  String? openedSession;
  bool loadingSessions = false;
  bool typing = false;
  String? error;
  bool _disposed = false;

  ChatController(this.service);

  // Safe notify
  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // 🔹 LOAD ALL SESSIONS
  Future<void> loadSessions() async {
    if (_disposed) return;

    loadingSessions = true;
    error = null;
    _safeNotify();

    try {
      final data = await service.getSessions();

      if (_disposed) return;

      sessions = data;

      // Parse messages for each session
      for (var s in sessions) {
        if (_disposed) return;

        final id = s['_id'] ?? s['id'];
        if (id == null) continue;

        final raw = s['messages'] ?? [];

        if (raw is List) {
          sessionMessages[id] = raw
              .map((m) {
                try {
                  return ChatMessage.fromMap(m as Map<String, dynamic>);
                } catch (e) {
                  print('Error parsing message: $e');
                  return null;
                }
              })
              .where((m) => m != null)
              .cast<ChatMessage>()
              .toList();
        } else {
          sessionMessages[id] = <ChatMessage>[];
        }
      }

      print('✅ Loaded ${sessions.length} sessions');
    } catch (e) {
      if (_disposed) return;
      error = 'Failed to load sessions: $e';
      print('❌ loadSessions error: $e');
    } finally {
      if (!_disposed) {
        loadingSessions = false;
        _safeNotify();
      }
    }
  }

  // 🔹 CREATE NEW SESSION
  Future<void> createSession() async {
    if (_disposed) return;

    try {
      final timestamp = DateTime.now();
      final title =
          'Chat ${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';

      final res = await service.createSession({"title": title});

      if (_disposed) return;

      print('Create session response: $res');

      if (res['ok'] == true || res['status'] == 200 || res['status'] == 201) {
        await loadSessions();

        if (_disposed) return;

        // Auto-open the newly created session
        if (sessions.isNotEmpty) {
          final newSession = sessions.last;
          final id = newSession['_id'] ?? newSession['id'];
          if (id != null) {
            await openSession(id);
          }
        }

        print('✅ Session created successfully');
      } else {
        error = res['message'] ?? res['error'] ?? 'Failed to create session';
        print('❌ createSession failed: ${res['error']}');
      }
    } catch (e) {
      if (_disposed) return;
      error = 'Error creating session: $e';
      print('❌ createSession error: $e');
    }

    if (!_disposed) {
      _safeNotify();
    }
  }

  // 🔹 OPEN SESSION
  Future<void> openSession(String id) async {
    if (_disposed) return;

    openedSession = id;
    error = null;
    _safeNotify();

    try {
      final resp = await service.getSession(id);

      if (_disposed) return;

      // Handle different response formats
      final session = resp['session'] ?? resp;
      final raw = session['messages'] ?? resp['messages'] ?? [];

      if (raw is List) {
        sessionMessages[id] = raw
            .map((m) {
              try {
                return ChatMessage.fromMap(m as Map<String, dynamic>);
              } catch (e) {
                print('Error parsing message: $e');
                return null;
              }
            })
            .where((m) => m != null)
            .cast<ChatMessage>()
            .toList();
      } else {
        sessionMessages[id] = <ChatMessage>[];
      }

      print(
          '✅ Opened session: $id with ${sessionMessages[id]?.length ?? 0} messages');
    } catch (e) {
      if (_disposed) return;
      error = 'Failed to load session: $e';
      print('❌ openSession error: $e');
      sessionMessages[id] = sessionMessages[id] ?? <ChatMessage>[];
    }

    if (!_disposed) {
      _safeNotify();
    }
  }

  // 🔹 DELETE SESSION
  Future<void> deleteSession(String id) async {
    if (_disposed) return;

    try {
      final ok = await service.deleteSession(id);

      if (_disposed) return;

      if (ok) {
        sessions.removeWhere((s) => (s['_id'] ?? s['id']) == id);
        sessionMessages.remove(id);

        if (openedSession == id) {
          openedSession = null;
        }

        print('✅ Session deleted: $id');
      }
    } catch (e) {
      if (_disposed) return;
      error = 'Failed to delete session: $e';
      print('❌ deleteSession error: $e');
    }

    if (!_disposed) {
      _safeNotify();
    }
  }

  // 🔹 SEND MESSAGE
  Future<void> sendMessage(String text) async {
    if (_disposed) return;

    if (openedSession == null) {
      error = 'No session selected';
      return;
    }

    final sid = openedSession!;
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      sender: "user",
      emotion: _detectEmotion(text),
      timestamp: DateTime.now(),
    );

    // Add user message immediately
    sessionMessages[sid] ??= <ChatMessage>[];
    sessionMessages[sid]!.add(userMsg);

    if (!_disposed) {
      _safeNotify();
    }

    // Show typing indicator
    typing = true;
    if (!_disposed) {
      _safeNotify();
    }

    try {
      final res = await service.updateSession(sid, userMsg.toMap());

      if (_disposed) return;

      if (res['ok'] == true) {
        // Update with server response
        final raw = res['messages'] ?? res['session']?['messages'] ?? [];

        if (raw is List) {
          sessionMessages[sid] = raw
              .map((m) {
                try {
                  return ChatMessage.fromMap(m as Map<String, dynamic>);
                } catch (e) {
                  print('Error parsing message: $e');
                  return null;
                }
              })
              .where((m) => m != null)
              .cast<ChatMessage>()
              .toList();
        }

        print('✅ Message sent successfully');
      } else {
        error = res['message'] ?? res['error'] ?? 'Failed to send message';
        print('❌ sendMessage failed: ${res['error']}');
      }
    } catch (e) {
      if (_disposed) return;
      error = 'Error sending message: $e';
      print('❌ sendMessage error: $e');
    }

    if (!_disposed) {
      typing = false;
      _safeNotify();
    }
  }

  // 🔹 CLEAR SESSION
  Future<void> clearSession(String id) async {
    if (_disposed) return;

    try {
      await service.clearSession(id);

      if (_disposed) return;

      sessionMessages[id] = [];
      print('✅ Session cleared: $id');

      if (!_disposed) {
        _safeNotify();
      }
    } catch (e) {
      if (_disposed) return;
      error = 'Failed to clear session: $e';
      print('❌ clearSession error: $e');
    }
  }

  // 🔹 SIMPLE EMOTION DETECTION
  String _detectEmotion(String text) {
    final t = text.toLowerCase();

    if (t.contains(RegExp(
        r'\b(happy|great|awesome|love|amazing|wonderful|fantastic|excellent)\b'))) {
      return 'happy';
    }
    if (t.contains(RegExp(r'\b(sad|down|unhappy|sorry|depressed|upset)\b'))) {
      return 'sad';
    }
    if (t
        .contains(RegExp(r'\b(angry|mad|furious|hate|annoyed|frustrated)\b'))) {
      return 'angry';
    }
    if (t.contains(RegExp(r'\b(calm|relaxed|peace|fine|okay|ok)\b'))) {
      return 'calm';
    }

    return 'neutral';
  }

  // 🔹 GET CURRENT MESSAGES
  List<ChatMessage> getCurrentMessages() {
    if (openedSession == null || _disposed) return [];
    return sessionMessages[openedSession!] ?? [];
  }

  // 🔹 DISPOSE
  @override
  void dispose() {
    _disposed = true;
    sessions.clear();
    sessionMessages.clear();
    super.dispose();
  }
}
