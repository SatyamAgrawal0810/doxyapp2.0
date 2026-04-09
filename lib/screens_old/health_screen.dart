// lib/screens/health_screen.dart
// ✅ Steps ONLY from _liveSteps (pedometer) — never overwritten by autoRefresh
// ✅ autoRefresh merges only HC fields (HR, sleep, calories, weight)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/health_service.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({Key? key}) : super(key: key);
  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  late final HealthService _service;

  bool _loading = true;
  bool _syncing = false;
  bool _connected = false;
  bool _showConnectBanner = false;
  String? _errorMsg;

  Map<String, dynamic> _today = {};
  Map<String, dynamic> _insights = {};

  // ✅ _liveSteps is the ONLY source of truth for steps
  int _liveSteps = 0;

  StreamSubscription<int>? _stepSub;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _service = HealthService(auth: auth);
    _init();
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _service.stopAutoRefresh();
    _service.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);

    await _service.startAppTimer();
    await _service.startLiveStepTracking();

    // ✅ Step listener — fires on EVERY step, updates _liveSteps immediately
    _stepSub?.cancel();
    _stepSub = _service.liveStepStream.listen((steps) {
      if (!mounted) return;
      setState(() => _liveSteps = steps);
    });

    final hasPerm = await _service.hasPermissions();
    final hasAsked = await _service.hasAskedPermission();
    setState(() {
      _connected = hasPerm;
      _showConnectBanner = !hasAsked;
    });

    await _loadData();

    // ✅ autoRefresh only provides HC data (no steps) — safely merge
    _service.startAutoRefresh((hcData) {
      if (!mounted) return;
      setState(() {
        // Merge HC fields only — steps stays as _liveSteps
        _today = {
          ..._today,
          ...hcData, // heartRate, sleep, calories, weight
          // steps is NOT in hcData, so _liveSteps is never touched here
        };
      });
    });

    setState(() => _loading = false);
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    final result = await _service.requestPermissions();
    switch (result) {
      case HealthPermissionResult.granted:
        setState(() {
          _connected = true;
          _showConnectBanner = false;
        });
        await _loadData();
        break;
      case HealthPermissionResult.notInstalled:
        setState(() => _errorMsg = 'Health Connect required. Installing...');
        await _service.installHealthConnect();
        break;
      case HealthPermissionResult.denied:
        setState(() {
          _showConnectBanner = false;
          _errorMsg =
              'Permission denied.\nOpen Health Connect → App permissions → Doxys → Allow all.';
        });
        break;
      case HealthPermissionResult.error:
        setState(() => _errorMsg = 'Something went wrong. Try again.');
        break;
    }
    setState(() => _loading = false);
  }

  Future<void> _loadData() async {
    try {
      final hc = await _service.readHCDataOnly();
      final insights = await _service.getInsights();
      if (!mounted) return;
      setState(() {
        // ✅ Merge HC data but keep steps as _liveSteps
        _today = {
          ..._today,
          ...hc,
          // steps intentionally NOT set from HC
        };
        _insights = insights;
        _errorMsg = null;
      });
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Failed to load health data.');
    }
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final ok = await _service.syncToBackend();
    setState(() => _syncing = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '✅ Synced with Doxy' : '⚠️ Sync failed'),
      backgroundColor: ok ? Colors.green[800] : Colors.red[800],
    ));
    if (ok) _loadData();
  }

  Future<void> _showManualDialog(String type) async {
    final ctl = TextEditingController();
    String title = '', hint = '', unit = '';
    switch (type) {
      case 'heartRate':
        title = 'Heart Rate';
        hint = '72';
        unit = 'bpm';
        break;
      case 'sleep':
        title = 'Sleep';
        hint = '7.5';
        unit = 'hours';
        break;
      case 'weight':
        title = 'Weight';
        hint = '70.0';
        unit = 'kg';
        break;
    }
    final val = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Enter $title',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600]),
            suffixText: unit,
            suffixStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: const Color(0xFF252525),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6A00)),
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (val == null || val.isEmpty || !mounted) return;
    final num = double.tryParse(val);
    if (num == null) return;
    switch (type) {
      case 'heartRate':
        await _service.saveManualData(heartRate: num.toInt());
        break;
      case 'sleep':
        await _service.saveManualData(sleepHours: num);
        break;
      case 'weight':
        await _service.saveManualData(weight: num);
        break;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ $title saved: $val $unit'),
        backgroundColor: Colors.green[800],
      ));
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Health Data',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (!_syncing)
            IconButton(
                icon: const Icon(Icons.sync, color: Color(0xFFFF6A00)),
                onPressed: _sync)
          else
            const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Color(0xFFFF6A00), strokeWidth: 2))),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6A00)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFFFF6A00),
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  _buildLiveStepBanner(),
                  const SizedBox(height: 16),
                  if (_showConnectBanner) ...[
                    _buildConnectBanner(),
                    const SizedBox(height: 16)
                  ],
                  if (_errorMsg != null) ...[
                    _buildError(),
                    const SizedBox(height: 8)
                  ],
                  _buildTodayGrid(),
                  const SizedBox(height: 16),
                  _buildManualEntry(),
                  const SizedBox(height: 24),
                  if ((_insights['weekly'] as Map?)?.isNotEmpty == true) ...[
                    _buildInsightsSection(),
                    const SizedBox(height: 24),
                    _buildRecommendations(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildLiveStepBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF6A00).withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.directions_walk, color: Color(0xFFFF6A00), size: 30),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Live Steps',
              style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          // ✅ Always _liveSteps — updates on every step
          Text('$_liveSteps',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold)),
        ]),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _LiveDot(),
          const SizedBox(height: 4),
          Text(_service.formatAppTime(),
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          Text('app time',
              style: TextStyle(color: Colors.grey[700], fontSize: 9)),
        ]),
      ]),
    );
  }

  Widget _buildConnectBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(children: [
        const Icon(Icons.health_and_safety, size: 40, color: Color(0xFFFF6A00)),
        const SizedBox(height: 10),
        const Text('Connect Health Connect',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
            'Sync Heart Rate, Sleep & Calories.\nSteps tracked live automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(
            onPressed: () => setState(() => _showConnectBanner = false),
            child: const Text('Skip', style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _connect,
            icon: const Icon(Icons.link),
            label: const Text('Connect Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6A00),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withOpacity(0.4))),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
        const SizedBox(width: 10),
        Expanded(
            child: Text(_errorMsg!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
        GestureDetector(
            onTap: () => setState(() => _errorMsg = null),
            child: const Icon(Icons.close, color: Colors.grey, size: 16)),
      ]),
    );
  }

  Widget _buildTodayGrid() {
    final metrics = [
      // ✅ Steps always from _liveSteps — never from _today map
      _MetricData('Steps', '$_liveSteps', Icons.directions_walk,
          Colors.orangeAccent, '/ 10k goal'),
      _MetricData(
          'Heart Rate',
          _today['heartRate'] != null && _today['heartRate'] != 0
              ? '${_today['heartRate']} bpm'
              : '--',
          Icons.favorite,
          Colors.pinkAccent,
          'avg today'),
      _MetricData('Sleep', _today['sleep'] ?? '--', Icons.nightlight_round,
          Colors.purpleAccent, 'last night'),
      _MetricData(
          'Calories',
          _today['calories'] != null && _today['calories'] != 0
              ? '${_today['calories']} kcal'
              : '--',
          Icons.local_fire_department,
          Colors.redAccent,
          'burned'),
      _MetricData('App Time', _service.formatAppTime(), Icons.timer_outlined,
          Colors.greenAccent, 'in app today'),
      _MetricData(
          'Weight',
          _today['weight'] != null && _today['weight'] != '--'
              ? '${_today['weight']} kg'
              : '--',
          Icons.monitor_weight_outlined,
          Colors.lightBlueAccent,
          'latest'),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("Today's Health",
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        Row(children: [
          Icon(Icons.circle,
              color: _connected ? Colors.greenAccent : Colors.grey, size: 8),
          const SizedBox(width: 4),
          Text(_connected ? 'HC Connected' : 'Sensor only',
              style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          if (!_connected && !_showConnectBanner) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _connect,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF6A00).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('Connect',
                    style: TextStyle(
                        color: Color(0xFFFF6A00),
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ]),
      ]),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35),
        itemCount: metrics.length,
        itemBuilder: (_, i) => _MetricCard(data: metrics[i]),
      ),
    ]);
  }

  Widget _buildManualEntry() {
    final hr = _today['heartRate'];
    final sleepMin = _today['sleepMinutes'];
    final weight = _today['weight'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.edit_note, color: Color(0xFFFF6A00), size: 20),
          const SizedBox(width: 8),
          const Text('Manual Entry',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('Tap to enter if -- shown',
              style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: _manualBtn(
                  Icons.favorite,
                  'Heart Rate',
                  Colors.pinkAccent,
                  hr != null && hr != 0 ? '$hr bpm' : '--',
                  () => _showManualDialog('heartRate'))),
          const SizedBox(width: 8),
          Expanded(
              child: _manualBtn(
                  Icons.nightlight_round,
                  'Sleep',
                  Colors.purpleAccent,
                  sleepMin != null && sleepMin != 0
                      ? '${(sleepMin / 60).toStringAsFixed(1)}h'
                      : '--',
                  () => _showManualDialog('sleep'))),
          const SizedBox(width: 8),
          Expanded(
              child: _manualBtn(
                  Icons.monitor_weight_outlined,
                  'Weight',
                  Colors.lightBlueAccent,
                  weight != null && weight != '--' ? '$weight kg' : '--',
                  () => _showManualDialog('weight'))),
        ]),
        const SizedBox(height: 8),
        Text('💡 Weight is remembered until you update it',
            style: TextStyle(color: Colors.grey[700], fontSize: 10)),
      ]),
    );
  }

  Widget _manualBtn(IconData icon, String label, Color color, String current,
      VoidCallback onTap) {
    final isEmpty = current == '--';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isEmpty ? const Color(0xFF1E1E1E) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isEmpty
                  ? Colors.grey.withOpacity(0.2)
                  : color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: isEmpty ? Colors.grey : color, size: 18),
          const SizedBox(height: 4),
          Text(current,
              style: TextStyle(
                  color: isEmpty ? Colors.grey : color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 9),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4)),
            child: Text('✏️ edit',
                style: TextStyle(
                    color: color, fontSize: 8, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  Widget _buildInsightsSection() {
    final weekly = _insights['weekly'] as Map? ?? {};
    final trends = _insights['trends'] as Map? ?? {};
    if (weekly.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Weekly Insights',
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      _InsightRow(
          label: 'Avg Steps',
          value: '${weekly['avgSteps'] ?? '--'}',
          trend: trends['steps']),
      _InsightRow(
          label: 'Avg Sleep',
          value: '${weekly['avgSleepHours'] ?? '--'} hrs',
          trend: trends['sleep']),
      _InsightRow(
          label: 'Active Mins',
          value: '${weekly['avgActiveMinutes'] ?? '--'} min',
          trend: trends['activity']),
    ]);
  }

  Widget _buildRecommendations() {
    final recs = (_insights['recommendations'] as List?)?.cast<Map>() ?? [];
    if (recs.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Doxy's Recommendations",
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      ...recs.take(3).map((r) => _RecommendationCard(rec: r)),
    ]);
  }
}

// ── Live Dot ───────────────────────────────────────────────────────────────────

class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20)),
          child: const Row(children: [
            Icon(Icons.circle, color: Colors.greenAccent, size: 7),
            SizedBox(width: 3),
            Text('LIVE',
                style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
      );
}

// ── Widgets ────────────────────────────────────────────────────────────────────

class _MetricData {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  _MetricData(this.label, this.value, this.icon, this.color, this.sub);
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;
  const _MetricCard({required this.data});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(data.icon, color: data.color, size: 18),
            const SizedBox(width: 6),
            Expanded(
                child: Text(data.label,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    overflow: TextOverflow.ellipsis)),
          ]),
          const Spacer(),
          Text(data.value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Text(data.sub,
              style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        ]),
      );
}

class _InsightRow extends StatelessWidget {
  final String label, value;
  final String? trend;
  const _InsightRow({required this.label, required this.value, this.trend});
  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.remove;
    Color color = Colors.grey;
    if (trend == 'improving') {
      icon = Icons.trending_up;
      color = Colors.greenAccent;
    }
    if (trend == 'declining') {
      icon = Icons.trending_down;
      color = Colors.redAccent;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 14))),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        const SizedBox(width: 8),
        Icon(icon, color: color, size: 18),
      ]),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final Map rec;
  const _RecommendationCard({required this.rec});
  @override
  Widget build(BuildContext context) {
    final priority = rec['priority'] ?? 'low';
    final color = priority == 'high'
        ? Colors.redAccent
        : priority == 'medium'
            ? Colors.orangeAccent
            : Colors.greenAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6)),
          child: Text(priority.toUpperCase(),
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Text(rec['message'] ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
        if (rec['action'] != null) ...[
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lightbulb_outline, color: Colors.amber[300], size: 14),
            const SizedBox(width: 4),
            Expanded(
                child: Text(rec['action'],
                    style: TextStyle(color: Colors.amber[200], fontSize: 12))),
          ]),
        ],
      ]),
    );
  }
}
