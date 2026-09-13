# Rencana Implementasi Agent-First Setup

> **Untuk pekerja agentik:** SUB-SKILL WAJIB: Gunakan superpowers:subagent-driven-development (direkomendasikan) atau superpowers:executing-plans untuk mengimplementasikan rencana ini task demi task. Langkah-langkah menggunakan sintaks checkbox (`- [ ]`) untuk pelacakan.

**Tujuan:** Menjadikan repository DompetKu agent-first: sebuah `AGENTS.md` yang tool-agnostic (diimpor oleh `CLAUDE.md` yang tipis), lima subagent Claude Code, tiga skill, sebuah git hook Conventional-Commits native, sebuah hook pengingat sinkronisasi konvensi, dan penghapusan tiga skrip legacy yang sudah mati.

**Arsitektur:** Perubahan murni dokumentasi/konfigurasi. Tidak ada kode aplikasi `lib/` yang disentuh kecuali menghapus tiga skrip root yang tidak direferensikan. Semua file baru berada di `.claude/agents/`, `.claude/skills/`, `.githooks/`, ditambah `AGENTS.md` dan `CLAUDE.md` di root repo.

**Tech Stack:** Aplikasi Flutter/Dart (tidak terpengaruh), format markdown agent/skill Claude Code, git hook POSIX shell (berjalan lewat `sh` bawaan Git for Windows).

**Spec:** `docs/superpowers/specs/2026-09-13-agent-first-setup-design.md`

## Batasan Global

- Semua konten subagent (`.claude/agents/*.md`) dan skill (`.claude/skills/*/SKILL.md`) ditulis dalam Bahasa Inggris.
- `AGENTS.md` dan `CLAUDE.md` ditulis dalam Bahasa Inggris.
- Tidak ada perubahan pada kode aplikasi `lib/` kecuali dua penghapusan yang tercantum di Task 13 (sudah dikonfirmasi mati).
- Tidak ada dependensi Node/`package.json`/husky — penegakan commit-msg adalah git hook POSIX shell native.
- Tidak ada perubahan pada cara penyimpanan anon key Supabase (di luar cakupan, didokumentasikan sebagai known context saja).
- Subagent `git-committer` harus mengikuti aturan keamanan git yang sudah berlaku untuk sesi ini: commit baru bukan amend, tanpa `--no-verify`, jangan pernah push tanpa permintaan eksplisit, review staged diff sebelum commit, HEREDOC untuk pesan multi-baris, trailer `Co-Authored-By`/`Claude-Session` wajib disertakan.
- Regex Conventional Commits yang digunakan di seluruh rencana ini: `^(feat|fix|chore|docs|refactor|test|style|perf|build|ci)(\([a-z0-9_-]+\))?!?: .+`

---

## Task 1: Git hook Conventional Commits

**Files:**
- Buat: `.githooks/commit-msg`
- Ubah: (hanya konfigurasi git lokal, bukan file) — `core.hooksPath`

**Interfaces:**
- Menghasilkan: hook `commit-msg` yang menegakkan regex Conventional Commits di atas. Semua commit dari task-task berikutnya di rencana ini harus mematuhinya setelah langkah konfigurasi git task ini dijalankan.

- [ ] **Langkah 1: Buat direktori hooks dan skrip**

Buat `.githooks/commit-msg` dengan konten berikut.

```sh
#!/bin/sh
# Enforce Conventional Commits on the first line of the commit message.
# Format: type(optional-scope)!: summary
# Allowed types: feat fix chore docs refactor test style perf build ci

commit_msg_file="$1"
first_line=$(head -n 1 "$commit_msg_file")

pattern='^(feat|fix|chore|docs|refactor|test|style|perf|build|ci)(\([a-z0-9_-]+\))?!?: .+'

if ! echo "$first_line" | grep -qE "$pattern"; then
  echo "commit-msg hook: commit message does not follow Conventional Commits." >&2
  echo "" >&2
  echo "  Got:      $first_line" >&2
  echo "  Expected: <type>(optional-scope): <summary>" >&2
  echo "  Types:    feat fix chore docs refactor test style perf build ci" >&2
  echo "  Example:  feat(auth): add biometric lock screen" >&2
  exit 1
fi

exit 0
```

- [ ] **Langkah 2: Jadikan hook executable dan daftarkan hooks path**

Jalankan:
```bash
chmod +x .githooks/commit-msg
git config core.hooksPath .githooks
```

- [ ] **Langkah 3: Uji hook menolak pesan yang buruk**

Jalankan:
```bash
git commit --allow-empty -m "this is not conventional"
```
Ekspektasi: perintah gagal, stderr menampilkan error `commit-msg hook:` di atas, tidak ada commit yang terbuat (`git log -1` masih menampilkan commit sebelumnya).

- [ ] **Langkah 4: Uji hook menerima pesan yang baik**

Jalankan:
```bash
git commit --allow-empty -m "chore: verify commit-msg hook"
```
Ekspektasi: commit berhasil. Kemudian batalkan commit uji kosong ini agar tidak mengotori history:
```bash
git reset --soft HEAD~1
```

- [ ] **Langkah 5: Commit hook itu sendiri**

```bash
git add .githooks/commit-msg
git commit -m "chore(git): add Conventional Commits commit-msg hook"
```

---

## Task 2: `AGENTS.md` — instruksi kanonik proyek

**Files:**
- Buat: `AGENTS.md`

**Interfaces:**
- Menghasilkan: file instruksi kanonik yang direferensikan oleh subagent/skill di semua task berikutnya melalui pointer (file-file Task 5-12 menautkan kembali ke bagian `AGENTS.md` yang relevan berdasarkan nama, bukan nomor baris, karena file ini akan terus berevolusi).

- [ ] **Langkah 1: Buat `AGENTS.md`**

```markdown
# AGENTS.md — DompetKu

Instructions for any AI coding agent (Claude Code, Codex, Cursor, etc.)
working in this repository. This file is the canonical source of truth;
`CLAUDE.md` just imports it for Claude Code.

## Project Overview

DompetKu (package name `catat_uang_app`) is a personal finance tracker
built with Flutter, backed by Supabase (Postgres + Auth). Features
include transactions, wallets, budgets, savings, targets, debts,
recurring transactions, a financial calendar, PDF export, biometric
lock, and an AI advisor / receipt scanner powered by Google Gemini
(`google_generative_ai`).

## Structure

- `lib/main.dart` — app entry point, Supabase init, theme setup, initial
  route decision (login vs. lock vs. home based on session state).
- `lib/core/` — cross-cutting concerns: `colors.dart` (palette),
  `theme_mode_manager.dart` (global `ValueNotifier<ThemeMode>`),
  `app_notification.dart`.
- `lib/models/` — plain Dart data classes, one per Supabase table
  concept, each with a `fromJson` factory matching that table's shape.
  There is no shared base model class — verify each model's own JSON
  keys rather than assuming a common pattern.
- `lib/screens/` — one file per screen, flat (no subfolders). Screens
  are `StatefulWidget`s that call services/Supabase directly; there is
  currently no repository or state-management layer between UI and
  data access. This is the existing pattern — follow it rather than
  introducing a new architecture unprompted.
- `lib/services/` — thin wrappers around Supabase/external APIs
  (`auth_service.dart`, `gemini_service.dart`, `pdf_service.dart`).

## Conventions

- **Theming:** Material 3, `ColorScheme.fromSeed(seedColor: AppColors.primary)`,
  light/dark switched via the global `themeNotifier` in
  `lib/core/theme_mode_manager.dart` (call `toggleTheme(bool isDark)` to
  change it — don't invent a second theme-switching mechanism).
- **Colors:** all named colors come from `AppColors` in `lib/core/colors.dart`.
  Don't hardcode hex colors in screens/widgets — add a new named constant
  to `AppColors` instead.
- **Font:** `google_fonts` Poppins (`GoogleFonts.poppinsTextTheme(...)`),
  applied once in `main.dart`'s `ThemeData.textTheme`.
- **Icons:** `phosphor_flutter`.
- **Locale:** Indonesian (`id_ID`) date/number formatting via `intl` and
  `initializeDateFormatting('id_ID', null)` in `main.dart`.
- **File naming:** `snake_case.dart` files, `*_screen.dart` for screens,
  `*_model.dart` for models, `*_service.dart` for services. Classes are
  `PascalCase` (standard Dart).
- **Commit messages:** Conventional Commits — `feat`, `fix`, `chore`,
  `docs`, `refactor`, `test`, `style`, `perf`, `build`, `ci`, optionally
  scoped: `feat(wallet): add transfer confirmation dialog`. Enforced by
  the `commit-msg` git hook — see "Git Hooks" below.

### Keeping this file in sync

When you change a documented convention above (font, icon package,
color palette, theming approach), update the relevant bullet in this
Conventions section as part of the same change/commit.

When a change would swap or add a library/dependency (e.g. replacing
`phosphor_flutter`, changing the font package), that already requires
explicit user confirmation under standing tool-use rules for
hard-to-reverse changes — get that confirmation first, then update this
file to match what was approved.

## Commands

- `flutter pub get` — install dependencies.
- `flutter analyze` — static analysis; run before claiming any Dart
  change is complete.
- `flutter test` — run the test suite.
- `flutter run -d chrome` — run as a web app (fastest way to visually
  verify UI changes).
- `flutter run -d windows` — run as a Windows desktop app.

## Git Hooks

This repo enforces Conventional Commits via a native git hook (no
Node/husky dependency). One-time local setup after cloning:

```bash
git config core.hooksPath .githooks
```

`core.hooksPath` is a local git config value, not a tracked file, so
this step doesn't happen automatically on clone — run it once per
machine/clone.

## Known Context

- The Supabase anon key is hardcoded in `lib/main.dart`. This is
  acceptable for a Supabase anon key as long as Row Level Security
  policies are correctly scoped server-side — it is not a bug to
  silently "fix" by moving it to an env file; leave it unless
  explicitly asked to change it.
- There is no CI pipeline currently. `flutter analyze` and `flutter
  test` are the local verification bar before reporting work as done.

## Claude Code Subagents & Skills

These directories are specific to Claude Code (other tools reading this
`AGENTS.md` can ignore this section):

| Name | Kind | Use when |
|---|---|---|
| `flutter-ui-builder` | subagent | Building or redesigning a screen/widget to match the existing visual language. |
| `flutter-code-reviewer` | subagent | Reviewing a Dart diff for correctness, null-safety, state/rebuild issues. |
| `supabase-schema-agent` | subagent | Changing Supabase schema/RLS and keeping Dart models/services in sync. |
| `flutter-qa-writer` | subagent | Writing widget/unit tests. |
| `git-committer` | subagent | Committing staged changes with a correct Conventional Commit message. |
| `add-feature` | skill | Adding a new feature/screen end-to-end. |
| `run-and-screenshot` | skill | Launching the app and visually verifying a UI change. |
| `supabase-schema-change` | skill | Safely changing Supabase schema and syncing Dart code. |
| `dompetku-feature-spec` | skill | Alongside brainstorming, when the user describes a new feature/refactor in free-form language. |
```

- [ ] **Langkah 2: Verifikasi bagian-bagian yang diperlukan sudah ada**

Jalankan:
```bash
grep -c "^## " AGENTS.md
```
Ekspektasi: `7` (Project Overview, Structure, Conventions, Commands, Git Hooks, Known Context, Claude Code Subagents & Skills — heading "Keeping this file in sync" tidak dihitung karena merupakan heading level-3 `###`). Jika angkanya berbeda, konfirmasi bahwa setiap bagian yang tercantum di Langkah 1 ada melalui `grep "^## " AGENTS.md`.

- [ ] **Langkah 3: Commit**

```bash
git add AGENTS.md
git commit -m "docs: add AGENTS.md canonical project instructions"
```

---

## Task 3: `CLAUDE.md` — import tipis untuk Claude Code

**Files:**
- Buat: `CLAUDE.md`

**Interfaces:**
- Mengonsumsi: `AGENTS.md` (Task 2) melalui sintaks import `@path` milik Claude Code.

- [ ] **Langkah 1: Buat `CLAUDE.md`**

```markdown
@AGENTS.md
```

- [ ] **Langkah 2: Verifikasi import ter-resolve**

Ajukan pertanyaan baru dalam sesi Claude Code yang sama, yang hanya bisa
dijawab dari konten `AGENTS.md`, misalnya "What icon package does this
project use?" Jawaban yang diharapkan: `phosphor_flutter`, bersumber dari
file yang diimpor. (Langkah ini adalah verifikasi manual selama eksekusi
rencana — tidak ada perintah otomatis untuk ini.)

- [ ] **Langkah 3: Commit**

```bash
git add CLAUDE.md
git commit -m "chore: add CLAUDE.md importing AGENTS.md"
```

---

## Task 4: Hook pengingat sinkronisasi konvensi

**Files:**
- Buat: `.claude/settings.json`

**Interfaces:**
- Menghasilkan: hook `PostToolUse` yang mencocokkan Edit/Write pada
  `pubspec.yaml`, `lib/core/colors.dart`, `lib/core/theme_mode_manager.dart`
  yang menampilkan pengingat untuk memperbarui `AGENTS.md`.

- [ ] **Langkah 1: Buat `.claude/settings.json`**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "case \"$CLAUDE_TOOL_INPUT_FILE_PATH\" in *pubspec.yaml|*lib/core/colors.dart|*lib/core/theme_mode_manager.dart) echo 'Reminder: this file backs a documented convention in AGENTS.md (font/icon/color/theme). If this change alters that convention, update AGENTS.md in the same commit.' >&2 ;; esac"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Langkah 2: Verifikasi hook terpicu**

Lakukan edit whitespace sepele pada `lib/core/colors.dart` (misalnya
tambahkan lalu hapus baris kosong lewat Edit tool) dan konfirmasi teks
pengingat muncul di output tool. Kembalikan edit sepele tersebut jika
meninggalkan diff:
```bash
git checkout -- lib/core/colors.dart
```

- [ ] **Langkah 3: Commit**

```bash
git add .claude/settings.json
git commit -m "chore: add AGENTS.md convention-sync reminder hook"
```

---

## Task 5: Subagent `flutter-ui-builder`

**Files:**
- Buat: `.claude/agents/flutter-ui-builder.md`

- [ ] **Langkah 1: Buat file subagent**

```markdown
---
name: flutter-ui-builder
description: Use when building a new screen/widget or redesigning an existing one in the DompetKu Flutter app, so the result matches the project's existing visual language (Material 3, AppColors, Poppins, Phosphor icons). Examples: "add a new screen for X", "redesign the wallet screen", "make the stats screen responsive".
tools: Read, Write, Edit, Bash, Glob, Grep
---

You build and redesign UI for the DompetKu Flutter app. Read `AGENTS.md`
at the repo root first (via `@AGENTS.md` import in `CLAUDE.md`, already
in your context) for project conventions before making changes.

Rules specific to your role:

- Match existing patterns: check 1-2 similar screens in `lib/screens/`
  before writing new UI, and follow their structure (StatefulWidget
  shape, AppBar style, spacing, card styling).
- Use `AppColors` (`lib/core/colors.dart`) for all colors — never
  hardcode a hex value. If a needed color doesn't exist yet, add a named
  constant to `AppColors` and note that in your summary.
- Use `phosphor_flutter` icons, not `Icons.*`, unless the surrounding
  file already uses `Icons.*` consistently (match the file you're
  editing).
- Respect the global theme: don't introduce a second theming mechanism
  alongside `themeNotifier`.
- Do not add a state management package (Provider/Riverpod/Bloc) or a
  repository/data layer — the project's current pattern is direct
  Supabase calls from StatefulWidgets. If you believe that pattern is
  actively blocking the task, say so and ask before introducing a new
  architecture.
- After UI changes, use the `run-and-screenshot` skill to visually
  verify the result before reporting the task done — don't rely on
  `flutter analyze` passing as proof the UI looks right.
- Do not touch Supabase schema or service-layer query logic — that's
  `supabase-schema-agent`'s job. If a UI task needs new data, ask for
  that agent or note the dependency.
```

- [ ] **Langkah 2: Verifikasi frontmatter valid**

Jalankan:
```bash
head -n 5 .claude/agents/flutter-ui-builder.md
```
Ekspektasi: menampilkan `---`, `name: flutter-ui-builder`, `description: ...`, `tools: ...`, `---` dalam urutan tersebut.

- [ ] **Langkah 3: Commit**

```bash
git add .claude/agents/flutter-ui-builder.md
git commit -m "chore(agents): add flutter-ui-builder subagent"
```

---

## Task 6: Subagent `flutter-code-reviewer`

**Files:**
- Buat: `.claude/agents/flutter-code-reviewer.md`

- [ ] **Langkah 1: Buat file subagent**

```markdown
---
name: flutter-code-reviewer
description: Use when reviewing a Dart diff in this repo for correctness, null-safety, state/rebuild issues, and consistency with existing patterns — before committing or when explicitly asked to review. Examples: "review my changes to wallet_screen.dart", "check this diff before I commit".
tools: Read, Grep, Glob, Bash
---

You review Dart/Flutter diffs in the DompetKu app. You do not edit
files — you only report findings. Read `AGENTS.md` for project
conventions first.

Review focus, in priority order:

1. **Correctness bugs**: null-safety violations, off-by-one, incorrect
   `fromJson` key mapping against the actual Supabase column names used
   elsewhere in the same model file, unhandled `Future` errors on
   Supabase calls.
2. **State/rebuild issues**: `setState` called after `dispose`, missing
   `mounted` checks after an `await` before touching `context` or
   calling `setState`, `ValueNotifier`/`themeNotifier` misuse.
3. **Consistency**: does the diff match the patterns in neighboring
   files (naming, `AppColors` usage instead of hardcoded hex, Phosphor
   icons, file/class naming conventions from `AGENTS.md`)?
4. **Simplification/reuse**: only flag when clearly beneficial — this
   codebase favors direct, explicit code over abstraction; don't push
   for a repository layer or state management package that doesn't
   exist here.

Run `flutter analyze` as part of your review and include any new
warnings/errors it surfaces on the changed files.

Report findings as a plain list: file, line, what's wrong, why it
matters, suggested fix — you don't apply fixes yourself.
```

- [ ] **Langkah 2: Verifikasi frontmatter valid**

Jalankan:
```bash
head -n 5 .claude/agents/flutter-code-reviewer.md
```
Ekspektasi: blok frontmatter valid seperti pada Task 5 Langkah 2.

- [ ] **Langkah 3: Commit**

```bash
git add .claude/agents/flutter-code-reviewer.md
git commit -m "chore(agents): add flutter-code-reviewer subagent"
```

---

## Task 7: Subagent `supabase-schema-agent`

**Files:**
- Buat: `.claude/agents/supabase-schema-agent.md`

- [ ] **Langkah 1: Buat file subagent**

```markdown
---
name: supabase-schema-agent
description: Use when changing Supabase table schema, RLS policies, or queries, and keeping the corresponding Dart models (lib/models/) and services (lib/services/) in sync. Examples: "add a new column to transactions", "add a table for recurring reminders", "the wallet model is missing a field the DB has".
tools: Read, Write, Edit, Bash, Glob, Grep
---

You work on the Supabase-backed data layer of DompetKu: schema, RLS, and
the Dart models/services that mirror them. Read `AGENTS.md` first.

Rules specific to your role:

- This session has no confirmed direct Supabase database/MCP access.
  Treat schema changes (DDL, RLS policy edits) as something you draft
  and hand to the user to apply via the Supabase dashboard/CLI, unless
  a Supabase tool is actually available in this session — check before
  assuming.
- When a table's shape changes, update every Dart model in
  `lib/models/` that maps to it: match `fromJson` keys to actual column
  names exactly (snake_case JSON keys are normal — see
  `TransactionModel.fromJson` for the existing pattern).
- Update `lib/services/*.dart` query code that selects/inserts/updates
  the affected table so it matches the new shape.
- Never change `lib/main.dart`'s Supabase init (URL/anon key) as a side
  effect of schema work — that's explicitly out of scope per
  `AGENTS.md`'s Known Context section.
- Follow the `supabase-schema-change` skill's procedure for the full
  sequence (plan → apply → RLS → sync models/services → note manual
  verification needed).
```

- [ ] **Langkah 2: Verifikasi frontmatter valid**

Jalankan:
```bash
head -n 5 .claude/agents/supabase-schema-agent.md
```
Ekspektasi: blok frontmatter valid.

- [ ] **Langkah 3: Commit**

```bash
git add .claude/agents/supabase-schema-agent.md
git commit -m "chore(agents): add supabase-schema-agent subagent"
```

---

## Task 8: Subagent `flutter-qa-writer`

**Files:**
- Buat: `.claude/agents/flutter-qa-writer.md`

- [ ] **Langkah 1: Buat file subagent**

```markdown
---
name: flutter-qa-writer
description: Use when writing widget or unit tests for DompetKu screens, models, or services. Examples: "write a test for the budget screen", "add unit tests for TransactionModel.fromJson".
tools: Read, Write, Edit, Bash, Glob, Grep
---

You write Flutter tests for DompetKu using `flutter_test`. Read
`AGENTS.md` first for project structure and conventions.

Rules specific to your role:

- Tests live under `test/`, mirroring the `lib/` path being tested
  (e.g. a test for `lib/models/transaction_model.dart` goes in
  `test/models/transaction_model_test.dart`).
- For widget tests that depend on Supabase, don't make real network
  calls — this codebase has no existing mocking convention, so check
  whether a fake/mock is feasible for the specific unit under test
  (e.g. `TransactionModel.fromJson` is pure and easy to unit test
  without Supabase; a full screen widget test that calls Supabase
  directly in `initState` may not be — flag that limitation rather than
  writing a flaky test).
- Prefer testing pure logic (model parsing, calculations like totals/
  budgets) over widget trees when a screen has heavy direct Supabase
  coupling, since that yields more reliable, faster tests.
- Run `flutter test <path>` after writing a test and report actual
  pass/fail output — never claim a test passes without running it.
- Do not modify application code in `lib/` to make a test pass unless
  the test reveals an actual bug — then say so explicitly rather than
  silently changing production code.
```

- [ ] **Langkah 2: Verifikasi frontmatter valid**

Jalankan:
```bash
head -n 5 .claude/agents/flutter-qa-writer.md
```
Ekspektasi: blok frontmatter valid.

- [ ] **Langkah 3: Commit**

```bash
git add .claude/agents/flutter-qa-writer.md
git commit -m "chore(agents): add flutter-qa-writer subagent"
```

---

## Task 9: Subagent `git-committer`

**Files:**
- Buat: `.claude/agents/git-committer.md`

- [ ] **Langkah 1: Buat file subagent**

```markdown
---
name: git-committer
description: Use when the user explicitly asks to commit staged or working-tree changes in this repo with a well-formed Conventional Commit message. Do not invoke proactively or speculatively — only on explicit request to commit. Examples: "commit this", "commit these changes as a fix".
tools: Read, Bash
---

You create git commits for DompetKu with correct Conventional Commits
messages. You are only ever invoked when the user has explicitly asked
for a commit — never commit proactively.

Process:

1. Run `git status` and `git diff` (staged and unstaged) to see what
   would be committed. If nothing is staged, review the working tree
   diff and stage the specific files relevant to the request by name
   (never `git add -A` or `git add .` blindly) — check for anything
   that looks like a secret or credential in an otherwise innocuous
   file before staging it.
2. Pick the correct Conventional Commit type: `feat` (new capability),
   `fix` (bug fix), `chore` (tooling/config/maintenance, no app
   behavior change), `docs` (documentation only), `refactor` (no
   behavior change), `test` (tests only), `style` (formatting only),
   `perf` (performance), `build` (build system/dependencies), `ci`
   (CI config). Add a scope in parentheses when it's obviously useful
   (e.g. `feat(wallet): ...`), otherwise omit it.
3. Write a message whose first line matches
   `^(feat|fix|chore|docs|refactor|test|style|perf|build|ci)(\([a-z0-9_-]+\))?!?: .+`
   — this repo's `commit-msg` hook rejects anything else. Keep the
   summary under ~72 chars, imperative mood ("add", not "added").
   Add a body only when the *why* isn't obvious from the diff.
4. Commit via a HEREDOC so multi-line messages are formatted correctly,
   always ending with the required trailer lines for this session:
   ```
   Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
   Claude-Session: <the session URL, if known in this context>
   ```
5. Always create a new commit — never `git commit --amend` unless the
   user explicitly asked to amend. Never pass `--no-verify` or any flag
   that bypasses the `commit-msg` hook. Never `git push` unless
   explicitly asked to push, and that is a separate request from "commit
   this".
6. After committing, run `git status` to confirm a clean result and
   report the commit hash and message back to the user.
```

- [ ] **Langkah 2: Verifikasi frontmatter valid**

Jalankan:
```bash
head -n 5 .claude/agents/git-committer.md
```
Ekspektasi: blok frontmatter valid.

- [ ] **Langkah 3: Commit**

```bash
git add .claude/agents/git-committer.md
git commit -m "chore(agents): add git-committer subagent"
```

---

## Task 10: Skill `add-feature`

**Files:**
- Buat: `.claude/skills/add-feature/SKILL.md`

- [ ] **Langkah 1: Buat file skill**

```markdown
---
name: add-feature
description: Use when adding a new feature or screen to DompetKu end-to-end (model, service, screen, navigation, styling), so nothing is missed and the result follows existing project conventions.
---

# Adding a Feature/Screen to DompetKu

Checklist for adding a new feature end-to-end. Read `AGENTS.md` first
for conventions (colors, icons, font, naming, file locations).

1. **Model** (if the feature needs new data): add
   `lib/models/<name>_model.dart` with a plain Dart class and a
   `fromJson` factory matching the actual Supabase column names. Look at
   `lib/models/transaction_model.dart` as the reference shape (no shared
   base class — this is a from-scratch file each time).
2. **Service** (if the feature needs new Supabase calls): add methods to
   an existing `lib/services/*.dart` file if the feature is closely
   related to one (e.g. wallet-related additions go in a wallet
   service), or create a new `lib/services/<name>_service.dart`
   following the shape of `lib/services/auth_service.dart` — a class
   wrapping `Supabase.instance.client` calls, one clear method per
   operation.
3. **Screen**: add `lib/screens/<name>_screen.dart`. Check 1-2 similar
   existing screens first and match their structure (StatefulWidget,
   AppBar style, spacing, card styling). Use `AppColors` for colors,
   `phosphor_flutter` for icons, `GoogleFonts` text theme already
   applied globally (don't re-apply font per-widget).
4. **Navigation**: wire the screen into `lib/main.dart`'s routing or
   into the relevant parent screen's navigation call
   (`Navigator.push(...)`), matching how existing screens are opened.
5. **Verify**: use the `run-and-screenshot` skill to visually confirm
   the new screen before reporting done. Run `flutter analyze` and fix
   any new warnings/errors on the files you touched.
6. **Test** (optional, ask the user if unclear): if the feature has
   non-trivial pure logic (calculations, parsing), consider the
   `flutter-qa-writer` subagent for unit tests.
7. **Commit**: if asked to commit, use the `git-committer` subagent
   (or follow the same Conventional Commits format manually) —
   `feat(<scope>): <summary>` is the usual type for a new feature.
```

- [ ] **Langkah 2: Verifikasi frontmatter valid**

Jalankan:
```bash
head -n 4 .claude/skills/add-feature/SKILL.md
```
Ekspektasi: `---`, `name: add-feature`, `description: ...`, `---`.

- [ ] **Langkah 3: Commit**

```bash
git add .claude/skills/add-feature/SKILL.md
git commit -m "chore(skills): add add-feature skill"
```

---

## Task 11: Skill `run-and-screenshot`

**Files:**
- Buat: `.claude/skills/run-and-screenshot/SKILL.md`

- [ ] **Langkah 1: Buat file skill**

```markdown
---
name: run-and-screenshot
description: Use when a UI change in DompetKu needs to be visually verified before reporting it done — launches the app and captures its visual state.
---

# Run & Visually Verify DompetKu

Never claim a UI change looks right without seeing it rendered. Use this
procedure before reporting UI work complete.

1. **Pick a target.** `flutter run -d chrome` is the fastest path to a
   visual check (renders as a normal web page, works with browser
   automation). Use `flutter run -d windows` only when the change is
   platform-specific to desktop behavior chrome can't exercise (e.g.
   window sizing, native file dialogs).
2. **Launch it** in the background so you can keep working:
   ```bash
   flutter run -d chrome --web-port=8765
   ```
   Wait for the "Flutter run key commands" banner and the app URL in
   the output before trying to interact with it.
3. **Navigate and capture.** If the `claude-in-chrome` skill/tools are
   available in this session, use them to open the app URL, navigate to
   the changed screen, and take a screenshot. If browser automation
   isn't available, ask the user to look at the running app and
   describe or screenshot what they see — don't guess at the visual
   result from code alone.
4. **Check the golden path and one edge case** relevant to the change
   (e.g. empty state, long text, dark mode via the app's theme toggle)
   — not just the happy path.
5. **Stop the app** when done verifying (Ctrl+C / stop the background
   process) rather than leaving it running.
6. **Report honestly.** If you could not actually view the rendered UI
   (no browser automation, no screenshot), say so explicitly instead of
   claiming the change was visually verified.
```

- [ ] **Langkah 2: Verifikasi frontmatter valid**

Jalankan:
```bash
head -n 4 .claude/skills/run-and-screenshot/SKILL.md
```
Ekspektasi: `---`, `name: run-and-screenshot`, `description: ...`, `---`.

- [ ] **Langkah 3: Commit**

```bash
git add .claude/skills/run-and-screenshot/SKILL.md
git commit -m "chore(skills): add run-and-screenshot skill"
```

---

## Task 12: Skill `supabase-schema-change`

**Files:**
- Buat: `.claude/skills/supabase-schema-change/SKILL.md`

- [ ] **Langkah 1: Buat file skill**

```markdown
---
name: supabase-schema-change
description: Use when changing Supabase table schema or RLS policies for DompetKu and keeping the Dart models/services in sync — a safe, ordered procedure so nothing drifts out of sync.
---

# Changing Supabase Schema Safely

This session has no confirmed direct Supabase database/MCP access —
verify whether one is available before assuming; if not, schema changes
are drafted here and applied manually by the user.

1. **Plan the change.** Write out the exact DDL (new/changed
   column/table) and, if relevant, the RLS policy needed for it. State
   which existing tables/columns it affects.
2. **Apply it.** If a Supabase tool/MCP is available in this session,
   use it. Otherwise, hand the DDL/RLS SQL to the user to run via the
   Supabase SQL editor or CLI, and wait for confirmation it was applied
   before continuing to step 3.
3. **Update RLS** if the change affects row visibility/ownership (e.g.
   a new table needs a `user_id`-scoped policy matching the pattern
   used by existing tables).
4. **Sync Dart models.** Update every `lib/models/*.dart` file that
   maps to the changed table: match `fromJson` keys to the exact new
   column names (snake_case JSON keys, per existing models like
   `TransactionModel`).
5. **Sync Dart services.** Update `lib/services/*.dart` query code
   (select/insert/update column lists) to match the new shape.
6. **Note manual verification still needed** — e.g. "check the
   Supabase dashboard to confirm the RLS policy was applied as written"
   — since this session may not be able to verify the live database
   state directly.
7. **Verify locally.** Run `flutter analyze` on the changed Dart files.
   If any screen reads the changed model, spot-check it compiles and,
   where feasible, use `run-and-screenshot` to confirm the screen still
   renders with the new shape.
```

- [ ] **Langkah 2: Verifikasi frontmatter valid**

Jalankan:
```bash
head -n 4 .claude/skills/supabase-schema-change/SKILL.md
```
Ekspektasi: `---`, `name: supabase-schema-change`, `description: ...`, `---`.

- [ ] **Langkah 3: Commit**

```bash
git add .claude/skills/supabase-schema-change/SKILL.md
git commit -m "chore(skills): add supabase-schema-change skill"
```

---

## Task 13: Skill `dompetku-feature-spec`

**Files:**
- Buat: `.claude/skills/dompetku-feature-spec/SKILL.md`

**Interfaces:**
- Mengonsumsi: `superpowers:brainstorming` (skill plugin eksternal, sudah
  terpasang) — skill ini memperluasnya, tidak pernah menggantikannya.
- Mengonsumsi (berdasarkan nama, bukan tautan file): nama subagent
  `supabase-schema-agent`, `flutter-ui-builder`, `flutter-qa-writer`
  (Task 5, 7, 8) untuk pemetaan spec Data/UI/Testing.

- [ ] **Langkah 1: Buat file skill**

```markdown
---
name: dompetku-feature-spec
description: Use alongside superpowers:brainstorming whenever the user describes a new DompetKu feature or refactor in free-form language. Adds DompetKu-specific clarifying questions, writes the resulting spec document in Bahasa Indonesia, and structures it so flutter-ui-builder, supabase-schema-agent, and other subagents can act on it directly. Never use instead of brainstorming — only to extend its clarifying-questions and design-presentation steps for this repo.
---

# DompetKu Feature/Refactor Spec Intake

Extends `superpowers:brainstorming` for this repo. Follow brainstorming's
own process in full (classify spike/bounded/architectural, ask one
question at a time, propose approaches, present design, get approval,
write the spec to `docs/superpowers/specs/`) — this skill only adds what
to ask and how to structure the output for DompetKu specifically. It is
never a substitute for brainstorming's approval gate.

## Additional clarifying questions to weave in

Ask these one at a time, only the ones relevant to what the user
described — don't ask all of them mechanically, and don't ask ones
brainstorming's own questions already answered:

- **Screens touched**: which existing screen(s) in `lib/screens/` does
  this affect, or is it a new screen entirely?
- **Data**: does this need a new Supabase table/column, or does it reuse
  existing data? If new/changed schema, note that `supabase-schema-agent`
  and the `supabase-schema-change` skill will be needed during
  implementation.
- **AI/Gemini involvement**: does this feature need `gemini_service.dart`
  (receipt scanning, advisory) or is it pure CRUD?
- **Cross-cutting conventions**: does this affect theming/colors/icons
  (see `AGENTS.md` Conventions)? If so, note it explicitly so the
  resulting work updates `AGENTS.md` per its sync rule.
- **Scope boundary**: is this additive (new screen/feature) or does it
  change behavior of an existing screen (refactor)? For a refactor, ask
  explicitly what should NOT change, to avoid scope creep during
  implementation.

## Language of the spec output

Write the spec document itself (the file saved to
`docs/superpowers/specs/`) in **Bahasa Indonesia** — that's what the user
reads. This applies to the spec's prose: headings, requirements,
rationale. Keep code identifiers, file paths, and technical terms
(class/method names, package names) as-is/untranslated inside that
Indonesian prose, the same way you would in a normal Indonesian
technical document. This is specific to specs produced via this skill —
it does not change the language of `AGENTS.md`, subagent files, or
skill files themselves, which stay in English.

## Structuring the spec for this repo's subagents

When brainstorming reaches its "Present the design" / spec-writing step,
structure the design into sections that map cleanly onto this repo's
subagents:

- A **Data** section (Supabase schema + model/service changes) — feeds
  `supabase-schema-agent`.
- A **UI** section (screens/widgets, styling) — feeds `flutter-ui-builder`.
- A **Testing** section (what's worth testing given existing patterns)
  — feeds `flutter-qa-writer`.

A section can be empty/omitted when the feature genuinely doesn't touch
that area (e.g. a pure UI tweak has no Data section) — don't pad the spec
with empty headings.

This mapping doesn't change brainstorming's spec file location or format
(`docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`) — it just makes
sure the spec reads as separable, actionable pieces once implementation
begins.

If anything the user said is ambiguous or conflicts with an existing
`AGENTS.md` convention, ask about it explicitly rather than guessing —
this is the same rule brainstorming already follows; this skill exists
to make sure DompetKu-specific ambiguity isn't overlooked.
```

- [ ] **Langkah 2: Verifikasi frontmatter valid**

Jalankan:
```bash
head -n 4 .claude/skills/dompetku-feature-spec/SKILL.md
```
Ekspektasi: `---`, `name: dompetku-feature-spec`, `description: ...`, `---`.

- [ ] **Langkah 3: Commit**

```bash
git add .claude/skills/dompetku-feature-spec/SKILL.md
git commit -m "chore(skills): add dompetku-feature-spec skill"
```

---

## Task 14: Hapus skrip legacy yang sudah mati

**Files:**
- Hapus: `update_home_screen.py`
- Hapus: `update_stats.dart`
- Hapus: `update_trx.dart`

**Interfaces:**
- Tidak ada — file-file ini tidak memiliki referensi masuk (sudah
  dikonfirmasi melalui `git grep` saat riset spec).

- [ ] **Langkah 1: Konfirmasi ulang tidak ada referensi**

Jalankan:
```bash
git grep -n "update_home_screen\|update_stats\|update_trx" -- . ':!update_home_screen.py' ':!update_stats.dart' ':!update_trx.dart'
```
Ekspektasi: tidak ada output (kosong). Jika sekarang muncul hasil yang
cocok, berhenti dan investigasi dulu sebelum menghapus — jangan
lanjutkan penghapusan.

- [ ] **Langkah 2: Hapus file-file tersebut**

```bash
git rm update_home_screen.py update_stats.dart update_trx.dart
```

- [ ] **Langkah 3: Verifikasi `flutter analyze` tetap lolos**

Jalankan:
```bash
flutter analyze
```
Ekspektasi: tidak ada error baru terkait file yang dihapus (file-file
tersebut memang tidak pernah menjadi bagian dari graph paket Dart yang
dianalisis, jadi ini seharusnya hanya konfirmasi no-op).

- [ ] **Langkah 4: Commit**

```bash
git commit -m "chore: remove dead legacy one-off migration scripts"
```

---

## Task 15: Verifikasi akhir

**Files:** tidak ada (hanya verifikasi)

- [ ] **Langkah 1: Konfirmasi Claude Code menemukan subagent dan skill baru**

Mulai sesi Claude Code baru di repo ini (atau tanyakan pada sesi yang
sedang berjalan, jika ia membaca ulang `.claude/`) untuk mendaftar
subagent dan skill yang tersedia. Ekspektasi: `flutter-ui-builder`,
`flutter-code-reviewer`, `supabase-schema-agent`, `flutter-qa-writer`,
`git-committer` muncul sebagai agent; `add-feature`, `run-and-screenshot`,
`supabase-schema-change`, `dompetku-feature-spec` muncul sebagai skill.

- [ ] **Langkah 2: Konfirmasi hook commit-msg bertahan pada skenario clone baru**

Jalankan:
```bash
git config --get core.hooksPath
```
Ekspektasi: `.githooks`. Catat di bagian Git Hooks pada `AGENTS.md`
(sudah ditulis di Task 2) bahwa ini adalah langkah lokal satu kali per
clone — tidak ada tindakan lebih lanjut yang diperlukan di sini, langkah
ini hanya mengonfirmasi kondisi saat ini.

- [ ] **Langkah 3: Konfirmasi `flutter analyze` dan `flutter test` bersih**

Jalankan:
```bash
flutter analyze
flutter test
```
Ekspektasi: `flutter analyze` tidak menunjukkan masalah baru yang
diakibatkan oleh rencana ini; `flutter test` lolos (test default
counter-app yang sudah ada sebelumnya tidak terkait dengan cakupan
rencana ini dan seharusnya tidak terpengaruh).

- [ ] **Langkah 4: Pemeriksaan status akhir**

Jalankan:
```bash
git status
git log --oneline -15
```
Ekspektasi: working tree bersih, 14 commit baru (Task 1-14) sejak
commit spec, masing-masing dengan pesan Conventional Commit.
