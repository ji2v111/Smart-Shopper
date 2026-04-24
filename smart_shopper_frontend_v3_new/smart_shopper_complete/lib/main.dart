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

class _Splash extends StatefulWidget {
  const _Splash();
  @override State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _navigate();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1500));
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
      backgroundColor: AppTheme.primary,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.shopping_bag_outlined,
                color: Colors.white, size: 56),
            ),
            const SizedBox(height: 24),
            const Text('Smart Shopper',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              )),
            const SizedBox(height: 8),
            const Text('اكتشف سعر أي منتج بالتصوير',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              )),
            const SizedBox(height: 60),
            const SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5)),
          ]),
        ),
      ),
    );
  }
}
