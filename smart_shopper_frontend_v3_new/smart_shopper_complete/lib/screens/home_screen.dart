import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../l10n.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'search_screen.dart';
import 'history_screen.dart';
import 'admin_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;
  String _role = 'user';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final r = await ApiService.getRole();
    if (mounted) setState(() => _role = r ?? 'user');
  }

  @override
  Widget build(BuildContext context) {
    final lang    = context.watch<AppState>().language;
    final t       = (String k) => L.t(k, lang);
    final isAdmin = _role == 'admin';
    final isRTL   = L.isRTL(lang);

    final screens = [
      const SearchScreen(),
      const HistoryScreen(),
      if (isAdmin) const AdminScreen(),
      const SettingsScreen(),
    ];

    final navItems = [
      BottomNavigationBarItem(
        icon: const Icon(Icons.search_rounded),
        label: t('search')),
      BottomNavigationBarItem(
        icon: const Icon(Icons.history_rounded),
        label: t('history')),
      if (isAdmin)
        BottomNavigationBarItem(
          icon: const Icon(Icons.admin_panel_settings_rounded),
          label: t('admin')),
      BottomNavigationBarItem(
        icon: const Icon(Icons.settings_rounded),
        label: t('settings')),
    ];

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: IndexedStack(index: _idx, children: screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
            border: const Border(
              top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
          ),
          child: BottomNavigationBar(
            currentIndex: _idx,
            onTap: (i) => setState(() => _idx = i),
            items: navItems,
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}
