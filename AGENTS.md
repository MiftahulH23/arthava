# AGENTS.md — DompetKu

Instructions for any AI coding agent (Claude Code, Codex, Cursor, etc.)
working in this repository. This file is the canonical source of truth;
`CLAUDE.md` just imports it for Claude Code.

## Project Overview

DompetKu (package name `catat_uang_app`) is a personal finance tracker
built with Flutter, backed by Supabase (Postgres + Auth). Features
include transactions, wallets, budgets, savings, targets, investments, debts,
recurring transactions, a financial calendar, PDF export, biometric
lock, and an AI advisor / receipt scanner powered by Google Gemini
(`google_generative_ai`).

## Structure

- `lib/main.dart` — app entry point, Supabase init, theme setup, initial
  route decision (login vs. lock vs. home based on session state).
- `lib/core/` — cross-cutting concerns: `colors.dart` (palette),
  `theme_mode_manager.dart` (global `ValueNotifier<ThemeMode>`),
  `app_notification.dart`.
- `lib/theme/app_forui_theme.dart` — maps `AppColors` and the font into
  forui's `FThemeData`. Build it with the `FThemeData(...)` constructor;
  `.copyWith` on a preset doesn't propagate the colors into per-widget
  styles.
- `lib/models/` — plain Dart data classes, one per Supabase table
  concept, each with a `fromJson` factory matching that table's shape.
  There is no shared base model class — verify each model's own JSON
  keys rather than assuming a common pattern.
- `lib/screens/<feature>/<feature>_screen.dart` — feature-first folders,
  one folder per screen (plus related detail screens, e.g.
  `budget/budget_detail_screen.dart`). Screens are
  `ConsumerStatefulWidget`s that read state from providers.
- `lib/providers/<feature>_provider.dart` — Riverpod (`flutter_riverpod`
  2.x) `NotifierProvider.autoDispose` per feature; providers own the
  Supabase queries. A `Notifier.build()` must not touch `state`
  synchronously (defer the first fetch with `Future.microtask`), or it
  throws `StateError: uninitialized provider`. To force a refresh,
  `ref.invalidate(...)` the provider; don't rely on changing a widget's
  `ValueKey`.
- `lib/widgets/` — shared UI built on forui: `AppButton`, `AppCard`,
  `AppTabSelector`, `AppBottomNav`, `showAppBottomSheet`. Use these
  instead of hand-rolling tabs, sheets, or buttons in a screen.
- `lib/services/` — thin wrappers around Supabase/external APIs
  (`auth_service.dart`, `gemini_service.dart`, `pdf_service.dart`).

## Conventions

- **Theming:** Material 3, `ColorScheme.fromSeed(seedColor: AppColors.primary)`,
  light/dark switched via the global `themeNotifier` in
  `lib/core/theme_mode_manager.dart` (call `toggleTheme(bool isDark)` to
  change it — don't invent a second theme-switching mechanism).
- **Colors:** all named colors come from `AppColors` in `lib/core/colors.dart`.
  Don't hardcode hex colors in screens/widgets — add a new named constant
  to `AppColors` instead. The palette is "iOS Blue": system blue primary
  (`#007AFF`) on the iOS grouped background (`#F2F2F7`), white cards;
  green/red are reserved for income/expense meaning.
- **Design direction:** Material widgets styled to feel like iOS (not
  Cupertino widgets): large left-aligned titles, grouped inset lists,
  segmented controls, add/edit forms as bottom sheets. For visual
  redesigns, agree on a mockup with the user before writing code.
- **Modals:** every modal in the app has the same look. Confirmations
  and choices go through `showAppConfirmDialog` / `showAppChoiceDialog`
  (`lib/widgets/app_dialogs.dart`); forms, lists and date/month/year/
  range pickers are bottom sheets (`showAppFormSheet`, `showApp*Picker`
  in `lib/widgets/app_pickers.dart`); blocking loading uses
  `runWithAppLoading`. Never call `showDialog`, `AlertDialog`,
  `showDatePicker`, `showDateRangePicker`, `showModalBottomSheet` or
  `showAppBottomSheet` directly from a screen.
  `test/architecture/modal_consistency_test.dart` enforces this; its
  `_legacy` list names the not-yet-redesigned screens and the plan that
  cleans each one — remove a file's entry when its plan does.
- **Font:** `google_fonts` Plus Jakarta Sans
  (`GoogleFonts.plusJakartaSansTextTheme(...)`), applied once in
  `main.dart`'s `ThemeData.textTheme` (light & dark), and mapped into
  `appForuiTheme`'s typography for forui widgets. Many screens still
  call `GoogleFonts.poppins(...)` inline, which overrides the theme;
  don't add new ones, and replace them with theme text styles when you
  touch a screen.
- **Icons:** `phosphor_flutter` (Regular for inactive, Fill for active).
  Swapping to `hugeicons` and to Phosphor Duotone were both tried and
  rejected by the user.
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
- The UI redesign (Phase B) is specified in
  `docs/superpowers/specs/2026-09-24-redesign-phase-b-design.md` (design
  rules, tokens, shared component API, decisions) with the approved
  mockup at `docs/design/dompetku-redesign-mockup.html`. Its plans are
  `docs/superpowers/plans/2026-09-2*-phase-b*.md`, executed in order
  B1 → B2 → B3 → B3b → B4 → B5 → B6 → B7.
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
