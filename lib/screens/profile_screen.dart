import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/push_service.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../models/elder.dart';
import '../models/notification.dart';
import '../models/user.dart';
import '../services/account_service.dart';
import '../state/auth_controller.dart';
import '../widgets/app_text_field.dart';
import '../widgets/common_widgets.dart';
import '../widgets/elder_widgets.dart';

/// Profil akun dan pengaturan notifikasi (sama dengan halaman Profil dan Pengaturan di web).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AccountService _service;
  final _nameKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  NotificationPrefs? _prefs;
  bool _loadingPrefs = true;
  bool _savingName = false;
  bool _savingPrefs = false;
  bool _testing = false;

  String _message = '';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _service = context.read<AccountService>();
    _name.text = context.read<AuthController>().user?.nama ?? '';
    _loadPrefs();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _show(String message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _isError = error;
    });
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await _service.preferences();
      if (mounted) setState(() => _prefs = p);
    } on ApiException catch (e) {
      _show(e.message, error: true);
    } catch (_) {
      _show('Pengaturan notifikasi tidak dapat dimuat.', error: true);
    } finally {
      if (mounted) setState(() => _loadingPrefs = false);
    }
  }

  Future<void> _saveName() async {
    FocusScope.of(context).unfocus();
    if (!_nameKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    setState(() => _savingName = true);
    try {
      final user = await _service.updateName(_name.text.trim());
      auth.updateUser(user);
      _show('Nama berhasil diperbarui.');
    } on ApiException catch (e) {
      _show(e.message, error: true);
    } catch (_) {
      _show('Gagal menyimpan nama.', error: true);
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  /// Simpan langsung saat pengaturan diubah; dikembalikan bila gagal.
  Future<void> _changePrefs(NotificationPrefs next) async {
    final previous = _prefs;
    setState(() {
      _prefs = next;
      _savingPrefs = true;
    });
    try {
      final saved = await _service.savePreferences(next);
      if (mounted) setState(() => _prefs = saved);
    } on ApiException catch (e) {
      if (mounted) setState(() => _prefs = previous);
      _show(e.message, error: true);
    } catch (_) {
      if (mounted) setState(() => _prefs = previous);
      _show('Gagal menyimpan pengaturan.', error: true);
    } finally {
      if (mounted) setState(() => _savingPrefs = false);
    }
  }

  Future<void> _sendTest() async {
    setState(() => _testing = true);
    try {
      final r = await _service.sendTestPush();
      if (!r.enabled) {
        _show(
          'Push belum aktif di server (kunci Firebase belum diisi di backend).',
          error: true,
        );
      } else if (r.tokens == 0) {
        _show(
          'Belum ada HP yang terdaftar untuk akun ini. Status push: ${PushService.instance.description}',
          error: true,
        );
      } else if (r.sent > 0) {
        _show('Notifikasi uji terkirim ke ${r.sent} perangkat. Cek bilah notifikasi HP.');
      } else {
        _show('Server gagal mengirim notifikasi uji. Cek log backend.', error: true);
      }
    } on ApiException catch (e) {
      _show(e.message, error: true);
    } catch (_) {
      _show('Gagal mengirim notifikasi uji.', error: true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthController, AppUser?>((c) => c.user);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil dan pengaturan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (_message.isNotEmpty) ...[
              StatusBanner(message: _message, isError: _isError),
              const SizedBox(height: 16),
            ],
            const SectionTitle('Akun'),
            const SizedBox(height: 12),
            AppCard(
              child: Form(
                key: _nameKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: 'Nama',
                      controller: _name,
                      validator: Validators.name,
                      enabled: !_savingName,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.role.label ?? '',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Simpan nama',
                      loading: _savingName,
                      onPressed: _saveName,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle('Notifikasi'),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: _buildPrefs(),
            ),
            const SizedBox(height: 12),
            Text(
              'Push di HP ini: ${PushService.instance.description}',
              style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Kirim notifikasi uji',
              loading: _testing,
              onPressed: _sendTest,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrefs() {
    final p = _prefs;
    if (_loadingPrefs && p == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    if (p == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Pengaturan tidak dapat dimuat. Tarik keluar lalu buka lagi layar ini.',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    final busy = _savingPrefs;
    return Column(
      children: [
        SwitchListTile(
          value: p.push,
          onChanged: busy ? null : (v) => _changePrefs(p.copyWith(push: v)),
          title: const Text('Push notification'),
          subtitle: const Text('Peringatan langsung ke HP, termasuk saat aplikasi ditutup.'),
          activeColor: AppColors.accent,
        ),
        SwitchListTile(
          value: p.dashboard,
          onChanged: busy ? null : (v) => _changePrefs(p.copyWith(dashboard: v)),
          title: const Text('Notifikasi di daftar'),
          subtitle: const Text('Muncul di layar Notifikasi dan dashboard web.'),
          activeColor: AppColors.accent,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Level minimum peringatan',
                  style: TextStyle(color: AppColors.ink),
                ),
              ),
              DropdownButton<RiskLevel>(
                value: p.minimumLevel,
                onChanged: busy
                    ? null
                    : (v) {
                        if (v != null) _changePrefs(p.copyWith(minimumLevel: v));
                      },
                items: [
                  for (final level in RiskLevel.values)
                    DropdownMenuItem<RiskLevel>(
                      value: level,
                      child: Text(level.label),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
