# 4. Native iPhone app first

Date: 2026-11-08 · Status: accepted

## Context

The design is iOS-first (Apple's patterns, SF Symbols, a sheet that drags down like the Music app). The app could be built as a web page that looks like an iPhone app, which is easy to share as a link, or as a real SwiftUI app.

## Decision

Build the native SwiftUI app first.

## Trade-offs

- It feels like a real iPhone app: native sheets, haptics, springs, SF Symbols, the system font.
- YouTube can start playing on its own inside the app's web view, which mobile browsers block.
- Running it needs Xcode on a Mac, and sharing it with others needs TestFlight. A shareable web version can come later.
- No third-party packages: the app talks to Supabase with plain HTTPS calls, so there's nothing to install or update.
