import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'main_wrapper.dart';

class SplashScreen extends StatefulWidget {
  final bool? userHasToken; // ← NEW FIX

  const SplashScreen({Key? key, this.userHasToken}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startSequence();
  }

  Future<void> _startSequence() async {
    final auth = Provider.of<AuthService>(context, listen: false);

    await Future.delayed(const Duration(milliseconds: 1000));

    // 1️⃣ If main.dart already gave us token state → USE IT
    bool hasToken = widget.userHasToken ?? false;

    // 2️⃣ Double confirm by checking secure storage
    if (!hasToken) {
      hasToken = await auth.hasToken();
    }

    print("🔑 SplashScreen hasToken = $hasToken");

    if (hasToken) {
      print("📡 Sync FCM token before navigating");
      await auth.sendDeviceTokenToServer();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainWrapper()),
        );
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6A00),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 64,
                    height: 64,
                    errorBuilder: (_, __, ___) => const Text(
                      'D',
                      style: TextStyle(
                        fontSize: 48,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'DOXY',
                style: TextStyle(
                  color: Color(0xFFFF6A00),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your Health, Simplified',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                color: Color(0xFFFF6A00),
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
