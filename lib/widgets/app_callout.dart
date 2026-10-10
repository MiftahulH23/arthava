import 'package:arthava/core/colors.dart';
import 'package:arthava/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

enum AppCalloutTone { info, accent }

/// Kotak info/saran (info Zakat, rekomendasi nabung Target).
class AppCallout extends StatelessWidget {
  const AppCallout({required this.icon, required this.child, this.tone = AppCalloutTone.info, super.key});

  final IconData icon;
  final Widget child;
  final AppCalloutTone tone;

  @override
  Widget build(BuildContext context) {
    final isInfo = tone == AppCalloutTone.info;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isInfo ? AppColors.primarySoft : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: isInfo ? AppColors.primary : AppColors.tintOrange),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle(
              style: AppTextStyles.subhead.copyWith(color: AppColors.textPrimary, height: 1.45),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
