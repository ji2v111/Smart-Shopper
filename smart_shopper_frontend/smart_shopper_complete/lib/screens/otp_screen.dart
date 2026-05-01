import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../l10n.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../widgets/error_handler.dart';
import 'home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});
  @override State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _ctrls = List.generate(6, (_) => TextEditingController());
  final _nodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;

  String get _code => _ctrls.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    // استمع لـ focus لتحديث الـ border
    for (final n in _nodes) n.addListener(() => setState(() {}));
    // focus على أول خانة
    WidgetsBinding.instance.addPostFrameCallback((_) => _nodes[0].requestFocus());
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.length < 6) return;
    setState(() => _loading = true);
    try {
      await ApiService.verifyOtp(widget.email, _code);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
    } catch (e) {
      if (mounted) {
        Err.show(context, e);
        for (final c in _ctrls) c.clear();
        _nodes[0].requestFocus();
      }
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    final t    = (String k) => L.t(k, lang);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            const SizedBox(height: 16),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.mark_email_read_outlined,
                color: AppTheme.primary, size: 42),
            ),
            const SizedBox(height: 24),
            Text(t('otp'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(t('otpSent'), style: TextStyle(fontSize: 14,
              color: dark ? Colors.white60 : const Color(0xFF6B7280)),
              textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(widget.email, style: const TextStyle(
              color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(t('otpHint'), style: TextStyle(fontSize: 13,
              color: dark ? Colors.white38 : const Color(0xFF9CA3AF)),
              textAlign: TextAlign.center),
            const SizedBox(height: 36),

            // ── OTP boxes — دايماً LTR بغض النظر عن لغة التطبيق ──
            Directionality(
              textDirection: TextDirection.ltr,   // ← الإصلاح الرئيسي
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: SizedBox(
                    width: 46, height: 56,
                    child: TextField(
                      controller: _ctrls[i],
                      focusNode:  _nodes[i],
                      textAlign:  TextAlign.center,
                      textDirection: TextDirection.ltr, // ← force LTR للأرقام
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: _nodes[i].hasFocus
                            ? const Color(0xFFF0F0F0)
                            : (dark ? const Color(0xFF1A1A2E) : Colors.white),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _nodes[i].hasFocus
                                ? AppTheme.primary
                                : const Color(0xFFE5E7EB),
                            width: _nodes[i].hasFocus ? 2 : 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _ctrls[i].text.isNotEmpty
                                ? AppTheme.primary
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.primary, width: 2),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        if (v.isNotEmpty) {
                          if (i < 5) _nodes[i + 1].requestFocus();
                        } else {
                          if (i > 0) _nodes[i - 1].requestFocus();
                        }
                        setState(() {});
                        // تحقق تلقائي
                        if (_code.length == 6) _verify();
                      },
                    ),
                  ),
                )),
              ),
            ),

            const SizedBox(height: 40),
            _loading
              ? const CircularProgressIndicator(color: AppTheme.primary)
              : ElevatedButton.icon(
                  onPressed: _code.length == 6 ? _verify : null,
                  icon: const Icon(Icons.verified_outlined, size: 20),
                  label: Text(t('verify')),
                ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loading ? null : () async {
                try {
                  // نحتاج كلمة المرور للإعادة — ارجع للـ LoginScreen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يرجى تسجيل الدخول مجدداً لإعادة إرسال الرمز'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.of(context).pop();
                } catch (_) {}
              },
              icon: const Icon(Icons.refresh_rounded, size: 18, color: AppTheme.primary),
              label: Text(t('resendOtp'),
                style: const TextStyle(color: AppTheme.primary)),
            ),
          ]),
        ),
      ),
    );
  }
}
