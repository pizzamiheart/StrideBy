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
