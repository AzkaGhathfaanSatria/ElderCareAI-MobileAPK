import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../models/user.dart';
import '../state/auth_controller.dart';
import '../widgets/app_text_field.dart';
import '../widgets/common_widgets.dart';

/// Registrasi akun. Admin tidak bisa mendaftar sendiri (ditolak backend),
/// jadi hanya dua peran yang ditawarkan, sama seperti di web.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  UserRole _role = UserRole.keluarga;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final navigator = Navigator.of(context);
    final email = _email.text.trim();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await auth.register(
        nama: _name.text.trim(),
        email: email,
        password: _password.text,
        role: _role,
      );
      // Kembali ke layar login dan kirim email agar terisi otomatis.
      navigator.pop(email);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BrandHeader(
                        title: 'Buat akun baru',
                        subtitle:
                            'Daftar untuk mulai memantau kesehatan dan keselamatan orang tua Anda.',
                      ),
                      const SizedBox(height: 28),
                      if (_error != null) ...[
                        StatusBanner(message: _error!),
                        const SizedBox(height: 16),
                      ],
                      AppTextField(
                        label: 'Nama lengkap',
                        hint: 'Nama Anda',
                        controller: _name,
                        enabled: !_loading,
                        validator: Validators.name,
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                      ),
                      const SizedBox(height: 18),
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
                        hint: 'Minimal 8 karakter',
                        controller: _password,
                        enabled: !_loading,
                        obscure: true,
                        validator: Validators.newPassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                      ),
                      const SizedBox(height: 18),
                      AppTextField(
                        label: 'Konfirmasi password',
                        hint: 'Ulangi password',
                        controller: _confirm,
                        enabled: !_loading,
                        obscure: true,
                        validator:
                            Validators.confirmPassword(() => _password.text),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Saya mendaftar sebagai',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _RoleCard(
                        title: 'Keluarga / Caregiver',
                        description:
                            'Memantau kondisi orang tua atau anggota keluarga.',
                        icon: Icons.favorite_outline,
                        selected: _role == UserRole.keluarga,
                        enabled: !_loading,
                        onTap: () => setState(() => _role = UserRole.keluarga),
                      ),
                      const SizedBox(height: 10),
                      _RoleCard(
                        title: 'Tenaga Medis',
                        description:
                            'Perawat atau dokter yang mendapat akses dari keluarga.',
                        icon: Icons.medical_services_outlined,
                        selected: _role == UserRole.tenagaMedis,
                        enabled: !_loading,
                        onTap: () =>
                            setState(() => _role = UserRole.tenagaMedis),
                      ),
                      const SizedBox(height: 28),
                      PrimaryButton(
                        label: 'Daftar',
                        loading: _loading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Sudah punya akun?',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text(
                              'Masuk',
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0x14C1802F) : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.accentDark : AppColors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.accent : AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
