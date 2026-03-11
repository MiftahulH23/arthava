import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/home_screen.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    // Otomatis minta sidik jari saat halaman ini dibuka
    _authenticate();
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      setState(() => _isAuthenticating = true);
      
      // [UPDATE]: Cukup panggil parameter yang wajib saja biar bebas error!
      authenticated = await auth.authenticate(
        localizedReason: 'Gunakan Sidik Jari / PIN untuk membuka brankas uangmu',
      );
      
      setState(() => _isAuthenticating = false);
    } on PlatformException catch (e) {
      debugPrint(e.toString());
      setState(() => _isAuthenticating = false);
      return;
    }
    
    if (!mounted) return;

    if (authenticated) {
      // Jika sidik jari benar, hancurkan gembok dan masuk ke Home Screen!
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Warna gelap premium
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsFill.fingerprint,
                size: 80,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              "Aplikasi Terkunci",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Verifikasi identitasmu untuk masuk",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 50),
            
            // Tombol manual kalau prompt biometriknya ter-cancel
            if (!_isAuthenticating)
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.lock_open, color: Colors.white),
                label: const Text(
                  "Buka Kunci", 
                  style: TextStyle(fontWeight: FontWeight.bold)
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              
            if (_isAuthenticating)
               const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}