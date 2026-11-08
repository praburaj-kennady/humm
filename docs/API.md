# API

Supabase generates a REST API from the schema. Everything below works with the project's **anon key**; the app never needs a secret key.

```
BASE = https://<project>.supabase.co/rest/v1
headers: apikey: <anon key>, Authorization: Bearer <anon key or user JWT>
```

With `supabase-js`:

```js
import { createClient } from '@supabase/supabase-js'
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

// Give every listener a user id, no sign-up screen. Needed for Saved.
await supabase.auth.signInAnonymously()
```

## Browse: `get_home`

One call for the whole home screen.

```js
const { data: home } = await supabase.rpc('get_home', { p_rail_limit: 20 })
```

```jsonc
{
  "chart": { "week_start": "2026-11-02", "title": "This week's top hooks", "is_sample": true },
  "rails": [
    { "slug": "top-this-week", "title": "Top hooks this week", "subtitle": "…", "kind": "chart",
      "hooks": [ /* hook cards, ranked */ ] },
    { "slug": "anirudh-on-repeat", "kind": "curated", "hooks": [ … ] },
    { "slug": "dance-floor", "kind": "mood", "hooks": [ … ] }
  ],
  "saved": [ /* your saved hook cards, newest first; null if not signed in */ ]
}
```

Rails with no hooks are left out. `p_rail_limit` is clamped to 1 to 50.

## Listen: `get_feed`

The full-screen swipe feed. Returns hook cards in play order.

```js
await supabase.rpc('get_feed', { p_rail: 'dance-floor', p_limit: 30 }) // a rail
await supabase.rpc('get_feed', { p_rail: 'saved' })                    // your Saved list
await supabase.rpc('get_feed')                                          // everything, chart first
```

## Save: `toggle_save`

```js
const { data: isSaved } = await supabase.rpc('toggle_save', { p_hook_id: hook.id })
```

Returns `true` if the hook is now saved, `false` if it was removed. Fails with `28000` when not signed in.

You can also read `saves` directly; RLS only ever shows your own rows.

## Hook card

Every hook comes back in the same shape (the `hook_cards` view):

| Field | Notes |
|---|---|
| `id`, `slug`, `label`, `lyric_line` | `label` is the card title, e.g. *The "Kaavaalaa" chorus* |
| `source`, `source_id` | `youtube` + video id, or `instagram` + reel shortcode |
| `start_ms`, `end_ms`, `duration_ms` | The hook's range inside the video |
| `timing_verified` | `false` while the timings are rough guesses |
| `song_title`, `song_title_ta`, `movie`, `release_year`, `composer`, `singers` | Song info |
| `moods` | Mood slugs, e.g. `["dance","feel-good"]` |
| `trend_rank`, `last_week_rank` | From this week's chart; `null` if not charting. `last_week_rank = null` on a charting hook means it's new |
| `embed_url` | Ready for an iframe. YouTube embeds start and stop at the hook |
| `thumbnail_url` | YouTube thumbnail (null for Instagram) |
| `source_url` | Opens the video at the hook |
| `full_song_url` | Source sheet: the full song on YouTube |
| `top_reel_url` | Source sheet: the top Reel using this hook (may be null) |
| `make_reel_url` | Instagram audio page for "Make a reel" (may be null) |

### Playing a hook

`embed_url` already has `start` and `end`, which is enough for a simple iframe. For the Feed, use the [YouTube IFrame Player API](https://developers.google.com/youtube/iframe_api_reference) with `startSeconds: start_ms / 1000` and `endSeconds: end_ms / 1000`, and listen for `ENDED` to loop or swipe to the next hook.

Instagram embeds can't seek, so an Instagram hook plays the whole reel.

## Writing to the catalogue

The public API is read-only. Add songs and hooks in Supabase Studio, with SQL using the service role, or by editing `supabase/seed.sql`. A hook only shows up once `status = 'published'`.
