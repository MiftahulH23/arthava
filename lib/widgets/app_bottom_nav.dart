import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Satu item navigasi di [AppBottomNav].
///
/// [icon] adalah path data hugeicons ([List<List<dynamic>>]), dirender
/// lewat widget [HugeIcon] — bukan [IconData]/[Icon] biasa. Paket
/// hugeicons hanya menyediakan satu gaya (`strokeRounded`), jadi tidak
/// ada lagi pasangan Fill/Regular seperti PhosphorIcons dulu: status
/// aktif/tidak aktif kini murni dibedakan lewat warna (dan opsional
/// stroke yang lebih tebal saat aktif), bukan bentuk ikon yang berbeda.
///
/// [activeColor] opsional — override warna saat item ini aktif. Dipakai
/// untuk mempertahankan pewarnaan semantik per-tab yang sudah ada di
/// bottom nav lama (misal tab "Pemasukan" berwarna hijau/income, tab
/// "Pengeluaran" berwarna merah/expense), bukan warna primary yang sama
/// untuk semua tab.
class AppBottomNavItem {
  final List<List<dynamic>> icon;
  final Color? activeColor;

  const AppBottomNavItem({required this.icon, this.activeColor});
}

/// Floating pill bottom navigation standar aplikasi.
///
/// Beda dari AppCard/AppButton/dll, widget ini TIDAK membungkus primitive
/// forui tertentu — dibangun dari widget Flutter dasar (Container + Row),
/// karena forui 0.17.0 tidak punya primitive floating-bottom-nav siap
/// pakai (diverifikasi terhadap source forui yang terpasang saat komponen
/// ini pertama dibuat). Warna non-aktif & background pill mengikuti
/// [AppColors]; warna aktif per-item bisa di-override lewat
/// [AppBottomNavItem.activeColor].
class AppBottomNav extends StatelessWidget {
  final List<AppBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const AppBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < items.length; i++) _buildItem(context, i),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final item = items[index];
    final isSelected = index == selectedIndex;
    final activeColor = item.activeColor ?? AppColors.primary;

    return GestureDetector(
      onTap: () => onChanged(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.12) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: HugeIcon(
          icon: item.icon,
          color: isSelected ? activeColor : AppColors.textSecondary,
          size: 24,
          strokeWidth: isSelected ? 2.2 : 1.8,
        ),
      ),
    );
  }
}
