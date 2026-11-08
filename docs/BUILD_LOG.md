# Build log

Newest first. Each entry: what changed, why, and what's next.

## Day 1, evening · 8 Nov 2026 · The iPhone app

**What shipped**

- A native SwiftUI app with the flow from Figma: Browse is home, a mini player docks at the bottom, and Listen slides up full screen with one hook at a time.
- It reads Browse in one call (`get_home`) and saves with `toggle_save`. The first save quietly gives the phone an anonymous id.
- Each hook plays through YouTube's own player and loops between its start and end.
- A new CI job builds the app on a Mac in GitHub's cloud on every change.
- The app is now called **Humm** (one fewer "m"). Shorter, and it's still the sound you make when a hook is stuck in your head.

**Decisions**

4. [Native iPhone first](decisions/0004-native-ios-first.md). A real SwiftUI app over a web page that imitates one.

**What I learned**

- Motion specs written in the design file (spring 0.45s, bounce 0.15) map one-to-one onto SwiftUI. The notes became code almost word for word.
- One shared player, not one per screen, is what lets a hook keep playing while you go from Listen back to Browse.

**Next**

- Run it on a real iPhone and tune the feel.
- TestFlight, so others can try it.

## Day 1, later · 8 Nov 2026 · It's live

**What shipped**

- The backend now runs on a free Supabase project (Mumbai region, close to most listeners).
- Anonymous sign-ins are on, so Saved works from the first tap.
- Supabase's security check: 0 issues.

**What I learned**

- My AI pair couldn't apply the schema itself: Supabase asks the project owner to confirm changes that touch permissions, and that prompt never reached me. So I pasted the schema and seed into the SQL Editor myself. It took two minutes, and I now know what's actually in the back room.
- The public ("publishable") key is meant to ship inside the app. It's the front-door pass; the database rules decide what comes through. The secret key is the one to guard.

**Next**

- Add a captcha to anonymous sign-ins before the app is shared widely, so bots can't burn through the free quota.
- Tune hook timings by ear, and add Instagram links.

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
