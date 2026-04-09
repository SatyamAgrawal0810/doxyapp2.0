
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/health_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _baseUrl = 'https://doxy-bh96.onrender.com/api/auth';
  bool _loading = true, _saving = false;
  Map<String, dynamic> _userData = {}, _manualData = {};
  final _nameCtl     = TextEditingController();
  final _stepGoalCtl = TextEditingController();
  final _sleepGoalCtl= TextEditingController();
  String _selectedLanguage = 'en';
  bool _notificationsEnabled = true, _voiceEnabled = true;
  String _voiceTone = 'friendly';

  @override
  void initState() { super.initState(); _loadProfile(); _loadManualData(); }

  Future<void> _loadManualData() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final data = await HealthService(auth: auth).getManualData();
    if (mounted) setState(() => _manualData = data);
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final res = await http.get(Uri.parse('$_baseUrl/me'),
          headers: {'Authorization': 'Bearer ${auth.token}', 'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final user = data['user'] as Map<String, dynamic>;
          setState(() {
            _userData       = user;
            _nameCtl.text   = user['name'] ?? '';
            _stepGoalCtl.text  = (user['healthGoals']?['dailySteps'] ?? 10000).toString();
            _sleepGoalCtl.text = (user['healthGoals']?['sleepHours'] ?? 8).toString();
            final lang = user['preferences']?['language'] ?? 'en';
            const validLangs = ['en','hi','es','fr','de'];
            _selectedLanguage      = validLangs.contains(lang) ? lang : 'en';
            _notificationsEnabled  = user['preferences']?['notifications'] ?? true;
            _voiceEnabled          = user['preferences']?['voiceEnabled'] ?? true;
            _voiceTone             = user['preferences']?['voiceTone'] ?? 'friendly';
          });
        }
      }
    } catch (e) { debugPrint('Profile load: $e'); }
    setState(() => _loading = false);
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      await http.put(Uri.parse('$_baseUrl/update'),
          headers: {'Authorization': 'Bearer ${auth.token}', 'Content-Type': 'application/json'},
          body: jsonEncode({'name': _nameCtl.text.trim()})).timeout(const Duration(seconds: 10));
      final res = await http.put(Uri.parse('$_baseUrl/preferences'),
          headers: {'Authorization': 'Bearer ${auth.token}', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'language': _selectedLanguage, 'notifications': _notificationsEnabled,
            'voiceEnabled': _voiceEnabled, 'voiceTone': _voiceTone,
            'dailySteps': int.tryParse(_stepGoalCtl.text) ?? 10000,
            'sleepHours': double.tryParse(_sleepGoalCtl.text) ?? 8.0,
          })).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && mounted) {
        await auth.refreshProfile();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile updated'), backgroundColor: Color(0xFF00C853)));
        await _loadProfile();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'), backgroundColor: Colors.red[900]));
    }
    setState(() => _saving = false);
  }

  @override
  void dispose() { _nameCtl.dispose(); _stepGoalCtl.dispose(); _sleepGoalCtl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [TextButton(
          onPressed: _saving ? null : _saveProfile,
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Color(0xFF2979FF), strokeWidth: 2))
              : const Text('Save', style: TextStyle(
                  color: Color(0xFF2979FF), fontWeight: FontWeight.bold, fontSize: 15)),
        )],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2979FF)))
          : ListView(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), children: [
              _buildAvatarSection(),
              const SizedBox(height: 28),
              _buildSection('Personal', [_inputTile(label: 'Full Name', controller: _nameCtl, icon: Icons.person_outline)]),
              const SizedBox(height: 20),
              _buildSection('Health Goals', [
                _inputTile(label: 'Daily Steps Goal', controller: _stepGoalCtl,
                    icon: Icons.directions_walk, keyboardType: TextInputType.number),
                _inputTile(label: 'Sleep Goal (hours)', controller: _sleepGoalCtl,
                    icon: Icons.nightlight_round,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ]),
              const SizedBox(height: 20),
              _buildSection('Preferences', [
                _dropdownTile<String>(label: 'Language', icon: Icons.language,
                    value: _selectedLanguage,
                    items: const {'en':'English','hi':'Hindi','es':'Spanish','fr':'French','de':'German'},
                    onChanged: (v) => setState(() => _selectedLanguage = v!)),
                _dropdownTile<String>(label: 'Voice Tone', icon: Icons.record_voice_over_outlined,
                    value: _voiceTone,
                    items: const {'friendly':'Friendly','professional':'Professional','calm':'Calm','energetic':'Energetic'},
                    onChanged: (v) => setState(() => _voiceTone = v!)),
                _switchTile(label: 'Push Notifications', icon: Icons.notifications_outlined,
                    value: _notificationsEnabled, onChanged: (v) => setState(() => _notificationsEnabled = v)),
                _switchTile(label: 'Voice Responses', icon: Icons.volume_up_outlined,
                    value: _voiceEnabled, onChanged: (v) => setState(() => _voiceEnabled = v)),
              ]),
              if (_manualData.isNotEmpty) ...[
                const SizedBox(height: 20), _buildManualHealthSection()],
              const SizedBox(height: 20),
              _buildAccountInfo(),
            ]),
    );
  }

  Widget _buildManualHealthSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text("Today's Manual Entries",
        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
    const SizedBox(height: 10),
    Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1E), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2979FF).withOpacity(0.15))),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.edit_note, color: Color(0xFF2979FF), size: 16),
          const SizedBox(width: 6),
          const Text('Manually entered today', style: TextStyle(color: Color(0xFF8A8AAD), fontSize: 12))]),
        const SizedBox(height: 10),
        if (_manualData['heartRate'] != null) _manualRow('Heart Rate', '${_manualData['heartRate']} bpm', Colors.pinkAccent),
        if (_manualData['sleepHours'] != null) _manualRow('Sleep', '${_manualData['sleepHours']} hours', Colors.purpleAccent),
        if (_manualData['weight'] != null) _manualRow('Weight', '${_manualData['weight']} kg', Colors.lightBlueAccent),
        const SizedBox(height: 8),
        const Text('Go to Health tab to update these values',
            style: TextStyle(color: Color(0xFF4A4A6A), fontSize: 11)),
      ])),
  ]);

  Widget _manualRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      const Spacer(),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.25))),
        child: Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold))),
    ]));

  Widget _buildAvatarSection() {
    final name     = _userData['name'] as String? ?? '';
    final email    = _userData['email'] as String? ?? '';
    final initial  = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final provider = _userData['authProvider'] ?? 'manual';
    return Center(child: Column(children: [
      Stack(children: [
        Container(width: 90, height: 90,
          decoration: const BoxDecoration(shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF2979FF)])),
          child: Center(child: Text(initial, style: const TextStyle(
              color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)))),
        if (provider == 'google')
          Positioned(right: 0, bottom: 0,
              child: Container(width: 26, height: 26,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: const Center(child: Text('G', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4285F4)))))),
      ]),
      const SizedBox(height: 12),
      Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(email, style: const TextStyle(color: Color(0xFF8A8AAD), fontSize: 13)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: provider == 'google'
              ? Colors.blue.withOpacity(0.12)
              : const Color(0xFF2979FF).withOpacity(0.12),
          borderRadius: BorderRadius.circular(20)),
        child: Text(provider == 'google' ? 'Google Account' : 'Email Account',
            style: TextStyle(
                color: provider == 'google' ? Colors.blue[300] : const Color(0xFF82B1FF),
                fontSize: 11, fontWeight: FontWeight.w600))),
    ]));
  }

  Widget _buildSection(String title, List<Widget> children) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Container(decoration: BoxDecoration(
          color: const Color(0xFF0F0F1E), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E1E38))),
          child: Column(children: children)),
    ]);

  Widget _inputTile({required String label, required TextEditingController controller,
      required IconData icon, TextInputType? keyboardType}) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF2979FF), size: 20),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: controller, keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(labelText: label,
              labelStyle: const TextStyle(color: Color(0xFF8A8AAD), fontSize: 12),
              border: InputBorder.none))),
      ]));

  Widget _dropdownTile<T>({required String label, required IconData icon, required T value,
      required Map<T,String> items, required void Function(T?) onChanged}) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF2979FF), size: 20),
        const SizedBox(width: 12),
        Expanded(child: DropdownButtonFormField<T>(value: value,
          dropdownColor: const Color(0xFF141428),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(labelText: label,
              labelStyle: const TextStyle(color: Color(0xFF8A8AAD), fontSize: 12),
              border: InputBorder.none),
          items: items.entries.map((e) =>
              DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: onChanged)),
      ]));

  Widget _switchTile({required String label, required IconData icon, required bool value,
      required void Function(bool) onChanged}) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF2979FF), size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14))),
        Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF2979FF)),
      ]));

  Widget _buildAccountInfo() {
    final joined = _userData['createdAt'] as String?;
    String joinedStr = '--';
    if (joined != null) { try { final dt = DateTime.parse(joined); joinedStr = '${dt.day}/${dt.month}/${dt.year}'; } catch (_) {} }
    final id = _userData['_id'] as String? ?? '';
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF0F0F1E), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E1E38))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Account Info', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _infoRow('Member since', joinedStr),
        _infoRow('User ID', id.length > 8 ? '${id.substring(0,8)}...' : id),
      ]));
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Color(0xFF8A8AAD), fontSize: 13)),
      Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13)),
    ]));
}
