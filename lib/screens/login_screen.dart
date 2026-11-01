import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../state/auth_controller.dart';
import '../widgets/app_text_field.dart';
import '../widgets/common_widgets.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });

    try {
      // Bila sukses, AuthGate otomatis berpindah ke layar utama.
      await auth.login(email: _email.text.trim(), password: _password.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Terjadi kesalahan tak terduga. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRegister() async {
    final registeredEmail = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (!mounted || registeredEmail == null) return;
    setState(() {
      _email.text = registeredEmail;
      _password.clear();
      _error = null;
      _notice = 'Registrasi berhasil. Silakan masuk dengan akun Anda.';
    });
  }

  Future<void> _openForgot() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(initialEmail: _email.text.trim()),
      ),
    );
    if (!mounted || changed != true) return;
    setState(() {
      _password.clear();
      _error = null;
      _notice = 'Password berhasil diubah. Silakan masuk dengan password baru.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BrandHeader(
                        title: 'Selamat datang kembali',
                        subtitle:
                            'Masuk untuk memantau kondisi orang tua Anda secara real-time.',
                      ),
                      const SizedBox(height: 28),
                      if (_notice != null) ...[
                        StatusBanner(message: _notice!, isError: false),
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
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 18),
                      AppTextField(
                        label: 'Password',
                        hint: 'Masukkan password',
                        controller: _password,
                        enabled: !_loading,
                        obscure: true,
                        validator: Validators.loginPassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading ? null : _openForgot,
                          child: const Text('Lupa password?'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Masuk',
                        loading: _loading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Belum punya akun?',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          TextButton(
                            onPressed: _loading ? null : _openRegister,
                            child: const Text(
                              'Daftar sekarang',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
