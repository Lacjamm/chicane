# CHANGELOG — Chicane: Full Throttle 3D

## v9.13 (this build)
**Real police car model:** every VCPD unit now uses the imported
`police_car` 3D model when it is installed (`assets/models/police_car/`),
complete with the flashing red/blue lightbar — which now also works on
imported bodies, not just procedural ones. The rank-10 Valkyr Unit keeps
its dedicated patrol-hypercar models and falls back to the cruiser.
Without the model installed, cops keep their procedural bodies as before.

## v9.12
**Branded loading screen for the web version:** the browser build now
boots into a Chicane-styled loader — neon title, live download bar with
MB and % readout, a shimmer state while the engine compiles, rotating
gameplay tips, and clear error messages if WebGL is unavailable. Fades
out the moment the engine starts.

**SPACE to jump, tap again for a double jump.** Grounded tap launches
the car; a second tap mid-air gives a stronger second kick with a
nose-up flourish. Handbrake (and drifting) moved from SPACE to CTRL —
pad layout unchanged except jump landing on LB.

## v9.11
**[G] GOD MODE hotkey (EASY level):** every race on EASY starts with a
flashing "PRESS [G] FOR GOD MODE" hint. Press it and: your car snaps
back to the middle of the road on the straight path to the finish, you
become untouchable, and ANYTHING that touches you — rivals, cops,
traffic, even buildings — explodes on contact. Press [G] again to turn
it off. (Same god-mode setting as Settings → Gameplay, now with a
live toggle.)

**Weapon slots moved to [1]/[2]/[3]** (F and H still work for slots
1/3) — this frees G for god mode. All menus, HUD and the inventory
overlay show the new keys.

**Lighter + clearer colours (third pass):** skies lifted toward clean
daylight tones per zone, fog cut to ~40% of before, warmer stronger
sun, higher ambient floor and exposure. Districts keep their identity
but everything reads bright and clear.

## v9.10
**Impound warning (3 minutes):** the first time the VCPD pins you down,
you are no longer busted on the spot. Instead: "IMPOUND WARNING!", a
flashing 3:00 countdown on the HUD, and one chance — lose the police
before it expires. Get caught again (or run out the clock while still
wanted) and the car is impounded for real. Shaking the heat clears the
warning.

**[Y] NUKE THE POLICE (EASY level only):** a panic button for Cruise
drivers. One press: screen flash, every police unit on the road goes up
in a blast, the busted meter and any impound warning are wiped, and your
car is set back in the middle of the road. 45s recharge; the HUD shows
"[Y] NUKE POLICE RDY" whenever you're on EASY. On other levels it just
tells you no.

## v9.9
**Three levels of play — EASY / NORMAL / HARD:**
- First launch now asks you to choose a level; switch any time from the
  main menu (LEVEL button) or Settings.
- Difficulty now shapes every arcade system, not just AI skill:
  - EASY — Cruise: weaker AI and police, 55% damage taken, health regen,
    30% faster weapon/warp cooldowns, 3s death countdown, destroyed
    enemies stay gone 14s, +25% cash.
  - NORMAL — Redline: the intended experience (5s death countdown,
    10s enemy respawn).
  - HARD — Apex: sharper AI, aggressive police, +40% damage taken, 35%
    slower weapons, 8s death countdown, enemies return in 7s, +15% cash.

## v9.8
**Brighter, again:** second global lighting lift — much higher ambient
floor (night zones can no longer go murky), hotter exposure, stronger
sun. The Settings Brightness slider still stacks on top.

**Destructible roadside buildings:** four types line every track and
each dies its own way when shot —
- GLASS TOWERS shatter into a cyan shard burst and collapse
- CONCRETE BLOCKS crumble: dust cloud + physical rubble chunks
- FUEL TANKS ignite into a full weapon blast that wrecks nearby cars
  and chain-detonates neighbouring buildings
- NEON SIGNS short out in a spark shower and topple over
Every weapon works on them: blasts (missiles/bombs/tank chains) level
them outright, machine guns and the flamethrower chew through building
HP, blades/chainsaw/wrecking-ball demolish on contact, shockwave
flattens everything in radius. +100 bounty per building. The bot race
harness now verifies demolition end-to-end.

## v9.7
**Health bar + RIP respawn:**
- The bottom-left damage meter is now a proper HEALTH bar: starts full,
  drains as you take hits, and shifts green → amber → red.
- Hitting zero no longer ends the race. Instead: slow-mo "RIP!", a
  "RESPAWN IN 5…4…3…2…1" countdown, and you're back — full health, a
  pristine rebuilt body (crumples, torn panels, broken lights and cracked
  glass all reset), tyres fixed, half a tank of nitrous, placed safely on
  the road. The AI keeps racing while you're down.
- The bot-race harness accounts for respawns (races can run longer) and
  reports how many times the player died.

## v9.6
**Weapon inventory on [Q]:**
- Hit [Q] in any race to bring up your weapon inventory — a live overlay
  showing your three equipped weapons with keys, cooldowns/active timers
  and descriptions, plus warp, EMP, turbo and (cop career) spikes and
  roadblocks. Hit [Q] again to close; works even while stunned.
- A toast at race start says so, and the HUD weapons row permanently
  shows "[Q] INVENTORY".
- Cop spike strips moved from [Q] to [K] to free the key (pad binding
  unchanged: LB).

## v9.5
**God mode:** Settings → Gameplay toggle. Your car takes no damage, no
EMP stuns, no spike-strip shredding. HUD shows ⚡GOD MODE while active.
Being busted is still possible — gods can't outrun paperwork.

**Warp speed:** press [Z] (pad: D-pad left) for 10 seconds at TRIPLE
velocity — 3× top speed cap and 3× engine force, with a launch kick and
exhaust flames. 25s recharge, shown on the HUD weapons row.

**Radar:** new proximity radar above the minimap (Settings → Gameplay to
toggle). Player-centred and rotating with your car: rivals orange, cops
blue, the suspect red, traffic grey. Racers beyond the 90m range pin to
the rim so you always know which direction they are. Rival blips were
also added to the Velocity County local map.

## v9.4
**Pick-3 weapon loadout (all unlimited ammo):**
- New WEAPONS menu on the main screen — choose any 3 of 10 weapons for
  slot keys [F]/[G]/[H] (pad: LS-click / Y / RB): Homing Missile, Machine
  Guns, Blade Wings, Chainsaw Ram, Wrecking Ball, Bombs, Flamethrower,
  Freeze Ray, EMP Burst, Shockwave. Cooldowns only, no ammo counts.
- Everything a weapon destroys uses the same 10-second respawn pipeline;
  the HUD bottom row shows your three slots and their ready state.
- Default loadout: Missile / Machine Guns / Bombs. Old saves migrate
  automatically; invalid loadouts self-heal to 3 valid picks.

**Drive any car:**
- The garage now offers DRIVE THIS — FREE on every non-secret car: pick
  the car you want and go. Secret cars still require their unlocks.

**Lighting overhaul (was too dark):**
- Global brightness lift in every district: higher ambient with a night
  floor, stronger sun, and a small exposure boost. Night zones (Neon
  City, The Black Track) are far more legible.
- New Brightness slider in Settings → Video (0.6–1.6) on top of that.
- Garage preview lighting brightened to match.
- `TestShot` screenshots now save to `res://shots/` on any machine
  (previously hardcoded to the devcontainer home directory).

## v9.3
**Missiles (unlimited) + respawns:**
- New weapon: homing missiles with UNLIMITED ammo — [F] on keyboard,
  left-stick click on pad. Locks the nearest car ahead (rivals, cops,
  suspects, traffic) and detonates on proximity; big fireball, camera
  shake, victims get launched. Your own blasts never damage you.
- Blown-up cars respawn after 10 seconds: rivals/cops return as fresh
  cars (same car, paint and role) near where they died; traffic density
  recovers with new cars ahead. The burning husk lingers until then.
- Exception: the intercept suspect stays down — destroying it is the
  arrest, as before. EMP, spikes and roadblocks are unchanged.
- The bot race harness now fires missiles through the first sprint and
  verifies blow-ups + respawns end-to-end.

**Car appearance pass (all cars):**
- Imported model skins (including the bundled Kenney pack) previously
  rendered fully matte — bodywork now gets a glossy clearcoat car-paint
  finish and wheels a rubber/alloy split, applied at load for every pack.
- Procedural cars: deeper showroom clearcoat on gloss paint, brighter
  polished alloy rims. Applies to player, rivals, cops and traffic.

**Bundled CC0 car model pack (Kenney Car Kit):**
- All 21 model skins now ship in `chicane_kenney_models_pack1.zip` (0.7 MB),
  generated from Kenney's CC0 Car Kit — no more empty bodywork picker on a
  fresh install. The zip auto-installs at first launch like any model pack.
- Each skin gets its own hue-shifted paint job baked into the palette
  texture, so shared base bodies still read as 21 distinct cars.
- Every skin in this pack has separately named wheels, so imported wheels
  spin and steer on all of them (the fused-wheel limitation only applies to
  the original high-poly packs).
- Regenerate with `tools/convert_car_models.gd` (sources vendored under
  `tools/kenney_car_kit/`, CC0 — see its License.txt).
- New visual check: `scenes/tests/TestModelsShot.tscn` renders every
  installed skin in a labelled grid and saves `shots/models_grid.png`.

## v7
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
