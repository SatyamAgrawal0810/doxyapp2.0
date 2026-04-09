// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/health_service.dart';
import '../services/suggestions_service.dart';
import 'suggestions_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onChatTap;
  final VoidCallback? onHealthTap;
  const HomeScreen({Key? key, this.onChatTap, this.onHealthTap})
      : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _breathController;
  late Animation<double> _breathAnim;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late Animation<double> _pulseOpacity;

  String _greeting = '';
  Suggestion? _topSuggestion;
  Map<String, dynamic> _healthSummary = {};
  bool _loading = true;

  // Today's mood emoji — loaded from SharedPreferences
  // Default: 😊 (happy)
  String _moodEmoji = '😊';

  @override
  void initState() {
    super.initState();
    _breathController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
        CurvedAnimation(parent: _breathController, curve: Curves.easeInOut));
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.35).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _setGreeting();
    _loadMoodEmoji();
    _loadData();
  }

  void _setGreeting() {
    final h = DateTime.now().hour;
    if (h < 12)
      _greeting = 'Good Morning ☀️';
    else if (h < 17)
      _greeting = 'Good Afternoon 👋';
    else if (h < 21)
      _greeting = 'Good Evening 🌆';
    else
      _greeting = 'Good Night 🌙';
  }

  Future<void> _loadMoodEmoji() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayKey = '${today.year}_${today.month}_${today.day}';
      final savedDate = prefs.getString('mood_date') ?? '';
      final savedEmoji = prefs.getString('mood_emoji') ?? '😊';
      // Use today's mood if saved today, else default happy
      if (savedDate == todayKey) {
        setState(() => _moodEmoji = savedEmoji);
      } else {
        setState(() => _moodEmoji = '😊');
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);

    final healthService = HealthService(auth: auth);
    await healthService.startLiveStepTracking();
    await Future.delayed(const Duration(milliseconds: 600));

    final results = await Future.wait([
      healthService.getTodaySummary().catchError((_) => <String, dynamic>{}),
      SuggestionsService(auth: auth).getTopSuggestion().catchError((_) => null),
    ]);

    healthService.stopLiveStepTracking();
    // Reload mood after data load too
    await _loadMoodEmoji();

    if (mounted) {
      setState(() {
        _healthSummary = results[0] as Map<String, dynamic>? ?? {};
        _topSuggestion = results[1] as Suggestion?;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final name = auth.userName ?? 'there';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFFFF6A00),
          backgroundColor: const Color(0xFF1A1A1A),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              _buildHeader(name),
              const SizedBox(height: 32),
              _buildAvatar(),
              const SizedBox(height: 32),
              if (_topSuggestion != null) _buildSuggestionCard(),
              const SizedBox(height: 20),
              _buildQuickStats(),
              const SizedBox(height: 20),
              _buildQuickActions(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_greeting,
              style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          const SizedBox(height: 2),
          Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
        ]),
        // Show today's mood emoji — tappable
        GestureDetector(
          onTap: _loadMoodEmoji,
          child: Column(children: [
            Text(_moodEmoji, style: const TextStyle(fontSize: 28)),
            Text(DateFormat('EEE, MMM d').format(DateTime.now()),
                style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ]),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    return Center(
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Opacity(
                opacity: _pulseOpacity.value,
                child: Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFFFF6A00), width: 2),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: 154,
              height: 154,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFFF6A00).withOpacity(0.15),
                  Colors.transparent
                ]),
              ),
            ),
            AnimatedBuilder(
              animation: _breathController,
              builder: (_, child) =>
                  Transform.scale(scale: _breathAnim.value, child: child),
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF8C42), Color(0xFFFF4500)],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFFF6A00).withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 4)
                  ],
                ),
                child: const _DoxyFace(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard() {
    final s = _topSuggestion!;
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SuggestionsScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFFFF6A00).withOpacity(0.15),
            const Color(0xFFFF6A00).withOpacity(0.05)
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF6A00).withOpacity(0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(s.title,
                    style: const TextStyle(
                        color: Color(0xFFFF8C42),
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(s.message,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
              ])),
          const Icon(Icons.arrow_forward_ios,
              color: Color(0xFFFF6A00), size: 14),
        ]),
      ),
    );
  }

  Widget _buildQuickStats() {
    final steps = _healthSummary['steps'] ?? '--';
    final sleep = _healthSummary['sleep'] ?? '--';
    final calories = _healthSummary['calories'] ?? '--';
    final heart = _healthSummary['heartRate'];
    final heartStr = (heart == null || heart == 0) ? '--' : '$heart bpm';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Today's Overview",
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _StatTile(
                icon: Icons.directions_walk,
                label: 'Steps',
                value: steps.toString(),
                color: Colors.orangeAccent)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatTile(
                icon: Icons.nightlight_round,
                label: 'Sleep',
                value: sleep.toString(),
                color: Colors.purpleAccent)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: _StatTile(
                icon: Icons.local_fire_department,
                label: 'Calories',
                value: calories.toString(),
                color: Colors.redAccent)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatTile(
                icon: Icons.favorite,
                label: 'Heart',
                value: heartStr,
                color: Colors.pinkAccent)),
      ]),
    ]);
  }

  Widget _buildQuickActions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Quick Actions',
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _ActionButton(
                icon: Icons.mic,
                label: 'Talk to Doxy',
                color: const Color(0xFFFF6A00),
                onTap: widget.onChatTap)),
        const SizedBox(width: 12),
        Expanded(
            child: _ActionButton(
                icon: Icons.monitor_heart_outlined,
                label: 'Health Data',
                color: Colors.teal,
                onTap: widget.onHealthTap)),
      ]),
    ]);
  }
}

class _DoxyFace extends StatelessWidget {
  const _DoxyFace();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _FacePainter(), child: const SizedBox.expand());
}

class _FacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final eyePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx - 20, cy - 12), 10, eyePaint);
    canvas.drawCircle(Offset(cx + 20, cy - 12), 10, eyePaint);
    final pupilPaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawCircle(Offset(cx - 18, cy - 10), 5, pupilPaint);
    canvas.drawCircle(Offset(cx + 22, cy - 10), 5, pupilPaint);
    final smilePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(cx - 22, cy + 14)
          ..quadraticBezierTo(cx, cy + 32, cx + 22, cy + 14),
        smilePaint);
    final blushPaint = Paint()..color = Colors.white.withOpacity(0.25);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - 34, cy + 14), width: 22, height: 12),
        blushPaint);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + 34, cy + 14), width: 22, height: 12),
        blushPaint);
  }

  @override
  bool shouldRepaint(_FacePainter _) => false;
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ])),
        ]),
      );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3))),
          child: Column(children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
