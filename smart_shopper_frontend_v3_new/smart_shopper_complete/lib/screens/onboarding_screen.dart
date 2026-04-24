import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n.dart';
import '../theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page   = 0;
  final _lang = 'ar'; // default

  final _pages = [
    _OBPage(
      icon: Icons.shopping_bag_outlined,
      iconColor: Color(0xFF6C63FF),
      bgColor: Color(0xFFEEECFF),
      titleKey: 'onb1Title',
      bodyKey: 'onb1Body',
    ),
    _OBPage(
      icon: Icons.add_photo_alternate_rounded,
      iconColor: Color(0xFF22C55E),
      bgColor: Color(0xFFE1F5EE),
      titleKey: 'onb2Title',
      bodyKey: 'onb2Body',
    ),
    _OBPage(
      icon: Icons.price_check_rounded,
      iconColor: Color(0xFFF59E0B),
      bgColor: Color(0xFFFAEEDA),
      titleKey: 'onb3Title',
      bodyKey: 'onb3Body',
    ),
  ];

  Future<void> _done() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final t = (String k) => L.t(k, _lang);
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // Skip
          Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: _done,
              child: Text(t('onbSkip'),
                style: const TextStyle(color: AppTheme.primary)),
            ),
          ),

          // Pages
          Expanded(
            child: PageView.builder(
              controller: _ctrl,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _pages.length,
              itemBuilder: (_, i) => _pages[i].build(context, _lang),
            ),
          ),

          // Dots + button
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(children: [
              // Dots
              Row(children: List.generate(_pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 6),
                width: i == _page ? 20 : 8, height: 8,
                decoration: BoxDecoration(
                  color: i == _page
                      ? AppTheme.primary
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4)),
              ))),
              const Spacer(),
              // Next / Start
              ElevatedButton(
                onPressed: isLast
                    ? _done
                    : () => _ctrl.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(120, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isLast ? t('onbStart') : t('onbNext')),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _OBPage {
  final IconData icon;
  final Color iconColor, bgColor;
  final String titleKey, bodyKey;
  const _OBPage({required this.icon, required this.iconColor,
    required this.bgColor, required this.titleKey, required this.bodyKey});

  Widget build(BuildContext context, String lang) {
    final t = (String k) => L.t(k, lang);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(36)),
          child: Icon(icon, color: iconColor, size: 60),
        ),
        const SizedBox(height: 40),
        Text(t(titleKey), style: const TextStyle(
          fontSize: 24, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text(t(bodyKey), style: const TextStyle(
          fontSize: 15, color: Color(0xFF6B7280), height: 1.6),
          textAlign: TextAlign.center),
      ]),
    );
  }
}
