# Aturan Saldo Dompet, Transfer, dan "Buat Dompet" dari Mana Saja — Design

**Tanggal:** 2026-09-28
**Status:** disetujui user di chat (2026-09-28), menunggu review spec tertulis
**Asal:** masukan user setelah mencoba build APK di HP (pasca Phase B).
**Bagian:** 1 dari 2. Bagian 2 (desain ulang Login & Daftar) punya spec sendiri, dimulai dari mockup.

## 1. Tujuan

1. Tidak ada pencatatan yang membuat saldo dompet turun di bawah batasnya.
2. Transfer bisa memilih arah mana pun, juga saat hanya ada 2 dompet.
3. User bisa membuat dompet langsung dari setiap layar yang memilih dompet.

Keberhasilan: semua jalur uang keluar ditolak dengan pesan yang sama saat saldo kurang (terbukti E2E ke Supabase sungguhan); transfer A→B dan B→A bisa dengan 2 dompet; "Dompet Baru" tersedia di semua pemilih dompet dan langsung terpilih setelah dibuat.

## 2. Keputusan user

| Pertanyaan | Keputusan |
|---|---|
| Tagihan rutin jatuh tempo saat saldo kurang | **Tertahan**: tidak dijalankan, tanggal jatuh tempo tetap, otomatis jalan saat saldo cukup; Beranda memberi tahu |
| Batas penolakan | **Saldo minimal = batas keras**: uang keluar ditolak bila sisa saldo < `wallets.min_balance` (0 bila kosong) |
| Pembagian kerja | Bagian 1 (aturan saldo, transfer, buat dompet) lalu Bagian 2 (Login & Daftar, mockup dulu) |

## 3. Aturan saldo (database)

**Definisi.** "Bisa dipakai" dompet = `balance − coalesce(min_balance, 0)`. Uang keluar sebesar *x* ditolak bila *x* > bisa dipakai. Uang masuk tidak pernah ditolak. Dompet yang sudah di bawah batas (data lama) tetap bisa menerima uang masuk.

**Satu fungsi pengecek** di migration baru, dipakai semua RPC uang:
`wallet_spend_guard(p_wallet_id bigint, p_amount numeric)` — mengunci dompet (lewat `lock_wallets`), menolak dompet bukan milik user (`Dompet tidak ditemukan.`), lalu bila `p_amount > 0` dan `p_amount > balance − min_balance` melempar:

> `Saldo dompet <nama> tidak cukup! Bisa dipakai: Rp <jumlah>`

(format rupiah titik ribuan, tanpa desimal). Pesan lama tiap fitur ("Saldo dompet tidak mencukupi!", "Saldo di X tidak cukup!", dst.) diganti pesan tunggal ini; app menampilkan pesan server apa adanya.

**Jalur uang yang memakai pengecek:**

| Jalur | RPC | Status sekarang |
|---|---|---|
| Tambah transaksi pengeluaran | `save_transaction` (baru) | tanpa cek → **ditambah** |
| Edit transaksi (efek bersih ke dompet) | `save_transaction` (edit) | tanpa cek → **ditambah**: yang dicek selisih bersih setelah efek lama dibalik (mis. edit pengeluaran 50K→80K cek 30K; pindah dompet cek penuh di dompet baru; edit pemasukan 100K→10K cek 90K keluar) |
| Hapus pemasukan | `delete_transaction` | tanpa cek → **ditambah** (menghapus pemasukan = uang keluar) |
| Transfer | `transfer_between_wallets` | cek saldo → **+ saldo minimal** |
| Nabung target | `deposit_to_target` | cek saldo → **+ saldo minimal** |
| Setor tabungan | `saving_transaction` | cek saldo → **+ saldo minimal** |
| Edit setoran/tarikan tabungan | `edit_saving_item` | tanpa cek → **ditambah** (selisih bersih) |
| Hapus tarikan tabungan (uang kembali keluar dompet) | `delete_saving_item` | tanpa cek → **ditambah** |
| Beli / top up investasi | `buy_investment`, `buy_sell_investment` | cek saldo → **+ saldo minimal** |
| Zakat / sedekah | `pay_zakat_sedekah` | cek saldo → **+ saldo minimal** |
| Utang & piutang (pinjamkan, bayar utang, ubah, hapus dengan pengembalian) | RPC utang (`debt_move_wallet` dkk.) | cek saldo → **+ saldo minimal** |
| Tagihan rutin otomatis | `run_due_recurring` | tanpa cek → **tertahan** (§4) |

Semua cek terjadi di dalam transaksi database yang sama dengan perubahan saldo (tidak ada baca-lalu-tulis dari app), mengikuti urutan kunci yang sudah ada (tabungan → dompet, target/investasi → dompet).

**App.**
- Peringatan saldo minimal di Tambah Transaksi (`minBalanceWarningMessage`, B3) diganti: server menolak, app menampilkan pesan server sebagai toast error dan sheet/layar tetap terbuka.
- Semua layar menampilkan pesan tolakan server apa adanya (pola `P0001 → pesan` yang sudah ada).
- Setting "Hitung saldo minimal di total saldo" (tampilan total) tidak berubah.

## 4. Tagihan rutin tertahan

- `run_due_recurring`: untuk jadwal pengeluaran yang dompetnya tidak cukup, **tidak** membuat transaksi dan **tidak** memajukan `next_run_date`; jadwal lain tetap diproses. Beberapa periode tertunggak diproses satu per satu sampai saldo habis (sisa tertahan).
- Kolom baru `recurring_transactions.blocked_reason text` (nullable, default null) diisi pesan saldo kurang saat tertahan dan dikosongkan saat jadwal berhasil jalan — dipakai Beranda.
- Beranda: bila ada jadwal tertahan, tampil pemberitahuan "Tagihan <catatan/kategori> belum terbayar — saldo <dompet> kurang" di area ringkasan (komponen `AppCallout`), mengetuknya membuka Tagihan & Pemasukan Rutin.
- Pemasukan rutin tidak pernah tertahan.

## 5. Transfer

Sheet Transfer (Dompet):
- Tombol tukar (ikon ⇅, `AppNavAction.icon`/tile bulat) di antara baris "Dari Dompet (Sumber)" dan "Ke Dompet (Tujuan)".
- Memilih dompet yang sama dengan sisi seberang → kedua sisi ditukar otomatis (tidak ditolak, tidak memunculkan pesan).
- Validasi lama "Dompet asal dan tujuan tidak boleh sama!" tetap ada di server sebagai pengaman.

## 6. "Dompet Baru" di setiap pemilih dompet

- Form Tambah Dompet dari layar Dompet dijadikan fungsi bersama yang bisa dipanggil dari mana saja dan mengembalikan id dompet baru (atau null bila batal).
- Pemilih dompet bersama (`AppWalletSelectRow`, pemilih di Tambah Transaksi, `DebtWalletPicker`, `AppSelectRow` dompet di Tabungan/Target/Tagihan Rutin, sheet Transfer) mendapat baris **"+ Dompet Baru"** di bawah daftar; memilihnya membuka form, lalu dompet baru langsung terpilih dan daftar dompet provider layar itu di-refresh.
- Bila belum ada dompet sama sekali, baris "Belum ada dompet"/"Buat dompet di menu utama!" diganti tombol **"Buat Dompet"** yang langsung membuka form.
- Layar yang tercakup: Tambah Transaksi, Transfer, Buku Tabungan (buat & setor/tarik), Target (nabung), Investasi, Zakat & Sedekah, Utang & Piutang (catat & bayar), Tagihan & Pemasukan Rutin.

## 7. Pengujian

- **E2E Supabase** (file baru `test/e2e/balance_rules_e2e_test.dart`, pola E2E yang ada; data "E2E …" dibersihkan): tiap baris tabel §3 — pas di batas diterima, lewat Rp 1 ditolak dengan pesan tunggal, saldo tidak berubah; dompet dengan `min_balance`; edit & hapus yang mengurangi saldo; tagihan rutin tertahan lalu jalan setelah saldo ditambah; dua operasi bersamaan tidak menembus batas. E2E lama disesuaikan bila pesannya berubah, dan semuanya tetap hijau.
- **Widget test:** tukar arah transfer (tombol ⇅ dan auto-tukar), "+ Dompet Baru" memilih dompet baru, tombol "Buat Dompet" saat kosong, pesan tolakan tampil & sheet tetap terbuka, pemberitahuan tagihan tertahan di Beranda.
- `flutter analyze` 0 error/warning; seluruh test hijau; screenshot layar yang berubah untuk dicek user sebelum merge.

## 8. Di luar cakupan

- Desain ulang Login & Daftar (Bagian 2).
- Mengubah perilaku "Hitung saldo minimal di total saldo".
- Notifikasi push untuk tagihan tertahan (hanya pemberitahuan di Beranda).
