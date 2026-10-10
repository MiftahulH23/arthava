# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Report it privately through GitHub: go to the **Security** tab of this repository, then **Report a vulnerability**. Include what you found, how to reproduce it, and what an attacker could do with it.

You'll get a reply within 7 days. Once a fix is released, you'll be credited in the release notes unless you prefer otherwise.

## Scope

In scope: the app code in this repository and the SQL in `supabase/migrations/`, for example a Row Level Security policy or database function that lets a user read or change another user's data.

Out of scope: your own Supabase project's configuration, and keys you put in your own `env.json`.

## Keys

The Supabase **anon** key is designed to be public, because Row Level Security protects the data. The `service_role` key must never be used in the app. If you find any other secret committed to this repository, report it as above.
