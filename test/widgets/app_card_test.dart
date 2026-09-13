import 'package:catat_uang_app/theme/app_forui_theme.dart';
import 'package:catat_uang_app/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

void main() {
  testWidgets('AppCard menampilkan child-nya', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: const Scaffold(
          body: AppCard(child: Text('Isi kartu')),
        ),
      ),
    );

    expect(find.text('Isi kartu'), findsOneWidget);
  });

  testWidgets('AppCard menampilkan title dan subtitle jika diberikan', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: const Scaffold(
          body: AppCard(
            title: Text('Judul'),
            subtitle: Text('Subjudul'),
            child: Text('Isi'),
          ),
        ),
      ),
    );

    expect(find.text('Judul'), findsOneWidget);
    expect(find.text('Subjudul'), findsOneWidget);
    expect(find.text('Isi'), findsOneWidget);
  });
}
