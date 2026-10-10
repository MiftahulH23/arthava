import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/widgets/app_swipe_actions.dart';
import 'package:catat_uang_app/widgets/app_swipe_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

class _Host extends StatefulWidget {
  const _Host({this.withRow = false});
  final bool withRow;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppSwipeTabs(
          index: tab,
          count: 2,
          onChanged: (i) => setState(() => tab = i),
          child: ListView(
            children: [
              AppSegmentedControl(labels: const ['A', 'B'], selectedIndex: tab, onChanged: (i) => setState(() => tab = i)),
              const SizedBox(height: 40, child: Text('judul')),
              AppSwipeTabBody(
                child: Column(children: [
                  Text('isi $tab'),
                  if (widget.withRow)
                    // Selebar layar seperti baris sungguhan (bukan selebar teks).
                    AppSwipeActions(
                      onDelete: () {},
                      child: const SizedBox(height: 60, width: double.infinity, child: Text('baris')),
                    ),
                  const SizedBox(height: 400),
                ]),
              ),
            ],
          ),
        ),
      );
}

class _FormHost extends StatefulWidget {
  const _FormHost({required this.formKey});
  final GlobalKey formKey;
  @override
  State<_FormHost> createState() => _FormHostState();
}

class _FormHostState extends State<_FormHost> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppSwipeTabs(
          index: tab,
          count: 2,
          onChanged: (i) => setState(() => tab = i),
          child: AppSwipeTabBody(
            keyByIndex: false,
            child: SizedBox(key: widget.formKey, height: 300, child: Text('form $tab')),
          ),
        ),
      );
}

void main() {
  testWidgets('geser kiri pendek: tetap di tab yang sama', (tester) async {
    await pumpApp(tester, const _Host());
    await tester.timedDrag(find.text('judul'), const Offset(-60, 0), const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('isi 0'), findsOneWidget);
  });

  testWidgets('geser kiri jauh: pindah ke tab berikutnya', (tester) async {
    await pumpApp(tester, const _Host());
    await tester.timedDrag(find.text('judul'), const Offset(-200, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('isi 1'), findsOneWidget);
  });

  testWidgets('fling cepat pendek tetap pindah tab', (tester) async {
    await pumpApp(tester, const _Host());
    await tester.fling(find.text('judul'), const Offset(-70, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text('isi 1'), findsOneWidget);
  });

  testWidgets('di tab terakhir geser kiri tidak pindah; geser kanan kembali', (tester) async {
    await pumpApp(tester, const _Host());
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    await tester.timedDrag(find.text('judul'), const Offset(-250, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('isi 1'), findsOneWidget);
    await tester.timedDrag(find.text('judul'), const Offset(250, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('isi 0'), findsOneWidget);
  });

  testWidgets('scroll vertikal tidak memindah tab', (tester) async {
    await pumpApp(tester, const _Host());
    await tester.drag(find.text('judul'), const Offset(-30, -300));
    await tester.pumpAndSettle();
    expect(find.text('isi 0'), findsOneWidget);
  });

  testWidgets('geser di atas data membuka Hapus, bukan pindah tab', (tester) async {
    await pumpApp(tester, const _Host(withRow: true));
    await tester.drag(find.text('baris'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Hapus'), findsOneWidget);
    expect(find.text('isi 0'), findsOneWidget);
  });

  testWidgets('selama drag penanda segmented ikut bergeser dan isi ikut tertarik', (tester) async {
    await pumpApp(tester, const _Host());
    final thumb = find.descendant(of: find.byKey(const ValueKey('segmented-thumb')), matching: find.byType(DecoratedBox)).first;
    final x0 = tester.getRect(thumb).left;
    final bodyX0 = tester.getTopLeft(find.text('isi 0')).dx;
    final gesture = await tester.startGesture(tester.getCenter(find.text('judul')));
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(thumb).left, greaterThan(x0));
    expect(tester.getTopLeft(find.text('isi 0')).dx, lessThan(bodyX0));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('keyByIndex false: state isi tidak dibuat ulang saat pindah tab', (tester) async {
    final key = GlobalKey();
    await pumpApp(tester, _FormHost(formKey: key));
    final before = key.currentContext;
    await tester.timedDrag(find.text('form 0'), const Offset(-250, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('form 1'), findsOneWidget);
    expect(identical(key.currentContext, before), isTrue);
  });

  testWidgets('lemparan berlawanan arah geser membatalkan pindah tab', (tester) async {
    await pumpApp(tester, const _Host());
    final gesture = await tester.startGesture(tester.getCenter(find.text('judul')));
    await gesture.moveBy(const Offset(-20, 0), timeStamp: const Duration(milliseconds: 10));
    await gesture.moveBy(const Offset(-180, 0), timeStamp: const Duration(milliseconds: 600));
    for (var i = 1; i <= 4; i++) {
      await gesture.moveBy(const Offset(8, 0), timeStamp: Duration(milliseconds: 600 + i * 10));
    }
    await gesture.up(timeStamp: const Duration(milliseconds: 645));
    await tester.pumpAndSettle();
    expect(find.text('isi 0'), findsOneWidget);
  });

  testWidgets('parent yang mengabaikan onChanged: isi kembali ke posisi semula', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: AppSwipeTabs(
          index: 0,
          count: 2,
          onChanged: (_) {},
          child: ListView(children: const [
            SizedBox(height: 40, child: Text('judul')),
            AppSwipeTabBody(child: Text('isi')),
          ]),
        ),
      ),
    );
    final x0 = tester.getTopLeft(find.text('isi')).dx;
    await tester.timedDrag(find.text('judul'), const Offset(-250, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('isi')).dx, x0);
  });
}
