# Code Structure Refactor — Phase 1: Foundation — Design Spec

Tanggal: 2026-09-13
Status: Disetujui oleh user, menunggu rencana implementasi

## Konteks

Setelah setup agent-first tooling (lihat
`2026-09-13-agent-first-setup-design.md`), user ingin memperbaiki
struktur kode DompetKu sebelum melanjutkan pekerjaan UI/UX, secara
spesifik agar:
- Komponen UI dapat digunakan ulang dan konsisten secara visual di
  seluruh layar (keluhan konkret user: selector mirip tab terlihat
  berbeda antar layar karena setiap layar mengimplementasikan ulang
  versinya sendiri).
- Logika bisnis (pemanggilan Supabase, perhitungan) dipisahkan dari
  widget layar agar layar tetap fokus pada UI.
- Subagent `flutter-ui-builder` (dari setup agent-first) nantinya bisa
  diberi instruksi "gunakan komponen X" alih-alih berimprovisasi per
  layar.

Ini adalah upaya besar yang melibatkan banyak layar. Sesuai keputusan
user, pekerjaan ini dibagi menjadi beberapa fase, masing-masing dengan
spec/plan sendiri. **Spec ini hanya mencakup Fase 1**: membangun
fondasi (component library + pola state management) dan membuktikannya
end-to-end pada satu layar yang representatif. Fase-fase berikutnya
(migrasi 23 layar sisanya, dengan prioritas `home_screen.dart` dan
`stats_screen.dart` yang menjadi tempat inkonsistensi tab benar-benar
terlihat) berada di luar cakupan spec ini dan akan mendapat spec-nya
masing-masing.

## Kondisi Saat Ini (hasil observasi)

- 24 layar di `lib/screens/`, flat, totalnya ~18.800 baris. Yang
  terbesar: `target_screen.dart` (1759 baris), `stats_screen.dart`
  (1432), `savings_screen.dart` (1427), `home_screen.dart` (1411).
- **Nol widget class yang reusable**: `grep -rn "^class .*extends
  StatelessWidget" lib/screens/*.dart` tidak menghasilkan apa pun.
  Setiap layar membangun UI-nya melalui method privat `_buildXxx` di
  dalam class `State`-nya — tidak ada yang diekstrak atau dibagikan.
- **13 dari 24 layar** memanggil `showModalBottomSheet` secara
  independen, masing-masing dengan styling inline sendiri (sudut
  membulat, padding, drag handle) — tidak ada wrapper bottom-sheet
  yang dibagikan bersama.
- **300+ kemunculan** `BorderRadius.circular(...)` tersebar di
  berbagai layar — styling card/container di-copy-paste, bukan
  dijadikan komponen.
- Selector mirip tab setidaknya ada di `home_screen.dart` dan
  `stats_screen.dart`, masing-masing diimplementasikan sebagai kode
  `Row`/`GestureDetector` ad hoc — bukan widget yang sama, sehingga
  terlihat tidak konsisten secara visual (keluhan yang dilaporkan
  user).
- Belum ada library state management. Layar berupa `StatefulWidget`
  yang memanggil `Supabase.instance.client` langsung di dalam method
  seperti `_showTransferSheet()`/`_showAddEditWalletSheet()` milik
  `wallet_screen.dart`.
- `wallet_screen.dart` (665 baris) merepresentasikan pola ini:
  sebuah `StatefulWidget` yang menyimpan field `SupabaseClient`,
  method logika bisnis, dan dua pemanggilan `showModalBottomSheet`
  dengan UI inline.

## Tujuan

1. Membangun `lib/widgets/`: component library bersama, dibuat dengan
   membungkus dan mengganti styling komponen **`forui`** (sesuai
   instruksi eksplisit user: "base component semuanya dari forui" —
   setiap komponen dasar di library ini membungkus widget forui,
   bukan kode kustom ad hoc), diberi tema agar sesuai identitas
   `AppColors`/Poppins/Phosphor yang sudah ada di aplikasi, bukan
   tampilan default forui.
2. Membangun `lib/providers/`: pola berbasis Riverpod untuk
   memindahkan logika bisnis (pemanggilan Supabase, perhitungan)
   keluar dari layar.
3. Membuktikan keduanya end-to-end dengan memigrasikan sepenuhnya
   **`wallet_screen.dart`** — UI dibangun ulang dari komponen
   `lib/widgets/`, logika dipindahkan ke
   `lib/providers/wallet_provider.dart`.
4. Meninggalkan codebase dalam kondisi di mana migrasi layar *kedua*
   (Fase 2+) punya pola yang jelas dan terdokumentasi untuk diikuti —
   deliverable spec ini adalah pola dan pembuktiannya, bukan cakupan
   penuh.

## Non-Tujuan

- Memigrasikan layar mana pun selain `wallet_screen.dart` (23 layar
  sisanya, termasuk `home_screen.dart`/`stats_screen.dart` yang
  berprioritas tinggi — untuk spec mendatang).
- Redesign visual di luar yang diperlukan untuk konsistensi. Ini
  adalah refactor struktural, bukan redesign UI/UX — komponen
  diberi styling ulang agar sesuai palet `AppColors` yang *sudah ada*,
  bukan tampilan baru.
- Perubahan skema Supabase.
- Tooling code generation (tanpa `riverpod_generator`/`build_runner`)
  — penggunaan Riverpod di fase ini memakai API `Provider`/
  `FutureProvider`/`NotifierProvider` biasa, agar jejak
  dependency/tooling tetap kecil. Pertimbangkan lagi codegen di fase
  berikutnya jika boilerplate mulai terasa menyulitkan.
- Memperbarui `flutter-ui-builder`/`AGENTS.md` untuk mewajibkan
  komponen baru — ditunda sampai *setelah* pola di fase ini terbukti
  berjalan (tugas follow-up singkat begitu Fase 1 selesai), tidak
  digabungkan ke plan ini.

## Desain

### 1. Dependencies

Diverifikasi lewat `flutter pub add --dry-run` terhadap toolchain
Flutter 3.38.5 / Dart 3.10.4 yang sebenarnya digunakan proyek ini
(bukan asumsi dari dokumentasi package, yang merujuk ke floor SDK
lebih baru yang tidak relevan):

- `forui` resolve ke **0.17.0** (versi terbaru 0.26.0 membutuhkan
  Flutter yang lebih baru dari yang dimiliki proyek ini — 0.17.0
  adalah versi yang benar-benar didapat SDK ini).
- `flutter_riverpod` resolve ke **3.3.2**.

Kedua dry-run selesai dengan bersih, tanpa konflik constraint
terhadap dependency yang sudah ada (`supabase_flutter`,
`google_fonts`, `fl_chart`, dll).

### 2. Struktur folder: `lib/widgets/` global + override lokal per-layar

Struktur feature-first/colocation — padanan Flutter dari pola
`components/` (global, dibagikan bersama) + `_components/` per-route
(override lokal, dipakai hanya saat sebuah layar butuh varian yang
berbeda dari komponen global) ala Next.js yang dideskripsikan user.
Dart tidak punya konvensi folder routing yang setara dengan prefix
underscore Next.js, jadi ini adalah struktur biasa yang ditegakkan
lewat konvensi (bukan oleh compiler):

```
lib/
  widgets/                          # global, shared across all screens
    app_card.dart
    app_bottom_sheet.dart
    app_button.dart
    app_tab_selector.dart
  screens/
    wallet/
      wallet_screen.dart            # moved from lib/screens/wallet_screen.dart
      widgets/                      # ONLY created if wallet needs a local
                                     # override that differs from lib/widgets/
```

Aturan: sebuah layar mengimpor langsung dari `lib/widgets/` secara
default. Subfolder `widgets/` lokal di bawah folder layar itu sendiri
hanya dibuat ketika sebuah komponen memang harus berbeda secara
visual/perilaku dari versi global untuk layar tersebut secara
spesifik — tidak pernah dibuat lebih dulu "untuk jaga-jaga." Layar
pembuktian di fase ini (`wallet_screen.dart`, Bagian 5) tidak
diperkirakan membutuhkan override lokal — jika implementer
menemukan bahwa ternyata perlu, itu tidak masalah dan sebaiknya
dicatat di laporan, tapi jangan mengada-adakan kebutuhan tersebut.

Fase ini hanya mengonversi `wallet_screen.dart` ke layout baru
`lib/screens/wallet/wallet_screen.dart`, sebagai bagian dari
pembuktian pola. 23 layar lainnya tetap flat di `lib/screens/`
sampai fase migrasinya masing-masing di kemudian hari — ini adalah
kondisi campuran yang disengaja dan sementara (sebagian layar dalam
layout per-folder, sebagian besar masih flat), yang wajar terjadi
di tengah migrasi dan perlu disebutkan di bagian Structure pada
`AGENTS.md` begitu fase ini selesai (ditunda ke tugas follow-up yang
sama dengan pembaruan `flutter-ui-builder`, sesuai Non-Tujuan spec
ini).

### 4. `lib/widgets/` — component library yang membungkus forui

Struktur: satu file per komponen, flat (mencerminkan kesederhanaan
pola `lib/models/`/`lib/services/` yang sudah ada — belum perlu
nesting lebih lanjut pada skala saat ini):

- `lib/widgets/app_card.dart` — membungkus `FCard` milik forui,
  diberi styling ulang dengan `AppColors.white`/`AppColors.background`
  dan konvensi corner radius yang sudah ada di aplikasi (dibaca dari
  penggunaan inline saat ini — sebagian besar layar memakai
  `BorderRadius.circular(16)` atau `(20)`; standarkan ke satu nilai
  sebagai bagian dari tugas ini dan catat nilai yang dipilih di doc
  comment komponennya).
- `lib/widgets/app_bottom_sheet.dart` — membungkus `FSheet` milik
  forui (atau `FPersistentSheet` jika lebih cocok — implementer
  mengonfirmasi terhadap API forui 0.17.0 yang sebenarnya, yang bisa
  saja berbeda dari dokumentasi terbaru), menyediakan satu helper
  `showAppBottomSheet(context, child: ...)` agar bottom sheet setiap
  layar mendapat padding/corner radius/drag-handle yang konsisten,
  alih-alih setiap layar menuliskan `showModalBottomSheet` inline
  dengan `shape`/`padding` sendiri.
- `lib/widgets/app_button.dart` — membungkus `FButton` milik forui,
  diberi styling ulang ke `AppColors.primary`/`AppColors.accent`.
- `lib/widgets/app_tab_selector.dart` — membungkus `FTabs` milik
  forui (atau primitive tab/segmented-control forui terdekat yang
  tersedia di versi 0.17.0), diberi styling ulang agar sesuai
  `AppColors`. Ini langsung menyasar inkonsistensi yang dilaporkan
  user — ini akan menjadi *satu-satunya* widget tab yang dipakai
  semua layar ke depannya.

Setiap file: satu class atau function yang mengembalikan `Widget`,
disertai doc comment singkat yang menyebutkan widget forui mana yang
dibungkus dan alasan pilihan styling-nya (*alasannya*, bukan
pengulangan dari kode) — sesuai konvensi proyek ini "default tanpa
komentar kecuali alasannya tidak jelas dengan sendirinya."

### 5. `lib/providers/` — pola Riverpod

- `main.dart` dibungkus dengan `ProviderScope` (root widget
  Riverpod), menggantikan `runApp(const MyApp())` biasa — ini adalah
  satu-satunya perubahan yang tidak terhindarkan pada `main.dart` di
  fase ini.
- `lib/providers/wallet_provider.dart`: sebuah `NotifierProvider`
  (atau `FutureProvider` untuk fetch read-only — implementer memilih
  sesuai pola yang direkomendasikan Riverpod 3.x saat ini untuk list
  yang didukung Supabase) yang menyimpan state daftar wallet,
  menyediakan method yang setara dengan yang saat ini dilakukan
  `wallet_screen.dart` secara inline (fetch wallet, tambah wallet,
  edit wallet, transfer antar wallet). Pemanggilan Supabase
  dipindahkan ke sini apa adanya dari layar — fase ini memindahkan
  kode, bukan menulis ulang logika query Supabase itu sendiri.
- Tidak ada provider lain di fase ini — satu file provider, yang
  membuktikan polanya, adalah deliverable-nya.

### 6. Migrasi `wallet_screen.dart` (pembuktian)

- Pindahkan `lib/screens/wallet_screen.dart` ke
  `lib/screens/wallet/wallet_screen.dart` (sesuai struktur folder di
  Bagian 2), perbarui importnya di file mana pun yang saat ini
  menavigasi ke sana.
- Konversi `WalletScreen` dari `StatefulWidget` menjadi
  `ConsumerWidget` (atau `ConsumerStatefulWidget` jika state UI
  lokal seperti text controller masih dibutuhkan berdampingan dengan
  state provider — keputusan implementer, dokumentasikan mana yang
  dipilih dan alasannya).
- Ganti UI card/container inline dengan `lib/widgets/app_card.dart`.
- Ganti kedua pemanggilan `showModalBottomSheet` dengan helper baru
  `showAppBottomSheet`.
- Hapus field `Supabase.instance.client` langsung dan method logika
  bisnis dari layar; layar membaca/memanggil lewat
  `wallet_provider.dart` sebagai gantinya.
- Kondisi akhir: `wallet_screen.dart` seharusnya menyusut secara
  substansial (target pasti tidak diwajibkan — "tidak ada logika
  bisnis tersisa di file" adalah standarnya, bukan jumlah baris).

### 7. Testing

- Widget test untuk setiap komponen baru di `lib/widgets/`
  (`test/widgets/`, mengikuti path yang sama) — memverifikasi
  komponen ter-render dan merespons parameter yang didokumentasikan
  (misalnya `AppButton` memanggil `onPressed`-nya, `AppTabSelector`
  melaporkan index yang dipilih saat di-tap).
- Sebuah test untuk logika `wallet_provider.dart` yang tidak
  membutuhkan koneksi Supabase langsung jika memungkinkan (misalnya
  method perhitungan murni, jika ada) — method yang bergantung penuh
  pada Supabase mungkin hanya feasible untuk di-smoke-test demi
  kebenaran compile/shape, sesuai keterbatasan yang sudah
  didokumentasikan subagent `flutter-qa-writer` untuk kode yang
  terikat Supabase.
- Verifikasi visual manual terhadap `wallet_screen.dart` yang sudah
  dimigrasikan lewat skill `run-and-screenshot` sebelum menyatakan
  fase ini selesai.

## Testing / Verifikasi (plan ini)

- `flutter analyze` bersih pada semua file baru/berubah (245 issue
  yang sudah ada sebelumnya di tempat lain berada di luar cakupan).
- `flutter test` — test widget/provider baru lulus; kegagalan
  `test/widget_test.dart` yang sudah ada sebelumnya dan tidak
  terkait (didokumentasikan di ledger setup agent-first) bukan
  urusan plan ini.
- Pengecekan visual lewat `run-and-screenshot` pada
  `wallet_screen.dart`: daftar wallet ter-render, sheet tambah/edit
  terbuka dengan styling bottom-sheet baru, sheet transfer berfungsi,
  tidak ada regresi fungsionalitas (saldo tetap terupdate dengan
  benar).

## Pertanyaan Terbuka

Tidak ada yang tersisa — semua sudah terselesaikan selama
brainstorming. Satu keputusan diserahkan secara eksplisit ke
implementer (Bagian 4: nama/API widget forui yang persis di v0.17.0
bisa saja berbeda dari dokumentasi terbaru yang dirujuk selama riset
spec ini — implementer memverifikasi terhadap package yang benar-benar
terinstal, misalnya lewat output `flutter pub deps` atau source
package yang di-vendor di bawah `~/.pub-cache`, sebelum menulis kode
wrapper final).
