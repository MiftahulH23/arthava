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
