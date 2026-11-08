-- Sample data for Humm.
--
-- What's real: song titles, movies, composers, singers and the YouTube video
-- ids (official uploads by Sun TV, Sony Music South, Think Music and others).
-- What's NOT real yet:
--   * hook start/end times are rough guesses (timing_verified = false);
--     tune them by ear before showing anyone.
--   * the weekly chart ranks are invented (charts.is_sample = true).
--   * no Instagram reel or audio links, so "Make a reel" is empty for now.

begin;

insert into public.moods (slug, label, position) values
  ('dance',     'Dance floor', 1),
  ('mass',      'Mass',        2),
  ('feel-good', 'Feel good',   3),
  ('throwback', 'Throwback',   4);

insert into public.songs (slug, title, title_ta, movie, release_year, composer, singers, full_song_youtube_id) values
  ('kaavaalaa',     'Kaavaalaa',            'காவாலா',          'Jailer',    2023, 'Anirudh Ravichander',  '{"Shilpa Rao","Anirudh Ravichander"}',                         'lM8h5Mm6ODo'),
  ('arabic-kuthu',  'Arabic Kuthu',         'அரபிக் குத்து',    'Beast',     2022, 'Anirudh Ravichander',  '{"Anirudh Ravichander","Jonita Gandhi"}',                      'KUN5Uf9mObQ'),
  ('rowdy-baby',    'Rowdy Baby',           'ரவுடி பேபி',       'Maari 2',   2018, 'Yuvan Shankar Raja',   '{"Dhanush","Dhee"}',                                           'x6Q7c9RyMzk'),
  ('vaathi-coming', 'Vaathi Coming',        'வாத்தி கம்மிங்',    'Master',    2021, 'Anirudh Ravichander',  '{"Anirudh Ravichander","Gana Balachandar"}',                   'fRD_3vJagxk'),
  ('why-this-kolaveri-di', 'Why This Kolaveri Di', 'வொய் திஸ் கொலவெறி டி', '3', 2011, 'Anirudh Ravichander', '{"Dhanush"}',                                      'YR12Z8f1Dh8'),
  ('naa-ready',     'Naa Ready',            'நா ரெடி',          'Leo',       2023, 'Anirudh Ravichander',  '{"Vijay","Anirudh Ravichander","Asal Kolaar"}',               'szvt1vD0Uug'),
  ('manasilaayo',   'Manasilaayo',          'மனசிலாயோ',        'Vettaiyan', 2024, 'Anirudh Ravichander',  '{"Malaysia Vasudevan","Yugendran Vasudevan","Anirudh Ravichander","Deepthi Suresh"}', '5WsUIeNAtbM'),
  ('golden-sparrow','Golden Sparrow',       null,               'Nilavuku En Mel Ennadi Kobam', 2025, 'G. V. Prakash Kumar', '{}',                              'AAq06bS8UZM');

-- Hooks. Times are in milliseconds and are rough until timing_verified = true.
insert into public.hooks (song_id, slug, label, lyric_line, source, source_id, start_ms, end_ms, status, published_at)
select s.id, v.slug, v.label, v.lyric_line, 'youtube', v.source_id, v.start_ms, v.end_ms, v.status::public.hook_status,
       case when v.status = 'published' then now() - v.age end
from (values
  ('kaavaalaa',            'kaavaalaa-chorus',        'The "Kaavaalaa" chorus',      'Nuvvu kaavaalayya',      'lM8h5Mm6ODo',  52000,  74000, 'published', interval '30 days'),
  ('arabic-kuthu',         'arabic-kuthu-halamithi',  'Halamithi Habibo',            'Halamithi habibo',       'KUN5Uf9mObQ',  38000,  60000, 'published', interval '60 days'),
  ('rowdy-baby',           'rowdy-baby-chorus',       'The "Rowdy Baby" chorus',     'Hey en goli soda-ve',    'x6Q7c9RyMzk',  44000,  66000, 'published', interval '90 days'),
  ('vaathi-coming',        'vaathi-coming-drop',      'The Vaathi Coming drop',      'Vaathi coming, othu',    'fRD_3vJagxk',  60000,  82000, 'published', interval '45 days'),
  ('why-this-kolaveri-di', 'kolaveri-opening',        'Soup song opening',           'Why this kolaveri di',   'YR12Z8f1Dh8',  20000,  45000, 'published', interval '120 days'),
  ('naa-ready',            'naa-ready-hook',          'The "Naa Ready" call',        'Naa ready dhaan varava', 'szvt1vD0Uug',  30000,  52000, 'published', interval '20 days'),
  ('manasilaayo',          'manasilaayo-chorus',      'The "Manasilaayo" chorus',    'Manasilaayo',            '5WsUIeNAtbM',  40000,  62000, 'published', interval '10 days'),
  ('golden-sparrow',       'golden-sparrow-chorus',   'The "Golden Sparrow" chorus', 'Golden sparrow',         'AAq06bS8UZM',  35000,  57000, 'published', interval '5 days'),
  -- Two hooks can come from the same song: the lyric video's version.
  ('arabic-kuthu',         'arabic-kuthu-lyric-drop', 'Halamithi Habibo (lyric video)', null,                  '8FAUEv_E_xQ',  40000,  62000, 'published', interval '58 days'),
  -- A draft, to prove drafts stay hidden from the app.
  ('naa-ready',            'naa-ready-bridge-draft',  'Bridge (draft)',              null,                     'szvt1vD0Uug',  95000, 115000, 'draft',     interval '0 days')
) as v(song_slug, slug, label, lyric_line, source_id, start_ms, end_ms, status, age)
join public.songs s on s.slug = v.song_slug;

insert into public.hook_moods (hook_id, mood_slug)
select h.id, v.mood
from (values
  ('kaavaalaa-chorus', 'dance'), ('kaavaalaa-chorus', 'feel-good'),
  ('arabic-kuthu-halamithi', 'dance'),
  ('arabic-kuthu-lyric-drop', 'dance'),
  ('rowdy-baby-chorus', 'dance'), ('rowdy-baby-chorus', 'feel-good'),
  ('vaathi-coming-drop', 'mass'), ('vaathi-coming-drop', 'dance'),
  ('kolaveri-opening', 'throwback'), ('kolaveri-opening', 'feel-good'),
  ('naa-ready-hook', 'mass'),
  ('manasilaayo-chorus', 'dance'), ('manasilaayo-chorus', 'feel-good'),
  ('golden-sparrow-chorus', 'feel-good'),
  ('naa-ready-bridge-draft', 'mass')
) as v(hook_slug, mood)
join public.hooks h on h.slug = v.hook_slug;

-- One sample weekly chart (Monday 2 Nov 2026). Ranks are made up.
insert into public.charts (week_start, title, is_sample, published_at)
values ('2026-11-02', 'This week''s top hooks', true, '2026-11-02 06:00+05:30');

insert into public.chart_entries (chart_id, rank, hook_id, last_week_rank)
select c.id, v.rank, h.id, v.last_week_rank
from (values
  (1, 'manasilaayo-chorus',     3),
  (2, 'golden-sparrow-chorus',  null),
  (3, 'kaavaalaa-chorus',       1),
  (4, 'naa-ready-hook',         2),
  (5, 'vaathi-coming-drop',     5)
) as v(rank, hook_slug, last_week_rank)
join public.hooks h on h.slug = v.hook_slug
cross join (select id from public.charts where week_start = '2026-11-02') c;

-- Home screen rows, top to bottom.
insert into public.rails (slug, title, subtitle, kind, mood_slug, position) values
  ('top-this-week',    'Top hooks this week', 'What Reels can''t stop using',    'chart',   null,        1),
  ('anirudh-on-repeat','Anirudh on repeat',   'Hand-picked',                      'curated', null,        2),
  ('dance-floor',      'Dance floor',         null,                               'mood',    'dance',     3),
  ('mass',             'Mass',                'Hero-entry energy',                'mood',    'mass',      4),
  ('throwback',        'Throwback',           'Before Reels, there was Bluetooth', 'mood',   'throwback', 5);

insert into public.rail_items (rail_slug, hook_id, position)
select 'anirudh-on-repeat', h.id, v.pos
from (values
  (1, 'kaavaalaa-chorus'), (2, 'arabic-kuthu-halamithi'), (3, 'vaathi-coming-drop'),
  (4, 'manasilaayo-chorus'), (5, 'naa-ready-hook'), (6, 'kolaveri-opening')
) as v(pos, hook_slug)
join public.hooks h on h.slug = v.hook_slug;

commit;
