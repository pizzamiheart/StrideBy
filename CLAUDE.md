# StrideBy

## What This Is
An iOS app that plots your real-world running miles along famous global routes. You run in your neighborhood — your pin moves across the world. Connect Strava, pick a route (NYC to LA, London to Tokyo, etc.), and watch yourself "travel" one run at a time.

## Core Value Props
- Strava auto-sync via webhooks (zero friction after setup)
- See landmarks, Street View-style imagery via Apple Look Around
- Run with friends on shared routes — see everyone's pins in realtime
- Shareable "postcard" milestone cards at landmarks
- Passport stamps when you cross country/state borders

## Tech Stack
- **iOS app:** Swift 5.9+, SwiftUI, MapKit, HealthKit
- **Backend:** Supabase (Postgres, Edge Functions, Realtime, Auth, Storage)
- **APIs:** Strava API (OAuth + webhooks), Apple Push Notification service
- **Maps:** MapKit + Apple Look Around (both free)
- **Minimum target:** iOS 17

## Project Structure
```
StrideBy/                           # Xcode project root
├── StrideBy.xcodeproj/
├── StrideBy/                       # Main app target
│   ├── StrideByApp.swift           # App entry point
│   ├── ContentView.swift           # Root view (will become tab controller)
│   ├── Assets.xcassets/            # Colors, app icon, images
│   ├── Features/
│   │   ├── Auth/                   # Strava OAuth, onboarding
│   │   ├── Map/                    # Main map view, route rendering, Look Around
│   │   ├── Routes/                 # Route selection, route definitions
│   │   ├── Progress/               # Mileage tracking, pin position calculation
│   │   ├── Social/                 # Friends, shared routes, realtime pins
│   │   ├── Postcards/              # Milestone cards, sharing
│   │   └── Profile/                # User profile, stats, settings
│   └── Core/
│       ├── Models/                 # Data models
│       ├── Services/               # Supabase client, Strava API, HealthKit
│       ├── Extensions/             # Swift/SwiftUI extensions
│       └── Utilities/              # Helpers, constants
├── StrideByTests/                  # Unit tests
├── StrideByUITests/                # UI tests
└── SupabaseEdgeFunctions/          # Deno/TypeScript edge functions
    ├── strava-webhook/             # Receives activity pushes from Strava
    └── generate-postcard/          # Generates milestone images
```

## Architecture Decisions
- MVVM pattern for SwiftUI views
- One ViewModel per feature screen
- Supabase Swift SDK for all backend communication
- Route data stored as GeoJSON arrays of coordinates in Supabase
- User progress = cumulative miles mapped to a position along the route polyline
- Realtime subscriptions for friend pin updates on shared routes

## Coding Conventions
- SwiftUI views: declarative, broken into small subviews when > ~50 lines
- Naming: Swift standard conventions (camelCase properties, PascalCase types)
- Use async/await throughout, no Combine unless necessary
- Keep ViewModels as @Observable classes (iOS 17 Observation framework)
- Error handling: do/catch with user-facing alerts for network errors, silent logging otherwise
- No force unwraps except for known-safe cases like Bundle resources

## Key Commands
- Build: Cmd+B in Xcode, or `xcodebuild -scheme StrideBy -destination 'platform=iOS Simulator,name=iPhone 16'`
- Run tests: `xcodebuild test -scheme StrideBy -destination 'platform=iOS Simulator,name=iPhone 16'`
- Supabase edge functions: `supabase functions serve` (local dev), `supabase functions deploy` (production)
- SwiftLint: `swiftlint` (if installed)

## Strava API Notes
- OAuth callback URL must be registered in Strava app settings
- Webhook subscription requires a public callback URL (use Supabase Edge Function)
- Rate limits: 100 requests/15 min, 1000/day — webhooks are push-based so this mostly doesn't matter
- Historical backfill at signup: queue requests with delays to respect rate limits
- Store access_token and refresh_token in Supabase, refresh when expired

## Supabase Setup
- Project URL and anon key stored in a local config file (NOT committed to git)
- Row Level Security (RLS) enabled on all tables
- Realtime enabled on user_progress table for friend pin tracking

## Design Principles

This app should look and feel like an Apple Design Award winner. Every screen should feel like it belongs on the App Store featured page.

### Philosophy
- **Quiet confidence.** The design should feel effortless, like it's not even trying. No busy layouts, no competing elements, no visual noise.
- **Content is the UI.** The map, the route, the progress — that IS the interface. Chrome and controls should disappear until needed.
- **Delight in the details.** Micro-interactions, smooth transitions, and subtle animations are what separate "nice app" from "wow, this is beautiful."

### Visual Language
- Large, generous whitespace — let elements breathe
- One accent color used sparingly (not splashed everywhere)
- SF Pro and SF Rounded fonts only — match the system, feel native
- SF Symbols for all icons — never use custom icon packs
- High contrast, accessible by default — beautiful and usable aren't opposites
- Dark mode is not an afterthought — design for both from day one

### Layout Rules
- Full-bleed maps — edge to edge, no inset cards sitting on top unless absolutely necessary
- Bottom sheets over modal screens — keep the map visible whenever possible
- Tab bar with 3-4 tabs max — Map, Routes, Social, Profile
- No settings screens with 30 toggles — opinionated defaults, minimal config
- Cards should float with subtle shadows and rounded corners (16pt radius)

### Motion & Animation
- Use SwiftUI's built-in spring animations as the default (.spring(response: 0.35, dampingFraction: 0.85))
- Pin movement along routes should be smooth and satisfying, never jumpy
- Screen transitions: matched geometry effects where possible
- Progress updates should feel like a celebration — subtle scale + haptic when milestones hit
- Avoid animation for animation's sake — every motion should have a purpose

### Map Aesthetic
- Use MKStandardMapConfiguration with a muted/subtle style
- Route lines: smooth, rounded caps, semi-transparent with a glow or gradient effect
- User pin: custom, branded, small but distinct — not a default red pin
- Friend pins: same style, different color per friend, with initials
- Landmarks along the route: minimal dots that expand on tap

### Postcard / Share Cards
- These are the viral mechanism — they must look stunning
- Full-bleed landmark photo as background, text overlay with blur
- Show: landmark name, distance traveled, route name, StrideBy branding (subtle)
- Sized for Instagram Stories (9:16) and square (1:1) feed posts
- Generated with SwiftUI's ImageRenderer

### What to Avoid
- Gradients everywhere (one subtle gradient max per screen)
- Bright/neon colors — keep the palette grounded and natural
- Cramming data into screens — if it feels like a dashboard, simplify
- Custom navigation patterns — use standard iOS navigation people already understand
- Skeleton loaders on every surface — a simple fade-in is cleaner

## Important Reminders
- The developer (Andrew) is new to Swift/SwiftUI — explain Swift-specific concepts when they come up
- Prefer simple, readable code over clever abstractions
- Always show how to test things in Xcode or the simulator
- When creating new files, include the standard Xcode file header
- Keep the app feeling fun and lightweight — this is not a serious training app
