import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:arthava/core/colors.dart';
import 'package:arthava/theme/app_forui_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Screenshot layar dengan font & ikon ASLI, untuk dicocokkan dengan mockup
/// (docs/design/dompetku-redesign-mockup.html). Font Plus Jakarta Sans diunduh
/// sekali lewat `tool/screenshots/fetch_fonts.sh` ke `.dart_tool/screenshot_fonts`
/// (test di-skip bila belum ada). PNG ditulis ke `build/screenshots/`.
const String screenshotFontDir = '.dart_tool/screenshot_fonts';

bool get screenshotFontsAvailable => File('$screenshotFontDir/PlusJakartaSans_700.ttf').existsSync();

final GlobalKey _boundaryKey = GlobalKey();

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final file = File(path);
    if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}

String? _packageRoot(String package) {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;
  final packages = (jsonDecode(config.readAsStringSync())['packages'] as List).cast<Map<String, dynamic>>();
  final entry = packages.where((p) => p['name'] == package).firstOrNull;
  if (entry == null) return null;
  return Uri.parse(entry['rootUri'] as String).toFilePath();
}

/// Memuat Plus Jakarta Sans (nama family persis seperti yang dipakai
/// google_fonts: `PlusJakartaSans_700`), ikon Phosphor, Material Icons, dan Roboto.
Future<void> loadRealFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final w in [400, 500, 600, 700, 800]) {
      await _loadFont('PlusJakartaSans_$w', ['$screenshotFontDir/PlusJakartaSans_$w.ttf']);
    }
    final phosphor = _packageRoot('phosphor_flutter');
    if (phosphor != null) {
      for (final (family, file) in [
        ('PhosphorRegular', 'Phosphor.ttf'),
        ('PhosphorFill', 'Phosphor-Fill.ttf'),
        ('PhosphorBold', 'Phosphor-Bold.ttf'),
      ]) {
        await _loadFont('packages/phosphor_flutter/$family', ['$phosphor/lib/fonts/$file']);
      }
    }
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final material = '$flutterRoot/bin/cache/artifacts/material_fonts';
      await _loadFont('MaterialIcons', ['$material/materialicons-regular.otf']);
      await _loadFont('Roboto', ['$material/roboto-regular.ttf', '$material/roboto-medium.ttf', '$material/roboto-bold.ttf']);
    }
  });
}

/// Seperti `pumpApp`, ditambah RepaintBoundary untuk diambil gambarnya.
Future<void> pumpScreen(
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
    RepaintBoundary(
      key: _boundaryKey,
      child: ProviderScope(
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
    ),
  );
  await tester.pump();
}

/// Menyimpan tampilan saat ini ke `build/screenshots/<name>.png` (skala 2x).
Future<File> saveScreenshot(WidgetTester tester, String name) async {
  await tester.pump();
  late File file;
  await tester.runAsync(() async {
    final boundary = _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    file = File('build/screenshots/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  return file;
}
