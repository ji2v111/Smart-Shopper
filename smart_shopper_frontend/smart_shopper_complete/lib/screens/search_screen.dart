import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../l10n.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../widgets/error_handler.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _picker = ImagePicker();
  Uint8List? _originalBytes;
  Uint8List? _croppedBytes;
  bool _cropping  = false;
  bool _searching = false;
  Map<String, dynamic>? _result;

  double? _processingTime;
  double? _cropTime;

  Future<void> _pickImage(ImageSource source) async {
    final xf = await _picker.pickImage(source: source, imageQuality: 90);
    if (xf == null) return;
    final bytes = await xf.readAsBytes();
    setState(() {
      _originalBytes  = bytes;
      _croppedBytes   = null;
      _result         = null;
      _processingTime = null;
      _cropTime       = null;
    });
    await _doCrop(bytes);
  }

  Future<void> _doCrop(Uint8List bytes) async {
    setState(() => _cropping = true);
    final sw = Stopwatch()..start();
    try {
      final tmpFile = await _writeTempFile(bytes);
      final res = await ApiService.cropImage(tmpFile);
      sw.stop();

      final serverCropTime = res['crop_time'];
      final ct = serverCropTime != null
          ? (serverCropTime as num).toDouble()
          : sw.elapsedMilliseconds / 1000.0;

      final cropped = base64Decode(res['b64'] as String);
      setState(() {
        _croppedBytes = cropped;
        _cropTime     = ct;
      });
    } catch (e) {
      sw.stop();
      setState(() {
        _croppedBytes = bytes;
        _cropTime     = sw.elapsedMilliseconds / 1000.0;
      });
      if (mounted) Err.show(context, 'Auto-crop failed, using original image');
    } finally {
      if (mounted) setState(() => _cropping = false);
    }
  }

  Future<File> _writeTempFile(Uint8List bytes) async {
    final d = Directory.systemTemp.createTempSync('smart_shopper_');
    final f = File('${d.path}/tmp_image.jpg');
    await f.writeAsBytes(bytes);
    return f;
  }

  Future<void> _search() async {
    if (_croppedBytes == null && _originalBytes == null) return;
    final lang = context.read<AppState>().language;

    setState(() { _searching = true; _processingTime = null; });
    final sw = Stopwatch()..start();

    try {
      final bytes = _croppedBytes ?? _originalBytes!;
      final res   = await ApiService.searchByBytes(bytes, language: lang);
      sw.stop();

      final serverTime = res['processing_time'];
      final elapsed = serverTime != null
          ? (serverTime as num).toDouble()
          : sw.elapsedMilliseconds / 1000.0;

      final productData = (res['product'] as Map<String, dynamic>?) ?? res;

      // Parse sources into clean List
      final sourcesList = _parseSources(productData['sources'] ?? res['sources']);

      // Parse price_range
      final priceRange = productData['price_range'] ?? res['price_range'];
      double? priceMin, priceMax;
      if (priceRange is Map) {
        priceMin = (priceRange['min'] as num?)?.toDouble();
        priceMax = (priceRange['max'] as num?)?.toDouble();
      }

      final enriched = {
        ...productData,
        'sources':         sourcesList,
        'price_min':       priceMin,
        'price_max':       priceMax,
        'cached':          res['source'] == 'cached',
        'similarity':      res['similarity'],
        'similarity_pct':  res['similarity_pct'],
        'processing_time': elapsed,
        'query_image_url': res['query_image_url'],
      };

      setState(() { _result = enriched; _processingTime = elapsed; });
    } catch (e) {
      sw.stop();
      if (mounted) Err.show(context, e);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

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

  void _reset() => setState(() {
    _originalBytes  = null;
    _croppedBytes   = null;
    _result         = null;
    _processingTime = null;
    _cropTime       = null;
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    final t    = (String k) => L.t(k, lang);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('search'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),

        // ── Image picker zone ─────────────────────────────
        GestureDetector(
          onTap: _croppedBytes == null && _originalBytes == null
              ? () => _showSourceSheet(context, t) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: _originalBytes == null ? 220 : 280,
            decoration: BoxDecoration(
              color: dark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _originalBytes != null ? AppTheme.primary : const Color(0xFFE5E7EB),
                width: _originalBytes != null ? 2 : 1,
              ),
            ),
            child: _originalBytes == null
                ? _UploadPlaceholder(t: t)
                : _cropping
                    ? _CroppingView(cropTime: _cropTime)
                    : _croppedBytes != null
                        ? _ImagePreview(bytes: _croppedBytes!, label: t('cropPreview'),
                            onRetake: () => _showSourceSheet(context, t))
                        : _ImagePreview(bytes: _originalBytes!, label: t('uploadImage'),
                            onRetake: () => _showSourceSheet(context, t)),
          ),
        ),
        const SizedBox(height: 16),

        if (_croppedBytes != null && !_cropping)
          _HintRow(icon: Icons.auto_fix_high_rounded,
            color: AppTheme.primary, text: t('cropHint')),

        if (_originalBytes != null && !_cropping)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(t('retake')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF333333),
                side: const BorderSide(color: const Color(0xFF333333)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            ),
          ),
        const SizedBox(height: 20),

        // ── Analyze / loading ─────────────────────────────
        if (_searching)
          Column(children: [
            const CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 12),
            Text(t('analyzing'),
              style: const TextStyle(color: AppTheme.primary)),
          ])
        else ...[
          ElevatedButton.icon(
            onPressed: (_originalBytes != null && !_cropping) ? _search : null,
            icon: const Icon(Icons.search_rounded, size: 22),
            label: Text(t('analyzeBtn')),
          ),

          // ── Timing badge ──────────────────────────────
          if (_processingTime != null || _cropTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.timer_outlined,
                      color: AppTheme.primary, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      (_cropTime != null && _processingTime != null)
                          ? 'Crop: ${_cropTime!.toStringAsFixed(1)}s  •  '
                            'Search: ${_processingTime!.toStringAsFixed(1)}s  •  '
                            'Total: ${(_cropTime! + _processingTime!).toStringAsFixed(1)}s'
                          : _processingTime != null
                              ? 'Processing: ${_processingTime!.toStringAsFixed(1)}s'
                              : 'Crop: ${_cropTime!.toStringAsFixed(1)}s',
                      style:  TextStyle(
                        fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              ),
            ),
        ],

        // ── Inline result ─────────────────────────────────
        if (_result != null && !_searching) ...[
          const SizedBox(height: 24),
          _InlineResultCard(result: _result!, lang: lang, dark: dark, t: t),
        ],

        const SizedBox(height: 32),

        // ── Tips (no image selected) ──────────────────────
        if (_originalBytes == null) ...[
          const Text('Tips for best results',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const _Tip(icon: Icons.light_mode_rounded, color: const Color(0xFF888888),
            text: 'Ensure good lighting and photograph the product clearly'),
          const _Tip(icon: Icons.center_focus_strong_rounded, color: AppTheme.primary,
            text: 'Center the product in the frame'),
          const _Tip(icon: Icons.image_rounded, color: AppTheme.primary,
            text: 'Supports JPG, PNG, WebP'),
        ],
      ]),
    );
  }

  void _showSourceSheet(BuildContext ctx, Function t) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(backgroundColor: const Color(0xFFF0F0F0),
                child: Icon(Icons.camera_alt_rounded, color: AppTheme.primary)),
              title: const Text('Camera'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFF2F2F2),
                child: Icon(Icons.photo_library_rounded, color: AppTheme.primary)),
              title: const Text('Gallery'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────── Inline Result Card ───────────────────

class _InlineResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final String lang;
  final bool dark;
  final String Function(String) t;

  const _InlineResultCard({
    required this.result, required this.lang,
    required this.dark,   required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final p           = result;
    final name        = (p['name']?.toString().isNotEmpty == true
        ? p['name'].toString()
        : p['product_name']?.toString()) ?? 'Unknown';
    final brand       = p['brand']?.toString() ?? '';
    final category    = p['category']?.toString() ?? '';
    final price       = p['price']?.toString() ?? '-';
    final currency    = p['currency']?.toString() ?? '';
    final priceMin    = p['price_min'];
    final priceMax    = p['price_max'];
    final description = p['description']?.toString() ?? '';
    final confidence  = p['confidence']?.toString() ?? 'low';
    final isCached    = p['cached'] == true;
    final simPct      = isCached && p['similarity'] != null
        ? ((p['similarity'] as num) * 100).round() : null;

    final productImageUrl = p['image_url']?.toString() ?? '';
    final queryImageUrl   = p['query_image_url']?.toString() ?? '';
    final sources         = p['sources'] is List ? p['sources'] as List : <dynamic>[];

    final confColor = confidence == 'high'
        ? AppTheme.primary
        : confidence == 'medium' ? const Color(0xFF888888) : const Color(0xFF333333);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header badges
      Row(children: [
        _Badge(
          label: isCached ? t('cached') : t('aiNew'),
          icon: isCached ? Icons.bolt_rounded : Icons.auto_awesome_rounded,
          color: isCached ? AppTheme.primary : AppTheme.primary,
          bg: isCached ? const Color(0xFFF0F0F0) : const Color(0xFFF0F0F0),
        ),
        if (simPct != null) ...[
          const SizedBox(width: 8),
          _Badge(
            label: '$simPct% ${t('match')}',
            icon: Icons.verified_rounded,
            color: AppTheme.primary,
            bg: const Color(0xFFF0F0F0),
          ),
        ],
      ]),
      const SizedBox(height: 12),

      // ── Dual images (query + match) or single ─────────
      if (isCached && queryImageUrl.isNotEmpty && productImageUrl.isNotEmpty)
        _DualImages(
          queryUrl: ApiService.fullImageUrl(queryImageUrl),
          matchUrl: ApiService.fullImageUrl(productImageUrl),
        )
      else if (productImageUrl.isNotEmpty)
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(ApiService.fullImageUrl(productImageUrl),
            width: double.infinity, height: 200, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const _ImgError()),
        ),
      const SizedBox(height: 16),

      // Name & brand
      Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      if (brand.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(brand, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
      ],
      const SizedBox(height: 16),

      // Price card
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
              Text(t('estPrice'), style: TextStyle(
                color: dark ? Colors.black54 : Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('$price $currency', style: TextStyle(
                color: dark ? Colors.black : Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
              if (priceMin != null && priceMax != null)
                Text('$priceMin – $priceMax $currency',
                  style: TextStyle(color: dark ? Colors.black45 : Colors.white60, fontSize: 12)),
            ])),
          if (simPct != null)
            Column(children: [
              Text('$simPct%', style: TextStyle(
                color: dark ? Colors.black : Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              Text(t('match'), style: TextStyle(
                color: dark ? Colors.black54 : Colors.white70, fontSize: 11)),
            ]),
        ]),
      ),
      const SizedBox(height: 16),

      // Details
      _ResultSection(label: t('result'), dark: dark, children: [
        if (category.isNotEmpty) _Row(label: t('category'), value: category),
        if (brand.isNotEmpty)    _Row(label: t('brand'),    value: brand),
        if (currency.isNotEmpty) _Row(label: t('currency'), value: currency),
        _Row(
          label: t('confidence'),
          value: confidence == 'high' ? t('confHigh')
              : confidence == 'medium' ? t('confMed') : t('confLow'),
          valueColor: confColor,
        ),
      ]),

      // Description
      if (description.isNotEmpty) ...[
        const SizedBox(height: 12),
        _ResultSection(label: t('description'), dark: dark, children: [
          Text(description, style: TextStyle(
            fontSize: 14, height: 1.6,
            color: dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151))),
        ]),
      ],

      // Sources as clickable links
      if (sources.isNotEmpty) ...[
        const SizedBox(height: 12),
        _ResultSection(label: t('sources'), dark: dark,
          children: sources.map((s) => _SourceLink(url: s.toString())).toList()),
      ],

      const SizedBox(height: 8),
    ]);
  }
}

// ── Helpers ───────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color, bg;
  const _Badge({required this.label, required this.icon,
    required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    ]),
  );
}

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
        child: Image.network(queryUrl, height: 160,
          width: double.infinity, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const _ImgError())),
    ])),
    const SizedBox(width: 10),
    Expanded(child: Column(children: [
      const Text('Matched product',
        style: TextStyle(fontSize: 11, color: Color(0xFF6B7280),
          fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(12),
        child: Image.network(matchUrl, height: 160,
          width: double.infinity, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const _ImgError())),
    ])),
  ]);
}

class _ImgError extends StatelessWidget {
  const _ImgError();
  @override
  Widget build(BuildContext context) => Container(
    height: 120,
    decoration: BoxDecoration(
      color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(12)),
    child: const Icon(Icons.inventory_2_rounded,
      color: AppTheme.primary, size: 40));
}

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

class _ResultSection extends StatelessWidget {
  final String label;
  final List<Widget> children;
  final bool dark;
  const _ResultSection({required this.label, required this.children, required this.dark});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280), letterSpacing: 0.3)),
      const SizedBox(height: 8),
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

class _Row extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _Row({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
      const Spacer(),
      Text(value, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
    ]),
  );
}

class _UploadPlaceholder extends StatelessWidget {
  final Function t;
  const _UploadPlaceholder({required this.t});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(width: 72, height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.add_photo_alternate_rounded,
          color: AppTheme.primary, size: 38)),
      const SizedBox(height: 16),
      Text(t('uploadImage'),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(t('uploadHint'),
        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
    ],
  );
}

class _CroppingView extends StatelessWidget {
  final double? cropTime;
  const _CroppingView({this.cropTime});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const CircularProgressIndicator(color: AppTheme.primary),
      const SizedBox(height: 16),
      const Text('Processing image…',
        style: TextStyle(fontSize: 14, color: AppTheme.primary)),
      if (cropTime != null) ...[
        const SizedBox(height: 6),
        Text('Crop: ${cropTime!.toStringAsFixed(1)}s',
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
      ],
    ],
  );
}

class _ImagePreview extends StatelessWidget {
  final Uint8List bytes;
  final String label;
  final VoidCallback onRetake;
  const _ImagePreview({required this.bytes, required this.label, required this.onRetake});
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
    ClipRRect(borderRadius: BorderRadius.circular(14),
      child: Image.memory(bytes, fit: BoxFit.contain)),
    Positioned(bottom: 10, right: 10,
      child: GestureDetector(
        onTap: onRetake,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black54, borderRadius: BorderRadius.circular(20)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.edit_rounded, color: Colors.white, size: 14),
            SizedBox(width: 6),
            Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
          ]),
        ),
      )),
  ]);
}

class _HintRow extends StatelessWidget {
  final IconData icon; final Color color; final String text;
  const _HintRow({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: color, size: 18),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color))),
  ]);
}

class _Tip extends StatelessWidget {
  final IconData icon; final Color color; final String text;
  const _Tip({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text, style: const TextStyle(fontSize: 13)))),
    ]),
  );
}