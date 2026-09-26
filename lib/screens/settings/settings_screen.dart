import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/edit_profile/edit_profile_screen.dart';
import 'package:catat_uang_app/screens/login/login_screen.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/screens/settings/include_min_balance_row.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// StatelessWidget: layar ini tidak punya state lokal — hanya satu aksi
// one-shot (_logout). Switch saldo minimal (Plan B3) adalah ConsumerWidget
// mandiri. Catatan koordinator: B3 Task 9 menyisipkan IncludeMinBalanceRow
// di layar lama dalam AppGroupedSection sementara — kode build() di bawah
// menggantikannya; pastikan baris itu hanya muncul sekali (di _generalRows).
// Task 5b nanti mengubah class ini jadi StatefulWidget untuk switch biometrik.
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
