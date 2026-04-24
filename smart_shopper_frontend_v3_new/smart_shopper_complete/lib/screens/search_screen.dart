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
import 'product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _picker = ImagePicker();
  Uint8List? _originalBytes;
  Uint8List? _croppedBytes;
  String?    _croppedB64;
  bool _cropping  = false;
  bool _searching = false;
  Map<String, dynamic>? _result;

  // وقت المعالجة الكاملة — يُعرض في التطبيق فقط
  double? _processingTime;

  Future<void> _pickImage(ImageSource source) async {
    final xf = await _picker.pickImage(source: source, imageQuality: 90);
    if (xf == null) return;
    final bytes = await xf.readAsBytes();
    setState(() {
      _originalBytes  = bytes;
      _croppedBytes   = null;
      _croppedB64     = null;
      _result         = null;
      _processingTime = null;
    });
    await _doCrop(bytes);
  }

  Future<void> _doCrop(Uint8List bytes) async {
    setState(() => _cropping = true);
    try {
      final tmpFile = await _writeTempFile(bytes);
      final b64 = await ApiService.cropImage(tmpFile);
      final cropped = base64Decode(b64);
      setState(() {
        _croppedBytes = cropped;
        _croppedB64   = b64;
      });
    } catch (e) {
      setState(() => _croppedBytes = bytes);
      if (mounted) {
        Err.show(context, 'Auto-crop failed, using original image');
      }
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

    setState(() {
      _searching      = true;
      _processingTime = null;
    });

    final sw = Stopwatch()..start();

    try {
      final bytes = _croppedBytes ?? _originalBytes!;
      final res   = await ApiService.searchByBytes(bytes, language: lang);
      sw.stop();

      // وقت المعالجة: نأخذ من الباك اند إذا توفّر، وإلا نحسبه من العميل
      final serverTime = res['processing_time'];
      final elapsed = serverTime != null
          ? (serverTime as num).toDouble()
          : sw.elapsedMilliseconds / 1000.0;

      final productData = (res['product'] as Map<String, dynamic>?) ?? res;
      final enriched = {
        ...productData,
        'cached':          res['source'] == 'cached',
        'similarity':      res['similarity'],
        'similarity_pct':  res['similarity_pct'],
        'processing_time': elapsed,
      };

      setState(() {
        _result         = enriched;
        _processingTime = elapsed;
      });

      if (mounted && enriched.isNotEmpty) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: enriched, lang: lang)));
      }
    } catch (e) {
      sw.stop();
      if (mounted) Err.show(context, e);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _reset() => setState(() {
    _originalBytes  = null;
    _croppedBytes   = null;
    _croppedB64     = null;
    _result         = null;
    _processingTime = null;
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    final t    = (String k) => L.t(k, lang);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isAr = L.isRTL(lang);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('search'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),

        // ── Image picker zone ─────────────────────────────
        GestureDetector(
          onTap: _croppedBytes == null && _originalBytes == null
              ? () => _showSourceSheet(context, t)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: _originalBytes == null ? 220 : 280,
            decoration: BoxDecoration(
              color: dark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _originalBytes != null
                    ? AppTheme.primary
                    : const Color(0xFFE5E7EB),
                width: _originalBytes != null ? 2 : 1,
              ),
            ),
            child: _originalBytes == null
                ? _UploadPlaceholder(t: t)
                : _cropping
                    ? _CroppingView(t: t)
                    : _croppedBytes != null
                        ? _ImagePreview(
                            bytes: _croppedBytes!,
                            label: t('cropPreview'),
                            onRetake: () => _showSourceSheet(context, t),
                          )
                        : _ImagePreview(
                            bytes: _originalBytes!,
                            label: t('uploadImage'),
                            onRetake: () => _showSourceSheet(context, t),
                          ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Hint / Crop status ────────────────────────────
        if (_croppedBytes != null && !_cropping)
          _HintRow(
            icon: Icons.auto_fix_high_rounded,
            color: AppTheme.secondary,
            text: t('cropHint'),
          ),
        if (_originalBytes != null && !_cropping)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(t('retake')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ),
        const SizedBox(height: 20),

        // ── Analyze button / Loading / Processing time ────
        if (_searching)
          Column(children: [
            const CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 12),
            Text(t('analyzing'),
              style: const TextStyle(color: AppTheme.primary)),
          ])
        else ...[
          ElevatedButton.icon(
            onPressed: (_originalBytes != null && !_cropping)
                ? _search : null,
            icon: const Icon(Icons.search_rounded, size: 22),
            label: Text(t('analyzeBtn')),
          ),

          // وقت المعالجة — يظهر فقط بعد انتهاء البحث
          if (_processingTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.timer_outlined,
                      color: AppTheme.primary, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      isAr
                        ? 'وقت المعالجة: ${_processingTime!.toStringAsFixed(1)}s'
                        : 'Processing: ${_processingTime!.toStringAsFixed(1)}s',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
        ],

        const SizedBox(height: 32),

        // ── Tips ──────────────────────────────────────────
        if (_originalBytes == null) ...[
          Text(
            isAr ? 'نصائح للحصول على أفضل نتائج' : 'Tips for best results',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _Tip(icon: Icons.light_mode_rounded, color: AppTheme.warning,
            text: isAr
                ? 'تأكد من الإضاءة الجيدة وصوّر المنتج بوضوح'
                : 'Ensure good lighting and photograph the product clearly'),
          _Tip(icon: Icons.center_focus_strong_rounded, color: AppTheme.primary,
            text: isAr
                ? 'ضع المنتج في مركز الصورة'
                : 'Center the product in the frame'),
          _Tip(icon: Icons.image_rounded, color: AppTheme.secondary,
            text: isAr
                ? 'يدعم JPG, PNG, WebP'
                : 'Supports JPG, PNG, WebP'),
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
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primaryLight,
                child: Icon(Icons.camera_alt_rounded, color: AppTheme.primary)),
              title: Text(L.isRTL(context.read<AppState>().language)
                  ? 'الكاميرا' : 'Camera'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE1F5EE),
                child: Icon(Icons.photo_library_rounded, color: AppTheme.secondary)),
              title: Text(L.isRTL(context.read<AppState>().language)
                  ? 'معرض الصور' : 'Gallery'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────── Sub-widgets ───────────────────

class _UploadPlaceholder extends StatelessWidget {
  final Function t;
  const _UploadPlaceholder({required this.t});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(20)),
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
  final Function t;
  const _CroppingView({required this.t});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const CircularProgressIndicator(color: AppTheme.primary),
      const SizedBox(height: 16),
      Text(L.isRTL(context.read<AppState>().language)
          ? 'جاري معالجة الصورة…' : 'Processing image…',
        style: const TextStyle(fontSize: 14, color: AppTheme.primary)),
    ],
  );
}

class _ImagePreview extends StatelessWidget {
  final Uint8List bytes;
  final String label;
  final VoidCallback onRetake;
  const _ImagePreview({required this.bytes, required this.label, required this.onRetake});
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(bytes, fit: BoxFit.contain)),
      Positioned(
        bottom: 10, right: 10,
        child: GestureDetector(
          onTap: onRetake,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.edit_rounded, color: Colors.white, size: 14),
              SizedBox(width: 6),
              Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ),
        ),
      ),
    ],
  );
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
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text, style: const TextStyle(fontSize: 13)))),
    ]),
  );
}