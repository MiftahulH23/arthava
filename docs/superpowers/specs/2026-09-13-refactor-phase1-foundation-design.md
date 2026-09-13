# Code Structure Refactor — Phase 1: Foundation — Design Spec

Date: 2026-09-13
Status: Approved by user, pending implementation plan

## Context

Following the agent-first tooling setup (see
`2026-09-13-agent-first-setup-design.md`), the user wants to improve
DompetKu's code structure before continuing UI/UX work, specifically so
that:
- UI components are reusable and visually consistent across screens
  (the user's concrete complaint: tab-like selectors look different from
  screen to screen because each screen reimplements its own).
- Business logic (Supabase calls, calculations) is separated from screen
  widgets so screens stay focused on UI.
- The `flutter-ui-builder` subagent (from the agent-first setup) can
  eventually be told "use component X" instead of improvising per screen.

This is a large, multi-screen effort. Per user decision, it is split into
phases, each its own spec/plan. **This spec covers Phase 1 only**: build
the foundation (component library + state management pattern) and prove
it end-to-end on one representative screen. Later phases (migrating the
remaining 23 screens, prioritizing `home_screen.dart` and
`stats_screen.dart` where the tab-inconsistency actually shows) are out
of scope here and will get their own specs.

## Current State (observed)

- 24 screens in `lib/screens/`, flat, totaling ~18,800 lines. Largest:
  `target_screen.dart` (1759 lines), `stats_screen.dart` (1432),
  `savings_screen.dart` (1427), `home_screen.dart` (1411).
- **Zero reusable widget classes**: `grep -rn "^class .*extends
  StatelessWidget" lib/screens/*.dart` returns nothing. Every screen
  builds its UI via private `_buildXxx` methods inside its `State`
  class — nothing is extracted or shared.
- **13 of 24 screens** call `showModalBottomSheet` independently, each
  with its own inline styling (rounded corners, padding, drag handle) —
  no shared bottom-sheet wrapper.
- **300+ occurrences** of `BorderRadius.circular(...)` across screens —
  card/container styling is copy-pasted, not componentized.
- Tab-like selectors exist in at least `home_screen.dart` and
  `stats_screen.dart`, each implemented as ad hoc `Row`/`GestureDetector`
  code — not the same widget, hence visually inconsistent (the user's
  reported pain point).
- No state management library. Screens are `StatefulWidget`s that call
  `Supabase.instance.client` directly in methods like
  `wallet_screen.dart`'s `_showTransferSheet()`/`_showAddEditWalletSheet()`.
- `wallet_screen.dart` (665 lines) is representative of the pattern:
  a `StatefulWidget` holding a `SupabaseClient` field, business-logic
  methods, and two `showModalBottomSheet` calls with inline UI.

## Goals

1. Establish `lib/widgets/`: a shared component library, built by
   wrapping and restyling **`forui`** components (per explicit user
   instruction: "base component semuanya dari forui" — every base
   component in this library wraps a forui widget, not ad hoc custom
   code), themed to match the app's existing `AppColors`/Poppins/Phosphor
   identity rather than forui's default look.
2. Establish `lib/providers/`: a Riverpod-based pattern for moving
   business logic (Supabase calls, calculations) out of screens.
3. Prove both end-to-end by fully migrating **`wallet_screen.dart`** —
   UI rebuilt from `lib/widgets/` components, logic moved to a
   `lib/providers/wallet_provider.dart`.
4. Leave the codebase in a state where a *second* screen's migration
   (Phase 2+) has a clear, documented pattern to follow — this spec's
   deliverable is the pattern and its proof, not full coverage.

## Non-Goals

- Migrating any screen other than `wallet_screen.dart` (23 screens
  remain, including the high-priority `home_screen.dart`/
  `stats_screen.dart` — future specs).
- Visual redesign beyond what's needed for consistency. This is a
  structural refactor, not a UI/UX redesign — components are restyled
  to match the *existing* `AppColors` palette, not a new look.
- Supabase schema changes.
- Code generation tooling (no `riverpod_generator`/`build_runner`) —
  Riverpod usage in this phase uses plain `Provider`/`FutureProvider`/
  `NotifierProvider` APIs, to keep the dependency/tooling footprint
  small. Revisit codegen in a later phase if boilerplate becomes painful.
- Updating `flutter-ui-builder`/`AGENTS.md` to mandate the new
  components — deferred to *after* this phase's pattern is proven working
  (a short follow-up task once Phase 1 lands), not bundled into this
  plan.

## Design

### 1. Dependencies

Verified via `flutter pub add --dry-run` against this project's actual
Flutter 3.38.5 / Dart 3.10.4 toolchain (not assumed from package docs,
which reference newer unrelated SDK floors):

- `forui` resolves to **0.17.0** (latest 0.26.0 requires a newer Flutter
  than this project has — 0.17.0 is the version this SDK actually gets).
- `flutter_riverpod` resolves to **3.3.2**.

Both dry-runs completed cleanly with no conflicting constraints against
existing dependencies (`supabase_flutter`, `google_fonts`, `fl_chart`,
etc.).

### 2. Folder structure: global `lib/widgets/` + per-screen local overrides

Feature-first/colocation structure — the Flutter equivalent of a Next.js
`components/` (global, shared) + per-route `_components/` (local
override, used only when a screen needs a variant that differs from the
global component) pattern the user described. Dart has no
routing-folder convention equivalent to Next.js's underscore prefix, so
this is a plain, enforced-by-convention (not by the compiler) structure:

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

Rule: a screen imports directly from `lib/widgets/` by default. A local
`widgets/` subfolder under that screen's own folder is created only when
a component must visually/behaviorally diverge from the global version
for that screen specifically — never created preemptively "just in
case." This phase's proof screen (`wallet_screen.dart`, Section 5) is
not expected to need a local override — if the implementer finds it
does, that's fine and should be noted in the report, but don't invent a
need for one.

This phase converts only `wallet_screen.dart` to the new
`lib/screens/wallet/wallet_screen.dart` layout, as part of proving the
pattern. The other 23 screens stay flat in `lib/screens/` until their own
future migration phase — this is an intentional, temporary mixed state
(some screens in per-folder layout, most still flat), which is normal
mid-migration and should be called out in `AGENTS.md`'s Structure
section once this phase lands (deferred to the same follow-up task as
the `flutter-ui-builder` update, per this spec's Non-Goals).

### 4. `lib/widgets/` — component library wrapping forui

Structure: one file per component, flat (mirrors the simplicity of the
existing `lib/models/`/`lib/services/` pattern — no further nesting
needed yet at this size):

- `lib/widgets/app_card.dart` — wraps forui's `FCard`, restyled with
  `AppColors.white`/`AppColors.background` and the app's existing corner
  radius convention (read from current inline usage — most screens use
  `BorderRadius.circular(16)` or `(20)`; standardize on one value as
  part of this task and note the chosen value in the component's doc
  comment).
- `lib/widgets/app_bottom_sheet.dart` — wraps forui's `FSheet` (or
  `FPersistentSheet` if a better fit — implementer confirms against
  forui 0.17.0's actual API, which may differ from the newest docs),
  providing one `showAppBottomSheet(context, child: ...)` helper so
  every screen's bottom sheet gets consistent padding/corner
  radius/drag-handle instead of each screen inlining
  `showModalBottomSheet` with its own `shape`/`padding`.
- `lib/widgets/app_button.dart` — wraps forui's `FButton`, restyled to
  `AppColors.primary`/`AppColors.accent`.
- `lib/widgets/app_tab_selector.dart` — wraps forui's `FTabs` (or the
  closest forui tab/segmented-control primitive available in 0.17.0),
  restyled to match `AppColors`. This directly targets the user's
  reported inconsistency — this becomes *the* tab widget every screen
  uses going forward.

Each file: a single `Widget`-returning class or function, a short doc
comment naming which forui widget it wraps and why the styling choices
were made (the *why*, not a restatement of the code) — matching this
project's "default to no comments unless the why is non-obvious"
convention.

### 5. `lib/providers/` — Riverpod pattern

- `main.dart` gets wrapped in `ProviderScope` (Riverpod's root widget),
  replacing the plain `runApp(const MyApp())` — this is the one
  unavoidable touch to `main.dart` in this phase.
- `lib/providers/wallet_provider.dart`: a `NotifierProvider` (or
  `FutureProvider` for read-only fetch — implementer picks per Riverpod
  3.x's current recommended pattern for a Supabase-backed list) holding
  wallet list state, exposing methods equivalent to what
  `wallet_screen.dart` currently does inline (fetch wallets, add wallet,
  edit wallet, transfer between wallets). Supabase calls move here
  verbatim from the screen — this phase moves code, it does not rewrite
  the Supabase query logic itself.
- No other providers in this phase — one provider file, proving the
  pattern, is the deliverable.

### 6. `wallet_screen.dart` migration (the proof)

- Move `lib/screens/wallet_screen.dart` to
  `lib/screens/wallet/wallet_screen.dart` (per Section 2's folder
  structure), updating its import in whichever file currently navigates
  to it.
- Convert `WalletScreen` from `StatefulWidget` to `ConsumerWidget` (or
  `ConsumerStatefulWidget` if local-only UI state like a text controller
  is still needed alongside provider state — implementer's call,
  document which was chosen and why).
- Replace inline card/container UI with `lib/widgets/app_card.dart`.
- Replace both `showModalBottomSheet` calls with the new
  `showAppBottomSheet` helper.
- Remove the direct `Supabase.instance.client` field and business-logic
  methods from the screen; screen reads/calls through
  `wallet_provider.dart` instead.
- End state: `wallet_screen.dart` should shrink substantially (exact
  target not mandated — "no business logic left in the file" is the
  bar, not a line count).

### 7. Testing

- Widget tests for each new `lib/widgets/` component (`test/widgets/`,
  mirroring path) — verifies the component renders and responds to its
  documented parameters (e.g. `AppButton` calls its `onPressed`,
  `AppTabSelector` reports the selected index on tap).
- A test for `wallet_provider.dart`'s logic that doesn't require a live
  Supabase connection where feasible (e.g. pure calculation methods, if
  any) — full Supabase-backed methods may only be feasible to
  smoke-test for compile/shape correctness, per the `flutter-qa-writer`
  subagent's existing documented limitation on Supabase-coupled code.
- Manual visual verification of the migrated `wallet_screen.dart` via
  the `run-and-screenshot` skill before calling this phase done.

## Testing / Verification (this plan)

- `flutter analyze` clean on all new/changed files (existing 245
  pre-existing issues elsewhere are out of scope).
- `flutter test` — new widget/provider tests pass; the pre-existing
  unrelated `test/widget_test.dart` failure (documented in the
  agent-first setup's ledger) is not this plan's concern.
- Visual check via `run-and-screenshot` on `wallet_screen.dart`: wallet
  list renders, add/edit sheet opens with the new bottom-sheet styling,
  transfer sheet works, no regression in functionality (balances still
  update correctly).

## Open Questions

None outstanding — all resolved during brainstorming. One implementer
judgment call is explicitly delegated (Section 4: exact forui widget
names/APIs at v0.17.0 may differ from the latest docs referenced during
this spec's research — implementer verifies against the actually
installed package, e.g. via `flutter pub deps` output or the vendored
package source under `~/.pub-cache`, before writing final wrapper code).
