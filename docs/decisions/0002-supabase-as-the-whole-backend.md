# 2. Supabase is the whole backend

Date: 2026-11-08 · Status: accepted

## Context

The backend has to serve a small catalogue (songs, hooks, a weekly chart, home rails) and one piece of user data (Saved). It should cost nothing to run, be quick to change, and be easy for someone reading the repo to understand.

## Options

- **Static JSON on a CDN.** Cheapest, but Saved would live only on the device and charts would need a rebuild per update.
- **Custom API (Node on Vercel/Cloudflare) + a database.** More code to host and maintain, and nothing it does that Postgres can't.
- **Supabase.** Postgres with an auto-generated REST API, auth and row level security. The free tier covers this easily.

## Decision

Supabase, with the logic in SQL: tables with strict constraints, RLS for permissions, one view (`hook_cards`) that shapes every hook the same way, and three small functions for the screens (`get_home`, `get_feed`, `toggle_save`).

## Trade-offs

- No server code to deploy. The schema is the API.
- Logic in SQL is less familiar to front-end readers, so the API doc spells out every call.
- Free projects pause after a week of no traffic. Fine for a portfolio; a weekly ping would keep it awake.
