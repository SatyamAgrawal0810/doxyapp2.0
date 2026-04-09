import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/enhanced_notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _voiceNotifications = true;
  bool _pushNotifications = true;
  bool _criticalAlerts = true;
  bool _medicationReminders = true;
  bool _eventReminders = true;
  bool _taskReminders = true;

  String _voiceTone = 'friendly';
  String _language = 'hi-IN';

  double _voiceVolume = 0.8;
  double _voiceSpeed = 0.5;

  bool _quietHoursEnabled = true;
  int _quietHoursStart = 22;
  int _quietHoursEnd = 7;

  bool _aiVoiceEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _voiceNotifications = prefs.getBool('voice_notifications') ?? true;
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
      _criticalAlerts = prefs.getBool('critical_alerts') ?? true;

      _medicationReminders = prefs.getBool('medication_reminders') ?? true;
      _eventReminders = prefs.getBool('event_reminders') ?? true;
      _taskReminders = prefs.getBool('task_reminders') ?? true;

      _voiceTone = prefs.getString('voice_tone') ?? 'friendly';
      _language = prefs.getString('language') ?? 'hi-IN';

      _voiceVolume = prefs.getDouble('voice_volume') ?? 0.8;
      _voiceSpeed = prefs.getDouble('voice_speed') ?? 0.5;

      _quietHoursStart = prefs.getInt('quiet_hours_start') ?? 22;
      _quietHoursEnd = prefs.getInt('quiet_hours_end') ?? 7;
      _quietHoursEnabled = prefs.getBool('quiet_hours_enabled') ?? true;

      _aiVoiceEnabled = prefs.getBool('ai_voice_enabled') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('voice_notifications', _voiceNotifications);
    await prefs.setBool('push_notifications', _pushNotifications);
    await prefs.setBool('critical_alerts', _criticalAlerts);

    await prefs.setBool('medication_reminders', _medicationReminders);
    await prefs.setBool('event_reminders', _eventReminders);
    await prefs.setBool('task_reminders', _taskReminders);

    await prefs.setString('voice_tone', _voiceTone);
    await prefs.setString('language', _language);

    await prefs.setDouble('voice_volume', _voiceVolume);
    await prefs.setDouble('voice_speed', _voiceSpeed);

    await prefs.setBool('quiet_hours_enabled', _quietHoursEnabled);
    await prefs.setInt('quiet_hours_start', _quietHoursStart);
    await prefs.setInt('quiet_hours_end', _quietHoursEnd);

    await prefs.setBool('ai_voice_enabled', _aiVoiceEnabled);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Settings Saved'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("🔔 Notification Settings"),
        backgroundColor: Colors.black,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildSection(
            title: "📱 General",
            children: [
              _toggle(
                title: "Push Notifications",
                subtitle: "Enable all push alerts",
                value: _pushNotifications,
                icon: Icons.notifications,
                onChanged: (v) {
                  setState(() => _pushNotifications = v);
                  _saveSettings();
                },
              ),
              _toggle(
                title: "Critical Alerts",
                subtitle: "High-priority alerts",
                value: _criticalAlerts,
                icon: Icons.warning,
                iconColor: Colors.red,
                onChanged: (v) {
                  setState(() => _criticalAlerts = v);
                  _saveSettings();
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildSection(
            title: "🎤 Voice",
            children: [
              _toggle(
                title: "Voice Notifications",
                subtitle: "Enable voice announcements",
                value: _voiceNotifications,
                icon: Icons.record_voice_over,
                iconColor: Colors.orange,
                onChanged: (v) {
                  setState(() => _voiceNotifications = v);
                  _saveSettings();
                },
              ),
              if (_voiceNotifications)
                Column(
                  children: [
                    _toggle(
                      title: "AI Voice",
                      subtitle: "Use AI generated speech",
                      value: _aiVoiceEnabled,
                      icon: Icons.psychology,
                      iconColor: Colors.purple,
                      onChanged: (v) {
                        setState(() => _aiVoiceEnabled = v);
                        _saveSettings();
                      },
                    ),
                    _dropdown(
                      title: "Voice Tone",
                      value: _voiceTone,
                      items: {
                        "friendly": "😊 Friendly",
                        "urgent": "⚡ Urgent",
                        "calm": "😌 Calm",
                        "energetic": "🚀 Energetic"
                      },
                      onChanged: (v) {
                        setState(() => _voiceTone = v!);
                        _saveSettings();
                      },
                    ),
                    _dropdown(
                      title: "Language",
                      value: _language,
                      items: {
                        "hi-IN": "🇮🇳 Hindi",
                        "en-US": "🇺🇸 English",
                      },
                      onChanged: (v) {
                        setState(() => _language = v!);
                        _saveSettings();
                      },
                    ),
                    _slider(
                      title: "Voice Volume",
                      value: _voiceVolume,
                      min: 0,
                      max: 1,
                      onChanged: (v) {
                        setState(() => _voiceVolume = v);
                        _saveSettings();
                      },
                    ),
                    _slider(
                      title: "Voice Speed",
                      value: _voiceSpeed,
                      min: 0.1,
                      max: 1,
                      onChanged: (v) {
                        setState(() => _voiceSpeed = v);
                        _saveSettings();
                      },
                    ),
                  ],
                )
            ],
          ),
          SizedBox(height: 16),
          _buildSection(
            title: "⏰ Reminder Types",
            children: [
              _toggle(
                title: "Medication Reminders",
                subtitle: "Pill notifications",
                value: _medicationReminders,
                icon: Icons.medication,
                onChanged: (v) {
                  setState(() => _medicationReminders = v);
                  _saveSettings();
                },
              ),
              _toggle(
                title: "Event Reminders",
                subtitle: "Appointments, meetings",
                value: _eventReminders,
                icon: Icons.event,
                onChanged: (v) {
                  setState(() => _eventReminders = v);
                  _saveSettings();
                },
              ),
              _toggle(
                title: "Task Reminders",
                subtitle: "Daily tasks, to-do alerts",
                value: _taskReminders,
                icon: Icons.check_circle,
                onChanged: (v) {
                  setState(() => _taskReminders = v);
                  _saveSettings();
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildSection(
            title: "🧪 Test Notifications",
            children: [
              ElevatedButton.icon(
                onPressed: _testVoice,
                icon: Icon(Icons.record_voice_over),
                label: Text("Test Voice"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
              SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _testPush,
                icon: Icon(Icons.notifications),
                label: Text("Test Push"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
              ),
              SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _testCritical,
                icon: Icon(Icons.warning),
                label: Text("Test Critical"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
              ),
            ],
          ),
          SizedBox(height: 32),
        ],
      ),
    );
  }

  // ===================== UI HELPERS ======================
  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      color: Colors.black,
      elevation: 0.5,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                )),
            SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _toggle({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required Function(bool) onChanged,
    Color iconColor = Colors.grey,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey)),
      trailing: Switch(
        value: value,
        activeColor: Colors.orange,
        onChanged: onChanged,
      ),
    );
  }

  Widget _dropdown({
    required String title,
    required String value,
    required Map<String, String> items,
    required Function(String?) onChanged,
  }) {
    return ListTile(
      title: Text(title, style: TextStyle(color: Colors.white)),
      trailing: DropdownButton<String>(
        value: value,
        dropdownColor: Colors.black,
        items: items.entries
            .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, style: TextStyle(color: Colors.white)),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _slider({
    required String title,
    required double value,
    required double min,
    required double max,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: Colors.orange,
          inactiveColor: Colors.grey,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ===================== TEST FUNCTIONS ======================
  Future<void> _testVoice() async {
    await EnhancedNotificationService.showAIVoiceNotification(
      title: "टेस्ट वॉयस",
      body: "यह आपकी वॉयस नोटिफिकेशन का टेस्ट है।",
    );
  }

  Future<void> _testPush() async {
    await EnhancedNotificationService.showInstantNotification(
      title: "Test Push",
      body: "This is a test push notification.",
    );
  }

  Future<void> _testCritical() async {
    await EnhancedNotificationService.showAIVoiceNotification(
      title: "Critical Alert",
      body: "यह एक महत्वपूर्ण चेतावनी है।",
    );
  }
}
