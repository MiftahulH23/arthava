import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  // Controller jangan di-init kosong, tapi nanti di initState
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = _supabase.auth.currentUser;
    
    // 1. ISI DATA LANGSUNG (Synchronous) dari Metadata Auth
    // Ini biar pas buka layar, textfield TIDAK KOSONG
    String initialName = user?.userMetadata?['name'] ?? "";
    String initialEmail = user?.email ?? "";

    _nameController = TextEditingController(text: initialName);
    _emailController = TextEditingController(text: initialEmail);

    // 2. Cek lagi ke Database (Untuk memastikan data paling update)
    _loadLatestData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadLatestData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      
      if (data != null && mounted) {
        // Kalau data di database beda sama yang di textfield, update
        if (_nameController.text != data['name']) {
          setState(() {
            _nameController.text = data['name'];
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal load profile db: $e");
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      AppNotification.error(context, "Nama tidak boleh kosong");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Update ke Tabel Profiles
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'name': _nameController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 2. Update ke User Metadata (Penting biar cache lokal juga update)
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {'name': _nameController.text.trim()},
        ),
      );

      if (mounted) {
        AppNotification.success(context, "Profil berhasil diperbarui!");
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal update: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Edit Profil",
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
          children: [
            // AVATAR
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                PhosphorIconsFill.user,
                size: 60,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 30),

            // FORM EMAIL
            _buildTextField(
              label: "Email",
              controller: _emailController,
              icon: PhosphorIconsRegular.envelope,
              isReadOnly: true,
            ),
            const SizedBox(height: 15),

            // FORM NAMA
            _buildTextField(
              label: "Nama Lengkap",
              controller: _nameController,
              icon: PhosphorIconsRegular.user,
              hint: "Masukkan nama kamu",
            ),
            const SizedBox(height: 40),

            // TOMBOL SIMPAN
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "Simpan Perubahan",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool isReadOnly = false,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isReadOnly ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: controller,
            readOnly: isReadOnly,
            style: GoogleFonts.poppins(
              color: isReadOnly ? Colors.grey : AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
              prefixIcon: Icon(icon, color: isReadOnly ? Colors.grey : AppColors.primary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
        ),
      ],
    );
  }
}