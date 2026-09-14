import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/edit_profile/edit_profile_screen.dart';
import 'package:catat_uang_app/screens/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// StatelessWidget: layar ini tidak punya state lokal (tidak ada setState di
// mana pun) — hanya satu aksi one-shot (_logout) tanpa data yang perlu
// dipertahankan, jadi tidak butuh StatefulWidget atau Riverpod provider.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    // Cek apakah mode gelap sedang aktif (untuk styling UI halaman ini).
    // CATATAN: sengaja TIDAK memakai AppCard di sini — AppCard (forui)
    // light-only by design, sedangkan layar ini mendukung dark mode secara
    // manual lewat Container/ListTile dinamis. Memakai AppCard akan
    // meregresi dark mode di layar ini.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      // Background otomatis ikut tema dari main.dart
      appBar: AppBar(
        title: Text(
          "Pengaturan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: contentColor,
          ),
        ),
        centerTitle: true,
        // Background & Icon AppBar otomatis ikut tema dari main.dart
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: contentColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Umum"),

            // 1. PROFIL AKUN
            _buildSettingItem(
              icon: PhosphorIconsFill.user,
              title: "Profil Akun",
              subtitle: "Atur nama dan info akun",
              cardColor: cardColor,
              contentColor: contentColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfileScreen(),
                  ),
                );
              },
            ),



            const SizedBox(height: 20),
            _buildSectionHeader("Lainnya"),

            // 3. TENTANG APLIKASI
            _buildSettingItem(
              icon: PhosphorIconsFill.info,
              title: "Tentang Aplikasi",
              subtitle: "Versi 1.0.0",
              cardColor: cardColor,
              contentColor: contentColor,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Aplikasi Catat Uang v1.0 by Miftahul Huda"),
                  ),
                );
              },
            ),

            // 4. KELUAR / LOGOUT
            _buildSettingItem(
              icon: PhosphorIconsFill.signOut,
              title: "Keluar",
              subtitle: "Logout dari akun",
              cardColor: cardColor,
              contentColor: contentColor, // Text default
              iconColor: Colors.red,
              textColor: Colors.red,
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required Color cardColor, // Warna kartu dinamis
    required Color contentColor, // Warna teks dinamis
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor, // Pakai warna dinamis
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (iconColor ?? AppColors.primary).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: textColor ?? contentColor, // Pakai warna dinamis
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              )
            : null,
        trailing:
            trailing ??
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ),
    );
  }
}
