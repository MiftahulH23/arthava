import 'package:catat_uang_app/screens/ai_advisor/ai_advisor_screen.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

// Seam: _supabase getter → _fetchFinancialContext gagal di dalam try/catch
// miliknya sendiri. GeminiService tidak dipanggil (tidak ada pesan terkirim).
void main() {
  setUp(() => AiSessionManager().clearSession());

  testWidgets('menampilkan judul tengah dan salam Gemi', (tester) async {
    await pumpApp(tester, const AiAdvisorScreen());
    await tester.pump();

    expect(find.byType(AppPageScaffold), findsOneWidget);
    // `title: 'AI Advisor'` juga bisa dirender AppPageScaffold (mis. semantics),
    // jadi cukup pastikan minimal satu.
    expect(find.text('AI Advisor'), findsAtLeastNWidgets(1));
    expect(find.text('Gemi - Siap bantu atur duitmu!'), findsOneWidget);
    expect(find.textContaining('Aku Gemi', findRichText: true), findsOneWidget);
    expect(find.text('Tanya soal keuanganmu...'), findsOneWidget);
  });

  testWidgets('kirim kosong tidak menambah bubble', (tester) async {
    await pumpApp(tester, const AiAdvisorScreen());
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Kirim'));
    await tester.pump();

    expect(find.byType(MarkdownBody), findsOneWidget); // hanya salam
    expect(find.text('Gemi sedang menganalisa...'), findsNothing);
  });

  testWidgets('reset sesi menampilkan salam lagi dan toast', (tester) async {
    await pumpApp(tester, const AiAdvisorScreen());
    await tester.pump();

    await tester.tap(find.byTooltip('Mulai Chat Baru'));
    await tester.pump();

    expect(find.text('Sesi chat diulang!'), findsOneWidget);
    expect(find.textContaining('Aku Gemi', findRichText: true), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
