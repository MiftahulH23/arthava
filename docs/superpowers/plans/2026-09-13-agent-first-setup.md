# Agent-First Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the DompetKu repository agent-first: a tool-agnostic `AGENTS.md` (imported by a thin `CLAUDE.md`), five Claude Code subagents, three skills, a native Conventional-Commits git hook, a convention-sync reminder hook, and removal of three dead legacy scripts.

**Architecture:** Pure documentation/configuration change. No `lib/` application code is touched except deleting three unreferenced root scripts. All new files live in `.claude/agents/`, `.claude/skills/`, `.githooks/`, plus `AGENTS.md` and `CLAUDE.md` at repo root.

**Tech Stack:** Flutter/Dart app (unaffected), Claude Code agent/skill markdown format, POSIX shell git hook (works via Git for Windows' bundled `sh`).

**Spec:** `docs/superpowers/specs/2026-09-13-agent-first-setup-design.md`

## Global Constraints

- All subagent (`.claude/agents/*.md`) and skill (`.claude/skills/*/SKILL.md`) content is written in English.
- `AGENTS.md` and `CLAUDE.md` are written in English.
- No changes to `lib/` application code except the two deletions listed in Task 13 (already confirmed dead).
- No Node/`package.json`/husky dependency — commit-msg enforcement is a native POSIX shell git hook.
- No change to how the Supabase anon key is stored (out of scope, documented as known context instead).
- The `git-committer` subagent must follow the same git safety rules already standing for this session: new commits not amends, no `--no-verify`, never push without explicit request, review staged diff before committing, HEREDOC for multi-line messages, required `Co-Authored-By`/`Claude-Session` trailer.
- Conventional Commits regex used everywhere in this plan: `^(feat|fix|chore|docs|refactor|test|style|perf|build|ci)(\([a-z0-9_-]+\))?!?: .+`

---

## Task 1: Conventional Commits git hook

**Files:**
- Create: `.githooks/commit-msg`
- Modify: (local git config only, not a file) — `core.hooksPath`

**Interfaces:**
- Produces: a `commit-msg` hook enforcing the Conventional Commits regex above. All later tasks' commits in this plan must conform to it once this task's git config step has run.

- [ ] **Step 1: Create the hooks directory and script**

Create `.githooks/commit-msg` with this content:

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

- [ ] **Step 2: Make the hook executable and register the hooks path**

Run:
```bash
chmod +x .githooks/commit-msg
git config core.hooksPath .githooks
```

- [ ] **Step 3: Test the hook rejects a bad message**

Run:
```bash
git commit --allow-empty -m "this is not conventional"
```
Expected: command fails, stderr shows the `commit-msg hook:` error above, no commit is created (`git log -1` still shows the previous commit).

- [ ] **Step 4: Test the hook accepts a good message**

Run:
```bash
git commit --allow-empty -m "chore: verify commit-msg hook"
```
Expected: commit succeeds. Then undo this empty test commit so it doesn't pollute history:
```bash
git reset --soft HEAD~1
```

- [ ] **Step 5: Commit the hook itself**

```bash
git add .githooks/commit-msg
git commit -m "chore(git): add Conventional Commits commit-msg hook"
```

---

## Task 2: `AGENTS.md` — canonical project instructions

**Files:**
- Create: `AGENTS.md`

**Interfaces:**
- Produces: the canonical instructions file every subsequent task's subagents/skills reference via pointers (Task 5-12 files link back to relevant `AGENTS.md` sections by name, not by line number, since this file will keep evolving).

- [ ] **Step 1: Create `AGENTS.md`**

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
```

- [ ] **Step 2: Verify required sections are present**

Run:
```bash
grep -c "^## " AGENTS.md
```
Expected: `7` (Project Overview, Structure, Conventions, Commands, Git Hooks, Known Context, Claude Code Subagents & Skills — the "Keeping this file in sync" heading doesn't count since it's a level-3 `###` heading). If the number differs, confirm every section listed in Step 1 exists via `grep "^## " AGENTS.md`.

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "docs: add AGENTS.md canonical project instructions"
```

---

## Task 3: `CLAUDE.md` — thin import for Claude Code

**Files:**
- Create: `CLAUDE.md`

**Interfaces:**
- Consumes: `AGENTS.md` (Task 2) via Claude Code's `@path` import syntax.

- [ ] **Step 1: Create `CLAUDE.md`**

```markdown
@AGENTS.md
```

- [ ] **Step 2: Verify the import resolves**

Ask a fresh question in this same Claude Code session that can only be
answered from `AGENTS.md` content, e.g. "What icon package does this
project use?" Expected answer: `phosphor_flutter`, sourced from the
imported file. (This step is a manual verification during plan
execution — there is no automated command for it.)

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "chore: add CLAUDE.md importing AGENTS.md"
```

---

## Task 4: Convention-sync reminder hook

**Files:**
- Create: `.claude/settings.json`

**Interfaces:**
- Produces: a `PostToolUse` hook matching Edit/Write on `pubspec.yaml`,
  `lib/core/colors.dart`, `lib/core/theme_mode_manager.dart` that prints
  a reminder to update `AGENTS.md`.

- [ ] **Step 1: Create `.claude/settings.json`**

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

- [ ] **Step 2: Verify the hook fires**

Make a trivial whitespace edit to `lib/core/colors.dart` (e.g. add then
remove a blank line via Edit tool) and confirm the reminder text appears
in tool output. Revert the trivial edit if it left any diff:
```bash
git checkout -- lib/core/colors.dart
```

- [ ] **Step 3: Commit**

```bash
git add .claude/settings.json
git commit -m "chore: add AGENTS.md convention-sync reminder hook"
```

---

## Task 5: `flutter-ui-builder` subagent

**Files:**
- Create: `.claude/agents/flutter-ui-builder.md`

- [ ] **Step 1: Create the subagent file**

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

- [ ] **Step 2: Verify frontmatter is well-formed**

Run:
```bash
head -n 5 .claude/agents/flutter-ui-builder.md
```
Expected: shows `---`, `name: flutter-ui-builder`, `description: ...`, `tools: ...`, `---` in that order.

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/flutter-ui-builder.md
git commit -m "chore(agents): add flutter-ui-builder subagent"
```

---

## Task 6: `flutter-code-reviewer` subagent

**Files:**
- Create: `.claude/agents/flutter-code-reviewer.md`

- [ ] **Step 1: Create the subagent file**

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

- [ ] **Step 2: Verify frontmatter is well-formed**

Run:
```bash
head -n 5 .claude/agents/flutter-code-reviewer.md
```
Expected: valid frontmatter block as in Task 5 Step 2.

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/flutter-code-reviewer.md
git commit -m "chore(agents): add flutter-code-reviewer subagent"
```

---

## Task 7: `supabase-schema-agent` subagent

**Files:**
- Create: `.claude/agents/supabase-schema-agent.md`

- [ ] **Step 1: Create the subagent file**

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

- [ ] **Step 2: Verify frontmatter is well-formed**

Run:
```bash
head -n 5 .claude/agents/supabase-schema-agent.md
```
Expected: valid frontmatter block.

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/supabase-schema-agent.md
git commit -m "chore(agents): add supabase-schema-agent subagent"
```

---

## Task 8: `flutter-qa-writer` subagent

**Files:**
- Create: `.claude/agents/flutter-qa-writer.md`

- [ ] **Step 1: Create the subagent file**

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

- [ ] **Step 2: Verify frontmatter is well-formed**

Run:
```bash
head -n 5 .claude/agents/flutter-qa-writer.md
```
Expected: valid frontmatter block.

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/flutter-qa-writer.md
git commit -m "chore(agents): add flutter-qa-writer subagent"
```

---

## Task 9: `git-committer` subagent

**Files:**
- Create: `.claude/agents/git-committer.md`

- [ ] **Step 1: Create the subagent file**

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

- [ ] **Step 2: Verify frontmatter is well-formed**

Run:
```bash
head -n 5 .claude/agents/git-committer.md
```
Expected: valid frontmatter block.

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/git-committer.md
git commit -m "chore(agents): add git-committer subagent"
```

---

## Task 10: `add-feature` skill

**Files:**
- Create: `.claude/skills/add-feature/SKILL.md`

- [ ] **Step 1: Create the skill file**

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

- [ ] **Step 2: Verify frontmatter is well-formed**

Run:
```bash
head -n 4 .claude/skills/add-feature/SKILL.md
```
Expected: `---`, `name: add-feature`, `description: ...`, `---`.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/add-feature/SKILL.md
git commit -m "chore(skills): add add-feature skill"
```

---

## Task 11: `run-and-screenshot` skill

**Files:**
- Create: `.claude/skills/run-and-screenshot/SKILL.md`

- [ ] **Step 1: Create the skill file**

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

- [ ] **Step 2: Verify frontmatter is well-formed**

Run:
```bash
head -n 4 .claude/skills/run-and-screenshot/SKILL.md
```
Expected: `---`, `name: run-and-screenshot`, `description: ...`, `---`.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/run-and-screenshot/SKILL.md
git commit -m "chore(skills): add run-and-screenshot skill"
```

---

## Task 12: `supabase-schema-change` skill

**Files:**
- Create: `.claude/skills/supabase-schema-change/SKILL.md`

- [ ] **Step 1: Create the skill file**

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

- [ ] **Step 2: Verify frontmatter is well-formed**

Run:
```bash
head -n 4 .claude/skills/supabase-schema-change/SKILL.md
```
Expected: `---`, `name: supabase-schema-change`, `description: ...`, `---`.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/supabase-schema-change/SKILL.md
git commit -m "chore(skills): add supabase-schema-change skill"
```

---

## Task 13: Remove dead legacy scripts

**Files:**
- Delete: `update_home_screen.py`
- Delete: `update_stats.dart`
- Delete: `update_trx.dart`

**Interfaces:**
- None — these files have no incoming references (already confirmed via
  `git grep` during spec research).

- [ ] **Step 1: Re-confirm no references exist**

Run:
```bash
git grep -n "update_home_screen\|update_stats\|update_trx" -- . ':!update_home_screen.py' ':!update_stats.dart' ':!update_trx.dart'
```
Expected: no output (empty). If this now shows a match, stop and
investigate before deleting — do not proceed with deletion.

- [ ] **Step 2: Delete the files**

```bash
git rm update_home_screen.py update_stats.dart update_trx.dart
```

- [ ] **Step 3: Verify `flutter analyze` still passes**

Run:
```bash
flutter analyze
```
Expected: no new errors related to the deleted files (they were never
part of the analyzed Dart package graph, so this should be a no-op
confirmation).

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: remove dead legacy one-off migration scripts"
```

---

## Task 14: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Confirm Claude Code discovers the new subagents and skills**

Start a fresh Claude Code session in this repo (or ask the current one,
if it re-reads `.claude/`) to list available subagents and skills.
Expected: `flutter-ui-builder`, `flutter-code-reviewer`,
`supabase-schema-agent`, `flutter-qa-writer`, `git-committer` appear as
agents; `add-feature`, `run-and-screenshot`, `supabase-schema-change`
appear as skills.

- [ ] **Step 2: Confirm the commit-msg hook survives a fresh clone scenario**

Run:
```bash
git config --get core.hooksPath
```
Expected: `.githooks`. Note in `AGENTS.md`'s Git Hooks section (already
written in Task 2) that this is a one-time local step per clone — no
further action needed here, this step just confirms current state.

- [ ] **Step 3: Confirm `flutter analyze` and `flutter test` are clean**

Run:
```bash
flutter analyze
flutter test
```
Expected: `flutter analyze` shows no new issues introduced by this
plan; `flutter test` passes (the pre-existing default counter-app test
is unrelated to this plan's scope and should be unaffected).

- [ ] **Step 4: Final status check**

Run:
```bash
git status
git log --oneline -15
```
Expected: clean working tree, 13 new commits (Tasks 1-13) since the
spec commits, each with a Conventional Commit message.
