import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../l10n.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../widgets/error_handler.dart';
import 'register_screen.dart';
import 'otp_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  bool _loading = false;
  bool _obs     = true;

  @override
  void dispose() { _email.dispose(); _pass.dispose(); super.dispose(); }

  Future<void> _login() async {
    final lang = context.read<AppState>().language;
    final t    = (String k) => L.t(k, lang);
    if (_email.text.isEmpty || _pass.text.isEmpty) {
      Err.show(context, t('fillFields')); return;
    }
    setState(() => _loading = true);
    try {
      final res = await ApiService.sendOtp(_email.text.trim(), _pass.text.trim());
      if (!mounted) return;
      // OTP معطل: الباكند يرجع token مباشرة
      if (res.containsKey('token')) {
        await ApiService.saveSession(
          res['token'], res['role'] ?? 'user',
          _email.text.trim(), res['region'] ?? 'SA');
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
      } else {
        // OTP مفعّل: اذهب لشاشة OTP
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OtpScreen(email: _email.text.trim())));
      }
    } catch (e) { if (mounted) Err.show(context, e); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    final t    = (String k) => L.t(k, lang);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 60),
            // Logo
            Center(child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF000000), Color(0xFF333333)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 38),
            )),
            const SizedBox(height: 20),
            Center(child: Text(t('appName'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700))),
            Center(child: Text(t('tagline'),
              style: TextStyle(fontSize: 13,
                color: dark ? Colors.white54 : const Color(0xFF6B7280)),
              textAlign: TextAlign.center)),
            const SizedBox(height: 48),

            // Email
            Text(t('email'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'you@example.com',
                prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 18),

            // Password
            Text(t('password'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _pass,
              obscureText: _obs,
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obs ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  onPressed: () => setState(() => _obs = !_obs),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Login button
            _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : ElevatedButton.icon(
                  onPressed: _login,
                  icon: const Icon(Icons.login_rounded, size: 20),
                  label: Text(t('loginBtn')),
                ),
            const SizedBox(height: 20),

            // Register link
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(L.isRTL(lang) ? 'ليس لديك حساب؟' : "Don't have an account?",
                style: TextStyle(fontSize: 13,
                  color: dark ? Colors.white54 : const Color(0xFF6B7280))),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: Text(t('register'),
                  style: const TextStyle(fontSize: 13, color: AppTheme.primary,
                    fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}
