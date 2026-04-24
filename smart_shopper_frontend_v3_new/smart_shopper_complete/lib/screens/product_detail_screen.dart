import 'package:flutter/material.dart';
import '../l10n.dart';
import '../theme.dart';
import '../services/api_service.dart';

class ProductDetailScreen extends StatelessWidget {
  final Map<String, dynamic> product;
  final String lang;
  const ProductDetailScreen({super.key, required this.product, required this.lang});

  @override
  Widget build(BuildContext context) {
    final t    = (String k) => L.t(k, lang);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p    = product;

    final name        = p['name']?.toString() ?? p['product_name']?.toString() ?? 'Unknown';
    final price       = p['price']?.toString() ?? '-';
    final currency    = p['currency']?.toString() ?? '';
    final priceMin    = p['price_min']?.toString();
    final priceMax    = p['price_max']?.toString();
    final description = p['description']?.toString() ?? p['ai_description']?.toString() ?? '';
    final category    = p['category']?.toString() ?? '';
    final brand       = p['brand']?.toString() ?? '';
    final sources = p['sources'] is List
        ? p['sources'] as List<dynamic>
        : p['sources'] is String && (p['sources'] as String).isNotEmpty
            ? (p['sources'] as String).contains('[')
                ? (List<dynamic>.from(
                    (p['sources'] as String)
                      .replaceAll('[','').replaceAll(']','')
                      .split(',')
                      .map((s) => s.trim().replaceAll('"',''))
                      .where((s) => s.isNotEmpty)))
                : [(p['sources'] as String)]
            : <dynamic>[];
    final imageUrl  = p['image_url']?.toString() ?? p['cropped_image_url']?.toString();
    final isCached  = p['cached'] == true;
    final timestamp = p['timestamp']?.toString() ?? p['created_at']?.toString() ?? '';

    // similarity: only meaningful for cached results
    final rawSim  = p['similarity'];
    final simPct  = isCached && rawSim != null
        ? ((rawSim as num) * 100).round()
        : null;

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

          // ── Product image ─────────────────────────────
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                ApiService.fullImageUrl(imageUrl),
                width: double.infinity, height: 220, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.inventory_2_rounded,
                    color: AppTheme.primary, size: 48)),
              ),
            ),
          const SizedBox(height: 16),

          // ── Name ──────────────────────────────────────
          Text(name, style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (brand.isNotEmpty)
            Text(brand, style: const TextStyle(
              fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 16),

          // ── Price card ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C95FF)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('estPrice'),
                    style: const TextStyle(
                      color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('$price $currency',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  if (priceMin != null && priceMax != null)
                    Text('$priceMin – $priceMax $currency',
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ])),
              // Show match % only for cached results
              if (simPct != null)
                Column(children: [
                  Text('$simPct%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22, fontWeight: FontWeight.w800)),
                  Text(t('match'),
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Details grid ─────────────────────────────
          _Section(label: t('result'), dark: dark, children: [
            if (category.isNotEmpty)
              _DetailRow(label: t('category'), value: category),
            if (brand.isNotEmpty)
              _DetailRow(label: t('brand'), value: brand),
            if (currency.isNotEmpty)
              _DetailRow(label: t('currency'), value: currency),
            if (timestamp.length >= 10)
              _DetailRow(label: t('date'), value: timestamp.substring(0, 10)),
          ]),

          // ── Description ───────────────────────────────
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Section(label: t('description'), dark: dark, children: [
              Text(description, style: TextStyle(
                fontSize: 14, height: 1.6,
                color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151))),
            ]),
          ],

          // ── Sources ───────────────────────────────────
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Section(label: t('sources'), dark: dark, children: [
              ...sources.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  const Icon(Icons.link_rounded,
                    color: AppTheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.toString(),
                    style: const TextStyle(
                      fontSize: 12, color: AppTheme.primary),
                    overflow: TextOverflow.ellipsis)),
                ]),
              )),
            ]),
          ],

          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

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
  const _DetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Text(label, style: const TextStyle(
        fontSize: 13, color: Color(0xFF6B7280))),
      const Spacer(),
      Text(value, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );
}