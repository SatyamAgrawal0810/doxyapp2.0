// lib/services/enhanced_notification_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:audioplayers/audioplayers.dart';

/// EnhancedNotificationService
/// - Local notifications (immediate & scheduled)
/// - TTS fallback (local) if no backend audio or playback fails
/// - Plays backend audioUrl when provided (audioplayers)
/// - Methods used by main.dart / calendar_screen.dart
class EnhancedNotificationService {
  // local notifications
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // TTS instance (local fallback)
  static FlutterTts? _tts;

  // audio player for backend audio URLs
  static final AudioPlayer _audioPlayer = AudioPlayer();

  // internal state
  static bool _initialized = false;
  static String? _authToken;

  /// Initialize (idempotent)
  static Future<void> init({String? authToken}) async {
    if (_initialized) return;

    _authToken = authToken;

    // timezone database (for scheduling)
    tzdata.initializeTimeZones();

    // 1) init local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestCriticalPermission: true,
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _notifications.initialize(initSettings,
        onDidReceiveNotificationResponse: (response) {
      debugPrint('🔔 Notification tapped: ${response.payload}');
      // Optionally handle payload
    });

    // 2) init TTS (best-effort)
    try {
      _tts ??= FlutterTts();
      await _tts?.setLanguage('hi-IN');
      await _tts?.setSpeechRate(0.48);
      await _tts?.setVolume(1.0);
      await _tts?.setPitch(1.02);
      debugPrint('🎤 Local TTS initialized');
    } catch (e) {
      debugPrint('⚠️ TTS init failed: $e');
      _tts = null;
    }

    // 3) request permissions (best effort)
    try {
      await Permission.notification.request();
    } catch (_) {}
    try {
      await Permission.microphone.request();
    } catch (_) {}

    // 4) create channels
    await _createNotificationChannels();

    _initialized = true;
    debugPrint('✅ EnhancedNotificationService ready');
  }

  static Future<void> _createNotificationChannels() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    // backend / general reminders
    final reminderChannel = AndroidNotificationChannel(
      'doxys_reminders',
      'Doxy Reminders',
      description: 'Reminder alerts sent by backend or local scheduling',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await android.createNotificationChannel(reminderChannel);

    // ai voice alerts (visual + voice)
    final voiceChannel = AndroidNotificationChannel(
      'ai_voice_alerts',
      'AI Voice Alerts',
      description: 'Notifications that include voice playback',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await android.createNotificationChannel(voiceChannel);

    // ultra high priority channel (scheduled urgent)
    final criticalChannel = AndroidNotificationChannel(
      'ultra_high_priority',
      'Ultra High Priority',
      description: 'Urgent alerts and full-screen intents',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await android.createNotificationChannel(criticalChannel);

    debugPrint('🔔 Notification channels created');
  }

  /// Show instant visual notification
  static Future<void> showInstantNotification({
    required String title,
    required String body,
    String channelId = 'doxys_reminders',
    String? payload,
    String priority = 'high',
  }) async {
    try {
      final importance = (priority == 'critical' || priority == 'urgent')
          ? Importance.max
          : Importance.high;

      final androidDetails = AndroidNotificationDetails(
        channelId,
        _getChannelName(channelId),
        channelDescription: _getChannelDescription(channelId),
        importance: importance,
        priority: importance == Importance.max ? Priority.max : Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      );

      final details =
          NotificationDetails(android: androidDetails, iOS: iosDetails);

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _notifications.show(id, title, body, details,
          payload: payload ?? 'instant:$id');

      debugPrint('📱 Instant notification shown: $title (id: $id)');
    } catch (e) {
      debugPrint('❌ showInstantNotification failed: $e');
    }
  }

  /// Show AI Voice notification:
  /// - If audioUrl provided -> try to play it (audioplayer)
  /// - If audioUrl missing or playback fails -> speak via local TTS
  /// - Always shows a visual notification afterwards
  static Future<void> showAIVoiceNotification({
    required String title,
    required String body,
    String channelId = 'ai_voice_alerts',
    Map<String, dynamic>? voiceSettings,
    String? audioUrl,
    String? payload,
    String priority = 'high',
  }) async {
    try {
      bool playedAudio = false;

      // 1) try backend audio URL first (non-blocking but awaited)
      if (audioUrl != null && audioUrl.isNotEmpty) {
        try {
          // stop any previous audio
          try {
            await _audioPlayer.stop();
          } catch (_) {}
          // play URL (await). We don't capture a "result" to print (avoids void interpolation error).
          await _audioPlayer.play(UrlSource(audioUrl));
          debugPrint('🎧 Played backend audio URL: $audioUrl');
          playedAudio = true;
        } catch (e) {
          debugPrint('❌ Playing backend audio failed: $e');
          playedAudio = false;
        }
      }

      // 2) fallback: local TTS speak
      if (!playedAudio) {
        if (_tts != null) {
          try {
            // Apply optional settings
            if (voiceSettings != null) {
              final lang = voiceSettings['language'] as String?;
              final rateNum = voiceSettings['rate'];
              final volumeNum = voiceSettings['volume'];
              final pitchNum = voiceSettings['pitch'];

              if (lang != null) await _tts?.setLanguage(lang);
              if (rateNum is num) await _tts?.setSpeechRate(rateNum.toDouble());
              if (volumeNum is num) await _tts?.setVolume(volumeNum.toDouble());
              if (pitchNum is num) await _tts?.setPitch(pitchNum.toDouble());
            }

            // generate short message
            final msg = _generateVoiceMessage(title, body, voiceSettings);
            await _tts?.stop();
            await _tts?.speak(msg);
            debugPrint('🗣️ Spoken by local TTS: $msg');
          } catch (e) {
            debugPrint('❌ Local TTS speak failed: $e');
          }
        } else {
          debugPrint('⚠️ No local TTS available and no backend audio');
        }
      }

      // 3) show visual notification (so user sees it)
      await showInstantNotification(
        title: '🎤 $title',
        body: body,
        channelId: channelId,
        payload: payload ?? 'ai_voice:${DateTime.now().millisecondsSinceEpoch}',
        priority: priority,
      );
    } catch (e) {
      debugPrint('❌ showAIVoiceNotification failed: $e');
    }
  }

  static String _generateVoiceMessage(
      String title, String body, Map<String, dynamic>? settings) {
    String base = '$title. $body';
    if (settings == null) return 'नोटिफिकेशन: $base';

    final tone = settings['tone'] as String? ?? 'friendly';
    switch (tone) {
      case 'urgent':
        base = 'अत्यावश्यक! $base कृपया तुरंत ध्यान दें।';
        break;
      case 'calm':
        base = 'शांति से सुनें। $base';
        break;
      case 'energetic':
        base = 'हैलो! $base चलिए शुरू करते हैं!';
        break;
      default:
        base = 'नमस्ते! $base';
    }
    final custom = settings['customMessage'] as String?;
    if (custom != null && custom.isNotEmpty) base = custom;
    return base;
  }

  /// Schedule an ultra-high priority notification (tz-aware)
  static Future<void> scheduleUltraHighPriorityNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String eventId,
    String? payload,
  }) async {
    try {
      // ensure tz inited
      tzdata.initializeTimeZones();

      // adjust very-near-past times to near future to avoid failure
      DateTime finalTime = scheduledTime;
      if (finalTime.isBefore(DateTime.now().add(const Duration(seconds: 5)))) {
        finalTime = DateTime.now().add(const Duration(seconds: 5));
      }

      final notificationId = eventId.hashCode.abs();

      final androidDetails = AndroidNotificationDetails(
        'ultra_high_priority',
        'Ultra High Priority',
        channelDescription: 'Maximum priority notifications for urgent events',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        ticker: title,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        interruptionLevel: InterruptionLevel.critical,
      );

      final details =
          NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        tz.TZDateTime.from(finalTime, tz.local),
        details,
        payload: payload ?? 'ultra_priority:$eventId',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );

      debugPrint(
          '⏰ Scheduled notification (id: $notificationId) at $finalTime');
    } catch (e) {
      debugPrint('❌ scheduleUltraHighPriorityNotification failed: $e');
    }
  }

  /// Cancel scheduled event notification by eventId
  static Future<void> cancelEventNotification(String eventId) async {
    try {
      final id = eventId.hashCode.abs();
      await _notifications.cancel(id);
      debugPrint('🗑️ Cancelled notification for event $eventId (id $id)');
    } catch (e) {
      debugPrint('❌ cancelEventNotification failed: $e');
    }
  }

  /// Get pending scheduled notifications
  static Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint('📋 Pending notifications count: ${pending.length}');
      return pending;
    } catch (e) {
      debugPrint('❌ getPendingNotifications failed: $e');
      return [];
    }
  }

  /// Send a test instant notification (used by UI)
  static Future<void> sendTestNotification() async {
    try {
      await showInstantNotification(
        title: '🧪 Test Notification',
        body: 'This is a test from EnhancedNotificationService.',
        channelId: 'doxys_reminders',
        priority: 'high',
      );
      debugPrint('🧪 Test notification triggered');
    } catch (e) {
      debugPrint('❌ sendTestNotification failed: $e');
    }
  }

  /// Debug info printed to console, useful for support screens
  static Future<void> debugNotificationSystem() async {
    try {
      debugPrint('🔍 === NOTIFICATION SYSTEM DEBUG ===');
      debugPrint('   initialized: $_initialized');
      debugPrint('   authToken present: ${_authToken != null}');
      final permission = await Permission.notification.status;
      debugPrint('   Notification permission: $permission');
      final pending = await getPendingNotifications();
      debugPrint('   Pending notifications: ${pending.length}');
      debugPrint('🔍 === DEBUG COMPLETE ===');
    } catch (e) {
      debugPrint('❌ debugNotificationSystem failed: $e');
    }
  }

  /// Dispose: stop audio + tts
  static Future<void> dispose() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    try {
      await _tts?.stop();
    } catch (_) {}
    _initialized = false;
    debugPrint('🧹 EnhancedNotificationService disposed');
  }

  // helpers
  static String _getChannelName(String id) {
    switch (id) {
      case 'ai_voice_alerts':
        return 'AI Voice Alerts';
      case 'doxys_reminders':
        return 'Doxy Reminders';
      case 'ultra_high_priority':
        return 'Ultra High Priority';
      default:
        return 'Notifications';
    }
  }

  static String _getChannelDescription(String id) {
    switch (id) {
      case 'ai_voice_alerts':
        return 'Notifications with voice playback';
      case 'doxys_reminders':
        return 'Reminder alerts';
      case 'ultra_high_priority':
        return 'Urgent alerts';
      default:
        return 'General notifications';
    }
  }
}
