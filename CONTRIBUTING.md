# Contributing to Arthava

Thanks for helping. This guide covers how to propose a change and what a pull request needs before it can be merged.

## How changes get in

`main` is protected. Nobody except the maintainer can push to it. Every change from contributors arrives as a pull request, and the maintainer ([@MiftahulH23](https://github.com/MiftahulH23)) reviews and merges it.

1. **Talk first for anything big.** Open an issue (bug or feature request) and describe what you want to do. Small fixes like typos, small bugs or tests can go straight to a PR.
2. **Fork** the repository and clone your fork.
3. **Set up** the project with your own Supabase backend by following the [README](README.md#getting-started).
4. **Branch** from `main`: `feat/recurring-reminders`, `fix/budget-rounding`, `docs/readme-typo`.
5. **Make the change**, with tests.
6. **Check** locally:
   ```bash
   flutter analyze   # no errors or warnings
   flutter test      # all green
   ```
7. **Push** to your fork and **open a pull request** against `main`. Fill in the template, and add screenshots for UI changes.
8. CI runs analyze and tests. The maintainer reviews, may ask for changes, and merges when it's ready.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org), enforced by the git hook (`git config core.hooksPath .githooks`):

```
feat(wallet): add transfer confirmation
fix(budget): round the remaining amount down
docs: explain the E2E setup
```

Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `style`, `perf`, `build`, `ci`.

## Code conventions

[`AGENTS.md`](AGENTS.md) is the full reference. The rules reviewers check most:

- **Colors** only from `AppColors` (`lib/core/colors.dart`). No hex values in screens or widgets. `test/conventions_test.dart` fails otherwise.
- **Text styles** from `AppTextStyles`. Don't call `GoogleFonts.*` in screens.
- **Icons** from `phosphor_flutter` (Regular when inactive, Fill when active).
- **Modals** only through the shared components: `showAppConfirmDialog`, `showAppChoiceDialog`, `showAppFormSheet`, `showApp*Picker`, `runWithAppLoading`. Never call `showDialog` or `showModalBottomSheet` directly. `test/architecture/modal_consistency_test.dart` enforces this.
- **Shared UI**: use the widgets in `lib/widgets/` (`AppPageScaffold`, `AppGroupedSection`, `AppListRow`, ...) instead of building cards, rows or sheets by hand.
- **State**: one Riverpod `NotifierProvider` per feature in `lib/providers/`. Providers own the Supabase queries, and screens only read them.
- **Locale**: user-facing text is Bahasa Indonesia, and money is formatted as Rupiah (`id_ID`).

## Database changes

- Never edit a migration that has already been merged. Add a **new** file in `supabase/migrations/` named `YYYYMMDDHHMM_short_description.sql`.
- Every table needs Row Level Security with policies scoped to `auth.uid()`.
- **Money changes** (wallet or savings balances) go through a Postgres function that does the work in one transaction. Follow the `wallet_add` pattern in `202609260004_atomic_money.sql`. Don't read a balance in the app and write it back.
- Update the matching model in `lib/models/` and `docs/database/schema.md` in the same PR.
- If your change touches money or the database, run the E2E tests against your own project (see the README) and say so in the PR.

## Tests

- New logic gets unit tests. New screens or widgets get widget tests using `pumpApp` from `test/helpers/pump_app.dart` with fake provider notifiers.
- Don't commit real credentials, personal data or `env.json`.

## Code of conduct

Be kind and constructive. Critique the code, not the person. Harassment of any kind isn't tolerated, and the maintainer may remove comments or block accounts that break this.
