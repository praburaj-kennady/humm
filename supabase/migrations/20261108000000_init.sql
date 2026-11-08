-- Humm: the best part of Tamil songs, played through YouTube / Instagram embeds.
--
-- The app never stores or cuts audio. A "hook" is just metadata:
-- which video, where the good part starts and ends, and what it feels like.
--
-- Read access is public (anyone can browse). Writes to the catalogue happen
-- only with the service role (Supabase Studio, seed, or a future admin tool).
-- The one thing listeners write is their own Saved list, via anonymous auth.

------------------------------------------------------------------------------
-- Types
------------------------------------------------------------------------------

create type public.hook_source as enum ('youtube', 'instagram');
create type public.hook_status as enum ('draft', 'published', 'hidden');
create type public.rail_kind   as enum ('chart', 'mood', 'curated');

------------------------------------------------------------------------------
-- Songs: the full track a hook comes from
------------------------------------------------------------------------------

create table public.songs (
  id                   uuid primary key default gen_random_uuid(),
  slug                 text not null unique
                         check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  title                text not null check (length(title) between 1 and 200),
  title_ta             text check (length(title_ta) <= 200),     -- title in Tamil script
  movie                text check (length(movie) <= 200),         -- null for indie singles
  release_year         smallint check (release_year between 1930 and 2100),
  composer             text check (length(composer) <= 200),
  singers              text[] not null default '{}',
  -- The full song on YouTube, for the Source sheet's "Full song" link.
  full_song_youtube_id text check (full_song_youtube_id ~ '^[A-Za-z0-9_-]{11}$'),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

------------------------------------------------------------------------------
-- Moods: a small fixed vocabulary that drives the mood rails
------------------------------------------------------------------------------

create table public.moods (
  slug     text primary key check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  label    text not null check (length(label) between 1 and 40),
  position smallint not null default 0
);

------------------------------------------------------------------------------
-- Hooks: the best part of a song, as a time range inside an embeddable video
------------------------------------------------------------------------------

create table public.hooks (
  id              uuid primary key default gen_random_uuid(),
  song_id         uuid not null references public.songs (id) on delete cascade,
  slug            text not null unique
                    check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  label           text not null check (length(label) between 1 and 120), -- e.g. "The 'Kaavaalaa' chorus"
  lyric_line      text check (length(lyric_line) <= 200),                  -- the line people sing along to

  source          public.hook_source not null,
  -- YouTube: 11-char video id. Instagram: the reel shortcode from /reel/<code>/.
  source_id       text not null,
  start_ms        integer not null check (start_ms >= 0),
  end_ms          integer not null,

  -- Source sheet + "Make a reel"
  top_reel_url    text check (top_reel_url   ~ '^https://(www\.)?instagram\.com/(reel|p)/[A-Za-z0-9_-]+/?$'),
  reel_audio_url  text check (reel_audio_url ~ '^https://(www\.)?instagram\.com/reels/audio/[0-9]+/?$'),

  -- Sample data ships with rough timings. Flip this once someone has listened.
  timing_verified boolean not null default false,
  status          public.hook_status not null default 'draft',
  published_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint hooks_range_valid
    check (end_ms > start_ms and end_ms - start_ms between 5000 and 90000),
  constraint hooks_source_id_shape check (
    (source = 'youtube'   and source_id ~ '^[A-Za-z0-9_-]{11}$') or
    (source = 'instagram' and source_id ~ '^[A-Za-z0-9_-]{5,40}$')
  ),
  constraint hooks_published_has_date
    check (status <> 'published' or published_at is not null)
);

create index hooks_song_id_idx on public.hooks (song_id);
-- The same clip should not be entered twice.
create unique index hooks_source_clip_uidx on public.hooks (source, source_id, start_ms);
create index hooks_published_idx on public.hooks (published_at desc) where status = 'published';

create table public.hook_moods (
  hook_id   uuid not null references public.hooks (id) on delete cascade,
  mood_slug text not null references public.moods (slug) on update cascade on delete cascade,
  primary key (hook_id, mood_slug)
);
create index hook_moods_mood_idx on public.hook_moods (mood_slug);

------------------------------------------------------------------------------
-- Weekly chart: "trend rank" lives here, one row per hook per week
------------------------------------------------------------------------------

create table public.charts (
  id           uuid primary key default gen_random_uuid(),
  week_start   date not null unique check (extract(isodow from week_start) = 1), -- Mondays
  title        text not null default 'This week' check (length(title) <= 80),
  is_sample    boolean not null default false,  -- true while the ranks are made up
  published_at timestamptz,
  created_at   timestamptz not null default now()
);

create table public.chart_entries (
  chart_id       uuid not null references public.charts (id) on delete cascade,
  rank           smallint not null check (rank between 1 and 100),
  hook_id        uuid not null references public.hooks (id) on delete restrict,
  last_week_rank smallint check (last_week_rank between 1 and 100),  -- null = new entry
  primary key (chart_id, rank),
  unique (chart_id, hook_id)
);
create index chart_entries_hook_idx on public.chart_entries (hook_id);

------------------------------------------------------------------------------
-- Browse rails: the rows on the home screen, in order
------------------------------------------------------------------------------

create table public.rails (
  slug      text primary key check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  title     text not null check (length(title) between 1 and 60),
  subtitle  text check (length(subtitle) <= 120),
  kind      public.rail_kind not null,
  mood_slug text references public.moods (slug) on update cascade on delete cascade,
  position  smallint not null,
  is_active boolean not null default true,
  constraint rails_mood_matches_kind check ((kind = 'mood') = (mood_slug is not null))
);
create unique index rails_position_uidx on public.rails (position) where is_active;

-- Hand-picked order for 'curated' rails.
create table public.rail_items (
  rail_slug text not null references public.rails (slug) on update cascade on delete cascade,
  hook_id   uuid not null references public.hooks (id) on delete cascade,
  position  smallint not null,
  primary key (rail_slug, hook_id),
  unique (rail_slug, position)
);
create index rail_items_hook_idx on public.rail_items (hook_id);

------------------------------------------------------------------------------
-- Saves: a listener's Saved list. Users are Supabase anonymous users, so
-- nobody has to sign up; linking an email later keeps the same user id.
------------------------------------------------------------------------------

create table public.saves (
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  hook_id    uuid not null references public.hooks (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, hook_id)
);
create index saves_hook_idx on public.saves (hook_id);
create index saves_user_recent_idx on public.saves (user_id, created_at desc);

------------------------------------------------------------------------------
-- updated_at bookkeeping
------------------------------------------------------------------------------

create function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger songs_touch before update on public.songs
  for each row execute function public.touch_updated_at();
create trigger hooks_touch before update on public.hooks
  for each row execute function public.touch_updated_at();

------------------------------------------------------------------------------
-- Row level security
------------------------------------------------------------------------------

alter table public.songs         enable row level security;
alter table public.moods         enable row level security;
alter table public.hooks         enable row level security;
alter table public.hook_moods    enable row level security;
alter table public.charts        enable row level security;
alter table public.chart_entries enable row level security;
alter table public.rails         enable row level security;
alter table public.rail_items    enable row level security;
alter table public.saves         enable row level security;

-- Catalogue: anyone can read what is published. No write policies, so only
-- the service role (which bypasses RLS) can change it.
create policy "songs are public"  on public.songs for select to anon, authenticated using (true);
create policy "moods are public"  on public.moods for select to anon, authenticated using (true);
create policy "rails are public"  on public.rails for select to anon, authenticated using (is_active);

create policy "published hooks are public" on public.hooks
  for select to anon, authenticated using (status = 'published');

create policy "moods of published hooks are public" on public.hook_moods
  for select to anon, authenticated
  using (exists (select 1 from public.hooks h where h.id = hook_id and h.status = 'published'));

create policy "published charts are public" on public.charts
  for select to anon, authenticated using (published_at is not null and published_at <= now());

create policy "entries of published charts are public" on public.chart_entries
  for select to anon, authenticated
  using (exists (select 1 from public.charts c
                 where c.id = chart_id and c.published_at is not null and c.published_at <= now()));

create policy "rail items are public" on public.rail_items
  for select to anon, authenticated using (true);

-- Saves: you see and change only your own.
create policy "read own saves"   on public.saves for select to authenticated using (user_id = (select auth.uid()));
create policy "add own saves"    on public.saves for insert to authenticated with check (user_id = (select auth.uid()));
create policy "remove own saves" on public.saves for delete to authenticated using (user_id = (select auth.uid()));

-- Table privileges: read-only catalogue, saves writable by signed-in users.
revoke all on all tables in schema public from anon, authenticated;
grant select on public.songs, public.moods, public.hooks, public.hook_moods,
                public.charts, public.chart_entries, public.rails, public.rail_items
  to anon, authenticated;
grant select, insert, delete on public.saves to authenticated;
-- anon needs SELECT so get_home/get_feed can plan; RLS still returns no rows.
grant select on public.saves to anon;

------------------------------------------------------------------------------
-- API: what the app actually calls
------------------------------------------------------------------------------

-- The latest published chart's ranks. "Trend rank" for any hook comes from here.
create view public.current_chart_entries
with (security_invoker = true) as
select ce.hook_id, ce.rank, ce.last_week_rank, c.week_start, c.title as chart_title, c.is_sample
from public.chart_entries ce
join public.charts c on c.id = ce.chart_id
where c.id = (
  select id from public.charts
  where published_at is not null and published_at <= now()
  order by week_start desc
  limit 1
);

-- One row per published hook, with everything a card, the Feed and the
-- Source sheet need. Embed and link URLs are built here so every client
-- builds them the same way.
create view public.hook_cards
with (security_invoker = true) as
select
  h.id,
  h.slug,
  h.label,
  h.lyric_line,
  h.source,
  h.source_id,
  h.start_ms,
  h.end_ms,
  (h.end_ms - h.start_ms)                        as duration_ms,
  h.timing_verified,
  h.published_at,
  s.id                                           as song_id,
  s.slug                                         as song_slug,
  s.title                                        as song_title,
  s.title_ta                                     as song_title_ta,
  s.movie,
  s.release_year,
  s.composer,
  s.singers,
  coalesce(
    (select array_agg(hm.mood_slug order by m.position)
       from public.hook_moods hm join public.moods m on m.slug = hm.mood_slug
      where hm.hook_id = h.id),
    '{}'::text[])                                as moods,
  cc.rank                                        as trend_rank,
  cc.last_week_rank,
  -- Player: YouTube IFrame embed clipped to the hook. Instagram embeds can't
  -- seek, so the reel is the whole clip.
  case h.source
    when 'youtube' then format(
      'https://www.youtube-nocookie.com/embed/%s?start=%s&end=%s&playsinline=1&rel=0&modestbranding=1',
      h.source_id, h.start_ms / 1000, ceil(h.end_ms / 1000.0)::int)
    when 'instagram' then format('https://www.instagram.com/reel/%s/embed', h.source_id)
  end                                            as embed_url,
  case h.source
    when 'youtube'   then format('https://i.ytimg.com/vi/%s/hqdefault.jpg', h.source_id)
  end                                            as thumbnail_url,
  -- Source sheet
  h.top_reel_url,
  case
    when s.full_song_youtube_id is not null
      then format('https://www.youtube.com/watch?v=%s', s.full_song_youtube_id)
    when h.source = 'youtube'
      then format('https://www.youtube.com/watch?v=%s', h.source_id)
  end                                            as full_song_url,
  case h.source
    when 'youtube'   then format('https://www.youtube.com/watch?v=%s&t=%ss', h.source_id, h.start_ms / 1000)
    when 'instagram' then format('https://www.instagram.com/reel/%s/', h.source_id)
  end                                            as source_url,
  -- "Make a reel": straight to the Instagram audio page when we know it.
  h.reel_audio_url                               as make_reel_url
from public.hooks h
join public.songs s on s.id = h.song_id
left join public.current_chart_entries cc on cc.hook_id = h.id
where h.status = 'published';

-- Supabase's default privileges grant everything on new objects; views are read-only here.
revoke all on public.current_chart_entries, public.hook_cards from anon, authenticated;
grant select on public.current_chart_entries, public.hook_cards to anon, authenticated;

-- Home screen in one call: the chart, every active rail with its hooks, and
-- (when signed in) the listener's Saved list.
create function public.get_home(p_rail_limit integer default 20)
returns jsonb
language sql stable security invoker set search_path = ''
as $$
  with lim as (select least(greatest(coalesce(p_rail_limit, 20), 1), 50) as n),
  rail_hooks as (
    -- chart rail: by rank
    select r.slug as rail_slug, hc.id as hook_id, hc.trend_rank::int as ord
    from public.rails r
    join public.hook_cards hc on hc.trend_rank is not null
    where r.kind = 'chart'
    union all
    -- mood rails: charting hooks first, then newest
    select r.slug, hc.id,
           (row_number() over (partition by r.slug
              order by hc.trend_rank nulls last, hc.published_at desc))::int
    from public.rails r
    join public.hook_cards hc on r.mood_slug = any (hc.moods)
    where r.kind = 'mood'
    union all
    -- curated rails: hand-picked order
    select r.slug, ri.hook_id, ri.position::int
    from public.rails r
    join public.rail_items ri on ri.rail_slug = r.slug
    where r.kind = 'curated'
  ),
  ranked as (
    select rail_slug, hook_id,
           row_number() over (partition by rail_slug order by ord) as pos
    from rail_hooks
  )
  select jsonb_build_object(
    'chart', (
      select jsonb_build_object('week_start', week_start, 'title', chart_title, 'is_sample', is_sample)
      from public.current_chart_entries limit 1),
    'rails', coalesce((
      select jsonb_agg(jsonb_build_object(
               'slug', r.slug, 'title', r.title, 'subtitle', r.subtitle, 'kind', r.kind,
               'hooks', (
                 select coalesce(jsonb_agg(to_jsonb(hc) order by k.pos), '[]'::jsonb)
                 from ranked k join public.hook_cards hc on hc.id = k.hook_id
                 where k.rail_slug = r.slug and k.pos <= (select n from lim)))
             order by r.position)
      from public.rails r
      where exists (select 1 from ranked k where k.rail_slug = r.slug)), '[]'::jsonb),
    'saved', case when (select auth.uid()) is null then null else coalesce((
      select jsonb_agg(to_jsonb(hc) order by sv.created_at desc)
      from public.saves sv join public.hook_cards hc on hc.id = sv.hook_id
      where sv.user_id = (select auth.uid())), '[]'::jsonb) end
  );
$$;

-- The full-screen swipe Feed. With a rail, plays that rail in order; without,
-- plays the chart first and then everything else, newest first.
create function public.get_feed(p_rail text default null, p_limit integer default 30)
returns setof public.hook_cards
language sql stable security invoker set search_path = ''
as $$
  select hc.*
  from public.hook_cards hc
  left join public.rails r on r.slug = p_rail
  left join public.rail_items ri on ri.rail_slug = r.slug and r.kind = 'curated' and ri.hook_id = hc.id
  left join public.saves sv on p_rail = 'saved' and sv.hook_id = hc.id and sv.user_id = (select auth.uid())
  where p_rail is null
     or (p_rail = 'saved' and sv.hook_id is not null)
     or (r.kind = 'chart'   and hc.trend_rank is not null)
     or (r.kind = 'mood'    and r.mood_slug = any (hc.moods))
     or (r.kind = 'curated' and ri.hook_id is not null)
  order by
    case when p_rail = 'saved' then sv.created_at end desc nulls last,
    ri.position nulls last,
    hc.trend_rank nulls last,
    hc.published_at desc,
    hc.id
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
$$;

-- Save / unsave in one tap. Returns true when the hook is now saved.
create function public.toggle_save(p_hook_id uuid)
returns boolean
language plpgsql volatile security invoker set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'sign in (anonymous is fine) before saving' using errcode = '28000';
  end if;
  if not exists (select 1 from public.hooks where id = p_hook_id and status = 'published') then
    raise exception 'hook % not found', p_hook_id using errcode = 'P0002';
  end if;

  delete from public.saves where user_id = v_user and hook_id = p_hook_id;
  if found then
    return false;
  end if;

  insert into public.saves (user_id, hook_id) values (v_user, p_hook_id)
  on conflict do nothing;
  return true;
end $$;

revoke execute on function public.get_home(integer), public.get_feed(text, integer),
                           public.toggle_save(uuid), public.touch_updated_at()
  from public, anon, authenticated;
grant execute on function public.get_home(integer), public.get_feed(text, integer) to anon, authenticated;
grant execute on function public.toggle_save(uuid) to authenticated;
