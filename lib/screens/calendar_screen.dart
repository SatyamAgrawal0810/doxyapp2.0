// lib/screens/calendar_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import '../services/calendar_service.dart';
import '../services/auth_service.dart';
import '../services/enhanced_notification_service.dart';

class EnhancedCalendarScreen extends StatefulWidget {
  const EnhancedCalendarScreen({Key? key}) : super(key: key);
  @override
  State<EnhancedCalendarScreen> createState() => _EnhancedCalendarScreenState();
}

class _EnhancedCalendarScreenState extends State<EnhancedCalendarScreen> {
  late CalendarFormat _calendarFormat;
  DateTime _focused = DateTime.now();
  DateTime? _selected;

  final Map<DateTime, List<Map<String, dynamic>>> _events = {};
  final Map<DateTime, List<Map<String, dynamic>>> _reminders = {};
  final Map<DateTime, List<Map<String, dynamic>>> _habitMarkers = {};
  final Map<DateTime, List<Map<String, dynamic>>> _routineMarkers = {};

  bool _loading = true;
  bool _isSpeaking = false;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.month;
    _selected = _focused;
    _initTts();
    _loadAll();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('hi-IN');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    _tts.setStartHandler(() => setState(() => _isSpeaking = true));
    _tts.setCompletionHandler(() => setState(() => _isSpeaking = false));
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
      return;
    }
    final clean = text.replaceAll(RegExp(r'[🎯🌅🌆🔔📅⚡🏃💪]'), '').trim();
    await _tts.speak(clean);
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadEvents(), _loadReminders(), _loadHabits(), _loadRoutines()]);
    setState(() => _loading = false);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dayName(int weekday) {
    const days = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday'];
    return days[weekday - 1];
  }

  Future<void> _loadEvents() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final cs = CalendarService(baseUrl: 'https://doxy-bh96.onrender.com/api', auth: auth);
    try {
      final data = await cs.getEvents();
      setState(() {
        _events.clear();
        for (final e in data) {
          final eTitle = e['title'] as String? ?? '';
          final eDesc = e['description'] as String? ?? '';
          if (eTitle.contains('Morning') || eTitle.contains('Evening') ||
              eDesc.contains('Morning Activities') || eDesc.contains('Evening Activities') ||
              eDesc.contains('morning') || eDesc.contains('evening')) continue;
          final start = (DateTime.tryParse(e['start'] ?? e['startTime'] ?? '') ?? DateTime.now()).toLocal();
          final end = (DateTime.tryParse(e['end'] ?? e['endTime'] ?? '') ?? start.add(const Duration(hours: 1))).toLocal();
          _events.putIfAbsent(_dateOnly(start), () => []).add({
            'id': e['_id'] ?? e['id'],
            'title': e['title'] ?? 'Untitled Event',
            'start': start, 'end': end,
            'description': e['description'] ?? '',
            'location': e['location'] ?? '',
            'reminderPreferences': e['reminderPreferences'] ?? {},
          });
        }
      });
    } catch (e) { debugPrint('Load events: $e'); }
  }

  Future<void> _loadReminders() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final cs = CalendarService(baseUrl: 'https://doxy-bh96.onrender.com/api', auth: auth);
    try {
      final data = await cs.getReminders();
      setState(() {
        _reminders.clear();
        for (final r in data) {
          final time = DateTime.parse(r['reminderTime']).toLocal();
          _reminders.putIfAbsent(_dateOnly(time), () => []).add({
            'id': r['_id'], 'title': r['title'],
            'description': r['description'] ?? '', 'time': time,
          });
        }
      });
    } catch (e) { debugPrint('Load reminders: $e'); }
  }

  Future<void> _loadHabits() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final res = await http.get(
        Uri.parse('https://doxy-bh96.onrender.com/api/habits'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final habits = (jsonDecode(res.body)['data'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _habitMarkers.clear();
        for (final h in habits) {
          final reminders = h['reminders'] as List? ?? [];
          int hour = 9, minute = 0;
          bool hasReminder = false;
          for (final rem in reminders) {
            if (rem['enabled'] == true) {
              hour = (rem['time'] as Map?)?['hour'] ?? 9;
              minute = (rem['time'] as Map?)?['minute'] ?? 0;
              hasReminder = true;
              break;
            }
          }
          for (int i = 0; i < 30; i++) {
            final day = DateTime.now().add(Duration(days: i));
            _habitMarkers.putIfAbsent(_dateOnly(day), () => []).add({
              'id': h['_id'] ?? h['id'],
              'title': '${h['name']}',
              'time': DateTime(day.year, day.month, day.day, hour, minute),
              'category': h['category'] ?? 'habit',
              'type': 'habit',
              'streak': (h['streak'] as Map?)?['current'] ?? 0,
              'icon': h['icon'] ?? '🎯',
              'hasReminder': hasReminder,
            });
          }
        }
      });
    } catch (e) { debugPrint('Load habits: $e'); }
  }

  Future<void> _loadRoutines() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final res = await http.get(
        Uri.parse('https://doxy-bh96.onrender.com/api/routines'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body);
      final routines = ((body['data'] ?? body['routines'] ?? []) as List).cast<Map<String, dynamic>>();
      setState(() {
        _routineMarkers.clear();
        for (final r in routines) {
          final scheduleDays = ((r['schedule'] as Map?)?['days'] as List?)?.cast<String>() ?? [];
          final morning = r['morningRoutine'] as Map? ?? {};
          final evening = r['eveningRoutine'] as Map? ?? {};
          final morningActs = (morning['activities'] as List? ?? []);
          final eveningActs = (evening['activities'] as List? ?? []);
          for (int i = 0; i < 30; i++) {
            final day = DateTime.now().add(Duration(days: i));
            if (!scheduleDays.contains(_dayName(day.weekday))) continue;
            final key = _dateOnly(day);
            if (morning['enabled'] == true) {
              final h = (morning['wakeUpTime'] as Map?)?['hour'] ?? 6;
              final m = (morning['wakeUpTime'] as Map?)?['minute'] ?? 0;
              _routineMarkers.putIfAbsent(key, () => []).add({
                'id': '${r['_id']}_morning',
                'title': '${r['name']} (Morning)',
                'time': DateTime(day.year, day.month, day.day, h, m),
                'type': 'routine_morning', 'routineName': r['name'],
              });
              for (int ai = 0; ai < morningActs.length; ai++) {
                final act = morningActs[ai] as Map;
                final aTitle = act['title'] ?? '';
                if (aTitle.isEmpty) continue;
                final aH = (act['startTime'] as Map?)?['hour'] ?? h;
                final aM = (act['startTime'] as Map?)?['minute'] ?? m;
                _routineMarkers.putIfAbsent(key, () => []).add({
                  'id': '${r['_id']}_mact_$ai',
                  'title': aTitle,
                  'time': DateTime(day.year, day.month, day.day, aH, aM),
                  'type': 'routine_activity', 'routineName': r['name'],
                  'duration': act['duration'] ?? 30,
                });
              }
            }
            if (evening['enabled'] == true) {
              final h = (evening['sleepTime'] as Map?)?['hour'] ?? 22;
              final m = (evening['sleepTime'] as Map?)?['minute'] ?? 0;
              _routineMarkers.putIfAbsent(key, () => []).add({
                'id': '${r['_id']}_evening',
                'title': '${r['name']} (Evening)',
                'time': DateTime(day.year, day.month, day.day, h, m),
                'type': 'routine_evening', 'routineName': r['name'],
              });
              for (int ai = 0; ai < eveningActs.length; ai++) {
                final act = eveningActs[ai] as Map;
                final aTitle = act['title'] ?? '';
                if (aTitle.isEmpty) continue;
                final aH = (act['startTime'] as Map?)?['hour'] ?? h;
                final aM = (act['startTime'] as Map?)?['minute'] ?? m;
                _routineMarkers.putIfAbsent(key, () => []).add({
                  'id': '${r['_id']}_eact_$ai',
                  'title': aTitle,
                  'time': DateTime(day.year, day.month, day.day, aH, aM),
                  'type': 'routine_activity', 'routineName': r['name'],
                  'duration': act['duration'] ?? 30,
                });
              }
            }
          }
        }
      });
    } catch (e) { debugPrint('Load routines: $e'); }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = _dateOnly(day);
    return [...(_events[key] ?? []), ...(_habitMarkers[key] ?? []), ...(_routineMarkers[key] ?? [])];
  }
  List<Map<String, dynamic>> _getRemindersForDay(DateTime day) => _reminders[_dateOnly(day)] ?? [];

  Future<void> _deleteEvent(String id) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final cs = CalendarService(baseUrl: 'https://doxy-bh96.onrender.com/api', auth: auth);
    final ok = await cs.deleteEvent(id);
    if (ok) {
      await EnhancedNotificationService.cancelEventNotification(id);
      await _loadEvents();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Event deleted'), backgroundColor: Color(0xFF757575)));
    }
  }

  Future<void> _deleteReminder(String id) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final cs = CalendarService(baseUrl: 'https://doxy-bh96.onrender.com/api', auth: auth);
    final ok = await cs.deleteReminder(id);
    if (ok) {
      await EnhancedNotificationService.cancelEventNotification(id);
      await _loadReminders();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reminder deleted'), backgroundColor: Color(0xFF757575)));
    }
  }

  Future<void> _createEventForSelected(Map<String, dynamic> eventData) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final cs = CalendarService(baseUrl: 'https://doxy-bh96.onrender.com/api', auth: auth);
    final selectedDate = _selected ?? DateTime.now();
    final startDate = DateTime.tryParse(eventData['startDate']) ?? selectedDate;
    final endDate = DateTime.tryParse(eventData['endDate']) ?? selectedDate;
    final startTime = DateTime(startDate.year, startDate.month, startDate.day,
        eventData['startHour'] ?? 0, eventData['startMinute'] ?? 0);
    final endTime = DateTime(endDate.year, endDate.month, endDate.day,
        eventData['endHour'] ?? 23, eventData['endMinute'] ?? 59);
    final reminderMinutes = eventData['reminderMinutes'] ?? 15;
    final reminderTime = startTime.subtract(Duration(minutes: reminderMinutes));
    final payload = {
      "title": eventData["title"],
      "description": eventData["description"] ?? "",
      "location": eventData["location"] ?? "",
      "start": startTime.toUtc().toIso8601String(),
      "end": endTime.toUtc().toIso8601String(),
      "startTime": startTime.toUtc().toIso8601String(),
      "endTime": endTime.toUtc().toIso8601String(),
      "isAllDay": false, "attendees": [], "colorId": "1",
      "reminders": {"useDefault": false, "overrides": [{"method": "popup", "minutes": reminderMinutes}]},
      "reminderPreferences": {
        "enabled": eventData["notificationEnabled"] ?? true,
        "minutesBefore": reminderMinutes,
        "type": eventData["reminderType"] ?? "event",
        "priority": eventData["reminderPriority"] ?? "medium",
        "notificationMethods": {"push": true, "voice": eventData["voiceEnabled"] ?? false, "email": false},
        "voiceSettings": {
          "enabled": eventData["voiceEnabled"] ?? false,
          "tone": eventData["voiceTone"] ?? "friendly",
          "language": eventData["voiceLanguage"] ?? "hi-IN",
          "customMessage": eventData["voiceCustomMessage"] ?? ""
        },
      }
    };
    final res = await cs.createEvent(payload);
    if (res['status'] == 201 || res['status'] == 200) {
      if (eventData['notificationEnabled'] == true && reminderTime.isAfter(DateTime.now())) {
        await EnhancedNotificationService.scheduleUltraHighPriorityNotification(
          title: eventData['title'],
          body: 'Your event starts in $reminderMinutes minutes',
          scheduledTime: reminderTime,
          eventId: res['body']['_id'] ?? DateTime.now().toString(),
        );
      }
      if (eventData['voiceEnabled'] == true) {
        await _speak('Event ${eventData['title']} created. It starts at ${DateFormat('hh:mm a').format(startTime)}');
      }
      await _loadEvents();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Event "${eventData['title']}" created'),
          backgroundColor: const Color(0xFF4CAF50)));
    }
  }

  Future<void> _createReminderForSelected(Map<String, dynamic> remData) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final cs = CalendarService(baseUrl: 'https://doxy-bh96.onrender.com/api', auth: auth);
    final selectedDate = _selected ?? DateTime.now();
    final remDate = DateTime.tryParse(remData['date']) ?? selectedDate;
    final scheduled = DateTime(remDate.year, remDate.month, remDate.day,
        remData['hour'] ?? 0, remData['minute'] ?? 0);
    final payload = {
      "title": remData["title"], "description": remData["description"] ?? "",
      "reminderTime": scheduled.toUtc().toIso8601String(),
      "type": "custom", "priority": "medium"
    };
    final res = await cs.createReminder(payload);
    if (res['status'] == 201 || res['status'] == 200) {
      final saved = res['body']['reminder'] ?? res['body'];
      final id = saved['_id'] ?? saved['id'];
      setState(() {
        _reminders.putIfAbsent(_dateOnly(scheduled), () => []).add({
          'id': id, 'title': payload['title'],
          'description': payload['description'], 'time': scheduled
        });
      });
      if ((remData['notificationEnabled'] ?? true) && scheduled.isAfter(DateTime.now())) {
        await EnhancedNotificationService.scheduleUltraHighPriorityNotification(
          title: payload['title'] as String,
          body: payload['description'] as String? ?? "",
          scheduledTime: scheduled, eventId: id,
        );
        await _speak('Reminder set. ${payload['title']} at ${DateFormat('hh:mm a').format(scheduled)}');
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reminder created'), backgroundColor: Color(0xFF4CAF50)));
    }
  }

  @override
  void dispose() { _tts.stop(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final selectedKey = _dateOnly(_selected ?? _focused);
    final eventsForSelected = _events[selectedKey] ?? [];
    final remindersForSelected = _reminders[selectedKey] ?? [];
    final habitsForSelected = _habitMarkers[selectedKey] ?? [];
    final routinesForSelected = _routineMarkers[selectedKey] ?? [];
    final hasAnything = eventsForSelected.isNotEmpty || remindersForSelected.isNotEmpty ||
        habitsForSelected.isNotEmpty || routinesForSelected.isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: const Color(0xFF111125),
        centerTitle: true, elevation: 0,
        actions: [
          if (_isSpeaking) IconButton(
              icon: const Icon(Icons.volume_off, color: Color(0xFF2979FF)),
              onPressed: () async { await _tts.stop(); setState(() => _isSpeaking = false); }),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.grey), onPressed: _loadAll),
        ],
      ),
      backgroundColor: const Color(0xFF07070F),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)))
          : Column(children: [
              Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFF111125),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E1E38))),
                child: TableCalendar(
                  focusedDay: _focused,
                  firstDay: DateTime.utc(2000, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (d) => _dateOnly(d) == _dateOnly(_selected ?? _focused),
                  onDaySelected: (selected, focused) => setState(() { _selected = selected; _focused = focused; }),
                  onFormatChanged: (f) => setState(() => _calendarFormat = f),
                  eventLoader: (day) => _getEventsForDay(day),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return null;
                      final hasHabit = (_habitMarkers[_dateOnly(day)] ?? []).isNotEmpty;
                      final hasRoutine = (_routineMarkers[_dateOnly(day)] ?? []).isNotEmpty;
                      final hasEvent = (_events[_dateOnly(day)] ?? []).isNotEmpty;
                      return Positioned(bottom: 1, child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (hasEvent) _dot(const Color(0xFF2979FF)),
                        if (hasHabit) _dot(Colors.orange),
                        if (hasRoutine) _dot(Colors.purple),
                      ]));
                    },
                  ),
                  calendarStyle: const CalendarStyle(
                    selectedDecoration: BoxDecoration(color: Color(0xFF2979FF), shape: BoxShape.circle),
                    todayDecoration: BoxDecoration(color: Color(0x442979FF), shape: BoxShape.circle),
                    weekendTextStyle: TextStyle(color: Colors.grey),
                    defaultTextStyle: TextStyle(color: Colors.white),
                    outsideTextStyle: TextStyle(color: Colors.grey),
                    markersMaxCount: 0,
                  ),
                  headerStyle: const HeaderStyle(
                    titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    formatButtonDecoration: BoxDecoration(color: Color(0xFF2979FF), borderRadius: BorderRadius.all(Radius.circular(12))),
                    formatButtonTextStyle: TextStyle(color: Colors.white),
                    leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFF2979FF)),
                    rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFF2979FF)),
                  ),
                ),
              ),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    _legendItem(const Color(0xFF2979FF), 'Events'),
                    const SizedBox(width: 12),
                    _legendItem(Colors.orange, 'Habits'),
                    const SizedBox(width: 12),
                    _legendItem(Colors.purple, 'Routines'),
                  ])),
              const SizedBox(height: 8),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Flexible(child: Text(DateFormat('dd MMM yyyy').format(_selected ?? _focused),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2979FF), foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      onPressed: () async {
                        final d = await _showCreateEventDialog();
                        if (d != null) await _createEventForSelected(d);
                      },
                      child: const Text('Add Event'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E38), foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      onPressed: () async {
                        final d = await _showCreateReminderDialog();
                        if (d != null) await _createReminderForSelected(d);
                      },
                      child: const Text('Add Reminder'),
                    ),
                  ])),
              const SizedBox(height: 8),
              Expanded(
                child: !hasAnything
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[700]),
                        const SizedBox(height: 16),
                        Text('Nothing scheduled', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Add events, reminders, habits or routines',
                            style: TextStyle(color: Colors.grey[700], fontSize: 13), textAlign: TextAlign.center),
                      ]))
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        children: [
                          if (eventsForSelected.isNotEmpty) ...[
                            _sectionHeader(Icons.event, 'Events', const Color(0xFF2979FF)),
                            const SizedBox(height: 8),
                            ...eventsForSelected.map((ev) {
                              final id = ev['id'] ?? '';
                              final title = ev['title'] ?? 'Untitled';
                              final start = ev['start'] as DateTime;
                              final end = ev['end'] as DateTime;
                              final desc = ev['description'] ?? '';
                              final loc = ev['location'] ?? '';
                              return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Slidable(
                                    key: ValueKey(id),
                                    endActionPane: ActionPane(motion: const ScrollMotion(), children: [
                                      SlidableAction(onPressed: (_) => _deleteEvent(id),
                                          backgroundColor: Colors.red[600]!, foregroundColor: Colors.white,
                                          icon: Icons.delete_outline, label: 'Delete',
                                          borderRadius: BorderRadius.circular(8)),
                                    ]),
                                    child: Container(
                                      decoration: BoxDecoration(
                                          gradient: const LinearGradient(colors: [Color(0xFF111125), Color(0xFF181830)]),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF1E1E38), width: 0.5)),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(14),
                                        leading: Container(width: 4, height: 50,
                                            decoration: BoxDecoration(color: const Color(0xFF2979FF), borderRadius: BorderRadius.circular(2))),
                                        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          const SizedBox(height: 4),
                                          Row(children: [
                                            const Icon(Icons.access_time, size: 13, color: Color(0xFF2979FF)),
                                            const SizedBox(width: 4),
                                            Text('${DateFormat('hh:mm a').format(start)} - ${DateFormat('hh:mm a').format(end)}',
                                                style: const TextStyle(color: Colors.grey, fontSize: 13))
                                          ]),
                                          if (loc.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Row(children: [
                                              const Icon(Icons.location_on, size: 13, color: Color(0xFF2979FF)),
                                              const SizedBox(width: 4),
                                              Expanded(child: Text(loc, style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                                  maxLines: 1, overflow: TextOverflow.ellipsis))
                                            ])
                                          ],
                                          if (desc.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(desc, style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                                maxLines: 2, overflow: TextOverflow.ellipsis)
                                          ],
                                        ]),
                                        trailing: IconButton(
                                            icon: Icon(_isSpeaking ? Icons.volume_off : Icons.volume_up,
                                                color: const Color(0xFF2979FF), size: 18),
                                            onPressed: () => _speak('Event $title from ${DateFormat('hh:mm a').format(start)} to ${DateFormat('hh:mm a').format(end)}. ${loc.isNotEmpty ? 'At $loc.' : ''} ${desc.isNotEmpty ? desc : ''}')),
                                      ),
                                    ),
                                  ));
                            }).toList(),
                          ],
                          if (remindersForSelected.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _sectionHeader(Icons.notifications, 'Reminders', Colors.amber),
                            const SizedBox(height: 8),
                            ...remindersForSelected.map((rem) {
                              final id = rem['id'] ?? '';
                              final title = rem['title'] ?? 'Reminder';
                              final time = rem['time'] as DateTime;
                              final desc = rem['description'] ?? '';
                              return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Slidable(
                                    key: ValueKey(id),
                                    endActionPane: ActionPane(motion: const ScrollMotion(), children: [
                                      SlidableAction(onPressed: (_) => _deleteReminder(id),
                                          backgroundColor: Colors.red, foregroundColor: Colors.white,
                                          icon: Icons.delete, label: 'Delete', borderRadius: BorderRadius.circular(8)),
                                    ]),
                                    child: Container(
                                      decoration: BoxDecoration(
                                          color: const Color(0xFF0D0D1A),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.amber.withOpacity(0.3))),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(14),
                                        leading: Container(width: 4, height: 50,
                                            decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(2))),
                                        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          const SizedBox(height: 4),
                                          Row(children: [
                                            const Icon(Icons.access_time, size: 13, color: Colors.amber),
                                            const SizedBox(width: 4),
                                            Text(DateFormat('hh:mm a').format(time), style: const TextStyle(color: Colors.grey, fontSize: 13))
                                          ]),
                                          if (desc.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(desc, style: TextStyle(color: Colors.grey[400], fontSize: 12))
                                          ],
                                        ]),
                                        trailing: IconButton(
                                            icon: Icon(_isSpeaking ? Icons.volume_off : Icons.volume_up,
                                                color: Colors.amber, size: 18),
                                            onPressed: () => _speak('Reminder: $title at ${DateFormat('hh:mm a').format(time)}. ${desc.isNotEmpty ? desc : ''}')),
                                      ),
                                    ),
                                  ));
                            }).toList(),
                          ],
                          if (habitsForSelected.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _sectionHeader(Icons.track_changes, 'Habits', Colors.orange),
                            const SizedBox(height: 8),
                            ...habitsForSelected.map((h) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF0D0D1A),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3))),
                                child: Row(children: [
                                  Container(width: 4, height: 50,
                                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(2))),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(h['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      const Icon(Icons.access_time, size: 13, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text(h['hasReminder'] == true
                                          ? DateFormat('hh:mm a').format(h['time'] as DateTime)
                                          : 'Anytime',
                                          style: TextStyle(
                                              color: h['hasReminder'] == true ? Colors.orange : Colors.grey[500],
                                              fontSize: 13)),
                                      if ((h['streak'] ?? 0) > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(6)),
                                            child: Text('${h['streak']} day streak',
                                                style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold))),
                                      ],
                                    ]),
                                  ])),
                                  IconButton(
                                      icon: Icon(_isSpeaking ? Icons.volume_off : Icons.volume_up,
                                          color: Colors.orange, size: 18),
                                      onPressed: () => _speak('Habit: ${(h['title'] ?? '')}. ${(h['streak'] ?? 0) > 0 ? 'Current streak ${h['streak']} days.' : ''}')),
                                ]),
                              ),
                            )).toList(),
                          ],
                          if (routinesForSelected.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _sectionHeader(Icons.auto_awesome, 'Routines', Colors.purple),
                            const SizedBox(height: 8),
                            ...routinesForSelected.map((r) {
                              final type = r['type'] as String? ?? '';
                              final isMorning = type == 'routine_morning';
                              final isActivity = type == 'routine_activity';
                              final color = isMorning ? Colors.orange : isActivity ? Colors.teal : Colors.purple;
                              final label = isMorning ? 'Morning' : isActivity ? 'Activity' : 'Evening';
                              final duration = r['duration'];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF0D0D1A),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: color.withOpacity(isActivity ? 0.2 : 0.35))),
                                  child: Row(children: [
                                    Container(width: 3, height: 42,
                                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                                    const SizedBox(width: 10),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(r['title'] ?? '', style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: isActivity ? FontWeight.normal : FontWeight.w600,
                                          fontSize: isActivity ? 12 : 14)),
                                      const SizedBox(height: 3),
                                      Row(children: [
                                        Icon(Icons.access_time, size: 11, color: color),
                                        const SizedBox(width: 3),
                                        Text(DateFormat('hh:mm a').format(r['time'] as DateTime),
                                            style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                                        if (duration != null) ...[
                                          const SizedBox(width: 6),
                                          Text('$duration min', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                                        ],
                                        const SizedBox(width: 6),
                                        Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                                color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                            child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold))),
                                      ]),
                                    ])),
                                    IconButton(
                                        icon: Icon(_isSpeaking ? Icons.volume_off : Icons.volume_up,
                                            color: color, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          final name = r['title']?.toString() ?? '';
                                          _speak('$label: $name at ${DateFormat('hh:mm a').format(r['time'] as DateTime)}${duration != null ? ". Duration $duration minutes" : ""}');
                                        }),
                                  ]),
                                ),
                              );
                            }).toList(),
                          ],
                        ],
                      ),
              ),
            ]),
    );
  }

  Widget _dot(Color color) => Container(
      width: 6, height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  Widget _legendItem(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11))
      ]);

  Widget _sectionHeader(IconData icon, String title, Color color) => Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
      ]);

  Future<Map<String, dynamic>?> _showCreateEventDialog() {
    final titleCtl = TextEditingController();
    final descCtl = TextEditingController();
    final locCtl = TextEditingController();
    final voiceMsgCtl = TextEditingController();
    final now = DateTime.now();
    final sel = _selected ?? now;
    String startDate = DateFormat('yyyy-MM-dd').format(sel);
    String endDate = DateFormat('yyyy-MM-dd').format(sel);
    int startHour = now.hour, startMinute = now.minute, endHour = now.hour + 1, endMinute = now.minute;
    bool notificationEnabled = true, voiceEnabled = false, pushEnabled = true, emailEnabled = false;
    int reminderMinutes = 15;
    String reminderType = 'event', reminderPriority = 'medium', voiceTone = 'friendly', voiceLanguage = 'hi-IN';

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
            backgroundColor: const Color(0xFF111125),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: EdgeInsets.fromLTRB(16, 24, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            title: const Row(children: [
              Icon(Icons.event_note, color: Color(0xFF2979FF)),
              SizedBox(width: 8),
              Text('Create New Event', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))
            ]),
            content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildSH('Event Details'),
              const SizedBox(height: 12),
              _df(titleCtl, 'Event Title *', Icons.title),
              const SizedBox(height: 10),
              _df(descCtl, 'Description', Icons.description, maxLines: 2),
              const SizedBox(height: 10),
              _df(locCtl, 'Location', Icons.location_on),
              const SizedBox(height: 16),
              _buildSH('Date & Time'),
              const SizedBox(height: 10),
              _dtp(label: 'Start Date', icon: Icons.calendar_today, value: startDate, onTap: () async {
                final p = await showDatePicker(context: ctx, initialDate: DateTime.parse(startDate),
                    firstDate: DateTime(2000), lastDate: DateTime(2100),
                    builder: (c, ch) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF2979FF))), child: ch!));
                if (p != null) ss(() => startDate = DateFormat('yyyy-MM-dd').format(p));
              }),
              const SizedBox(height: 10),
              _dtp(label: 'End Date', icon: Icons.event, value: endDate, onTap: () async {
                final p = await showDatePicker(context: ctx, initialDate: DateTime.parse(endDate),
                    firstDate: DateTime.parse(startDate), lastDate: DateTime(2100),
                    builder: (c, ch) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF2979FF))), child: ch!));
                if (p != null) ss(() => endDate = DateFormat('yyyy-MM-dd').format(p));
              }),
              const SizedBox(height: 10),
              _tr(ctx, 'Start Time', Icons.play_arrow, startHour, startMinute, (t) => ss(() { startHour = t.hour; startMinute = t.minute; })),
              const SizedBox(height: 10),
              _tr(ctx, 'End Time', Icons.stop, endHour, endMinute, (t) => ss(() { endHour = t.hour; endMinute = t.minute; })),
              const SizedBox(height: 16),
              _buildSH('Reminder Settings'),
              const SizedBox(height: 10),
              _dd(label: 'Reminder Type', value: reminderType,
                  items: {'event': 'Event', 'medication': 'Medication', 'task': 'Task', 'appointment': 'Appointment'},
                  onChanged: (v) => ss(() => reminderType = v!)),
              const SizedBox(height: 10),
              _dd(label: 'Priority', value: reminderPriority,
                  items: {'low': 'Low', 'medium': 'Medium', 'high': 'High', 'urgent': 'Urgent'},
                  onChanged: (v) => ss(() => reminderPriority = v!)),
              const SizedBox(height: 10),
              _dd(label: 'Remind me', value: reminderMinutes.toString(),
                  items: {'5': '5 min before', '10': '10 min before', '15': '15 min before', '30': '30 min before', '60': '1 hour before'},
                  onChanged: (v) => ss(() => reminderMinutes = int.parse(v!))),
              const SizedBox(height: 16),
              _buildSH('Notifications'),
              const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF181830), borderRadius: BorderRadius.circular(8)),
                  child: Column(children: [
                    _sw(title: 'Push', value: pushEnabled, onChanged: (v) => ss(() => pushEnabled = v)),
                    _sw(title: 'Voice', value: voiceEnabled, onChanged: (v) => ss(() => voiceEnabled = v)),
                    _sw(title: 'Email', value: emailEnabled, onChanged: (v) => ss(() => emailEnabled = v)),
                  ])),
              if (voiceEnabled) ...[
                const SizedBox(height: 16),
                _buildSH('Voice Settings'),
                const SizedBox(height: 10),
                _dd(label: 'Voice Tone', value: voiceTone,
                    items: {'friendly': 'Friendly', 'urgent': 'Urgent', 'calm': 'Calm'},
                    onChanged: (v) => ss(() => voiceTone = v!)),
                const SizedBox(height: 10),
                _dd(label: 'Language', value: voiceLanguage,
                    items: {'hi-IN': 'Hindi', 'en-US': 'English', 'en-IN': 'English (India)'},
                    onChanged: (v) => ss(() => voiceLanguage = v!)),
                const SizedBox(height: 10),
                _df(voiceMsgCtl, 'Custom Voice Message (optional)', Icons.mic),
              ],
              const SizedBox(height: 4),
            ]))),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2979FF), foregroundColor: Colors.white),
                onPressed: () {
                  if (titleCtl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter event title'), backgroundColor: Colors.red));
                    return;
                  }
                  Navigator.of(ctx).pop({
                    'title': titleCtl.text.trim(), 'description': descCtl.text.trim(),
                    'location': locCtl.text.trim(), 'startDate': startDate, 'endDate': endDate,
                    'startHour': startHour, 'startMinute': startMinute, 'endHour': endHour, 'endMinute': endMinute,
                    'notificationEnabled': notificationEnabled, 'reminderMinutes': reminderMinutes,
                    'reminderType': reminderType, 'reminderPriority': reminderPriority,
                    'pushEnabled': pushEnabled, 'voiceEnabled': voiceEnabled, 'emailEnabled': emailEnabled,
                    'voiceTone': voiceTone, 'voiceLanguage': voiceLanguage,
                    'voiceCustomMessage': voiceMsgCtl.text.trim(), 'tags': [reminderType, 'calendar']
                  });
                },
                child: const Text('Create Event'),
              ),
            ],
          )),
    );
  }

  Future<Map<String, dynamic>?> _showCreateReminderDialog() {
    final titleCtl = TextEditingController();
    final descCtl = TextEditingController();
    final now = DateTime.now();
    final sel = _selected ?? now;
    String dateStr = DateFormat('yyyy-MM-dd').format(sel);
    int hour = now.hour, minute = now.minute;
    bool notificationEnabled = true;
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
            backgroundColor: const Color(0xFF111125),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            insetPadding: EdgeInsets.fromLTRB(16, 24, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            title: const Row(children: [
              Icon(Icons.notifications, color: Color(0xFF2979FF)),
              SizedBox(width: 8),
              Text('Create Reminder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            ]),
            content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              _df(titleCtl, 'Title *', Icons.title),
              const SizedBox(height: 10),
              _df(descCtl, 'Description', Icons.description, maxLines: 2),
              const SizedBox(height: 10),
              _dtp(label: 'Date', icon: Icons.calendar_today, value: dateStr, onTap: () async {
                final p = await showDatePicker(context: ctx, initialDate: DateTime.parse(dateStr),
                    firstDate: DateTime(2000), lastDate: DateTime(2100),
                    builder: (c, ch) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF2979FF))), child: ch!));
                if (p != null) ss(() => dateStr = DateFormat('yyyy-MM-dd').format(p));
              }),
              const SizedBox(height: 10),
              _dtp(label: 'Time', icon: Icons.access_time,
                  value: '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay(hour: hour, minute: minute),
                        builder: (c, ch) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF2979FF))), child: ch!));
                    if (t != null) ss(() { hour = t.hour; minute = t.minute; });
                  }),
              const SizedBox(height: 10),
              Row(children: [
                const Expanded(child: Text('Send notification', style: TextStyle(color: Colors.white))),
                Switch(value: notificationEnabled, activeColor: const Color(0xFF2979FF),
                    onChanged: (v) => ss(() => notificationEnabled = v))
              ]),
              const SizedBox(height: 4),
            ]))),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2979FF)),
                onPressed: () {
                  if (titleCtl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter reminder title'), backgroundColor: Colors.red));
                    return;
                  }
                  Navigator.of(ctx).pop({'title': titleCtl.text.trim(), 'description': descCtl.text.trim(),
                      'date': dateStr, 'hour': hour, 'minute': minute, 'notificationEnabled': notificationEnabled});
                },
                child: const Text('Create Reminder'),
              ),
            ],
          )),
    );
  }

  Widget _df(TextEditingController ctl, String hint, IconData icon, {int maxLines = 1}) =>
      TextField(controller: ctl, maxLines: maxLines, style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
              labelText: hint, labelStyle: TextStyle(color: Colors.grey[400]),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[600]!), borderRadius: BorderRadius.circular(8)),
              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2979FF)), borderRadius: BorderRadius.all(Radius.circular(8))),
              prefixIcon: Icon(icon, color: Colors.grey[400])));

  Widget _tr(BuildContext ctx, String label, IconData icon, int h, int m, void Function(TimeOfDay) onPicked) =>
      Row(children: [
        Icon(icon, color: const Color(0xFF2979FF), size: 20),
        const SizedBox(width: 8),
        Text('$label:', style: TextStyle(color: Colors.grey[300])),
        const SizedBox(width: 12),
        Expanded(child: GestureDetector(
          onTap: () async {
            final t = await showTimePicker(context: ctx, initialTime: TimeOfDay(hour: h, minute: m),
                builder: (c, ch) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF2979FF))), child: ch!));
            if (t != null) onPicked(t);
          },
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF181830), borderRadius: BorderRadius.circular(8)),
              child: Text('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white, fontSize: 15))),
        )),
      ]);

  Widget _buildSH(String title) => Text(title,
      style: const TextStyle(color: Color(0xFF2979FF), fontWeight: FontWeight.w600, fontSize: 15));

  Widget _dtp({required String label, required IconData icon, required String value, required VoidCallback onTap}) =>
      GestureDetector(onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(color: const Color(0xFF181830), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[600]!)),
            child: Row(children: [
              Icon(icon, color: const Color(0xFF2979FF), size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(color: Colors.grey[300], fontSize: 13), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)),
              const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 20)
            ]),
          ));

  Widget _dd({required String label, required String value, required Map<String, String> items, required Function(String?) onChanged}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        const SizedBox(height: 6),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: const Color(0xFF181830), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[600]!)),
            child: DropdownButton<String>(
                value: value, isExpanded: true, dropdownColor: const Color(0xFF111125),
                underline: const SizedBox(), style: const TextStyle(color: Colors.white),
                items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: onChanged)),
      ]);

  Widget _sw({required String title, required bool value, required Function(bool) onChanged}) =>
      Row(children: [
        Expanded(child: Text(title, style: const TextStyle(color: Colors.white))),
        Switch(value: value, activeColor: const Color(0xFF2979FF), onChanged: (v) => onChanged(v))
      ]);
}
