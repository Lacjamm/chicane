# CHICANE: FULL THROTTLE 3D

A fully 3D open-road hypercar racing game with police pursuits, real vehicle
physics, BeamNG-style crash deformation and an unlimited-ammo weapon loadout —
built in Godot 4.

Everything is procedural: the tracks, the seven districts of Velora Coast,
even the music and sound effects. Car models come from a bundled CC0 pack
(Kenney Car Kit, `chicane_kenney_models_pack1.zip` — auto-installs on first
launch); without it the game seamlessly uses procedural car bodies. Optional
higher-detail model packs drop into the same folder and install themselves.

## How to run it (3 steps, ~2 minutes)

1. Download **Godot 4.3** (free, ~50 MB) from https://godotengine.org/download
   — get the standard version (not .NET) for your OS.
2. Open Godot, click **Import**, and select the `project.godot` file inside
   this folder.
3. Press **F5** (or the ▶ Play button, top right). That's it.

If the window opens black or crashes on an older PC: in Godot go to
*Project → Project Settings → Rendering → Renderer* and switch
**Forward+** to **Compatibility**, then run again.

## Controls

| Key | Action |
|---|---|
| W / ↑ | Accelerate |
| S / ↓ | Brake / reverse |
| A·D / ←·→ | Steer |
| SPACE | Jump — tap again mid-air for a double jump |
| CTRL | Handbrake — hold + steer to drift |
| B / V | Gear up / down *(manual transmission mode)* |
| SHIFT / N | Nitrous |
| F / G / H | Fire weapon slots 1-3 *(pick your 3 in Main Menu → WEAPONS)* |
| Q | Weapon inventory overlay |
| Z | Warp speed — 10 s at 3× velocity |
| T | Turbo burst |
| E | EMP blast · start event at a marker *(Velocity County)* |
| K | Spike strip *(cop career)* |
| R | Call roadblock *(cop career)* |
| C | Camera (chase / far / hood) |
| X | Reset car onto the road |
| M | Cycle radio station |
| TAB | Look back |
| ESC | Pause |

## What's in the game

- **Racer Career** — 33 events over 7 tiers across Neon City, Crimson Desert,
  Stormridge Mountains, Aeroport Runway, Coastal Freeway, Industrial Docks and
  the hidden Black Track. Sprint, Circuit, Drag, Drift Trial, Top Speed,
  Elimination, Pursuit Escape, Hot Pursuit and 6 Boss Races (Vex, Nova, Raze,
  Specter, Apex... and Zero). Includes **The 50-Mile Gauntlet** — a marathon
  Hot Pursuit survival on the Coastal Freeway.
- **Cop Career** — 12 interceptor missions. Ram, EMP, spike and roadblock
  suspects into custody. Rank up to unlock five VCPD hypercars.
- **Heat 1–10** — patrols → spike traps → EMP units → roadblocks → helicopter
  → hypercar police → armoured interceptors → full lockdown.
- **Garage** — 16 buyable + 6 secret hypercars with live rotating 3D preview,
  8 upgrade lines, 12 paints, 5 finishes.
- **Free Drive** — cruise any district; trip a speed camera at 200+ km/h and
  the heat starts building. Escape to bank the bounty.
- **Destruction physics** — impact-point mesh crumpling, bumpers and wings
  that tear off as physics debris, wheel-killing spike strips, engine smoke
  and fire, slow-motion crash cam, and traffic that goes flying, tumbling and
  crumpling when you hit it. Damage changes how your car drives.
- **Weapons** — pick any 3 of 10 (missiles, machine guns, blade wings,
  chainsaw, wrecking ball, bombs, flamethrower, freeze ray, EMP, shockwave),
  all unlimited ammo. Destroyed cars respawn after a few seconds. Hit **Q**
  in a race for your live inventory.
- **Destructible buildings** — glass towers, concrete blocks, fuel tanks
  and neon signs line every road, each with its own explosion: shatter,
  rubble + dust, chain-reaction fireballs, spark showers. +100 bounty each.
- **Health & respawning** — a real HEALTH bar; hit zero and it's "RIP!",
  a respawn countdown, and you're back in a pristine car mid-race.
- **Three levels of play** — EASY / NORMAL / HARD chosen at first launch
  (switchable any time): scales AI, police, damage, weapon cooldowns,
  respawn timers, health regen and payouts.
- **Warp speed, god mode & radar** — [Z] triple-speed burst; Settings
  toggles for invincibility and a rotating proximity radar.
- **Every car free to drive** — the garage unlocks any non-secret car
  instantly; secrets still require their challenges.
- **Saves automatically** to your user folder after every event.

## Project layout (for curious modders)

```
scripts/d.gd            all game data: cars, events, zones, bosses
scripts/p.gd            profile + save system
scripts/sfx.gd          audio manager
scripts/car_factory.gd  procedural car meshes + deformation + debris
scripts/track_gen.gd    procedural roads and scenery
scripts/vehicle_base.gd shared vehicle physics + damage
scripts/player_car.gd   player handling, nitrous, drift, camera
scripts/ai_car.gd       rival / cop / suspect AI drivers
scripts/traffic_car.gd  civilian traffic (freezes → full physics on impact)
scripts/race.gd         race modes, heat system, weapons, scoring
scripts/hud.gd          in-race HUD
scripts/menus.gd        menus, careers, garage
scripts/main.gd         orchestrator
tools/gen_audio.py            regenerates every sound in assets/sfx
```

Tuning tip: car stats live at the top of `scripts/d.gd` — change a number,
press F5, feel the difference.

Built with Claude. Drive fast, crash spectacularly. 🏁


## v3 — "Production" update

**Driving:** real transmission (6 gears + reverse, torque curves per engine class, shift cuts,
engine braking, launch traction control), per-class handling personalities, surface grip
(dry / wet / dirt / shredded tyres), ABS-assisted braking, brake & reverse lights,
skill-based drifting with countersteer assist and clean-exit drift banking.

**Camera:** spring-damped chase cam with brake dive, drift framing, impact shake, road
vibration, wall avoidance, hood + bumper modes, speed/nitrous FOV.

**AI:** precomputed racing lines with real braking zones, driver personalities and
believable mistakes, slipstreaming, committed avoidance, police director with coordinated
roles (chaser / PIT rammer / spike unit / interceptor with warning), suspects that use
nitrous and get sloppy as they take damage. No visible teleports — stuck AI is nudged
on-screen and only repositioned off-screen.

**Tracks:** TRUE closed-loop circuits with lap lines, quarter checkpoints (anti-cut),
lap timing + best laps, wrong-way detection; district landmarks (desert gas station,
docks freighter, airport jet).

**New events:** Time Attack (checkpoints add seconds), Speed Trap (five cameras),
Rival Duel — plus medals, personal bests, Performance Ratings and upgrade trade-offs
(power vs launch grip, armour vs weight, drift suspension vs stability, race tyres vs
drift initiation).

**Controller:** full Xbox-style mapping (RT/LT analogue throttle & brake, stick steering
with deadzone setting), vibration on impacts, menu focus navigation, HUD prompts switch
between keyboard and pad automatically.

**Audio:** 4-band layered engine crossfade driven by real RPM and load, gear-shift clunks,
turbo whine + blow-off, wind, slip-responsive tyre squeal, music ducking under big crashes.

**Settings:** volumes (master/music/engine/FX), quality presets (Low/Med/High), FOV,
camera shake, speed streaks, steering sensitivity, controller deadzone, vibration,
traffic density, reset confirmation.

**Testing:** `scenes/tests/TestAll.tscn` runs a 180-check validation suite (events, cars,
every district, loop closure, racing line, save migration); `scenes/tests/TestRace.tscn`
runs scripted bot races across sprint / pursuit / drift / true circuit.


## v4 — "Velocity County" open world

**One connected world.** Free Drive now leads with **★ VELOCITY COUNTY** — a
~21 km seeded ring highway that crosses every district in order: Coastal
Freeway → Neon City → Industrial Docks → Aeroport Runway → Crimson Desert →
Stormridge Mountains, with gateway arches and name signs at each border. The
same seed always builds the same county, so your discoveries stay valid
forever. Sky, sun, fog and ambience **cross-fade live** as you cross a border
("ENTERING NEON CITY"), and district surface grip follows you.

**Seamless events.** Five on-road event markers (one per district — sprint,
time attack, speed trap, drift, pursuit escape) glow beside the road. Roll up
below 70 km/h and press **E** (or **Y** on pad) to start instantly — rivals
spawn around you, you race on the open road, and when it ends you're still
in the world. No menus, no loading.

**Road discovery.** Every metre you drive is remembered (saved per seed).
The HUD shows your district and county discovery %; fully discovering a
district pays **$15,000**.

**Barn finds.** Three derelict hypercars are hidden beside the county roads
(look for the golden **?**). Drive up to claim the wreck, then finish **3
events** — anywhere in the game — and it's restored into your garage free
(or pays $40,000 if you already own it).

**Speed cameras & jumps.** Five fixed cameras keep your best speed on record
forever — beat your record for bounty, and 200+ km/h flashes still raise
Heat. Two danger ramps pay Air Time bounties.

**Cars fixed & upgraded.** Car bodies are now fully **opaque** from every
angle (no more see-through hulls), glass is deep-tinted instead of
transparent, rims are gunmetal, and every car gained wheel-arch flares.

**Saves migrate safely.** Old profiles gain the new `roam` block with
defaults — nothing existing is touched.

*Deferred (honest list):* festival hub & influence track, livery editor,
photo mode, dynamic weather/time cycle, convoys/drivatars, police career
patrol in roam, route creator, player homes, rewind, destruction arenas and
the Grand Velocity Tour endgame from the 28-phase brief are not in this
build. The connected world, seamless events, discovery, barn finds, cameras
and safe migration are fully implemented and tested (189 automated checks +
scripted open-world bot run).


## v5 — Real 3D car models + whole-game improvement pass

**Twelve imported car models.** The game now ships with 12 detailed GLTF
car models (supplied by the owner, credits in `assets/models/ATTRIBUTION.md`)
integrated as four new vehicles:

- **Aegir Konung** (Megacar, $480k) — six selectable bodyworks: Jarl,
  Jarl Attack, Vala RS, Vala Carbon, Vala Classic, Aegir One
- **Vitesse Royale** (Hyper GT, $420k) — Divergent + Boulder Track bodies
- **Ion GT-e** (Hybrid Sports, $98k) — an affordable model car early on
- **Talon GT3-R** (Track Racer, $260k) — full GT3 aero
- **VCPD Valkyr Unit** (cop rank 10) — two real patrol bodyworks

A shared loader normalises each model's orientation and scale, detects the
four wheel clusters by name + position and remounts them on the physics
hubs — so imported wheels genuinely **spin and steer**. Models whose wheels
are one combined mesh keep them baked (noted per model). Pick bodywork in
the garage under **BODYWORK**; "Procedural body" is still available, and
paint/finish still applies to procedural bodies. Crash deformation
automatically stays off for imported bodies (handling damage, smoke and
fire still apply).

**Driving options (Settings → Driving):**
- **Automatic or Manual transmission** — manual uses B/V (D-pad left/down
  on pad) with a rev limiter and downshift protection
- Toggleable **ABS**, **Traction control**, **Stability assist**
- **Countersteer assist** strength slider
- **Chase camera distance & height** sliders

**Weather:** rain now falls in the wet districts (Neon City, Stormridge,
Docks) — velocity-led particle sheet, toggleable in settings; wet grip
already applied. District rain switches live as you cross borders in
Velocity County.

**Tests:** validation suite grew to **226 checks** (model files, skin
references, end-to-end model build, settings migration) — all passing,
plus the scripted open-world bot run.


## v6 — Four more models + cleaner maps

**New cars from imported models:**
- **Tempesta SVJ** now wears real bodywork — three selectable models:
  Tempesta V12, Tempesta Volt and Tempesta Retro (procedural body still
  available). If you already owned a Tempesta, it upgrades automatically.
- **Marauder GS-R** (Muscle Racer, $74k) — race-liveried muscle coupe with
  its own loose-tail, punchy-engine class personality. Its wheels (and the
  Volt's) split onto the physics hubs, so they spin and steer.

**Cleaner maps:**
- The minimap now sits on a rounded translucent panel with a smoothed
  road line (two neighbour-averaging passes — no more scribbly ring), and
  closed loops draw as proper closed rings.
- In **Velocity County** the minimap becomes a **zoomed local map**: a
  readable window of road around you with a heading arrow, plus dots for
  event markers (cyan), barn finds (gold), speed cameras (amber) and
  police (flashing red/blue).

Suite: **236 checks, all passing.**


## v7 — Optional model packs + five new cars

**The game no longer needs the model packs to run.** Model files are
verified before loading; anything missing silently falls back to the
procedural body and is hidden from the garage bodywork list. Install the
model pack zips (extract into the same folder as the game) and they are
detected automatically. The validation suite passes with zero packs
installed (230 checks) and with all packs (232 checks).

**New this build:** Vitesse gains the Tourbillon bodywork; Marauder gains
the Formula 78; three new cars — **Goblin V12** (Track Hypercar, $195k),
**Cinder 21C** (Experimental Prototype, $380k) and **Wolf Compact**
(Compact, $16k, extracted from a low-poly pack). Hold **TAB** (right-stick
click) to look behind you. `scenes/tests/Bench.tscn` benchmarks world-gen time
and frame cost. See CHANGELOG.md and KNOWN_ISSUES.md.


## v9 — Bundled models, arsenal & quality-of-life

- **Bundled CC0 car models** — all 21 bodywork skins now ship in a 0.7 MB
  pack generated from Kenney's Car Kit (CC0, hue-shifted per skin so every
  bodywork reads distinct); regenerate with `tools/convert_car_models.gd`.
  Wheels on every bundled skin split onto the physics hubs and spin/steer.
- **Pick-3 weapon loadout** with unlimited ammo (10 weapons), a live [Q]
  inventory overlay, and difficulty-scaled respawns for everything you
  destroy.
- **Destructible roadside buildings** (v9.8) — four types, four deaths:
  shattering glass, crumbling concrete with physical rubble, fuel tanks
  that chain-detonate into real weapon blasts, sparking neon signs.
- **HEALTH bar + RIP respawn** (v9.7) — zero health means a slow-mo
  "RIP!", a countdown, and a rebuilt car back on the road; races are no
  longer lost to a wreck.
- **Three levels of play** (v9.9) — EASY — Cruise / NORMAL — Redline /
  HARD — Apex, chosen at first launch; one tuning table in `d.gd` drives
  AI skill, damage, cooldowns, respawn timers, regen and payouts.
- **Warp speed** ([Z], 3× for 10 s), **god mode** and a rotating
  **proximity radar** (both in Settings → Gameplay).
- **Lighting overhauls** ×2 + Brightness slider; glossy clearcoat paint on
  all cars, imported and procedural.
- **Every non-secret car free to drive** from the garage.
- Validation suite: **294 checks**, plus scripted bot races that fire the
  full loadout and verify blow-ups, respawns, warp and building
  demolition end-to-end.

## Shipping builds

`export_presets.cfg` ships with Windows, Linux and Web presets. Install the
export templates once (Godot → Editor → Manage Export Templates) and then
*Project → Export* produces distributable builds into `../dist/`, or from a
terminal: `godot --headless --path chicane3d --export-release Windows`.

**Play in the browser:** every push to `main` auto-builds the Web (HTML5)
export and deploys it to GitHub Pages via
`.github/workflows/deploy-web.yml` (models regenerated from the CC0 kit,
validation suite as a deploy gate, then export + publish). The site lives
at `https://<owner>.github.io/<repo>/`. The web build uses the GL
Compatibility renderer and needs no special headers (threads disabled).

## Credits & license notes

- Car models: ["Car Kit" by Kenney](https://kenney.nl/assets/car-kit) —
  CC0, vendored under `tools/kenney_car_kit/`.
- Everything else (code, tracks, audio, procedural cars) is original to
  this project.
