import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/home/home_screen.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, @visibleForTesting this.auth});

  /// Hanya untuk test: pengganti `LocalAuthentication` (plugin tidak tersedia
  /// di lingkungan test). Produksi selalu memakai `const LockScreen()`.
  final LocalAuthentication? auth;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  late final LocalAuthentication _auth = widget.auth ?? LocalAuthentication();
  bool _isLoading = false;
  bool _canCheckBiometrics = false;
  bool _showManualButton = false;

  // [FIX] Ini dia "Satpam" kita biar gak ditanya 2 kali
  bool _hasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometrics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // [FIX] Cek apakah satpam bilang belum sukses (!hasAuthenticated)
    if (state == AppLifecycleState.resumed &&
        _canCheckBiometrics &&
        !_isLoading &&
        !_hasAuthenticated) {
      _authenticateWithBiometrics();
    }
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();

      if (mounted) {
        setState(() {
          _canCheckBiometrics = canCheckBiometrics && isDeviceSupported;
        });

        if (_canCheckBiometrics) {
          _authenticateWithBiometrics();
        } else {
          _navigateToHome();
        }
      }
    } catch (e) {
      debugPrint("Error check biometrics: $e");
      _navigateToHome();
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    // [FIX] Kalau lagi loading ATAU udah sukses, jangan jalankan lagi!
    if (_isLoading || _hasAuthenticated) return;

    setState(() {
      _isLoading = true;
      _showManualButton = false;
    });

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Gunakan biometrik untuk membuka DompetKu',
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (authenticated) {
          _hasAuthenticated =
              true; // [FIX] Gembok satpam ditutup! Gak bakal nanya lagi.
          _navigateToHome();
        } else {
          setState(() => _showManualButton = true);
        }
      }
    } on PlatformException catch (e) {
      debugPrint("Error Auth: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showManualButton = true;
        });
        AppNotification.error(context, "Gagal menggunakan biometrik.");
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsFill.lockSimple,
                  color: AppColors.primary,
                  size: 46,
                ),
              ),
              const SizedBox(height: 24),
              Text('Aplikasi Terkunci', style: AppTextStyles.title),
              const SizedBox(height: 10),
              Text(
                'Demi keamanan datamu, silakan buka kunci menggunakan biometrik perangkat.',
                textAlign: TextAlign.center,
                style: AppTextStyles.subhead.copyWith(height: 1.5),
              ),
              const SizedBox(height: 32),
              const Icon(
                PhosphorIconsRegular.userFocus,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                Column(
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text('Sedang memverifikasi...', style: AppTextStyles.subhead),
                  ],
                ),
              if (!_isLoading && _showManualButton)
                AppPrimaryButton(
                  label: 'Buka Kunci',
                  onPressed: _authenticateWithBiometrics,
                ),
              const Spacer(),
              Text(
                'Aman bersama DompetKu',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
