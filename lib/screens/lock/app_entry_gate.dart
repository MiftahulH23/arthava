import 'package:arthava/core/colors.dart';
import 'package:arthava/core/lock_policy.dart';
import 'package:arthava/screens/home/home_screen.dart';
import 'package:arthava/screens/lock/lock_screen.dart';
import 'package:arthava/services/biometric_lock_setting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// Titik masuk setelah login (cold start): menampilkan [LockScreen] bila user
/// mengaktifkan kunci biometrik di Pengaturan dan perangkat mendukungnya,
/// selain itu langsung [HomeScreen]. Gagal membaca setting → langsung Beranda
/// (kunci ini fitur kenyamanan; data tetap dilindungi login + RLS).
class AppEntryGate extends StatefulWidget {
  const AppEntryGate({
    super.key,
    @visibleForTesting this.loadSetting,
    @visibleForTesting this.deviceSupported,
    @visibleForTesting this.lockBuilder,
    @visibleForTesting this.homeBuilder,
  });

  final Future<bool> Function()? loadSetting;
  final Future<bool> Function()? deviceSupported;
  final Widget Function()? lockBuilder;
  final Widget Function()? homeBuilder;

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  late final Future<bool> _showLock = _decide();

  static Future<bool> _deviceSupports() async {
    final auth = LocalAuthentication();
    return await auth.canCheckBiometrics && await auth.isDeviceSupported();
  }

  Future<bool> _decide() async {
    try {
      final enabled = await (widget.loadSetting ?? loadBiometricLockSetting)();
      if (!enabled || kIsWeb) return false; // web: plugin local_auth tidak dipanggil sama sekali
      final supported = await (widget.deviceSupported ?? _deviceSupports)();
      return shouldShowLock(enabled: enabled, isWeb: kIsWeb, deviceSupported: supported);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _showLock,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        if (snapshot.data == true) return widget.lockBuilder?.call() ?? const LockScreen();
        return widget.homeBuilder?.call() ?? const HomeScreen();
      },
    );
  }
}
