import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Nominal besar di tengah (read-only), mis. "Jumlah Uang" di sheet.
class AppAmountDisplay extends StatelessWidget {
  const AppAmountDisplay({required this.label, required this.amountText, this.color, this.below, super.key});

  final String label;
  final String amountText;
  final Color? color;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            amountText,
            maxLines: 1,
            style: AppTextStyles.amountLarge.copyWith(color: color ?? AppColors.textPrimary),
          ),
        ),
        if (below != null) ...[const SizedBox(height: 8), below!],
      ],
    );
  }
}

/// Input nominal besar di tengah dengan prefix "Rp" dan titik ribuan otomatis.
class AppAmountField extends StatelessWidget {
  const AppAmountField({
    required this.controller,
    required this.label,
    this.color,
    this.autofocus = false,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final Color? color;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.amountLarge.copyWith(color: color ?? AppColors.textPrimary);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          autofocus: autofocus,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          inputFormatters: [RupiahInputFormatter()],
          textAlign: TextAlign.center,
          style: style,
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            hintText: '0',
            hintStyle: style.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5)),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text('Rp', style: style.copyWith(fontSize: 28, color: AppColors.textSecondary)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
        ),
      ],
    );
  }
}
