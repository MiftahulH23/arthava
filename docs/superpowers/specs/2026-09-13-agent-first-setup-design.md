# Agent-First Setup for DompetKu — Design Spec

Date: 2026-09-13
Status: Disetujui oleh user, menunggu rencana implementasi

## Context

DompetKu (`catat_uang_app`) adalah aplikasi keuangan pribadi berbasis Flutter +
Supabase. Selanjutnya user ingin berinvestasi pada UI/UX, tetapi terlebih
dahulu ingin repository ini disiapkan agar "agent-first": instruksi baku,
subagent, dan skill agar AI coding agent (Claude Code) dapat bekerja pada
codebase ini secara andal dan konsisten, tanpa perlu menurunkan ulang konteks
proyek di setiap sesi.

Fase ini murni infrastruktur/tooling. Tidak ada kode aplikasi di `lib/` yang
di-refactor dalam pekerjaan ini, kecuali penghapusan tiga skrip legacy yang
sudah dikonfirmasi mati di root repo.

## Current State (observed)

- Aplikasi Flutter, Material3, `google_fonts` (Poppins), `AppColors` kustom.
- Tidak ada library state management — tema menggunakan `ValueNotifier`
  global (`lib/core/theme_mode_manager.dart`); sebagian besar screen berupa
  `StatefulWidget` dengan state lokal dan pemanggilan Supabase langsung.
- `lib/screens/` bersifat flat — 20+ screen, tanpa subfolder widgets/ atau
  features/.
- `lib/models/`, `lib/services/` (`auth_service.dart`, `gemini_service.dart`,
  `pdf_service.dart`) adalah satu-satunya pemisahan di luar screens.
- Backend: Supabase (`supabase_flutter`). Anon key di-hardcode di
  `lib/main.dart` — dapat diterima untuk anon key Supabase SELAMA kebijakan
  RLS sudah di-scope dengan benar, tetapi perlu ditandai ke agent sebagai
  fakta yang diketahui, bukan bug yang harus "diperbaiki" secara diam-diam.
- Tidak ditemukan konfigurasi CI. Tidak ada test suite yang bermakna
  (`test/widget_test.dart` masih berupa test default counter-app Flutter,
  belum disesuaikan dengan aplikasi ini).
- Tiga skrip codegen sekali pakai di root repo sudah mati:
  `update_home_screen.py`, `update_stats.dart`, `update_trx.dart`.
  Dikonfirmasi lewat `git grep` — tidak direferensikan di mana pun. Masing-
  masing adalah skrip mutasi satu tujuan yang transformasinya sudah
  diterapkan ke file target (dikonfirmasi dengan mencocokkan riwayat commit,
  misalnya commit "responsive web layout"). Ketiganya bukan tool yang bisa
  dipakai ulang.

## Goals

1. Memberi setiap sesi agent konteks baku tentang proyek ini lewat
   `AGENTS.md` yang tool-agnostic, sehingga agent tidak perlu menemukan
   ulang struktur/konvensi dari nol setiap kali — dan agar tool selain
   Claude Code (Codex, Cursor, dll.) bisa membaca instruksi yang sama.
2. Menyediakan lima subagent khusus yang sesuai dengan alur kerja nyata
   user: pembuatan UI, code review, kerja Supabase/data, testing, dan
   commit git dengan format conventional-commit.
3. Menyediakan empat skill untuk prosedur berulang yang paling umum:
   menambah fitur/screen, menjalankan+memverifikasi tampilan aplikasi
   secara visual, mengubah skema Supabase dengan aman, dan menyusun
   deskripsi fitur/refactor bebas menjadi spec khusus DompetKu.
4. Menegakkan format Conventional Commits (`feat:`, `fix:`, `chore:`, dll.)
   lewat native git hook `commit-msg`, sehingga riwayat commit tetap
   konsisten terlepas dari siapa/apa yang melakukan commit.
5. Menghapus beban mati (skrip legacy) yang jika dibiarkan bisa membingungkan
   agent yang sedang menjelajahi repo.
6. Semua definisi subagent dan skill ditulis dalam bahasa Inggris (sesuai
   instruksi user), demi portabilitas dan konsistensi. `AGENTS.md` dan
   `CLAUDE.md` juga ditulis dalam bahasa Inggris.
7. Menjaga konvensi yang terdokumentasi (font, ikon, warna) di `AGENTS.md`
   tetap selaras dengan kode lewat kombinasi aturan tertulis dan hook
   pengingat `PostToolUse`, sementara perubahan dependency/library tetap
   selalu memerlukan konfirmasi eksplisit dari user (tidak berubah dari
   perilaku baku yang berlaku).

## Non-Goals

- Tidak ada refactor struktur `lib/` (tidak ada ekstraksi widget, tidak ada
  pengenalan state management, tidak ada pengenalan repository layer).
- Tidak ada perubahan pada cara anon key Supabase dikonfigurasi/disimpan.
- Tidak ada penyiapan pipeline CI/CD (tidak diminta).
- Tidak ada penulisan automated test baru pada fase ini (subagent QA
  bersifat scaffolding untuk penggunaan di masa depan, bukan mandat untuk
  menulis test sekarang).
- Tidak ada otomasi pembuatan PR — subagent commit hanya menangani commit,
  bukan push atau membuka PR (hal itu tetap harus melalui permintaan
  eksplisit dari user, sesuai aturan baku penggunaan tool).

## Design

### 1. `AGENTS.md` (repo root) — instruksi kanonis, tool-agnostic

Ini adalah single source of truth. Tool AI coding apa pun yang mengikuti
konvensi `AGENTS.md` (Claude Code, Codex, Cursor, dll.) membaca file ini
secara langsung.

Bagian-bagian:
- **Project overview**: apa itu DompetKu, tech stack (Flutter, Supabase,
  Gemini AI untuk pemindaian struk/advisory, fl_chart, ekspor pdf/printing).
- **Structure**: penjelasan `lib/core`, `lib/models`, `lib/screens`,
  `lib/services`, serta fakta bahwa screen saat ini masih flat/monolitik
  (dinyatakan sebagai fakta, bukan masalah yang harus diperbaiki).
- **Conventions observed**: Material3 + `ColorScheme.fromSeed`, `AppColors`
  untuk palet, Poppins lewat `google_fonts`, `ValueNotifier<ThemeMode>`
  untuk pergantian tema, locale/format tanggal Indonesia (`id_ID`), penamaan
  file snake_case / class PascalCase (standar Dart).
  - Penamaan file screen: `*_screen.dart` di `lib/screens/`.
  - Model berupa class Dart biasa dengan `fromJson`/`toJson` yang mengikuti
    bentuk tabel Supabase (verifikasi per file, jangan asumsikan ada base
    class bersama).
- **Commands**: `flutter analyze`, `flutter test`, `flutter run -d chrome`
  / `-d windows`, `flutter pub get`.
- **Commit convention**: Conventional Commits (`feat:`, `fix:`, `chore:`,
  `docs:`, `refactor:`, `test:`, `style:`, `perf:`, `build:`, `ci:`),
  ditegakkan oleh git hook `commit-msg` yang dijelaskan di bawah.
- **Known context / do-not-touch-silently**:
  - Anon key Supabase di-hardcode di `lib/main.dart` secara sengaja untuk
    tahap proyek saat ini; jangan "perbaiki" hal ini kecuali diminta secara
    eksplisit.
  - Belum ada CI saat ini; `flutter analyze` + `flutter test` adalah standar
    verifikasi lokal sebelum mengklaim pekerjaan selesai.
- **Pointers to subagents/skills**: tabel satu baris berisi kapan harus
  menggunakan masing-masing dari lima subagent Claude Code dan tiga skill
  yang didefinisikan di bawah (dicatat sebagai khusus Claude Code, karena
  format `.claude/` bukan bagian dari standar lintas-tool `AGENTS.md`).

### 1b. `CLAUDE.md` (repo root) — entry point tipis untuk Claude Code

Hanya berisi:
```
@AGENTS.md
```
ditambah, bila diperlukan, addendum singkat khusus Claude Code (misalnya
menyebutkan secara eksplisit direktori `.claude/agents/` dan
`.claude/skills/` agar routing Claude Code sendiri mendeteksinya — ini
sebenarnya metadata yang sudah otomatis ditemukan oleh Claude Code, jadi
addendum kemungkinan besar hanya berupa baris import tersebut kecuali
pengujian menunjukkan sebaliknya).

### 2. Subagent — `.claude/agents/*.md`

Semua ditulis dalam bahasa Inggris. Setiap file: YAML frontmatter (`name`,
`description`, `tools`) + system prompt body singkat.

- **`flutter-ui-builder`**
  Tujuan: membangun dan mendesain ulang screen/widget agar sesuai dengan
  bahasa visual proyek yang sudah ada (Material3, AppColors, Poppins). Akses
  tool penuh (Read/Write/Edit/Bash) karena perlu menjalankan aplikasi untuk
  verifikasi visual (dipasangkan dengan skill `run-and-screenshot`).
- **`flutter-code-reviewer`**
  Tujuan: mereview diff Dart untuk correctness, null-safety, masalah
  state/rebuild, dan konsistensi dengan pola yang sudah ada pada file yang
  disentuh. Tool read-only (Read/Grep/Glob/Bash untuk `flutter analyze`) —
  tanpa Write/Edit, sehingga tidak bisa "memperbaiki sambil mereview".
- **`supabase-schema-agent`**
  Tujuan: bekerja dengan skema tabel Supabase, RLS, dan model/service Dart
  yang mencerminkannya; menjaga `lib/models/*` dan `lib/services/*` tetap
  selaras dengan perubahan skema. Akses tool penuh.
- **`flutter-qa-writer`**
  Tujuan: menulis widget/unit test untuk screen dan logika Flutter,
  mengikuti konvensi `flutter_test`. Akses tool penuh, dibatasi pada
  `test/` dengan akses baca ke `lib/`.
- **`git-committer`**
  Tujuan: melakukan staging dan commit perubahan dengan pesan Conventional
  Commits yang tersusun baik (type yang benar — `feat`/`fix`/`chore`/`docs`/
  `refactor`/`test`/`style`/`perf`/`build`/`ci` — scope/summary yang ringkas,
  body yang menjelaskan alasan bila tidak jelas dengan sendirinya). Mengikuti
  aturan keamanan git yang sama yang sudah berlaku untuk sesi ini (commit
  baru bukan amend, tanpa `--no-verify`, tidak pernah push tanpa permintaan
  eksplisit, mereview staged diff sebelum commit, HEREDOC untuk pesan
  multi-baris, trailer Co-Authored-By/Claude-Session yang wajib). Tools:
  Bash (pada praktiknya hanya git) + Read untuk inspeksi diff. Subagent ini
  hanya dipanggil saat user meminta commit — tidak melakukan commit secara
  proaktif.

Deskripsi setiap subagent menyatakan dengan jelas kapan ia harus dipanggil,
sehingga routing tidak tumpang tindih (misalnya UI builder tidak mengerjakan
data layer, schema agent tidak menyentuh widget tree kecuali yang diperlukan
untuk menjaga model tetap sinkron, git-committer tidak pernah menulis kode
aplikasi).

### 3. Skill — `.claude/skills/<name>/SKILL.md`

Semua ditulis dalam bahasa Inggris.

- **`add-feature`**: checklist langkah demi langkah untuk menambah
  fitur/screen baru — model → service (pemanggilan Supabase) → screen →
  penyambungan route di `main.dart` atau navigasi → styling sesuai konvensi
  `AppColors`/tema. Ditulis sebagai prosedur yang diikuti oleh
  `flutter-ui-builder` atau sesi umum, bukan sebagai agent tersendiri.
- **`run-and-screenshot`**: prosedur untuk menjalankan aplikasi (memilih
  target: chrome untuk preview web cepat, windows untuk desktop) dan
  menangkap kondisi visual sebelum melaporkan pekerjaan UI selesai —
  mengoperasionalkan panduan sistem "uji golden path di browser" khusus
  untuk proyek ini.
- **`supabase-schema-change`**: prosedur aman untuk mengubah skema
  Supabase — merencanakan migrasi, menerapkannya, memperbarui RLS bila
  perlu, lalu memperbarui model dan service Dart yang sesuai, serta
  mencatat verifikasi manual apa (misalnya pengecekan dashboard Supabase)
  yang masih diperlukan karena sesi ini belum dikonfirmasi memiliki akses
  MCP/DB Supabase langsung.

- **`dompetku-feature-spec`**: digunakan *bersamaan dengan*
  `superpowers:brainstorming` (tidak pernah menggantikannya) setiap kali
  user mendeskripsikan fitur/refactor DompetKu baru dalam bahasa bebas.
  Menambahkan pertanyaan klarifikasi khusus proyek (screen mana, dampak
  terhadap Supabase, keterlibatan Gemini/AI, dampak theming) ke langkah
  pertanyaan klarifikasi milik brainstorming, dan menyusun spec yang
  dihasilkan menjadi bagian Data/UI/Testing yang langsung memetakan ke
  `supabase-schema-agent` / `flutter-ui-builder` / `flutter-qa-writer`.
  Intake spec/fitur dasar itu sendiri (deskripsi bebas → spec terstruktur,
  bertanya saat kurang jelas) sudah ditangani oleh skill
  `superpowers:brainstorming` yang sudah terpasang — skill ini hanya
  menambahkan konten khusus DompetKu ke alur yang sudah ada tersebut.
  **Dokumen** spec yang dihasilkan ditulis dalam Bahasa Indonesia (bahasa
  yang digunakan user untuk membacanya); file skill itu sendiri tetap dalam
  bahasa Inggris seperti semua skill/subagent lain di repo ini.

### 4. Penegakan Conventional Commits — native git hook

Tanpa dependency Node/`package.json` (proyek ini murni Flutter). Sebagai
gantinya:
- `.githooks/commit-msg` — skrip shell POSIX yang memvalidasi baris pertama
  pesan commit terhadap regex Conventional Commits
  (`^(feat|fix|chore|docs|refactor|test|style|perf|build|ci)(\(.+\))?!?: .+`),
  menolak commit dengan pesan error yang jelas + contoh jika tidak cocok.
- Repo dikonfigurasi untuk menggunakan direktori hooks ini:
  `git config core.hooksPath .githooks`.
  Ini adalah langkah setup lokal, sekali jalan (tidak di-commit sebagai
  konfigurasi git global) — didokumentasikan di `AGENTS.md` agar manusia
  atau agent yang menyiapkan repo dari awal tahu harus menjalankannya.
  Tidak dapat diterapkan otomatis hanya dengan clone karena `core.hooksPath`
  adalah konfigurasi lokal, bukan file repo yang otomatis dibaca git demi
  alasan keamanan.
- Hook ini berlaku untuk siapa pun yang melakukan commit (manusia lewat
  IDE/CLI, atau subagent `git-committer`), terlepas dari tool yang dipakai.

### 5. Menjaga `AGENTS.md` tetap sinkron — aturan + reminder hook

Dua lapis agar konvensi yang terdokumentasi (font, set ikon, palet warna)
tidak melenceng dari kode yang sebenarnya:

- **Aturan di `AGENTS.md`** itu sendiri: "Saat mengubah konvensi yang
  terdokumentasi (font, package ikon, palet warna, pendekatan theming),
  perbarui bagian Conventions pada file ini dalam perubahan yang sama.
  Ketika sebuah perubahan mengganti atau menambah library/dependency, hal
  itu sudah memerlukan konfirmasi eksplisit dari user sesuai aturan baku
  penggunaan tool — lakukan itu dulu, baru kemudian perbarui file ini."
- **Hook `PostToolUse`** (`.claude/settings.json`) yang aktif setelah
  Edit/Write pada file yang membawa konvensi — `pubspec.yaml`,
  `lib/core/colors.dart`, `lib/core/theme_mode_manager.dart` — dan
  menyuntikkan pengingat ke konteks: "File ini memengaruhi konvensi yang
  terdokumentasi di AGENTS.md — perbarui jika perubahan ini mengubah
  konvensi font/ikon/warna/tema." Ini adalah nudge, bukan blocker: tidak
  menghentikan proses edit atau memerlukan konfirmasi tersendiri, hanya
  membuat drift jauh lebih kecil kemungkinannya pada sesi yang panjang atau
  dilanjutkan. Perubahan dependency/library tetap terikat oleh aturan
  konfirmasi baku yang sudah ada, tidak terpengaruh oleh hook ini.

### 6. Cleanup

Menghapus (bukan memindahkan) tiga skrip legacy di root:
`update_home_screen.py`, `update_stats.dart`, `update_trx.dart`.
Alasan: sudah dikonfirmasi tidak direferensikan lewat `git grep`, dan
masing-masing adalah skrip mutasi sekali pakai yang sudah diterapkan ke file
targetnya — membiarkannya tetap ada berisiko membuat agent salah mengira
skrip-skrip ini adalah tooling yang bisa dipakai ulang.

## Testing / Verification

Ini adalah perubahan yang murni docs/config (ditambah satu penghapusan).
Verifikasi:
- `flutter analyze` tetap lolos setelah penghapusan skrip (skrip-skrip
  tersebut memang bukan bagian dari target package Dart yang dianalisis,
  tetapi tetap perlu dikonfirmasi tidak ada referensi build yang rusak).
- Konfirmasi secara manual bahwa `.claude/agents/*.md` dan
  `.claude/skills/*/SKILL.md` terbentuk dengan baik (frontmatter valid)
  dengan meminta Claude Code menampilkan daftar agent/skill yang tersedia
  setelah setup.
- Konfirmasi bahwa import `@AGENTS.md` di `CLAUDE.md` benar-benar menarik
  konten (diuji dengan menanyakan sesi Claude Code baru sebuah pertanyaan
  yang hanya bisa dijawab dari konten `AGENTS.md`).
- Menguji hook `commit-msg` secara langsung: setelah menjalankan
  `git config core.hooksPath .githooks`, coba commit dengan pesan yang
  tidak sesuai format (diharapkan ditolak) dan pesan yang sesuai format
  (diharapkan berhasil).

## Open Questions

Tidak ada yang tersisa — semua sudah diselesaikan selama brainstorming.
