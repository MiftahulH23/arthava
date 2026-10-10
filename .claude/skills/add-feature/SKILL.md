---
name: add-feature
description: Use when adding a new feature or screen to Arthava end-to-end (model, service, screen, navigation, styling), so nothing is missed and the result follows existing project conventions.
---

# Adding a Feature/Screen to Arthava

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
