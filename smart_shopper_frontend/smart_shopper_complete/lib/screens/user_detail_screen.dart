import 'package:flutter/material.dart';
import '../l10n.dart';
import '../theme.dart';
import '../data/regions.dart';
import '../services/api_service.dart';
import '../widgets/error_handler.dart';
import 'product_detail_screen.dart';

class UserDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String lang;
  const UserDetailScreen({super.key, required this.user, required this.lang});
  @override State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final d = await ApiService.getUserDetail(widget.user['id']);
      setState(() => _detail = d);
    } catch (e) {
      if (mounted) Err.show(context, e);
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final t    = (String k) => L.t(k, lang);
    final u    = widget.user;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reg  = regionByCode(u['region'] ?? 'SA');
    final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(title: Text(t('userInfo'))),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── User card ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFFF0F0F0),
                    child: Text(initial, style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name.isEmpty ? u['email'] : name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(u['email'], style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280))),
                    const SizedBox(height: 8),
                    Row(children: [
                      _Badge(
                        label: u['role'] ?? 'user',
                        color: u['role'] == 'admin' ? AppTheme.primary : AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      _Badge(
                        label: u['is_verified'] == 1
                            ? t('verified') : t('unverified'),
                        color: u['is_verified'] == 1
                            ? AppTheme.primary : const Color(0xFF888888),
                      ),
                    ]),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Region & stats ─────────────────────────
              Row(children: [
                Expanded(child: _InfoCard(
                  icon: Text(reg.flag, style: const TextStyle(fontSize: 28)),
                  label: t('region'),
                  value: lang == 'ar' ? reg.nameAr : reg.nameEn,
                )),
                const SizedBox(width: 12),
                Expanded(child: _InfoCard(
                  icon: const Icon(Icons.search_rounded, color: AppTheme.primary, size: 28),
                  label: t('totalSearches'),
                  value: '${_detail?['stats']?['total_searches'] ?? 0}',
                )),
                const SizedBox(width: 12),
                Expanded(child: _InfoCard(
                  icon: const Icon(Icons.price_check_rounded, color: AppTheme.primary, size: 28),
                  label: t('avgPrice'),
                  value: '${_detail?['stats']?['avg_price'] ?? 0}',
                )),
              ]),
              const SizedBox(height: 20),

              // ── Join date ──────────────────────────────
              if (u['created_at'] != null)
                _Row(label: t('date'),
                  value: u['created_at'].toString().substring(0, 10)),
              const SizedBox(height: 20),

              // ── Recent products ────────────────────────
              if (_detail?['products'] != null &&
                  (_detail!['products'] as List).isNotEmpty) ...[
                Text(t('recentProducts'), style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ...(_detail!['products'] as List).map((p) {
                  final prod = p as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: prod['image_url'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              ApiService.fullImageUrl(prod['image_url']),
                              width: 48, height: 48, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                const Icon(Icons.inventory_2_rounded,
                                  color: AppTheme.primary)),
                          )
                        : const Icon(Icons.inventory_2_rounded, color: AppTheme.primary),
                      title: Text(
                        (prod['name'] ?? '').toString().isNotEmpty
                            ? prod['name'] : 'Product #${prod['id']}',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${prod['price'] ?? '-'} ${prod['currency'] ?? ''}',
                        style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.primary, size: 20),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(
                          product: prod, lang: lang))),
                    ),
                  );
                }),
              ],
            ]),
          ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label; final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: TextStyle(
      fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

class _InfoCard extends StatelessWidget {
  final Widget icon; final String label, value;
  const _InfoCard({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFEEEEEE)),
    ),
    child: Column(children: [
      icon,
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
        textAlign: TextAlign.center),
    ]),
  );
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    ]),
  );
}
