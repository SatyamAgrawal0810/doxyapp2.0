// lib/screens/suggestions_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/suggestions_service.dart';
import 'habits_screen.dart';
import 'routines_screen.dart';
import 'health_screen.dart';
import 'calendar_screen.dart';
import 'mood_screen.dart';
import 'chat/chat_screen.dart';

class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({Key? key}) : super(key: key);
  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  late SuggestionsService _service;
  List<Suggestion> _suggestions = [];
  bool _loading = true;
  final Set<String> _dismissedLocally = {};

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _service = SuggestionsService(auth: auth);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.getAllSuggestions();
    if (mounted)
      setState(() {
        _suggestions = list;
        _loading = false;
      });
  }

  String _localKey(Suggestion s) =>
      '${s.type}_${s.data['habitId'] ?? s.data['routineId'] ?? ''}';

  Future<void> _dismiss(Suggestion s) async {
    setState(() => _dismissedLocally.add(_localKey(s)));
    await _service.dismissSuggestion(s.type,
        habitId: s.data['habitId'] as String?,
        routineId: s.data['routineId'] as String?);
  }

  Future<void> _action(Suggestion s) async {
    await _service.logAction(s.type, extraData: s.data);
    _navigateToRoute(s.action?.route ?? '');
  }

  void _navigateToRoute(String route) {
    Widget? screen;

    if (route.startsWith('/habits'))
      screen = const HabitsScreen();
    else if (route.startsWith('/routines'))
      screen = const RoutinesScreen();
    else if (route == '/health')
      screen = const HealthScreen();
    else if (route == '/calendar')
      screen = const EnhancedCalendarScreen();
    else if (route == '/mood')
      screen = const MoodScreen();
    else if (route == '/chat' || route == '/dashboard')
      screen = const ChatScreen();
    else if (route == '/analytics')
      screen = const HealthScreen(); // fallback to health

    if (screen != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ Action recorded'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _suggestions
        .where((s) => !_dismissedLocally.contains(_localKey(s)))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: Column(children: [
          const Text("Doxy's Suggestions",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          if (!_loading && visible.isNotEmpty)
            Text('${visible.length} for you today',
                style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ]),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            onPressed: () {
              _dismissedLocally.clear();
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6A00)))
          : visible.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFFFF6A00),
                  child: _buildList(visible),
                ),
    );
  }

  Widget _buildList(List<Suggestion> suggestions) {
    final urgent = suggestions.where((s) => s.priority >= 9).toList();
    final high =
        suggestions.where((s) => s.priority >= 7 && s.priority < 9).toList();
    final normal = suggestions.where((s) => s.priority < 7).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      children: [
        if (urgent.isNotEmpty) ...[
          _sectionLabel('🚨 Urgent', Colors.redAccent),
          const SizedBox(height: 8),
          ...urgent.map((s) => _SuggestionCard(
              suggestion: s,
              onDismiss: () => _dismiss(s),
              onAction: () => _action(s))),
          const SizedBox(height: 16),
        ],
        if (high.isNotEmpty) ...[
          _sectionLabel('⚡ Needs Attention', Colors.orangeAccent),
          const SizedBox(height: 8),
          ...high.map((s) => _SuggestionCard(
              suggestion: s,
              onDismiss: () => _dismiss(s),
              onAction: () => _action(s))),
          const SizedBox(height: 16),
        ],
        if (normal.isNotEmpty) ...[
          _sectionLabel('💡 Suggestions for You', Colors.white70),
          const SizedBox(height: 8),
          ...normal.map((s) => _SuggestionCard(
              suggestion: s,
              onDismiss: () => _dismiss(s),
              onAction: () => _action(s))),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _buildEmpty() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎉', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 14),
          const Text("You're all caught up!",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Doxy has no new suggestions right now.',
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Color(0xFFFF6A00)),
            label: const Text('Refresh',
                style: TextStyle(color: Color(0xFFFF6A00))),
          ),
        ]),
      );
}

// ── Suggestion Card ───────────────────────────────────────────────────────────
class _SuggestionCard extends StatelessWidget {
  final Suggestion suggestion;
  final VoidCallback onDismiss;
  final VoidCallback onAction;

  const _SuggestionCard({
    required this.suggestion,
    required this.onDismiss,
    required this.onAction,
  });

  Color get _borderColor {
    if (suggestion.priority >= 9) return Colors.redAccent.withOpacity(0.5);
    if (suggestion.priority >= 7)
      return const Color(0xFFFF6A00).withOpacity(0.5);
    if (suggestion.priority >= 5) return Colors.amber.withOpacity(0.3);
    return Colors.white.withOpacity(0.06);
  }

  Color get _bgColor {
    if (suggestion.priority >= 9) return Colors.red.withOpacity(0.05);
    if (suggestion.priority >= 7)
      return const Color(0xFFFF6A00).withOpacity(0.05);
    return const Color(0xFF161616);
  }

  String get _categoryTag {
    switch (suggestion.category) {
      case SuggestionCategory.habit:
        return '🎯 Habit';
      case SuggestionCategory.routine:
        return '📅 Routine';
      case SuggestionCategory.health:
        return '💚 Health';
      case SuggestionCategory.wellness:
        return '😴 Wellness';
      case SuggestionCategory.fitness:
        return '🏃 Fitness';
      case SuggestionCategory.productivity:
        return '⚡ Productivity';
      case SuggestionCategory.planning:
        return '📋 Planning';
      case SuggestionCategory.motivation:
        return '🌟 Motivation';
      case SuggestionCategory.opportunity:
        return '⏱️ Opportunity';
      case SuggestionCategory.feature:
        return '✨ Feature';
      case SuggestionCategory.growth:
        return '🌱 Growth';
      default:
        return '💡 Tip';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(
          '${suggestion.type}_${suggestion.data['habitId'] ?? suggestion.data['routineId'] ?? DateTime.now().millisecondsSinceEpoch}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: Colors.red[900], borderRadius: BorderRadius.circular(14)),
        child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline, color: Colors.white),
              Text('Dismiss',
                  style: TextStyle(color: Colors.white, fontSize: 11)),
            ]),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor, width: 1.2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _borderColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                  child: Text(suggestion.emoji,
                      style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(suggestion.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_categoryTag,
                        style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                            fontWeight: FontWeight.w500)),
                  ),
                ])),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, color: Colors.grey[600], size: 18),
            ),
          ]),

          const SizedBox(height: 10),
          Text(suggestion.message,
              style: TextStyle(
                  color: Colors.grey[300], fontSize: 13.5, height: 1.4)),

          // Data badges
          if (_hasDataBadges()) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: _buildDataBadges()),
          ],

          // Action button
          if (suggestion.action != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Spacer(),
              GestureDetector(
                onTap: onDismiss,
                child: Text('Dismiss',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(_getActionIcon(suggestion.action!.route),
                    size: 14, color: Colors.white),
                label: Text(suggestion.action!.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: suggestion.priority >= 9
                      ? Colors.redAccent
                      : suggestion.priority >= 7
                          ? const Color(0xFFFF6A00)
                          : const Color(0xFF2A2A2A),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  IconData _getActionIcon(String route) {
    if (route.startsWith('/habits')) return Icons.track_changes;
    if (route.startsWith('/routines')) return Icons.auto_awesome;
    if (route == '/health') return Icons.monitor_heart;
    if (route == '/calendar') return Icons.calendar_month;
    if (route == '/mood') return Icons.mood;
    if (route == '/chat') return Icons.chat_bubble;
    return Icons.arrow_forward;
  }

  bool _hasDataBadges() {
    final d = suggestion.data;
    return d['currentStreak'] != null ||
        d['avgSteps'] != null ||
        d['avgSleep'] != null ||
        d['minutesUntil'] != null ||
        d['duration'] != null ||
        d['habitName'] != null ||
        d['routineName'] != null ||
        d['eventsCount'] != null;
  }

  List<Widget> _buildDataBadges() {
    final d = suggestion.data;
    final badges = <Widget>[];

    void badge(String label, Color color, IconData icon) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ));
    }

    if (d['currentStreak'] != null)
      badge('${d['currentStreak']} day streak', Colors.orange,
          Icons.local_fire_department);
    if (d['habitName'] != null)
      badge(d['habitName'].toString(), Colors.lightBlue, Icons.track_changes);
    if (d['routineName'] != null)
      badge(d['routineName'].toString(), Colors.purple, Icons.auto_awesome);
    if (d['avgSteps'] != null)
      badge('${d['avgSteps']} avg steps', Colors.lightBlue,
          Icons.directions_walk);
    if (d['avgSleep'] != null)
      badge(
          '${d['avgSleep']}h avg sleep', Colors.purple, Icons.nightlight_round);
    if (d['minutesUntil'] != null)
      badge(
          'in ${d['minutesUntil']} min', const Color(0xFFFF6A00), Icons.timer);
    if (d['duration'] != null)
      badge('${d['duration']} min free', Colors.green, Icons.free_breakfast);
    if (d['eventsCount'] != null)
      badge('${d['eventsCount']} events', Colors.blue, Icons.calendar_month);

    return badges;
  }
}
