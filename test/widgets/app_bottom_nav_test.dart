import 'package:arthava/theme/app_forui_theme.dart';
import 'package:arthava/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

void main() {
  final items = const [
    AppBottomNavItem(icon: PhosphorIconsRegular.house, activeIcon: PhosphorIconsFill.house),
    AppBottomNavItem(icon: PhosphorIconsRegular.wallet, activeIcon: PhosphorIconsFill.wallet),
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
    expect(find.byIcon(PhosphorIconsFill.house), findsOneWidget); // item aktif pakai activeIcon
    expect(find.byIcon(PhosphorIconsRegular.wallet), findsOneWidget); // item tidak aktif pakai icon biasa
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

    await tester.tap(find.byIcon(PhosphorIconsRegular.wallet));
    await tester.pump();

    expect(tappedIndex, 1);
  });

  testWidgets('AppBottomNav memakai activeColor kustom untuk item aktif jika diberikan', (tester) async {
    final coloredItems = const [
      AppBottomNavItem(icon: PhosphorIconsRegular.house),
      AppBottomNavItem(icon: PhosphorIconsRegular.wallet, activeColor: Colors.red),
    ];

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: Scaffold(
          body: AppBottomNav(items: coloredItems, selectedIndex: 1, onChanged: (_) {}),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(PhosphorIconsRegular.wallet));
    expect(icon.color, Colors.red);
  });
}
