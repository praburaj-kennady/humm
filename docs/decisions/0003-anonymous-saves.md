# 3. Saved works without sign-up

Date: 2026-11-08 · Status: accepted

## Context

The design has a Saved area on Browse. A sign-up screen before you can save a hook would kill the one-tap feel.

## Decision

The app calls Supabase `signInAnonymously()` on first launch. That gives every listener a real user id, so saves live in the database behind RLS. If we later add "keep your saves across devices", linking an email or Apple ID to the anonymous user keeps the same id and the same saves.

## Trade-offs

- Reinstalling the app or clearing storage loses an anonymous user's saves, until account linking exists.
- Anonymous users count toward Supabase's monthly active users. The free tier allows 50,000, far beyond what a portfolio needs.
