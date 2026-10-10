# Tab Kapsul, Geser Tab, Geser Hapus — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lima perbaikan hasil uji HP: keyboard tertutup saat memilih, garis fokus isian utuh, tab bergaya kapsul, pindah tab dengan geser layar, dan hapus dengan geser data.

**Architecture:** Perubahan dipusatkan di widget bersama (`showAppBottomSheet`, `AppTextField`, `AppSegmentedControl`, `AppSwipeActions`) ditambah satu widget baru `AppSwipeTabs`/`AppSwipeTabBody`. Layar hanya membungkus kontennya. Logika hapus tiap layar dipakai apa adanya. Untuk utang, logikanya dipindah ke helper bersama `confirmAndDeleteDebt` supaya daftar dan detail memakai dialog yang sama.

**Tech Stack:** Flutter 3.38.5, Riverpod 2.6.1, phosphor_flutter, flutter_test. Tanpa dependensi baru.

**Spec:** `docs/superpowers/specs/2026-10-10-tabs-swipe-design.md`

## Global Constraints

- Tidak ada perubahan skema/RPC/provider. Dialog dan pesan hapus yang ada dipakai apa adanya.
- Warna hanya dari `AppColors`, teks dari `AppTextStyles`, ikon Phosphor. Tidak ada `Color(0x…)` di `lib/screens`/`lib/widgets`.
- Modal hanya lewat komponen bersama (`test/architecture/modal_consistency_test.dart`).
- Gaya tab: kapsul (radius 999), jalur `track`, penanda `surface`, tinggi 36, padding 3. Label tidak terpilih `textSecondary` w600, terpilih warna `selectedLabelColors[i]` atau `textPrimary` w700.
- Geser tab: pindah bila dilepas > 25% lebar atau kecepatan > 400 px/s. Ada tahanan 0.3 di tab pertama/terakhir.
- Geser di atas data (`AppSwipeActions`) membuka aksi, bukan pindah tab.
- Commit Conventional Commits, branch `feat/tabs-swipe`, tidak push tanpa diminta. Selesai = `flutter analyze` 0 error/warning + `flutter test` penuh (E2E lewat env `E2E_EMAIL`/`E2E_PASSWORD`, tidak pernah disimpan) lulus.

## Review Focus

1. Hapus utang dari daftar padahal cicilan belum dimuat → pilihan "kembalikan saldo" tetap muncul bila ada cicilan yang menyentuh dompet (Task 7).
2. Geser vertikal (scroll daftar) tidak boleh memindah tab, dan geser kecil diagonal tidak membuat layar bergetar (Task 5).
3. Isian yang sedang fokus di halaman lalu lembar dibuka dan dibatalkan → keyboard tetap tertutup (Task 1).
4. Tab Masuk/Daftar yang digeser tidak me-reset isian/permintaan yang sedang berjalan (Task 6, `keyByIndex: false`).
5. Kartu yang dibungkus `AppSwipeActions(borderRadius)` tetap bisa diketuk (buka detail/opsi) saat tertutup (Task 4 & 8).

---

### Task 1: Keyboard tertutup saat lembar pilihan dibuka

**Files:**
- Modify: `lib/widgets/app_bottom_sheet.dart`
- Test: `test/widgets/app_bottom_sheet_test.dart`

**Interfaces:**
- Produces: `showAppBottomSheet` melepas fokus utama sebelum lembar tampil.

- [ ] **Step 1: Tes gagal** — tambah ke `main()` di `test/widgets/app_bottom_sheet_test.dart` (import `package:catat_uang_app/widgets/app_bottom_sheet.dart` sudah ada; pastikan juga `flutter/material.dart`):

```dart
  testWidgets('membuka sheet melepas fokus isian; setelah ditutup keyboard tidak naik lagi', (tester) async {
    final controller = TextEditingController();
    final node = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(node.dispose);
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Column(children: [
            TextField(controller: controller, focusNode: node),
            TextButton(
              onPressed: () => showAppBottomSheet<void>(
                context: context,
                builder: (_) => const SizedBox(height: 200, child: Text('isi sheet')),
              ),
              child: const Text('buka'),
            ),
          ]),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(node.hasFocus, isTrue);

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('isi sheet'), findsOneWidget);
    expect(node.hasFocus, isFalse);

    Navigator.of(tester.element(find.text('isi sheet'))).pop();
    await tester.pumpAndSettle();
    expect(node.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });
```

- [ ] **Step 2: Jalankan** `flutter test test/widgets/app_bottom_sheet_test.dart` → FAIL (`node.hasFocus` masih `true`, atau fokus kembali setelah pop).

- [ ] **Step 3: Implementasi** — di `showAppBottomSheet`, sebelum `return showFSheet<T>(`:

```dart
  // Lembar pilihan (kategori, dompet, tanggal, …) tidak butuh keyboard: lepas
  // fokus dulu supaya keyboard turun dan tidak naik lagi saat lembar ditutup
  // (route bawah mengembalikan fokus ke node terakhir — kini tidak ada).
  FocusManager.instance.primaryFocus?.unfocus();
```

Tambahkan kalimat yang sama ke doc comment fungsi.

- [ ] **Step 4: Jalankan** `flutter test test/widgets/` → PASS.
- [ ] **Step 5: Commit** `fix(widgets): dismiss keyboard before opening any app sheet`.

---

### Task 2: Garis fokus isian selaras dengan kartu (radius 20)

**Files:**
- Modify: `lib/widgets/app_text_field.dart` (jalur non-outlined)
- Test: `test/widgets/app_text_field_test.dart`

**Interfaces:**
- Produces: `AppTextField` non-outlined memakai `OutlineInputBorder` radius 20 (sama dengan `AppGroupedSection`).

- [ ] **Step 1: Tes gagal** — tambahkan:

```dart
  testWidgets('isian biasa: sudut garis fokus 20 = radius kartu grouped section', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: AppTextField(controller: controller, hint: 'Catatan')));
    final deco = tester.widget<TextField>(find.byType(TextField)).decoration!;
    final focused = deco.focusedBorder! as OutlineInputBorder;
    expect(focused.borderRadius, BorderRadius.circular(20));
    expect(focused.borderSide.color, AppColors.primary);
    expect((deco.enabledBorder! as OutlineInputBorder).borderRadius, BorderRadius.circular(20));
  });
```

- [ ] **Step 2: Jalankan** `flutter test test/widgets/app_text_field_test.dart` → FAIL (radius 16).
- [ ] **Step 3: Implementasi** — di `build()` jalur biasa ganti `final radius = BorderRadius.circular(16);` → `BorderRadius.circular(20)`. Ubah doc comment kelas: "Default tanpa border (radius 20, sama dengan kartu `AppGroupedSection` supaya garis fokus tidak terpotong)".
- [ ] **Step 4: Jalankan** `flutter test test/widgets/ test/screens/` → PASS. Kalau ada tes yang memeriksa radius 16, sesuaikan ke 20 dan catat sebagai Ruling.
- [ ] **Step 5: Commit** `fix(widgets): match text field radius to grouped card so focus border is whole`.

---

### Task 3: `AppSegmentedControl` gaya kapsul + `position`

**Files:**
- Modify: `lib/widgets/app_segmented_control.dart`
- Test: `test/widgets/app_segmented_control_test.dart`

**Interfaces:**
- Consumes: `AppSwipeTabs.maybePositionOf(context, count)` dari Task 5. Untuk sementara, tes Task 3 hanya memakai parameter `position` eksplisit. Lookup otomatis ditambahkan di Task 5.
- Produces: `AppSegmentedControl({labels, selectedIndex, onChanged, selectedLabelColors, ValueListenable<double>? position})`. Penanda adalah satu `AnimatedAlign` dengan `key: const ValueKey('segmented-thumb')`.

- [ ] **Step 1: Tes gagal** — di `test/widgets/app_segmented_control_test.dart`:
  - ganti tes 'warna teks terpilih' baris terakhir menjadi `expect(tester.widget<Text>(find.text('Pemasukan')).style!.color, AppColors.textSecondary);`
  - tambahkan (import `package:flutter/foundation.dart`):

```dart
  testWidgets('jalur dan penanda berbentuk kapsul, penanda di segmen terpilih', (tester) async {
    await pumpApp(tester, Scaffold(body: Center(child: SizedBox(width: 300, child: AppSegmentedControl(
      labels: const ['Masuk', 'Daftar'], selectedIndex: 1, onChanged: (_) {},
    )))));
    await tester.pumpAndSettle();
    final track = tester.widget<Container>(find.descendant(
      of: find.byType(AppSegmentedControl), matching: find.byType(Container)).first);
    expect((track.decoration! as BoxDecoration).borderRadius, BorderRadius.circular(999));
    final thumb = find.byKey(const ValueKey('segmented-thumb'));
    final thumbBox = tester.getRect(find.descendant(of: thumb, matching: find.byType(DecoratedBox)).first);
    expect(thumbBox.center.dx, greaterThan(tester.getCenter(find.byType(AppSegmentedControl)).dx));
    expect(tester.widget<Text>(find.text('Daftar')).style!.fontWeight, FontWeight.w700);
  });

  testWidgets('position pecahan menggeser penanda di antara segmen', (tester) async {
    final position = ValueNotifier<double>(0);
    addTearDown(position.dispose);
    await pumpApp(tester, Scaffold(body: Center(child: SizedBox(width: 300, child: AppSegmentedControl(
      labels: const ['A', 'B'], selectedIndex: 0, onChanged: (_) {}, position: position,
    )))));
    await tester.pumpAndSettle();
    final thumb = find.descendant(of: find.byKey(const ValueKey('segmented-thumb')), matching: find.byType(DecoratedBox)).first;
    final x0 = tester.getRect(thumb).left;
    position.value = 0.5;
    await tester.pumpAndSettle();
    final xHalf = tester.getRect(thumb).left;
    position.value = 1;
    await tester.pumpAndSettle();
    final x1 = tester.getRect(thumb).left;
    expect(xHalf, greaterThan(x0));
    expect(x1, greaterThan(xHalf));
    expect((xHalf - (x0 + x1) / 2).abs(), lessThan(1));
  });
```

- [ ] **Step 2: Jalankan** `flutter test test/widgets/app_segmented_control_test.dart` → FAIL (`position` tidak ada; radius 10).

- [ ] **Step 3: Implementasi** — ganti isi file:

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Segmented control gaya kapsul iOS. Controlled: parent memegang
/// [selectedIndex]. Penanda putih meluncur ke segmen terpilih; bila
/// [position] (0..n-1, boleh pecahan) diberikan, penanda mengikuti nilai itu
/// langsung — dipakai saat layar sedang digeser (lihat `AppSwipeTabs`).
class AppSegmentedControl extends StatelessWidget {
  const AppSegmentedControl({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.selectedLabelColors,
    this.position,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<Color>? selectedLabelColors;
  final ValueListenable<double>? position;

  static const double _height = 36;
  static const double _pad = 3;

  Color _selectedColor(int i) {
    final colors = selectedLabelColors;
    if (colors != null && i < colors.length) return colors[i];
    return AppColors.textPrimary;
  }

  Widget _thumb(double pos) {
    final n = labels.length;
    final x = n <= 1 ? 0.0 : -1 + 2 * (pos.clamp(0, n - 1) / (n - 1));
    return AnimatedAlign(
      key: const ValueKey('segmented-thumb'),
      alignment: Alignment(x, 0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: FractionallySizedBox(
        widthFactor: 1 / n,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.10), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listenable = position;
    return Container(
      height: _height,
      padding: const EdgeInsets.all(_pad),
      decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(999)),
      child: Stack(
        children: [
          Positioned.fill(
            child: listenable == null
                ? _thumb(selectedIndex.toDouble())
                : ValueListenableBuilder<double>(valueListenable: listenable, builder: (_, pos, __) => _thumb(pos)),
          ),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selectedIndex,
                    inMutuallyExclusiveGroup: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (i != selectedIndex) onChanged(i);
                      },
                      child: Center(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subhead.copyWith(
                            fontWeight: i == selectedIndex ? FontWeight.w700 : FontWeight.w600,
                            color: i == selectedIndex ? _selectedColor(i) : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Jalankan** `flutter test test/widgets/ test/screens/` → PASS. Tes layar yang memeriksa warna label segmented tidak terpilih = `textPrimary` disesuaikan ke `textSecondary` (Ruling).
- [ ] **Step 5: Commit** `feat(widgets): capsule segmented control with sliding thumb`.

---

### Task 4: `AppSwipeActions` — `borderRadius` & `confirmDelete`

**Files:**
- Modify: `lib/widgets/app_swipe_actions.dart`
- Test: `test/widgets/app_swipe_actions_test.dart`

**Interfaces:**
- Produces: `AppSwipeActions({child, onEdit, onDelete, deleteConfirmTitle, deleteConfirmMessage, BorderRadius? borderRadius, bool confirmDelete = true})`.

- [ ] **Step 1: Tes gagal** — tambahkan:

```dart
  testWidgets('confirmDelete false: onDelete langsung dipanggil tanpa dialog bawaan', (tester) async {
    var deleted = 0;
    await pumpApp(tester, Scaffold(body: AppSwipeActions(
      onDelete: () => deleted++,
      confirmDelete: false,
      child: const ListTile(title: Text('Makan')),
    )));
    await tester.drag(find.text('Makan'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus?'), findsNothing);
    expect(deleted, 1);
  });

  testWidgets('borderRadius memotong baris sesuai radius kartu dan latar tidak putih', (tester) async {
    await pumpApp(tester, Scaffold(body: AppSwipeActions(
      onDelete: () {},
      borderRadius: BorderRadius.circular(24),
      child: const SizedBox(height: 80, child: Text('Kartu')),
    )));
    final clip = tester.widget<ClipRRect>(find.descendant(of: find.byType(AppSwipeActions), matching: find.byType(ClipRRect)).first);
    expect(clip.borderRadius, BorderRadius.circular(24));
    final material = tester.widget<Material>(find.descendant(of: find.byType(AppSwipeActions), matching: find.byType(Material)).first);
    expect(material.type, MaterialType.transparency);
  });

  testWidgets('kartu ber-borderRadius tetap bisa diketuk saat tertutup', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AppSwipeActions(
      onDelete: () {},
      borderRadius: BorderRadius.circular(24),
      child: GestureDetector(onTap: () => taps++, child: const SizedBox(height: 80, child: Text('Kartu'))),
    )));
    await tester.tap(find.text('Kartu'));
    expect(taps, 1);
  });
```

- [ ] **Step 2: Jalankan** `flutter test test/widgets/app_swipe_actions_test.dart` → FAIL (parameter tidak ada).

- [ ] **Step 3: Implementasi**:
  - Tambah field `final BorderRadius? borderRadius;` dan `final bool confirmDelete;` beserta parameter konstruktornya (`this.borderRadius, this.confirmDelete = true`). Docs:
    - `borderRadius`: "Potong baris mengikuti radius kartu (`AppSurfaceCard` = 24); null = siku (baris grouped list)."
    - `confirmDelete`: "false = [onDelete] dipanggil langsung; pemanggil menampilkan dialognya sendiri (mis. hapus utang dengan pilihan kembalikan saldo)."
  - `_handleDelete`:

```dart
  Future<void> _handleDelete() async {
    if (!widget.confirmDelete) {
      _close();
      widget.onDelete?.call();
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: widget.deleteConfirmTitle,
      message: widget.deleteConfirmMessage,
    );
    if (!mounted) return;
    _close();
    if (confirmed) widget.onDelete?.call();
  }
```

  - Di `build()`:
    - ganti `ClipRect(` dengan `widget.borderRadius == null ? ClipRect(child: stack) : ClipRRect(borderRadius: widget.borderRadius!, child: stack)`, dengan `stack` adalah `Stack` yang sudah ada;
    - `Material(color: AppColors.surface, …)` menjadi `Material(type: widget.borderRadius == null ? MaterialType.canvas : MaterialType.transparency, color: widget.borderRadius == null ? AppColors.surface : null, …)`. Kartu sudah putih sendiri; latar transparan mencegah sudut putih di atas latar abu.
- [ ] **Step 4: Jalankan** `flutter test test/widgets/app_swipe_actions_test.dart test/screens/` → PASS.
- [ ] **Step 5: Commit** `feat(widgets): swipe actions on rounded cards and caller-owned delete confirm`.

---

### Task 5: `AppSwipeTabs` + `AppSwipeTabBody`

**Files:**
- Create: `lib/widgets/app_swipe_tabs.dart`
- Modify: `lib/widgets/app_segmented_control.dart` (lookup otomatis `position`)
- Test: `test/widgets/app_swipe_tabs_test.dart`

**Interfaces:**
- Produces:
  - `AppSwipeTabs({required int index, required int count, required ValueChanged<int> onChanged, required Widget child})`
  - `static ValueListenable<double>? AppSwipeTabs.maybePositionOf(BuildContext context, int count)`: null bila tidak ada `AppSwipeTabs` di atas, atau `count` berbeda.
  - `AppSwipeTabBody({required Widget child, bool keyByIndex = true})`: ikut tertarik saat drag. Bila `keyByIndex`, isi baru meluncur masuk saat index berganti.
  - `AppSegmentedControl` tanpa `position` eksplisit memakai `AppSwipeTabs.maybePositionOf(context, labels.length)`.

- [ ] **Step 1: Tes gagal** — `test/widgets/app_swipe_tabs_test.dart`:

```dart
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
                    AppSwipeActions(onDelete: () {}, child: const SizedBox(height: 60, child: Text('baris'))),
                  const SizedBox(height: 400),
                ]),
              ),
            ],
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
    await pumpApp(tester, Scaffold(body: StatefulBuilder(builder: (context, setState) {
      var tab = 0;
      return AppSwipeTabs(
        index: tab,
        count: 2,
        onChanged: (i) => setState(() => tab = i),
        child: AppSwipeTabBody(keyByIndex: false, child: SizedBox(key: key, height: 300, child: const Text('form'))),
      );
    })));
    final before = key.currentContext;
    await tester.timedDrag(find.text('form'), const Offset(-250, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(identical(key.currentContext, before), isTrue);
  });
}
```

- [ ] **Step 2: Jalankan** `flutter test test/widgets/app_swipe_tabs_test.dart` → FAIL kompilasi (`app_swipe_tabs.dart` tidak ada).

- [ ] **Step 3: Implementasi** — `lib/widgets/app_swipe_tabs.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Pindah tab dengan menggeser layar (spec 2026-10-10 §3.4). Membungkus
/// seluruh halaman: geser horizontal di mana saja memindah tab, kecuali di
/// atas `AppSwipeActions` (lebih dalam di arena gesture → baris yang menang).
/// Bagian yang berganti per tab dibungkus [AppSwipeTabBody] supaya ikut
/// tertarik jari; `AppSegmentedControl` di dalamnya otomatis mengikuti posisi.
class AppSwipeTabs extends StatefulWidget {
  const AppSwipeTabs({
    required this.index,
    required this.count,
    required this.onChanged,
    required this.child,
    super.key,
  });

  final int index;
  final int count;
  final ValueChanged<int> onChanged;
  final Widget child;

  static const double switchFraction = 0.25;
  static const double switchVelocity = 400;
  static const double edgeResistance = 0.3;

  static _SwipeTabsScope? _scopeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SwipeTabsScope>();

  /// Posisi (0..count-1, pecahan saat digeser) untuk penanda tab, atau null
  /// bila tidak berada di dalam [AppSwipeTabs] dengan jumlah tab yang sama.
  static ValueListenable<double>? maybePositionOf(BuildContext context, int count) {
    final scope = _scopeOf(context);
    return scope != null && scope.count == count ? scope.position : null;
  }

  @override
  State<AppSwipeTabs> createState() => _AppSwipeTabsState();
}

class _AppSwipeTabsState extends State<AppSwipeTabs> {
  final ValueNotifier<double> _drag = ValueNotifier<double>(0);
  late final ValueNotifier<double> _position = ValueNotifier<double>(widget.index.toDouble());
  double _width = 1;
  int _direction = 1;

  @override
  void didUpdateWidget(AppSwipeTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _direction = widget.index > oldWidget.index ? 1 : -1;
      _drag.value = 0;
      _position.value = widget.index.toDouble();
    }
  }

  @override
  void dispose() {
    _drag.dispose();
    _position.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final next = _drag.value + delta;
    final pastStart = widget.index == 0 && next > 0;
    final pastEnd = widget.index == widget.count - 1 && next < 0;
    final value = (pastStart || pastEnd) ? _drag.value + delta * AppSwipeTabs.edgeResistance : next;
    _drag.value = value.clamp(-_width, _width);
    _position.value = (widget.index - _drag.value / _width).clamp(0, widget.count - 1).toDouble();
  }

  void _onEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final dx = _drag.value;
    var target = widget.index;
    if ((dx < -_width * AppSwipeTabs.switchFraction || velocity < -AppSwipeTabs.switchVelocity) &&
        widget.index < widget.count - 1) {
      target = widget.index + 1;
    } else if ((dx > _width * AppSwipeTabs.switchFraction || velocity > AppSwipeTabs.switchVelocity) &&
        widget.index > 0) {
      target = widget.index - 1;
    }
    if (target == widget.index) {
      _drag.value = 0;
      _position.value = widget.index.toDouble();
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      widget.onChanged(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth.isFinite && constraints.maxWidth > 0 ? constraints.maxWidth : 1;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: _onUpdate,
          onHorizontalDragEnd: _onEnd,
          onHorizontalDragCancel: () {
            _drag.value = 0;
            _position.value = widget.index.toDouble();
          },
          child: _SwipeTabsScope(
            index: widget.index,
            count: widget.count,
            direction: _direction,
            drag: _drag,
            position: _position,
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _SwipeTabsScope extends InheritedWidget {
  const _SwipeTabsScope({
    required this.index,
    required this.count,
    required this.direction,
    required this.drag,
    required this.position,
    required super.child,
  });

  final int index;
  final int count;
  final int direction;
  final ValueListenable<double> drag;
  final ValueListenable<double> position;

  @override
  bool updateShouldNotify(_SwipeTabsScope old) =>
      old.index != index || old.count != count || old.direction != direction;
}

/// Bagian halaman yang berganti per tab: ikut tertarik saat layar digeser,
/// dan (bila [keyByIndex]) meluncur masuk dari sisi yang sesuai saat tab
/// berganti. [keyByIndex] false untuk isi yang state-nya harus bertahan
/// (mis. form Masuk/Daftar yang keduanya tetap ter-mount).
class AppSwipeTabBody extends StatelessWidget {
  const AppSwipeTabBody({required this.child, this.keyByIndex = true, super.key});

  final Widget child;
  final bool keyByIndex;

  @override
  Widget build(BuildContext context) {
    final scope = AppSwipeTabs._scopeOf(context);
    if (scope == null) return child;
    final content = keyByIndex
        ? AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(begin: Offset(0.35 * scope.direction, 0), end: Offset.zero).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: KeyedSubtree(key: ValueKey<int>(scope.index), child: child),
          )
        : child;
    return ValueListenableBuilder<double>(
      valueListenable: scope.drag,
      builder: (context, dx, inner) => Transform.translate(offset: Offset(dx, 0), child: inner),
      child: content,
    );
  }
}
```

Di `AppSegmentedControl.build()`, ganti `final listenable = position;` menjadi:

```dart
    final listenable = position ?? AppSwipeTabs.maybePositionOf(context, labels.length);
```

dan tambahkan import `package:catat_uang_app/widgets/app_swipe_tabs.dart`.

- [ ] **Step 4: Jalankan** `flutter test test/widgets/` → PASS. Tes "scroll vertikal" membuktikan arena gesture memilih scroll untuk geseran yang dominan vertikal.
- [ ] **Step 5: Commit** `feat(widgets): swipe between tabs with AppSwipeTabs`.

---

### Task 6: Geser tab di enam halaman

**Files:**
- Modify:
  - `lib/screens/transaction_history/transactions_tab_screen.dart`
  - `lib/screens/stats/stats_screen.dart`
  - `lib/screens/debt/debt_screen.dart`
  - `lib/screens/manage_category/manage_category_screen.dart`
  - `lib/screens/zakat_sedekah/zakat_sedekah_screen.dart`
  - `lib/screens/login/login_screen.dart`
- Test:
  - `test/screens/debt/debt_screen_test.dart`
  - `test/screens/login/login_screen_test.dart`
  - `test/screens/manage_category/manage_category_screen_test.dart`
  - `test/screens/zakat_sedekah/zakat_sedekah_screen_test.dart` (buat bila belum ada)
  - `test/screens/stats/stats_screen_test.dart`
  - `test/screens/transaction_history/transactions_tab_screen_test.dart` (buat bila belum ada)

**Interfaces:**
- Consumes: `AppSwipeTabs`, `AppSwipeTabBody` (Task 5).

- [ ] **Step 1: Tes gagal** — satu tes per layar, polanya sama. Contoh Utang & Piutang di `debt_screen_test.dart`:

```dart
  testWidgets('geser layar ke kiri pindah ke Piutang, ke kanan kembali', (tester) async {
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(FakeDebtNotifier(state())));
    await tester.pump();
    await tester.timedDrag(find.text('Total Utang'), const Offset(-250, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('Piutang dari:'), findsWidgets);
    await tester.timedDrag(find.text('Total Utang'), const Offset(250, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('Piutang dari:'), findsNothing);
  });
```

  Layar lain memakai pola yang sama (geser −250 di elemen judul/ringkasan yang tidak ikut berganti):
  - **Login:** geser di `find.text('Yuk, atur keuanganmu')` → `find.byType(RegisterForm)` findsOneWidget. Tambahkan juga: ketik nama di Daftar, geser kembali ke Masuk lalu ke Daftar → nama masih ada.
  - **Kelola Kategori:** geser di `find.text('Kelola Kategori')` → fake provider menerima `fetchCategories(isExpense: false)`. Pakai fake yang sudah ada di tes itu; catat panggilannya.
  - **Zakat & Sedekah:** geser di `find.text('Zakat & Sedekah')` → tombol bawah berubah menjadi 'Bayar Sedekah'.
  - **Statistik:** geser di `find.text('Statistik')` → fake `setIsExpense(true)` terpanggil. Pakai fake notifier yang ada di tes Statistik.
  - **Transaksi:** pump `TransactionsTabScreen(refreshCounter: 0, onActiveTabChanged: cb)` dengan override provider riwayat seperti di `transaction_history_screen_test.dart`. Geser di `find.text('Pemasukan')` → `cb(true)` terpanggil.

- [ ] **Step 2: Jalankan** tes-tes tersebut → FAIL (geseran tidak memindah tab).

- [ ] **Step 3: Implementasi** per layar:
  - **Utang & Piutang** (`debt_screen.dart`):
    - bungkus `AppPageScaffold(...)` dengan `AppSwipeTabs(index: _isMyDebt ? 0 : 1, count: 2, onChanged: (i) => setState(() => _isMyDebt = i == 0), child: AppPageScaffold(...))`;
    - tiga cabang setelah segmented (loading / empty / daftar) diganti satu anak: `AppSwipeTabBody(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 14, children: [ <cabang yang sama> ]))`.
  - **Statistik:** bungkus `AppPageScaffold` dengan `AppSwipeTabs(index: state.isExpense ? 1 : 0, count: 2, onChanged: (i) => _notifier.setIsExpense(i == 1), child: ...)`. Bagian dari `if (state.isLoading)` sampai akhir daftar dibungkus `AppSwipeTabBody(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 14, children: [...]))`.
  - **Kelola Kategori:** bungkus dengan `AppSwipeTabs(index: isExpense ? 0 : 1, count: 2, onChanged: (i) { final wantExpense = i == 0; if (isExpense != wantExpense) ref.read(categoryProvider.notifier).fetchCategories(isExpense: wantExpense); }, child: ...)`. Cabang daftar dibungkus `AppSwipeTabBody`.
  - **Zakat & Sedekah:** bungkus dengan `AppSwipeTabs(index: _isZakat ? 0 : 1, count: 2, onChanged: (i) => setState(() => _isZakat = i == 0), child: ...)`. `..._buildZakatSection()` / `..._buildSedekahSection()` menjadi `AppSwipeTabBody(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 14, children: _isZakat ? _buildZakatSection() : _buildSedekahSection()))`.
  - **Masuk/Daftar** (`login_screen.dart`):
    - bungkus `AuthLayout(...)` dengan `AppSwipeTabs(index: _tab, count: 2, onChanged: _switchTab, child: ...)`;
    - `Column` berisi kedua `_tabBody` dibungkus `AppSwipeTabBody(keyByIndex: false, child: ...)`.
  - **Transaksi** (`transactions_tab_screen.dart`):
    - kembalikan `AppSwipeTabs(index: _tabIndex, count: 2, onChanged: _select, child: AppSwipeTabBody(child: <TransactionHistoryScreen terpilih seperti sekarang>))`;
    - ekstrak `onChanged` switcher menjadi `void _select(int i)` yang sama.

  Semua `AppSegmentedControl` di halaman-halaman ini otomatis mengikuti posisi geser (Task 5).

- [ ] **Step 4: Jalankan** `flutter test test/screens/` → PASS (tes lama ketuk tab tetap lulus).
- [ ] **Step 5: Commit** `feat(screens): swipe to switch tabs on tabbed pages`.

---

### Task 7: Hapus utang dengan geser + helper bersama

**Files:**
- Create: `lib/screens/debt/debt_delete.dart`
- Modify: `lib/screens/debt/debt_detail_screen.dart` (`_deleteDebt` memakai helper), `lib/screens/debt/debt_screen.dart` (kartu dibungkus `AppSwipeActions`)
- Test: `test/screens/debt/debt_screen_test.dart`, `test/screens/debt/debt_detail_screen_test.dart` (tetap lulus)

**Interfaces:**
- Produces: `Future<bool?> confirmAndDeleteDebt(BuildContext context, WidgetRef ref, DebtModel debt, {VoidCallback? onConfirmed})`.
  - `null` = batal; `true` = terhapus dengan refund; `false` = terhapus tanpa refund.
  - Melempar error provider apa adanya; pemanggil yang menampilkan toast error.
  - `onConfirmed` dipanggil tepat sebelum `deleteDebt`, untuk flag `_deleted` di detail.
  - Bila riwayat cicilan belum dimuat (`payments[debt.id] == null`), helper memuatnya dulu (`fetchPayments`) supaya keputusan "bertautan dompet" benar.

- [ ] **Step 1: Tes gagal** — di `debt_screen_test.dart` (import `package:flutter/cupertino.dart`):

```dart
  testWidgets('geser kartu utang lalu Hapus: dialog lama, deleteDebt terpanggil', (tester) async {
    final fake = FakeDebtNotifier(state());
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(fake), size: const Size(390, 1400));
    await tester.pump();
    await tester.drag(find.text('Rina'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Catatan?'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Hapus'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('deleteDebt:2'));
    expect(find.text('Data berhasil dihapus!'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('hapus dari daftar memuat riwayat cicilan dulu sebelum memilih dialog', (tester) async {
    final fake = FakeDebtNotifier(state());
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(fake), size: const Size(390, 1400));
    await tester.pump();
    await tester.drag(find.text('Rina'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('fetchPayments:2'));
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(fake.calls.where((c) => c.startsWith('deleteDebt')), isEmpty);
  });

  testWidgets('geser kartu utang lalu Edit membuka form terisi', (tester) async {
    await pumpApp(tester, const DebtScreen(), overrides: debtOverrides(FakeDebtNotifier(state())), size: const Size(390, 1400));
    await tester.pump();
    await tester.drag(find.text('Rina'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Rina'), findsWidgets); // nama terisi di form
    expect(find.text('Simpan Perubahan'), findsOneWidget);
  });
```

  Cek nama pemanggilan `fetchPayments` di `FakeDebtNotifier`. Bila belum mencatat `fetchPayments:<id>`, tambahkan override `Future<void> fetchPayments(int debtId) async => calls.add('fetchPayments:$debtId');` di `debt_test_utils.dart`. Sesuaikan juga teks tombol simpan form utang dengan yang sebenarnya di `debt_form_sheet.dart`.

- [ ] **Step 2: Jalankan** `flutter test test/screens/debt/` → FAIL ('Hapus' tidak ada di daftar).

- [ ] **Step 3: Implementasi**
  - **`lib/screens/debt/debt_delete.dart`:** pindahkan isi dialog dari `_deleteDebt`:

```dart
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/debt_payment_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Konfirmasi + hapus utang (dipakai daftar & detail). Pilihan "kembalikan
/// saldo" hanya untuk utang yang menyentuh dompet; riwayat cicilan dimuat dulu
/// bila belum ada (dari daftar belum pernah dibuka).
/// null = batal; true = dihapus & saldo dikembalikan; false = dihapus saja.
Future<bool?> confirmAndDeleteDebt(
  BuildContext context,
  WidgetRef ref,
  DebtModel debt, {
  VoidCallback? onConfirmed,
}) async {
  const intro = 'Data utang ini dan seluruh riwayat cicilannya akan dihapus permanen.';
  if (ref.read(debtProvider).payments[debt.id] == null) {
    await ref.read(debtProvider.notifier).fetchPayments(debt.id);
    if (!context.mounted) return null;
  }
  final payments = ref.read(debtProvider).payments[debt.id] ?? const <DebtPaymentModel>[];
  final linkedToWallet =
      (debt.transactionId != null && debt.walletId != null) || payments.any((p) => p.affectsWallet);

  final bool? refund;
  if (linkedToWallet) {
    refund = await showAppChoiceDialog<bool>(
      context: context,
      title: 'Hapus Catatan?',
      message: '$intro Kembalikan saldo dompet seperti sebelum utang ini dicatat?',
      choices: const [
        AppDialogChoice(label: 'Hapus & kembalikan saldo', value: true),
        AppDialogChoice(label: 'Hapus saja', value: false, destructive: true),
      ],
    );
  } else {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'Hapus Catatan?',
      message: '$intro Utang ini tidak terhubung ke saldo dompet, jadi saldo tidak berubah.',
    );
    refund = confirm ? false : null;
  }
  if (refund == null || !context.mounted) return null;
  onConfirmed?.call();
  await ref.read(debtProvider.notifier).deleteDebt(debt.id, refundWallet: refund);
  return refund;
}
```

  - **Detail** (`debt_detail_screen.dart`), `_deleteDebt` menjadi:

```dart
  Future<void> _deleteDebt(DebtModel debt) async {
    try {
      final refund = await confirmAndDeleteDebt(context, ref, debt, onConfirmed: () => _deleted = true);
      if (refund == null || !mounted) return;
      Navigator.pop(context);
      AppNotification.success(context, refund ? 'Utang dihapus dan saldo dikembalikan!' : 'Data berhasil dihapus!');
    } catch (e) {
      _deleted = false;
      if (!mounted) return;
      AppNotification.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }
```

  - **Daftar** (`debt_screen.dart`): setiap `DebtCard` dibungkus:

```dart
            AppSwipeActions(
              key: ValueKey('debt-${debt.id}'),
              borderRadius: BorderRadius.circular(24),
              confirmDelete: false,
              onEdit: () => showDebtFormSheet(context, debt: debt),
              onDelete: () => _delete(debt),
              child: DebtCard(debt: debt, today: today, onTap: () => _openDetail(debt)),
            ),
```

    dengan method:

```dart
  Future<void> _delete(DebtModel debt) async {
    try {
      final refund = await confirmAndDeleteDebt(context, ref, debt);
      if (refund == null || !mounted) return;
      AppNotification.success(context, refund ? 'Utang dihapus dan saldo dikembalikan!' : 'Data berhasil dihapus!');
    } catch (e) {
      if (!mounted) return;
      AppNotification.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }
```

    (import `app_swipe_actions.dart`, `app_notification.dart`, `debt_delete.dart`.)
- [ ] **Step 4: Jalankan** `flutter test test/screens/debt/` → PASS (tes detail lama tetap lulus).
- [ ] **Step 5: Commit** `feat(debt): swipe a debt card to edit or delete`.

---

### Task 8: Geser hapus di Target, Tabungan, Detail Tabungan, Transaksi Rutin, Kategori, Investasi

**Files:**
- Modify:
  - `lib/screens/target/target_screen.dart`
  - `lib/screens/savings/savings_screen.dart`
  - `lib/screens/savings/saving_detail_screen.dart`
  - `lib/screens/recurring/recurring_screen.dart`
  - `lib/screens/manage_category/manage_category_screen.dart`
  - `lib/screens/investment/investment_screen.dart`
- Test: tes layar masing-masing di `test/screens/...`

**Interfaces:**
- Consumes: `AppSwipeActions(borderRadius:, confirmDelete:)` (Task 4).

- [ ] **Step 1: Ubah tes jadi gagal** — di tiap tes yang mengetuk ikon:
  - ganti `await tester.tap(find.byIcon(PhosphorIconsRegular.trash).first)` (atau `PhosphorIconsFill.trash`) dengan `await tester.drag(find.text('<nama item>'), const Offset(-250, 0)); await tester.pumpAndSettle(); await tester.tap(find.text('Hapus'));`;
  - ganti ketukan `pencilSimple` dengan geser yang sama lalu `tap(find.text('Edit'))`.

  Contoh baru di `target_screen_test.dart`:

```dart
  testWidgets('kartu target tidak lagi punya ikon pensil/sampah; geser membuka Edit dan Hapus', (tester) async {
    // pump seperti tes lain di file ini
    expect(find.byIcon(PhosphorIconsRegular.trash), findsNothing);
    expect(find.byIcon(PhosphorIconsRegular.pencilSimple), findsNothing);
    await tester.drag(find.text('<nama target contoh>'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);
  });
```

  Buat tes serupa di:
  - **savings** (nama grup);
  - **saving_detail** (judul baris 'Setoran Tabungan');
  - **recurring** (nama kategori);
  - **manage_category**: kategori milik user bisa digeser; kategori bawaan tidak memunculkan 'Hapus' saat digeser;
  - **investment**: baris aset; lembar opsi tidak lagi berisi 'Hapus Portofolio'. Ubah tes 'Hapus Portofolio dikonfirmasi' agar memakai geser + `find.text('Hapus Portofolio?')` pada dialog.

- [ ] **Step 2: Jalankan** `flutter test test/screens/` → FAIL (ikon masih ada / 'Hapus' tidak muncul).

- [ ] **Step 3: Implementasi** per layar. Hapus `AppNavAction.icon(pencilSimple…)` dan `AppNavAction.icon(trash…)` atau `IconButton`, lalu bungkus elemen daftar:
  - **Target:** di tempat `_buildTargetCard(item)` dipanggil:
    `AppSwipeActions(key: ValueKey('target-${item.id}'), borderRadius: BorderRadius.circular(24), confirmDelete: false, onEdit: () => _showEditSheet(item), onDelete: () => _confirmDelete(item.id, item.name), child: _buildTargetCard(item))`.
  - **Tabungan:** di tempat `_buildGroupCard(groupName, items)` dipanggil:
    `AppSwipeActions(key: ValueKey('saving-$groupName'), borderRadius: BorderRadius.circular(24), confirmDelete: false, onEdit: () => _showEditSheet(groupName, loc, note), onDelete: () => _confirmDelete(groupName), child: …)`.
    `loc` dan `note` dihitung di pemanggil dengan cara yang sama seperti di `_buildGroupCard`.
  - **Detail Tabungan:** `_buildHistoryRow` mengembalikan
    `AppSwipeActions(key: ValueKey('saving-item-${item.id}'), confirmDelete: false, onEdit: () => _showEditSheet(item), onDelete: () => _confirmDeleteItem(item), child: AppListRow(...))`.
    Baris dalam grouped section, jadi tanpa `borderRadius`. Kolom trailing tinggal teks nominal.
  - **Transaksi Rutin:** pemanggil `_buildCard(item, walletNames)` dibungkus
    `AppSwipeActions(key: ValueKey('recurring-${item.id}'), borderRadius: BorderRadius.circular(24), confirmDelete: false, onEdit: () => _showAddEditSheet(item: item), onDelete: () => _confirmDelete(item), child: …)`.
    `Opacity` tetap di dalam `_buildCard`.
  - **Kategori:** `_buildCategoryRow`:
    - kategori bawaan dikembalikan apa adanya;
    - selain itu `AppSwipeActions(key: ValueKey('category-${cat.id}'), deleteConfirmTitle: 'Hapus Kategori?', deleteConfirmMessage: "Yakin mau hapus '${cat.name}'?", onEdit: () => _showInputSheet(context, ref, categoryToEdit: cat), onDelete: () => _deleteCategory(context, ref, cat.id), child: AppListRow(…tanpa trailing))`.
    - Dialog bawaannya memakai teks yang sama dengan dialog lama.
  - **Investasi:**
    - `_InvestmentRow(...)` dibungkus `AppSwipeActions(key: ValueKey('inv-${inv.id}'), deleteConfirmTitle: 'Hapus Portofolio?', deleteConfirmMessage: "Aset '${inv.name}' dihapus dari daftar. Saldo dompet tidak berubah.", onDelete: () => ref.read(investmentProvider.notifier).deleteInvestment(inv.id), child: …)`;
    - hapus `AppListRow` "Hapus Portofolio" dari `_showActionSheet`.

  Import `package:catat_uang_app/widgets/app_swipe_actions.dart` di tiap file, dan hapus import yang jadi tak terpakai.
- [ ] **Step 4: Jalankan** `flutter test test/screens/ test/architecture/ test/conventions_test.dart` dan `flutter analyze` → PASS / 0 error-warning.
- [ ] **Step 5: Commit** `feat(screens): swipe to edit or delete savings, targets, schedules, categories and investments`.

---

### Task 9: Screenshot + verifikasi penuh

**Files:**
- Create: `test/screenshots/tabs_swipe_screenshots_test.dart`

- [ ] **Step 1: Tulis tes screenshot**:

```dart
@Tags(['screenshot'])
library;

import 'package:catat_uang_app/screens/debt/debt_screen.dart';
import 'package:catat_uang_app/screens/login/login_screen.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/debt/debt_test_utils.dart';
import 'screenshot_harness.dart';

void main() {
  final skip = !screenshotFontsAvailable;

  testWidgets('01 tab kapsul (Masuk/Daftar)', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const LoginScreen());
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'ts_01_capsule_tabs');
  }, skip: skip);

  testWidgets('02 geser hapus utang', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const DebtScreen(), overrides: debtOverrides(FakeDebtNotifier(DebtState(
      isLoading: false,
      debts: [
        sampleDebt(id: 1, dueDate: DateTime(2026, 9, 22), notes: 'Modal usaha'),
        sampleDebt(id: 2, name: 'Rina', amount: 750000, remaining: 750000, dueDate: DateTime(2026, 11, 15)),
      ],
    ))));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Rina'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'ts_02_swipe_delete_debt');
  }, skip: skip);

  testWidgets('03 isian catatan fokus di kartu', (tester) async {
    await loadRealFonts(tester);
    final c = TextEditingController(text: 'Beli Nasi Padang');
    await pumpScreen(tester, Scaffold(body: Padding(
      padding: const EdgeInsets.all(16),
      child: AppGroupedSection(header: 'Catatan (Opsional)', children: [AppTextField(controller: c, hint: 'x')]),
    )));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'ts_03_note_focus');
  }, skip: skip);
}
```

  (tambah import `package:catat_uang_app/providers/debt_provider.dart` untuk `DebtState`.)

- [ ] **Step 2: Hasilkan** `flutter test test/screenshots/tabs_swipe_screenshots_test.dart` → 3 PASS. Bandingkan hasilnya dengan mockup. Jangan membuka PNG saat tes masih berjalan (Windows mengunci file).
- [ ] **Step 3: Verifikasi penuh** — `flutter analyze` → 0 error/warning; `E2E_EMAIL=… E2E_PASSWORD=… flutter test` → semua lulus.
- [ ] **Step 4: Commit** `test(ui): screenshots for capsule tabs, swipe delete and note focus`.
- [ ] **Step 5: Review akhir & serah terima** — reviewer baru (opus) untuk seluruh branch; perbaiki semua temuan (termasuk minor) RED→GREEN; kirim screenshot ke pengguna; merge lokal hanya setelah pengguna setuju.
