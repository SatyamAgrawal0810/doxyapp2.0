// lib/screens/routines_screen.dart — Blue Theme
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../services/auth_service.dart';

final _notifs = FlutterLocalNotificationsPlugin();
bool _notifInited = false;

Future<void> _initNotifs() async {
  if (_notifInited) return;
  tz.initializeTimeZones();
  await _notifs.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  _notifInited = true;
}

Future<void> _scheduleDailyNotif({
  required int id, required String title, required String body,
  required int hour, required int minute, List<String> days = const [],
}) async {
  await _initNotifs();
  try {
    final ist = tz.getLocation('Asia/Kolkata');
    final now = tz.TZDateTime.now(ist);
    var scheduled = tz.TZDateTime(ist, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    await _notifs.zonedSchedule(
      id, title, body, scheduled,
      NotificationDetails(android: AndroidNotificationDetails(
        'doxys_voice_reminders', 'Doxy Voice Reminders',
        importance: Importance.max, priority: Priority.high, playSound: true, enableVibration: true,
        styleInformation: BigTextStyleInformation(body, contentTitle: title),
      )),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  } catch (e) { debugPrint('Schedule notif error: $e'); }
}

Future<void> _cancelRoutineNotifs(String routineId) async {
  await _initNotifs();
  final hash = routineId.hashCode.abs() % 10000;
  for (int i = 0; i < 50; i++) await _notifs.cancel(hash + i);
}

// ─────────────────────────────────────────────────────────────────────────────

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({Key? key}) : super(key: key);
  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  static const String _base = 'https://doxy-bh96.onrender.com/api/routines';
  List<Map<String, dynamic>> _routines = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _initNotifs(); _load(); }

  String get _token => Provider.of<AuthService>(context, listen: false).token ?? '';
  Map<String, String> get _headers =>
      {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'};

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse(_base), headers: _headers).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = (body['data'] ?? body['routines'] ?? []) as List;
        setState(() => _routines = data.cast<Map<String, dynamic>>());
      }
    } catch (e) { debugPrint('Load routines: $e'); }
    setState(() => _loading = false);
  }

  Future<void> _completeMorning(String id) async {
    final res = await http.post(Uri.parse('$_base/$id/complete-morning'), headers: _headers);
    if (!mounted) return;
    final body = jsonDecode(res.body);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.statusCode == 200 ? 'Morning completed!' : (body['message'] ?? 'Failed')),
        backgroundColor: res.statusCode == 200 ? Colors.green[800] : Colors.orange[800]));
    if (res.statusCode == 200) _load();
  }

  Future<void> _completeEvening(String id) async {
    final res = await http.post(Uri.parse('$_base/$id/complete-evening'), headers: _headers);
    if (!mounted) return;
    final body = jsonDecode(res.body);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.statusCode == 200 ? 'Evening completed!' : (body['message'] ?? 'Failed')),
        backgroundColor: res.statusCode == 200 ? Colors.purple[800] : Colors.orange[800]));
    if (res.statusCode == 200) _load();
  }

  Future<void> _delete(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111125),
        title: const Text('Delete Routine?', style: TextStyle(color: Colors.white)),
        content: Text('Delete "$name"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    await _cancelRoutineNotifs(id);
    await http.delete(Uri.parse('$_base/$id'), headers: _headers);
    _load();
  }

  void _showForm({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RoutineFormSheet(token: _token, existing: existing, onSaved: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Daily Routines', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true, elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.grey), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF2979FF),
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () => _showForm()),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)))
          : _routines.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(onRefresh: _load, color: const Color(0xFF2979FF),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _routines.length,
                    itemBuilder: (_, i) {
                      final r = _routines[i];
                      return _RoutineCard(
                        routine: r,
                        onEdit: () => _showForm(existing: r),
                        onDelete: () => _delete(r['_id'] ?? r['id'] ?? '', r['name'] ?? ''),
                        onMorning: () => _completeMorning(r['_id'] ?? r['id'] ?? ''),
                        onEvening: () => _completeEvening(r['_id'] ?? r['id'] ?? ''),
                      );
                    },
                  )),
    );
  }

  Widget _buildEmpty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.auto_awesome, size: 72, color: Color(0xFF2979FF)),
    const SizedBox(height: 16),
    const Text('No routines yet', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Text('Tap + to create your first routine', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
  ]));
}

// ── Routine Card ──────────────────────────────────────────────────────────────
class _RoutineCard extends StatelessWidget {
  final Map routine;
  final VoidCallback onEdit, onDelete, onMorning, onEvening;
  const _RoutineCard({required this.routine, required this.onEdit,
      required this.onDelete, required this.onMorning, required this.onEvening});

  String _fmt(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final name = routine['name'] ?? 'Routine';
    final stats = routine['stats'] as Map? ?? {};
    final morningEnabled = (routine['morningRoutine'] as Map?)?['enabled'] == true;
    final eveningEnabled = (routine['eveningRoutine'] as Map?)?['enabled'] == true;
    final wakeH = ((routine['morningRoutine'] as Map?)?['wakeUpTime'] as Map?)?['hour'] ?? 6;
    final wakeM = ((routine['morningRoutine'] as Map?)?['wakeUpTime'] as Map?)?['minute'] ?? 0;
    final sleepH = ((routine['eveningRoutine'] as Map?)?['sleepTime'] as Map?)?['hour'] ?? 22;
    final sleepM = ((routine['eveningRoutine'] as Map?)?['sleepTime'] as Map?)?['minute'] ?? 0;
    final morningActs = ((routine['morningRoutine'] as Map?)?['activities'] as List?) ?? [];
    final eveningActs = ((routine['eveningRoutine'] as Map?)?['activities'] as List?) ?? [];
    final days = (routine['schedule'] as Map?)?['days'] as List? ?? [];
    final endDate = (routine['period'] as Map?)?['endDate'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: const Color(0xFF0F0F1E), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: const Color(0xFF2979FF).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.auto_awesome, color: Color(0xFF2979FF), size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            if (days.isNotEmpty)
              Text(days.map((d) => d.toString().substring(0, 2).toUpperCase()).join(' · '),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            if (endDate != null)
              Text('Until ${endDate.substring(0, 10)}', style: TextStyle(color: Colors.orange[300], fontSize: 10)),
          ])),
          Row(children: [
            _statBadge('${stats['currentStreak'] ?? 0} streak', Colors.orange),
            const SizedBox(width: 4),
            _statBadge('${stats['morningCompletions'] ?? 0} AM', Colors.blue),
            const SizedBox(width: 4),
            _statBadge('${stats['eveningCompletions'] ?? 0} PM', Colors.purple),
          ]),
          PopupMenuButton<String>(
            color: const Color(0xFF141428),
            icon: Icon(Icons.more_vert, color: Colors.grey[500]),
            onSelected: (v) { if (v == 'edit') onEdit(); else onDelete(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [
                Icon(Icons.edit, color: Colors.blue, size: 18), SizedBox(width: 8),
                Text('Edit', style: TextStyle(color: Colors.white))])),
              const PopupMenuItem(value: 'delete', child: Row(children: [
                Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ])),

        if (morningEnabled) ...[
          const Divider(color: Color(0xFF1E1E38), height: 1),
          Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.wb_sunny, color: Colors.orange, size: 18),
              const SizedBox(width: 6),
              const Text('Morning', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text('Wake ${_fmt(wakeH, wakeM)}',
                      style: TextStyle(color: Colors.orange[300], fontSize: 12, fontWeight: FontWeight.bold))),
            ]),
            if (morningActs.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...morningActs.take(4).map((a) {
                final aH = (a['startTime'] as Map?)?['hour'] ?? wakeH;
                final aM = (a['startTime'] as Map?)?['minute'] ?? 0;
                return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
                  const Icon(Icons.circle, size: 6, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a['title'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text('${_fmt(aH, aM)} · ${a['duration'] ?? 0}min',
                          style: TextStyle(color: Colors.orange[300], fontSize: 10))),
                ]));
              }),
              if (morningActs.length > 4)
                Text('+${morningActs.length - 4} more', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            ],
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: onMorning,
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Complete Morning'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800], foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            )),
          ])),
        ],

        if (eveningEnabled) ...[
          const Divider(color: Color(0xFF1E1E38), height: 1),
          Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.nights_stay, color: Colors.purple, size: 18),
              const SizedBox(width: 6),
              const Text('Evening', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text('Sleep ${_fmt(sleepH, sleepM)}',
                      style: TextStyle(color: Colors.purple[300], fontSize: 12, fontWeight: FontWeight.bold))),
            ]),
            if (eveningActs.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...eveningActs.take(4).map((a) {
                final aH = (a['startTime'] as Map?)?['hour'] ?? sleepH;
                final aM = (a['startTime'] as Map?)?['minute'] ?? 0;
                return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
                  const Icon(Icons.circle, size: 6, color: Colors.purple),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a['title'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text('${_fmt(aH, aM)} · ${a['duration'] ?? 0}min',
                          style: TextStyle(color: Colors.purple[300], fontSize: 10))),
                ]));
              }),
              if (eveningActs.length > 4)
                Text('+${eveningActs.length - 4} more', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            ],
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: onEvening,
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Complete Evening'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[800], foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            )),
          ])),
        ],
      ]),
    );
  }

  Widget _statBadge(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)));
}

// ── Routine Form ──────────────────────────────────────────────────────────────
class _RoutineFormSheet extends StatefulWidget {
  final String token;
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _RoutineFormSheet({required this.token, this.existing, required this.onSaved});
  @override
  State<_RoutineFormSheet> createState() => _RoutineFormSheetState();
}

class _RoutineFormSheetState extends State<_RoutineFormSheet> {
  static const String _base = 'https://doxy-bh96.onrender.com/api/routines';
  final _nameCtl = TextEditingController();
  List<String> _days = ['monday','tuesday','wednesday','thursday','friday'];
  bool _morningEnabled = true, _eveningEnabled = true;
  int _wakeH = 6, _wakeM = 0, _sleepH = 22, _sleepM = 0;
  List<Map<String, dynamic>> _morningActs = [], _eveningActs = [];
  bool _saving = false;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  static const _weekDays = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday'];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final r = widget.existing!;
      _nameCtl.text = r['name'] ?? '';
      _days = ((r['schedule'] as Map?)?['days'] as List?)?.cast<String>() ?? _days;
      final period = r['period'] as Map? ?? {};
      if (period['startDate'] != null) _startDate = DateTime.tryParse(period['startDate']) ?? DateTime.now();
      if (period['endDate'] != null) _endDate = DateTime.tryParse(period['endDate']);
      final m = r['morningRoutine'] as Map? ?? {};
      _morningEnabled = m['enabled'] ?? true;
      _wakeH = (m['wakeUpTime'] as Map?)?['hour'] ?? 6;
      _wakeM = (m['wakeUpTime'] as Map?)?['minute'] ?? 0;
      _morningActs = List<Map<String, dynamic>>.from(((m['activities'] as List?) ?? []).map((a) => Map<String, dynamic>.from(a as Map)));
      final e = r['eveningRoutine'] as Map? ?? {};
      _eveningEnabled = e['enabled'] ?? true;
      _sleepH = (e['sleepTime'] as Map?)?['hour'] ?? 22;
      _sleepM = (e['sleepTime'] as Map?)?['minute'] ?? 0;
      _eveningActs = List<Map<String, dynamic>>.from(((e['activities'] as List?) ?? []).map((a) => Map<String, dynamic>.from(a as Map)));
    }
  }

  @override
  void dispose() { _nameCtl.dispose(); super.dispose(); }

  String _fmt(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  Future<void> _pickTime(String label, int h, int m, void Function(int, int) onPicked) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: h, minute: m), helpText: label,
        builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF2979FF))), child: child!));
    if (t != null) setState(() => onPicked(t.hour, t.minute));
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final initial = isEnd ? (_endDate ?? DateTime.now().add(const Duration(days: 30))) : _startDate;
    final p = await showDatePicker(context: context, initialDate: initial,
        firstDate: isEnd ? _startDate : DateTime(2024), lastDate: DateTime(2030),
        builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF2979FF))), child: child!));
    if (p != null) setState(() { if (isEnd) _endDate = p; else _startDate = p; });
  }

  Future<void> _scheduleNotifications(String routineId) async {
    final hash = routineId.hashCode.abs() % 10000;
    int notifId = hash;
    if (_endDate != null && _endDate!.isBefore(DateTime.now())) return;
    if (_morningEnabled) {
      await _scheduleDailyNotif(id: notifId++, title: 'Wake Up Time',
          body: '${_nameCtl.text.trim()} — Good morning! Time to start your day at ${_fmt(_wakeH, _wakeM)}',
          hour: _wakeH, minute: _wakeM, days: _days);
      for (final act in _morningActs) {
        final aH = (act['startTime'] as Map?)?['hour'] ?? _wakeH;
        final aM = (act['startTime'] as Map?)?['minute'] ?? 0;
        final title = act['title'] ?? '';
        if (title.isNotEmpty) {
          await _scheduleDailyNotif(id: notifId++, title: title,
              body: 'Morning activity — ${act['duration'] ?? 30} minutes | ${_nameCtl.text.trim()}',
              hour: aH, minute: aM, days: _days);
        }
      }
    }
    if (_eveningEnabled) {
      final beforeH = (_sleepH * 60 + _sleepM - 30) ~/ 60;
      final beforeM = (_sleepH * 60 + _sleepM - 30) % 60;
      await _scheduleDailyNotif(id: notifId++, title: 'Bedtime Soon',
          body: '${_nameCtl.text.trim()} — Wind down! Sleep time in 30 minutes at ${_fmt(_sleepH, _sleepM)}',
          hour: beforeH.clamp(0, 23), minute: beforeM.clamp(0, 59), days: _days);
      await _scheduleDailyNotif(id: notifId++, title: 'Evening Routine',
          body: '${_nameCtl.text.trim()} — Time for your evening routine! Sleep at ${_fmt(_sleepH, _sleepM)}',
          hour: _sleepH, minute: _sleepM, days: _days);
      for (final act in _eveningActs) {
        final aH = (act['startTime'] as Map?)?['hour'] ?? _sleepH;
        final aM = (act['startTime'] as Map?)?['minute'] ?? 0;
        final title = act['title'] ?? '';
        if (title.isNotEmpty) {
          await _scheduleDailyNotif(id: notifId++, title: title,
              body: 'Evening activity — ${act['duration'] ?? 30} minutes | ${_nameCtl.text.trim()}',
              hour: aH, minute: aM, days: _days);
        }
      }
    }
  }

  Future<void> _save() async {
    if (_nameCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter routine name')));
      return;
    }
    if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one day')));
      return;
    }
    setState(() => _saving = true);
    final payload = {
      'name': _nameCtl.text.trim(),
      'period': {'startDate': DateFormat('yyyy-MM-dd').format(_startDate),
          'endDate': _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null, 'isActive': true},
      'schedule': {'days': _days},
      'morningRoutine': {
        'enabled': _morningEnabled,
        'wakeUpTime': {'hour': _wakeH, 'minute': _wakeM},
        'activities': _morningActs.map((a) => {
          'title': a['title'] ?? '', 'startTime': a['startTime'] ?? {'hour': _wakeH, 'minute': _wakeM},
          'duration': a['duration'] ?? 30, 'priority': a['priority'] ?? 'medium', 'category': a['category'] ?? 'personal',
          'addToCalendar': true, 'reminder': {'enabled': true, 'minutesBefore': 5, 'notificationMethod': 'voice'},
        }).toList(),
      },
      'eveningRoutine': {
        'enabled': _eveningEnabled,
        'sleepTime': {'hour': _sleepH, 'minute': _sleepM},
        'activities': _eveningActs.map((a) => {
          'title': a['title'] ?? '', 'startTime': a['startTime'] ?? {'hour': _sleepH, 'minute': _sleepM},
          'duration': a['duration'] ?? 30, 'priority': a['priority'] ?? 'medium', 'category': a['category'] ?? 'personal',
          'addToCalendar': true, 'reminder': {'enabled': true, 'minutesBefore': 5, 'notificationMethod': 'voice'},
        }).toList(),
      },
      'calendarSync': {'enabled': true},
    };
    final headers = {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'};
    try {
      final isEdit = widget.existing != null;
      final id = isEdit ? (widget.existing!['_id'] ?? widget.existing!['id']) : null;
      final res = isEdit
          ? await http.put(Uri.parse('$_base/$id'), headers: headers, body: jsonEncode(payload))
          : await http.post(Uri.parse(_base), headers: headers, body: jsonEncode(payload));
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        final responseBody = jsonDecode(res.body);
        final savedId = responseBody['data']?['_id'] ?? responseBody['routine']?['_id'] ?? id ?? '';
        if (savedId.isNotEmpty) { await _cancelRoutineNotifs(savedId); await _scheduleNotifications(savedId); }
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEdit ? 'Routine updated! Notifications scheduled.' : 'Routine created! Notifications scheduled.'),
            backgroundColor: Colors.green[800]));
      } else {
        final err = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: ${err['message'] ?? res.statusCode}'), backgroundColor: Colors.red[900]));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[900]));
    }
    setState(() => _saving = false);
  }

  void _addAct(bool isMorning) => setState(() {
    final defaultH = isMorning ? _wakeH : _sleepH;
    final defaultM = isMorning ? _wakeM : _sleepM;
    (isMorning ? _morningActs : _eveningActs).add({
      'title': '', 'startTime': {'hour': defaultH, 'minute': defaultM},
      'duration': 30, 'priority': 'medium', 'category': 'personal'
    });
  });

  void _removeAct(bool isMorning, int idx) => setState(() {
    if (isMorning) _morningActs.removeAt(idx); else _eveningActs.removeAt(idx);
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: const BoxDecoration(color: Color(0xFF0D0D1A), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
            Text(widget.existing != null ? 'Edit Routine' : 'New Routine',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
          ])),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              _label('Routine Name *'),
              _field(controller: _nameCtl, hint: 'e.g., My Daily Routine'),
              const SizedBox(height: 14),
              _label('Duration'),
              Row(children: [
                Expanded(child: GestureDetector(onTap: () => _pickDate(isEnd: false),
                    child: _dateDisplay('Start', DateFormat('dd MMM yyyy').format(_startDate), Colors.blue))),
                const SizedBox(width: 8),
                Expanded(child: GestureDetector(onTap: () => _pickDate(isEnd: true),
                    child: _dateDisplay('End (optional)',
                        _endDate != null ? DateFormat('dd MMM yyyy').format(_endDate!) : 'No end date',
                        _endDate != null ? Colors.orange : Colors.grey))),
                if (_endDate != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(onTap: () => setState(() => _endDate = null),
                      child: const Icon(Icons.close, color: Colors.grey, size: 18)),
                ],
              ]),
              const SizedBox(height: 14),
              _label('Active Days'),
              Wrap(spacing: 6, runSpacing: 6, children: _weekDays.map((d) {
                final sel = _days.contains(d);
                return GestureDetector(
                  onTap: () => setState(() { if (sel) _days.remove(d); else _days.add(d); }),
                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: sel ? const Color(0xFF2979FF) : const Color(0xFF141428),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(d.substring(0, 2).toUpperCase(),
                          style: TextStyle(color: sel ? Colors.white : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                );
              }).toList()),
              const SizedBox(height: 16),
              _sectionHeader('Morning Routine', _morningEnabled, (v) => setState(() => _morningEnabled = v), Colors.orange),
              if (_morningEnabled) ...[
                const SizedBox(height: 10),
                GestureDetector(onTap: () => _pickTime('Wake Up Time', _wakeH, _wakeM, (h, m) { _wakeH = h; _wakeM = m; }),
                    child: _timeDisplay('Wake Up Time', _fmt(_wakeH, _wakeM), Colors.orange, subtitle: 'Tap to change')),
                const SizedBox(height: 10),
                ..._morningActs.asMap().entries.map((e) => _actTile(e.value, e.key, true)),
                TextButton.icon(onPressed: () => _addAct(true),
                    icon: const Icon(Icons.add, color: Color(0xFF2979FF), size: 18),
                    label: const Text('Add Morning Activity', style: TextStyle(color: Color(0xFF2979FF)))),
              ],
              const SizedBox(height: 8),
              _sectionHeader('Evening Routine', _eveningEnabled, (v) => setState(() => _eveningEnabled = v), Colors.purple),
              if (_eveningEnabled) ...[
                const SizedBox(height: 10),
                GestureDetector(onTap: () => _pickTime('Sleep Time', _sleepH, _sleepM, (h, m) { _sleepH = h; _sleepM = m; }),
                    child: _timeDisplay('Sleep Time', _fmt(_sleepH, _sleepM), Colors.purple, subtitle: 'Tap to change · Reminder 30 min before')),
                const SizedBox(height: 10),
                ..._eveningActs.asMap().entries.map((e) => _actTile(e.value, e.key, false)),
                TextButton.icon(onPressed: () => _addAct(false),
                    icon: const Icon(Icons.add, color: Color(0xFF2979FF), size: 18),
                    label: const Text('Add Evening Activity', style: TextStyle(color: Color(0xFF2979FF)))),
              ],
              const SizedBox(height: 20),
            ]),
          )),
          Padding(padding: const EdgeInsets.all(20), child: SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2979FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.existing != null ? 'Update Routine' : 'Create Routine',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          )),
        ]),
      ),
    );
  }

  Widget _dateDisplay(String label, String value, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
        const SizedBox(height: 2),
        Row(children: [
          Expanded(child: Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))),
          Icon(Icons.edit_calendar, color: color, size: 14),
        ]),
      ]));

  Widget _timeDisplay(String label, String time, Color color, {String? subtitle}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3))),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
            if (subtitle != null) Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(time, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold))),
          const SizedBox(width: 6),
          Icon(Icons.access_time, color: color, size: 16),
        ]),
      );

  Widget _actTile(Map<String, dynamic> act, int idx, bool isMorning) {
    final color = isMorning ? Colors.orange : Colors.purple;
    final aH = (act['startTime'] as Map?)?['hour'] ?? (isMorning ? _wakeH : _sleepH);
    final aM = (act['startTime'] as Map?)?['minute'] ?? 0;
    final titleCtl = TextEditingController(text: act['title'] ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF141428), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.drag_handle, color: Colors.grey[600], size: 16),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: titleCtl, onChanged: (v) => act['title'] = v,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(hintText: 'Activity name', hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                  border: InputBorder.none, contentPadding: EdgeInsets.zero))),
          GestureDetector(onTap: () => _removeAct(isMorning, idx),
              child: const Icon(Icons.close, color: Colors.red, size: 16)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => _pickTime('Activity Start Time', aH, aM, (h, m) => setState(() { act['startTime'] = {'hour': h, 'minute': m}; })),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.3))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.access_time, color: color, size: 14), const SizedBox(width: 4),
                  Text(_fmt(aH, aM), style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4), Icon(Icons.edit, color: color, size: 10),
                ])),
          )),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Duration', style: TextStyle(color: Colors.grey[600], fontSize: 9)),
            const SizedBox(height: 2),
            TextField(keyboardType: TextInputType.number,
                controller: TextEditingController(text: (act['duration'] ?? 30).toString()),
                onChanged: (v) => act['duration'] = int.tryParse(v) ?? 30,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(filled: true, fillColor: const Color(0xFF181830),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    suffixText: 'min', suffixStyle: TextStyle(color: Colors.grey[500], fontSize: 11))),
          ])),
        ]),
      ]),
    );
  }

  Widget _sectionHeader(String title, bool enabled, void Function(bool) onToggle, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Row(children: [
          Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          const Spacer(),
          Switch(value: enabled, onChanged: onToggle, activeColor: color),
        ]),
      );

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)));

  Widget _field({required TextEditingController controller, required String hint}) =>
      TextField(controller: controller, style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
              filled: true, fillColor: const Color(0xFF141428),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)));
}
