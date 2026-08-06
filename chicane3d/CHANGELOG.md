# CHANGELOG — Chicane: Full Throttle 3D

## v7 (this build)
**Missing-model resilience (the "critical issue"):** model packs are OPTIONAL.
- `D.skin_ok()` verifies files exist before any load; vehicles, garage preview
  and the bodywork picker all fall back to procedural bodies automatically.
- Garage hides bodywork whose files are not installed; a dev warning is
  logged once, players see nothing broken.
- Validation suite treats model files as optional assets: reports
  "N/21 skins installed", never fails on absence, and verifies the
  procedural fallback path explicitly. Proven: full suite passes with the
  entire assets/models directory deleted (230 checks) and present (232).
- If packs are added later they are detected automatically on next launch.

**Five new imported vehicles/bodywork:**
- Vitesse Royale gains the Tourbillon bodywork (3 total).
- Marauder GS-R gains Formula 78 muscle bodywork (2 total).
- NEW Goblin V12 ($195k, Track Hypercar) — wheels split onto physics hubs.
- NEW Cinder 21C ($380k, Experimental Prototype class: featherweight,
  extreme downforce, peaky engine) — wheels split onto hubs.
- NEW Wolf Compact ($16k, Compact class: light, momentum car) — extracted
  from a multi-car low-poly pack via the new per-skin "only" subtree filter.
- Baked shadow/glow planes in models are now auto-hidden (they distorted
  scale and floated under cars).
- 21 model skins total across 10 cars + 1 police unit.

**Game feel & tools:**
- Look-back camera: hold TAB (right-stick click on pad).
- New class personalities: Experimental Prototype, Compact.
- Performance benchmark scene `scenes/tests/Bench.tscn` — reports world-gen time,
  avg/worst physics frame, body count, memory (headless-safe).

## v6
Tempesta gains 3 Lamborghini-family bodyworks; new Marauder GS-R; smoothed
minimap on panel; zoomed roam local map with POI dots; multi-part delivery.

## v5
12 imported models as Aegir/Ion/Talon/Vitesse/VCPD Valkyr; wheel-cluster
splitting (spin+steer); manual gearbox + assists toggles; camera distance/
height settings; rain in wet districts. Suite 226 checks.

## v4
Velocity County connected open world (21 km seeded ring, 6 districts),
seamless on-road events, road discovery, barn finds, speed cameras, jumps,
opaque car bodies fix. Suite 189 checks.

## v3
Transmission simulation, chase cam, racing-line AI + police director, true
circuits, time attack/speed trap/duel, controller support, settings, audio
layering, 180-check suite.
