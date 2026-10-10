import 'package:arthava/screens/ai_advisor/ai_advisor_screen.dart';
import 'package:arthava/widgets/app_page_scaffold.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

// Seam: _supabase getter → _fetchFinancialContext gagal di dalam try/catch
// miliknya sendiri. GeminiService tidak dipanggil (tidak ada pesan terkirim).
void main() {
  setUp(() => AiSessionManager().clearSession());

  testWidgets('menampilkan judul tengah dan salam asisten', (tester) async {
    await pumpApp(tester, const AiAdvisorScreen());
    await tester.pump();

    expect(find.byType(AppPageScaffold), findsOneWidget);
    // `title: 'Tanya AI'` juga bisa dirender AppPageScaffold (mis. semantics),
    // jadi cukup pastikan minimal satu.
    expect(find.text('Tanya AI'), findsAtLeastNWidgets(1));
    expect(find.text('Siap bantu atur duitmu!'), findsOneWidget);
    expect(find.textContaining('Gemi', findRichText: true), findsNothing);
    expect(find.textContaining('Aku asisten keuanganmu', findRichText: true), findsOneWidget);
    expect(find.text('Tanya soal keuanganmu...'), findsOneWidget);
  });

  testWidgets('kirim kosong tidak menambah bubble', (tester) async {
    await pumpApp(tester, const AiAdvisorScreen());
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Kirim'));
    await tester.pump();

    expect(find.byType(MarkdownBody), findsOneWidget); // hanya salam
    expect(find.text('AI sedang menganalisa...'), findsNothing);
  });

  testWidgets('reset sesi menampilkan salam lagi dan toast', (tester) async {
    await pumpApp(tester, const AiAdvisorScreen());
    await tester.pump();

    await tester.tap(find.byTooltip('Mulai Chat Baru'));
    await tester.pump();

    expect(find.text('Sesi chat diulang!'), findsOneWidget);
    expect(find.textContaining('Aku asisten keuanganmu', findRichText: true), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
