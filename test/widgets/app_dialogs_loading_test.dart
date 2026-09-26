import 'dart:async';

import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext ctx;
    await pumpApp(tester, Builder(builder: (c) {
      ctx = c;
      return const Scaffold(body: SizedBox());
    }));
    return ctx;
  }

  testWidgets('HUD tampil selama tugas berjalan lalu hilang, hasil diteruskan', (tester) async {
    final ctx = await pumpHost(tester);
    final gate = Completer<int>();
    final result = runWithAppLoading(ctx, () => gate.future, message: 'Membaca struk...');
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.text('Membaca struk...'), findsOneWidget);
    gate.complete(7);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(await result, 7);
  });

  testWidgets('tugas selesai sebelum frame pertama: HUD tidak nyangkut', (tester) async {
    final ctx = await pumpHost(tester);
    final value = await runWithAppLoading(ctx, () async => 'cepat');
    await tester.pumpAndSettle();
    expect(value, 'cepat');
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });

  testWidgets('tugas melempar: HUD tertutup dan error diteruskan', (tester) async {
    final ctx = await pumpHost(tester);
    Object? caught;
    try {
      await runWithAppLoading<void>(ctx, () async => throw StateError('gagal'));
    } catch (e) {
      caught = e;
    }
    await tester.pumpAndSettle();
    expect(caught, isA<StateError>());
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });

  testWidgets('tombol kembali tidak menutup HUD', (tester) async {
    final ctx = await pumpHost(tester);
    final gate = Completer<void>();
    unawaited(runWithAppLoading(ctx, () => gate.future));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
  });
}
