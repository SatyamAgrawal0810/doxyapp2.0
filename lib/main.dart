import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/enhanced_notification_service.dart';
import 'services/local_tts_service.dart';

import 'screens/splash_screen.dart';
import 'screens/main_wrapper.dart';
import 'screens/home_dashboard.dart';
import 'screens/calendar_screen.dart';
import 'screens/health_screen.dart';
import 'screens/login_page.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Global TTS for background/foreground voice
final FlutterTts _globalTts = FlutterTts();
bool _ttsInited = false;

Future<void> _initGlobalTts() async {
  if (_ttsInited) return;
  await _globalTts.setLanguage('hi-IN');
  await _globalTts.setSpeechRate(0.48);
  await _globalTts.setVolume(1.0);
  _ttsInited = true;
}

Future<void> _speakText(String text) async {
  await _initGlobalTts();
  final clean = text.replaceAll(RegExp(r'[🎯🌅🌆🔔📅⚡✅🔊💪🧘📚]'), '').trim();
  if (clean.isNotEmpty) await _globalTts.speak(clean);
}

// Save pending voice text for when app opens
Future<void> _savePendingVoiceText(String text) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_voice_text', text);
  } catch (_) {}
}

// ── Background FCM handler ─────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final title =
      message.notification?.title ?? message.data['title'] ?? 'Doxy Reminder';
  final body = message.notification?.body ?? message.data['body'] ?? '';
  final audioUrl = message.data['audioUrl'] as String?;
  final isVoice =
      message.data['voice'] == 'true' || message.data['voice'] == true;

  debugPrint('🔕 BG Notification: $title | voice=$isVoice');

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    isVoice && body.isNotEmpty ? '🔊 $body' : body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'doxys_voice_reminders',
        'Doxy Voice Reminders',
        channelDescription: 'Voice reminder notifications from Doxy',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        fullScreenIntent: isVoice,
        styleInformation: isVoice && body.isNotEmpty
            ? BigTextStyleInformation('🔊 $body',
                contentTitle: title, summaryText: 'Voice Reminder')
            : null,
      ),
    ),
  );

  // Save audio URL (FCM voice) OR text (for TTS)
  try {
    final prefs = await SharedPreferences.getInstance();
    if (audioUrl != null && audioUrl.isNotEmpty) {
      await prefs.setString('pending_voice_audio', audioUrl);
      await prefs.setString('pending_voice_title', title);
      await prefs.setString('pending_voice_body', body);
    } else if (isVoice && body.isNotEmpty) {
      // No audio URL — save text for TTS on app open
      await prefs.setString('pending_voice_text', '$title. $body');
    }
  } catch (e) {
    debugPrint('❌ Prefs error: $e');
  }
}

// ── Local notification response (app tap or foreground receive) ────────────
@pragma('vm:entry-point')
void _onLocalNotifResponse(NotificationResponse response) async {
  // When user TAPS a notification — speak it
  final body = response.payload ?? '';
  if (body.isNotEmpty) {
    await _speakText(body);
  }
}

@pragma('vm:entry-point')
void _onLocalNotifBackgroundResponse(NotificationResponse response) async {
  // Background tap — save for TTS on resume
  final body = response.payload ?? '';
  if (body.isNotEmpty) {
    await _savePendingVoiceText(body);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('🔥 Firebase initialized');
  await _initGlobalTts();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Init local notifications with response handlers
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    onDidReceiveNotificationResponse: _onLocalNotifResponse,
    onDidReceiveBackgroundNotificationResponse: _onLocalNotifBackgroundResponse,
  );

  // Create notification channels
  final androidImpl =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
    'doxys_reminders',
    'Doxy Reminders',
    description: 'Reminder notifications',
    importance: Importance.max,
  ));

  await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
    'doxys_voice_reminders',
    'Doxy Voice Reminders',
    description: 'Voice reminder notifications from Doxy',
    importance: Importance.max,
  ));

  await _askPermissions();
  await EnhancedNotificationService.init();

  runApp(const DoxyApp());
}

Future<void> _askPermissions() async {
  await Permission.notification.request();
  await Permission.microphone.request();
  await Permission.storage.request();
  if (await Permission.scheduleExactAlarm.isDenied) {
    await Permission.scheduleExactAlarm.request();
  }
  debugPrint('📌 Permissions granted');
}

class DoxyApp extends StatelessWidget {
  const DoxyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService())
      ],
      child: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (auth.isAuthenticated) {
            FirebaseMessaging.instance.getToken().then((token) {
              debugPrint('📡 Token on login: $token');
              auth.sendDeviceTokenToServer();
            });
          }
          return MaterialApp(
            navigatorKey: GlobalKeys.navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            home: AppLifecycleHandler(
                child: SplashScreen(userHasToken: auth.isAuthenticated)),
            onGenerateRoute: _onRoute,
          );
        },
      ),
    );
  }

  Route? _onRoute(RouteSettings settings) {
    if (settings.arguments is Map<String, dynamic>) {
      final args = settings.arguments as Map<String, dynamic>;
      switch (args['type']) {
        case 'medication':
          return MaterialPageRoute(builder: (_) => const HealthScreen());
        case 'event':
        case 'appointment':
          return MaterialPageRoute(
              builder: (_) => const EnhancedCalendarScreen());
        case 'task':
          return MaterialPageRoute(builder: (_) => const HomeScreen());
      }
    }
    switch (settings.name) {
      case '/home':
        return MaterialPageRoute(builder: (_) => const MainWrapper());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginPage());
      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }
}

class GlobalKeys {
  static final navigatorKey = GlobalKey<NavigatorState>();
}

class AppLifecycleHandler extends StatefulWidget {
  final Widget child;
  const AppLifecycleHandler({super.key, required this.child});
  @override
  State<AppLifecycleHandler> createState() => _AppLifecycleHandlerState();
}

class _AppLifecycleHandlerState extends State<AppLifecycleHandler>
    with WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _playPending());

    // Foreground FCM
    FirebaseMessaging.onMessage.listen((message) async {
      final title =
          message.notification?.title ?? message.data['title'] ?? 'Reminder';
      final body = message.notification?.body ?? message.data['body'] ?? '';
      final audioUrl = message.data['audioUrl'] as String?;
      final isVoice =
          message.data['voice'] == 'true' || message.data['voice'] == true;

      debugPrint('📩 FG Notification: $title | voice=$isVoice');

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        isVoice ? '🔊 $body' : body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
              'doxys_voice_reminders', 'Doxy Voice Reminders',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true),
        ),
      );

      // Play voice (app in foreground)
      try {
        if (audioUrl != null && audioUrl.isNotEmpty) {
          await _player.stop();
          await _player.play(UrlSource(audioUrl));
          debugPrint('🎧 FG audio: $audioUrl');
        } else if (isVoice && body.isNotEmpty) {
          // No backend audio — use TTS
          await _speakText('$title. $body');
          debugPrint('🔊 FG TTS: $title');
        } else if (body.isNotEmpty) {
          await LocalTTS.speak('$title. $body');
        }
      } catch (e) {
        debugPrint('❌ FG audio error: $e');
        try {
          await _speakText('$title. $body');
        } catch (_) {}
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((_) async {
      debugPrint('📱 App opened from notification');
      await _playPending();
    });
  }

  // Play pending audio URL OR pending TTS text
  Future<void> _playPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. FCM audio URL (from backend voice reminder)
      final audioUrl = prefs.getString('pending_voice_audio');
      if (audioUrl != null && audioUrl.isNotEmpty) {
        await prefs.remove('pending_voice_audio');
        await prefs.remove('pending_voice_title');
        await prefs.remove('pending_voice_body');
        debugPrint('🎧 Playing pending audio: $audioUrl');
        await Future.delayed(const Duration(milliseconds: 1500));
        await _player.stop();
        await _player.play(UrlSource(audioUrl));
        return;
      }

      // 2. Local notification TTS text (from habit/routine reminder)
      final voiceText = prefs.getString('pending_voice_text');
      if (voiceText != null && voiceText.isNotEmpty) {
        await prefs.remove('pending_voice_text');
        debugPrint('🔊 Speaking pending TTS: $voiceText');
        await Future.delayed(const Duration(milliseconds: 1000));
        await _speakText(voiceText);
      }
    } catch (e) {
      debugPrint('⚠️ Pending play error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _playPending();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    _globalTts.stop();
    EnhancedNotificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
