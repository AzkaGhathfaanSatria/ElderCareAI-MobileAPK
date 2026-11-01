import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/validators.dart';
import '../state/auth_controller.dart';
import '../widgets/app_text_field.dart';
import '../widgets/common_widgets.dart';

/// Atur password baru memakai token dari email. Menutup dirinya dengan `true` bila berhasil.
///
/// Tautan di email mengarah ke website (FRONTEND_URL) dan sering tidak bisa dibuka dari HP, jadi
/// token ditempel di sini. Boleh menempel seluruh tautan; bagian `token=` diambil otomatis.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Ambil token dari tautan lengkap (`...?token=abc&x=y`) atau token polos.
  static String extractToken(String raw) {
    final text = raw.trim();
    final i = text.indexOf('token=');
    if (i < 0) return text;
    var rest = text.substring(i + 'token='.length);
    final end = rest.indexOf(RegExp(r'[&#\s]'));
    if (end >= 0) rest = rest.substring(0, end);
    return Uri.decodeComponent(rest);
  }

  String? _validateToken(String? value) {
    final t = extractToken(value ?? '');
    if (t.isEmpty) return 'Token wajib diisi.';
    if (t.length < 20) return 'Token terlalu pendek. Salin utuh dari tautan email.';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await auth.resetPassword(
        token: extractToken(_token.text),
        password: _password.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan tak terduga. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Password baru')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Tempel token dari email reset password, lalu isi password baru.',
                      style: TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      StatusBanner(message: _error!),
                      const SizedBox(height: 16),
                    ],
                    AppTextField(
                      label: 'Token',
                      hint: 'Tempel token atau seluruh tautan',
                      controller: _token,
                      enabled: !_loading,
                      validator: _validateToken,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'Password baru',
                      hint: 'Minimal 8 karakter',
                      controller: _password,
                      enabled: !_loading,
                      obscure: true,
                      validator: Validators.newPassword,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'Ulangi password baru',
                      controller: _confirm,
                      enabled: !_loading,
                      obscure: true,
                      validator: Validators.confirmPassword(() => _password.text),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Simpan password baru',
                      loading: _loading,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
