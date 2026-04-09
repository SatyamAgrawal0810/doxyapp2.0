// lib/screens/main_wrapper.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'home_dashboard.dart';
import 'calendar_screen.dart';
import 'health_screen.dart';
import 'mood_screen.dart';
import 'routines_screen.dart';
import 'habits_screen.dart';
import 'suggestions_screen.dart';
import 'profile_screen.dart';
import 'chat/chat_screen.dart';
import 'login_page.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({Key? key}) : super(key: key);
  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _idx = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(
        onChatTap: () => setState(() => _idx = 3),
        onHealthTap: () => setState(() => _idx = 2),
      ),
      const EnhancedCalendarScreen(),
      const HealthScreen(),
      const ChatScreen(),
      const _MorePlaceholder(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _pages),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        border: Border(top: BorderSide(color: Color(0xFF1E1E1E))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  index: 0,
                  current: _idx,
                  onTap: () => setState(() => _idx = 0)),
              _NavItem(
                  icon: Icons.calendar_month_outlined,
                  activeIcon: Icons.calendar_month,
                  label: 'Calendar',
                  index: 1,
                  current: _idx,
                  onTap: () => setState(() => _idx = 1)),
              _NavItem(
                  icon: Icons.monitor_heart_outlined,
                  activeIcon: Icons.monitor_heart,
                  label: 'Health',
                  index: 2,
                  current: _idx,
                  onTap: () => setState(() => _idx = 2)),
              _NavItem(
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  label: 'Chat',
                  index: 3,
                  current: _idx,
                  onTap: () => setState(() => _idx = 3)),
              _NavItem(
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view,
                  label: 'More',
                  index: 4,
                  current: _idx,
                  onTap: () => _showMoreSheet(context)),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final auth = Provider.of<AuthService>(context, listen: false);
        final name = auth.userName ?? 'User';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      CircleAvatar(
                          backgroundColor: const Color(0xFFFF6A00),
                          radius: 22,
                          child: Text(initial,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              Text(auth.userEmail ?? '',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 12)),
                            ]),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          color: Colors.grey, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
                children: [
                  _MoreGridItem(
                      icon: '😊',
                      label: 'Mood',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const MoodScreen()));
                      }),
                  _MoreGridItem(
                      icon: '⚙️',
                      label: 'Routines',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RoutinesScreen()));
                      }),
                  _MoreGridItem(
                      icon: '👤',
                      label: 'Profile',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileScreen()));
                      }),
                  // ✅ Insights → Habits
                  _MoreGridItem(
                      icon: '🎯',
                      label: 'Habits',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HabitsScreen()));
                      }),
                  // ✅ Notifications → Suggestions
                  _MoreGridItem(
                      icon: '💡',
                      label: 'Suggestions',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SuggestionsScreen()));
                      }),
                  _MoreGridItem(
                      icon: '🚪',
                      label: 'Logout',
                      color: Colors.red.withOpacity(0.1),
                      onTap: () async {
                        Navigator.pop(context);
                        final auth =
                            Provider.of<AuthService>(context, listen: false);
                        await auth.logout();
                        if (context.mounted)
                          Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (_) => const LoginPage()),
                              (r) => false);
                      }),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final VoidCallback onTap;
  const _NavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      required this.index,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = current == index;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFFF6A00).withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(selected ? activeIcon : icon,
                  color: selected ? const Color(0xFFFF6A00) : Colors.grey[600],
                  size: 22),
            ),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    color:
                        selected ? const Color(0xFFFF6A00) : Colors.grey[600],
                    fontSize: 10,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class _MoreGridItem extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  final Color? color;
  const _MoreGridItem(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            color: color ?? const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _MorePlaceholder extends StatelessWidget {
  const _MorePlaceholder();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: Color(0xFF0A0A0A));
}
