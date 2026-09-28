# Redesign Login & Daftar (Bagian 2) — Desain

Tanggal: 2026-09-28 · Revisi 2 (menggantikan mockup A) · Status: disetujui
lewat mockup

Mockup yang disetujui: https://claude.ai/artifact/7EKjsBNgGkWqocfKZZsLDu
(tata letak mengikuti referensi Rotta/Potara Studio di Dribbble; warna,
huruf, dan ikon tetap milik DompetKu).

## 1. Masalah

Revisi 1 (hero + sheet abu, tombol menempel di bawah) menyisakan ruang
kosong besar antara isian dan tombol di HP tinggi. Pengguna memilih tata
letak referensi Rotta, ditambah tombol Google. Facebook tidak dipasang.

## 2. Ruang lingkup

- Masuk dan Daftar digabung jadi **satu layar** (`LoginScreen`) dengan
  pilihan **Masuk | Daftar** (`AppSegmentedControl`). `RegisterScreen`
  dihapus. `main.dart` dan Pengaturan tetap membuka `LoginScreen()`.
- Logika `_login()` dan `_register()` tidak berubah (validasi, pesan,
  panggilan Supabase), dengan satu pengecualian yang wajib: setelah daftar
  berhasil, dulu `Navigator.pop` kembali ke Login. Sekarang tab pindah ke
  **Masuk** dan email yang baru didaftarkan terisi otomatis. Tanpa
  perubahan ini, `pop` akan menutup layar akar.
- **Tombol Google** ("Lanjut dengan Google") ada di kedua tab di bawah
  garis "atau masuk dengan" / "atau daftar dengan". Saat diketuk, muncul
  notifikasi info **"Login Google belum tersedia. Pakai email dan password
  dulu ya."**. Tidak ada panggilan ke Google atau Supabase OAuth.
- Tidak dipasang: Facebook, "Ingat saya" (sesi sudah otomatis tersimpan),
  dan "Lupa password?".
- Backend tidak tersentuh, jadi E2E cukup dijalankan ulang sebagai regresi.

## 3. Tata letak

```
┌──────────────────────────────┐  hero gradasi heroGradientStart→End,
│ [logo 44]          ◯ ◯ (dekor)│  2 lingkaran garis tipis putih 13%
│ Yuk, atur keuanganmu (26/800) │  di kanan atas
│ Masuk atau buat akun untuk…   │
├─╮────────────────────────────╭┤  sheet PUTIH (surface), radius atas 24
│ [ Masuk | Daftar ]            │  AppSegmentedControl
│ [✉ Email                  ]   │  isian berlabel di dalam kotak
│ [🔒 Password           👁 ]   │
│ [        Masuk         ]      │  AppPrimaryButton
│ ──── atau masuk dengan ────   │
│ [ G  Lanjut dengan Google ]   │  AuthGoogleButton (garis tepi)
│            … spacer …         │
│ Datamu hanya bisa dilihat …   │  footer kecil (tab Masuk saja)
└──────────────────────────────┘
```

- **Hero:**
  - kotak logo 44 (putih 18%) dengan `PhosphorIconsFill.wallet`;
  - judul "Yuk, atur keuanganmu";
  - subjudul "Masuk atau buat akun untuk mulai mencatat pemasukan dan
    pengeluaranmu." (warna `heroLabel`);
  - hero sama untuk kedua tab.
- **Tab Masuk:**
  - Email (label "Email", hint "email@contoh.com") dan Password (label
    "Password", hint "Masukkan password Anda", tombol mata);
  - tombol "Masuk";
  - "atau masuk dengan", lalu Google;
  - footer "Datamu hanya bisa dilihat dari akunmu sendiri.".
- **Tab Daftar:**
  - Nama lengkap, Email, dan Password (hint "Buat password yang kuat",
    tombol mata);
  - caption "Minimal 6 karakter.";
  - tombol "Daftar Sekarang";
  - "atau daftar dengan", lalu Google;
  - tanpa footer.
- **Tombol dan scroll:** tombol ikut langsung di bawah isian, lalu spacer
  sebelum footer. Isi bisa di-scroll saat keyboard terbuka. Sudut sheet
  adalah kotak nyata, dan safe area kiri/kanan/atas/bawah dihitung.
- **Pindah tab:** isian Daftar dan password Masuk dikosongkan (tiap tab
  punya state sendiri). Email di tab Masuk tetap tersimpan, dan setelah
  daftar berhasil email itu diisi dengan email yang baru didaftarkan.
- **Status bar:** `AppSystemUi.onHero` (ikon terang). Default aplikasi
  `AppSystemUi.standard` tetap dipasang di `MaterialApp.builder`.

## 4. Komponen

- **`AppTextField(outlined: true)`:**
  - garis tepi dan cincin fokus digambar oleh kotak pembungkus:
    - tidak fokus: `Border.all(track, 1.5)`;
    - fokus: `primary` 1.5 + cincin `focusRing` 4px;
    - di dalamnya `TextField` tanpa border;
  - dengan `label`, label kecil tampil **di dalam** kotak di atas nilai
    (`labelText` + `FloatingLabelBehavior.always`), bukan di luar;
  - ikon awal `primary` saat fokus;
  - tanpa `outlined`, perilaku lama tetap.
- **`AppNotification.info(context, message)`:** gaya sama seperti toast
  lain, dengan lingkaran `primarySoft` dan ikon info `primary`.
- **`AuthGoogleButton({label, onTap})`:**
  - tinggi 48, radius 14, putih, garis tepi `track`;
  - logo "G" empat warna digambar `CustomPainter` (`GoogleLogo`), dengan
    warna baru `AppColors.googleBlue/Red/Yellow/Green`;
  - tanpa dependensi baru.
- **`AuthDivider(label)`:** garis — teks — garis.
- **`AuthLayout({title, subtitle, leading, children, footer?})`:**
  - hero dengan dekorasi lingkaran;
  - sheet putih;
  - `children` diberi jarak 12;
  - `footer` opsional di dasar (setelah `Spacer`).
  - `AuthLogo` tetap dipakai. `AuthBackButton` dan `AuthFooter` dihapus
    karena tidak dipakai lagi.
- **`LoginForm` dan `RegisterForm`** (`lib/screens/login/`) memegang
  controller dan `_login()`/`_register()` masing-masing. `LoginScreen`
  hanya memegang tab dan email hasil daftar.

## 5. Pengujian

- **Unit/widget:**
  - toast info (ikon `primary`, latar `primarySoft`);
  - field outlined (kotak berganti garis tepi saat fokus, label di dalam
    kotak dan di atas teks isian);
  - `AuthGoogleButton` (teks, logo, onTap);
  - `AuthLayout` (tidak overflow di 320×568 + keyboard, text scale 1.3,
    safe area samping, status bar).
- **LoginScreen:**
  - tab default Masuk;
  - pindah ke Daftar menampilkan Nama lengkap;
  - validasi kosong dan spasi saja di kedua tab (pesan lama);
  - ketuk Google di kedua tab memunculkan toast info;
  - Facebook tidak ada;
  - daftar berhasil pindah ke Masuk dengan email terisi: tes memanggil
    `onRegistered` milik `RegisterForm` secara langsung, karena
    `_register()` sendiri tidak diubah dan tidak punya seam Supabase.
- **Screenshot:** Masuk, Masuk fokus, Daftar, dan toast Google.
- **Verifikasi penuh:** `flutter analyze` bersih, dan `flutter test` penuh
  termasuk E2E lulus.
