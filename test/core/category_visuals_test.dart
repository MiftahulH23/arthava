import 'package:catat_uang_app/core/category_visuals.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

void main() {
  test('categoryIcon memetakan kata kunci seperti _getCategoryIcon lama', () {
    expect(categoryIcon('Makan Siang'), PhosphorIcons.bowlFood(PhosphorIconsStyle.fill));
    expect(categoryIcon('Kopi'), PhosphorIcons.coffee(PhosphorIconsStyle.fill));
    expect(categoryIcon('Bensin'), PhosphorIcons.bus(PhosphorIconsStyle.fill));
    expect(categoryIcon('Indomart'), PhosphorIcons.shoppingBag(PhosphorIconsStyle.fill));
    expect(categoryIcon('Nonton'), PhosphorIcons.gameController(PhosphorIconsStyle.fill));
    expect(categoryIcon('Obat'), PhosphorIcons.firstAid(PhosphorIconsStyle.fill));
    expect(categoryIcon('Tagihan Listrik'), PhosphorIcons.lightning(PhosphorIconsStyle.fill));
    expect(categoryIcon('Gaji'), PhosphorIcons.money(PhosphorIconsStyle.fill));
    expect(categoryIcon('Bonus'), PhosphorIcons.gift(PhosphorIconsStyle.fill));
    expect(categoryIcon('Tabungan'), PhosphorIcons.bank(PhosphorIconsStyle.fill));
    expect(categoryIcon('Lainnya'), PhosphorIcons.tag(PhosphorIconsStyle.fill));
  });

  test('categoryColor memakai tint AppColors, default primary', () {
    expect(categoryColor('Makan'), AppColors.tintOrange);
    expect(categoryColor('Transportasi'), AppColors.tintBlue);
    expect(categoryColor('Tagihan Listrik'), AppColors.tintAmber);
    expect(categoryColor('Gaji'), AppColors.tintGreen);
    expect(categoryColor('Tabungan'), AppColors.tintTeal);
    expect(categoryColor('Sesuatu Baru'), AppColors.primary);
  });
}
