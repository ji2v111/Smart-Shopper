import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../l10n.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang  = state.language;
    final t     = (String k) => L.t(k, lang);
    final dark  = state.isDark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('settings'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),

        // ── Dark / Light ──────────────────────────────────
        _SectionLabel(L.isRTL(lang) ? 'المظهر' : 'Appearance'),
        _Card(children: [
          _Tile(
            icon: dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            iconBg: const Color(0xFFFAEEDA),
            iconColor: const Color(0xFF888888),
            title: t('darkMode'),
            trailing: Switch(
              value: dark,
              onChanged: (_) => state.toggleTheme(),
              activeColor: AppTheme.primary,
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // ── Language ──────────────────────────────────────
        _SectionLabel(t('language')),
        _Card(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: L.languages.map((l) {
                final active = l['code'] == lang;
                return GestureDetector(
                  onTap: () => state.setLanguage(l['code']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active ? AppTheme.primary : const Color(0xFFE5E7EB)),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(l['flag']!,
                        style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 2),
                      Text(l['code']!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: active ? Colors.white : const Color(0xFF6B7280))),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // ── Account ───────────────────────────────────────
        _SectionLabel(L.isRTL(lang) ? 'الحساب' : 'Account'),
        _Card(children: [
          _Tile(
            icon: Icons.logout_rounded,
            iconBg: const Color(0xFFFCEBEB),
            iconColor: const Color(0xFF333333),
            title: t('logout'),
            textColor: const Color(0xFF333333),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(t('logout')),
                  content: Text(t('logoutConfirm')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false),
                      child: Text(t('cancel'))),
                    TextButton(onPressed: () => Navigator.pop(context, true),
                      child: Text(t('exit'),
                        style: const TextStyle(color: const Color(0xFF333333)))),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await ApiService.clearSession();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
              }
            },
          ),
        ]),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(
      fontSize: 12, fontWeight: FontWeight.w600,
      color: Color(0xFF6B7280), letterSpacing: 0.5)),
  );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFEEEEEE)),
    ),
    child: Column(children: children),
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String title;
  final Color? textColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _Tile({required this.icon, required this.iconBg, required this.iconColor,
      required this.title, this.textColor, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: iconColor, size: 20),
    ),
    title: Text(title, style: TextStyle(
      fontSize: 15, fontWeight: FontWeight.w500, color: textColor)),
    trailing: trailing ??
        (onTap != null ? Icon(Icons.chevron_right_rounded,
            color: const Color(0xFFD1D5DB), size: 20) : null),
    onTap: onTap,
  );
}
