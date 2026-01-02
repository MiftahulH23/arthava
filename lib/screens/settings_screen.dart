import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/edit_profile_screen.dart'; // IMPORT INI PENTING
import 'package:catat_uang_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isDarkMode = false;

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Pengaturan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Umum"),

            // 1. PROFIL AKUN (SUDAH AKTIF)
            _buildSettingItem(
              icon: PhosphorIconsFill.user,
              title: "Profil Akun",
              subtitle: "Atur nama dan info akun",
              onTap: () {
                // NAVIGASI KE EDIT PROFILE
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfileScreen(),
                  ),
                );
              },
            ),

            // 2. MODE GELAP (DUMMY)
            _buildSettingItem(
              icon: PhosphorIconsFill.moonStars,
              title: "Mode Gelap",
              subtitle: "Ganti tampilan aplikasi",
              trailing: Switch(
                value: _isDarkMode,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() => _isDarkMode = val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Fitur Dark Mode segera hadir!"),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
            _buildSectionHeader("Lainnya"),

            // 3. TENTANG APLIKASI
            _buildSettingItem(
              icon: PhosphorIconsFill.info,
              title: "Tentang Aplikasi",
              subtitle: "Versi 1.0.0",
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
              iconColor: Colors.red,
              textColor: Colors.red,
              onTap: _logout,
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
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
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
            color: textColor ?? AppColors.textPrimary,
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
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ),
    );
  }
}
