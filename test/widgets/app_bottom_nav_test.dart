import 'package:catat_uang_app/theme/app_forui_theme.dart';
import 'package:catat_uang_app/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hugeicons/hugeicons.dart';

void main() {
  final items = const [
    AppBottomNavItem(icon: HugeIcons.strokeRoundedHome01),
    AppBottomNavItem(icon: HugeIcons.strokeRoundedWallet01),
  ];

  testWidgets('AppBottomNav menampilkan semua item', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: Scaffold(
          body: AppBottomNav(items: items, selectedIndex: 0, onChanged: (_) {}),
        ),
      ),
    );

    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(find.byType(HugeIcon), findsNWidgets(2));
  });

  testWidgets('AppBottomNav memanggil onChanged dengan index yang benar saat item ditap', (tester) async {
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: Scaffold(
          body: AppBottomNav(
            items: items,
            selectedIndex: 0,
            onChanged: (index) => tappedIndex = index,
          ),
        ),
      ),
    );

    final icons = tester.widgetList<HugeIcon>(find.byType(HugeIcon)).toList();
    final walletIndex = icons.indexWhere((i) => i.icon == HugeIcons.strokeRoundedWallet01);
    await tester.tap(find.byType(HugeIcon).at(walletIndex));
    await tester.pump();

    expect(tappedIndex, 1);
  });

  testWidgets('AppBottomNav memakai activeColor kustom untuk item aktif jika diberikan', (tester) async {
    final coloredItems = const [
      AppBottomNavItem(icon: HugeIcons.strokeRoundedHome01),
      AppBottomNavItem(icon: HugeIcons.strokeRoundedWallet01, activeColor: Colors.red),
    ];

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: Scaffold(
          body: AppBottomNav(items: coloredItems, selectedIndex: 1, onChanged: (_) {}),
        ),
      ),
    );

    final icons = tester.widgetList<HugeIcon>(find.byType(HugeIcon)).toList();
    final activeIcon = icons.firstWhere((i) => i.icon == HugeIcons.strokeRoundedWallet01);
    expect(activeIcon.color, Colors.red);
  });
}
