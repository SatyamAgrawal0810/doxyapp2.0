// lib/screens/habits_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../services/auth_service.dart';

// ── Notification + TTS Singleton ─────────────────────────────────────────────
final _notifs = FlutterLocalNotificationsPlugin();
final FlutterTts _tts = FlutterTts();
bool _habitNotifsInited = false;

Future<void> _initHabitSystem() async {
  if (_habitNotifsInited) return;
  tz.initializeTimeZones();
  await _notifs.initialize(
    const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );
  await _tts.setLanguage('hi-IN');
  await _tts.setSpeechRate(0.48);
  await _tts.setVolume(1.0);
  _habitNotifsInited = true;
}

// Schedule daily habit reminder with voice body text
Future<void> _scheduleHabitDailyNotif({
  required int id,
  required String habitName,
  required int hour,
  required int minute,
}) async {
  await _initHabitSystem();
  try {
    final ist = tz.getLocation('Asia/Kolkata');
    final now = tz.TZDateTime.now(ist);
    var scheduled =
        tz.TZDateTime(ist, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now))
      scheduled = scheduled.add(const Duration(days: 1));

    await _notifs.zonedSchedule(
      id,
      '🎯 Habit Reminder',
      'Time to do: $habitName. Tap to check in!',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'doxys_voice_reminders',
          'Doxy Voice Reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          fullScreenIntent: false,
          styleInformation: BigTextStyleInformation(
              '🔊 Time to do: $habitName. Tap to check in!',
              contentTitle: '🎯 Habit Reminder',
              summaryText: 'Daily Reminder'),
        ),
      ),
      payload: 'Habit reminder. Time to do: $habitName',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    // Also speak immediately if this is scheduled for right now (for testing)
    debugPrint('🔔 Habit reminder scheduled: $habitName at $hour:$minute');
  } catch (e) {
    debugPrint('⚠️ Habit schedule error: $e');
  }
}

// Show instant notification + speak (for check-in confirmation)
Future<void> _notifyCheckin(String habitName, int streak) async {
  await _initHabitSystem();

  final msg = streak > 1
      ? '$habitName checked in! Amazing! $streak day streak!'
      : '$habitName done for today. Keep it up!';

  // Push notification
  await _notifs.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    '✅ Habit Complete!',
    '🔥 $habitName${streak > 1 ? " — $streak day streak!" : " done!"}',
    const NotificationDetails(
      android: AndroidNotificationDetails(
          'doxys_voice_reminders', 'Doxy Voice Reminders',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true),
    ),
  );

  // Voice
  await _tts.stop();
  await _tts.speak(msg);
}

// Cancel a habit's scheduled notification
Future<void> _cancelHabitNotif(int id) async {
  await _initHabitSystem();
  await _notifs.cancel(id);
}

int _habitNotifId(String habitId) => habitId.hashCode.abs() % 100000;

// ─────────────────────────────────────────────────────────────────────────────

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({Key? key}) : super(key: key);
  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  static const String _base = 'https://doxy-bh96.onrender.com/api/habits';
  List<Map<String, dynamic>> _habits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initHabitSystem();
    _load();
  }

  String get _token =>
      Provider.of<AuthService>(context, listen: false).token ?? '';
  Map<String, String> get _headers =>
      {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'};

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http
          .get(Uri.parse(_base), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() => _habits =
            (body['data'] as List? ?? []).cast<Map<String, dynamic>>());
      }
    } catch (e) {
      debugPrint('Load habits: $e');
    }
    setState(() => _loading = false);
  }

  bool _isCheckedToday(Map h) {
    final completions = h['completions'] as List? ?? [];
    final today = DateTime.now();
    return completions.any((c) {
      try {
        final d = DateTime.parse(c['date'].toString()).toLocal();
        return d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
      } catch (_) {
        return false;
      }
    });
  }

  Future<void> _checkin(Map h) async {
    final id = h['_id'] ?? h['id'];
    final name = h['name'] ?? 'Habit';
    try {
      final res = await http
          .post(
            Uri.parse('$_base/$id/checkin'),
            headers: _headers,
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        final newStreak = body['streak']?['current'] ??
            (h['streak'] as Map?)?['current'] ??
            0;

        // ✅ Notification + Voice
        await _notifyCheckin(name, newStreak);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(body['message'] ??
                '🎉 Checked in! ${newStreak > 1 ? "🔥 $newStreak day streak!" : ""}'),
            backgroundColor: Colors.green[800]));
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(body['message'] ?? 'Already checked in today'),
            backgroundColor: Colors.orange[800]));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red[900]));
    }
  }

  Future<void> _delete(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title:
            const Text('Delete Habit?', style: TextStyle(color: Colors.white)),
        content: Text('Delete "$name"?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    await _cancelHabitNotif(_habitNotifId(id));
    await http.delete(Uri.parse('$_base/$id'), headers: _headers);
    _load();
  }

  void _showCreateSheet({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) =>
          _HabitFormSheet(token: _token, existing: existing, onSaved: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Habit Tracker 🎯',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.grey),
              onPressed: _load)
        ],
      ),
      floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFFFF6A00),
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () => _showCreateSheet()),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6A00)))
          : _habits.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFFFF6A00),
                  child: _buildList()),
    );
  }

  Widget _buildEmpty() => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🎯', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 16),
        const Text('No habits yet',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Tap + to create your first habit',
            style: TextStyle(color: Colors.grey[500], fontSize: 14)),
      ]));

  Widget _buildList() {
    final checked = _habits.where((h) => _isCheckedToday(h)).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          _statCard('Total', '${_habits.length}', Icons.list_alt, Colors.blue),
          const SizedBox(width: 10),
          _statCard('Done Today', '$checked', Icons.check_circle, Colors.green),
          const SizedBox(width: 10),
          _statCard(
              'Streaks',
              '${_habits.where((h) => ((h['streak'] as Map?)?['current'] ?? 0) > 0).length}',
              Icons.local_fire_department,
              Colors.orange),
        ]),
        const SizedBox(height: 16),
        ..._habits.map((h) => _HabitCard(
              habit: h,
              isChecked: _isCheckedToday(h),
              onCheckin: () => _checkin(h),
              onEdit: () => _showCreateSheet(existing: h),
              onDelete: () =>
                  _delete(h['_id'] ?? h['id'] ?? '', h['name'] ?? ''),
            )),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) =>
      Expanded(
          child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.3))),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
        ]),
      ));
}

// ── Habit Card ────────────────────────────────────────────────────────────────
class _HabitCard extends StatelessWidget {
  final Map habit;
  final bool isChecked;
  final VoidCallback onCheckin, onEdit, onDelete;
  const _HabitCard(
      {required this.habit,
      required this.isChecked,
      required this.onCheckin,
      required this.onEdit,
      required this.onDelete});

  static const _categoryEmoji = {
    'health': '💚',
    'fitness': '💪',
    'mindfulness': '🧘',
    'productivity': '⚡',
    'learning': '📚',
    'social': '👥',
    'custom': '✨'
  };

  @override
  Widget build(BuildContext context) {
    final name = habit['name'] ?? 'Habit';
    final category = habit['category'] ?? 'custom';
    final streak = (habit['streak'] as Map?)?['current'] ?? 0;
    final rate = (habit['stats'] as Map?)?['completionRate'] ?? 0;
    final emoji = _categoryEmoji[category] ?? '🎯';
    final reminders = habit['reminders'] as List? ?? [];
    final hasReminder = reminders.any((r) => r['enabled'] == true);
    final remH =
        hasReminder ? ((reminders.first['time'] as Map?)?['hour'] ?? 9) : null;
    final remM = hasReminder
        ? ((reminders.first['time'] as Map?)?['minute'] ?? 0)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isChecked
                  ? Colors.green.withOpacity(0.5)
                  : Colors.white.withOpacity(0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: const Color(0xFFFF6A00).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Center(
                  child: Text(habit['icon'] ?? emoji,
                      style: const TextStyle(fontSize: 22)))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                Row(children: [
                  Text(category,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  if (hasReminder && remH != null) ...[
                    const SizedBox(width: 8),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFF6A00).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(
                            '🔔 ${remH.toString().padLeft(2, '0')}:${remM.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                color: Color(0xFFFF6A00), fontSize: 10))),
                  ],
                ]),
              ])),
          if (isChecked)
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('✅ Done',
                    style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold))),
          PopupMenuButton<String>(
            color: const Color(0xFF1E1E1E),
            icon: Icon(Icons.more_vert, color: Colors.grey[500]),
            onSelected: (v) {
              if (v == 'edit')
                onEdit();
              else
                onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Text('Edit', style: TextStyle(color: Colors.white))
                  ])),
              const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red))
                  ])),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _badge('🔥 $streak day streak', Colors.orange),
          const SizedBox(width: 8),
          _badge('$rate% success', Colors.green),
        ]),
        const SizedBox(height: 12),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isChecked ? null : onCheckin,
              icon: Icon(isChecked ? Icons.check_circle : Icons.circle_outlined,
                  size: 18),
              label: Text(isChecked ? 'Completed Today! ✅' : 'Check In Now 🎯'),
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isChecked ? Colors.green[800] : const Color(0xFFFF6A00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
            )),
      ]),
    );
  }

  Widget _badge(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)));
}

// ── Habit Form ────────────────────────────────────────────────────────────────
class _HabitFormSheet extends StatefulWidget {
  final String token;
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _HabitFormSheet(
      {required this.token, this.existing, required this.onSaved});
  @override
  State<_HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends State<_HabitFormSheet> {
  static const String _base = 'https://doxy-bh96.onrender.com/api/habits';
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  String _category = 'health', _frequency = 'daily', _icon = '🎯';
  bool _reminderEnabled = false;
  int _reminderHour = 9, _reminderMinute = 0;
  bool _saving = false;

  static const _categories = [
    'health',
    'fitness',
    'mindfulness',
    'productivity',
    'learning',
    'social',
    'custom'
  ];
  static const _categoryEmoji = {
    'health': '💚',
    'fitness': '💪',
    'mindfulness': '🧘',
    'productivity': '⚡',
    'learning': '📚',
    'social': '👥',
    'custom': '✨'
  };
  static const _icons = [
    '🎯',
    '💪',
    '🧘',
    '📚',
    '✨',
    '🔥',
    '💚',
    '⚡',
    '🌟',
    '🎨',
    '🏃',
    '💼'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final h = widget.existing!;
      _nameCtl.text = h['name'] ?? '';
      _descCtl.text = h['description'] ?? '';
      _category = h['category'] ?? 'health';
      _icon = h['icon'] ?? '🎯';
      _frequency = (h['goal'] as Map?)?['frequency'] ?? 'daily';
      final remList = h['reminders'] as List?;
      if (remList != null && remList.isNotEmpty) {
        final rem = remList.first as Map;
        _reminderEnabled = rem['enabled'] ?? false;
        _reminderHour = (rem['time'] as Map?)?['hour'] ?? 9;
        _reminderMinute = (rem['time'] as Map?)?['minute'] ?? 0;
      }
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
      helpText: 'Daily Reminder Time',
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(primary: Color(0xFFFF6A00))),
          child: child!),
    );
    if (t != null)
      setState(() {
        _reminderHour = t.hour;
        _reminderMinute = t.minute;
      });
  }

  Future<void> _save() async {
    if (_nameCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter habit name')));
      return;
    }
    setState(() => _saving = true);
    final payload = {
      'name': _nameCtl.text.trim(),
      'description': _descCtl.text.trim(),
      'category': _category,
      'icon': _icon,
      'goal': {'frequency': _frequency, 'targetCount': 1, 'unit': 'times'},
      'reminders': [
        {
          'enabled': _reminderEnabled,
          'voiceEnabled': true,
          'time': {'hour': _reminderHour, 'minute': _reminderMinute}
        }
      ],
    };
    final headers = {
      'Authorization': 'Bearer ${widget.token}',
      'Content-Type': 'application/json'
    };
    try {
      final isEdit = widget.existing != null;
      final id = isEdit
          ? (widget.existing!['_id'] ?? widget.existing!['id'] ?? '')
          : '';
      final res = isEdit
          ? await http.put(Uri.parse('$_base/$id'),
              headers: headers, body: jsonEncode(payload))
          : await http.post(Uri.parse(_base),
              headers: headers, body: jsonEncode(payload));

      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        final resBody = jsonDecode(res.body);
        final savedId =
            resBody['data']?['_id'] ?? resBody['habit']?['_id'] ?? id;

        // Schedule/cancel local reminder
        final notifId = _habitNotifId(savedId);
        await _cancelHabitNotif(notifId);
        if (_reminderEnabled && savedId.isNotEmpty) {
          await _scheduleHabitDailyNotif(
            id: notifId,
            habitName: _nameCtl.text.trim(),
            hour: _reminderHour,
            minute: _reminderMinute,
          );
        }

        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${isEdit ? "✅ Habit updated!" : "✅ Habit created!"} ${_reminderEnabled ? "🔔 Reminder at ${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')}" : ""}'),
            backgroundColor: Colors.green[800]));
      } else {
        final err = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: ${err['message'] ?? res.statusCode}'),
            backgroundColor: Colors.red[900]));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red[900]));
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2)))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Text(widget.existing != null ? '✏️ Edit Habit' : '🎯 New Habit',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context)),
              ])),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              _lbl('Habit Name *'),
              _fld(controller: _nameCtl, hint: 'e.g., Morning Meditation'),
              const SizedBox(height: 12),
              _lbl('Description'),
              _fld(
                  controller: _descCtl,
                  hint: 'What do you want to achieve?',
                  maxLines: 2),
              const SizedBox(height: 12),
              _lbl('Icon'),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _icons
                      .map((ic) => GestureDetector(
                            onTap: () => setState(() => _icon = ic),
                            child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: _icon == ic
                                        ? const Color(0xFFFF6A00)
                                            .withOpacity(0.2)
                                        : const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: _icon == ic
                                            ? const Color(0xFFFF6A00)
                                            : Colors.transparent)),
                                child: Text(ic,
                                    style: const TextStyle(fontSize: 22))),
                          ))
                      .toList()),
              const SizedBox(height: 12),
              _lbl('Category'),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories
                      .map((cat) => GestureDetector(
                            onTap: () => setState(() => _category = cat),
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                    color: _category == cat
                                        ? const Color(0xFFFF6A00)
                                            .withOpacity(0.2)
                                        : const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: _category == cat
                                            ? const Color(0xFFFF6A00)
                                            : Colors.transparent)),
                                child: Text(
                                    '${_categoryEmoji[cat]} ${cat[0].toUpperCase()}${cat.substring(1)}',
                                    style: TextStyle(
                                        color: _category == cat
                                            ? const Color(0xFFFF6A00)
                                            : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))),
                          ))
                      .toList()),
              const SizedBox(height: 12),
              _lbl('Frequency'),
              Row(
                  children: ['daily', 'weekly', 'custom']
                      .map((f) => Expanded(
                          child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () => setState(() => _frequency = f),
                                child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                        color: _frequency == f
                                            ? const Color(0xFFFF6A00)
                                            : const Color(0xFF1E1E1E),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Text(
                                        f[0].toUpperCase() + f.substring(1),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: _frequency == f
                                                ? Colors.white
                                                : Colors.grey,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600))),
                              ))))
                      .toList()),
              const SizedBox(height: 16),

              // ── Reminder Section ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF6A00).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFFF6A00).withOpacity(0.2))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.notifications_active,
                            color: Color(0xFFFF6A00), size: 18),
                        const SizedBox(width: 8),
                        const Text('Daily Reminder',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Switch(
                            value: _reminderEnabled,
                            onChanged: (v) =>
                                setState(() => _reminderEnabled = v),
                            activeColor: const Color(0xFFFF6A00)),
                      ]),
                      if (_reminderEnabled) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _pickTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFFF6A00)
                                        .withOpacity(0.4))),
                            child: Row(children: [
                              const Icon(Icons.access_time,
                                  color: Color(0xFFFF6A00), size: 18),
                              const SizedBox(width: 10),
                              const Text('Reminder Time',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                              const Spacer(),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFFF6A00)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                      '${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                          color: Color(0xFFFF6A00),
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold))),
                              const SizedBox(width: 6),
                              const Icon(Icons.edit,
                                  color: Color(0xFFFF6A00), size: 14),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.volume_up,
                              color: Colors.greenAccent, size: 13),
                          const SizedBox(width: 4),
                          Text(
                              'Voice reminder + notification daily at set time\nVoice confirmation on check-in',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 10)),
                        ]),
                      ],
                    ]),
              ),
              const SizedBox(height: 20),
            ]),
          )),
          Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6A00),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          widget.existing != null
                              ? 'Update Habit'
                              : 'Create Habit',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                ),
              )),
        ]),
      ),
    );
  }

  Widget _lbl(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t,
          style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600)));

  Widget _fld(
          {required TextEditingController controller,
          required String hint,
          int maxLines = 1}) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
      );
}
