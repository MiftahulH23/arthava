import 'package:arthava/core/app_notification.dart';
import 'package:arthava/core/colors.dart';
import 'package:arthava/screens/edit_profile/edit_profile_screen.dart';
import 'package:arthava/screens/login/login_screen.dart';
import 'package:arthava/widgets/app_grouped_section.dart';
import 'package:arthava/widgets/app_list_row.dart';
import 'package:arthava/widgets/app_page_scaffold.dart';
import 'package:arthava/widgets/app_switch.dart';
import 'package:arthava/screens/settings/include_min_balance_row.dart';
import 'package:arthava/services/biometric_lock_setting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pengaturan. StatefulWidget karena switch "Kunci dengan biometrik" (Plan
/// B7 Task 5b) menyimpan status lokal; switch saldo minimal (Plan B3) adalah
/// ConsumerWidget mandiri.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    @visibleForTesting this.loadBiometricLock,
    @visibleForTesting this.saveBiometricLock,
    @visibleForTesting this.biometricAuth,
  });

  /// Default: baca/tulis `profiles.use_biometric_lock` user yang login.
  final Future<bool> Function()? loadBiometricLock;
  final Future<void> Function(bool value)? saveBiometricLock;

  /// Default: `LocalAuthentication()` (plugin tidak tersedia di test).
  final LocalAuthentication? biometricAuth;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _useBiometricLock = false;
  bool _savingBiometric = false;
  late final LocalAuthentication _auth = widget.biometricAuth ?? LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadBiometricLock();
  }

  Future<void> _loadBiometricLock() async {
    try {
      final value = await (widget.loadBiometricLock ?? loadBiometricLockSetting)();
      if (!mounted) return;
      setState(() => _useBiometricLock = value);
    } catch (e) {
      debugPrint('Gagal memuat pengaturan kunci biometrik: $e');
    }
  }

  Future<void> _toggleBiometricLock(bool value) async {
    // Dikunci sejak awal (termasuk selama prompt biometrik): ketukan kedua
    // tidak memulai verifikasi kedua.
    if (_savingBiometric) return;
    setState(() => _savingBiometric = true);
    try {
      if (value) {
        if (kIsWeb) {
          AppNotification.error(context, 'Kunci biometrik tidak tersedia di versi web.');
          return;
        }
        final supported = await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
        if (!mounted) return;
        if (!supported) {
          AppNotification.error(context, 'Perangkat ini tidak mendukung biometrik.');
          return;
        }
        try {
          final ok = await _auth.authenticate(localizedReason: 'Konfirmasi untuk mengaktifkan kunci Arthava');
          if (!ok || !mounted) return;
        } on LocalAuthException catch (e) {
          // local_auth 3.x melempar exception saat dibatalkan/gagal.
          final canceled = e.code == LocalAuthExceptionCode.userCanceled ||
              e.code == LocalAuthExceptionCode.systemCanceled;
          if (!canceled && mounted) AppNotification.error(context, 'Verifikasi biometrik gagal.');
          return;
        }
      }

      try {
        await (widget.saveBiometricLock ?? saveBiometricLockSetting)(value);
        if (!mounted) return;
        setState(() => _useBiometricLock = value);
        AppNotification.success(context, value ? 'Kunci biometrik aktif.' : 'Kunci biometrik dimatikan.');
      } catch (e) {
        if (mounted) AppNotification.error(context, 'Gagal menyimpan pengaturan.');
      }
    } catch (e) {
      if (mounted) AppNotification.error(context, 'Perangkat ini tidak mendukung biometrik.');
    } finally {
      if (mounted) setState(() => _savingBiometric = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  /// Baris grup "Umum". Baris terakhir adalah switch saldo minimal dari
  /// Plan B3 (`IncludeMinBalanceRow`, ConsumerWidget mandiri).
  List<Widget> _generalRows(BuildContext context) => [
        AppListRow(
          leading: const AppIconTile(
            icon: PhosphorIconsFill.user,
            color: AppColors.primary,
            filled: true,
          ),
          title: 'Profil Akun',
          subtitle: 'Atur nama dan info akun',
          showChevron: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EditProfileScreen()),
            );
          },
        ),
        const IncludeMinBalanceRow(),
        AppListRow(
          leading: const AppIconTile(icon: PhosphorIconsFill.fingerprint, color: AppColors.primary, filled: true),
          title: 'Kunci dengan biometrik',
          subtitle: 'Minta sidik jari / Face ID saat aplikasi dibuka',
          trailing: AppSwitch(
            value: _useBiometricLock,
            onChanged: _savingBiometric ? null : _toggleBiometricLock,
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Pengaturan',
      backLabel: 'Beranda',
      children: [
        AppGroupedSection(header: 'Umum', children: _generalRows(context)),
        AppGroupedSection(
          header: 'Lainnya',
          children: [
            AppListRow(
              leading: const AppIconTile(
                icon: PhosphorIconsFill.info,
                color: AppColors.tintBlue,
                filled: true,
              ),
              title: 'Tentang Aplikasi',
              subtitle: 'Versi 1.0.0',
              showChevron: true,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Aplikasi Arthava v1.0 by Miftahul Huda'),
                  ),
                );
              },
            ),
            AppListRow(
              leading: const AppIconTile(
                icon: PhosphorIconsFill.signOut,
                color: AppColors.expense,
                filled: true,
              ),
              title: 'Keluar',
              titleColor: AppColors.expense,
              subtitle: 'Logout dari akun',
              onTap: () => _logout(context),
            ),
          ],
        ),
      ],
    );
  }
}
