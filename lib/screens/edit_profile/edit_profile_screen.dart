import 'package:arthava/core/app_notification.dart';
import 'package:arthava/core/colors.dart';
import 'package:arthava/core/formatters.dart';
import 'package:arthava/providers/edit_profile_provider.dart';
import 'package:arthava/theme/app_text_styles.dart';
import 'package:arthava/widgets/app_buttons.dart';
import 'package:arthava/widgets/app_grouped_section.dart';
import 'package:arthava/widgets/app_list_row.dart';
import 'package:arthava/widgets/app_page_scaffold.dart';
import 'package:arthava/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Inisial avatar memakai initialsOf() dari lib/core/formatters.dart (dibuat Plan B3,
// sudah dites di sana): '?' untuk nama kosong → avatar menampilkan ikon user.

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({
    super.key,
    @visibleForTesting this.initialName,
    @visibleForTesting this.initialEmail,
  });

  /// Hanya untuk test: nilai awal pengganti metadata Auth Supabase.
  /// Produksi selalu `const EditProfileScreen()`.
  final String? initialName;
  final String? initialEmail;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    String initialName = widget.initialName ?? '';
    String initialEmail = widget.initialEmail ?? '';

    if (widget.initialName == null && widget.initialEmail == null) {
      // ISI DATA LANGSUNG (Synchronous) dari Metadata Auth supaya textfield
      // tidak kosong saat layar dibuka. Data terbaru dari tabel `profiles`
      // disinkronkan lewat ref.listen di build().
      final user = Supabase.instance.client.auth.currentUser;
      initialName = user?.userMetadata?['name'] ?? '';
      initialEmail = user?.email ?? '';
    }

    _nameController = TextEditingController(text: initialName);
    _emailController = TextEditingController(text: initialEmail);
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

    ref.listen<EditProfileState>(editProfileProvider, (previous, next) {
      if (next.latestName != null && _nameController.text != next.latestName) {
        _nameController.text = next.latestName!;
      }
    });

    final isLoading = state.isSaving;

    return AppPageScaffold(
      title: 'Edit Profil',
      backLabel: 'Pengaturan',
      titleWidget: _ProfileHeader(controller: _nameController),
      bottomBar: AppPrimaryButton(
        label: 'Simpan Perubahan',
        color: AppColors.textPrimary,
        loading: isLoading,
        onPressed: isLoading ? null : _updateProfile,
      ),
      children: [
        AppGroupedSection(
          children: [
            AppListRow(
              leading: const Icon(
                PhosphorIconsRegular.envelope,
                color: AppColors.textSecondary,
                size: 22,
              ),
              title: 'Email',
              subtitle: _emailController.text,
              trailing: const Icon(
                PhosphorIconsRegular.lockSimple,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
            AppTextField(
              controller: _nameController,
              label: 'Nama Lengkap',
              hint: 'Masukkan nama kamu',
              icon: PhosphorIconsRegular.user,
            ),
          ],
        ),
      ],
    );
  }
}

/// Avatar inisial + judul "Edit Profil" (mockup), ikut berubah saat nama diketik.
class _ProfileHeader extends StatelessWidget {
  final TextEditingController controller;

  const _ProfileHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Center(
        heightFactor: 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final raw = initialsOf(value.text);
                final initials = raw == '?' ? '' : raw;
                return Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: initials.isEmpty
                      ? const Icon(PhosphorIconsFill.user, color: Colors.white, size: 44)
                      : Text(
                          initials,
                          style: AppTextStyles.title.copyWith(
                            color: Colors.white,
                            fontSize: 32,
                          ),
                        ),
                );
              },
            ),
            const SizedBox(height: 10),
            Text('Edit Profil', style: AppTextStyles.headline),
          ],
        ),
      ),
    );
  }
}
