// lib/services/notification_manager.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationManager extends ChangeNotifier {
  String? _authToken;
  WebSocketChannel? _channel;

  bool isConnected = false;
  bool _isConnecting = false;

  int totalReceived = 0;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  // ❌ Remove TTS completely
  // FlutterTts? _flutterTts;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  NotificationManager({String? authToken}) {
    _authToken = authToken;
    Future.microtask(() async {
      await _initializeNotifications();
      _connect();
    });
  }

  /// ========================== Initialization ==========================
  Future<void> _initializeNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifications.initialize(initSettings,
        onDidReceiveNotificationResponse: (response) {
      print('🎯 Notification tapped: ${response.payload}');
    });

    await Permission.notification.request();
    print('✅ Local Notifications Initialized');
  }

  /// ========================== Token Update ==========================
  void updateAuthToken(String? token) {
    if (_authToken == token) return;
    _authToken = token;
    reconnect();
  }

  String _buildWsUrl() {
    const host = "doxy-bh96.onrender.com";
    const path = "/ws";
    if (_authToken == null || _authToken!.isEmpty) {
      return "wss://$host$path";
    }
    final encoded = Uri.encodeComponent(_authToken!);
    return "wss://$host$path?token=$encoded";
  }

  /// ========================== WebSocket Connect ==========================
  void _connect() {
    if (_isConnecting) return;
    _isConnecting = true;

    if (_authToken == null || _authToken!.isEmpty) {
      print("❌ WS Skipped — No Token");
      _markDisconnected();
      return;
    }

    final url = _buildWsUrl();
    print("🌐 WS Connect → $url");

    () async {
      try {
        final conn = await Connectivity().checkConnectivity();
        if (conn == ConnectivityResult.none) {
          print("⚠️ No internet — retry later");
          _markDisconnected();
          _scheduleReconnect();
          return;
        }

        final uri = Uri.parse(url);
        final dns = await InternetAddress.lookup(uri.host);
        if (dns.isEmpty) {
          print("❌ DNS failed for ${uri.host}");
          _markDisconnected();
          _scheduleReconnect();
          return;
        }

        _channel = IOWebSocketChannel.connect(
          url,
          pingInterval: const Duration(seconds: 20),
        );

        print("✅ WS Connected");
        isConnected = true;
        _isConnecting = false;
        _reconnectAttempts = 0;
        notifyListeners();

        _channel!.stream.listen(
          (msg) async {
            totalReceived++;
            print("⚡ WS Message → $msg");

            try {
              final data = jsonDecode(msg);

              final title = data['title'] ?? 'Doxy Alert';
              final body = data['body'] ?? 'You have a new notification';

              final voice = data['voice'] ?? false;

              // Always show visual notification
              await _showNotification(title: title, body: body);

              // ❌ REMOVE TTS from here
              // If voice: EnhancedNotificationService will speak
              if (voice) {
                print(
                    "🎤 Voice notification requested → handled by EnhancedNotificationService");
              }
            } catch (e) {
              print("❌ Message parse error → $e");
            }
          },
          onDone: _handleDisconnect,
          onError: (e) {
            print("❌ WS Error → $e");
            _handleDisconnect();
          },
          cancelOnError: true,
        );
      } catch (e) {
        print("❌ WS Unexpected Error → $e");
        _markDisconnected();
        _scheduleReconnect();
      }
    }();
  }

  /// ========================== Local Notification ==========================
  Future<void> _showNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'backend_notifications',
      'Backend Notifications',
      channelDescription: 'Real-time notifications from server',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  /// ========================== Disconnect / Reconnect ==========================
  void _handleDisconnect() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _markDisconnected();
    _scheduleReconnect();
  }

  void _markDisconnected() {
    isConnected = false;
    _isConnecting = false;
    _channel = null;
    notifyListeners();
  }

  void _scheduleReconnect() {
    _reconnectAttempts++;
    final delay =
        (1000 * (1 << (_reconnectAttempts > 6 ? 6 : _reconnectAttempts)))
            .clamp(1200, 25000);

    print("🔄 WS Reconnect in ${delay}ms (attempt $_reconnectAttempts)");
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delay), _connect);
  }

  /// PUBLIC RECONNECT
  Future<void> reconnect() async {
    print("🔄 WS Immediate Reconnect");
    _reconnectTimer?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}

    _markDisconnected();
    _reconnectAttempts = 0;
    _connect();
  }

  /// Stats
  Map<String, dynamic> getConnectionStats() => {
        "connected": isConnected,
        "received": totalReceived,
        "attempts": _reconnectAttempts,
      };

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    super.dispose();
  }
}
