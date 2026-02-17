# StrideBy Improvements

Last updated: February 17, 2026

## Brand Direction (Working Draft)

### Core vibe
- Not too serious, but still design-forward and impressive.
- The product should feel fun, playful, and motivating, not corporate.
- StrideBy should have "spirit" and "spunk."
- The app should encourage consistency in running by making post-run exploration feel like a reward.

### Product feeling to optimize for
- "I want to run again tomorrow so I can travel again."
- "This is delightful and different from normal fitness apps."
- "This feels like a game/travel toy, not a spreadsheet."

### What to avoid
- Safe/default UI patterns that look interchangeable.
- Over-reliance on generic SF Symbol + card layouts.
- A map-heavy home that feels like a utility dashboard.

## High-Priority Branding Work

These should be defined before polishing social share assets:

1. Brand voice + tone
- Playful, witty microcopy rules.
- Caption style system for shares (fun presets + editing support).

2. Visual identity foundations
- Color system with a distinctive palette (not generic default app colors).
- Typography direction that feels intentional and bold.
- Motion language for transitions and celebration moments.
- Icon/illustration style rules.

3. Signature UI motif
- Define one "only-in-StrideBy" visual system for the home experience.
- Could be a travel passport motif, kinetic progress ribbon, route "postcard deck," or other branded pattern.

## Social Share Asset Improvements

### App preview assets (App Store + marketing)
- Cohesive brand template set for screenshots and app preview clips.
- Clear narrative arc: run -> move -> land somewhere -> share.
- Standardized copy style for overlays and CTAs.

### In-app share output (social)
- Higher-art-direction share cards (Story 9:16 first, then 1:1).
- Multiple themed templates tied to brand system.
- Better composition hierarchy (headline, route, location, delta, branding).
- Funny preset captions with consistent tone.

## Home Experience Redesign Goal

Current issue:
- Home is too dominated by map and feels less one-of-a-kind.

Goal:
- Make first screen feel uniquely StrideBy while still preserving map utility.

Potential direction:
- Move map to "context layer" and make a branded "travel moment" layer primary.
- Emphasize:
  - where you are now,
  - what just happened,
  - what you can unlock next.

## Recommended Sequencing

### Short answer
Yes: finish #3 instrumentation first, then move into design iteration.

### Why this order
- Instrumentation unlocks fast feedback loops on any design changes.
- Without funnel metrics, redesign decisions are mostly subjective.

### Practical split
1. Finish #3 event logging hooks (small sprint).
2. Run a focused brand/design sprint.
3. Implement home redesign + upgraded share assets.
4. Measure deltas on activation, delight actions, and share completion.

## Light Design Interview (for next session)

Questions to answer before UI overhaul:

1. Brand personality spectrum
- More "playful arcade travel" or "cool premium travel magazine"?

2. Visual boldness tolerance
- Do we want loud/expressive or restrained/confident?

3. Motion preference
- High-motion personality or subtle polished motion?

4. Copy tone
- More witty/snarky or warm/encouraging?

5. Social identity
- Do you want people sharing mostly for humor, aesthetic flex, or running achievement?

6. Audience first
- Primarily "runners who like travel" or "people who need motivation to run"?

7. Map prominence
- Should map be 70/30 background/foreground, 50/50, or 30/70?

8. Brand references
- 3 apps/brands you want to feel closer to.
- 3 apps/brands you definitely do not want to resemble.

## Execution Note

After instrumentation is complete, run a dedicated "Brand + Home V1" sprint:
- Finalize design tokens (type, color, spacing, motion).
- Build one bold home screen variant in SwiftUI.
- Build one polished share template pack.
- Ship and measure within 3-5 days.

---

## Brand Interview Output (Feb 17, 2026)

### Chosen direction
- Serious premium + punk edge.
- Built for virality without manipulative mechanics.
- Long-term social layer possible (Twitter 2010 / Instagram 2013 energy), but not the immediate focus.

### Motion guidance
- Medium intensity.
- "A bit fun, a bit zen."
- Attention-holding without overstimulation.

### Voice + copy guidance
- Speak to users like adults.
- No sales-y promises.
- Clear, descriptive, concise.
- Positioning: fun and enjoyable utility, not life-transformation theater.

### Home balance
- Map-forward: target 65/35 or 70/30.
- Keep map primary, but add stronger branded identity in the supporting layer.

### Share objective
- Aesthetic-first sharing.
- De-emphasize try-hard achievement framing.

### Brand inspiration note
- OpenClaw philosophy: strong product quality + playful mascot/branding + attractive virality without dark patterns.

## Design Translation (Actionable)

### North-star statement
- "Premium travel-running product with punk restraint: playful accents over a serious core."

### UI principles for next sprint
1. Keep map dominant, but add a signature StrideBy identity layer (progress/travel moment stack).
2. Replace generic icon-card feel with stronger typography, spacing, and composition hierarchy.
3. Use motion as punctuation, not spectacle.
4. Optimize share outputs for visual taste first, metrics second.

### Immediate build targets
1. Home V1 (map-forward)
- Introduce branded top/bottom chrome with stronger visual identity.
- Keep direct route context + progress + one clear post-run moment.

2. Share Asset V2
- Build aesthetically-led template set (Story first, then square).
- Add subtle brand markers and cleaner visual hierarchy.

3. Social posture (early)
- Keep interactions lightweight (follow/feed style), avoid heavy moderation burden at start.
- Prioritize small social proofs over full network feature depth.
