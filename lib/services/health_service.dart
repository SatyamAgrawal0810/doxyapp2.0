// lib/services/health_service.dart
// ✅ FIX: autoRefresh returns HC data only (no steps field)
// ✅ Steps ONLY come from pedometer stream — never overwritten

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:http/http.dart' as http;
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class HealthService {
  final AuthService auth;
  final Health _health = Health();
  static const String _baseUrl = 'https://doxy-bh96.onrender.com/api/health';

  // ── Pedometer ──────────────────────────────────────────────────────────────
  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<PedestrianStatus>? _statusSub;
  int _stepOffset = -1;
  int _todaySteps = 0;
  DateTime? _offsetDate;

  final _stepController = StreamController<int>.broadcast();
  Stream<int> get liveStepStream => _stepController.stream;
  int get currentLiveSteps => _todaySteps;

  int _lastSyncedSteps = -1;
  bool _syncBusy = false;

  // ── App timer ──────────────────────────────────────────────────────────────
  static const _kAppSecs = 'app_seconds_today';
  static const _kAppSecsDate = 'app_seconds_date';
  int _appSecondsToday = 0;
  Timer? _appTimer;
  Timer? _refreshTimer;

  static const _kHcAsked = 'hc_permission_asked_v2';

  static const _hcTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.WEIGHT,
  ];

  static const _kManualHR = 'manual_heart_rate';
  static const _kManualSleep = 'manual_sleep_hours';
  static const _kManualWeight = 'manual_weight_kg';
  static const _kManualHRDate = 'manual_hr_date';
  static const _kManualSleepDate = 'manual_sleep_date';

  HealthService({required this.auth});

  // ── Health Connect ─────────────────────────────────────────────────────────

  Future<bool> isHealthConnectAvailable() async {
    try {
      return await Health().isHealthConnectAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<void> installHealthConnect() async {
    try {
      await Health().installHealthConnect();
    } catch (_) {}
  }

  Future<bool> hasAskedPermission() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kHcAsked) ?? false;
  }

  Future<HealthPermissionResult> requestPermissions() async {
    try {
      await _health.configure();
      if (!await isHealthConnectAvailable())
        return HealthPermissionResult.notInstalled;
      final granted = await _health.requestAuthorization(
        _hcTypes,
        permissions: _hcTypes.map((_) => HealthDataAccess.READ).toList(),
      );
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kHcAsked, true);
      return granted
          ? HealthPermissionResult.granted
          : HealthPermissionResult.denied;
    } catch (e) {
      debugPrint('Permission error: $e');
      return HealthPermissionResult.error;
    }
  }

  Future<bool> hasPermissions() async {
    try {
      if (!await isHealthConnectAvailable()) return false;
      return await _health.hasPermissions(
            _hcTypes,
            permissions: _hcTypes.map((_) => HealthDataAccess.READ).toList(),
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  // ── App Timer ──────────────────────────────────────────────────────────────

  Future<void> startAppTimer() async {
    await _loadAppSeconds();
    _appTimer?.cancel();
    _appTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      _appSecondsToday++;
      if (_appSecondsToday % 5 == 0) await _saveAppSeconds();
    });
  }

  Future<void> _loadAppSeconds() async {
    final p = await SharedPreferences.getInstance();
    final today = _dayKey();
    if ((p.getString(_kAppSecsDate) ?? '') == today) {
      _appSecondsToday = p.getInt(_kAppSecs) ?? 0;
    } else {
      _appSecondsToday = 0;
      await p.setString(_kAppSecsDate, today);
      await p.setInt(_kAppSecs, 0);
    }
  }

  Future<void> _saveAppSeconds() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kAppSecs, _appSecondsToday);
    await p.setString(_kAppSecsDate, _dayKey());
  }

  int get appSecondsToday => _appSecondsToday;
  String formatAppTime() {
    final s = _appSecondsToday;
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h ${m % 60}m';
  }

  // ── Auto Refresh — HC data ONLY, NO steps field ────────────────────────────
  // ✅ KEY FIX: callback never includes 'steps' — screen keeps its own _liveSteps
  void startAutoRefresh(void Function(Map<String, dynamic>) onData) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final data = await readHCDataOnly(); // ✅ no steps here
      onData(data);
    });
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  // ── Pedometer ──────────────────────────────────────────────────────────────

  Future<void> startLiveStepTracking() async {
    _stepSub?.cancel();
    _statusSub?.cancel();
    await _loadOffset();

    _statusSub = Pedometer.pedestrianStatusStream.listen(
      (s) => debugPrint('Walk: ${s.status}'),
      onError: (e) => debugPrint('Ped status: $e'),
    );

    _stepSub = Pedometer.stepCountStream.listen(
      (StepCount event) async {
        final raw = event.steps;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        if (_stepOffset == -1 ||
            _offsetDate == null ||
            _offsetDate!.isBefore(today)) {
          _stepOffset = raw;
          _offsetDate = today;
          await _saveOffset(raw, today);
          debugPrint('📅 Offset reset: $raw');
        }

        _todaySteps = (raw - _stepOffset).clamp(0, 999999);

        // ✅ Emit on every single step — instant UI update
        if (!_stepController.isClosed) _stepController.add(_todaySteps);
        debugPrint('👟 Steps: $_todaySteps');

        if (_todaySteps - _lastSyncedSteps >= 10) _autoSyncSteps(_todaySteps);
      },
      onError: (e) => debugPrint('Step err: $e'),
    );
  }

  void stopLiveStepTracking() {
    _stepSub?.cancel();
    _statusSub?.cancel();
    _stepSub = _statusSub = null;
  }

  String _dayKey() => _dateKey(DateTime.now());
  String _dateKey(DateTime d) => '${d.year}_${d.month}_${d.day}';

  Future<void> _saveOffset(int v, DateTime d) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('step_offset_val', v);
    await p.setString('step_offset_date', _dateKey(d));
  }

  Future<void> _loadOffset() async {
    final p = await SharedPreferences.getInstance();
    final val = p.getInt('step_offset_val');
    final dated = p.getString('step_offset_date');
    final today = DateTime.now();
    if (val != null && dated == _dateKey(today)) {
      _stepOffset = val;
      _offsetDate = DateTime(today.year, today.month, today.day);
      debugPrint('📅 Loaded offset: $_stepOffset');
    } else {
      _stepOffset = -1;
      _offsetDate = null;
    }
  }

  void dispose() {
    stopLiveStepTracking();
    stopAutoRefresh();
    _appTimer?.cancel();
    _saveAppSeconds();
    if (!_stepController.isClosed) _stepController.close();
  }

  // ── Auto sync steps ────────────────────────────────────────────────────────

  Future<void> _autoSyncSteps(int steps) async {
    if (_syncBusy) return;
    _syncBusy = true;
    _lastSyncedSteps = steps;
    try {
      await http
          .post(
            Uri.parse('$_baseUrl/mobile-sync'),
            headers: {
              'Authorization': 'Bearer ${auth.token ?? ''}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'date': DateTime.now().toIso8601String(),
              'steps': {'count': steps},
              'activeMinutes': {'total': (steps / 100).round()},
              'source': 'pedometer',
            }),
          )
          .timeout(const Duration(seconds: 8));
      debugPrint('✅ Synced: $steps steps');
    } catch (e) {
      debugPrint('⚠️ Auto-sync: $e');
    } finally {
      _syncBusy = false;
    }
  }

  // ── HC data only (no steps) — used by autoRefresh ─────────────────────────
  // ✅ This never returns 'steps' so it can never override pedometer value
  Future<Map<String, dynamic>> readHCDataOnly() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int heartRate = 0;
    double sleepMin = 0, calories = 0, weight = 0;

    try {
      final pts = await _health.getHealthDataFromTypes(
          startTime: today, endTime: now, types: [HealthDataType.HEART_RATE]);
      if (pts.isNotEmpty) {
        final sum = pts.fold<int>(0,
            (s, p) => s + (p.value as NumericHealthValue).numericValue.toInt());
        heartRate = sum ~/ pts.length;
      }
    } catch (_) {}

    try {
      final sleepStart = DateTime(now.year, now.month, now.day - 1, 18, 0);
      final sleepEnd = DateTime(now.year, now.month, now.day, 12, 0);
      final pts = await _health.getHealthDataFromTypes(
          startTime: sleepStart,
          endTime: sleepEnd,
          types: [HealthDataType.SLEEP_ASLEEP]);
      for (final p in pts)
        sleepMin += p.dateTo.difference(p.dateFrom).inMinutes;
    } catch (_) {}

    try {
      final totalPts = await _health.getHealthDataFromTypes(
          startTime: today,
          endTime: now,
          types: [HealthDataType.TOTAL_CALORIES_BURNED]);
      for (final p in totalPts)
        calories += (p.value as NumericHealthValue).numericValue.toDouble();
      if (calories == 0) {
        final activePts = await _health.getHealthDataFromTypes(
            startTime: today,
            endTime: now,
            types: [HealthDataType.ACTIVE_ENERGY_BURNED]);
        for (final p in activePts)
          calories += (p.value as NumericHealthValue).numericValue.toDouble();
      }
    } catch (_) {}

    try {
      final pts = await _health.getHealthDataFromTypes(
          startTime: now.subtract(const Duration(days: 30)),
          endTime: now,
          types: [HealthDataType.WEIGHT]);
      if (pts.isNotEmpty) {
        pts.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        weight =
            (pts.first.value as NumericHealthValue).numericValue.toDouble();
      }
    } catch (_) {}

    // Manual fallback
    final manual = await getManualData();
    if (heartRate == 0 && manual['heartRate'] != null)
      heartRate = manual['heartRate'] as int;
    if (sleepMin == 0 && manual['sleepHours'] != null)
      sleepMin = (manual['sleepHours'] as double) * 60;
    if (weight == 0 && manual['weight'] != null)
      weight = manual['weight'] as double;

    // ✅ NO 'steps' field here — screen keeps its own pedometer steps
    return {
      'heartRate': heartRate,
      'sleepMinutes': sleepMin.round(),
      'sleep': sleepMin > 0 ? '${(sleepMin / 60).toStringAsFixed(1)}h' : '--',
      'calories': calories > 0 ? calories.round() : 0,
      'bloodOxygen': '--',
      'weight': weight > 0 ? weight.toStringAsFixed(1) : '--',
    };
  }

  // ── Full readTodayData (includes steps from pedometer) ─────────────────────
  Future<Map<String, dynamic>> readTodayData() async {
    final hc = await readHCDataOnly();
    return {
      ...hc,
      'steps': _todaySteps,
      'activeMinutes': (_todaySteps / 100).round(),
      'appTime': formatAppTime(),
    };
  }

  Future<Map<String, dynamic>> getTodaySummary() => readTodayData();

  Future<bool> syncToBackend() async {
    try {
      final data = await readTodayData();
      final res = await http
          .post(
            Uri.parse('$_baseUrl/mobile-sync'),
            headers: {
              'Authorization': 'Bearer ${auth.token ?? ''}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'date': DateTime.now().toIso8601String(),
              'steps': {'count': data['steps']},
              'heartRate': {
                'average': data['heartRate'],
                'resting': data['heartRate']
              },
              'sleep': {'duration': data['sleepMinutes']},
              'calories': {'burned': data['calories']},
              'activeMinutes': {'total': data['activeMinutes']},
              'source': defaultTargetPlatform == TargetPlatform.iOS
                  ? 'healthkit'
                  : 'health_connect',
            }),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getInsights() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/insights'),
        headers: {'Authorization': 'Bearer ${auth.token ?? ''}'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200)
        return jsonDecode(res.body)['insights'] as Map<String, dynamic>? ?? {};
    } catch (_) {}
    return {};
  }

  Future<void> saveManualData(
      {int? heartRate, double? sleepHours, double? weight}) async {
    final p = await SharedPreferences.getInstance();
    final today = _dayKey();
    if (heartRate != null) {
      await p.setInt(_kManualHR, heartRate);
      await p.setString(_kManualHRDate, today);
    }
    if (sleepHours != null) {
      await p.setDouble(_kManualSleep, sleepHours);
      await p.setString(_kManualSleepDate, today);
    }
    if (weight != null) {
      await p.setDouble(_kManualWeight, weight);
    }
  }

  Future<Map<String, dynamic>> getManualData() async {
    final p = await SharedPreferences.getInstance();
    final today = _dayKey();
    final Map<String, dynamic> r = {};
    if ((p.getString(_kManualHRDate) ?? '') == today &&
        p.containsKey(_kManualHR)) r['heartRate'] = p.getInt(_kManualHR);
    if ((p.getString(_kManualSleepDate) ?? '') == today &&
        p.containsKey(_kManualSleep))
      r['sleepHours'] = p.getDouble(_kManualSleep);
    if (p.containsKey(_kManualWeight))
      r['weight'] = p.getDouble(_kManualWeight);
    return r;
  }
}

enum HealthPermissionResult { granted, denied, notInstalled, error }
