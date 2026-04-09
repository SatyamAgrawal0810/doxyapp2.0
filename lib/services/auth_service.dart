import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService extends ChangeNotifier {
  static const String API_BASE_URL = "https://doxy-bh96.onrender.com/api/auth";

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final AppLinks _appLinks = AppLinks();

  String? token;
  bool isLoading = false;
  bool _isSendingDeviceToken = false;

  // ✅ Cached profile — provides userName, userEmail, userId without extra calls
  Map<String, dynamic>? _cachedProfile;

  String? get userName => _cachedProfile?['name'] as String?;
  String? get userEmail => _cachedProfile?['email'] as String?;
  String? get userId => _cachedProfile?['_id'] as String?;
  String? get userAvatar => _cachedProfile?['avatar'] as String?;
  String? get authProvider => _cachedProfile?['authProvider'] as String?;
  Map<String, dynamic>? get userPreferences =>
      _cachedProfile?['preferences'] as Map<String, dynamic>?;
  Map<String, dynamic>? get healthGoals =>
      _cachedProfile?['healthGoals'] as Map<String, dynamic>?;

  AuthService() {
    _loadToken();
    _initDeepLinkListener();
    _initFCMListeners();
  }

  void _initDeepLinkListener() {
    _appLinks.uriLinkStream.listen((uri) async {
      if (uri == null) return;
      debugPrint("🔗 Deep Link Received: $uri");
      final jwt = uri.queryParameters["token"];
      if (jwt != null && jwt.isNotEmpty) {
        await saveToken(jwt);
        debugPrint("🔥 Google OAuth Success — JWT Saved");
      }
    });
  }

  void _initFCMListeners() {
    FirebaseMessaging.instance.getToken().then((t) async {
      if (t != null && isAuthenticated) await sendDeviceTokenToServer();
    });
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (isAuthenticated) await sendDeviceTokenToServer();
    });
  }

  Future<void> _loadToken() async {
    token = await _storage.read(key: "jwt_token");
    notifyListeners();
    if (token != null) {
      await sendDeviceTokenToServer();
      await _fetchAndCacheProfile();
    }
  }

  Future<void> saveToken(String t) async {
    token = t;
    await _storage.write(key: "jwt_token", value: t);
    notifyListeners();
    await sendDeviceTokenToServer();
    await _fetchAndCacheProfile();
  }

  Future<void> removeToken() async {
    token = null;
    _cachedProfile = null;
    await _storage.delete(key: "jwt_token");
    notifyListeners();
  }

  Map<String, String> _headers() => {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      };

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  // Fetches /api/auth/me once after login and caches result
  Future<void> _fetchAndCacheProfile() async {
    if (token == null || token!.isEmpty) return;
    try {
      final res = await http
          .get(Uri.parse("$API_BASE_URL/me"), headers: _headers())
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        // Backend returns { success: true, user: {...} }
        final user = body['user'] ?? body['data']?['user'];
        if (user != null) {
          _cachedProfile = user as Map<String, dynamic>;
          notifyListeners();
          debugPrint("✅ Profile cached: ${_cachedProfile?['name']}");
        }
      }
    } catch (e) {
      debugPrint("⚠️ Profile cache fetch failed: $e");
    }
  }

  Future<void> refreshProfile() => _fetchAndCacheProfile();

  Future<void> sendDeviceTokenToServer() async {
    if (_isSendingDeviceToken) return;
    _isSendingDeviceToken = true;
    try {
      if (!isAuthenticated) return;
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;
      await http.post(
        Uri.parse("https://doxy-bh96.onrender.com/api/notifications/register"),
        headers: _headers(),
        body: jsonEncode({
          "token": fcmToken,
          "deviceInfo": {"platform": "android"},
        }),
      );
    } catch (e) {
      debugPrint("❌ Device token upload failed: $e");
    } finally {
      _isSendingDeviceToken = false;
    }
  }

  Future<Map<String, dynamic>> signup(
      String name, String email, String password) async {
    try {
      isLoading = true;
      notifyListeners();
      final res = await http.post(
        Uri.parse("$API_BASE_URL/signup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"name": name, "email": email, "password": password}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        await saveToken(data["token"]);
        return {"ok": true};
      }
      return {"ok": false, "message": data["message"] ?? "Signup failed"};
    } catch (e) {
      return {"ok": false, "message": e.toString()};
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      isLoading = true;
      notifyListeners();
      final res = await http.post(
        Uri.parse("$API_BASE_URL/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        await saveToken(data["token"]);
        return {"ok": true};
      }
      return {"ok": false, "message": data["message"] ?? "Login failed"};
    } catch (e) {
      return {"ok": false, "message": e.toString()};
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      isLoading = true;
      notifyListeners();
      final res =
          await http.get(Uri.parse("$API_BASE_URL/google?state=mobile"));
      final data = jsonDecode(res.body);
      final authUrl = data["authUrl"];
      if (authUrl == null || authUrl.isEmpty) throw "Google Auth URL missing";
      await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("❌ Google Login Error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    try {
      final res =
          await http.get(Uri.parse("$API_BASE_URL/me"), headers: _headers());
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final user = data['user'] ?? data['data']?['user'];
        if (user != null) {
          _cachedProfile = user as Map<String, dynamic>;
          notifyListeners();
        }
        return {"ok": true, "data": data};
      }
      return {"ok": false, "message": data["message"] ?? "Error"};
    } catch (e) {
      return {"ok": false, "message": e.toString()};
    }
  }

  Future<Map<String, dynamic>> updatePreferences(
      Map<String, dynamic> prefs) async {
    try {
      final res = await http.put(
        Uri.parse("$API_BASE_URL/preferences"),
        headers: _headers(),
        body: jsonEncode(prefs),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        await _fetchAndCacheProfile();
        return {"ok": true, "data": data};
      }
      return {"ok": false, "message": data["message"] ?? "Update failed"};
    } catch (e) {
      return {"ok": false, "message": e.toString()};
    }
  }

  Future<void> logout() async {
    try {
      await http.post(Uri.parse("$API_BASE_URL/logout"), headers: _headers());
    } catch (_) {}
    await removeToken();
  }

  Future<bool> hasToken() async {
    final t = await _storage.read(key: "jwt_token");
    return t != null && t.isNotEmpty;
  }

  Future<String?> getToken() async {
    if (token != null && token!.isNotEmpty) return token;
    final stored = await _storage.read(key: "jwt_token");
    if (stored != null && stored.isNotEmpty) {
      token = stored;
      return stored;
    }
    return null;
  }
}
