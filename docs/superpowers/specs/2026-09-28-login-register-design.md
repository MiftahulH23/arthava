# Redesign Login & Daftar (Bagian 2) — Desain

Tanggal: 2026-09-28 · Status: menunggu persetujuan

Mockup yang disetujui: opsi **A** di
https://claude.ai/artifact/DTEbDUhmQ2iPN83SSnRoDS (versi 3, tanpa chip
"Saldo bulan ini").

## 1. Masalah

Di HP, isian Login/Daftar berada dalam satu `AppGroupedSection`: isian
putih tanpa garis tepi, dan garis fokus biru terpotong oleh sudut grup.
Hasilnya terlihat berantakan. Pengguna minta tampilan yang lebih rapi dan
kreatif.

## 2. Ruang lingkup

Hanya tampilan. `_login()` dan `_register()` tidak diubah sama sekali:
validasi, pesan, panggilan Supabase, dan navigasi tetap seperti sekarang.

Tidak termasuk: "Lupa password?" (hanya ide di mockup), login sosial,
serta perubahan skema atau backend. Karena backend tidak tersentuh,
E2E cukup dijalankan ulang sebagai regresi, tanpa E2E baru.

## 3. Tata letak (sama untuk kedua layar)

```
┌──────────────────────────────┐  hero gradasi heroGradientStart→End
│ [‹ Masuk]        (Daftar saja)│  padding atas = safe area + 16
│ [logo 44]        (Login saja) │
│ Judul 24/800 putih            │
│ Tagline 12.5 putih 85%        │
├─╮────────────────────────────╭┤  sheet background, radius atas 26,
│  Judul sheet 16/800 (Login)   │  naik 30px menutupi hero
│  [ isian ]  [ isian ]         │
│  … spacer …                   │
│  [ Tombol utama 46 ]          │
│  Belum punya akun? Daftar     │
└──────────────────────────────┘
```

- **Login**: kotak logo 44×44, radius 12, putih alpha 18%, ikon
  `PhosphorIconsFill.wallet` putih. Judul "DompetKu", tagline "Cerdas
  mengelola, tenang finansial". Judul sheet "Masuk ke akunmu". Isian email
  dan password (tombol mata tetap ada), tombol "Masuk Sekarang", footer
  "Belum punya akun? **Daftar Disini**".
- **Daftar**: tombol teks "‹ Masuk" putih di hero (`Navigator.pop`),
  judul "Buat akun baru", tagline "Gabung dan mulai atur keuanganmu".
  Isian nama (hint "Nama lengkap"), email, dan password (dengan mata).
  Di bawahnya caption "Minimal 6 karakter.", lalu "Daftar Sekarang" dan
  footer "Sudah punya akun? **Masuk Disini**".
- Konten sheet bisa di-scroll saat keyboard muncul. Bila layar cukup
  tinggi, tombol dan footer menempel di bawah (`CustomScrollView` +
  `SliverFillRemaining(hasScrollBody: false)` + `Spacer`), jadi tidak
  overflow di layar pendek. Sudut atas sheet adalah kotak nyata di dalam
  hero (bukan `Transform`), dan safe area kiri/kanan ikut dihitung.
- Status bar di atas hero memakai ikon terang (`AppSystemUi.onHero`), nav
  bar Android mengikuti latar sheet. Default seluruh aplikasi
  (`AppSystemUi` di `MaterialApp.builder`) adalah ikon gelap, jadi gaya
  terang tidak terbawa ke layar lain setelah login.

## 4. Komponen

- **`AuthLayout`** (`lib/screens/login/auth_layout.dart`) menggantikan
  `AuthBrand`. Parameternya: `title`, `subtitle`, `leading` (`AuthLogo`
  atau `AuthBackButton`), `sheetTitle?`, `fields` (isian), `action`
  (tombol), dan `footer`. `AuthFooter` dipertahankan dan dipindah ke file ini.
  `auth_brand.dart` dihapus.
- **`AppTextField`** mendapat parameter `outlined` (default `false`,
  sehingga 32 pemakaian lain tidak berubah). Saat `true`:
  - tinggi ±48, radius 14, isi `surface`, garis tepi 1.5px `track`;
  - saat fokus: garis tepi `primary` 1.5px, cincin 4px `focusRing`
    (warna baru di `AppColors`: `0x21007AFF`, biru 13%), dan ikon awal
    berwarna `primary`;
  - status fokus dibaca dari `FocusNode` (milik pemanggil kalau ada,
    kalau tidak dibuat sendiri), jadi widget ini menjadi `StatefulWidget`.
- Tombol memakai `AppPrimaryButton` yang sudah ada, dan teks memakai
  `AppTextStyles`. Tidak ada hex yang ditulis langsung.

## 5. Pengujian

- **Widget test Login/Daftar yang ada tetap lulus.** Tes validasi, tes
  spasi saja, dan tes navigasi ke Daftar dan kembali akan mencari teks
  yang sama. Teks yang berubah ("Selamat Datang!" menjadi "Masuk ke
  akunmu", dan hint nama) diperbarui di tes.
- **Tes baru untuk `AppTextField(outlined: true)`:** garis tepi berwarna
  `track` saat tidak fokus; setelah diketuk, cincin `focusRing` dan ikon
  `primary` muncul. Tes lama field tanpa `outlined` tidak berubah.
- **Tes tata letak:** Login dan Daftar tidak overflow di 320×568 dan
  390×844, dan tidak overflow saat keyboard terbuka (`viewInsets`).
- **Screenshot:** `b7_01_login` dan `b7_02_register` diperbarui, plus satu
  shot fokus email untuk dibandingkan dengan mockup.
- Semua tes lain harus tetap lulus: `flutter analyze` bersih, dan
  `flutter test` penuh termasuk E2E sebagai regresi.
