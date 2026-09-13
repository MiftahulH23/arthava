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

1. Give every agent session standing context about this project via
   `CLAUDE.md`, so agents don't need to rediscover structure/conventions
   from scratch each time.
2. Provide four specialized subagents matching the user's actual workflows:
   UI building, code review, Supabase/data work, and testing.
3. Provide three skills for the most common repeatable procedures:
   adding a feature/screen, running+visually verifying the app, and
   changing the Supabase schema safely.
4. Remove dead weight (legacy scripts) that would otherwise confuse an
   agent exploring the repo.
5. All subagent and skill definitions are written in English (per user
   instruction), for portability and consistency. `CLAUDE.md` is also
   written in English.

## Non-Goals

- No refactor of `lib/` structure (no widget extraction, no state
  management introduction, no repository-layer introduction).
- No change to how the Supabase anon key is configured/stored.
- No CI/CD pipeline setup (not requested).
- No new automated test writing in this phase (the QA subagent is scaffolding
  for future use, not a mandate to write tests now).

## Design

### 1. `CLAUDE.md` (repo root)

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
- **Known context / do-not-touch-silently**:
  - Supabase anon key is hardcoded in `lib/main.dart` by design for this
    project's current stage; don't "fix" this unless explicitly asked.
  - No CI currently; `flutter analyze` + `flutter test` are the local
    verification bar before claiming work done.
- **Pointers to subagents/skills**: one-line table of when to reach for
  each of the four subagents and three skills defined below.

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

Each subagent description states clearly when it should be invoked, so
routing doesn't overlap (e.g. UI builder doesn't do data-layer work,
schema agent doesn't touch widget trees beyond what's needed to keep
models in sync).

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

### 4. Cleanup

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

## Open Questions

None outstanding — all resolved during brainstorming.
