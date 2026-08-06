# Known issues & honest limitations

- Model packs are separate zips (30 MB transfer limit). Without them the
  game uses procedural bodies for everything — fully playable by design.
- Wheels on some imported models are one fused mesh (agera11*, one1, both
  patrol cars, aventador, countach, tourbillon, firebird, vw_lp) — those
  wheels do not visually spin; physics is unaffected. (*agera11 splits.)
- Crash mesh deformation is disabled for imported bodies (by design —
  handling damage, smoke and fire still apply).
- Deferred features from the long-form briefs: festival hub, livery editor,
  photo mode, day/night cycle, route creator, convoys, player homes,
  rewind, destruction arenas, Grand Velocity Tour, full control remapping.
- The scripted bot in TestRace drives imperfectly on purpose; per-phase
  outcomes (win/wrecked/busted) vary run to run — the suite checks
  completion, not victory.
- Under software rendering (llvmpipe) heavy models reduce FPS; on any real
  GPU (the target) performance is fine. Traffic/AI never load model skins
  unless the car id itself has them.
