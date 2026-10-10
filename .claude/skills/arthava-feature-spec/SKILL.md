---
name: arthava-feature-spec
description: Use alongside superpowers:brainstorming whenever the user describes a new Arthava feature or refactor in free-form language. Adds Arthava-specific clarifying questions, writes the resulting spec document in Bahasa Indonesia, and structures it so flutter-ui-builder, supabase-schema-agent, and other subagents can act on it directly. Never use instead of brainstorming — only to extend its clarifying-questions and design-presentation steps for this repo.
---

# Arthava Feature/Refactor Spec Intake

Extends `superpowers:brainstorming` for this repo. Follow brainstorming's
own process in full (classify spike/bounded/architectural, ask one
question at a time, propose approaches, present design, get approval,
write the spec to `docs/superpowers/specs/`) — this skill only adds what
to ask and how to structure the output for Arthava specifically. It is
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
to make sure Arthava-specific ambiguity isn't overlooked.
