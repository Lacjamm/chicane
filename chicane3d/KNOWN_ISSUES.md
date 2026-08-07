# Known issues & honest limitations

- Model packs are separate zips (30 MB transfer limit). Without them the
  game uses procedural bodies for everything — fully playable by design.
- Wheels on some imported models in the ORIGINAL high-poly packs are one
  fused mesh (agera11*, one1, both patrol cars, aventador, countach,
  tourbillon, firebird, vw_lp) — those wheels do not visually spin; physics
  is unaffected. (*agera11 splits.) The bundled Kenney CC0 pack does not
  have this problem — all its wheels split onto hubs and spin.
- The bundled Kenney pack is stylised low-poly; the skins keep their slots
  and paint identities, so swapping in a high-poly pack later just works
  (delete assets/models plus user://model_cache_*.scn and drop the new
  zips next to the game).
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
- Controller buttons are saturated: weapon slot 3 shares RB with the cop
  roadblock, and warp shares D-pad left with manual gear-up. Keyboard has
  no conflicts ([F]/[G]/[H] weapons, [Q] inventory, [Z] warp, [K] spikes).
- The [Q] inventory overlay is read-only in-race; loadout changes happen
  in Main Menu → WEAPONS (deliberate — no mouse dependency mid-race).
