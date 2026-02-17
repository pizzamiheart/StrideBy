# StrideBy Feature Ideas

Ideas to revisit later. Not prioritized — just a parking lot.

---

## Nearby Attractions Button
Replace the old "Nearest Place" button with a curated "Nearby Attraction" feature. Instead of just finding the nearest town by route distance, show famous landmarks and attractions near the user's current pin — Eiffel Tower, Strasbourg Cathedral, Colosseum, Mt. Fuji viewpoints, etc. Each route would have a hand-picked list of must-see spots with Look Around imagery. This is the thing that makes people screenshot and share.

## Shareable Postcard Milestone Cards
When users hit a landmark (cross into a new country, reach a famous city), auto-generate a beautiful share card with the landmark photo as background, distance traveled, and StrideBy branding. Sized for Instagram Stories (9:16) and feed (1:1). The viral mechanism — these need to look stunning.

## Passport Stamps
Collect stamps when you cross country or state borders along a route. Visual passport book in the Profile tab that fills up as you travel. Dover to Calais = UK stamp + France stamp. Crossing from Kansas to Colorado = new stamp.

---

## Social & Network Effects

### Shared Routes / Run Together
Pick a route with friends and see everyone's pins on the same map in realtime (via Supabase Realtime subscriptions). "Race" NYC to LA together. Leaderboard per route showing who's furthest. Low-friction invite via share link — tap to join someone's route.

### Activity Feed
See when friends hit milestones: "Sarah just reached Paris on European Crossing!" or "Mike completed Coast to Coast!" Lightweight feed in the Friends tab — not a full social network, just route-relevant moments. Push notifications for friend milestones on shared routes.

### Running Clubs / Groups
Create or join a group (e.g. "NYC Run Club"). Group picks a route and everyone's miles contribute to a shared pin. "Our club ran NYC to LA together in 3 months." Good hook for running clubs that already exist IRL — gives them a shared goal.

### Weekly Challenges
Time-limited group challenges: "Run 50 miles this week as a group to unlock the Tokyo route." Creates urgency and a reason to open the app regularly. Challenges could unlock new routes, cosmetic pin styles, or postcard backgrounds.

### Referral Loop
When you share a postcard or milestone card, include a deep link. Recipient taps it, downloads the app, and auto-joins your route. The sharer gets a cosmetic reward (custom pin color, special stamp). Make the viral loop as short as possible: see card → download → running together in under 2 minutes.

### Strava Integration Social Layer
Surface mutual Strava followers who also use StrideBy. "3 of your Strava friends are on StrideBy" during onboarding. Auto-suggest shared routes with people you already run with.

---

## Portal Effect When User Clicks "Look Around"

### Look Around feels like a time travel 
So when you click it the the screen feels like you're jumping through a time portal and it's fascinating and fun rather than the swipe up menu that comes up now. It should feel magical to travel to that point where you've progressed to on the map.

---

## Banked Build Plan: UGC + Viral Sharing

### Product Goal
Create a lightweight, repeatable sharing loop where each run produces a delightful "travel moment" users want to post to Strava and social.

### Share Objects (MVP-first)
- Route Postcard: destination image + city + "I moved X miles on [route]".
- Landmark Unlock Card: triggered at major POIs.
- Route Completion Card: full celebratory share.

### Caption System
- 1-tap caption presets with fun tone:
  - "Ran in my neighborhood, landed in Tokyo."
  - "Cardio passport stamped."
  - "Leg day, jet lag."
- Optional user editable text before export.

### Distribution Channels
- Native iOS share sheet first (supports Strava/IG/X/messages with zero API risk).
- Export sizes:
  - Story 9:16
  - Feed square 1:1
  - Wide 16:9

### Viral Loop
- Include deep link in shared payload:
  - Open app (or install) -> jump to same route -> prompt "Run this route".
- Referral attribution:
  - `shared_by_user_id`
  - `route_id`
  - `template_id`
  - `opened_at`, `installed_at`, `started_route_at`

### Suggested Implementation Phases
1. Card renderer + templates + share sheet.
2. Auto-prompt on milestones (not every run).
3. Deep-link landing + start-same-route flow.
4. Analytics dashboard for share/open/install/start-route funnel.
5. Later: direct Strava activity enrichment via API (policy/rate-limit review required).

### Data/Infra Prereqs (for later)
- User auth + profiles.
- Event table for share funnel telemetry.
- Signed URL/image hosting for durable cards.
- Background job support for async card rendering if needed.

---

## Post-Run Cinematic Replay (MVP Spec)

### Product Direction
Replace the single post-run "where am I now?" moment with a short replay of the distance just completed on the selected city route.

### Core UX
- After each synced run, user gets a 20-30 second replay:
  - Animated path segment for this run's miles
  - City/landmark highlights along that segment
  - Distance, pace, elevation overlays
- Replay should feel like a mini travel episode, not a static map update.

### Why This Solves Current Problem
- Avoids dependence on one exact Look Around point.
- Lets us stitch several strong-coverage checkpoints.
- Creates better emotional payoff and stronger shareability.

### MVP Output (First Shipping Version)
- Video format: MP4/H.264
- Length: 20-30 seconds
- Aspect ratios:
  - 9:16 (Stories/Reels) primary
  - 1:1 (Feed) optional
- Visuals:
  - Segment start/end markers
  - Animated route progress line
  - 3-5 checkpoint cards (landmark names + map snapshots)
  - Elevation mini-chart synced to timeline

### Data Model (Suggested)
- `RunReplayPlan`
  - `run_id`
  - `route_id`
  - `start_mile`
  - `end_mile`
  - `distance_miles`
  - `duration_seconds`
  - `pace`
  - `elevation_gain_ft`
  - `checkpoint_miles: [Double]`
  - `checkpoint_coordinates: [LatLng]`
  - `checkpoint_titles: [String]`

### Segment Selection Algorithm (MVP)
1. Determine `start_mile` and `end_mile` from pre-run and post-run route progress.
2. Sample N evenly spaced checkpoints along that segment (target N = 5).
3. For each checkpoint, choose best visual source:
   - 1st: Look Around if available
   - 2nd: Flyover/hybrid snapshot
   - 3rd: standard map snapshot fallback
4. Remove duplicates/low-value checkpoints (too close visually).

### Replay Timeline Template (Example 24s)
- 0-2s: Title card ("You ran 5.0 mi through Paris")
- 2-16s: Animated segment progression + checkpoint reveals
- 16-21s: Stats panel (distance, pace, elevation)
- 21-24s: End card ("Now at Mile X on [Route]") + share CTA

### iOS Implementation Notes
- Rendering:
  - SwiftUI views rendered frame-by-frame
  - `AVAssetWriter` for video assembly
- Snapshot fetch:
  - Preload all checkpoint visuals first
  - Timeout + fallback strategy per checkpoint
- Performance:
  - Generate replay asynchronously after sync
  - Cache generated videos by `run_id`

### Rollout Plan
1. V1: map-based cinematic replay (no continuous street-level video)
2. V1.1: richer transitions + branded motion style
3. V2: optional "street snippets" from high-confidence Look Around checkpoints
4. V2.1: one-tap share composer with caption presets

### Success Metrics
- Replay completion rate
- Replay share rate
- Share-to-install conversion
- D7 retention delta between users who watch replay vs skip

### Deferred: Full Street-Level Autoplay
- We tested a `Watch Run` street-tour prototype and intentionally removed it from the app.
- Reason: Apple Look Around API does not provide the same continuous forward-navigation control as native Apple Maps interaction, so the result felt like stitched scene hops in a sheet rather than true in-street movement.
- Revisit only if:
  - We can get smoother camera-path control from Apple APIs, or
  - We move to a provider/workflow that supports continuous street-level playback.
- Until then, prefer map-first cinematic replay and optional high-confidence street snippets.
