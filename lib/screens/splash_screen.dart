import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'main_wrapper.dart';

class SplashScreen extends StatefulWidget {
  final bool? userHasToken;
  const SplashScreen({Key? key, this.userHasToken}) : super(key: key);
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _scaleAnim = Tween(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    _startSequence();
  }

  Future<void> _startSequence() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    await Future.delayed(const Duration(milliseconds: 1800));
    bool hasToken = widget.userHasToken ?? false;
    if (!hasToken) hasToken = await auth.hasToken();
    if (hasToken) await auth.sendDeviceTokenToServer();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
                hasToken ? const MainWrapper() : const LoginPage()),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070F),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1565C0), Color(0xFF2979FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF2979FF).withOpacity(0.45),
                        blurRadius: 36,
                        spreadRadius: 4),
                  ],
                ),
                child: Center(
                  child: Image.asset('assets/images/logo.png',
                      width: 66,
                      height: 66,
                      errorBuilder: (_, __, ___) => const Text('D',
                          style: TextStyle(
                              fontSize: 52,
                              color: Colors.white,
                              fontWeight: FontWeight.bold))),
                ),
              ),
              const SizedBox(height: 28),
              const Text('DOXY',
                  style: TextStyle(
                      color: Color(0xFF2979FF),
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6)),
              const SizedBox(height: 8),
              Text('Your Health, Simplified',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14)),
              const SizedBox(height: 52),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    color: Color(0xFF2979FF), strokeWidth: 2),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
