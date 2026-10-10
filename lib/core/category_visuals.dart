import 'package:arthava/core/colors.dart';
import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Ikon kategori berdasarkan kata kunci nama (dipindah dari
/// InputTransactionScreen._getCategoryIcon, perilaku sama persis).
IconData categoryIcon(String categoryName) {
  final name = categoryName.toLowerCase();
  if (name.contains('makan')) return PhosphorIcons.bowlFood(PhosphorIconsStyle.fill);
  if (name.contains('minum') || name.contains('kopi') || name.contains('cafe')) {
    return PhosphorIcons.coffee(PhosphorIconsStyle.fill);
  }
  if (name.contains('transport') || name.contains('bensin')) {
    return PhosphorIcons.bus(PhosphorIconsStyle.fill);
  }
  if (name.contains('belanja') || name.contains('mart')) {
    return PhosphorIcons.shoppingBag(PhosphorIconsStyle.fill);
  }
  if (name.contains('hiburan') || name.contains('nonton')) {
    return PhosphorIcons.gameController(PhosphorIconsStyle.fill);
  }
  if (name.contains('kesehatan') || name.contains('obat')) {
    return PhosphorIcons.firstAid(PhosphorIconsStyle.fill);
  }
  if (name.contains('tagihan') || name.contains('listrik')) {
    return PhosphorIcons.lightning(PhosphorIconsStyle.fill);
  }
  if (name.contains('gaji')) return PhosphorIcons.money(PhosphorIconsStyle.fill);
  if (name.contains('bonus')) return PhosphorIcons.gift(PhosphorIconsStyle.fill);
  if (name.contains('tabung')) return PhosphorIcons.bank(PhosphorIconsStyle.fill);
  return PhosphorIcons.tag(PhosphorIconsStyle.fill);
}

/// Warna tint ikon kategori (spec §4.1). Kategori tak dikenal = primary.
Color categoryColor(String categoryName) {
  final name = categoryName.toLowerCase();
  if (name.contains('makan')) return AppColors.tintOrange;
  if (name.contains('minum') || name.contains('kopi') || name.contains('cafe')) {
    return AppColors.tintBrown;
  }
  if (name.contains('transport') || name.contains('bensin')) return AppColors.tintBlue;
  if (name.contains('belanja') || name.contains('mart')) return AppColors.tintPink;
  if (name.contains('hiburan') || name.contains('nonton')) return AppColors.tintIndigo;
  if (name.contains('kesehatan') || name.contains('obat')) return AppColors.tintRed;
  if (name.contains('tagihan') || name.contains('listrik')) return AppColors.tintAmber;
  if (name.contains('gaji')) return AppColors.tintGreen;
  if (name.contains('bonus')) return AppColors.tintSky;
  if (name.contains('tabung')) return AppColors.tintTeal;
  return AppColors.primary;
}
