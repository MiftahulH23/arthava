# Agent-First Setup for DompetKu — Design Spec

Date: 2026-09-13
Status: Approved by user, pending implementation plan

## Context

DompetKu (`catat_uang_app`) is a Flutter + Supabase personal finance app.
The user wants to invest in UI/UX next, but first wants the repository set
up to be "agent-first": standing instructions, subagents, and skills so
that AI coding agents (Claude Code) can work on this codebase reliably and
consistently, without re-deriving project context every session.

This phase is infrastructure/tooling only. No application code in `lib/`
is refactored as part of this work, except for removing three confirmed-
dead legacy scripts at the repo root.

## Current State (observed)

- Flutter app, Material3, `google_fonts` (Poppins), custom `AppColors`.
- No state management library — theme uses a global `ValueNotifier`
  (`lib/core/theme_mode_manager.dart`); screens are mostly `StatefulWidget`
  with local state and direct Supabase calls.
- `lib/screens/` is flat — 20+ screens, no widgets/ or features/ subfolder.
- `lib/models/`, `lib/services/` (`auth_service.dart`, `gemini_service.dart`,
  `pdf_service.dart`) are the only separation beyond screens.
- Backend: Supabase (`supabase_flutter`). Anon key is hardcoded in
  `lib/main.dart` — acceptable for a Supabase anon key IF RLS policies are
  correctly scoped, but worth flagging to agents as a known fact, not a
  bug to silently "fix".
- No CI config found. No meaningful test suite (`test/widget_test.dart` is
  the default Flutter counter-app test, not adapted to this app).
- Three one-off codegen scripts at repo root are dead: `update_home_screen.py`,
  `update_stats.dart`, `update_trx.dart`. Confirmed via `git grep` — not
  referenced anywhere. Each is a single-purpose mutation script whose
  transformation is already applied to the target file (confirmed by
  matching commit history, e.g. "responsive web layout" commit). They are
  not reusable tools.

## Goals

1. Give every agent session standing context about this project via a
   tool-agnostic `AGENTS.md`, so agents don't need to rediscover
   structure/conventions from scratch each time — and so tools other than
   Claude Code (Codex, Cursor, etc.) can read the same instructions.
2. Provide five specialized subagents matching the user's actual
   workflows: UI building, code review, Supabase/data work, testing, and
   conventional-commit git commits.
3. Provide three skills for the most common repeatable procedures:
   adding a feature/screen, running+visually verifying the app, and
   changing the Supabase schema safely.
4. Enforce Conventional Commits format (`feat:`, `fix:`, `chore:`, etc.)
   via a native git `commit-msg` hook, so commit history stays consistent
   regardless of who/what is committing.
5. Remove dead weight (legacy scripts) that would otherwise confuse an
   agent exploring the repo.
6. All subagent and skill definitions are written in English (per user
   instruction), for portability and consistency. `AGENTS.md` and
   `CLAUDE.md` are also written in English.
7. Keep documented conventions (font, icon, color) in `AGENTS.md` in sync
   with the code via a written rule plus a `PostToolUse` reminder hook,
   while dependency/library changes still always require explicit user
   confirmation (unchanged from standing behavior).

## Non-Goals

- No refactor of `lib/` structure (no widget extraction, no state
  management introduction, no repository-layer introduction).
- No change to how the Supabase anon key is configured/stored.
- No CI/CD pipeline setup (not requested).
- No new automated test writing in this phase (the QA subagent is scaffolding
  for future use, not a mandate to write tests now).
- No PR-creation automation — the commit subagent handles commits only,
  not pushing or opening PRs (those still go through explicit user request,
  per standing tool-use rules).

## Design

### 1. `AGENTS.md` (repo root) — canonical, tool-agnostic instructions

This is the single source of truth. Any AI coding tool that follows the
`AGENTS.md` convention (Claude Code, Codex, Cursor, etc.) reads this file
directly.

Sections:
- **Project overview**: what DompetKu is, tech stack (Flutter, Supabase,
  Gemini AI for receipt scanning/advisory, fl_chart, pdf/printing export).
- **Structure**: explanation of `lib/core`, `lib/models`, `lib/screens`,
  `lib/services`, and the fact that screens are currently flat/monolithic
  (stated as fact, not as a problem to fix).
- **Conventions observed**: Material3 + `ColorScheme.fromSeed`, `AppColors`
  for palette, Poppins via `google_fonts`, `ValueNotifier<ThemeMode>` for
  theme switching, Indonesian (`id_ID`) locale/date formatting, snake_case
  file names / PascalCase classes (standard Dart).
  - Screen file naming: `*_screen.dart` in `lib/screens/`.
  - Models are plain Dart classes with `fromJson`/`toJson` matching
    Supabase table shape (verify per-file, don't assume a shared base).
- **Commands**: `flutter analyze`, `flutter test`, `flutter run -d chrome`
  / `-d windows`, `flutter pub get`.
- **Commit convention**: Conventional Commits (`feat:`, `fix:`, `chore:`,
  `docs:`, `refactor:`, `test:`, `style:`, `perf:`, `build:`, `ci:`),
  enforced by the `commit-msg` git hook described below.
- **Known context / do-not-touch-silently**:
  - Supabase anon key is hardcoded in `lib/main.dart` by design for this
    project's current stage; don't "fix" this unless explicitly asked.
  - No CI currently; `flutter analyze` + `flutter test` are the local
    verification bar before claiming work done.
- **Pointers to subagents/skills**: one-line table of when to reach for
  each of the five Claude Code subagents and three skills defined below
  (noted as Claude-Code-specific, since `.claude/` format isn't part of
  the `AGENTS.md` cross-tool standard).

### 1b. `CLAUDE.md` (repo root) — thin Claude Code entry point

Contains only:
```
@AGENTS.md
```
plus, if needed, a short Claude-Code-specific addendum (e.g. explicitly
naming the `.claude/agents/` and `.claude/skills/` directories so Claude
Code's own routing picks them up — this is metadata Claude Code already
discovers automatically, so the addendum will likely just be the import
line unless testing shows otherwise).

### 2. Subagents — `.claude/agents/*.md`

All in English. Each file: YAML frontmatter (`name`, `description`,
`tools`) + a short system prompt body.

- **`flutter-ui-builder`**
  Purpose: build and redesign screens/widgets to match the project's
  existing visual language (Material3, AppColors, Poppins). Full tool
  access (Read/Write/Edit/Bash) since it needs to run the app to verify
  visually (pairs with the `run-and-screenshot` skill).
- **`flutter-code-reviewer`**
  Purpose: review Dart diffs for correctness, null-safety, state/rebuild
  issues, and consistency with existing patterns in the file being
  touched. Read-only tools (Read/Grep/Glob/Bash for `flutter analyze`) —
  no Write/Edit, so it can't "fix while reviewing".
- **`supabase-schema-agent`**
  Purpose: work with Supabase table schema, RLS, and the Dart
  models/services that mirror them; keep `lib/models/*` and
  `lib/services/*` in sync with schema changes. Full tool access.
- **`flutter-qa-writer`**
  Purpose: write widget/unit tests for Flutter screens and logic,
  following `flutter_test` conventions. Full tool access, scoped to
  `test/` and read access to `lib/`.
- **`git-committer`**
  Purpose: stage and commit changes with a well-formed Conventional
  Commits message (correct type — `feat`/`fix`/`chore`/`docs`/`refactor`/
  `test`/`style`/`perf`/`build`/`ci` — concise scope/summary, body
  explaining why when non-obvious). Follows the same git safety rules
  already in force for this session (new commits not amends, no
  `--no-verify`, never push without explicit request, review staged diff
  before committing, HEREDOC for multi-line messages, required
  Co-Authored-By/Claude-Session trailer). Tools: Bash (git only, in
  practice) + Read for diff inspection. This subagent is only invoked
  when the user asks to commit — it does not commit proactively.

Each subagent description states clearly when it should be invoked, so
routing doesn't overlap (e.g. UI builder doesn't do data-layer work,
schema agent doesn't touch widget trees beyond what's needed to keep
models in sync, git-committer never writes application code).

### 3. Skills — `.claude/skills/<name>/SKILL.md`

All in English.

- **`add-feature`**: step-by-step checklist for adding a new
  feature/screen — model → service (Supabase calls) → screen → route
  wiring in `main.dart` or navigation → styling per `AppColors`/theme
  conventions. Written as a procedure the `flutter-ui-builder` or a
  general session follows, not as a standalone agent.
- **`run-and-screenshot`**: procedure to launch the app (choose a target:
  chrome for quick web preview, windows for desktop) and capture visual
  state before reporting UI work as complete — operationalizes the
  "test the golden path in a browser" system guidance for this specific
  project.
- **`supabase-schema-change`**: safe procedure for changing Supabase
  schema — plan the migration, apply it, update RLS if needed, then
  update the corresponding Dart model(s) and service(s), and note what
  manual verification (e.g. Supabase dashboard check) is still needed
  since this session has no direct Supabase MCP/DB access confirmed.

Spec/feature intake for new work ("I want to describe a feature/refactor
in my own words and have it turned into a clear spec, asking me
questions when something's unclear") is already handled by the
pre-installed `superpowers:brainstorming` skill — the same one used to
produce this document. No additional skill is needed for that.

### 4. Conventional Commits enforcement — native git hook

No Node/`package.json` dependency (project is Flutter-only). Instead:
- `.githooks/commit-msg` — a POSIX shell script that validates the commit
  message's first line against a Conventional Commits regex
  (`^(feat|fix|chore|docs|refactor|test|style|perf|build|ci)(\(.+\))?!?: .+`),
  rejecting the commit with a clear error + example if it doesn't match.
- Repo is configured to use this hooks directory: `git config core.hooksPath .githooks`.
  This is a local, one-time setup step (not committed as global git config) —
  documented in `AGENTS.md` so a human or agent setting up the repo fresh
  knows to run it. Cannot be auto-applied by cloning alone since
  `core.hooksPath` is a local config, not a repo file that git reads
  automatically for security reasons.
- The hook applies to anyone committing (human via IDE/CLI, or the
  `git-committer` subagent), regardless of tool.

### 5. Keeping `AGENTS.md` in sync — rule + reminder hook

Two layers so documented conventions (font, icon set, color palette)
don't drift from the actual code:

- **Rule in `AGENTS.md`** itself: "When you change a documented
  convention (font, icon package, color palette, theming approach),
  update the Conventions section of this file in the same change. When a
  change swaps or adds a library/dependency, that already requires
  explicit user confirmation per standing tool-use rules — do that first,
  then update this file."
- **`PostToolUse` hook** (`.claude/settings.json`) that fires after
  Edit/Write on convention-bearing files — `pubspec.yaml`,
  `lib/core/colors.dart`, `lib/core/theme_mode_manager.dart` — and injects
  a reminder into context: "This file affects a documented convention in
  AGENTS.md — update it if this change alters font/icon/color/theme
  conventions." This is a nudge, not a blocker: it doesn't stop the edit
  or require confirmation itself, it just makes drift much less likely
  across long or resumed sessions. Dependency/library changes remain
  gated by the existing standing confirmation rule, unaffected by this
  hook.

### 6. Cleanup

Delete (not move) the three legacy root scripts:
`update_home_screen.py`, `update_stats.dart`, `update_trx.dart`.
Rationale: confirmed unreferenced via `git grep`, and each is a one-shot
mutation already applied to its target file — keeping them around would
mislead an agent into thinking they are reusable tooling.

## Testing / Verification

This is a docs/config-only change (plus a deletion). Verification:
- `flutter analyze` still passes after script deletion (scripts aren't
  part of the analyzed Dart package target anyway, but confirm no build
  reference breaks).
- Manually confirm `.claude/agents/*.md` and `.claude/skills/*/SKILL.md`
  are well-formed (valid frontmatter) by having Claude Code list
  available agents/skills after setup.
- Confirm `CLAUDE.md`'s `@AGENTS.md` import actually pulls in content
  (test by asking a fresh Claude Code session a question only answerable
  from `AGENTS.md` content).
- Test the `commit-msg` hook directly: after `git config core.hooksPath
  .githooks`, attempt a commit with a non-conforming message (expect
  rejection) and a conforming one (expect success).

## Open Questions

None outstanding — all resolved during brainstorming.
