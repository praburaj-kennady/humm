#!/usr/bin/env bash
# Spins up a throwaway Postgres, applies the migration + seed, runs the API tests.
# PREVIEW=1 also prints what get_home returns.
# Needs Postgres 15+ binaries on PATH (or PG_BIN set). No Docker, no Supabase CLI.
set -euo pipefail
cd "$(dirname "$0")/.."

PG_BIN="${PG_BIN:-$(dirname "$(command -v postgres || echo /usr/lib/postgresql/16/bin/postgres)")}"
DATA="$(mktemp -d)"
PORT="${PORT:-54329}"
RUN_AS=()
if [ "$(id -u)" = 0 ]; then chown postgres "$DATA"; RUN_AS=(sudo -u postgres); fi

cleanup() { "${RUN_AS[@]}" "$PG_BIN/pg_ctl" -D "$DATA" stop -m fast >/dev/null 2>&1 || true; rm -rf "$DATA"; }
trap cleanup EXIT

"${RUN_AS[@]}" "$PG_BIN/initdb" -D "$DATA" -U postgres -A trust >/dev/null
"${RUN_AS[@]}" "$PG_BIN/pg_ctl" -D "$DATA" -o "-p $PORT -k /tmp -c listen_addresses=''" -w start >/dev/null

PSQL=(psql -h /tmp -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1 -q)
"${PSQL[@]}" -f tests/supabase_stub.sql
for f in supabase/migrations/*.sql; do "${PSQL[@]}" -f "$f"; done
"${PSQL[@]}" -f supabase/seed.sql
"${PSQL[@]}" -f tests/api_test.sql
if [ -n "${PREVIEW:-}" ]; then "${PSQL[@]}" -c "set role anon; select jsonb_pretty(public.get_home(2));"; fi
