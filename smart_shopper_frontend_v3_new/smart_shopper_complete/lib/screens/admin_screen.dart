import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../l10n.dart';
import '../theme.dart';
import '../data/regions.dart';
import '../services/api_service.dart';
import '../widgets/error_handler.dart';
import 'product_detail_screen.dart';
import 'user_detail_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<dynamic> _users = [], _products = [];
  bool _loadU = true, _loadP = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override void dispose() { _tab.dispose(); super.dispose(); }

  void _loadAll() { _loadUsers(); _loadProducts(); }

  Future<void> _loadUsers() async {
    setState(() => _loadU = true);
    try {
      final r = await ApiService.getUsers();
      setState(() => _users = r['users'] ?? []);
    } catch (e) { if (mounted) Err.show(context, e); }
    finally { if (mounted) setState(() => _loadU = false); }
  }

  Future<void> _loadProducts() async {
    setState(() => _loadP = true);
    try {
      final r = await ApiService.getHistory();
      setState(() => _products = r['products'] ?? []);
    } catch (e) {}
    finally { if (mounted) setState(() => _loadP = false); }
  }

  Future<bool?> _confirm(String lang, String body) async =>
      showDialog<bool>(context: context, builder: (_) => AlertDialog(
        title: Text(L.t('deleteConfirm', lang)),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text(L.t('cancel', lang))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text(L.t('delete', lang),
              style: const TextStyle(color: AppTheme.danger))),
        ],
      ));

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    final t    = (String k) => L.t(k, lang);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('adminPanel'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),

          // Stats row
          Row(children: [
            _Stat(icon: Icons.people_alt_rounded,
              iconBg: AppTheme.primaryLight, iconColor: AppTheme.primary,
              label: t('users'),    value: '${_users.length}'),
            const SizedBox(width: 10),
            _Stat(icon: Icons.inventory_2_rounded,
              iconBg: const Color(0xFFE1F5EE), iconColor: AppTheme.secondary,
              label: t('products'), value: '${_products.length}'),
          ]),
          const SizedBox(height: 12),

          // Delete all
          OutlinedButton.icon(
            onPressed: () async {
              if (await _confirm(lang, t('deleteAllConfirm')) != true) return;
              try {
                await ApiService.deleteAllProducts();
                _loadProducts();
                if (mounted) Err.show(context, t('deleteAllDone'), isSuccess: true);
              } catch (e) { if (mounted) Err.show(context, e); }
            },
            icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.danger),
            label: Text(t('deleteAll'), style: const TextStyle(color: AppTheme.danger)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.danger),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 14),

          // Tabs
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: TabBar(
              controller: _tab,
              indicator: BoxDecoration(
                color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF6B7280),
              tabs: [Tab(text: t('users')), Tab(text: t('products'))],
            ),
          ),
        ]),
      ),

      Expanded(child: TabBarView(controller: _tab, children: [
        // ── Users ──────────────────────────────────────────
        _loadU
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                itemBuilder: (_, i) {
                  final u    = _users[i] as Map<String, dynamic>;
                  final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
                  final reg  = regionByCode(u['region'] ?? 'SA');
                  final init = name.isNotEmpty ? name[0].toUpperCase()
                      : u['email'].toString()[0].toUpperCase();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryLight,
                        child: Text(init, style: const TextStyle(
                          color: AppTheme.primary, fontWeight: FontWeight.w700))),
                      title: Text(
                        name.isNotEmpty ? name : u['email'],
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${reg.flag} ${lang == 'ar' ? reg.nameAr : reg.nameEn}  •  ${u['email']}',
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        _MiniTag(u['role'] ?? 'user',
                          u['role'] == 'admin' ? AppTheme.primary : AppTheme.secondary),
                        // Promote / Demote
                        IconButton(
                          tooltip: u['role'] == 'admin' ? t('demoteUser') : t('promoteUser'),
                          icon: Icon(
                            u['role'] == 'admin'
                              ? Icons.remove_moderator_outlined
                              : Icons.admin_panel_settings_outlined,
                            color: u['role'] == 'admin'
                              ? AppTheme.danger
                              : AppTheme.primary,
                            size: 20),
                          onPressed: () async {
                            final newRole = u['role'] == 'admin' ? 'user' : 'admin';
                            final msg = newRole == 'admin'
                              ? t('promoteConfirm')
                              : t('demoteConfirm');
                            if (await _confirm(lang, msg) != true) return;
                            try {
                              await ApiService.updateUserRole(u['id'], newRole);
                              _loadAll();
                              if (mounted) Err.show(context,
                                newRole == 'admin' ? t('promoted') : t('demoted'),
                                isSuccess: true);
                            } catch (e) { if (mounted) Err.show(context, e); }
                          },
                        ),
                        IconButton(
                          tooltip: t('deleteUser'),
                          icon: const Icon(Icons.person_remove_outlined,
                            color: AppTheme.danger, size: 20),
                          onPressed: () async {
                            if (await _confirm(lang, t('deleteConfirm')) != true) return;
                            try {
                              await ApiService.deleteUser(u['id']);
                              _loadAll();
                              if (mounted) Err.show(context, t('deleteDone'), isSuccess: true);
                            } catch (e) { if (mounted) Err.show(context, e); }
                          },
                        ),
                      ]),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => UserDetailScreen(user: u, lang: lang))),
                    ),
                  );
                },
              ),
            ),

        // ── Products ────────────────────────────────────────
        _loadP
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadProducts,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _products.length,
                itemBuilder: (_, i) {
                  final p    = _products[i] as Map<String, dynamic>;
                  final name = (p['name'] ?? '').toString().isNotEmpty
                      ? p['name'] : 'Product #${p['id']}';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: p['image_url'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              ApiService.fullImageUrl(p['image_url']),
                              width: 48, height: 48, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                const Icon(Icons.inventory_2_rounded,
                                  color: AppTheme.primary)))
                        : const Icon(Icons.inventory_2_rounded, color: AppTheme.primary),
                      title: Text(name, style: const TextStyle(fontSize: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${p['price'] ?? '-'} ${p['currency'] ?? ''}  •  '
                        '${(p['timestamp'] ?? '').toString().substring(0, 10)}',
                        style: const TextStyle(color: AppTheme.secondary, fontSize: 12)),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(product: p, lang: lang))),
                      trailing: IconButton(
                        tooltip: t('deleteProduct'),
                        icon: const Icon(Icons.delete_outline_rounded,
                          color: AppTheme.danger, size: 20),
                        onPressed: () async {
                          if (await _confirm(lang, t('deleteConfirm')) != true) return;
                          try {
                            await ApiService.deleteProduct(p['id']);
                            _loadProducts();
                            if (mounted) Err.show(context, t('deleteDone'), isSuccess: true);
                          } catch (e) { if (mounted) Err.show(context, e); }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
      ])),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final IconData icon; final Color iconBg, iconColor;
  final String label, value;
  const _Stat({required this.icon, required this.iconBg, required this.iconColor,
      required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFEEEEEE))),
    child: Row(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 20)),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
      ]),
    ]),
  ));
}

class _MiniTag extends StatelessWidget {
  final String label; final Color color;
  const _MiniTag(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(
      fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
}
