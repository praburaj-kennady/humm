# 1. Play hooks through official embeds, never host audio

Date: 2026-11-08 · Status: accepted

## Context

The app plays the best part of a song. The obvious build is to cut that part out and stream it. That means hosting copyrighted audio, which needs licences from labels. This is a portfolio project and will never approach labels.

## Decision

Every hook is a pointer: a YouTube video id or Instagram reel shortcode plus a start and end time. Playback goes through the platform's own embed player. The database stores no audio and no video.

## Trade-offs

- Plays and views count for the original upload, and the artist keeps the ad revenue.
- No background play. Embeds stop when the app is in the background. A future Apple Music mode could fix this for subscribers.
- Instagram embeds can't seek, so an Instagram hook plays the whole reel. Most hooks should point at YouTube.
- If a video is taken down, the hook breaks. A periodic check for dead embeds is a later job.
