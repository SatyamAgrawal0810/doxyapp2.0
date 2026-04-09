
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'main_wrapper.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameCtl  = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passCtl  = TextEditingController();
  bool _isLoading = false;
  bool _isObscure = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.isAuthenticated) {
      Future.microtask(() => Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const MainWrapper()), (r) => false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF07070F),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(child: Column(children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF2979FF)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: Text('D', style: TextStyle(
                        fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(height: 20),
                const Text('DOXY', style: TextStyle(
                    fontSize: 28, color: Color(0xFF2979FF),
                    fontWeight: FontWeight.w700, letterSpacing: 5)),
                const SizedBox(height: 6),
                const Text('Create your account',
                    style: TextStyle(color: Color(0xFF8A8AAD), fontSize: 14)),
              ])),
              const SizedBox(height: 40),
              _inputField(icon: Icons.person_outline, controller: _nameCtl, hint: 'Full Name'),
              const SizedBox(height: 14),
              _inputField(icon: Icons.email_outlined, controller: _emailCtl,
                  hint: 'Email address', keyboard: TextInputType.emailAddress),
              const SizedBox(height: 14),
              _inputField(
                icon: Icons.lock_outline, controller: _passCtl, hint: 'Password',
                obscure: _isObscure,
                suffix: IconButton(
                  icon: Icon(
                    _isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: const Color(0xFF8A8AAD), size: 20),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2979FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : () async {
                  final name  = _nameCtl.text.trim();
                  final email = _emailCtl.text.trim();
                  final pass  = _passCtl.text.trim();
                  if (name.isEmpty || email.isEmpty || pass.isEmpty) {
                    _snack(context, 'Please fill all fields'); return;
                  }
                  setState(() => _isLoading = true);
                  final res = await auth.signup(name, email, pass);
                  setState(() => _isLoading = false);
                  if (res['ok'] == true && mounted) {
                    Navigator.pushAndRemoveUntil(context,
                        MaterialPageRoute(builder: (_) => const MainWrapper()), (r) => false);
                  } else { _snack(context, res['message']); }
                },
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Create Account',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 28),
              Row(children: const [
                Expanded(child: Divider(color: Color(0xFF1E1E38))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text('OR', style: TextStyle(color: Color(0xFF4A4A6A), fontSize: 12))),
                Expanded(child: Divider(color: Color(0xFF1E1E38))),
              ]),
              const SizedBox(height: 20),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF1E1E38)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  _snack(context, 'Opening Google login...');
                  await auth.loginWithGoogle();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/icons/google.png', width: 20,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.g_mobiledata, color: Colors.white, size: 22)),
                    const SizedBox(width: 10),
                    const Text('Continue with Google',
                        style: TextStyle(fontSize: 15, color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Already have an account? ',
                    style: TextStyle(color: Color(0xFF8A8AAD))),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Text('Sign in',
                      style: TextStyle(
                          color: Color(0xFF2979FF), fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: const Color(0xFF111125),
          behavior: SnackBarBehavior.floating,
          content: Text(msg, style: const TextStyle(color: Colors.white))));

  Widget _inputField({
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    Widget? suffix,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF111125),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E1E38)),
      ),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF8A8AAD), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF4A4A6A)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (suffix != null) suffix,
      ]),
    );
  }
}
