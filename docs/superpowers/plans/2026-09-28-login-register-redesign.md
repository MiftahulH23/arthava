# Redesign Login & Daftar — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Layar Login & Daftar mengikuti mockup A (hero gradasi biru + sheet membulat + isian terpisah bergaris tepi dengan cincin fokus), tanpa mengubah logika auth.

**Architecture:** `AppTextField` mendapat varian `outlined` (default off, 30+ pemakaian lain tak berubah) yang melacak fokus untuk garis tepi/cincin. Tata letak auth dipindah ke `AuthLayout` baru (`lib/screens/login/auth_layout.dart`) berbasis `CustomScrollView` + `SliverFillRemaining(hasScrollBody: false)` supaya tombol menempel di bawah pada layar tinggi dan bisa di-scroll saat keyboard terbuka. `auth_brand.dart` dihapus.

**Tech Stack:** Flutter 3.38.5, phosphor_flutter, AppColors/AppTextStyles, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-28-login-register-design.md`

## Global Constraints

- `_login()` dan `_register()` tidak diubah satu karakter pun (validasi, pesan, Supabase, navigasi).
- Tidak ada `Color(0x…)` di `lib/screens`/`lib/widgets` — warna baru hanya di `AppColors` (`focusRing = Color(0x21007AFF)`).
- Tidak ada `GoogleFonts.*` di layar/widget; pakai `AppTextStyles`.
- Ikon Phosphor Regular/Fill/Bold saja.
- "Lupa password?" tidak dibuat.
- Commit Conventional Commits; branch `feat/login-register-redesign`; tidak push.
- Selesai = `flutter analyze` bersih + `flutter test` penuh (termasuk E2E via env `E2E_EMAIL`/`E2E_PASSWORD`, tidak pernah disimpan) lulus.

## Review Focus

1. Keyboard terbuka di HP kecil (320×568, inset bawah 300) → tidak overflow, tombol bisa di-scroll dan ditekan (Task 2).
2. Layar tinggi (390×844) → tombol utama menempel dekat bawah, bukan tepat di bawah isian (Task 2).
3. Teks diperbesar (textScale 1.3) di 320 lebar → tidak overflow (Task 2).
4. `focusNode` milik pemanggil pada `AppTextField(outlined: true)` → tidak di-dispose oleh widget, fokus tetap terlacak (Task 1).
5. Field tanpa `outlined` → tetap tanpa garis tepi (regresi 30+ form lain) (Task 1).

---

### Task 1: `AppTextField(outlined: true)` + `AppColors.focusRing`

**Files:**
- Modify: `lib/core/colors.dart` (tambah konstanta di blok Phase B)
- Modify: `lib/widgets/app_text_field.dart` (jadi StatefulWidget)
- Test: `test/widgets/app_text_field_test.dart`

**Interfaces:**
- Produces: `AppTextField({..., bool outlined = false})`; `AppColors.focusRing`. Saat outlined, TextField dibungkus satu `AnimatedContainer` (radius 14) yang `boxShadow`-nya berisi cincin fokus saat fokus, kosong saat tidak.

- [ ] **Step 1: Tulis tes gagal** — tambahkan ke `main()` di `test/widgets/app_text_field_test.dart` (tambah import `package:catat_uang_app/core/colors.dart` dan `package:phosphor_flutter/phosphor_flutter.dart`):

```dart
  BoxDecoration ring(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration! as BoxDecoration;
  Color prefixColor(WidgetTester tester) =>
      tester.widget<Icon>(find.byIcon(PhosphorIconsRegular.envelopeSimple)).color!;

  testWidgets('outlined: garis tepi track, fokus menampilkan cincin dan ikon biru', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: AppTextField(
      controller: controller, hint: 'email', icon: PhosphorIconsRegular.envelopeSimple, outlined: true)));

    final deco = tester.widget<TextField>(find.byType(TextField)).decoration!;
    final enabled = deco.enabledBorder! as OutlineInputBorder;
    expect(enabled.borderSide.color, AppColors.track);
    expect(enabled.borderSide.width, 1.5);
    expect((deco.focusedBorder! as OutlineInputBorder).borderSide.color, AppColors.primary);
    expect(ring(tester).boxShadow, anyOf(isNull, isEmpty));
    expect(prefixColor(tester), AppColors.textSecondary);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(ring(tester).boxShadow!.single.color, AppColors.focusRing);
    expect(ring(tester).boxShadow!.single.spreadRadius, 4);
    expect(prefixColor(tester), AppColors.primary);
  });

  testWidgets('outlined memakai focusNode pemanggil tanpa men-dispose-nya', (tester) async {
    final controller = TextEditingController();
    final node = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(node.dispose);
    await pumpApp(tester, Scaffold(body: AppTextField(
      controller: controller, focusNode: node, icon: PhosphorIconsRegular.envelopeSimple, outlined: true)));

    node.requestFocus();
    await tester.pumpAndSettle();
    expect(ring(tester).boxShadow, isNotEmpty);

    await tester.pumpWidget(const SizedBox());
    // Node masih milik pemanggil: tidak boleh sudah di-dispose.
    expect(() => node.addListener(() {}), returnsNormally);
  });

  testWidgets('tanpa outlined: tetap tanpa garis tepi dan tanpa cincin', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: AppTextField(controller: controller, hint: 'x')));
    final enabled = tester.widget<TextField>(find.byType(TextField)).decoration!.enabledBorder! as OutlineInputBorder;
    expect(enabled.borderSide, BorderSide.none);
    expect(find.byType(AnimatedContainer), findsNothing);
  });
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/widgets/app_text_field_test.dart`
Expected: FAIL kompilasi — `No named parameter with the name 'outlined'` / `focusRing` tidak ada.

- [ ] **Step 3: Implementasi**

`lib/core/colors.dart`, setelah `primarySoft`:

```dart
  static const Color focusRing = Color(0x21007AFF); // Cincin fokus isian bergaris tepi (biru 13%)
```

Ganti isi `lib/widgets/app_text_field.dart` (parameter & field lama tetap, akses via `widget.`):

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Field putih gaya iOS. Default tanpa border (radius 16); [outlined] =
/// isian terpisah radius 14 bergaris tepi 1.5px, fokus menampilkan garis
/// biru + cincin 4px (layar Login/Daftar).
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.controller,
    this.hint,
    this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.readOnly = false,
    this.maxLines = 1,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.label,
    this.onChanged,
    this.inputFormatters,
    this.outlined = false,
    super.key,
  });

  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final bool readOnly;
  final int maxLines;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  /// Label kecil opsional di atas input (gaya baris iOS "Nama Lengkap" +
  /// nilai). Null = tanpa label.
  final String? label;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final bool outlined;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());
  bool _focused = false;

  void _onFocusChange() {
    if (_focused != _node.hasFocus) setState(() => _focused = _node.hasFocus);
  }

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.focusNode ?? _ownNode;
    if (previous != _node) {
      previous?.removeListener(_onFocusChange);
      _node.addListener(_onFocusChange);
      _focused = _node.hasFocus;
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outlined = widget.outlined;
    final radius = BorderRadius.circular(outlined ? 14 : 16);
    final idleSide = outlined ? const BorderSide(color: AppColors.track, width: 1.5) : BorderSide.none;
    final iconColor = outlined && _focused ? AppColors.primary : AppColors.textSecondary;
    Widget field = TextField(
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
        prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 20, color: iconColor),
        suffixIcon: widget.suffix,
        filled: true,
        fillColor: widget.readOnly ? AppColors.track : AppColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: outlined ? 14 : 16),
        border: OutlineInputBorder(borderRadius: radius, borderSide: idleSide),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: idleSide),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
    if (outlined) {
      field = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: _focused
              ? const [BoxShadow(color: AppColors.focusRing, spreadRadius: 4)]
              : const [],
        ),
        child: field,
      );
    }
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
}
```

Catatan: tes lama "tanpa label tidak menambah teks apa pun" (`find.byType(Column)` findsNothing) tetap lulus karena varian default tidak menambah Column.

- [ ] **Step 4: Jalankan, pastikan lulus**

Run: `flutter test test/widgets/app_text_field_test.dart test/conventions_test.dart`
Expected: semua PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/colors.dart lib/widgets/app_text_field.dart test/widgets/app_text_field_test.dart
git commit -m "feat(widgets): add outlined AppTextField variant with focus ring"
```

---

### Task 2: `AuthLayout` (hero + sheet) dan `AuthFooter`

**Files:**
- Create: `lib/screens/login/auth_layout.dart`
- Test: `test/screens/login/auth_layout_test.dart`

**Interfaces:**
- Consumes: `AppColors.heroGradientStart/End`, `AppColors.heroLabel`, `AppColors.white`, `AppTextStyles.title/subhead/headline`.
- Produces:
  - `AuthLayout({required String title, required String subtitle, required Widget leading, String? sheetTitle, required List<Widget> fields, required Widget action, required Widget footer})`
  - `AuthLogo({required IconData icon})` — kotak 44 putih 18%, radius 12.
  - `AuthBackButton({required String label, required VoidCallback onTap})` — caret kiri + label putih.
  - `AuthFooter({required String prompt, required String action, required VoidCallback onTap})` — dipindah apa adanya dari `auth_brand.dart` (file lama dihapus di Task 4).

- [ ] **Step 1: Tulis tes gagal** — `test/screens/login/auth_layout_test.dart`:

```dart
import 'package:catat_uang_app/screens/login/auth_layout.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

var tapped = 0;

Widget _layout() => AuthLayout(
      title: 'DompetKu',
      subtitle: 'Tagline',
      leading: const AuthLogo(icon: PhosphorIconsFill.wallet),
      sheetTitle: 'Masuk ke akunmu',
      fields: [
        AppTextField(controller: TextEditingController(), hint: 'a', outlined: true),
        AppTextField(controller: TextEditingController(), hint: 'b', outlined: true),
        AppTextField(controller: TextEditingController(), hint: 'c', outlined: true),
      ],
      action: AppPrimaryButton(label: 'Aksi', onPressed: () => tapped++),
      footer: AuthFooter(prompt: 'Belum? ', action: 'Daftar', onTap: () {}),
    );

void main() {
  setUp(() => tapped = 0);

  testWidgets('menampilkan hero, judul sheet, isian, tombol, footer', (tester) async {
    await pumpApp(tester, _layout());
    expect(find.text('DompetKu'), findsOneWidget);
    expect(find.text('Tagline'), findsOneWidget);
    expect(find.text('Masuk ke akunmu'), findsOneWidget);
    expect(find.byType(AppTextField), findsNWidgets(3));
    expect(find.text('Daftar'), findsOneWidget);
  });

  testWidgets('layar tinggi: tombol menempel dekat bawah', (tester) async {
    await pumpApp(tester, _layout(), size: const Size(390, 844));
    expect(tester.getBottomLeft(find.text('Daftar')).dy, greaterThan(760));
    expect(tester.getTopLeft(find.text('Aksi')).dy - tester.getBottomLeft(find.text('c')).dy, greaterThan(100));
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

  testWidgets('AuthBackButton memanggil onTap', (tester) async {
    var back = 0;
    await pumpApp(tester, Scaffold(body: ColoredBox(
      color: Colors.black, child: AuthBackButton(label: 'Masuk', onTap: () => back++))));
    await tester.tap(find.text('Masuk'));
    expect(back, 1);
    expect(find.byIcon(PhosphorIconsBold.caretLeft), findsOneWidget);
  });
}
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/screens/login/auth_layout_test.dart`
Expected: FAIL kompilasi — `auth_layout.dart` tidak ada.

- [ ] **Step 3: Implementasi** — `lib/screens/login/auth_layout.dart`:

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Kerangka layar auth (mockup A): hero gradasi biru di atas, sheet abu
/// membulat yang menutupi hero 30px. Tombol & footer menempel di bawah pada
/// layar tinggi; seluruh isi bisa di-scroll saat keyboard terbuka.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.fields,
    required this.action,
    required this.footer,
    this.sheetTitle,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final String? sheetTitle;
  final List<Widget> fields;
  final Widget action;
  final Widget footer;

  static const double _overlap = 30;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
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
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, padding.top + 16, 24, _overlap + 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          leading,
                          const SizedBox(height: 14),
                          Text(
                            title,
                            style: AppTextStyles.title.copyWith(fontSize: 24, color: AppColors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: AppTextStyles.subhead.copyWith(fontSize: 12.5, color: AppColors.heroLabel),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -_overlap),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                        ),
                        padding: EdgeInsets.fromLTRB(20, 24, 20, padding.bottom + 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (sheetTitle != null) ...[
                              Text(sheetTitle!, style: AppTextStyles.title.copyWith(fontSize: 16)),
                              const SizedBox(height: 14),
                            ],
                            for (var i = 0; i < fields.length; i++) ...[
                              if (i > 0) const SizedBox(height: 12),
                              fields[i],
                            ],
                            const SizedBox(height: 24),
                            const Spacer(),
                            action,
                            const SizedBox(height: 14),
                            footer,
                          ],
                        ),
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

/// Kotak logo kecil di hero Login (putih 18% di atas gradasi).
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

/// Tombol kembali "‹ Masuk" putih di hero Daftar.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({required this.label, required this.onTap, super.key});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(PhosphorIconsBold.caretLeft, size: 16, color: AppColors.white),
              const SizedBox(width: 4),
              Text(label, style: AppTextStyles.subhead.copyWith(fontWeight: FontWeight.w600, color: AppColors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris "Belum punya akun? Daftar Disini" di bawah form auth.
class AuthFooter extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onTap;

  const AuthFooter({
    required this.prompt,
    required this.action,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap: di layar sempit tautan turun ke baris berikut, bukan overflow.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt, style: AppTextStyles.subhead),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: AppTextStyles.subhead.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
```

Bila `SliverFillRemaining` melempar galat intrinsic (TextField/Wrap), ganti dengan `LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox(minHeight: constraints.maxHeight)` + `IntrinsicHeight`; tes yang sama harus tetap lulus.

- [ ] **Step 4: Jalankan, pastikan lulus**

Run: `flutter test test/screens/login/auth_layout_test.dart test/conventions_test.dart`
Expected: semua PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/login/auth_layout.dart test/screens/login/auth_layout_test.dart
git commit -m "feat(auth): add hero and sheet AuthLayout"
```

---

### Task 3: Login memakai `AuthLayout`

**Files:**
- Modify: `lib/screens/login/login_screen.dart:1-13` (import), `:67-129` (`build`)
- Test: `test/screens/login/login_screen_test.dart`

**Interfaces:**
- Consumes: `AuthLayout`, `AuthLogo`, `AuthFooter` (Task 2); `AppTextField(outlined: true)` (Task 1).

- [ ] **Step 1: Ubah tes jadi gagal** — di tes pertama `login_screen_test.dart`, ganti dua baris

```dart
    expect(find.text('Selamat Datang!'), findsOneWidget);
    expect(find.text('Silakan masuk untuk melanjutkan'), findsOneWidget);
```

menjadi

```dart
    expect(find.text('Masuk ke akunmu'), findsOneWidget);
    expect(find.text('Selamat Datang!'), findsNothing);
    expect(find.text('Lupa password?'), findsNothing);
    final fields = tester.widgetList<AppTextField>(find.byType(AppTextField));
    expect(fields.length, 2);
    expect(fields.every((f) => f.outlined), isTrue);
```

dan tambah import `package:catat_uang_app/widgets/app_text_field.dart`. Tambah tes:

```dart
  testWidgets('Login dengan keyboard terbuka di HP kecil tidak overflow', (tester) async {
    await pumpApp(tester, const LoginScreen(), size: const Size(320, 568));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Masuk Sekarang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk Sekarang'));
    await tester.pump();
    expect(find.text('Email dan Password wajib diisi!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/screens/login/login_screen_test.dart`
Expected: FAIL — `Masuk ke akunmu` tidak ditemukan.

- [ ] **Step 3: Implementasi** — ganti import `auth_brand.dart`, `app_grouped_section.dart`, `app_page_scaffold.dart`, `app_text_styles.dart` dengan `package:catat_uang_app/screens/login/auth_layout.dart`, lalu ganti `build` (`_login` tidak disentuh):

```dart
  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'DompetKu',
      subtitle: 'Cerdas mengelola, tenang finansial',
      leading: const AuthLogo(icon: PhosphorIconsFill.wallet),
      sheetTitle: 'Masuk ke akunmu',
      fields: [
        AppTextField(
          controller: _emailController,
          hint: 'email@contoh.com',
          icon: PhosphorIconsRegular.envelopeSimple,
          keyboardType: TextInputType.emailAddress,
          outlined: true,
        ),
        AppTextField(
          controller: _passwordController,
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
      ],
      action: AppPrimaryButton(
        label: 'Masuk Sekarang',
        onPressed: _isLoading ? null : _login,
        loading: _isLoading,
      ),
      footer: AuthFooter(
        prompt: 'Belum punya akun? ',
        action: 'Daftar Disini',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegisterScreen()),
          );
        },
      ),
    );
  }
```

- [ ] **Step 4: Jalankan, pastikan lulus**

Run: `flutter test test/screens/login/ && flutter analyze lib/screens/login`
Expected: PASS; analyze tanpa issue (tidak ada import tak terpakai).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/login/login_screen.dart test/screens/login/login_screen_test.dart
git commit -m "feat(auth): restyle login with hero sheet and outlined fields"
```

---

### Task 4: Daftar memakai `AuthLayout`, hapus `auth_brand.dart`

**Files:**
- Modify: `lib/screens/register/register_screen.dart:1-10` (import), `:79-135` (`build`)
- Delete: `lib/screens/login/auth_brand.dart`
- Test: `test/screens/register/register_screen_test.dart`

**Interfaces:**
- Consumes: `AuthLayout`, `AuthBackButton`, `AuthFooter` (Task 2); `AppTextField(outlined: true)` (Task 1).

- [ ] **Step 1: Ubah tes jadi gagal** — ganti isi tes pertama `register_screen_test.dart` dengan:

```dart
  testWidgets('Daftar Akun menampilkan layout sesuai mockup', (tester) async {
    await _openRegister(tester);

    expect(find.text('Buat akun baru'), findsOneWidget);
    expect(find.text('Gabung dan mulai atur keuanganmu'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget); // tombol kembali di hero
    expect(find.byIcon(PhosphorIconsBold.caretLeft), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.user), findsOneWidget);
    expect(find.text('Nama lengkap'), findsOneWidget); // hint
    expect(find.text('Minimal 6 karakter.'), findsOneWidget);
    expect(find.text('Daftar Sekarang'), findsOneWidget);
    expect(find.text('Masuk Disini'), findsOneWidget);
    final fields = tester.widgetList<AppTextField>(find.byType(AppTextField));
    expect(fields.length, 3);
    expect(fields.every((f) => f.outlined), isTrue);
  });
```

tambah import `package:catat_uang_app/widgets/app_text_field.dart`, dan tambah tes:

```dart
  testWidgets('Daftar dengan keyboard terbuka di HP kecil tidak overflow', (tester) async {
    await pumpApp(tester, const RegisterScreen(), size: const Size(320, 568));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Daftar Sekarang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daftar Sekarang'));
    await tester.pump();
    expect(find.text('Semua kolom wajib diisi ya bos!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/screens/register/register_screen_test.dart`
Expected: FAIL — `Buat akun baru` tidak ditemukan.

- [ ] **Step 3: Implementasi** — ganti import `auth_brand.dart`, `app_grouped_section.dart`, `app_page_scaffold.dart` dengan `package:catat_uang_app/screens/login/auth_layout.dart` dan tambah `package:catat_uang_app/theme/app_text_styles.dart`. Ganti `build` (`_register` tidak disentuh):

```dart
  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Buat akun baru',
      subtitle: 'Gabung dan mulai atur keuanganmu',
      leading: AuthBackButton(label: 'Masuk', onTap: () => Navigator.pop(context)),
      fields: [
        AppTextField(
          controller: _nameController,
          hint: 'Nama lengkap',
          icon: PhosphorIconsRegular.user,
          outlined: true,
        ),
        AppTextField(
          controller: _emailController,
          hint: 'email@contoh.com',
          icon: PhosphorIconsRegular.envelopeSimple,
          keyboardType: TextInputType.emailAddress,
          outlined: true,
        ),
        AppTextField(
          controller: _passwordController,
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
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('Minimal 6 karakter.', style: AppTextStyles.caption),
        ),
      ],
      action: AppPrimaryButton(
        label: 'Daftar Sekarang',
        onPressed: _isLoading ? null : _register,
        loading: _isLoading,
      ),
      footer: AuthFooter(
        prompt: 'Sudah punya akun? ',
        action: 'Masuk Disini',
        onTap: () => Navigator.pop(context),
      ),
    );
  }
```

Hapus file lama: `git rm lib/screens/login/auth_brand.dart`.

- [ ] **Step 4: Jalankan, pastikan lulus**

Run: `flutter test test/screens/register/ test/screens/login/ && flutter analyze`
Expected: PASS; analyze 0 error/warning. `grep -rn auth_brand lib test` kosong.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/register/register_screen.dart test/screens/register/register_screen_test.dart
git commit -m "feat(auth): restyle register with hero sheet and outlined fields"
```

---

### Task 5: Screenshot + verifikasi penuh

**Files:**
- Modify: `test/screenshots/b7_screenshots_test.dart`

- [ ] **Step 1: Tambah shot fokus** — setelah tes `02 daftar akun`:

```dart
  testWidgets('02b login fokus email', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const LoginScreen());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'miftahul@contoh.com');
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'b7_01b_login_focus');
  }, skip: skip);
```

(tambah `import 'package:flutter/material.dart';` untuk `TextField`).

- [ ] **Step 2: Hasilkan screenshot**

Run: `bash tool/screenshots/fetch_fonts.sh` (bila `.dart_tool/screenshot_fonts` kosong), lalu `flutter test test/screenshots/b7_screenshots_test.dart`
Expected: 6 PASS (tidak ada yang skip). Buka `b7_01_login`, `b7_01b_login_focus`, `b7_02_register` dan bandingkan dengan mockup A: hero gradasi, sheet membulat menutupi hero, isian bergaris tepi, cincin biru di email, tombol di bawah.

- [ ] **Step 3: Verifikasi penuh**

Run: `flutter analyze` → 0 error/warning.
Run: `E2E_EMAIL=… E2E_PASSWORD=… flutter test` → semua lulus (E2E sebagai regresi; kredensial hanya lewat env).

- [ ] **Step 4: Commit**

```bash
git add test/screenshots/b7_screenshots_test.dart
git commit -m "test(auth): add login focus screenshot"
```

- [ ] **Step 5: Review akhir & serah terima** — reviewer baru (opus) memeriksa seluruh branch; perbaiki temuan (termasuk minor) dengan RED→GREEN; kirim screenshot ke pengguna; merge lokal ke `main` hanya setelah pengguna setuju. Tidak push.
