import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_swipe_tabs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Segmented control gaya kapsul iOS. Controlled: parent memegang
/// [selectedIndex]. Penanda putih meluncur ke segmen terpilih; bila
/// [position] (0..n-1, boleh pecahan) diberikan, penanda mengikuti nilai itu
/// langsung — dipakai saat layar sedang digeser (lihat `AppSwipeTabs`).
class AppSegmentedControl extends StatelessWidget {
  const AppSegmentedControl({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.selectedLabelColors,
    this.position,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<Color>? selectedLabelColors;
  final ValueListenable<double>? position;

  static const double _height = 36;
  static const double _pad = 3;

  Color _selectedColor(int i) {
    final colors = selectedLabelColors;
    if (colors != null && i < colors.length) return colors[i];
    return AppColors.textPrimary;
  }

  Widget _thumb(double pos) {
    final n = labels.length;
    final x = n <= 1 ? 0.0 : -1 + 2 * (pos.clamp(0, n - 1) / (n - 1));
    // Pecahan = sedang digeser jari: ikut langsung tanpa animasi.
    final dragging = pos != pos.roundToDouble();
    return AnimatedAlign(
      key: const ValueKey('segmented-thumb'),
      alignment: Alignment(x, 0),
      duration: dragging ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: FractionallySizedBox(
        widthFactor: 1 / n,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.10), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Kopling implisit: tanpa [position], kontrol ini mengikuti geser halaman
    // milik `AppSwipeTabs` terdekat di atasnya bila jumlah tabnya sama. Kontrol
    // dengan jumlah opsi sama yang bukan penanda tab halaman harus diberi
    // [position] sendiri atau ditaruh di luar `AppSwipeTabs`.
    final listenable = position ?? AppSwipeTabs.maybePositionOf(context, labels.length);
    return Container(
      height: _height,
      padding: const EdgeInsets.all(_pad),
      decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(999)),
      child: Stack(
        children: [
          Positioned.fill(
            child: listenable == null
                ? _thumb(selectedIndex.toDouble())
                : ValueListenableBuilder<double>(valueListenable: listenable, builder: (_, pos, _) => _thumb(pos)),
          ),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selectedIndex,
                    inMutuallyExclusiveGroup: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (i != selectedIndex) onChanged(i);
                      },
                      child: Center(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subhead.copyWith(
                            fontWeight: i == selectedIndex ? FontWeight.w700 : FontWeight.w600,
                            color: i == selectedIndex ? _selectedColor(i) : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
