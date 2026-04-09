// lib/screens/mood_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/proactive_service.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({Key? key}) : super(key: key);
  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  static const String _baseUrl = 'https://doxy-bh96.onrender.com/api';

  int _selectedMood = -1;
  final _noteCtl = TextEditingController();
  bool _submitting = false;
  bool _todayLogged = false;

  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;
  String _aiSuggestion = '';

  static const List<_MoodOption> _moods = [
    _MoodOption('😔', 'Low', Color(0xFF4A90E2), 0),
    _MoodOption('😐', 'Meh', Color(0xFF9B9B9B), 1),
    _MoodOption('🙂', 'Okay', Color(0xFFFFD700), 2),
    _MoodOption('😊', 'Good', Color(0xFF7ED321), 3),
    _MoodOption('🤩', 'Great', Color(0xFFFF6A00), 4),
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/mood/history?days=14'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json'
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final entries =
            (body['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final today = DateTime.now();
        final todayStr =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        final alreadyLogged = entries
            .any((e) => (e['date'] as String? ?? '').startsWith(todayStr));
        setState(() {
          _history = entries;
          _todayLogged = alreadyLogged;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Mood history error: $e');
    }
    setState(() => _loadingHistory = false);
  }

  Future<void> _submitMood() async {
    if (_selectedMood < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a mood first 😊')));
      return;
    }
    setState(() => _submitting = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final moodLabel = _moods[_selectedMood].label.toLowerCase();
      final res = await http
          .post(
            Uri.parse('$_baseUrl/mood/log'),
            headers: {
              'Authorization': 'Bearer ${auth.token}',
              'Content-Type': 'application/json'
            },
            body: jsonEncode({
              'mood': moodLabel,
              'score': _selectedMood,
              'note': _noteCtl.text.trim(),
              'timestamp': DateTime.now().toIso8601String()
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final proactive = ProactiveService(auth: auth);
        final suggestion = await proactive.getMoodSuggestion(moodLabel);
        setState(() {
          _todayLogged = true;
          _aiSuggestion = suggestion;
        });
        _noteCtl.clear();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Mood logged!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2)));
        await _loadHistory();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: $e'), backgroundColor: Colors.red[900]));
    }
    setState(() => _submitting = false);
  }

  @override
  void dispose() {
    _noteCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Mood Tracker',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        color: const Color(0xFFFF6A00),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            _buildTodayCard(),
            const SizedBox(height: 20),
            if (_aiSuggestion.isNotEmpty) _buildSuggestionCard(),
            if (_aiSuggestion.isNotEmpty) const SizedBox(height: 20),
            _buildWeeklyChart(),
            const SizedBox(height: 20),
            _buildHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('How are you feeling?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          if (_todayLogged)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('Logged today ✓',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
            ),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
                _moods.length,
                (i) => SizedBox(
                      width: constraints.maxWidth / _moods.length - 4,
                      child: _MoodEmoji(
                        option: _moods[i],
                        selected: _selectedMood == i,
                        onTap: () => setState(() => _selectedMood = i),
                      ),
                    )),
          );
        }),
        if (!_todayLogged) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtl,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "Add a note (optional)... what's on your mind?",
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitMood,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedMood >= 0
                    ? _moods[_selectedMood].color
                    : Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      _selectedMood >= 0
                          ? 'Log ${_moods[_selectedMood].emoji} Mood'
                          : 'Select a mood',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildSuggestionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFFFF6A00).withOpacity(0.12),
          const Color(0xFFFF6A00).withOpacity(0.04)
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF6A00).withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🤖', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Doxy's Response",
              style: TextStyle(
                  color: Color(0xFFFF8C42),
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_aiSuggestion,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ])),
      ]),
    );
  }

  Widget _buildWeeklyChart() {
    final last7 = _history.take(7).toList().reversed.toList();
    if (last7.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('This Week',
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      SizedBox(
        // Fixed height — no overflow
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: last7.map((entry) {
            final score = (entry['score'] as num? ?? 0).toInt().clamp(0, 4);
            // Max bar height = 72px (leaving room for emoji 16px + label 18px + gaps)
            final barHeight = 14.0 + score * 14.0; // 14 to 70
            final color = _moods[score].color;
            final date = entry['date'] as String? ?? '';
            final day = date.length >= 10
                ? _dayLabel(date.substring(8, 10), date.substring(5, 7))
                : '?';

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_moods[score].emoji,
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 3),
                    Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(day,
                        style: TextStyle(color: Colors.grey[500], fontSize: 9),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  String _dayLabel(String day, String month) {
    final now = DateTime.now();
    final dt = DateTime(now.year, int.parse(month), int.parse(day));
    final diff = now.difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yest.';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }

  Widget _buildHistory() {
    if (_loadingHistory)
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6A00)));
    if (_history.isEmpty)
      return Center(
          child: Text('No mood logs yet — start tracking! 😊',
              style: TextStyle(color: Colors.grey[600])));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Recent Logs',
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      ..._history.take(10).map((e) => _MoodHistoryTile(entry: e)),
    ]);
  }
}

class _MoodOption {
  final String emoji, label;
  final Color color;
  final int score;
  const _MoodOption(this.emoji, this.label, this.color, this.score);
}

class _MoodEmoji extends StatelessWidget {
  final _MoodOption option;
  final bool selected;
  final VoidCallback onTap;
  const _MoodEmoji(
      {required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? option.color.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
              color: selected ? option.color : Colors.transparent, width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(option.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 3),
          Text(option.label,
              style: TextStyle(
                  color: selected ? option.color : Colors.grey[600],
                  fontSize: 9,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}

class _MoodHistoryTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _MoodHistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final score = (entry['score'] as num? ?? 0).toInt().clamp(0, 4);
    const moods = ['😔', '😐', '🙂', '😊', '🤩'];
    const moodNames = ['Low', 'Meh', 'Okay', 'Good', 'Great'];
    const colors = [
      Color(0xFF4A90E2),
      Color(0xFF9B9B9B),
      Color(0xFFFFD700),
      Color(0xFF7ED321),
      Color(0xFFFF6A00)
    ];
    final date = entry['date'] as String? ?? '';
    final dateStr = date.length >= 10
        ? '${date.substring(8, 10)}/${date.substring(5, 7)}'
        : '--';
    final note = entry['note'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(children: [
        Text(moods[score], style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(moodNames[score],
              style: TextStyle(
                  color: colors[score],
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          if (note.isNotEmpty)
            Text(note,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
        ])),
        Text(dateStr, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ]),
    );
  }
}
