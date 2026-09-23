# Redesign Visual — Fase A (Fondasi + Home Screen) — Design Spec

Tanggal: 2026-09-23
Status: Disetujui oleh user, menunggu rencana implementasi

## Konteks

Setelah refactor struktur kode selesai (Fase 1 & 2, semua 24 screen sudah
punya folder per-fitur, provider Riverpod, dan component library bersama
di `lib/widgets/` yang membungkus `forui`), user sekarang ingin lanjut ke
redesign visual/UX yang sejak awal jadi tujuan utama proyek ini.

Arah desain yang disepakati sebelumnya: **Material dengan vibe iOS/fintech
premium**, bukan Cupertino murni (project ini multi-platform — android,
ios, web, windows — sehingga Cupertino murni akan terasa asing di
platform selain iOS). Referensi visual: dua desain aplikasi fintech
bertema hijau (screenshot disediakan user) — card besar dengan gradient,
sudut sangat rounded, shadow lembut, angka besar & bold, bottom
navigation floating dengan indicator pill di tab aktif.

Seperti refactor struktur sebelumnya, redesign 24 screen sekaligus
terlalu besar untuk satu putaran. **Spec ini hanya mencakup Fase A**:
membangun fondasi visual baru (palet warna, tipografi, komponen inti)
dan membuktikannya pada satu screen representatif (**Home**). Fase
berikutnya (rollout ke 23 screen lain) di luar cakupan spec ini dan akan
mendapat spec-nya sendiri.

## Keputusan Desain (hasil brainstorming dengan user)

1. **Palet warna**: ganti total ke hijau (bukan sekadar restyle biru-abu
   yang sekarang) — mengikuti arah warna dari referensi.
2. **Referensi visual utama**: referensi #1 (terang, hijau pastel,
   background putih/hijau muda lembut, hero card hijau tua solid untuk
   saldo). Referensi #2 (kontras tinggi, hero card gelap) TIDAK dipakai.
3. **Bukan cuma ganti warna** — layout dan bentuk card di Home juga
   dirombak mengikuti pola referensi (posisi elemen, bentuk card saldo,
   quick actions, list aktivitas). **Fitur dan fungsi tetap identik** —
   tidak ada data yang hilang, tidak ada aksi yang hilang/berubah
   fungsinya, hanya presentasi visualnya yang berubah.
4. **Screen pilot**: Home — paling sering dilihat, paling representatif
   untuk membuktikan arah desain baru (hero card, quick actions, bottom
   nav semua ada di satu tempat).
5. **Bottom navigation**: ganti dari `BottomAppBar` custom yang sekarang
   ke gaya **floating pill** seperti referensi — nav bar melayang
   (bukan menempel penuh di tepi layar), dengan indicator khusus
   (bulat/pill terisi) di tab yang sedang aktif.
6. **Font**: ganti dari Poppins ke **Plus Jakarta Sans** (via
   `google_fonts`, package yang sudah terpasang — tidak perlu dependency
   baru, hanya ganti nama font yang dipanggil).

## Kondisi Saat Ini (hasil observasi)

- `lib/core/colors.dart`: `AppColors.primary` = `#2D3E50` (biru-abu
  gelap), `AppColors.background` = `#F4F6F8` (abu sangat muda),
  `AppColors.income` = `#2ECC71` (hijau segar — sudah dekat dengan arah
  warna baru, jadi titik awal yang baik untuk hijau utama),
  `AppColors.expense` = `#E74C3C` (merah soft), `AppColors.accent` =
  `#3498DB` (biru terang).
- Font: Poppins, dipasang sekali di `main.dart` via
  `GoogleFonts.poppinsTextTheme(...)`, dan dipetakan ke tema forui lewat
  `lib/theme/app_forui_theme.dart`'s `typography` field
  (`GoogleFonts.poppins().fontFamily!`).
- `home_screen.dart` (`lib/screens/home/home_screen.dart`, hasil
  migrasi Fase 2): `ConsumerStatefulWidget`, state dari `homeProvider`
  (`lib/providers/home_provider.dart`) berisi `userName`,
  `monthlyIncome`, `monthlyExpense`, `totalSavings`, `totalInvestments`,
  `wallets`, `totalWalletBalance`, `isLoading`. Navigasi bawah saat ini
  pakai `BottomAppBar` (baris ~1073) dengan tombol-tombol ikon manual,
  bukan `BottomNavigationBar` standar Flutter maupun komponen bersama.
  Ada layout terpisah untuk mobile (`_buildMobileLayout`) dan
  web/desktop (`_buildWebLayout`).
- Component library dari refactor sebelumnya (`lib/widgets/`):
  `AppCard`/`AppButton`/`AppTabSelector`/`showAppBottomSheet`, semua
  membungkus `forui`, di-theme lewat `appForuiTheme`
  (`lib/theme/app_forui_theme.dart`) yang memetakan `AppColors` ke
  `FThemeData`.

## Tujuan

1. Update `AppColors` ke palet hijau baru sesuai referensi #1, dan
   perbarui `appForuiTheme` supaya perubahan ini otomatis menyebar ke
   semua komponen forui yang sudah dipakai (`AppCard`, `AppButton`,
   `AppTabSelector`, sheet dari `showAppBottomSheet`) — tanpa perlu
   menyentuh satu per satu.
2. Ganti font dari Poppins ke Plus Jakarta Sans, di satu tempat
   (`main.dart` + `app_forui_theme.dart`), supaya konsisten di seluruh
   app (bukan cuma Home) sejak Fase A — font adalah perubahan global
   yang murah dilakukan sekaligus, beda dari layout yang memang harus
   digilir per screen.
3. Membangun komponen navigasi baru: **floating pill bottom nav**
   (`lib/widgets/app_bottom_nav.dart`), menggantikan `BottomAppBar`
   custom di Home — dibuat sebagai komponen bersama (bukan kode
   khusus-Home) supaya screen lain bisa memakainya juga di fase
   berikutnya.
4. Membangun ulang **layout visual** `home_screen.dart` mengikuti pola
   referensi: hero balance card solid hijau tua, quick actions
   (card putih bulat kecil), recent activity list (card putih + icon
   badge bulat berwarna), semuanya di atas floating pill bottom nav yang
   baru — **tanpa mengubah fitur/fungsi/data yang ditampilkan**, hanya
   presentasinya.
5. Meninggalkan codebase dalam kondisi di mana migrasi visual layar
   *kedua* (Fase B+) punya pola desain yang jelas dan terbukti untuk
   diikuti.

## Non-Tujuan

- Redesign layar mana pun selain `home_screen.dart` (23 layar lainnya —
  untuk spec/fase mendatang).
- Perubahan fitur, alur data, atau logika bisnis apa pun — provider
  (`homeProvider`) dan semua data yang ditampilkan **tidak berubah**,
  hanya cara menampilkannya.
- Perubahan warna semantik `income`/`expense` (hijau untuk pemasukan,
  merah untuk pengeluaran tetap dipertahankan — itu makna, bukan tema).
- Perubahan skema Supabase.
- Redesign untuk mode gelap (`settings_screen.dart` tetap jadi
  satu-satunya screen dengan dark-mode manual; forui theme tetap
  light-only seperti keputusan Fase 1 — tidak diperluas di sini).

## Desain

### 1. Palet warna baru (`lib/core/colors.dart`)

Nilai hex final ditentukan oleh implementer berdasarkan referensi visual
(user sudah menyediakan screenshot referensi #1 sebagai sumber warna
yang tepat) — implementer men-sample warna dari referensi tersebut
(hero card hijau tua, background hijau pastel/putih) alih-alih menebak.
Struktur yang WAJIB dipertahankan (nama field, supaya tidak merusak
seluruh codebase yang sudah memakai `AppColors.primary` dkk secara
luas):

- `primary` → hijau tua solid (dipakai untuk hero card, tombol utama)
- `background` → hijau pastel sangat muda atau putih kehijauan (sesuai
  referensi — background utama app)
- `white` → tetap `Colors.white`
- `income` → tetap hijau (boleh disamakan dengan `primary` atau sedikit
  divariasikan — implementer pertimbangkan kontras/legibility saat
  dipakai bersamaan sebagai badge warna di list transaksi)
- `expense` → tetap merah soft (tidak berubah, sudah kontras baik
  dengan hijau)
- `textPrimary` / `textSecondary` → disesuaikan agar kontras baik
  dengan background baru yang lebih terang
- `accent` → boleh dipertahankan biru terang untuk elemen yang butuh
  penekanan berbeda dari hijau utama, atau disesuaikan — implementer
  pertimbangkan berdasarkan referensi

### 2. Font: Plus Jakarta Sans

- `lib/main.dart`: ganti `GoogleFonts.poppinsTextTheme(...)` →
  `GoogleFonts.plusJakartaSansTextTheme(...)`.
- `lib/theme/app_forui_theme.dart`: ganti
  `GoogleFonts.poppins().fontFamily!` →
  `GoogleFonts.plusJakartaSans().fontFamily!`.
- Ini perubahan global (bukan per-screen) — begitu Fase A selesai,
  SELURUH app (semua 24 screen) langsung memakai font baru, bukan cuma
  Home. Ini disengaja (murah, konsisten, tidak ada alasan menunda font
  di screen yang belum di-redesign layoutnya).
- Update dokumentasi konvensi (`AGENTS.md`'s Conventions section, sesuai
  aturan "Keeping this file in sync" yang sudah ada di sana) untuk
  mencerminkan font baru.

### 3. Komponen baru: `AppBottomNav` (`lib/widgets/app_bottom_nav.dart`)

Floating pill bottom navigation. Bentuk: container melayang (margin dari
tepi layar, bukan menempel penuh), rounded penuh (pill shape),
shadow lembut, berisi beberapa item navigasi (ikon + optional label),
dengan indicator visual jelas pada item yang aktif (background bulat
atau pill terisi warna primary di sekitar ikon aktif — sesuai
referensi).

Interface yang diusulkan (implementer boleh menyesuaikan detail, ini
bukan kontrak kaku seperti komponen forui-wrapper sebelumnya karena
ini komponen custom, bukan wrapper):
```dart
class AppBottomNavItem {
  final IconData icon;
  final String? label;
  const AppBottomNavItem({required this.icon, this.label});
}

class AppBottomNav extends StatelessWidget {
  final List<AppBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  // ...
}
```

Dibangun sebagai widget Flutter biasa (Container + Row + AnimatedContainer
untuk transisi indicator), TIDAK perlu membungkus widget forui tertentu
(beda dari `AppCard`/`AppButton`/dll — forui tidak (setahu implementer
saat spec ini ditulis) punya primitive floating-pill-bottom-nav siap
pakai; implementer verifikasi ke source forui yang terpasang sebelum
memutuskan build-from-scratch vs ada primitive yang cocok, mengikuti
disiplin "cek source asli, jangan asumsi" yang sudah jadi kebiasaan di
refactor sebelumnya).

### 4. Migrasi `home_screen.dart` ke layout baru

- Hero balance card: ganti card saldo yang sekarang jadi card solid
  `AppColors.primary` (hijau tua) besar di bagian atas, menampilkan
  total saldo (`totalWalletBalance` dari `homeProvider`, data yang
  sudah ada — tidak berubah), mengikuti proporsi/bentuk referensi
  (rounded besar, padding lega, angka besar bold).
- Quick actions: elemen aksi cepat yang sudah ada di Home saat ini
  (implementer identifikasi dari kode yang ada) direstyle jadi
  card putih bulat kecil sejajar horizontal, ikon di dalam badge bulat
  berwarna, sesuai referensi.
- Recent activity: list transaksi terakhir yang sudah ada, card per-item
  putih dengan icon badge bulat berwarna (income=hijau, expense=merah,
  sesuai kategori/tipe transaksi — logika penentuan warna badge sudah
  ada di kode saat ini, dipertahankan, hanya bentuk card-nya yang
  diperbarui).
- Bottom nav: ganti `BottomAppBar` (baris ~1073 saat ini) dengan
  `AppBottomNav` yang baru, item navigasi sama persis dengan yang ada
  sekarang (tab yang sama, urutan sama) — hanya kulitnya yang berubah.
- **Mobile dan web/desktop layout**: `home_screen.dart` punya dua path
  layout terpisah (`_buildMobileLayout`/`_buildWebLayout`). Implementer
  terapkan desain baru ke KEDUANYA — redesign yang hanya menyentuh
  mobile dan meninggalkan web/desktop dengan tampilan lama akan
  membuat versi web terasa usang dibanding versi mobile secara
  langsung terlihat. Jika ada perbedaan tata letak yang masuk akal
  antara mobile/web (misal bottom nav floating pill mungkin kurang
  cocok untuk layout desktop lebar), implementer boleh mengadaptasi
  (misal sidebar untuk web) — tapi ini keputusan yang harus
  didokumentasikan di laporan implementasi, bukan diam-diam
  dibiarkan berbeda.
- Semua binding data (`ref.watch(homeProvider)`, dsb) TIDAK berubah —
  ini murni migrasi presentasi di atas provider yang sudah ada.

### 5. Testing / Verifikasi

- `flutter analyze` + `flutter test` seperti biasa (bar minimum,
  tidak ada regresi baru).
- Widget test untuk `AppBottomNav` (komponen baru): render semua item,
  tap mengubah `selectedIndex` dan memanggil `onChanged` dengan index
  yang benar — mengikuti pola test yang sudah dipakai untuk
  `AppTabSelector`.
- **Verifikasi visual manual oleh user** (real device/browser, akun
  asli) sebelum dianggap selesai — WAJIB, bukan opsional. Pelajaran
  dari refactor struktur sebelumnya: dua bug nyata (crash Material
  ancestor, provider stuck-loading) hanya ketahuan lewat tes manual,
  tidak lewat code review. Untuk redesign visual, risiko serupa (atau
  lebih tinggi, karena ini soal presentasi visual yang sulit
  diverifikasi lewat teks) — jangan anggap selesai sebelum user benar-
  benar melihat hasilnya di app yang jalan.

## Pertanyaan Terbuka

Tidak ada yang tersisa — semua sudah diputuskan lewat brainstorming.
Satu keputusan implementasi didelegasikan secara eksplisit ke
implementer (Bagian 1: nilai hex warna final di-sample dari referensi
visual, bukan ditebak oleh spec ini; Bagian 3: apakah `AppBottomNav`
membungkus primitive forui atau dibangun from-scratch, diverifikasi
terhadap source forui yang terpasang saat implementasi berjalan).
