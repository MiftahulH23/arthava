# Tab Kapsul, Geser Pindah Tab, Geser Hapus, Isian & Keyboard — Desain

Tanggal: 2026-10-10 · Status: menunggu persetujuan

Mockup: https://claude.ai/artifact/YLE9CBJxRGEw7iMCGN2gJo (versi 2). Keputusan
pengguna: gaya tab **A · Kapsul geser**. Aturan geser: **di atas data = buka
Edit/Hapus, di tempat lain = pindah tab**.

## 1. Masalah (hasil uji di HP)

1. Setelah memilih isian jenis select/dropdown, keyboard muncul lagi atau
   masih terbuka.
2. Garis biru fokus pada isian Catatan (Tambah Transaksi) terpotong di sudut.
3. Tab berbentuk kotak abu persegi panjang. Pengguna ingin gaya baru yang
   lebih minimalis dan tetap bernuansa iOS.
4. Pindah tab hanya bisa dengan mengetuk. Pengguna ingin bisa juga dengan
   menggeser layar.
5. Hapus utang/piutang dan data sejenis masih lewat tombol. Pengguna ingin
   menghapus dengan menggeser data, seperti di daftar transaksi.

## 2. Ruang lingkup

Hanya UI dan interaksi. Tidak ada perubahan skema, RPC, atau provider. Logika
hapus yang ada (dialog, pesan, panggilan provider) dipakai apa adanya; yang
berubah hanya cara memicunya. E2E dijalankan ulang sebagai regresi.

## 3. Rancangan

### 3.1 Keyboard tertutup saat memilih

`showAppBottomSheet` (`lib/widgets/app_bottom_sheet.dart`), yang menjadi dasar
semua lembar pilihan, menutup fokus (`FocusManager.instance.primaryFocus
?.unfocus()`) **sebelum** lembar dibuka.

- Saat lembar ditutup, Flutter mengembalikan fokus ke node yang terakhir fokus
  di route bawah. Karena fokus sudah dilepas, keyboard tidak naik lagi.
- Ini berlaku otomatis untuk `showAppFormSheet`, semua `showApp*Picker`,
  `AppSelectRow`, `AppWalletSelectRow`, `AppSearchableGroup`, dan
  `showAppPeriodPicker`.
- Pengecualian: lembar yang berisi isian teks (form) tetap bisa memfokuskan
  isiannya sendiri, karena yang dilepas hanya fokus halaman di belakangnya.

### 3.2 Garis fokus isian di dalam kartu

`AppTextField` varian biasa (bukan `outlined`): radius 16 → **20**, sama dengan
radius `AppGroupedSection`. Garis fokus biru 1.5px menjadi utuh di keempat
sudut. Tidak ada cincin luar, karena cincin akan terpotong oleh kartu. Isian
yang sama di luar kartu (mis. di lembar form) ikut radius 20, dan masih
selaras dengan kartu lain.

### 3.3 `AppSegmentedControl` gaya kapsul

API tetap sama (`labels`, `selectedIndex`, `onChanged`,
`selectedLabelColors`), dengan satu parameter baru opsional:
`ValueListenable<double>? position`.

- Jalur: kapsul bulat penuh (radius 999), warna `track`, tinggi 36, padding 3.
- Penanda: kapsul putih (`surface`) dengan bayangan lembut. Penanda meluncur
  (`AnimatedAlign`, 220 ms, `easeOutCubic`) ke segmen terpilih.
- Bila `position` diberikan (nilai 0..n-1, boleh pecahan), penanda mengikuti
  nilai itu secara langsung. Ini dipakai saat layar sedang digeser.
- Label: tidak terpilih `textSecondary` w600; terpilih memakai warna dari
  `selectedLabelColors` atau `textPrimary`, w700.
- Semantik: tiap segmen tetap `button` + `selected` +
  `inMutuallyExclusiveGroup`.

Gaya ini berlaku untuk semua pemakai: Transaksi, Statistik, Utang & Piutang,
Kelola Kategori, Zakat & Sedekah, Masuk/Daftar, Tambah Transaksi (jenis &
sumber dana), form utang, Ekspor, dan form transaksi rutin. `AppChipTabs`
(chip periode) tidak berubah.

### 3.4 Geser layar untuk pindah tab

Widget bersama baru **`AppSwipeTabs`** (`lib/widgets/app_swipe_tabs.dart`):

```dart
AppSwipeTabs(
  index: _tab,
  count: 2,
  onChanged: (i) => setState(() => _tab = i),
  child: <halaman>,
)
```

- Menangkap geser horizontal di seluruh `child`. Baris `AppSwipeActions` di
  dalamnya berada lebih dalam di arena gesture, jadi geseran yang dimulai di
  atas data tetap membuka Edit/Hapus. Geseran di tempat lain memindah tab.
- Selama digeser, isi yang dibungkus `AppSwipeTabBody` ikut tertarik jari.
  Pada tab pertama/terakhir ada tahanan, sehingga hanya bergeser sedikit.
- Dilepas melewati 25% lebar layar, atau dengan kecepatan > 400 px/s ke arah
  yang benar, maka `onChanged(index ± 1)` dipanggil dan isi baru meluncur
  masuk dari sisi yang sesuai. Kalau tidak, isi kembali ke posisi semula.
- `AppSwipeTabs.positionOf(context)` memberi `ValueListenable<double>` untuk
  `AppSegmentedControl.position`, supaya penanda kapsul ikut bergeser.
- **`AppSwipeTabBody`** membungkus bagian yang berganti per tab: daftar,
  grafik, atau form. Judul, tab, dan ringkasan tetap diam.

Halaman yang memakai geser:

| Halaman | Tab | Yang ikut bergeser |
|---|---|---|
| Transaksi (`TransactionsTabScreen`) | Pemasukan / Pengeluaran | seluruh `TransactionHistoryScreen` (tiap tab punya scaffold sendiri) |
| Statistik | Pemasukan / Pengeluaran | grafik & daftar kategori |
| Utang & Piutang | Utang Saya / Piutang | daftar kartu |
| Kelola Kategori | Pengeluaran / Pemasukan | daftar kategori |
| Zakat & Sedekah | Zakat / Sedekah | isi form |
| Masuk / Daftar | Masuk / Daftar | form (dua-duanya tetap ter-mount) |

Pilihan di dalam form (Tambah Transaksi, form utang, Ekspor, form transaksi
rutin) **tidak** bisa digeser, supaya tidak tergeser tanpa sengaja.

### 3.5 Geser untuk hapus

`AppSwipeActions` mendapat dua parameter baru:

- `borderRadius` (default `null` = sudut siku seperti sekarang). Bila diisi,
  baris dipotong mengikuti radius itu, sehingga bisa dipakai di kartu
  (`AppSurfaceCard`, radius 24) tanpa sudut putih yang mencuat.
- `confirmDelete` (default `true`). Bila `false`, `onDelete` langsung
  dipanggil tanpa dialog bawaan. Ini untuk data yang sudah punya dialog
  sendiri, mis. utang dengan pilihan "kembalikan saldo".

Diterapkan ke:

| Daftar | Edit | Hapus (dialog yang dipakai) |
|---|---|---|
| Utang & Piutang (kartu) | form utang | `_deleteDebt` dari detail, dipindah ke helper bersama `confirmAndDeleteDebt` |
| Target (kartu) | `_showEditSheet` | `_confirmDelete` yang ada |
| Tabungan (kartu grup) | `_showEditSheet` | `_confirmDelete` yang ada |
| Riwayat setor/tarik di Detail Tabungan | `_showEditSheet` | `_confirmDeleteItem` yang ada |
| Transaksi Rutin | `_showAddEditSheet` | `_confirmDelete` yang ada |
| Kelola Kategori (selain kategori bawaan) | `_showInputSheet` | dialog yang ada |
| Investasi (kartu) | — | dialog "Hapus Portofolio" yang ada |

- Ikon pensil dan tong sampah di kartu-kartu tersebut dihapus. Aksinya
  pindah ke geser.
- Investasi: baris "Hapus Portofolio" di lembar opsi dihapus, karena sudah
  ada di geser.
- Detail Utang tetap punya tombol hapus di header (halaman detail).
- Dompet tetap dihapus lewat lembar opsi dompet. Penghapusan dompet punya
  aturan saldo, jadi tidak lewat geseran cepat.
- Kategori bawaan tidak bisa digeser, sama seperti sekarang yang tidak punya
  tombol.

## 4. Pengujian

- **`showAppBottomSheet`:** isian yang fokus kehilangan fokus saat lembar
  dibuka, dan tetap tidak fokus setelah lembar ditutup.
- **`AppTextField`:** border fokus biasa beradius 20.
- **`AppSegmentedControl`:**
  - jalur dan penanda berbentuk kapsul;
  - penanda berada di segmen terpilih;
  - mengikuti `position` pecahan;
  - semantik tetap.
- **`AppSwipeTabs`:**
  - geser kiri pendek → tetap;
  - geser kiri jauh → `onChanged(1)`;
  - fling cepat → pindah;
  - di tab terakhir geser kiri → tetap;
  - geser di atas `AppSwipeActions` → membuka aksi, bukan pindah tab;
  - `position` bergerak selama drag.
- **`AppSwipeActions`:**
  - `borderRadius` memotong sesuai radius;
  - `confirmDelete: false` memanggil `onDelete` tanpa dialog.
- **Layar** (tiap tabel di §3.4 dan §3.5):
  - geser layar pindah tab;
  - geser data membuka Hapus dan memanggil dialog yang benar;
  - tombol pensil/sampah lama tidak ada lagi;
  - tes lama yang mengetuk ikon tersebut diganti dengan geser.
- **Screenshot:** tab kapsul (Transaksi), geser hapus utang (terbuka), isian
  Catatan fokus.
- **Verifikasi penuh:** `flutter analyze` bersih, dan `flutter test` penuh
  termasuk E2E lulus.
