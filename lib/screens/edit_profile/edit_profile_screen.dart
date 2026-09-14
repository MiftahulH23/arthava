import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/providers/edit_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  // Controller jangan di-init kosong, tapi nanti di initState
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;

    // ISI DATA LANGSUNG (Synchronous) dari Metadata Auth
    // Ini biar pas buka layar, textfield TIDAK KOSONG
    String initialName = user?.userMetadata?['name'] ?? "";
    String initialEmail = user?.email ?? "";

    _nameController = TextEditingController(text: initialName);
    _emailController = TextEditingController(text: initialEmail);

    // Cek lagi ke Database (untuk memastikan data paling update) dilakukan
    // oleh editProfileProvider saat pertama kali di-watch/build di bawah.
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      AppNotification.error(context, "Nama tidak boleh kosong");
      return;
    }

    try {
      await ref
          .read(editProfileProvider.notifier)
          .updateProfile(_nameController.text.trim());

      if (mounted) {
        AppNotification.success(context, "Profil berhasil diperbarui!");
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal update: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editProfileProvider);

    // Kalau data di database beda sama yang di textfield, update — meniru
    // _loadLatestData yang lama.
    ref.listen<EditProfileState>(editProfileProvider, (previous, next) {
      if (next.latestName != null && _nameController.text != next.latestName) {
        _nameController.text = next.latestName!;
      }
    });

    final isLoading = state.isSaving;

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
                onPressed: isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: isLoading
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
