-- End-to-end checks of the API as the app sees it (anon and signed-in roles).
-- Runs inside a transaction and rolls back. Any failed assert aborts the run.
\set ON_ERROR_STOP on
begin;

insert into auth.users (id) values
  ('00000000-0000-0000-0000-00000000000a'),
  ('00000000-0000-0000-0000-00000000000b');

-------------------------------------------------------------------- anon
set local role anon;

do $$
declare home jsonb; n int;
begin
  -- Drafts never reach the app.
  select count(*) into n from public.hooks where status <> 'published';
  assert n = 0, 'anon can see draft hooks';
  select count(*) into n from public.hook_cards;
  assert n = 9, format('expected 9 published hook cards, got %s', n);

  -- Embed URL is clipped to the hook.
  assert (select embed_url from public.hook_cards where slug = 'kaavaalaa-chorus')
       = 'https://www.youtube-nocookie.com/embed/lM8h5Mm6ODo?start=52&end=74&playsinline=1&rel=0&modestbranding=1',
       'embed url wrong';
  assert (select full_song_url from public.hook_cards where slug = 'kaavaalaa-chorus')
       = 'https://www.youtube.com/watch?v=lM8h5Mm6ODo', 'full song url wrong';

  -- Home: chart rail first, ranked; anon has no saved list.
  home := public.get_home();
  assert home->'chart'->>'is_sample' = 'true', 'chart should be marked sample';
  assert home->'rails'->0->>'slug' = 'top-this-week', 'first rail should be the chart';
  assert home->'rails'->0->'hooks'->0->>'slug' = 'manasilaayo-chorus', 'chart #1 wrong';
  assert jsonb_array_length(home->'rails'->0->'hooks') = 5, 'chart should have 5 hooks';
  assert home->'saved' = 'null'::jsonb, 'anon should get saved = null';
  assert jsonb_array_length(home->'rails') = 5, format('expected 5 rails, got %s', jsonb_array_length(home->'rails'));
  -- Curated rail keeps hand-picked order.
  assert home->'rails'->1->'hooks'->0->>'slug' = 'kaavaalaa-chorus', 'curated order wrong';
  -- Mood rail: charting hooks first.
  assert home->'rails'->2->'hooks'->0->>'slug' = 'manasilaayo-chorus', 'mood rail should lead with chart #1';
  -- Draft (mood "mass") is not in the Mass rail.
  assert not (home->'rails'->3->'hooks') @> '[{"slug":"naa-ready-bridge-draft"}]', 'draft leaked into rail';
  -- Rail limit works.
  assert jsonb_array_length(public.get_home(2)->'rails'->2->'hooks') = 2, 'rail limit ignored';

  -- Feed: no rail = chart first, then everything else.
  select count(*) into n from public.get_feed();
  assert n = 9, format('feed should have 9 hooks, got %s', n);
  assert (select slug from public.get_feed() limit 1) = 'manasilaayo-chorus', 'feed should start at chart #1';
  assert (select slug from public.get_feed('anirudh-on-repeat') limit 1) = 'kaavaalaa-chorus', 'curated feed order';
  select count(*) into n from public.get_feed('throwback');
  assert n = 1, 'throwback feed should have 1 hook';
  select count(*) into n from public.get_feed('no-such-rail');
  assert n = 0, 'unknown rail should be empty';
end $$;

-- Anon cannot write anything.
do $$ begin
  begin
    insert into public.songs (slug, title) values ('x', 'x');
    assert false, 'anon inserted a song';
  exception when insufficient_privilege then null; end;
  begin
    perform public.toggle_save((select id from public.hook_cards limit 1));
    assert false, 'anon could save';
  exception when insufficient_privilege then null; end;
end $$;

reset role;

-------------------------------------------------------------------- user A
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';

do $$
declare hk uuid; draft uuid;
begin
  select id into hk from public.hook_cards where slug = 'rowdy-baby-chorus';
  assert public.toggle_save(hk) = true,  'first toggle should save';
  assert public.toggle_save(hk) = false, 'second toggle should unsave';
  assert public.toggle_save(hk) = true,  'third toggle should save again';
  assert jsonb_array_length(public.get_home()->'saved') = 1, 'saved list should have 1';
  assert (select slug from public.get_feed('saved') limit 1) = 'rowdy-baby-chorus', 'saved feed';

  -- Can't save a draft (it's invisible).
  begin
    perform public.toggle_save('11111111-1111-1111-1111-111111111111');
    assert false, 'saved a missing hook';
  exception when no_data_found then null; end;

  -- Can't write a save for someone else.
  begin
    insert into public.saves (user_id, hook_id) values ('00000000-0000-0000-0000-00000000000b', hk);
    assert false, 'saved as another user';
  exception when insufficient_privilege then null; end;
end $$;

reset role;

-------------------------------------------------------------------- user B
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';

do $$ begin
  assert (select count(*) from public.saves) = 0, 'user B can see user A''s saves';
  assert public.get_home()->'saved' = '[]'::jsonb, 'user B saved list should be empty';
end $$;

reset role;

-------------------------------------------------------------------- constraints
do $$ begin
  begin
    insert into public.hooks (song_id, slug, label, source, source_id, start_ms, end_ms)
    select id, 'too-long', 'x', 'youtube', 'lM8h5Mm6ODo', 0, 200000 from public.songs limit 1;
    assert false, 'accepted a 200s hook';
  exception when check_violation then null; end;
  begin
    insert into public.hooks (song_id, slug, label, source, source_id, start_ms, end_ms)
    select id, 'bad-id', 'x', 'youtube', 'not-a-video-id!', 0, 20000 from public.songs limit 1;
    assert false, 'accepted a bad youtube id';
  exception when check_violation then null; end;
  begin
    update public.hooks set status = 'published', published_at = null where slug = 'naa-ready-bridge-draft';
    assert false, 'published without a date';
  exception when check_violation then null; end;
  begin
    insert into public.charts (week_start) values ('2026-11-04');
    assert false, 'chart week must start on Monday';
  exception when check_violation then null; end;
end $$;

rollback;
\echo 'All API tests passed'
