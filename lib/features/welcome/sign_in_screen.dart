import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/night_background.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';

/// Name + optional mobile number, opened from Profile.
///
/// Stored on the device only. The number is not verified yet — OTP verification
/// (Firebase Phone Auth) plugs in at [_submit] once Firebase is configured.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: ref.read(settingsProvider).name);
  final _countryCode = TextEditingController(text: '+91');
  late final _phone = TextEditingController(text: _savedNational());

  /// When editing from Profile, pre-fill the saved number (Indian numbers only, for now).
  String _savedNational() {
    final saved = ref.read(settingsProvider).phone;
    return saved.startsWith('+91') ? saved.substring(3) : '';
  }

  @override
  void dispose() {
    _name.dispose();
    _countryCode.dispose();
    _phone.dispose();
    super.dispose();
  }

  String get _code => _countryCode.text.replaceAll(RegExp(r'[^0-9]'), '');

  String? _validatePhone(String? value, AppLocalizations l) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null; // optional
    final ok = _code == '91' ? RegExp(r'^[6-9]\d{9}$').hasMatch(digits) : digits.length >= 6 && digits.length <= 14;
    return ok && _code.isNotEmpty ? null : l.phoneInvalid;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    final phone = digits.isEmpty ? '' : '+$_code$digits';
    await ref.read(settingsProvider.notifier).signIn(name: _name.text, phone: phone);
    if (!mounted) return;
    context.canPop() ? context.pop() : context.go('/home');
  }

  InputDecoration _field(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.ivoryCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        errorStyle: const TextStyle(color: AppColors.goldSoft),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                const SizedBox(height: 40),
                const Center(child: LogoMark(size: 84)),
                const SizedBox(height: 16),
                const Center(child: Wordmark(size: 40)),
                const SizedBox(height: 28),
                Text(l.signInTitle, textAlign: TextAlign.center, style: AppText.serif(26, color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  l.signInSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), height: 1.4),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: _field(l.yourName),
                  validator: (v) => (v ?? '').trim().isEmpty ? l.nameRequired : null,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 84,
                      child: TextFormField(
                        controller: _countryCode,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[+0-9]')), LengthLimitingTextInputFormatter(4)],
                        decoration: _field(''),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.telephoneNumberNational],
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(14)],
                        decoration: _field(l.mobileNumber, hint: '98765 43210'),
                        validator: (v) => _validatePhone(v, l),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  onPressed: _submit,
                  child: Text(l.continueLabel),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
