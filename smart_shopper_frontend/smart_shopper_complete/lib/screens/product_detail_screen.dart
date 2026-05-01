import 'dart:convert';
import 'package:flutter/material.dart';
import '../l10n.dart';
import '../theme.dart';
import '../services/api_service.dart';

class ProductDetailScreen extends StatelessWidget {
  final Map<String, dynamic> product;
  final String lang;
  const ProductDetailScreen({super.key, required this.product, required this.lang});

  List<dynamic> _parseSources(dynamic raw) {
    if (raw is List) return raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded;
      } catch (_) {}
      if (raw.contains('[')) {
        return raw
            .replaceAll('[', '').replaceAll(']', '')
            .split(',')
            .map((s) => s.trim().replaceAll('"', ''))
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [raw];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final t    = (String k) => L.t(k, lang);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p    = product;

    final name        = (p['name']?.toString().isNotEmpty == true
        ? p['name'].toString()
        : p['product_name']?.toString()) ?? 'Unknown';
    final price       = p['price']?.toString() ?? '-';
    final currency    = p['currency']?.toString() ?? '';
    final priceMin    = p['price_min']?.toString();
    final priceMax    = p['price_max']?.toString();
    final description = p['description']?.toString() ?? p['ai_description']?.toString() ?? '';
    final category    = p['category']?.toString() ?? '';
    final brand       = p['brand']?.toString() ?? '';
    final sources     = _parseSources(p['sources']);
    final imageUrl    = p['image_url']?.toString() ?? p['cropped_image_url']?.toString() ?? '';
    final queryImgUrl = p['query_image_url']?.toString() ?? '';
    final isCached    = p['cached'] == true;
    final timestamp   = p['timestamp']?.toString() ?? p['created_at']?.toString() ?? '';
    final confidence  = p['confidence']?.toString() ?? 'low';

    final rawSim = p['similarity'];
    final simPct = isCached && rawSim != null
        ? ((rawSim as num) * 100).round() : null;

    final confColor = confidence == 'high'
        ? AppTheme.primary
        : confidence == 'medium' ? const Color(0xFF888888) : const Color(0xFF333333);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('productDetail')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Dual images when cached, else single ──────────
          if (isCached && queryImgUrl.isNotEmpty && imageUrl.isNotEmpty)
            _DualImages(
              queryUrl: ApiService.fullImageUrl(queryImgUrl),
              matchUrl: ApiService.fullImageUrl(imageUrl),
            )
          else if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                ApiService.fullImageUrl(imageUrl),
                width: double.infinity, height: 220, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _ImgError()),
            ),
          const SizedBox(height: 16),

          // ── Name ──────────────────────────────────────────
          Text(name, style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700)),
          if (brand.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(brand, style: const TextStyle(
              fontSize: 13, color: Color(0xFF6B7280))),
          ],
          const SizedBox(height: 16),

          // ── Price card ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF000000), Color(0xFF333333)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('estPrice'), style: const TextStyle(
                    color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('$price $currency', style: const TextStyle(
                    color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  if (priceMin != null && priceMax != null)
                    Text('$priceMin – $priceMax $currency',
                      style: TextStyle(color: dark ? Colors.black45 : Colors.white60, fontSize: 12)),
                ])),
              if (simPct != null)
                Column(children: [
                  Text('$simPct%', style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  Text(t('match'), style: const TextStyle(
                    color: Colors.white70, fontSize: 11)),
                ]),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Details ───────────────────────────────────────
          _Section(label: t('result'), dark: dark, children: [
            if (category.isNotEmpty) _DetailRow(label: t('category'), value: category),
            if (brand.isNotEmpty)    _DetailRow(label: t('brand'),    value: brand),
            if (currency.isNotEmpty) _DetailRow(label: t('currency'), value: currency),
            _DetailRow(
              label: t('confidence'),
              value: confidence == 'high' ? t('confHigh')
                  : confidence == 'medium' ? t('confMed') : t('confLow'),
              valueColor: confColor,
            ),
            if (timestamp.length >= 10)
              _DetailRow(label: t('date'), value: timestamp.substring(0, 10)),
          ]),

          // ── Description ───────────────────────────────────
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Section(label: t('description'), dark: dark, children: [
              Text(description, style: TextStyle(
                fontSize: 14, height: 1.6,
                color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151))),
            ]),
          ],

          // ── Sources — clickable links ──────────────────────
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Section(label: t('sources'), dark: dark, children: [
              ...sources.map((s) => _SourceLink(url: s.toString())),
            ]),
          ],

          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

// ── Dual images side by side ──────────────────────────────

class _DualImages extends StatelessWidget {
  final String queryUrl, matchUrl;
  const _DualImages({required this.queryUrl, required this.matchUrl});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Column(children: [
      const Text('Your photo',
        style: TextStyle(fontSize: 11, color: Color(0xFF6B7280),
          fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(12),
        child: Image.network(queryUrl, height: 170,
          width: double.infinity, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _ImgError())),
    ])),
    const SizedBox(width: 10),
    Expanded(child: Column(children: [
      const Text('Matched product',
        style: TextStyle(fontSize: 11, color: Color(0xFF6B7280),
          fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(12),
        child: Image.network(matchUrl, height: 170,
          width: double.infinity, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _ImgError())),
    ])),
  ]);
}

class _ImgError extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 120,
    decoration: BoxDecoration(
      color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(12)),
    child: const Icon(Icons.inventory_2_rounded,
      color: AppTheme.primary, size: 40));
}

// ── Clickable source link ─────────────────────────────────

class _SourceLink extends StatelessWidget {
  final String url;
  const _SourceLink({required this.url});

  bool get _isUrl =>
      url.startsWith('http://') || url.startsWith('https://');

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: GestureDetector(
      onTap: _isUrl
          ? () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Source link',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                content: SelectableText(url,
                  style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
                actions: [TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'))],
              ))
          : null,
      child: Row(children: [
        Icon(_isUrl ? Icons.open_in_new_rounded : Icons.link_rounded,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(url,
          style:  TextStyle(
            fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            decoration: TextDecoration.underline),
          overflow: TextOverflow.ellipsis, maxLines: 2)),
      ]),
    ),
  );
}

// ── Section container ─────────────────────────────────────

class _Section extends StatelessWidget {
  final String label;
  final List<Widget> children;
  final bool dark;
  const _Section({required this.label, required this.children, required this.dark});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280), letterSpacing: 0.3)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: dark ? const Color(0xFF374151) : const Color(0xFFEEEEEE))),
        child: Column(children: children),
      ),
    ],
  );
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _DetailRow({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Text(label, style: const TextStyle(
        fontSize: 13, color: Color(0xFF6B7280))),
      const Spacer(),
      Text(value, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
    ]),
  );
}