import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../l10n.dart';
import '../theme.dart';
import '../data/regions.dart';
import '../services/api_service.dart';
import '../widgets/error_handler.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstName = TextEditingController();
  final _lastName  = TextEditingController();
  final _email     = TextEditingController();
  final _pass      = TextEditingController();
  String _region   = 'SA';
  bool   _loading  = false;
  bool   _obs      = true;

  @override
  void dispose() {
    _firstName.dispose(); _lastName.dispose();
    _email.dispose(); _pass.dispose(); super.dispose();
  }

  Future<void> _register() async {
    final lang = context.read<AppState>().language;
    final t    = (String k) => L.t(k, lang);
    if (_firstName.text.isEmpty || _lastName.text.isEmpty ||
        _email.text.isEmpty    || _pass.text.isEmpty) {
      Err.show(context, t('fillFields')); return;
    }
    if (_pass.text.length < 6) { Err.show(context, t('shortPass')); return; }
    setState(() => _loading = true);
    try {
      await ApiService.register(_email.text.trim(), _pass.text.trim(),
          _firstName.text.trim(), _lastName.text.trim(), _region);
      if (!mounted) return;
      Err.show(context, L.t('registered', lang), isSuccess: true);
      // OTP معطل: بعد التسجيل اذهب لـ LoginScreen مباشرة
      Navigator.of(context).pop();
    } catch (e) { if (mounted) Err.show(context, e); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _pickRegion() {
    final lang = context.read<AppState>().language;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6, maxChildSize: 0.85, minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(L.t('selectRegion', lang),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: ListView.builder(
            controller: ctrl,
            itemCount: kRegions.length,
            itemBuilder: (_, i) {
              final r = kRegions[i];
              final isSelected = r.code == _region;
              return ListTile(
                leading: Text(r.flag, style: const TextStyle(fontSize: 24)),
                title: Text(lang == 'ar' ? r.nameAr : r.nameEn,
                  style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                subtitle: Text(r.currency, style: const TextStyle(fontSize: 12)),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary)
                    : null,
                onTap: () { setState(() => _region = r.code); Navigator.pop(context); },
              );
            },
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    final t    = (String k) => L.t(k, lang);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reg  = regionByCode(_region);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('register')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 24),

            // Name row
            Row(children: [
              Expanded(child: _Field(
                label: t('firstName'), ctrl: _firstName,
                hint: L.isRTL(lang) ? 'محمد' : 'John',
                icon: Icons.person_outline_rounded,
              )),
              const SizedBox(width: 12),
              Expanded(child: _Field(
                label: t('lastName'), ctrl: _lastName,
                hint: L.isRTL(lang) ? 'الأحمد' : 'Smith',
                icon: Icons.person_outline_rounded,
              )),
            ]),
            const SizedBox(height: 16),

            // Email
            _Field(label: t('email'), ctrl: _email,
              hint: 'you@example.com', icon: Icons.alternate_email_rounded,
              type: TextInputType.emailAddress),
            const SizedBox(height: 16),

            // Password
            Text(t('password'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _pass, obscureText: _obs,
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obs ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  onPressed: () => setState(() => _obs = !_obs),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Region picker
            Text(t('region'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickRegion,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF1A1A2E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(children: [
                  Text(reg.flag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    lang == 'ar' ? reg.nameAr : reg.nameEn,
                    style: const TextStyle(fontSize: 15),
                  )),
                  Text(reg.currency,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF6B7280), size: 20),
                ]),
              ),
            ),
            const SizedBox(height: 32),

            // Register button
            _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : ElevatedButton.icon(
                  onPressed: _register,
                  icon: const Icon(Icons.person_add_outlined, size: 20),
                  label: Text(t('registerBtn')),
                ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final IconData icon;
  final TextInputType type;
  const _Field({required this.label, required this.ctrl, required this.hint,
      required this.icon, this.type = TextInputType.text});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      TextField(controller: ctrl, keyboardType: type,
        decoration: InputDecoration(hintText: hint,
          prefixIcon: Icon(icon, size: 20))),
    ],
  );
}
