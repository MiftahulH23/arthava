import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Segmented control iOS (spec G6). Controlled: parent memegang [selectedIndex].
class AppSegmentedControl extends StatelessWidget {
  const AppSegmentedControl({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.selectedLabelColors,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<Color>? selectedLabelColors;

  Color _selectedColor(int i) {
    final colors = selectedLabelColors;
    if (colors != null && i < colors.length) return colors[i];
    return AppColors.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (i != selectedIndex) onChanged(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selectedIndex ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: i == selectedIndex
                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 4, offset: const Offset(0, 1))]
                          : null,
                    ),
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subhead.copyWith(
                        fontWeight: FontWeight.w600,
                        color: i == selectedIndex ? _selectedColor(i) : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
