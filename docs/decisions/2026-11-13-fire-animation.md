# Fire animation — decisions

Date: 2026-11-13. User: "Let's improve animations.gd and the fire animation. It should build up
and disperse."

## Decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Build-up speed | Quick (sharp spike) | Matches dragon fire bursts |
| Dispersion behavior | Fade-out into smaller pieces | Embers lingering after breath ends |
| Duration | Pulsing for longer sustained breaths | Allows continuous fire while holding the key |
| Effect model | Sprite-based nodes (Flame, OuterFlame, MidFlame, CoreFlame + new dispersion pieces) | Project uses ColorRects for visual effects; GPU particles not yet needed |

## Open / deferred
- **Particle system vs. sprite animation** — assumed sprite-based (build-up + dispersion pieces) since the project already uses ColorRects. Revisit if performance or visual fidelity demands GPU particles.
