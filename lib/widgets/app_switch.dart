import 'package:arthava/core/colors.dart';
import 'package:flutter/cupertino.dart';

/// Switch gaya iOS; aktif = hijau income.
class AppSwitch extends StatelessWidget {
  const AppSwitch({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSwitch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.income,
      inactiveTrackColor: AppColors.track,
    );
  }
}
