import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  final LocalAuthentication _auth = LocalAuthentication();
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
        localizedReason: 'Gunakan biometrik untuk membuka CatatUang',
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
    const backgroundColor = Colors.white;
    const textColor = Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: AppColors.primary,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 30),

                Text(
                  "Aplikasi Terkunci",
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  "Demi keamanan datamu, silakan buka kunci menggunakan biometrik perangkat.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: textColor.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 50),

                if (_isLoading)
                  Column(
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 20),
                      Text(
                        "Sedang memverifikasi...",
                        style: GoogleFonts.poppins(
                          color: textColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),

                if (!_isLoading && _showManualButton)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: _authenticateWithBiometrics,
                      child: Text(
                        "Buka Kunci",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                const Spacer(),
                Text(
                  "Aman bersama CatatUang",
                  style: GoogleFonts.poppins(
                    color: textColor.withOpacity(0.3),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
