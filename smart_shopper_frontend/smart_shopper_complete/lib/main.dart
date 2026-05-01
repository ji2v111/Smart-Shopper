import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';
import 'theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const SmartShopperApp());
}

class SmartShopperApp extends StatelessWidget {
  const SmartShopperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..load(),
      child: Consumer<AppState>(
        builder: (_, state, __) => MaterialApp(
          title: 'Smart Shopper',
          debugShowCheckedModeBanner: false,
          themeMode: state.themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          locale: Locale(state.language),
          home: const _Splash(),
        ),
      ),
    );
  }
}

// ─────────────────── Splash Screen ───────────────────────

class _Splash extends StatefulWidget {
  const _Splash();
  @override State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _navigate();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    final loggedIn = await ApiService.isLoggedIn();

    if (!mounted) return;
    Widget next;
    if (!onboardingDone) {
      next = const OnboardingScreen();
    } else if (loggedIn) {
      next = const HomeScreen();
    } else {
      next = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              // ── App Logo ────────────────────────────────
              const AppLogo(size: 110),
              const SizedBox(height: 28),
              const Text('Smart Shopper',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                )),
              const SizedBox(height: 8),
              const Text('Snap. Identify. Know the Price.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  letterSpacing: 0.2,
                )),
              const SizedBox(height: 72),
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white70, strokeWidth: 2)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────── App Logo Widget ─────────────────────
//
// Displays the real app logo from assets/logo.png.
// Shown on: splash screen and app icon (configured in pubspec.yaml).
// The white background is clipped to a rounded square to match icon shape.

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
