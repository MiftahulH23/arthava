import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/edit_profile/edit_profile_screen.dart';
import 'package:catat_uang_app/screens/login/login_screen.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_switch.dart';
import 'package:catat_uang_app/screens/settings/include_min_balance_row.dart';
import 'package:catat_uang_app/services/biometric_lock_setting.dart';
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
    if (_savingBiometric) return;
    if (value) {
      if (kIsWeb) {
        AppNotification.error(context, 'Kunci biometrik tidak tersedia di versi web.');
        return;
      }
      try {
        final supported = await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
        if (!mounted) return;
        if (!supported) {
          AppNotification.error(context, 'Perangkat ini tidak mendukung biometrik.');
          return;
        }
        final ok = await _auth.authenticate(localizedReason: 'Konfirmasi untuk mengaktifkan kunci DompetKu');
        if (!ok || !mounted) return; // dibatalkan / gagal: tidak mengubah apa pun
      } catch (e) {
        if (mounted) AppNotification.error(context, 'Perangkat ini tidak mendukung biometrik.');
        return;
      }
    }

    setState(() => _savingBiometric = true);
    try {
      await (widget.saveBiometricLock ?? saveBiometricLockSetting)(value);
      if (!mounted) return;
      setState(() => _useBiometricLock = value);
      AppNotification.success(context, value ? 'Kunci biometrik aktif.' : 'Kunci biometrik dimatikan.');
    } catch (e) {
      if (mounted) AppNotification.error(context, 'Gagal menyimpan pengaturan.');
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
                    content: Text('Aplikasi DompetKu v1.0 by Miftahul Huda'),
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
