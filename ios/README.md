# Hummm for iPhone

The native app. SwiftUI, iOS 17 and up, no third-party packages.

## Run it on your Mac

You need a Mac with **Xcode 16 or newer** (free on the Mac App Store).

1. Download the code: on GitHub, **Code → Download ZIP**, then unzip it. (Or `git clone https://github.com/praburaj-kennady/hummm`.)
2. Open `ios/Hummm.xcodeproj`. Xcode opens the project.
3. At the top of the window, pick an iPhone simulator (for example *iPhone 16 Pro*).
4. Press **⌘R** (or the ▶ button). The simulator starts and the app opens.

Without any settings it runs on **demo data** (the seed songs) and says *Demo data* in the corner. Saves stay on the phone.

## Connect it to the live backend

1. Copy `ios/Supabase.example.plist` into the `ios/Hummm/` folder and rename it `Supabase.plist`.
2. Open it and fill in the two values from Supabase (**Project Settings → API Keys**): the project URL and the **publishable** key (starts with `sb_publishable_`). Never the secret key.
3. Run again. The *Demo data* pill disappears, Browse loads from Supabase, and saves go to your database.

`Supabase.plist` is git-ignored, so the values never land in this public repo. (The publishable key is designed to ship inside apps; the database's row level security decides what it can do.)

## Run it on your own iPhone

1. Plug the iPhone in and pick it at the top of Xcode instead of a simulator.
2. Click the **Hummm** project → **Signing & Capabilities** → choose your Apple ID as the Team. A free Apple ID works; the app then lasts 7 days before you run it again.
3. Press **⌘R**. The first time, the iPhone asks you to trust the developer in **Settings → General → VPN & Device Management**.

## How it's put together

| File | What it does |
|---|---|
| `HummmApp.swift` | Starts the app. `RootView` stacks Browse, the mini player and Listen. |
| `Views/BrowseView.swift` | The home screen: mood pills, Trending, Saved, By composer, the other rails. |
| `Views/MiniPlayerView.swift` | What's playing, docked at the bottom. Tap to open Listen. |
| `Views/ListenView.swift` | The full-screen feed. Swipe up for the next hook, drag down to go back. |
| `Views/SourceSheet.swift` | "Where this hook is from": top Reel, full song, Make a reel. |
| `Views/SearchView.swift` | Search by song, movie, composer, singer or mood. |
| `Player.swift` | One player for the whole app. Keeps the queue and loops the hook. |
| `YouTubePlayer.swift` | The YouTube embed in a web view, and the messages to and from it. |
| `Backend.swift` | The three calls to Supabase, the anonymous sign-in, and demo mode. |
| `Library.swift` | Browse data and your Saved list, shared by every screen. |
| `Theme.swift` | Colours from the Figma variables, press feedback, small formatters. |

Motion follows the notes in the Figma file: swipes settle on a spring (0.45s, bounce 0.15), a quick flick moves on even after a short drag, Listen opens in 380ms on the iOS sheet curve and closes in 260ms, buttons press to 0.95. With Reduce Motion on, slides become simple swaps.

## Known limits

- **No background play.** YouTube's player stops when the app goes to the background ([decision 1](../docs/decisions/0001-embeds-only.md)).
- **Instagram hooks** open in Instagram, because its embed can't be controlled from the app. All seed hooks are YouTube.
- Some videos don't allow playing inside other apps. The app says so and offers *Open on YouTube*.
