import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/validators.dart';
import '../state/auth_controller.dart';
import '../widgets/app_text_field.dart';
import '../widgets/common_widgets.dart';
import 'reset_password_screen.dart';

/// Minta tautan reset password. Menutup dirinya dengan `true` bila password berhasil diubah
/// (lewat [ResetPasswordScreen]) supaya layar login bisa menampilkan pesan sukses.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);

  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
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
      await auth.forgotPassword(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan tak terduga. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openReset() async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
    );
    if (done == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lupa password')),
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
                      'Masukkan email akun Anda. Kami mengirim tautan untuk membuat password baru.',
                      style: TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    if (_sent) ...[
                      const StatusBanner(
                        message:
                            'Jika email terdaftar, tautan reset sudah dikirim. Buka email Anda, lalu salin token dari tautannya (bagian setelah "token=") dan tempel di layar berikutnya.',
                        isError: false,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_error != null) ...[
                      StatusBanner(message: _error!),
                      const SizedBox(height: 16),
                    ],
                    AppTextField(
                      label: 'Email',
                      hint: 'nama@email.com',
                      controller: _email,
                      enabled: !_loading,
                      validator: Validators.email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: _sent ? 'Kirim ulang tautan' : 'Kirim tautan reset',
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading ? null : _openReset,
                      child: const Text('Sudah punya token? Atur password baru'),
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
