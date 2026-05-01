import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../l10n.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../widgets/error_handler.dart';
import 'product_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _products = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.getHistory();
      setState(() => _products = r['products'] ?? []);
    } catch (e) {
      if (mounted) Err.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    final t    = (String k) => L.t(k, lang);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverToBoxAdapter(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('historyTitle'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(t('historyHint'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                const SizedBox(height: 12),
                if (!_loading)
                  Text('${_products.length} ${t('productCount')}',
                    style: const TextStyle(
                      fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w500)),
              ],
            )),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
          else if (_products.isEmpty)
            SliverFillRemaining(
              child: _EmptyHistory(t: t))
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _ProductCard(
                    product: _products[i] as Map<String, dynamic>,
                    lang: lang,
                  ),
                  childCount: _products.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final String lang;
  const _ProductCard({required this.product, required this.lang});

  @override
  Widget build(BuildContext context) {
    final p       = product;
    final name    = (p['name'] ?? '').toString().isNotEmpty
        ? p['name'] : 'Product #${p['id']}';
    final price   = p['price']?.toString() ?? '-';
    final currency = p['currency']?.toString() ?? '';
    final imageUrl = p['image_url']?.toString();
    final date    = (p['timestamp'] ?? '').toString();
    final conf    = p['confidence']?.toString() ?? 'low';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: p, lang: lang))),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      ApiService.fullImageUrl(imageUrl),
                      width: 64, height: 64, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _PlaceholderImg())
                  : _PlaceholderImg(),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.toString(),
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('$price $currency',
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppTheme.primary)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    width: 50, height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: conf == 'high'
                            ? [AppTheme.primary, AppTheme.primary]
                            : conf == 'medium'
                                ? [const Color(0xFF888888), const Color(0xFF888888)]
                                : [const Color(0xFF333333), const Color(0xFF333333)]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${conf == 'high' ? 100 : conf == 'medium' ? 50 : 20}%',
                    style: const TextStyle(
                      fontSize: 11, color: Color(0xFF6B7280))),
                  const Spacer(),
                  if (date.length >= 10)
                    Text(date.substring(0, 10),
                      style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF))),
                ]),
              ],
            )),
            const Icon(Icons.chevron_right_rounded,
              color: Color(0xFFD1D5DB), size: 20),
          ]),
        ),
      ),
    );
  }
}

class _PlaceholderImg extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 64, height: 64,
    decoration: BoxDecoration(
      color: const Color(0xFFF0F0F0),
      borderRadius: BorderRadius.circular(10)),
    child: const Icon(Icons.inventory_2_rounded,
      color: AppTheme.primary, size: 30));
}

class _EmptyHistory extends StatelessWidget {
  final Function t;
  const _EmptyHistory({required this.t});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(24)),
        child: const Icon(Icons.history_rounded,
          color: AppTheme.primary, size: 42)),
      const SizedBox(height: 16),
      Text(t('noProducts'),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(t('noProductsHint'),
        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        textAlign: TextAlign.center),
    ]),
  );
}
