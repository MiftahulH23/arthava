# Phase B7 — Akun & Pembersihan Akhir Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mendesain ulang 5 screen akun (Login, Daftar Akun, Kunci Aplikasi, Pengaturan, Edit Profil) sesuai mockup iOS Blue, lalu menutup Phase B: hapus widget lama yang tak terpakai, pastikan seluruh `lib/` bebas Poppins dan warna hardcoded, perbarui `AGENTS.md`, dan jalankan verifikasi + review akhir.

**Architecture:** Setiap screen dirakit ulang dari komponen bersama Plan B1 (`AppPageScaffold`, `AppGroupedSection`, `AppListRow`, `AppIconTile`, `AppTextField`, `AppPrimaryButton`, `AppTextStyles`). Logika (auth Supabase, biometrik `local_auth`, provider `editProfileProvider`) tidak diubah; hanya ditambah *seam* minimal (getter lazy / parameter `@visibleForTesting`) supaya screen bisa dirender di widget test tanpa Supabase/plugin. Task pembersihan bekerja lintas seluruh app setelah B1–B6 selesai.

**Tech Stack:** Flutter, `flutter_riverpod` 2.6.1, `supabase_flutter`, `local_auth` 3.0.1, `phosphor_flutter` 2.1.0, `google_fonts` (Plus Jakarta Sans via `AppTextStyles`), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-24-redesign-phase-b-design.md` (baca §3, §4, §5, §6, §9, §10 sebelum mulai). Mockup: `docs/design/dompetku-redesign-mockup.html`, entri `SCREENS` bernama `Login`, `Daftar Akun`, `Kunci Aplikasi`, `Pengaturan`, `Edit Profil`.

**Prasyarat:** Plan B1–B6 sudah di-merge ke `main`. Branch kerja: `redesign/phase-b7-account-cleanup` dari `main`.

## Global Constraints

Dari spec §9 (aturan engineering, wajib):
1. Jangan jalankan `dart format` ke seluruh file. Edit terarah; diff sebanding dengan perubahan.
2. `Notifier.build()` tidak boleh menyentuh `state` secara sinkron; fetch pertama lewat `Future.microtask(...)`.
3. Refresh provider lewat `ref.invalidate(...)`, bukan mengganti `ValueKey`.
4. Setelah `await` (terutama `Navigator.push`), cek `if (!mounted) return;` sebelum `setState`/`ref`/`context`.
5. Tab di dalam Home memakai `AppPageScaffold(embedded: true)` (tidak relevan untuk screen B7 — semua screen B7 adalah halaman push/root).
6. Jangan menaruh `Center`/`Align`/`Expanded` tanpa batas di slot yang memberi tinggi longgar — pakai `heightFactor: 1`.
7. Pertahankan konkurensi fetch asli.
8. Semua `onTap` / navigasi / efek samping lama dipertahankan persis; redesign hanya mengubah tampilan kecuali spec menyebut perubahan logika.
9. Tidak ada hex di screen — semua warna dari `AppColors`. Pengecualian: `Colors.white`, `Colors.transparent`, warna dompet dari data.
10. Commit message Conventional Commits (hook `commit-msg`), scope tanpa koma, diakhiri baris atribusi:
    ```
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
    Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
    ```
11. Perubahan skema DB tidak ada di plan ini.

Dari spec §10 (definisi selesai per screen):
1. `flutter analyze` tidak menambah error/warning baru (info `withOpacity` lama boleh).
2. `flutter test` hijau.
3. `grep -c "GoogleFonts.poppins" <file screen>` = 0.
4. Tidak ada hex/`Colors.<warna>` baru di screen (kecuali pengecualian §9.9).
5. Checklist visual task dicocokkan dengan mockup memakai skill `run-and-screenshot`; bila agent tak punya otomasi browser, koordinator meminta screenshot ke user di akhir plan (Task 10).

Tambahan khusus plan ini:
- Setelah edit file, kembalikan noise registrant: `git checkout -- linux macos windows` sebelum commit.
- Label copy UI diambil persis dari kode lama (tabel preservasi tiap task). Satu-satunya perubahan visual copy yang disengaja: label field di atas input Login/Daftar tidak ditampilkan lagi (mockup memakai placeholder saja, gaya iOS); teks hint tetap sama persis.
- `LockScreen` saat ini **tidak dipakai** oleh alur navigasi (`lib/main.dart:108` langsung ke `HomeScreen`/`LoginScreen`; import di `main.dart:5` tidak terpakai). Plan ini hanya mendesain ulang tampilannya — **jangan** menyambungkannya ke alur (itu perubahan perilaku). Laporkan fakta ini ke user di Task 10.

## Review Focus

1. **Tombol simpan/masuk ditekan saat loading** — Login/Daftar/Edit Profil: tombol harus nonaktif selama `_isLoading`/`isSaving` (tidak ada submit ganda). Dites di Task 1 (`AppPrimaryButton` menerima `onPressed: null` saat loading) dan Task 5.
2. **Field kosong atau spasi saja** — Login/Daftar menolak kosong dengan toast yang sama persis; Edit Profil menolak nama berisi spasi saja ("Nama tidak boleh kosong", karena `trim()`). Dites di Task 1, 2, 5.
3. **Biometrik gagal / dibatalkan** — Kunci Aplikasi harus menampilkan tombol "Buka Kunci" setelah `authenticate` mengembalikan `false`, dan tombol memicu autentikasi ulang. Saat verifikasi berlangsung, tampil spinner + "Sedang memverifikasi..." tanpa tombol. Dites di Task 3.
4. **Nama kosong / satu kata / banyak spasi di avatar inisial** — nama kosong menampilkan ikon user (bukan '?'); logika inisial memakai `initialsOf` dari Plan B3. Dites di Task 5 (widget avatar).
5. **Kembali dari Edit Profil setelah simpan** — sukses harus `pop(true)` tepat sekali dan toast sukses tampil; gagal menampilkan "Gagal update: ..." tanpa pop. Dites di Task 5.

---

## File Structure

| File | Aksi | Tanggung jawab |
|---|---|---|
| `lib/screens/login/auth_brand.dart` | Create | `AuthBrand` (logo + judul + tagline) dan `AuthFooter` (teks + tautan) dipakai Login & Daftar |
| `lib/screens/login/login_screen.dart` | Modify | Layout baru; getter lazy `_supabase`; dispose controller |
| `lib/screens/register/register_screen.dart` | Modify | Layout baru; getter lazy `_supabase`; dispose controller |
| `lib/screens/lock/lock_screen.dart` | Modify | Layout baru dengan glyph Face ID; seam `auth` untuk test |
| `lib/screens/settings/settings_screen.dart` | Modify | Grouped list ala Settings iPhone; `_generalRows` siap ditambah baris B3 |
| `lib/screens/edit_profile/edit_profile_screen.dart` | Modify | Avatar inisial, grup Email/Nama, tombol bawah; seam `initialName/initialEmail`; avatar via `initialsOf` (B3) |
| `lib/widgets/app_text_field.dart` | Modify | Parameter opsional `label` |
| `lib/core/colors.dart` | Modify | `incomeSoft`, `expenseSoft` |
| `lib/core/app_notification.dart` | Modify | Font → `AppTextStyles`, hex → `AppColors` |
| `lib/widgets/app_tab_selector.dart`, `app_card.dart`, `app_button.dart` | Delete (bersyarat) | Widget lama tak terpakai |
| `test/widgets/app_tab_selector_test.dart`, `app_card_test.dart`, `app_button_test.dart` | Delete (bersyarat) | Test widget lama |
| `test/theme/app_forui_theme_test.dart` | Create | Test pemetaan tema forui dipindah dari `app_card_test.dart` |
| `test/flutter_test_config.dart` | Modify | Komentar Poppins → Plus Jakarta Sans |
| `test/screens/login_screen_test.dart`, `register_screen_test.dart`, `lock_screen_test.dart`, `settings_screen_test.dart`, `edit_profile_screen_test.dart` | Create | Widget test tiap screen |
| `test/widgets/app_text_field_test.dart` | Modify | Test parameter `label` |
| `AGENTS.md` | Modify | Bullet Font & daftar komponen |

---

### Task 1: Login

**Files:**
- Create: `lib/screens/login/auth_brand.dart`
- Modify: `lib/screens/login/login_screen.dart` (seluruh `build()` dan `_buildTextField` diganti; `_login()` baris 25-49 tidak berubah)
- Test: `test/screens/login_screen_test.dart`

**Interfaces:**
- Consumes (B1, spec §6): `AppPageScaffold({required String title, String? backLabel, List<Widget> actions, required List<Widget> children, Widget? bottomBar, Widget? titleWidget, ...})`, `AppGroupedSection({String? header, required List<Widget> children, bool insetSeparators = true})`, `AppTextField({required TextEditingController controller, String? hint, IconData? icon, bool obscure = false, Widget? suffix, TextInputType? keyboardType, ...})`, `AppPrimaryButton({required String label, required VoidCallback? onPressed, IconData? icon, Color? color, bool loading = false})`, `AppTextStyles.title/.subhead`, `AppColors.primary/.primarySoft/.textPrimary`, `pumpApp(tester, child, {overrides, size})` dari `test/helpers/pump_app.dart`.
- Produces: `AuthBrand({required IconData icon, required String title, required String subtitle, bool filled = true})` dan `AuthFooter({required String prompt, required String action, required VoidCallback onTap})` di `lib/screens/login/auth_brand.dart` — dipakai Task 2.

**Tabel preservasi (kode lama → kode baru):**

| Perilaku | Lokasi lama | Wajib tetap |
|---|---|---|
| Validasi kosong → `AppNotification.error(context, "Email dan Password wajib diisi!")` lalu return | `login_screen.dart:26-29` | sama persis |
| `setState(_isLoading = true)` sebelum auth | `:31` | sama |
| `_supabase.auth.signInWithPassword(email:, password:)` dengan teks controller mentah (tanpa trim) | `:33-36` | sama (jangan menambah trim) |
| Sukses: `AppNotification.success(context, "Selamat datang kembali!")` + `Navigator.pushReplacement(... HomeScreen())` di dalam `if (mounted)` | `:37-43` | sama |
| Gagal: `AppNotification.error(context, "Email atau password salah.")` | `:44-45` | sama |
| `finally`: `if (mounted) setState(_isLoading = false)` | `:46-48` | sama |
| Tombol nonaktif saat loading (`onPressed: _isLoading ? null : _login`) + spinner putih | `:216, 225-233` | `AppPrimaryButton(onPressed: _isLoading ? null : _login, loading: _isLoading)` |
| Toggle mata password (`_isObscure = !_isObscure`), ikon `eye` saat tersembunyi, `eyeSlash` saat terlihat | `:196-206` | sama |
| Tap "Daftar Disini" → `Navigator.push(... RegisterScreen())` | `:257-265` | sama |
| Copy: "DompetKu", "Cerdas mengelola, tenang finansial", "Selamat Datang!", "Silakan masuk untuk melanjutkan", hint "email@contoh.com", hint "Masukkan password Anda", "Masuk Sekarang", "Belum punya akun? ", "Daftar Disini" | `:111, 121, 163, 172, 184, 193, 235, 251, 267` | sama persis |
| Ikon: `PhosphorIconsFill.wallet` (logo), `PhosphorIconsRegular.envelopeSimple`, `PhosphorIconsRegular.lockKey` | `:104, 185, 195` | sama |

- [ ] **Step 1: Buat branch**

```bash
git checkout main && git pull
git checkout -b redesign/phase-b7-account-cleanup
```

- [ ] **Step 2: Tulis test yang gagal**

Buat `test/screens/login_screen_test.dart`:

```dart
import 'package:catat_uang_app/screens/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('Login menampilkan layout iOS sesuai mockup', (tester) async {
    await pumpApp(tester, const LoginScreen());

    expect(find.text('DompetKu'), findsWidgets);
    expect(find.text('Cerdas mengelola, tenang finansial'), findsOneWidget);
    expect(find.text('Selamat Datang!'), findsOneWidget);
    expect(find.text('Silakan masuk untuk melanjutkan'), findsOneWidget);
    expect(find.text('Masuk Sekarang'), findsOneWidget);
    expect(find.text('Daftar Disini'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.wallet), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.envelopeSimple), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.lockKey), findsOneWidget);
    // Label field lama sengaja tidak ditampilkan (mockup: placeholder saja).
    expect(find.text('Alamat Email'), findsNothing);
  });

  testWidgets('Login kosong menampilkan toast validasi tanpa menyentuh Supabase', (tester) async {
    await pumpApp(tester, const LoginScreen());

    await tester.tap(find.text('Masuk Sekarang'));
    await tester.pump();

    expect(find.text('Email dan Password wajib diisi!'), findsOneWidget);
    // Toast AppNotification memakai Timer 3 detik; habiskan supaya tidak ada timer tertunda.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Ikon mata men-toggle visibilitas password', (tester) async {
    await pumpApp(tester, const LoginScreen());

    // Urutan field: email (index 0) lalu password (index 1).
    EditableText passwordField() =>
        tester.widgetList<EditableText>(find.byType(EditableText)).elementAt(1);

    expect(find.byIcon(PhosphorIconsRegular.eye), findsOneWidget);
    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byIcon(PhosphorIconsRegular.eye));
    await tester.pump();

    expect(find.byIcon(PhosphorIconsRegular.eyeSlash), findsOneWidget);
    expect(passwordField().obscureText, isFalse);
  });
}
```

- [ ] **Step 3: Jalankan test, pastikan gagal**

Run: `flutter test test/screens/login_screen_test.dart`
Expected: FAIL — test pertama gagal karena `Supabase.instance` diakses di field initializer (`login_screen.dart:20`) sebelum `Supabase.initialize` (assertion "You must initialize the supabase instance"), atau karena teks "Alamat Email" masih ada.

- [ ] **Step 4: Buat `lib/screens/login/auth_brand.dart`**

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Header branding layar auth (Login & Daftar): ikon aplikasi ala ikon iOS,
/// judul, dan tagline. [filled] = kotak ikon warna primary + glyph putih
/// (Login); false = kotak primarySoft + glyph primary (Daftar).
class AuthBrand extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled;

  const AuthBrand({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.filled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: filled ? AppColors.primary : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(24),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 40,
              color: filled ? Colors.white : AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.subhead,
          ),
        ],
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
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

- [ ] **Step 5: Ganti isi `lib/screens/login/login_screen.dart`**

Ganti import (baris 1-8), field `_supabase` (baris 20), tambahkan `dispose()`, lalu ganti seluruh `build()` (baris 51-285) dan hapus `_buildTextField` (baris 287-342). Method `_login()` (baris 25-49) **tidak disentuh**. Hasil akhir file:

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/home/home_screen.dart';
import 'package:catat_uang_app/screens/login/auth_brand.dart';
import 'package:catat_uang_app/screens/register/register_screen.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Getter (bukan field) supaya Supabase.instance baru diakses saat login
  // benar-benar dijalankan — layar bisa dirender di widget test tanpa
  // Supabase.initialize.
  SupabaseClient get _supabase => Supabase.instance.client;

  bool _isLoading = false;
  bool _isObscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // ... TIDAK BERUBAH (salin persis baris 25-49 kode lama) ...
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'DompetKu',
      titleWidget: const AuthBrand(
        icon: PhosphorIconsFill.wallet,
        title: 'DompetKu',
        subtitle: 'Cerdas mengelola, tenang finansial',
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selamat Datang!', style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text('Silakan masuk untuk melanjutkan', style: AppTextStyles.subhead),
          ],
        ),
        AppGroupedSection(
          insetSeparators: false,
          children: [
            AppTextField(
              controller: _emailController,
              hint: 'email@contoh.com',
              icon: PhosphorIconsRegular.envelopeSimple,
              keyboardType: TextInputType.emailAddress,
            ),
            AppTextField(
              controller: _passwordController,
              hint: 'Masukkan password Anda',
              icon: PhosphorIconsRegular.lockKey,
              obscure: _isObscure,
              suffix: IconButton(
                onPressed: () => setState(() => _isObscure = !_isObscure),
                icon: Icon(
                  _isObscure
                      ? PhosphorIconsRegular.eye
                      : PhosphorIconsRegular.eyeSlash,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        AppPrimaryButton(
          label: 'Masuk Sekarang',
          onPressed: _isLoading ? null : _login,
          loading: _isLoading,
        ),
        AuthFooter(
          prompt: 'Belum punya akun? ',
          action: 'Daftar Disini',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RegisterScreen()),
            );
          },
        ),
      ],
    );
  }
}
```

Catatan: `AppPageScaffold` tanpa `backLabel` tidak menampilkan tombol kembali (Login adalah root). Import `google_fonts` dihapus.

- [ ] **Step 6: Jalankan test, pastikan lulus**

Run: `flutter test test/screens/login_screen_test.dart`
Expected: PASS (3 test).

- [ ] **Step 7: Cek Poppins/hex/analyze**

```bash
grep -c "GoogleFonts.poppins" lib/screens/login/login_screen.dart lib/screens/login/auth_brand.dart   # 0 dan 0
grep -nE "Color\(0x|Colors\.(grey|black|red|green|blue|purple|teal|orange)" lib/screens/login/   # tidak ada output
flutter analyze lib/screens/login test/screens/login_screen_test.dart
```
Expected: dua `0`, grep warna kosong, analyze tanpa error/warning baru.

- [ ] **Step 8: Checklist visual (dicocokkan dengan mockup "Login")**

- [ ] Latar halaman abu iOS (`AppColors.background`), bukan putih penuh; tidak ada lingkaran dekoratif lama.
- [ ] Ikon aplikasi kotak bersudut (radius 24) biru dengan dompet putih + bayangan biru, di tengah.
- [ ] "DompetKu" tebal di tengah, tagline abu di bawahnya.
- [ ] "Selamat Datang!" rata kiri, subjudul abu di bawahnya.
- [ ] Email & password dalam **satu** kartu putih dengan garis pemisah penuh (bukan dua kotak terpisah), tanpa label di atas field.
- [ ] Ikon mata di kanan field password.
- [ ] Tombol biru penuh "Masuk Sekarang" tinggi 52 radius 16; saat loading berisi spinner putih dan tidak bisa ditekan.
- [ ] Footer "Belum punya akun? **Daftar Disini**" di tengah, tautan biru.
- [ ] Tidak ada tombol kembali di nav bar.

- [ ] **Step 9: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add lib/screens/login/auth_brand.dart lib/screens/login/login_screen.dart test/screens/login_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(auth): redesign login screen to iOS grouped form

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 2: Daftar Akun

**Files:**
- Modify: `lib/screens/register/register_screen.dart` (seluruh `build()` baris 66-288 dan `_buildTextField` baris 290-345 diganti; `_register()` baris 25-64 tidak berubah)
- Test: `test/screens/register_screen_test.dart`

**Interfaces:**
- Consumes: `AuthBrand`, `AuthFooter` (Task 1, `lib/screens/login/auth_brand.dart`); komponen B1 yang sama dengan Task 1; `AppPageScaffold.backLabel` (tombol kembali memanggil `Navigator.maybePop`).
- Produces: —

**Tabel preservasi:**

| Perilaku | Lokasi lama | Wajib tetap |
|---|---|---|
| Validasi: nama/email/password kosong → `AppNotification.error(context, "Semua kolom wajib diisi ya bos!")` | `register_screen.dart:26-31` | sama persis |
| `signUp(email:, password:, data: {'name': ...})` | `:35-39` | sama |
| Upsert `profiles {id, name}`, error ditelan dengan `debugPrint("Warning: Gagal simpan profil: ...")` | `:41-49` | sama |
| Sukses: `AppNotification.success(context, "Registrasi Berhasil! Silakan Login.")` + `Navigator.pop(context)` di `if (mounted)` | `:51-57` | sama |
| Gagal: `AppNotification.error(context, e.toString())` | `:59-60` | sama |
| `finally` reset loading | `:61-63` | sama |
| Tombol kembali kiri atas → `Navigator.pop(context)` | `:101-102` | via `AppPageScaffold(backLabel: 'Masuk')` |
| Toggle mata password | `:205-215` | sama |
| Tombol nonaktif + spinner saat loading | `:225, 234-242` | `AppPrimaryButton(onPressed: _isLoading ? null : _register, loading: _isLoading)` |
| "Masuk Disini" → `Navigator.pop(context)` | `:266-267` | sama |
| Copy: "Daftar Akun", "Gabung dan mulai atur keuanganmu", hint "Masukkan nama asli bos", "email@contoh.com", "Buat password yang kuat", "Daftar Sekarang", "Sudah punya akun? ", "Masuk Disini" | `:138, 147, 188, 195, 202, 244, 260, 269` | sama persis |
| Ikon: `PhosphorIconsFill.userCirclePlus`, `PhosphorIconsRegular.user`, `.envelopeSimple`, `.lockKey` | `:131, 189, 196, 204` | sama |

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/screens/register_screen_test.dart`:

```dart
import 'package:catat_uang_app/screens/register/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

Future<void> _openRegister(WidgetTester tester) async {
  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          ),
          child: const Text('buka'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Daftar Akun menampilkan layout sesuai mockup', (tester) async {
    await _openRegister(tester);

    expect(find.text('Daftar Akun'), findsWidgets);
    expect(find.text('Gabung dan mulai atur keuanganmu'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget); // label tombol kembali nav bar
    expect(find.byIcon(PhosphorIconsFill.userCirclePlus), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.user), findsOneWidget);
    expect(find.text('Daftar Sekarang'), findsOneWidget);
    expect(find.text('Masuk Disini'), findsOneWidget);
    expect(find.text('Nama Lengkap'), findsNothing);
  });

  testWidgets('Daftar kosong menampilkan toast validasi', (tester) async {
    await _openRegister(tester);

    await tester.tap(find.text('Daftar Sekarang'));
    await tester.pump();

    expect(find.text('Semua kolom wajib diisi ya bos!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('"Masuk Disini" dan tombol kembali menutup layar', (tester) async {
    await _openRegister(tester);
    await tester.tap(find.text('Masuk Disini'));
    await tester.pumpAndSettle();
    expect(find.text('buka'), findsOneWidget);

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('buka'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/screens/register_screen_test.dart`
Expected: FAIL — assertion Supabase belum diinisialisasi (field `_supabase` baris 20) saat layar dibangun.

- [ ] **Step 3: Implementasi**

Ganti import (baris 1-7), field `_supabase` (baris 20), tambah `dispose()`, ganti `build()` dan hapus `_buildTextField`. `_register()` tidak disentuh. Hasil akhir file:

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/login/auth_brand.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Getter lazy: lihat catatan di LoginScreen.
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

  Future<void> _register() async {
    // ... TIDAK BERUBAH (salin persis baris 25-64 kode lama) ...
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Daftar Akun',
      backLabel: 'Masuk',
      titleWidget: const AuthBrand(
        icon: PhosphorIconsFill.userCirclePlus,
        title: 'Daftar Akun',
        subtitle: 'Gabung dan mulai atur keuanganmu',
        filled: false,
      ),
      children: [
        AppGroupedSection(
          insetSeparators: false,
          children: [
            AppTextField(
              controller: _nameController,
              hint: 'Masukkan nama asli bos',
              icon: PhosphorIconsRegular.user,
            ),
            AppTextField(
              controller: _emailController,
              hint: 'email@contoh.com',
              icon: PhosphorIconsRegular.envelopeSimple,
              keyboardType: TextInputType.emailAddress,
            ),
            AppTextField(
              controller: _passwordController,
              hint: 'Buat password yang kuat',
              icon: PhosphorIconsRegular.lockKey,
              obscure: _isObscure,
              suffix: IconButton(
                onPressed: () => setState(() => _isObscure = !_isObscure),
                icon: Icon(
                  _isObscure
                      ? PhosphorIconsRegular.eye
                      : PhosphorIconsRegular.eyeSlash,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        AppPrimaryButton(
          label: 'Daftar Sekarang',
          onPressed: _isLoading ? null : _register,
          loading: _isLoading,
        ),
        AuthFooter(
          prompt: 'Sudah punya akun? ',
          action: 'Masuk Disini',
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
```

Catatan: import `package:flutter/services.dart` lama tidak terpakai → dihapus.

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `flutter test test/screens/register_screen_test.dart`
Expected: PASS (3 test). Bila label tombol kembali di `AppPageScaffold` dirender bersama chevron sehingga `find.text('Masuk')` tidak menemukan teks terpisah, ganti dengan `find.textContaining('Masuk').first` dan catat di laporan.

- [ ] **Step 5: Cek Poppins/hex/analyze**

```bash
grep -c "GoogleFonts.poppins" lib/screens/register/register_screen.dart   # 0
grep -nE "Color\(0x|Colors\.(grey|black|red|green|blue|purple|teal|orange)" lib/screens/register/   # kosong
flutter analyze lib/screens/register test/screens/register_screen_test.dart
```

- [ ] **Step 6: Checklist visual (mockup "Daftar Akun")**

- [ ] Nav bar kiri: chevron + "Masuk" biru; tidak ada ikon `arrow_back_ios_new` hitam lama.
- [ ] Kotak ikon biru muda (primarySoft) dengan ikon user-plus biru (bukan lingkaran putih berbayang).
- [ ] "Daftar Akun" tebal di tengah + subjudul abu.
- [ ] Tiga field (nama, email, password) dalam **satu** kartu putih dengan pemisah penuh; tanpa label di atas field.
- [ ] Tombol "Daftar Sekarang" biru penuh; footer "Sudah punya akun? **Masuk Disini**".

- [ ] **Step 7: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add lib/screens/register/register_screen.dart test/screens/register_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(auth): redesign register screen to iOS grouped form

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 3: Kunci Aplikasi

**Files:**
- Modify: `lib/screens/lock/lock_screen.dart` (konstruktor + field `_auth` baris 10-18; `build()` baris 118-206)
- Test: `test/screens/lock_screen_test.dart`

**Interfaces:**
- Consumes: `AppPrimaryButton`, `AppTextStyles.title/.subhead/.caption`, `AppColors.background/.primary/.primarySoft/.textSecondary`; `LocalAuthentication` (`local_auth` 3.0.1: `Future<bool> get canCheckBiometrics`, `Future<bool> isDeviceSupported()`, `Future<bool> authenticate({required String localizedReason, Iterable<AuthMessages> authMessages, bool biometricOnly, bool sensitiveTransaction, bool persistAcrossBackgrounding})`).
- Produces: `LockScreen({Key? key, @visibleForTesting LocalAuthentication? auth})` — seam test; produksi tetap `const LockScreen()`.

**Tabel preservasi:**

| Perilaku | Lokasi lama | Wajib tetap |
|---|---|---|
| `addObserver` di `initState`, `removeObserver` di `dispose` | `lock_screen.dart:27-37` | sama |
| Saat app `resumed` dan `_canCheckBiometrics && !_isLoading && !_hasAuthenticated` → autentikasi ulang | `:40-48` | sama |
| `_checkBiometrics`: `canCheckBiometrics && isDeviceSupported()`; bila tidak bisa → `_navigateToHome()`; error → `debugPrint` + `_navigateToHome()` | `:50-70` | sama |
| `_authenticateWithBiometrics`: guard `_isLoading || _hasAuthenticated`; set loading & sembunyikan tombol; `authenticate(localizedReason: 'Gunakan biometrik untuk membuka DompetKu')` | `:72-84` | sama persis (string) |
| Sukses → `_hasAuthenticated = true` + `_navigateToHome()`; gagal → tampilkan tombol manual | `:86-96` | sama |
| `PlatformException` → reset + tombol manual + `AppNotification.error(context, "Gagal menggunakan biometrik.")` | `:97-105` | sama |
| Error lain → reset loading | `:106-108` | sama |
| `_navigateToHome` → `pushReplacement(HomeScreen())` | `:111-116` | sama |
| Loading → spinner primary + "Sedang memverifikasi..." | `:168-180` | sama (copy) |
| `!_isLoading && _showManualButton` → tombol "Buka Kunci" memanggil `_authenticateWithBiometrics` | `:182-190` | `AppPrimaryButton` (dulu `AppButton`) |
| Copy: "Aplikasi Terkunci", "Demi keamanan datamu, silakan buka kunci menggunakan biometrik perangkat.", "Aman bersama DompetKu" | `:149, 159, 194` | sama persis |

Perubahan visual yang disengaja (mockup): ikon gembok Material `Icons.lock_outline` → `PhosphorIconsFill.lockSimple` (aturan G15); ditambah glyph Face ID `PhosphorIconsRegular.userFocus` (sudah diverifikasi ada di `phosphor_flutter` 2.1.0) yang **selalu** tampil sebagai dekorasi (tidak bisa diketuk — menambah aksi tap adalah perubahan perilaku).

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/screens/lock_screen_test.dart`:

```dart
import 'dart:async';

import 'package:catat_uang_app/screens/lock/lock_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

class _FakeLocalAuth extends LocalAuthentication {
  _FakeLocalAuth({this.result});

  /// null = authenticate tidak pernah selesai (untuk menguji state loading).
  final bool? result;
  int authenticateCalls = 0;
  final _never = Completer<bool>();

  @override
  Future<bool> get canCheckBiometrics async => true;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) {
    authenticateCalls++;
    expect(localizedReason, 'Gunakan biometrik untuk membuka DompetKu');
    return result == null ? _never.future : Future.value(result);
  }
}

void main() {
  testWidgets('Biometrik gagal menampilkan tombol Buka Kunci yang memicu ulang', (tester) async {
    final auth = _FakeLocalAuth(result: false);
    await pumpApp(tester, LockScreen(auth: auth));
    await tester.pump(); // _checkBiometrics
    await tester.pump(); // authenticate selesai

    expect(find.text('Aplikasi Terkunci'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.lockSimple), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.userFocus), findsOneWidget);
    expect(find.text('Aman bersama DompetKu'), findsOneWidget);
    expect(find.text('Buka Kunci'), findsOneWidget);
    expect(auth.authenticateCalls, 1);

    await tester.tap(find.text('Buka Kunci'));
    await tester.pump();
    await tester.pump();
    expect(auth.authenticateCalls, 2);
  });

  testWidgets('Selama verifikasi tampil spinner dan teks, tanpa tombol', (tester) async {
    await pumpApp(tester, LockScreen(auth: _FakeLocalAuth()));
    await tester.pump();

    expect(find.text('Sedang memverifikasi...'), findsOneWidget);
    expect(find.text('Buka Kunci'), findsNothing);
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/screens/lock_screen_test.dart`
Expected: FAIL kompilasi — `LockScreen` belum punya parameter `auth`.

- [ ] **Step 3: Tambah seam dan ganti `build()`**

Ubah konstruktor dan field (baris 10-18):

```dart
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, @visibleForTesting this.auth});

  /// Hanya untuk test: pengganti `LocalAuthentication` (plugin tidak tersedia
  /// di lingkungan test). Produksi selalu memakai `const LockScreen()`.
  final LocalAuthentication? auth;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  late final LocalAuthentication _auth = widget.auth ?? LocalAuthentication();
```

Ganti import (baris 1-8) — `app_button.dart` dan `google_fonts` dihapus:

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/home/home_screen.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
```

Ganti seluruh `build()` (baris 118-206):

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsFill.lockSimple,
                  color: AppColors.primary,
                  size: 46,
                ),
              ),
              const SizedBox(height: 24),
              Text('Aplikasi Terkunci', style: AppTextStyles.title),
              const SizedBox(height: 10),
              Text(
                'Demi keamanan datamu, silakan buka kunci menggunakan biometrik perangkat.',
                textAlign: TextAlign.center,
                style: AppTextStyles.subhead.copyWith(height: 1.5),
              ),
              const SizedBox(height: 32),
              const Icon(
                PhosphorIconsRegular.userFocus,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                Column(
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text('Sedang memverifikasi...', style: AppTextStyles.subhead),
                  ],
                ),
              if (!_isLoading && _showManualButton)
                AppPrimaryButton(
                  label: 'Buka Kunci',
                  onPressed: _authenticateWithBiometrics,
                ),
              const Spacer(),
              Text(
                'Aman bersama DompetKu',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `flutter test test/screens/lock_screen_test.dart`
Expected: PASS (2 test). Bila jumlah `pump()` kurang untuk menyelesaikan dua `await` di `_checkBiometrics`, tambah satu `await tester.pump();` lagi (bukan `pumpAndSettle`, karena test kedua punya Future yang tidak pernah selesai + spinner animasi).

- [ ] **Step 5: Cek Poppins/hex/analyze**

```bash
grep -c "GoogleFonts.poppins" lib/screens/lock/lock_screen.dart   # 0
grep -nE "Color\(0x|Colors\.(grey|black|red|green|blue|purple|teal|orange)" lib/screens/lock/   # kosong
flutter analyze lib/screens/lock test/screens/lock_screen_test.dart
```

- [ ] **Step 6: Checklist visual (mockup "Kunci Aplikasi")**

- [ ] Latar abu iOS.
- [ ] Lingkaran biru muda dengan gembok biru (Phosphor, bukan ikon Material).
- [ ] "Aplikasi Terkunci" tebal, penjelasan abu rata tengah.
- [ ] Glyph Face ID (`userFocus`) biru besar di tengah.
- [ ] Tombol biru penuh "Buka Kunci" muncul setelah biometrik gagal; saat verifikasi hanya spinner + "Sedang memverifikasi...".
- [ ] "Aman bersama DompetKu" kecil pudar di bawah.

(Untuk melihat layar ini di browser: sementara ganti `home:` di `main.dart` ke `const LockScreen()` **tanpa commit**, atau cukup andalkan widget test + screenshot user dari perangkat bila tersedia. Jangan commit perubahan `main.dart`.)

- [ ] **Step 7: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add lib/screens/lock/lock_screen.dart test/screens/lock_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(auth): redesign lock screen with Face ID glyph

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 4: Pengaturan

**Files:**
- Modify: `lib/screens/settings/settings_screen.dart` (import, seluruh `build()` baris 26-114, hapus `_buildSectionHeader` & `_buildSettingItem` baris 116-176; `_logout` baris 15-24 tidak berubah)
- Test: `test/screens/settings_screen_test.dart`

**Interfaces:**
- Consumes: `AppPageScaffold`, `AppGroupedSection({String? header, ...})`, `AppListRow({Widget? leading, required String title, Color? titleColor, String? subtitle, Widget? trailing, String? value, bool showChevron, VoidCallback? onTap})`, `AppIconTile({required IconData icon, required Color color, bool filled, bool round, double size})`, `AppColors.primary/.tintBlue/.expense`.
- Produces: method `List<Widget> _generalRows(BuildContext context)` — **titik tambah Plan B3**: B3 menambahkan satu `AppListRow` switch "Hitung saldo minimal di total saldo" di akhir list ini (dan mengubah class jadi `ConsumerWidget` bila perlu). Task ini **tidak** mengimplementasikan switch tersebut.

**Tabel preservasi:**

| Perilaku | Lokasi lama | Wajib tetap |
|---|---|---|
| `_logout`: `auth.signOut()` lalu `if (context.mounted) pushAndRemoveUntil(LoginScreen, (route) => false)` | `settings_screen.dart:15-24` | sama, tanpa dialog konfirmasi baru |
| Kembali → `Navigator.pop(context)` | `:49-52` | via `AppPageScaffold(backLabel: 'Beranda')` |
| Grup "Umum": "Profil Akun" / "Atur nama dan info akun", ikon `PhosphorIconsFill.user` → push `EditProfileScreen()` | `:59-76` | sama |
| Grup "Lainnya": "Tentang Aplikasi" / "Versi 1.0.0", ikon `PhosphorIconsFill.info` → `SnackBar(content: Text("Aplikasi DompetKu v1.0 by Miftahul Huda"))` | `:81-97` | sama persis |
| "Keluar" / "Logout dari akun", ikon `PhosphorIconsFill.signOut`, merah → `_logout(context)` | `:99-109` | merah = `AppColors.expense` |

Perubahan visual yang disengaja (mockup): baris "Keluar" tanpa chevron; ikon memakai tile `filled` (latar warna penuh, glyph putih) — Profil `primary`, Tentang `tintBlue`, Keluar `expense`. Dukungan dark mode manual lama (`isDark`, `Color(0xFF1E1E1E)`) dihapus — spec §7.5: dark mode tidak didesain ulang di Phase B; layar tetap bisa dibuka di dark mode tanpa crash (warna terang).

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/screens/settings_screen_test.dart`:

```dart
import 'package:catat_uang_app/screens/settings/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('Pengaturan menampilkan grup Umum dan Lainnya ala Settings iPhone', (tester) async {
    await pumpApp(tester, const SettingsScreen());

    expect(find.text('Pengaturan'), findsWidgets);
    expect(find.text('UMUM'), findsOneWidget);
    expect(find.text('LAINNYA'), findsOneWidget);
    expect(find.text('Profil Akun'), findsOneWidget);
    expect(find.text('Atur nama dan info akun'), findsOneWidget);
    expect(find.text('Tentang Aplikasi'), findsOneWidget);
    expect(find.text('Versi 1.0.0'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
    expect(find.text('Logout dari akun'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.signOut), findsOneWidget);
  });

  testWidgets('Tentang Aplikasi menampilkan snackbar versi', (tester) async {
    await pumpApp(tester, const SettingsScreen());

    await tester.tap(find.text('Tentang Aplikasi'));
    await tester.pump();

    expect(find.text('Aplikasi DompetKu v1.0 by Miftahul Huda'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
```

(Logout & "Profil Akun" tidak diketuk di test: keduanya menyentuh Supabase.)

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: FAIL — `find.text('UMUM')` tidak ditemukan (header lama "Umum" huruf campur).

- [ ] **Step 3: Implementasi — hasil akhir file**

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/edit_profile/edit_profile_screen.dart';
import 'package:catat_uang_app/screens/login/login_screen.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/screens/settings/include_min_balance_row.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// StatelessWidget: layar ini tidak punya state lokal — hanya satu aksi
// one-shot (_logout). Switch saldo minimal (Plan B3) adalah ConsumerWidget
// mandiri. Catatan koordinator: B3 Task 9 menyisipkan IncludeMinBalanceRow
// di layar lama dalam AppGroupedSection sementara — kode build() di bawah
// menggantikannya; pastikan baris itu hanya muncul sekali (di _generalRows).
// Task 5b nanti mengubah class ini jadi StatefulWidget untuk switch biometrik.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  /// Baris grup "Umum". Baris terakhir adalah switch saldo minimal dari
  /// Plan B3 (`IncludeMinBalanceRow`, ConsumerWidget mandiri).
  List<Widget> _generalRows(BuildContext context) => [
        AppListRow(
          leading: const AppIconTile(
            icon: PhosphorIconsFill.user,
            color: AppColors.primary,
            filled: true,
          ),
          title: 'Profil Akun',
          subtitle: 'Atur nama dan info akun',
          showChevron: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EditProfileScreen()),
            );
          },
        ),
        const IncludeMinBalanceRow(),
      ];

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Pengaturan',
      backLabel: 'Beranda',
      children: [
        AppGroupedSection(header: 'Umum', children: _generalRows(context)),
        AppGroupedSection(
          header: 'Lainnya',
          children: [
            AppListRow(
              leading: const AppIconTile(
                icon: PhosphorIconsFill.info,
                color: AppColors.tintBlue,
                filled: true,
              ),
              title: 'Tentang Aplikasi',
              subtitle: 'Versi 1.0.0',
              showChevron: true,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Aplikasi DompetKu v1.0 by Miftahul Huda'),
                  ),
                );
              },
            ),
            AppListRow(
              leading: const AppIconTile(
                icon: PhosphorIconsFill.signOut,
                color: AppColors.expense,
                filled: true,
              ),
              title: 'Keluar',
              titleColor: AppColors.expense,
              subtitle: 'Logout dari akun',
              onTap: () => _logout(context),
            ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: PASS (2 test). Bila `AppGroupedSection` B1 merender header lewat `Text(header.toUpperCase())`, `find.text('UMUM')` cocok; bila B1 memakai `TextStyle` tanpa mengubah string, sesuaikan komponen B1 (spec §6: "label HURUF BESAR di atas grup") — **jangan** mengubah test ke 'Umum'.

- [ ] **Step 5: Cek Poppins/hex/analyze**

```bash
grep -c "GoogleFonts.poppins" lib/screens/settings/settings_screen.dart   # 0
grep -nE "Color\(0x|Colors\.(grey|black|red|green|blue|purple|teal|orange)" lib/screens/settings/   # kosong
flutter analyze lib/screens/settings test/screens/settings_screen_test.dart
```

- [ ] **Step 6: Checklist visual (mockup "Pengaturan")**

- [ ] Nav bar kiri: chevron + "Beranda" biru; judul besar "Pengaturan" rata kiri (bukan AppBar tengah).
- [ ] Label grup kecil HURUF BESAR abu "UMUM" dan "LAINNYA".
- [ ] Grup putih radius 20; tiap baris tile ikon **berisi warna penuh** (biru untuk Profil, biru muda `tintBlue` untuk Tentang, merah untuk Keluar) dengan glyph putih.
- [ ] Profil Akun & Tentang Aplikasi punya chevron; Keluar tanpa chevron, teks merah.
- [ ] Pemisah antar baris menjorok (mulai setelah ikon).

- [ ] **Step 7: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add lib/screens/settings/settings_screen.dart test/screens/settings_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(settings): redesign settings as iOS grouped list

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 5: Edit Profil (+ parameter `label` di `AppTextField`)

**Files:**
- Modify: `lib/widgets/app_text_field.dart` (tambah parameter opsional `label`)
- Modify: `test/widgets/app_text_field_test.dart` (tambah test `label`)
- Modify: `lib/screens/edit_profile/edit_profile_screen.dart` (konstruktor, `initState` baris 22-37, `build()` baris 66-171, hapus `_buildTextField` baris 173-216; `_updateProfile` baris 46-64 tidak berubah)
- Test: `test/screens/edit_profile_screen_test.dart`

**Interfaces:**
- Consumes: `AppPageScaffold(title:, backLabel:, titleWidget:, bottomBar:, children:)`, `AppGroupedSection`, `AppListRow`, `AppTextField`, `AppPrimaryButton(color:, loading:)`, `AppTextStyles.headline/.caption/.title`; `editProfileProvider` (`NotifierProvider.autoDispose<EditProfileNotifier, EditProfileState>`), `EditProfileState({String? latestName, bool isSaving})`, `EditProfileNotifier.updateProfile(String name)`.
- Produces:
  - `AppTextField` baru menerima `String? label` (opsional; null = perilaku lama persis). Spec §6 membolehkan parameter opsional tambahan — catat di laporan.
  - `EditProfileScreen({Key? key, @visibleForTesting String? initialName, @visibleForTesting String? initialEmail})`.
  - Tidak ada fungsi inisial baru: pakai `initialsOf(String)` dari `lib/core/formatters.dart` (Plan B3). Pastikan import `formatters.dart` ada di screen.

**Tabel preservasi:**

| Perilaku | Lokasi lama | Wajib tetap |
|---|---|---|
| Nilai awal nama dari `user.userMetadata['name']`, email dari `user.email` (sinkron di `initState`) | `edit_profile_screen.dart:25-33` | sama (kecuali seam test) |
| `ref.listen` → bila `latestName` beda dari teks field, isi field | `:72-76` | sama |
| Validasi `trim().isEmpty` → `AppNotification.error(context, "Nama tidak boleh kosong")` | `:47-50` | sama persis |
| Simpan `updateProfile(name.trim())`; sukses `AppNotification.success(context, "Profil berhasil diperbarui!")` + `Navigator.pop(context, true)`; gagal `"Gagal update: $e"` | `:52-63` | sama |
| Tombol nonaktif + spinner putih saat `state.isSaving`; warna tombol `AppColors.textPrimary` | `:143-165` | `AppPrimaryButton(color: AppColors.textPrimary, loading: isLoading, onPressed: isLoading ? null : _updateProfile)` |
| Email read-only | `:125-130` | read-only (ditampilkan sebagai baris list + ikon gembok) |
| Hint nama "Masukkan nama kamu", label "Email" & "Nama Lengkap" | `:126, 135, 138` | sama |
| Kembali → `Navigator.pop(context)` | `:93-96` | via `backLabel: 'Pengaturan'` |
| Judul "Edit Profil" | `:84` | di bawah avatar (mockup) |

Perubahan visual yang disengaja (mockup): avatar lingkaran biru berisi **inisial nama** (maks 2 huruf), berubah langsung saat nama diketik; bila nama kosong tampil ikon `PhosphorIconsFill.user` putih.

- [ ] **Step 1: Tulis test `label` di AppTextField (gagal)**

Tambahkan ke `test/widgets/app_text_field_test.dart` (di dalam `main()` yang sudah ada dari B1):

```dart
  testWidgets('AppTextField menampilkan label kecil di atas input bila diberikan', (tester) async {
    final controller = TextEditingController(text: 'Akun Tes');
    addTearDown(controller.dispose);
    await pumpApp(
      tester,
      Scaffold(body: AppTextField(controller: controller, label: 'Nama Lengkap')),
    );

    expect(find.text('Nama Lengkap'), findsOneWidget);
    expect(find.text('Akun Tes'), findsOneWidget);
    final labelTop = tester.getTopLeft(find.text('Nama Lengkap')).dy;
    final inputTop = tester.getTopLeft(find.byType(EditableText)).dy;
    expect(labelTop, lessThan(inputTop));
  });

  testWidgets('AppTextField tanpa label tidak menambah teks apa pun', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpApp(tester, Scaffold(body: AppTextField(controller: controller, hint: 'x')));
    expect(find.byType(Column), findsNothing);
  });
```

(Pastikan import `../helpers/pump_app.dart`, `package:flutter/material.dart`, `package:catat_uang_app/widgets/app_text_field.dart` sudah ada di file; tambahkan bila belum. Bila test kedua gagal karena implementasi B1 memang memakai `Column` internal, ubah asersinya menjadi `expect(find.text('Nama Lengkap'), findsNothing);`.)

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/widgets/app_text_field_test.dart`
Expected: FAIL kompilasi — parameter `label` belum ada.

- [ ] **Step 3: Implementasi `label` di `lib/widgets/app_text_field.dart`**

Tambahkan field + parameter konstruktor (urutan parameter lain tidak diubah):

```dart
  /// Label kecil opsional di atas input, di dalam field yang sama
  /// (gaya baris iOS "Nama Lengkap" + nilai). Null = tanpa label.
  final String? label;
```

```dart
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
    this.label,
    super.key,
  });
```

Di `build()`, simpan widget yang sekarang dikembalikan ke variabel `field`, lalu:

```dart
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(label!, style: AppTextStyles.caption),
        ),
        field,
      ],
    );
```

(Tambahkan `import 'package:catat_uang_app/theme/app_text_styles.dart';` bila belum ada.)

Run: `flutter test test/widgets/app_text_field_test.dart` → PASS.

- [ ] **Step 4: Tulis test screen yang gagal**

Buat `test/screens/edit_profile_screen_test.dart`:

```dart
import 'package:catat_uang_app/providers/edit_profile_provider.dart';
import 'package:catat_uang_app/screens/edit_profile/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

class _FakeEditProfileNotifier extends EditProfileNotifier {
  String? savedName;
  Object? failWith;

  @override
  EditProfileState build() => const EditProfileState();

  @override
  Future<void> updateProfile(String name) async {
    if (failWith != null) throw failWith!;
    savedName = name;
  }
}

Future<_FakeEditProfileNotifier> _open(WidgetTester tester, {String name = 'Akun Tes'}) async {
  late _FakeEditProfileNotifier fake;
  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditProfileScreen(
                initialName: name,
                initialEmail: 'akun.tes@email.com',
              ),
            ),
          ),
          child: const Text('buka'),
        ),
      ),
    ),
    overrides: [
      editProfileProvider.overrideWith(() => fake = _FakeEditProfileNotifier()),
    ],
  );
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  // initialsOf() sudah dites di Plan B3 (test/core/formatters_test.dart);
  // di sini cukup test widget avatar (nama kosong → ikon user, bukan '?').

  testWidgets('Edit Profil menampilkan avatar inisial, email terkunci, dan field nama', (tester) async {
    await _open(tester);

    expect(find.text('AT'), findsOneWidget);
    expect(find.text('Edit Profil'), findsOneWidget);
    expect(find.text('Pengaturan'), findsOneWidget); // label kembali
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('akun.tes@email.com'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.lockSimple), findsOneWidget);
    expect(find.text('Nama Lengkap'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);
  });

  testWidgets('Avatar mengikuti nama yang diketik; nama kosong menampilkan ikon', (tester) async {
    await _open(tester);

    await tester.enterText(find.byType(EditableText).last, 'Budi Santoso');
    await tester.pump();
    expect(find.text('BS'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).last, '');
    await tester.pump();
    expect(find.byIcon(PhosphorIconsFill.user), findsOneWidget);
  });

  testWidgets('Nama berisi spasi saja ditolak tanpa memanggil provider', (tester) async {
    final fake = await _open(tester);

    await tester.enterText(find.byType(EditableText).last, '   ');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pump();

    expect(find.text('Nama tidak boleh kosong'), findsOneWidget);
    expect(fake.savedName, isNull);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Simpan sukses meneruskan nama ter-trim lalu kembali', (tester) async {
    final fake = await _open(tester);

    await tester.enterText(find.byType(EditableText).last, '  Budi  ');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(fake.savedName, 'Budi');
    expect(find.text('buka'), findsOneWidget);
    expect(find.text('Profil berhasil diperbarui!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Simpan gagal menampilkan error dan tetap di layar', (tester) async {
    final fake = await _open(tester);
    fake.failWith = Exception('jaringan');

    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pump();

    expect(find.textContaining('Gagal update'), findsOneWidget);
    expect(find.text('Edit Profil'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
```

(Catatan: `AppNotification.error` menerjemahkan pesan lewat `_translateError`; itu sebabnya test gagal memakai `textContaining('Gagal update')`. Bila `_translateError` mengganti seluruh pesan untuk `Exception`, ganti asersinya dengan `expect(find.text('Edit Profil'), findsOneWidget)` saja dan catat.)

- [ ] **Step 5: Jalankan, pastikan gagal**

Run: `flutter test test/screens/edit_profile_screen_test.dart`
Expected: FAIL kompilasi — `initialName` belum ada.

- [ ] **Step 6: Implementasi — hasil akhir file**

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/providers/edit_profile_provider.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Inisial avatar memakai initialsOf() dari lib/core/formatters.dart (dibuat Plan B3,
// sudah dites di sana): '?' untuk nama kosong → avatar menampilkan ikon user.

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({
    super.key,
    @visibleForTesting this.initialName,
    @visibleForTesting this.initialEmail,
  });

  /// Hanya untuk test: nilai awal pengganti metadata Auth Supabase.
  /// Produksi selalu `const EditProfileScreen()`.
  final String? initialName;
  final String? initialEmail;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    String initialName = widget.initialName ?? '';
    String initialEmail = widget.initialEmail ?? '';

    if (widget.initialName == null && widget.initialEmail == null) {
      // ISI DATA LANGSUNG (Synchronous) dari Metadata Auth supaya textfield
      // tidak kosong saat layar dibuka. Data terbaru dari tabel `profiles`
      // disinkronkan lewat ref.listen di build().
      final user = Supabase.instance.client.auth.currentUser;
      initialName = user?.userMetadata?['name'] ?? '';
      initialEmail = user?.email ?? '';
    }

    _nameController = TextEditingController(text: initialName);
    _emailController = TextEditingController(text: initialEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    // ... TIDAK BERUBAH (salin persis baris 46-64 kode lama) ...
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editProfileProvider);

    ref.listen<EditProfileState>(editProfileProvider, (previous, next) {
      if (next.latestName != null && _nameController.text != next.latestName) {
        _nameController.text = next.latestName!;
      }
    });

    final isLoading = state.isSaving;

    return AppPageScaffold(
      title: 'Edit Profil',
      backLabel: 'Pengaturan',
      titleWidget: _ProfileHeader(controller: _nameController),
      bottomBar: AppPrimaryButton(
        label: 'Simpan Perubahan',
        color: AppColors.textPrimary,
        loading: isLoading,
        onPressed: isLoading ? null : _updateProfile,
      ),
      children: [
        AppGroupedSection(
          children: [
            AppListRow(
              leading: const Icon(
                PhosphorIconsRegular.envelope,
                color: AppColors.textSecondary,
                size: 22,
              ),
              title: 'Email',
              subtitle: _emailController.text,
              trailing: const Icon(
                PhosphorIconsRegular.lockSimple,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
            AppTextField(
              controller: _nameController,
              label: 'Nama Lengkap',
              hint: 'Masukkan nama kamu',
              icon: PhosphorIconsRegular.user,
            ),
          ],
        ),
      ],
    );
  }
}

/// Avatar inisial + judul "Edit Profil" (mockup), ikut berubah saat nama diketik.
class _ProfileHeader extends StatelessWidget {
  final TextEditingController controller;

  const _ProfileHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Center(
        heightFactor: 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final raw = initialsOf(value.text);
                final initials = raw == '?' ? '' : raw;
                return Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: initials.isEmpty
                      ? const Icon(PhosphorIconsFill.user, color: Colors.white, size: 44)
                      : Text(
                          initials,
                          style: AppTextStyles.title.copyWith(
                            color: Colors.white,
                            fontSize: 32,
                          ),
                        ),
                );
              },
            ),
            const SizedBox(height: 10),
            Text('Edit Profil', style: AppTextStyles.headline),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Jalankan test, pastikan lulus**

Run: `flutter test test/screens/edit_profile_screen_test.dart test/widgets/app_text_field_test.dart`
Expected: PASS semua.

- [ ] **Step 8: Cek Poppins/hex/analyze**

```bash
grep -c "GoogleFonts.poppins" lib/screens/edit_profile/edit_profile_screen.dart   # 0
grep -nE "Color\(0x|Colors\.(grey|black|red|green|blue|purple|teal|orange)" lib/screens/edit_profile/   # kosong
flutter analyze lib/screens/edit_profile lib/widgets/app_text_field.dart test/screens test/widgets/app_text_field_test.dart
```

- [ ] **Step 9: Checklist visual (mockup "Edit Profil")**

- [ ] Nav bar kiri: chevron + "Pengaturan".
- [ ] Avatar lingkaran biru besar dengan inisial putih tebal di tengah; "Edit Profil" tebal di bawahnya.
- [ ] Satu kartu putih: baris "Email" (ikon amplop abu, email abu di bawah, ikon gembok kecil di kanan) + field "Nama Lengkap" (label kecil abu di atas nilai).
- [ ] Tombol "Simpan Perubahan" warna gelap (`textPrimary`) menempel di bawah layar; spinner putih saat menyimpan.

- [ ] **Step 10: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add lib/widgets/app_text_field.dart test/widgets/app_text_field_test.dart lib/screens/edit_profile/edit_profile_screen.dart test/screens/edit_profile_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(profile): redesign edit profile with initials avatar

Adds an optional label to AppTextField for iOS-style labelled rows.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 5b: Sambungkan kunci biometrik (bisa dinyalakan/dimatikan)

> Ditambahkan koordinator setelah keputusan user 2026-09-24: kunci biometrik saat ini tidak pernah aktif karena `lib/main.dart:108` langsung ke `HomeScreen` (import `LockScreen` di `main.dart:5` tidak terpakai). User memilih: **sambungkan, dengan switch di Pengaturan, default mati.**

**Keputusan desain:**
- Pengaturan disimpan di server: kolom `profiles.use_biometric_lock boolean not null default false` (tanpa dependency baru; `shared_preferences` tidak ada di pubspec). Di perangkat yang tidak mendukung biometrik, kunci dilewati walau setting aktif.
- Kunci hanya saat aplikasi dibuka (cold start), tidak saat kembali dari background — di luar scope, dicatat di laporan.
- Web (`kIsWeb`) selalu melewati kunci (`local_auth` tidak mendukung web).
- Gagal membaca setting (offline/error) → langsung ke Beranda (fail-open; kunci ini fitur kenyamanan, bukan batas keamanan — data tetap dilindungi login + RLS). Catat di laporan.

**Files:**
- Create: `supabase/migrations/202609240003_biometric_lock.sql`
- Create: `lib/screens/lock/app_entry_gate.dart`
- Create: `lib/core/lock_policy.dart`
- Modify: `lib/main.dart:108` (`home:`), hapus import `lock_screen.dart` bila tidak terpakai lagi setelah gate
- Modify: `lib/screens/settings/settings_screen.dart` (`_generalRows` — tambah baris switch; bila B3 sudah menambah baris saldo minimal, letakkan setelahnya)
- Test: `test/core/lock_policy_test.dart`, `test/screens/lock/app_entry_gate_test.dart`

**Interfaces:**
- Consumes: `LockScreen` (Task 3, termasuk seam `auth`), `HomeScreen`, `AppListRow`, `AppSwitch`, `AppNotification`, `Supabase.instance.client`.
- Produces:
  ```dart
  // lib/core/lock_policy.dart
  bool shouldShowLock({required bool enabled, required bool isWeb, required bool deviceSupported});
  // lib/screens/lock/app_entry_gate.dart
  class AppEntryGate extends StatelessWidget {
    const AppEntryGate({super.key, @visibleForTesting this.loadSetting, @visibleForTesting this.deviceSupported});
    final Future<bool> Function()? loadSetting;      // default: baca profiles.use_biometric_lock
    final Future<bool> Function()? deviceSupported;  // default: LocalAuthentication canCheckBiometrics && isDeviceSupported
  }
  ```

- [ ] **Step 1: Tulis migration**

`supabase/migrations/202609240003_biometric_lock.sql`:
```sql
alter table public.profiles
  add column if not exists use_biometric_lock boolean not null default false;
```
Koordinator menyerahkan SQL ini ke user untuk dijalankan di SQL Editor (dari laptop; editor HP menambah tanda kurung otomatis). Verifikasi:
```sql
select column_name, data_type, column_default from information_schema.columns
where table_schema = 'public' and table_name = 'profiles' and column_name = 'use_biometric_lock';
```
Harus 1 baris. **Jangan lanjut ke Step 5 (kode yang membaca kolom) sebelum user konfirmasi.** Tambahkan juga baris kolom ini ke `docs/database/schema.md` tabel `profiles`.

- [ ] **Step 2: Test gagal `shouldShowLock`**

`test/core/lock_policy_test.dart`:
```dart
import 'package:catat_uang_app/core/lock_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kunci tampil hanya bila aktif, bukan web, dan perangkat mendukung', () {
    expect(shouldShowLock(enabled: true, isWeb: false, deviceSupported: true), isTrue);
    expect(shouldShowLock(enabled: false, isWeb: false, deviceSupported: true), isFalse);
    expect(shouldShowLock(enabled: true, isWeb: true, deviceSupported: true), isFalse);
    expect(shouldShowLock(enabled: true, isWeb: false, deviceSupported: false), isFalse);
  });
}
```
Run: `flutter test test/core/lock_policy_test.dart` → FAIL (file belum ada).

- [ ] **Step 3: Implementasi `lock_policy.dart`**

```dart
/// Aturan kapan layar Kunci Aplikasi ditampilkan saat aplikasi dibuka.
bool shouldShowLock({required bool enabled, required bool isWeb, required bool deviceSupported}) =>
    enabled && !isWeb && deviceSupported;
```
Run test → PASS.

- [ ] **Step 4: Test gagal `AppEntryGate`**

`test/screens/lock/app_entry_gate_test.dart` — pakai `pumpApp`. Tiga kasus: (a) `loadSetting` → `false` ⇒ tidak ada teks "Aplikasi Terkunci" (HomeScreen dirender; override provider Home dengan fake notifier seperti di test Beranda B3, atau cukup `expect(find.byType(LockScreen), findsNothing)`); (b) `loadSetting` → `true`, `deviceSupported` → `true` ⇒ `find.byType(LockScreen)` findsOneWidget; (c) `loadSetting` melempar exception ⇒ `LockScreen` findsNothing (fail-open). Saat merender `LockScreen` di test, pastikan seam `auth` Task 3 tidak memicu plugin: gate meneruskan `LockScreen()` biasa, jadi di test kasus (b) cukup cek tipe widget sebelum `pumpAndSettle` (pakai `tester.pump()` dua kali), atau tambahkan parameter `@visibleForTesting Widget Function()? lockBuilder` bila diperlukan dan catat.

- [ ] **Step 5: Implementasi `AppEntryGate`**

```dart
import 'package:catat_uang_app/core/lock_policy.dart';
import 'package:catat_uang_app/screens/home/home_screen.dart';
import 'package:catat_uang_app/screens/lock/lock_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Titik masuk setelah login: menampilkan [LockScreen] bila user
/// mengaktifkan kunci biometrik dan perangkat mendukungnya, selain itu
/// langsung [HomeScreen]. Gagal membaca setting → langsung Beranda.
class AppEntryGate extends StatelessWidget {
  const AppEntryGate({super.key, @visibleForTesting this.loadSetting, @visibleForTesting this.deviceSupported});

  final Future<bool> Function()? loadSetting;
  final Future<bool> Function()? deviceSupported;

  static Future<bool> _loadFromProfile() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await client.from('profiles').select('use_biometric_lock').eq('id', uid).maybeSingle();
    return (row?['use_biometric_lock'] as bool?) ?? false;
  }

  static Future<bool> _deviceSupports() async {
    final auth = LocalAuthentication();
    return await auth.canCheckBiometrics && await auth.isDeviceSupported();
  }

  Future<bool> _decide() async {
    try {
      final enabled = await (loadSetting ?? _loadFromProfile)();
      if (!enabled || kIsWeb) return false;
      final supported = await (deviceSupported ?? _deviceSupports)();
      return shouldShowLock(enabled: enabled, isWeb: kIsWeb, deviceSupported: supported);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _decide(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data == true ? const LockScreen() : const HomeScreen();
      },
    );
  }
}
```
(`_decide()` dipanggil di `build`; karena `AppEntryGate` hanya dibangun sekali sebagai `home:`, ini aman. Bila analyzer/ reviewer keberatan, jadikan `StatefulWidget` dengan `late final Future<bool> _future = _decide();` di `initState`.)

Run test Step 4 → PASS.

- [ ] **Step 6: Sambungkan di `main.dart`**

Ganti `lib/main.dart:108`:
```dart
home: user != null ? const AppEntryGate() : const LoginScreen(),
```
Tambah import `app_entry_gate.dart`; hapus import `lock_screen.dart` dan `home_screen.dart` bila tidak terpakai lagi (cek `flutter analyze`). Perbarui komentar di atasnya supaya sesuai kenyataan (gate, bukan "arahkan ke Gembok" tanpa syarat). Setelah login berhasil, `LoginScreen` tetap menavigasi seperti sekarang (tidak diubah) — kunci hanya berlaku saat cold start.

- [ ] **Step 7: Switch di Pengaturan**

Di `_generalRows(context)` tambahkan baris (setelah baris saldo minimal B3 bila ada):
```dart
AppListRow(
  leading: const AppIconTile(icon: PhosphorIconsFill.fingerprint, color: AppColors.primary, filled: true),
  title: 'Kunci dengan biometrik',
  subtitle: 'Minta sidik jari / Face ID saat aplikasi dibuka',
  trailing: AppSwitch(value: _useBiometricLock, onChanged: _toggleBiometricLock),
),
```
Screen Pengaturan menjadi `StatefulWidget` (atau `ConsumerStatefulWidget` bila B3 sudah mengubahnya) dengan state `bool _useBiometricLock = false;` yang dimuat di `initState` (select `use_biometric_lock` dari `profiles`, `if (!mounted) return;` sebelum `setState`). `_toggleBiometricLock(bool value)`:
1. Bila `value == true`: di web → `AppNotification.error(context, 'Kunci biometrik tidak tersedia di versi web.')` dan berhenti. Cek `canCheckBiometrics && isDeviceSupported()`; bila tidak → `AppNotification.error(context, 'Perangkat ini tidak mendukung biometrik.')` dan berhenti. Lalu `authenticate(localizedReason: 'Konfirmasi untuk mengaktifkan kunci DompetKu')`; batal/gagal → berhenti tanpa mengubah.
2. `update profiles set use_biometric_lock = value where id = uid`; sukses → `setState` + `AppNotification.success(context, value ? 'Kunci biometrik aktif.' : 'Kunci biometrik dimatikan.')`; gagal → `AppNotification.error(context, 'Gagal menyimpan pengaturan.')` dan switch kembali.
Semua cabang cek `mounted` setelah `await`. Tambahkan widget test Pengaturan yang memastikan baris "Kunci dengan biometrik" tampil (seam pemuatan setting boleh ditambah seperti pola `AppEntryGate`, dicatat).

- [ ] **Step 8: Analyze, test, commit**

Run: `flutter analyze` (tanpa error/warning baru) dan `flutter test` (hijau).
```bash
git checkout -- linux macos windows 2>/dev/null
git add supabase/migrations/202609240003_biometric_lock.sql lib/core/lock_policy.dart lib/screens/lock/app_entry_gate.dart lib/main.dart lib/screens/settings/settings_screen.dart docs/database/schema.md test/core/lock_policy_test.dart test/screens/lock/app_entry_gate_test.dart test/screens/settings/
git commit -m "$(cat <<'EOF'
feat(lock): gate app start behind optional biometric lock

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

**Checklist visual:** baris switch "Kunci dengan biometrik" di grup UMUM Pengaturan dengan ikon sidik jari filled biru; di HP dengan setting aktif, layar Kunci Aplikasi (desain Task 3) muncul saat app dibuka, lalu Beranda setelah berhasil.

---

### Task 6: Toast `AppNotification` bebas Poppins & hex

**Files:**
- Modify: `lib/core/colors.dart` (tambah 2 konstanta)
- Modify: `lib/core/app_notification.dart` (baris ±161-183: warna & font toast)
- Test: `test/core/app_notification_test.dart` (baru)

**Interfaces:**
- Consumes: `AppTextStyles.body`, `AppColors.income/.expense/.textPrimary`.
- Produces: `AppColors.incomeSoft = Color(0xFFE3F4EB)`, `AppColors.expenseSoft = Color(0xFFFCE5E3)`.

Alasan: `grep -rn "GoogleFonts.poppins" lib/` (Task 8) mencakup `lib/core/app_notification.dart`, dan toast tampil di semua screen — tanpa task ini sisa Poppins tidak pernah nol.

Pemetaan warna:

| Lama | Baru |
|---|---|
| `const Color(0xFFFEE2E2)` (latar ikon error) | `AppColors.expenseSoft` |
| `const Color(0xFFD1FAE5)` (latar ikon sukses) | `AppColors.incomeSoft` |
| `const Color(0xFFEF4444)` (ikon error) | `AppColors.expense` |
| `const Color(0xFF10B981)` (ikon sukses) | `AppColors.income` |
| `const Color(0xFF1F2937)` (teks) | `AppColors.textPrimary` |
| `GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: ...)` | `AppTextStyles.body.copyWith(fontSize: 14, color: AppColors.textPrimary)` |

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/core/app_notification_test.dart`:

```dart
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('Toast error memakai warna AppColors dan font tema', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => AppNotification.error(context, 'Nama tidak boleh kosong'),
            child: const Text('tes'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('tes'));
    await tester.pump();

    final text = tester.widget<Text>(find.text('Nama tidak boleh kosong'));
    expect(text.style?.color, AppColors.textPrimary);
    expect(text.style?.fontFamily, isNot(contains('Poppins')));

    final icons = tester.widgetList<Icon>(find.byType(Icon)).where((i) => i.color == AppColors.expense);
    expect(icons, isNotEmpty);

    await tester.pump(const Duration(seconds: 4));
  });
}
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/core/app_notification_test.dart`
Expected: FAIL — warna teks masih `0xFF1F2937`, ikon masih `0xFFEF4444`.

- [ ] **Step 3: Implementasi**

Tambah ke `lib/core/colors.dart` (di bawah `expense`):

```dart
  static const Color incomeSoft = Color(0xFFE3F4EB); // Latar lembut hijau (toast sukses)
  static const Color expenseSoft = Color(0xFFFCE5E3); // Latar lembut merah (toast error)
```

Di `lib/core/app_notification.dart`: jalankan `grep -n "GoogleFonts\|Color(0x" lib/core/app_notification.dart`, lalu ganti tiap hit sesuai tabel pemetaan di atas (hapus `const` di depan ekspresi yang kini merujuk `AppColors` bila perlu — `AppColors.*` adalah `static const`, jadi `const` di level widget tetap sah). Ganti `import 'package:google_fonts/google_fonts.dart';` dengan:

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
```

`Colors.white`, `Colors.transparent`, `Colors.grey.shade200` (border toast) dan `Colors.black.withOpacity(0.08)` (bayangan) boleh tetap — di luar `lib/screens`/`lib/widgets` dan bukan warna semantik; biarkan agar diff kecil.

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `flutter test test/core/app_notification_test.dart` → PASS.
Run: `grep -c "GoogleFonts.poppins\|Color(0x" lib/core/app_notification.dart` → `0`.

- [ ] **Step 5: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add lib/core/colors.dart lib/core/app_notification.dart test/core/app_notification_test.dart
git commit -m "$(cat <<'EOF'
style(core): theme toast notifications with AppColors and Jakarta Sans

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 7: Hapus widget lama (`AppTabSelector`, `AppCard`, `AppButton`) + pindahkan test tema

**Files:**
- Delete (bersyarat): `lib/widgets/app_tab_selector.dart`, `lib/widgets/app_card.dart`, `lib/widgets/app_button.dart`, `test/widgets/app_tab_selector_test.dart`, `test/widgets/app_card_test.dart`, `test/widgets/app_button_test.dart`
- Create: `test/theme/app_forui_theme_test.dart`
- Modify: `test/flutter_test_config.dart` (komentar baris 7)
- Modify: `lib/widgets/app_bottom_nav.dart` (komentar baris ±23 yang menyebut `AppCard/AppButton`)

**Interfaces:**
- Consumes: `appForuiTheme` (`lib/theme/app_forui_theme.dart`).
- Produces: —

- [ ] **Step 1: Pastikan tidak ada pemakai tersisa**

```bash
grep -rnE "\bAppTabSelector\b|app_tab_selector\.dart" lib test --include=*.dart | grep -vE "^(lib/widgets/app_tab_selector\.dart|test/widgets/app_tab_selector_test\.dart):"
grep -rnE "\bAppCard\b|app_card\.dart" lib test --include=*.dart | grep -vE "^(lib/widgets/app_card\.dart|test/widgets/app_card_test\.dart):"
grep -rnE "\bAppButton\b(\.destructive)?|app_button\.dart" lib test --include=*.dart | grep -vE "^(lib/widgets/app_button\.dart|test/widgets/app_button_test\.dart):"
```

Expected: ketiga perintah **tidak mengeluarkan baris kode** (hit yang hanya berada di komentar — mis. `app_bottom_nav.dart:23` "Beda dari AppCard/AppButton/dll" — boleh; komentar itu diperbarui di Step 4).

**Bila ada pemakai nyata tersisa** (import atau pemanggilan di `lib/screens/**` / `lib/widgets/**`, per 2026-09-24 masih ada di `stats_screen.dart`, `transaction_history_screen.dart`, `transactions_tab_screen.dart`, `target_screen.dart`, `wallet_screen.dart`, `lock_screen.dart` — seharusnya semua sudah hilang setelah B3–B6 dan Task 3): **BERHENTI**. Jangan menghapus widget itu dan jangan memigrasi screen milik plan lain di task ini. Laporkan ke koordinator daftar file:baris yang masih memakai, dengan status `BLOCKED`, karena itu tanda plan B3–B6 belum tuntas. Widget yang pemakainya sudah nol tetap boleh dihapus (hapus per widget, tidak harus ketiganya sekaligus).

- [ ] **Step 2: Pindahkan test pemetaan tema forui**

`test/widgets/app_card_test.dart` baris 9-33 berisi dua test tema yang tetap berharga (regresi `FThemeData(...)` vs `.copyWith`). Buat `test/theme/app_forui_theme_test.dart` dengan dua test itu, judul test Poppins diganti:

```dart
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_forui_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Regresi: sebelumnya appForuiTheme dibangun dengan
  // FThemes.zinc.light.copyWith(colors:, style:), yang TIDAK menurunkan
  // colors/style ke style per-widget. Test ini membuktikan pemetaan tema
  // benar-benar sampai ke style widget.
  test('appForuiTheme menurunkan AppColors & radius ke cardStyle', () {
    // SALIN PERSIS isi test pertama dari test/widgets/app_card_test.dart
    // (asersi borderRadius 16, warna background, title/subtitle color).
    // Bila B1 mengubah warna kartu forui, sesuaikan asersi dengan nilai B1
    // dan catat di laporan.
  });

  test('appForuiTheme memakai Plus Jakarta Sans, bukan Inter bawaan forui', () {
    expect(appForuiTheme.typography.defaultFontFamily, isNot(contains('Inter')));
    expect(appForuiTheme.typography.defaultFontFamily, contains('PlusJakartaSans'));
    expect(
      appForuiTheme.cardStyle.contentStyle.titleTextStyle.fontFamily,
      appForuiTheme.typography.defaultFontFamily,
    );
  });
}
```

Salin badan test pertama apa adanya dari `app_card_test.dart` (baris 14-25) — jangan ditulis ulang dari ingatan. Jalankan dulu `flutter test test/theme/app_forui_theme_test.dart` → PASS. (Bila asersi `contains('PlusJakartaSans')` gagal karena nama family dari `GoogleFonts.plusJakartaSans().fontFamily` berformat lain, cetak nilainya sekali dengan `print`, pakai substring yang benar, hapus `print`.)

- [ ] **Step 3: Hapus widget & test lama (hanya yang lolos Step 1)**

```bash
git rm lib/widgets/app_tab_selector.dart test/widgets/app_tab_selector_test.dart
git rm lib/widgets/app_card.dart test/widgets/app_card_test.dart
git rm lib/widgets/app_button.dart test/widgets/app_button_test.dart
```

- [ ] **Step 4: Perbarui komentar yang merujuk widget/font lama**

`test/flutter_test_config.dart` baris 7: ganti "`appForuiTheme` memetakan font Poppins lewat `GoogleFonts.poppins()`" menjadi "`appForuiTheme` memetakan font Plus Jakarta Sans lewat `GoogleFonts.plusJakartaSans()`".

`lib/widgets/app_bottom_nav.dart` komentar "Beda dari AppCard/AppButton/dll, widget ini TIDAK membungkus primitive forui" → "Widget ini TIDAK membungkus primitive forui".

- [ ] **Step 5: Verifikasi**

```bash
flutter analyze
flutter test
```
Expected: analyze 0 error; semua test hijau.

- [ ] **Step 6: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add -A lib/widgets test/widgets test/theme test/flutter_test_config.dart
git status --short   # pastikan hanya file di atas
git commit -m "$(cat <<'EOF'
chore(cleanup): remove unused AppTabSelector, AppCard, AppButton

Theme mapping tests move to test/theme/app_forui_theme_test.dart.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 8: Pemeriksaan seluruh app — nol Poppins, nol warna hardcoded

**Files:**
- Modify: file apa pun yang masih tertangkap grep di bawah (perbaikan per-hit, terarah)
- Modify (bila perlu): `lib/core/colors.dart`

**Interfaces:**
- Consumes: `AppTextStyles.*`, `AppColors.*`.
- Produces: —

- [ ] **Step 1: Poppins**

```bash
grep -rn "GoogleFonts.poppins" lib/
```

Expected: **tidak ada output**. Untuk tiap hit:
- Ganti dengan `AppTextStyles.<gaya terdekat>.copyWith(...)` sesuai tabel spec §5 (ukuran → gaya: ≥30 `largeTitle`/`amountHero`, 20-26 `title`, 17-18 `headline`, 15-16 `body`/`bodyStrong`, 13-14 `subhead`, 10-12 `caption`), pertahankan `color`/`fontWeight` asli via `copyWith`.
- Hapus `import 'package:google_fonts/google_fonts.dart';` bila tak terpakai lagi di file itu.
- Satu-satunya pemakaian `google_fonts` yang sah: `lib/theme/app_text_styles.dart`, `lib/theme/app_forui_theme.dart`, `lib/main.dart` (`plusJakartaSansTextTheme`). Cek: `grep -rln "google_fonts" lib/` → hanya tiga file itu.

- [ ] **Step 2: Warna hardcoded**

```bash
grep -rnE "Color\(0x|Colors\.(purple|teal|blue|green|red|orange|indigo|deepPurple)" lib/screens lib/widgets
```

Expected: **tidak ada output**, kecuali pengecualian terdokumentasi berikut.

Pengecualian sah (spec §9.9) — bila muncul, biarkan tetapi tulis di laporan (file:baris + alasan):
1. **Palet pilihan warna dompet** (lingkaran "Pilih Warna" di sheet Tambah/Edit Dompet). Plan B3 sudah memindahkannya ke `AppColors.walletColorChoices` (`List<String>` hex yang disimpan ke DB) plus `AppColors.fromWalletHex(...)`. **Jangan membuat `walletChoices` baru**; bila grep masih menemukan literal palet di `wallet_screen.dart`, ganti rujukannya ke `AppColors.walletColorChoices`. Fallback warna dompet yang dibaca dari data (`fromWalletHex`) bukan literal hex dan tidak tertangkap pola `Color(0x`.
2. `Colors.white`, `Colors.transparent`, `Colors.black.withOpacity(...)` untuk bayangan — tidak tertangkap pola di atas.

Untuk hit lain, pemetaan wajib:

| Hit | Ganti dengan |
|---|---|
| `Colors.red*`, `Colors.redAccent` (hapus/error/over) | `AppColors.expense` |
| `Colors.green*`, `Colors.greenAccent`, `Colors.teal*` bermakna "masuk/lunas/tercapai" | `AppColors.income` |
| `Colors.teal*`, `Color(0xFF009688)`, `Color(0xFF00796B)` sebagai warna fitur (Tabungan/Target) | `AppColors.primary` |
| `Colors.purple*`, `Colors.deepPurple*`, `Colors.indigo*`, `Color(0xFF5E35B1)`, `Color(0xFF3949AB)` sebagai warna fitur (Anggaran/AI) | `AppColors.primary` |
| `Colors.blue*` sebagai warna fitur (Investasi/Sedekah) | `AppColors.primary`; tombol edit/pensil → `AppColors.tintBlue` |
| `Colors.orange*` peringatan / tempo / transfer / tarik | `AppColors.tintOrange` |
| `Color(0x...)` ikon kategori/fitur | `AppColors.tint<Warna>` terdekat (spec §4.1) |
| `Colors.grey*` tidak tertangkap pola — tetapi bila masih dipakai sebagai warna teks, ganti ke `AppColors.textSecondary` saat menyentuh baris itu (opsional, jangan memperbesar diff) |

- [ ] **Step 3: Tambahkan test penjaga regresi**

Buat `test/conventions_test.dart` supaya aturan ini tidak rusak lagi:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('Tidak ada GoogleFonts.poppins di lib/', () {
    final hits = <String>[];
    for (final f in _dartFiles('lib')) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('GoogleFonts.poppins')) hits.add('${f.path}:${i + 1}');
      }
    }
    expect(hits, isEmpty, reason: 'Pakai AppTextStyles (spec §5)');
  });

  test('Tidak ada warna hardcoded di lib/screens dan lib/widgets', () {
    final pattern = RegExp(r'Color\(0x|Colors\.(purple|teal|blue|green|red|orange|indigo|deepPurple)');
    final hits = <String>[];
    for (final dir in ['lib/screens', 'lib/widgets']) {
      for (final f in _dartFiles(dir)) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (pattern.hasMatch(lines[i])) hits.add('${f.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: 'Pakai AppColors (spec §4.1, §9.9)');
  });
}
```

Run: `flutter test test/conventions_test.dart` → PASS (bila gagal, daftar `hits` di pesan error adalah sisa yang harus diperbaiki di Step 1/2).

- [ ] **Step 4: Verifikasi penuh**

```bash
flutter analyze
flutter test
```

- [ ] **Step 5: Commit**

```bash
git checkout -- linux macos windows 2>/dev/null
git add lib test/conventions_test.dart
git status --short   # tinjau: hanya perbaikan Poppins/warna + test baru
git commit -m "$(cat <<'EOF'
chore(cleanup): remove remaining Poppins and hardcoded colors

Adds a conventions test that keeps lib/ free of both.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

(Bila Step 1-2 tidak menemukan hit sama sekali, commit hanya berisi `test/conventions_test.dart` dengan pesan `test(conventions): guard against Poppins and hardcoded colors`.)

---

### Task 9: Perbarui `AGENTS.md`

**Files:**
- Modify: `AGENTS.md` (bullet **Font** di Conventions; bullet `lib/widgets/` di Structure)

**Interfaces:** —

- [ ] **Step 1: Bullet Font**

Ganti seluruh bullet **Font** (yang saat ini diakhiri "Many screens still call `GoogleFonts.poppins(...)` inline ... when you touch a screen.") dengan:

```markdown
- **Font:** `google_fonts` Plus Jakarta Sans. `main.dart` applies
  `GoogleFonts.plusJakartaSansTextTheme(...)` to `ThemeData.textTheme`
  (light & dark), `appForuiTheme` maps it into forui typography, and
  screens use the named styles in `lib/theme/app_text_styles.dart`
  (`AppTextStyles.largeTitle`, `.title`, `.body`, ...). Don't call
  `GoogleFonts.*` from screens or widgets; `test/conventions_test.dart`
  fails on any `GoogleFonts.poppins`.
```

- [ ] **Step 2: Bullet `lib/widgets/`**

Ganti bullet yang dimulai "`lib/widgets/` — shared UI built on forui: `AppButton`, `AppCard`, ..." dengan:

```markdown
- `lib/widgets/` — shared iOS-style UI (API contract in spec §6 of
  `docs/superpowers/specs/2026-09-24-redesign-phase-b-design.md`):
  `AppPageScaffold` + `AppNavAction` (large title, nav bar, "+" action),
  `AppGroupedSection` + `AppListRow` + `AppIconTile` (grouped lists),
  `AppSegmentedControl`, `AppChipTabs`, `AppHeroCard`, `AppSurfaceCard`,
  `AppSummaryWidget`, `AppProgressBar`/`AppProgressRing`, `AppChip`,
  `AppCallout`, `AppPrimaryButton`/`AppPillButton`/`AppPill`,
  `AppSwitch`, `AppSwipeActions`, `showAppFormSheet`, `AppAmountDisplay`/
  `AppAmountField`, `AppTextField`, `AppEmptyState`,
  `showAppConfirmDialog`, `AppBottomNav`, `showAppBottomSheet`. Use these
  instead of hand-rolling cards, rows, tabs, sheets, or buttons in a
  screen. Screen widget tests use `pumpApp` from
  `test/helpers/pump_app.dart` with fake provider notifiers.
```

Cocokkan daftar ini dengan isi nyata folder: `ls lib/widgets` — tiap file di sana harus tersebut, dan jangan menyebut widget yang tidak ada.

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "$(cat <<'EOF'
docs(agents): document AppTextStyles and the phase B component library

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EvFbRHJdXcZ7eap6nAVzgk
EOF
)"
```

---

### Task 10: Verifikasi akhir Phase B — test penuh, checkpoint visual dengan user, review akhir

**Files:** — (tidak ada perubahan kode kecuali perbaikan dari temuan review)

**Interfaces:** —

- [ ] **Step 1: Analyze + test penuh**

```bash
flutter analyze
flutter test
```

Expected: 0 error, tidak ada warning baru dibanding `main` sebelum B7 (bandingkan: `git stash; flutter analyze | tail -1; git stash pop` tidak perlu — cukup pastikan tidak ada `warning •` di file yang disentuh B7); **semua test hijau** (tidak ada lagi test gagal bawaan setelah B1 menghapus `widget_test.dart`).

- [ ] **Step 2: Checkpoint visual seluruh app bersama user**

Pakai skill `run-and-screenshot`. Jalankan `flutter run -d chrome --web-port=8765` di background, tunggu "Debug service listening". Buka juga `docs/design/dompetku-redesign-mockup.html` di browser.

Bila tidak ada otomasi browser, koordinator mengirim pesan ke user (Bahasa Indonesia) berisi daftar layar dan minta screenshot tiap layar untuk dicocokkan dengan mockup:

1. Login → 2. Daftar Akun → 3. Beranda (usulan baru) → 4. Semua Fitur → 5. Transaksi → 6. Statistik → 7. Tambah Transaksi → 8. Dompet → 9. Anggaran + Detail + sheet Buat Anggaran → 10. Target → 11. Buku Tabungan + Detail → 12. Tagihan & Pemasukan Rutin → 13. Investasi → 14. Utang & Piutang + Detail + form → 15. Kalender → 16. Kelola Kategori → 17. Export → 18. AI Advisor → 19. Zakat & Sedekah → 20. Pengaturan → 21. Edit Profil. (Kunci Aplikasi tidak bisa dibuka dari alur normal — lihat Step 4.)

Untuk tiap screenshot, cocokkan: urutan section, judul besar + nav bar, posisi "+", kartu mana yang hero biru, segmented vs chip tabs, bentuk kartu/grup, empty state. Catat setiap selisih sebagai daftar; perbaiki selisih di screen milik B7 di sini, dan untuk screen plan lain buat daftar tindak lanjut (jangan diam-diam memperbaikinya di commit B7 tanpa dicatat).

Hentikan server setelah selesai (`netstat -ano | grep :8765` → `taskkill //F //PID <pid>`), lalu `git checkout -- linux macos windows`.

- [ ] **Step 3: Review akhir `flutter-code-reviewer`**

Dispatch subagent `flutter-code-reviewer` untuk `git diff main...HEAD` branch ini dengan fokus: poin 5 & 6 di definisinya (konformitas redesign + kelas bug yang diketahui), seam test (`@visibleForTesting` tidak dipakai kode produksi: `grep -rn "LockScreen(auth:\|initialName:\|initialEmail:" lib/` harus kosong), toast/tombol ganda, dan pengecekan bahwa `_login`/`_register`/`_updateProfile`/`_authenticateWithBiometrics`/`_logout` identik dengan `git show main:<file>`. Terapkan temuan Critical/Important, jalankan ulang Step 1.

- [ ] **Step 4: Laporan ke user**

Sampaikan (Bahasa Indonesia, ringkas):
- Screen akun selesai + hasil checkpoint visual.
- Widget lama yang dihapus (atau yang tertahan beserta alasannya dari Task 7 Step 1).
- Pengecualian warna yang dibiarkan (Task 8).
- **Temuan di luar scope:** `LockScreen` tidak pernah ditampilkan — `lib/main.dart:108` langsung membuka `HomeScreen` saat user sudah login, sehingga kunci biometrik tidak aktif; import `lock_screen.dart` di `main.dart:5` tidak terpakai. Tanyakan apakah kunci biometrik mau diaktifkan (perubahan perilaku, butuh persetujuan).

- [ ] **Step 5: Selesaikan branch**

Pakai skill `superpowers:finishing-a-development-branch` (merge ke `main` setelah user menyetujui hasil visual).
