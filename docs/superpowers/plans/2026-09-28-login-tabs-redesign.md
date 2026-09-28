# Login & Daftar Bergaya Rotta — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `LoginScreen` menjadi satu layar dengan tab Masuk | Daftar, isian berlabel di dalam kotak, dan tombol Google yang memunculkan notifikasi "belum tersedia", sesuai mockup yang disetujui.

**Architecture:** Melanjutkan branch `feat/login-register-redesign`. `AuthLayout` diubah menjadi hero berdekorasi + sheet putih dengan `children` bebas dan `footer` opsional. Bagian kecil auth (`AuthLogo`, `AuthDivider`, `AuthGoogleButton`, `GoogleLogo`) pindah ke `auth_parts.dart`. Logika login/daftar dipindah apa adanya ke `LoginForm`/`RegisterForm`; `LoginScreen` hanya memegang tab dan controller email. `RegisterScreen` dihapus.

**Tech Stack:** Flutter 3.38.5, phosphor_flutter, AppColors/AppTextStyles, flutter_test. Tanpa dependensi baru.

**Spec:** `docs/superpowers/specs/2026-09-28-login-register-design.md` (Revisi 2)

## Global Constraints

- Isi `_login()` tidak berubah. Isi `_register()` tidak berubah kecuali `Navigator.pop(context);` diganti `widget.onRegistered(_emailController.text);`.
- Tidak ada `Color(0x…)` di `lib/screens`/`lib/widgets`; warna Google masuk `AppColors` (`googleBlue 0xFF4285F4`, `googleRed 0xFFEA4335`, `googleYellow 0xFFFBBC05`, `googleGreen 0xFF34A853`).
- Tidak ada `GoogleFonts.*` di layar/widget. Ikon Phosphor saja. Tidak ada dependensi baru.
- Tidak ada Facebook, "Ingat saya", atau "Lupa password?". Google tidak memanggil apa pun selain `AppNotification.info`.
- Teks persis: judul "Yuk, atur keuanganmu"; subjudul "Masuk atau buat akun untuk mulai mencatat pemasukan dan pengeluaranmu."; tab "Masuk"/"Daftar"; tombol "Masuk" dan "Daftar Sekarang"; pemisah "atau masuk dengan"/"atau daftar dengan"; tombol Google "Lanjut dengan Google"; toast "Login Google belum tersedia. Pakai email dan password dulu ya."; footer Masuk "Datamu hanya bisa dilihat dari akunmu sendiri."; caption "Minimal 6 karakter.".
- Commit Conventional Commits; tidak push. Selesai = `flutter analyze` 0 error/warning + `flutter test` penuh (E2E lewat env `E2E_EMAIL`/`E2E_PASSWORD`, tidak pernah disimpan) lulus.

## Review Focus

1. Setelah daftar berhasil, layar akar tidak boleh ter-pop (dulu `Navigator.pop`) → pindah ke tab Masuk dengan email terisi (Task 5).
2. Tab Daftar di HP kecil dengan keyboard → tidak overflow, "Daftar Sekarang" bisa di-scroll dan ditekan (Task 5).
3. Label di dalam kotak tidak menabrak teks isian atau ikon, termasuk teks diperbesar 1.3 (Task 2 & Task 4).
4. Ketuk Google berulang cepat → satu toast (toast lama diganti), tidak menumpuk (Task 1 memakai `_removeCurrentToast` yang sama).
5. Field tanpa `outlined` di 30+ form lain tidak berubah (Task 2, tes regresi yang sudah ada).

---

### Task 1: `AppNotification.info`

**Files:**
- Modify: `lib/core/app_notification.dart`
- Test: `test/core/app_notification_test.dart`

**Interfaces:**
- Produces: `static void AppNotification.info(BuildContext context, String message)`.

- [ ] **Step 1: Tes gagal** — tambahkan ke `main()` (tambah import `package:phosphor_flutter/phosphor_flutter.dart`):

```dart
  testWidgets('Toast info memakai ikon info biru di lingkaran primarySoft', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => AppNotification.info(context, 'Login Google belum tersedia.'),
            child: const Text('tes'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('tes'));
    await tester.pump();

    expect(find.text('Login Google belum tersedia.'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(PhosphorIcons.info(PhosphorIconsStyle.bold)));
    expect(icon.color, AppColors.primary);
    final circle = tester.widget<Container>(
      find.ancestor(of: find.byWidget(icon), matching: find.byType(Container)).first,
    );
    expect((circle.decoration! as BoxDecoration).color, AppColors.primarySoft);
    await tester.pump(const Duration(seconds: 4));
  });
```

- [ ] **Step 2: Jalankan** `flutter test test/core/app_notification_test.dart` → FAIL kompilasi (`info` tidak ada).

- [ ] **Step 3: Implementasi** — di `app_notification.dart`:
  - tambah `enum _ToastKind { success, error, info }` di atas `class AppNotification`;
  - `success` memanggil `_showTopToast(context, message, kind: _ToastKind.success)`, `error` dengan `_ToastKind.error` (tetap lewat `_translateError`), dan baru:

```dart
  // PESAN INFO (BIRU), mis. fitur yang belum tersedia
  static void info(BuildContext context, String message) {
    _showTopToast(context, message, kind: _ToastKind.info);
  }
```

  - `_showTopToast(..., {required _ToastKind kind})` meneruskan `kind: kind` ke `_ToastWidget`;
  - `_ToastWidget` field `final _ToastKind kind;` menggantikan `isError`, dan tiga ekspresi warna/ikon menjadi:

```dart
color: switch (widget.kind) {
  _ToastKind.error => AppColors.expenseSoft,
  _ToastKind.info => AppColors.primarySoft,
  _ToastKind.success => AppColors.incomeSoft,
},
```
```dart
switch (widget.kind) {
  _ToastKind.error => PhosphorIcons.warning(PhosphorIconsStyle.bold),
  _ToastKind.info => PhosphorIcons.info(PhosphorIconsStyle.bold),
  _ToastKind.success => PhosphorIcons.check(PhosphorIconsStyle.bold),
},
color: switch (widget.kind) {
  _ToastKind.error => AppColors.expense,
  _ToastKind.info => AppColors.primary,
  _ToastKind.success => AppColors.income,
},
```

- [ ] **Step 4: Jalankan** `flutter test test/core/app_notification_test.dart` → PASS.
- [ ] **Step 5: Commit** `feat(core): add info toast to AppNotification`.

---

### Task 2: `AppTextField(outlined)` — garis tepi di kotak, label di dalam

**Files:**
- Modify: `lib/widgets/app_text_field.dart`
- Test: `test/widgets/app_text_field_test.dart`

**Interfaces:**
- Produces: `AppTextField(outlined: true, label: 'Email', ...)` → satu `AnimatedContainer` (warna isi, `Border.all` track/primary 1.5, cincin `focusRing` saat fokus) berisi `TextField` dengan `InputBorder.none`, `labelText: label`, `floatingLabelBehavior: FloatingLabelBehavior.always`. Tanpa `outlined`: tidak berubah.

- [ ] **Step 1: Tes gagal** — di `app_text_field_test.dart`, ganti helper dan tes `outlined: garis tepi track…` menjadi:

```dart
  BoxDecoration box(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration! as BoxDecoration;
  BoxDecoration ring(WidgetTester tester) => box(tester);
  Color borderColor(WidgetTester tester) => (box(tester).border! as Border).top.color;
  Color prefixColor(WidgetTester tester) =>
      tester.widget<Icon>(find.byIcon(PhosphorIconsRegular.envelopeSimple)).color!;

  testWidgets('outlined: kotak bergaris track, fokus jadi biru dengan cincin', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: AppTextField(
      controller: controller, hint: 'email', icon: PhosphorIconsRegular.envelopeSimple, outlined: true)));

    final deco = tester.widget<TextField>(find.byType(TextField)).decoration!;
    expect(deco.border, InputBorder.none);
    expect(deco.enabledBorder, InputBorder.none);
    expect(deco.focusedBorder, InputBorder.none);
    expect(borderColor(tester), AppColors.track);
    expect((box(tester).border! as Border).top.width, 1.5);
    expect(box(tester).boxShadow, anyOf(isNull, isEmpty));
    expect(prefixColor(tester), AppColors.textSecondary);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(borderColor(tester), AppColors.primary);
    expect(box(tester).boxShadow!.single.color, AppColors.focusRing);
    expect(box(tester).boxShadow!.single.spreadRadius, 4);
    expect(prefixColor(tester), AppColors.primary);
  });

  testWidgets('outlined + label: label kecil di dalam kotak, di atas teks isian', (tester) async {
    final controller = TextEditingController(text: 'miftahul@contoh.com');
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: Padding(
      padding: const EdgeInsets.all(16),
      child: AppTextField(controller: controller, label: 'Email', hint: 'email@contoh.com',
          icon: PhosphorIconsRegular.envelopeSimple, outlined: true),
    )));

    expect(tester.widget<TextField>(find.byType(TextField)).decoration!.labelText, 'Email');
    expect(find.descendant(of: find.byType(AnimatedContainer), matching: find.text('Email')), findsOneWidget);
    final labelRect = tester.getRect(find.text('Email'));
    final inputRect = tester.getRect(find.byType(EditableText));
    final boxRect = tester.getRect(find.byType(AnimatedContainer));
    expect(labelRect.bottom, lessThanOrEqualTo(inputRect.top + 1));
    expect(labelRect.top, greaterThan(boxRect.top));
    expect(labelRect.left, greaterThan(tester.getRect(find.byIcon(PhosphorIconsRegular.envelopeSimple)).right));
  });

  testWidgets('outlined + label pada teks 1.3x tidak overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = TextEditingController(text: 'nama.panjang.sekali@contoh.com');
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: SizedBox(width: 280, child: AppTextField(
      controller: controller, label: 'Email', icon: PhosphorIconsRegular.envelopeSimple, outlined: true))),
      size: const Size(320, 568));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
```

Tes lain (`focusNode pemanggil…`, `…focusNode diganti…`, `tanpa outlined…`) tetap; mereka memakai `ring(tester).boxShadow`, yang kini alias `box`.

- [ ] **Step 2: Jalankan** `flutter test test/widgets/app_text_field_test.dart` → FAIL (`deco.border` bukan `InputBorder.none`; label di luar kotak).

- [ ] **Step 3: Implementasi** — ganti bagian `build` di `_AppTextFieldState` (state fokus, `initState`, `didUpdateWidget`, `dispose` tetap):

```dart
  @override
  Widget build(BuildContext context) {
    if (widget.outlined) return _buildOutlined();
    final radius = BorderRadius.circular(16);
    final field = TextField(
      controller: widget.controller,
      focusNode: _node,
      autofocus: widget.autofocus,
      textCapitalization: widget.textCapitalization,
      obscureText: widget.obscure,
      keyboardType: widget.keyboardType,
      readOnly: widget.readOnly,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      inputFormatters: widget.inputFormatters,
      style: AppTextStyles.body,
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 20, color: AppColors.textSecondary),
        suffixIcon: widget.suffix,
        filled: true,
        fillColor: widget.readOnly ? AppColors.track : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
    if (widget.label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(widget.label!, style: AppTextStyles.caption),
        ),
        field,
      ],
    );
  }

  /// Kotak terpisah bergaris tepi. Garis & cincin digambar kotak pembungkus
  /// (bukan InputBorder) supaya label bisa duduk di dalam kotak, bukan di
  /// garis tepi seperti OutlineInputBorder.
  Widget _buildOutlined() {
    final radius = BorderRadius.circular(14);
    final labelStyle = AppTextStyles.subhead.copyWith(fontWeight: FontWeight.w600);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: widget.readOnly ? AppColors.track : AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: _focused ? AppColors.primary : AppColors.track, width: 1.5),
        boxShadow: _focused ? const [BoxShadow(color: AppColors.focusRing, spreadRadius: 4)] : const [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _node,
        autofocus: widget.autofocus,
        textCapitalization: widget.textCapitalization,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        readOnly: widget.readOnly,
        maxLines: widget.obscure ? 1 : widget.maxLines,
        onTap: widget.onTap,
        onChanged: widget.onChanged,
        inputFormatters: widget.inputFormatters,
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          labelText: widget.label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: labelStyle,
          floatingLabelStyle: labelStyle,
          hintText: widget.hint,
          hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          prefixIcon: widget.icon == null
              ? null
              : Icon(widget.icon, size: 20, color: _focused ? AppColors.primary : AppColors.textSecondary),
          suffixIcon: widget.suffix,
          contentPadding: EdgeInsets.fromLTRB(16, widget.label == null ? 14 : 10, 16, widget.label == null ? 14 : 10),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
```

Hapus juga variabel `outlined`/`idleSide`/`iconColor` lama dan pembungkus `AnimatedContainer` lama di jalur non-outlined.

- [ ] **Step 4: Jalankan** `flutter test test/widgets/app_text_field_test.dart test/conventions_test.dart` → PASS.
- [ ] **Step 5: Commit** `feat(widgets): draw outlined field border on its box and float label inside`.

---

### Task 3: `auth_parts.dart` — logo, pemisah, tombol Google

**Files:**
- Modify: `lib/core/colors.dart` (4 warna Google)
- Create: `lib/screens/login/auth_parts.dart`
- Modify: `lib/screens/login/auth_layout.dart` (pindahkan `AuthLogo`, `AuthBackButton`, `AuthFooter` ke `auth_parts.dart`, re-export)
- Test: `test/screens/login/auth_parts_test.dart`

**Interfaces:**
- Produces: `AuthLogo({required IconData icon})`, `AuthFooter`/`AuthBackButton` (dipindah, sementara), `AuthDivider({required String label})`, `AuthGoogleButton({required String label, required VoidCallback onTap})`, `GoogleLogo({double size = 18})`.

- [ ] **Step 1: Tes gagal** — `test/screens/login/auth_parts_test.dart`:

```dart
import 'package:catat_uang_app/screens/login/auth_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('AuthGoogleButton menampilkan logo G dan label, lalu memanggil onTap', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: Center(child: AuthGoogleButton(label: 'Lanjut dengan Google', onTap: () => taps++))));
    expect(find.text('Lanjut dengan Google'), findsOneWidget);
    expect(find.byType(GoogleLogo), findsOneWidget);
    await tester.tap(find.text('Lanjut dengan Google'));
    expect(taps, 1);
    expect(tester.getSize(find.byType(AuthGoogleButton)).height, 48);
  });

  testWidgets('AuthDivider menampilkan teks di antara dua garis', (tester) async {
    await pumpApp(tester, const Scaffold(body: AuthDivider(label: 'atau masuk dengan')));
    final text = tester.getRect(find.text('atau masuk dengan'));
    expect(text.left, greaterThan(40));
    expect(text.right, lessThan(390 - 40));
  });

  testWidgets('AuthLogo 44x44 dengan ikon', (tester) async {
    await pumpApp(tester, const Scaffold(body: Center(child: AuthLogo(icon: PhosphorIconsFill.wallet))));
    expect(tester.getSize(find.byType(AuthLogo)), const Size(44, 44));
    expect(find.byIcon(PhosphorIconsFill.wallet), findsOneWidget);
  });
}
```

- [ ] **Step 2: Jalankan** `flutter test test/screens/login/auth_parts_test.dart` → FAIL kompilasi (`auth_parts.dart` tidak ada).

- [ ] **Step 3: Implementasi**

`lib/core/colors.dart`, di akhir blok Phase B:

```dart
  // Logo "G" tombol Google (warna merek resmi).
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleRed = Color(0xFFEA4335);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleGreen = Color(0xFF34A853);
```

`lib/screens/login/auth_parts.dart`:

```dart
import 'dart:math' as math;

import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Kotak logo kecil di hero auth (putih 18% di atas gradasi).
class AuthLogo extends StatelessWidget {
  const AuthLogo({required this.icon, super.key});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 24, color: AppColors.white),
    );
  }
}

/// Garis — "atau masuk dengan" — garis.
class AuthDivider extends StatelessWidget {
  const AuthDivider({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.track, thickness: 1, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: AppTextStyles.caption),
        ),
        const Expanded(child: Divider(color: AppColors.track, thickness: 1, height: 1)),
      ],
    );
  }
}

/// Tombol "Lanjut dengan Google" bergaris tepi.
class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({required this.label, required this.onTap, super.key});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.track, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GoogleLogo(),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.subhead.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo "G" empat warna, digambar tanpa aset atau paket SVG.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({this.size = 18, super.key});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GoogleLogoPainter());
}

class _GoogleLogoPainter extends CustomPainter {
  static double _rad(double deg) => deg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.2;
    final center = size.center(Offset.zero);
    final radius = (s - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // Sudut searah jarum jam dari arah jam 3; celah "G" di kanan atas.
    canvas.drawArc(rect, _rad(220), _rad(100), false, arc(AppColors.googleRed));
    canvas.drawArc(rect, _rad(145), _rad(75), false, arc(AppColors.googleYellow));
    canvas.drawArc(rect, _rad(40), _rad(105), false, arc(AppColors.googleGreen));
    canvas.drawArc(rect, _rad(0), _rad(40), false, arc(AppColors.googleBlue));
    canvas.drawRect(
      Rect.fromLTRB(center.dx, center.dy - stroke / 2, center.dx + radius + stroke / 2, center.dy + stroke / 2),
      Paint()..color = AppColors.googleBlue,
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}
```

Pindahkan juga kelas `AuthFooter` dan `AuthBackButton` apa adanya dari `auth_layout.dart` ke `auth_parts.dart` (tambah import `phosphor_flutter` di sana). Di `auth_layout.dart`, hapus ketiga kelas itu beserta import `phosphor_flutter`, lalu tambahkan di bawah import:

```dart
export 'auth_parts.dart' show AuthLogo, AuthFooter, AuthBackButton;
```

Dengan export ini, `login_screen.dart`, `register_screen.dart`, dan tes lama tetap terkompilasi tanpa diubah. `AuthFooter` dan `AuthBackButton` dihapus di Task 5 saat layar lama hilang.

- [ ] **Step 4: Jalankan** `flutter test test/screens/login/ test/widgets/app_system_ui_test.dart test/conventions_test.dart` → PASS.
- [ ] **Step 5: Commit** `feat(auth): add Google button, divider and logo parts`.

---

### Task 4: `AuthLayout` — hero berdekorasi, sheet putih, `children` + `footer?`

**Files:**
- Modify: `lib/screens/login/auth_layout.dart`
- Modify: `lib/screens/login/login_screen.dart`, `lib/screens/register/register_screen.dart` (hanya menyesuaikan API baru agar tetap terkompilasi; diganti total di Task 5)
- Test: `test/screens/login/auth_layout_test.dart`, `test/widgets/app_system_ui_test.dart`

**Interfaces:**
- Produces: `AuthLayout({required String title, required String subtitle, required Widget leading, required List<Widget> children, Widget? footer})`. `children` diberi jarak 12 dan dimulai 0px di bawah sudut sheet; `footer` di dasar setelah `Spacer`.

- [ ] **Step 1: Tes gagal** — tulis ulang `test/screens/login/auth_layout_test.dart`:

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/login/auth_layout.dart';
import 'package:catat_uang_app/screens/login/auth_parts.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

var tapped = 0;

Widget _layout({bool withFooter = true}) => AuthLayout(
      title: 'Yuk, atur keuanganmu',
      subtitle: 'Tagline',
      leading: const AuthLogo(icon: PhosphorIconsFill.wallet),
      children: [
        AppTextField(controller: TextEditingController(), label: 'A', hint: 'a', outlined: true),
        AppTextField(controller: TextEditingController(), label: 'B', hint: 'b', outlined: true),
        AppTextField(controller: TextEditingController(), label: 'C', hint: 'c', outlined: true),
        AppPrimaryButton(label: 'Aksi', onPressed: () => tapped++),
      ],
      footer: withFooter ? const Text('Kaki') : null,
    );

void main() {
  setUp(() => tapped = 0);

  testWidgets('menampilkan hero, isi sheet, dan footer', (tester) async {
    await pumpApp(tester, _layout());
    expect(find.text('Yuk, atur keuanganmu'), findsOneWidget);
    expect(find.text('Tagline'), findsOneWidget);
    expect(find.byType(AppTextField), findsNWidgets(3));
    expect(find.text('Kaki'), findsOneWidget);
  });

  testWidgets('sheet putih: latar layar surface', (tester) async {
    await pumpApp(tester, _layout());
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, AppColors.surface);
  });

  testWidgets('layar tinggi: tombol langsung di bawah isian, footer di dasar', (tester) async {
    await pumpApp(tester, _layout(), size: const Size(390, 844));
    final gap = tester.getTopLeft(find.text('Aksi')).dy - tester.getBottomLeft(find.byType(AppTextField).last).dy;
    expect(gap, lessThan(40));
    expect(844 - tester.getBottomLeft(find.text('Kaki')).dy, closeTo(16, 0.5));
  });

  testWidgets('tanpa footer tetap dirender', (tester) async {
    await pumpApp(tester, _layout(withFooter: false));
    expect(tester.takeException(), isNull);
    expect(find.text('Kaki'), findsNothing);
  });

  testWidgets('HP kecil dengan keyboard: tidak overflow, tombol bisa di-scroll dan ditekan', (tester) async {
    await pumpApp(tester, _layout(), size: const Size(320, 568));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Aksi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aksi'));
    expect(tapped, 1);
  });

  testWidgets('teks diperbesar 1.3 di 320 lebar tidak overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, _layout(), size: const Size(320, 568));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tepi atas isian pertama bisa diketuk', (tester) async {
    await pumpApp(tester, _layout());
    final top = tester.getTopLeft(find.byType(TextField).first);
    await tester.tapAt(top + const Offset(60, 3));
    await tester.pump();
    expect(tester.widget<EditableText>(find.byType(EditableText).first).focusNode.hasFocus, isTrue);
  });

  testWidgets('safe area samping (landscape berponi) tidak menutupi isi', (tester) async {
    await pumpApp(tester, _layout(), size: const Size(844, 600));
    tester.view.padding = const FakeViewPadding(left: 48, right: 48);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Yuk, atur keuanganmu')).dx, greaterThanOrEqualTo(48 + 24));
    expect(tester.getTopLeft(find.byType(AppTextField).first).dx, greaterThanOrEqualTo(48 + 20));
  });

  testWidgets('status bar ikon terang, nav bar Android ikut warna sheet', (tester) async {
    await pumpApp(tester, _layout());
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
    expect(SystemChrome.latestStyle?.systemNavigationBarColor, AppColors.surface);
    expect(SystemChrome.latestStyle?.systemNavigationBarIconBrightness, Brightness.dark);
  });
}
```

Di `test/widgets/app_system_ui_test.dart`, ubah `AuthLayout(...)` menjadi:

```dart
      home: AuthLayout(
        title: 'DompetKu',
        subtitle: 'x',
        leading: const AuthLogo(icon: PhosphorIconsFill.wallet),
        children: [AppPrimaryButton(label: 'Aksi', onPressed: () {})],
      ),
```

(import `package:catat_uang_app/screens/login/auth_parts.dart`).

- [ ] **Step 2: Jalankan** `flutter test test/screens/login/auth_layout_test.dart` → FAIL kompilasi (`children` bukan parameter).

- [ ] **Step 3: Implementasi**

`lib/widgets/app_system_ui.dart`: `onHero.systemNavigationBarColor` diganti `AppColors.surface` (sheet kini putih); komentar "mengikuti latar sheet di bawah" tetap benar.

`lib/screens/login/auth_layout.dart` (seluruh isi, `export` dari Task 3 tetap):

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_system_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

export 'auth_parts.dart' show AuthLogo, AuthFooter, AuthBackButton;

/// Kerangka layar auth (gaya referensi Rotta): hero gradasi biru berdekorasi
/// lingkaran tipis, lalu sheet putih bersudut atas membulat. [children]
/// tersusun dari atas dengan jarak 12; [footer] opsional menempel di dasar.
/// Seluruh isi bisa di-scroll saat keyboard terbuka.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.children,
    this.footer,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final List<Widget> children;
  final Widget? footer;

  static const double _sheetRadius = 24;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.onHero,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        const Positioned(right: -80, top: -70, child: _Ring(size: 240)),
                        const Positioned(right: -36, top: -26, child: _Ring(size: 150)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(padding.left + 24, padding.top + 20, padding.right + 24, 32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  leading,
                                  const SizedBox(height: 18),
                                  Text(
                                    title,
                                    style: AppTextStyles.title.copyWith(fontSize: 26, color: AppColors.white),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    subtitle,
                                    style: AppTextStyles.subhead.copyWith(fontSize: 13, color: AppColors.heroLabel),
                                  ),
                                ],
                              ),
                            ),
                            // Sudut sheet sebagai kotak nyata (bukan Transform),
                            // jadi tidak ada ruang kosong tersembunyi di bawah.
                            Container(
                              height: _sheetRadius,
                              decoration: const BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padding.left + 20, 0, padding.right + 20, padding.bottom + 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < children.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            children[i],
                          ],
                          const SizedBox(height: 24),
                          const Spacer(),
                          if (footer != null) footer!,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lingkaran garis tipis dekoratif di hero.
class _Ring extends StatelessWidget {
  const _Ring({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white.withValues(alpha: 0.13), width: 1.5),
      ),
    );
  }
}
```

Agar `login_screen.dart` dan `register_screen.dart` tetap terkompilasi sampai Task 5, ubah pemanggilan `AuthLayout` di keduanya:
`children: [...fields, action, footer]` (hapus `sheetTitle:`, `fields:`, `action:`, `footer:`; judul sheet Login "Masuk ke akunmu" menjadi `Text('Masuk ke akunmu', style: AppTextStyles.title.copyWith(fontSize: 16))` sebagai anak pertama).

- [ ] **Step 4: Jalankan** `flutter test test/screens/login/ test/screens/register/ test/widgets/app_system_ui_test.dart test/conventions_test.dart` → PASS. (Tes lama login/register yang memeriksa posisi tombol di dasar tidak ada; bila ada yang gagal karena posisi, itu diganti total di Task 5 — catat sebagai Ruling bila perlu.)
- [ ] **Step 5: Commit** `feat(auth): white sheet AuthLayout with decorated hero and free children`.

---

### Task 5: `LoginScreen` dengan tab Masuk | Daftar

**Files:**
- Create: `lib/screens/login/login_form.dart`, `lib/screens/login/register_form.dart`
- Modify: `lib/screens/login/login_screen.dart` (seluruh isi)
- Modify: `lib/screens/login/auth_parts.dart`, `lib/screens/login/auth_layout.dart` (hapus `AuthFooter`, `AuthBackButton`, dan `export`)
- Delete: `lib/screens/register/register_screen.dart`, `test/screens/register/register_screen_test.dart`
- Test: `test/screens/login/login_screen_test.dart` (tulis ulang)

**Interfaces:**
- Consumes: `AuthLayout` (Task 4), `AuthLogo/AuthDivider/AuthGoogleButton` (Task 3), `AppTextField(outlined, label)` (Task 2), `AppNotification.info` (Task 1), `AppSegmentedControl(labels, selectedIndex, onChanged)`.
- Produces: `LoginForm({required TextEditingController emailController, required VoidCallback onGoogle})`, `RegisterForm({required ValueChanged<String> onRegistered, required VoidCallback onGoogle})`.

- [ ] **Step 1: Tes gagal** — tulis ulang `test/screens/login/login_screen_test.dart`:

```dart
import 'package:catat_uang_app/screens/login/login_form.dart';
import 'package:catat_uang_app/screens/login/login_screen.dart';
import 'package:catat_uang_app/screens/login/register_form.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

Finder _primary(String label) => find.widgetWithText(AppPrimaryButton, label);

Future<void> _toDaftar(WidgetTester tester) async {
  await tester.tap(find.text('Daftar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tab Masuk tampil default sesuai mockup', (tester) async {
    await pumpApp(tester, const LoginScreen());
    expect(find.text('Yuk, atur keuanganmu'), findsOneWidget);
    expect(find.text('Masuk atau buat akun untuk mulai mencatat pemasukan dan pengeluaranmu.'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.wallet), findsOneWidget);
    expect(find.byType(LoginForm), findsOneWidget);
    expect(find.byType(RegisterForm), findsNothing);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(_primary('Masuk'), findsOneWidget);
    expect(find.text('atau masuk dengan'), findsOneWidget);
    expect(find.text('Lanjut dengan Google'), findsOneWidget);
    expect(find.text('Datamu hanya bisa dilihat dari akunmu sendiri.'), findsOneWidget);
    expect(find.textContaining('Facebook'), findsNothing);
    expect(find.text('Lupa password?'), findsNothing);
    final fields = tester.widgetList<AppTextField>(find.byType(AppTextField));
    expect(fields.length, 2);
    expect(fields.every((f) => f.outlined), isTrue);
  });

  testWidgets('Masuk kosong menampilkan toast validasi', (tester) async {
    await pumpApp(tester, const LoginScreen());
    await tester.tap(_primary('Masuk'));
    await tester.pump();
    expect(find.text('Email dan Password wajib diisi!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Masuk: isian hanya spasi ditolak', (tester) async {
    await pumpApp(tester, const LoginScreen());
    for (final f in find.byType(TextField).evaluate().toList()) {
      await tester.enterText(find.byWidget(f.widget), '   ');
    }
    await tester.tap(_primary('Masuk'));
    await tester.pump();
    expect(find.text('Email dan Password wajib diisi!'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('ikon mata men-toggle visibilitas password', (tester) async {
    await pumpApp(tester, const LoginScreen());
    EditableText password() => tester.widgetList<EditableText>(find.byType(EditableText)).elementAt(1);
    expect(password().obscureText, isTrue);
    await tester.tap(find.byIcon(PhosphorIconsRegular.eye));
    await tester.pump();
    expect(find.byIcon(PhosphorIconsRegular.eyeSlash), findsOneWidget);
    expect(password().obscureText, isFalse);
  });

  testWidgets('pindah ke tab Daftar menampilkan form daftar tanpa footer', (tester) async {
    await pumpApp(tester, const LoginScreen());
    await _toDaftar(tester);
    expect(find.byType(RegisterForm), findsOneWidget);
    expect(find.text('Nama lengkap'), findsOneWidget);
    expect(find.text('Minimal 6 karakter.'), findsOneWidget);
    expect(_primary('Daftar Sekarang'), findsOneWidget);
    expect(find.text('atau daftar dengan'), findsOneWidget);
    expect(find.text('Datamu hanya bisa dilihat dari akunmu sendiri.'), findsNothing);
    final fields = tester.widgetList<AppTextField>(find.byType(AppTextField));
    expect(fields.length, 3);
    expect(fields.every((f) => f.outlined), isTrue);
  });

  testWidgets('Daftar kosong dan spasi saja ditolak dengan pesan lama', (tester) async {
    await pumpApp(tester, const LoginScreen());
    await _toDaftar(tester);
    await tester.ensureVisible(_primary('Daftar Sekarang'));
    await tester.tap(_primary('Daftar Sekarang'));
    await tester.pump();
    expect(find.text('Semua kolom wajib diisi ya bos!'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    for (final f in find.byType(TextField).evaluate().toList()) {
      await tester.enterText(find.byWidget(f.widget), '   ');
    }
    await tester.ensureVisible(_primary('Daftar Sekarang'));
    await tester.tap(_primary('Daftar Sekarang'));
    await tester.pump();
    expect(find.text('Semua kolom wajib diisi ya bos!'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  for (final tab in ['Masuk', 'Daftar']) {
    testWidgets('Google di tab $tab memunculkan info belum tersedia', (tester) async {
      await pumpApp(tester, const LoginScreen());
      if (tab == 'Daftar') await _toDaftar(tester);
      await tester.ensureVisible(find.text('Lanjut dengan Google'));
      await tester.tap(find.text('Lanjut dengan Google'));
      await tester.pump();
      expect(find.text('Login Google belum tersedia. Pakai email dan password dulu ya.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  }

  testWidgets('daftar berhasil: kembali ke tab Masuk dengan email terisi', (tester) async {
    await pumpApp(tester, const LoginScreen());
    await _toDaftar(tester);
    tester.widget<RegisterForm>(find.byType(RegisterForm)).onRegistered('baru@contoh.com');
    await tester.pumpAndSettle();
    expect(find.byType(LoginForm), findsOneWidget);
    expect(find.text('baru@contoh.com'), findsOneWidget);
  });

  for (final tab in ['Masuk', 'Daftar']) {
    testWidgets('tab $tab dengan keyboard di HP kecil tidak overflow', (tester) async {
      await pumpApp(tester, const LoginScreen(), size: const Size(320, 568));
      if (tab == 'Daftar') await _toDaftar(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = _primary(tab == 'Masuk' ? 'Masuk' : 'Daftar Sekarang');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      expect(
        find.text(tab == 'Masuk' ? 'Email dan Password wajib diisi!' : 'Semua kolom wajib diisi ya bos!'),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  }
}
```

Hapus `test/screens/register/register_screen_test.dart` (seluruh cakupannya pindah ke sini).

- [ ] **Step 2: Jalankan** `flutter test test/screens/login/login_screen_test.dart` → FAIL kompilasi (`login_form.dart` tidak ada).

- [ ] **Step 3: Implementasi**

`lib/screens/login/login_form.dart` — `_login()` disalin byte-demi-byte dari `login_screen.dart` saat ini:

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/home/home_screen.dart';
import 'package:catat_uang_app/screens/login/auth_parts.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tab "Masuk". Controller email milik [LoginScreen] supaya email hasil daftar
/// bisa diisikan ke sini.
class LoginForm extends StatefulWidget {
  const LoginForm({required this.emailController, required this.onGoogle, super.key});

  final TextEditingController emailController;
  final VoidCallback onGoogle;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  TextEditingController get _emailController => widget.emailController;
  final _passwordController = TextEditingController();

  // Getter (bukan field) supaya Supabase.instance baru diakses saat login
  // benar-benar dijalankan — layar bisa dirender di widget test tanpa
  // Supabase.initialize.
  SupabaseClient get _supabase => Supabase.instance.client;

  bool _isLoading = false;
  bool _isObscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  // <_login() disalin apa adanya dari login_screen.dart>

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'email@contoh.com',
          icon: PhosphorIconsRegular.envelopeSimple,
          keyboardType: TextInputType.emailAddress,
          outlined: true,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Masukkan password Anda',
          icon: PhosphorIconsRegular.lockKey,
          obscure: _isObscure,
          outlined: true,
          suffix: IconButton(
            onPressed: () => setState(() => _isObscure = !_isObscure),
            icon: Icon(
              _isObscure ? PhosphorIconsRegular.eye : PhosphorIconsRegular.eyeSlash,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 18),
        AppPrimaryButton(label: 'Masuk', onPressed: _isLoading ? null : _login, loading: _isLoading),
        const SizedBox(height: 18),
        const AuthDivider(label: 'atau masuk dengan'),
        const SizedBox(height: 18),
        AuthGoogleButton(label: 'Lanjut dengan Google', onTap: widget.onGoogle),
      ],
    );
  }
}
```

`lib/screens/login/register_form.dart` — `_register()` disalin dari `register_screen.dart`, **satu-satunya** perubahan: baris `Navigator.pop(context);` menjadi `widget.onRegistered(_emailController.text);`:

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/login/auth_parts.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tab "Daftar". Setelah berhasil, [onRegistered] menerima email baru —
/// [LoginScreen] pindah ke tab Masuk (dulu Navigator.pop ke layar Login).
class RegisterForm extends StatefulWidget {
  const RegisterForm({required this.onRegistered, required this.onGoogle, super.key});

  final ValueChanged<String> onRegistered;
  final VoidCallback onGoogle;

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Getter lazy: lihat catatan di LoginForm.
  SupabaseClient get _supabase => Supabase.instance.client;

  bool _isLoading = false;
  bool _isObscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // <_register() disalin; Navigator.pop(context) → widget.onRegistered(_emailController.text)>

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _nameController,
          label: 'Nama lengkap',
          hint: 'Masukkan nama asli bos',
          icon: PhosphorIconsRegular.user,
          outlined: true,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'email@contoh.com',
          icon: PhosphorIconsRegular.envelopeSimple,
          keyboardType: TextInputType.emailAddress,
          outlined: true,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Buat password yang kuat',
          icon: PhosphorIconsRegular.lockKey,
          obscure: _isObscure,
          outlined: true,
          suffix: IconButton(
            onPressed: () => setState(() => _isObscure = !_isObscure),
            icon: Icon(
              _isObscure ? PhosphorIconsRegular.eye : PhosphorIconsRegular.eyeSlash,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('Minimal 6 karakter.', style: AppTextStyles.caption),
        ),
        const SizedBox(height: 18),
        AppPrimaryButton(label: 'Daftar Sekarang', onPressed: _isLoading ? null : _register, loading: _isLoading),
        const SizedBox(height: 18),
        const AuthDivider(label: 'atau daftar dengan'),
        const SizedBox(height: 18),
        AuthGoogleButton(label: 'Lanjut dengan Google', onTap: widget.onGoogle),
      ],
    );
  }
}
```

`lib/screens/login/login_screen.dart` (seluruh isi):

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/screens/login/auth_layout.dart';
import 'package:catat_uang_app/screens/login/auth_parts.dart';
import 'package:catat_uang_app/screens/login/login_form.dart';
import 'package:catat_uang_app/screens/login/register_form.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Layar auth tunggal: tab Masuk | Daftar di atas sheet putih.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _tab = 0;
  final _loginEmail = TextEditingController();

  @override
  void dispose() {
    _loginEmail.dispose();
    super.dispose();
  }

  void _google() =>
      AppNotification.info(context, 'Login Google belum tersedia. Pakai email dan password dulu ya.');

  void _onRegistered(String email) => setState(() {
        _loginEmail.text = email;
        _tab = 0;
      });

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Yuk, atur keuanganmu',
      subtitle: 'Masuk atau buat akun untuk mulai mencatat pemasukan dan pengeluaranmu.',
      leading: const AuthLogo(icon: PhosphorIconsFill.wallet),
      children: [
        AppSegmentedControl(
          labels: const ['Masuk', 'Daftar'],
          selectedIndex: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        if (_tab == 0)
          LoginForm(emailController: _loginEmail, onGoogle: _google)
        else
          RegisterForm(onRegistered: _onRegistered, onGoogle: _google),
      ],
      footer: _tab == 0
          ? Text(
              'Datamu hanya bisa dilihat dari akunmu sendiri.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            )
          : null,
    );
  }
}
```

Lalu: `git rm lib/screens/register/register_screen.dart test/screens/register/register_screen_test.dart`; hapus `AuthFooter` dan `AuthBackButton` dari `auth_parts.dart`, dan baris `export` dari `auth_layout.dart` (sesuaikan import tes yang memakai `AuthLogo` lewat `auth_layout.dart` agar mengimpor `auth_parts.dart`). Cek: `grep -rn "RegisterScreen\|AuthFooter\|AuthBackButton\|register_screen" lib test` kosong.

- [ ] **Step 4: Jalankan** `flutter test test/screens/login/ test/widgets/ test/core/ test/conventions_test.dart test/architecture/` → PASS; `flutter analyze` → 0 error/warning.
- [ ] **Step 5: Commit** `feat(auth): merge login and register into tabbed screen with Google placeholder`.

---

### Task 6: Screenshot + verifikasi penuh

**Files:**
- Modify: `test/screenshots/b7_screenshots_test.dart`

- [ ] **Step 1: Perbarui tes screenshot** — hapus import `register_screen.dart`; ganti tes `02 daftar akun` dan tambah shot toast:

```dart
  testWidgets('02 daftar akun', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const LoginScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b7_02_register');
  }, skip: skip);

  testWidgets('02c toast Google', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const LoginScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut dengan Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await saveScreenshot(tester, 'b7_02c_google_toast');
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }, skip: skip);
```

- [ ] **Step 2: Hasilkan** `flutter test test/screenshots/b7_screenshots_test.dart` → 7 PASS (tanpa skip). Bandingkan `b7_01_login`, `b7_01b_login_focus`, `b7_02_register`, `b7_02c_google_toast` dengan mockup.
- [ ] **Step 3: Verifikasi penuh** — `flutter analyze` → 0 error/warning; `E2E_EMAIL=… E2E_PASSWORD=… flutter test` → semua lulus.
- [ ] **Step 4: Commit** `test(auth): screenshots for tabbed auth and Google toast`.
- [ ] **Step 5: Review akhir** — reviewer baru (opus) seluruh branch; perbaiki semua temuan (termasuk minor) RED→GREEN; kirim screenshot ke pengguna; merge lokal hanya setelah pengguna setuju. Tidak push.
