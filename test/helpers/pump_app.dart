import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_forui_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Memompa [child] seperti di aplikasi: ProviderScope (dengan [overrides]),
/// MaterialApp locale id_ID + delegasi lokalisasi, FTheme(appForuiTheme),
/// dan ukuran layar HP [size] (logical pixel, devicePixelRatio 1).
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Size size = const Size(390, 844),
}) async {
  await initializeDateFormatting('id_ID', null);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          scaffoldBackgroundColor: AppColors.background,
        ),
        builder: (context, navChild) => FTheme(data: appForuiTheme, child: navChild!),
        home: child,
      ),
    ),
  );
  await tester.pump();
}
