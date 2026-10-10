import 'package:arthava/core/colors.dart';
import 'package:flutter/material.dart';

/// Satu item navigasi di [AppBottomNav].
///
/// [activeIcon] opsional — dipakai saat item ini aktif, biasanya varian
/// "fill" dari [icon] (mengikuti pola PhosphorIcons regular/fill yang
/// sudah dipakai di project ini). Kalau tidak diberikan, [icon] dipakai
/// terus baik aktif maupun tidak.
///
/// [activeColor] opsional — override warna saat item ini aktif; default
/// [AppColors.primary].
class AppBottomNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final Color? activeColor;

  const AppBottomNavItem({required this.icon, this.activeIcon, this.activeColor});
}

/// Floating pill bottom navigation standar aplikasi.
///
/// Widget ini TIDAK membungkus primitive
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
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i != 0) const SizedBox(width: 4),
            _buildItem(context, i),
          ],
        ],
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
        child: Icon(
          isSelected ? (item.activeIcon ?? item.icon) : item.icon,
          color: isSelected ? activeColor : AppColors.textSecondary,
          size: 24,
        ),
      ),
    );
  }
}
