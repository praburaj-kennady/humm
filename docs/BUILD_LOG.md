# Build log

Newest first. Each entry: what changed, why, and what's next.

## Day 1 · 8 Nov 2026 · The backend

**What shipped**

- The full data model: songs, hooks, moods, a weekly chart, Browse rails and Saved.
- Three API calls that map to the three moments in the app: `get_home` (Browse), `get_feed` (Listen) and `toggle_save` (the heart button).
- Seed data: 8 well-known Tamil songs and 9 hooks, linked to official YouTube uploads.
- Tests that sign in as an anonymous visitor and as two different listeners, and check each one only sees what they should. They run in CI on every push.

**Decisions** (each has a short record in [decisions](decisions))

1. [Embeds only](decisions/0001-embeds-only.md). A hook is a pointer plus a time range. No audio is ever stored.
2. [Supabase is the whole backend](decisions/0002-supabase-as-the-whole-backend.md). The schema is the API, so there's no server to run.
3. [Saved without sign-up](decisions/0003-anonymous-saves.md). Anonymous auth gives every listener an id from the first tap.

**What I learned**

- The design shaped the API directly. The home screen is one call because Browse is one screen, and the Feed takes a rail because you open it from a rail.
- The hardest part of the data isn't the schema. It's the *timings*. Finding the exact second a hook lands still takes a human with headphones. Every seeded hook is marked `timing_verified = false` until then.

**Next**

- Listen through each seeded hook and fix its start and end.
- Add the top Reel and Instagram audio link for each hook.
- Deploy to a free Supabase project and connect the app.
