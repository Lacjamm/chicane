# Chicane: Full Throttle 3D

Open-road hypercar racing game. Godot 4.3 (standard, not .NET), pure GDScript —
no C#, no plugins. Runs headless in the devcontainer; play it in the Godot
editor on a host machine.

## Layout
- `chicane3d/` — the Godot project (`project.godot` lives here)
  - `scripts/` — all game code; `scripts/tests/` — test/bench harness scripts
  - `scenes/` — `Main.tscn` plus `scenes/tests/` wrapper scenes for the harness
  - `assets/sfx/` — generated WAVs (regenerate with `tools/gen_audio*.py`)
- `tools/` — Python asset generators (need numpy/pillow, installed in container)
- `.vscode/tasks.json` — canonical commands; mirror any path changes there

## Key files
- `chicane3d/scripts/d.gd` — ALL game data: cars, events, districts, MODEL_SKINS
- `chicane3d/scripts/p.gd` — player profile / save data (has migration logic)
- Autoloads (see project.godot): `D` (data), `P` (profile), `SFX`, `S` (settings)
- `chicane3d/KNOWN_ISSUES.md` — deliberate limitations; read before "fixing"

## Commands (run inside the devcontainer, from repo root)
- Import assets (after adding/changing assets):
  `godot --headless --path chicane3d --import`
- Validation suite (the default test — run after any change):
  `godot --headless --path chicane3d scenes/tests/TestAll.tscn`
- Scripted bot races: `godot --headless --path chicane3d scenes/tests/TestRace.tscn`
- Benchmark: `godot --headless --path chicane3d scenes/tests/Bench.tscn`
- Rendered smoke test: `xvfb-run -a -s '-screen 0 1280x720x24' godot --path chicane3d --rendering-driver opengl3`

## Conventions
- Test scripts print PASS/FAIL lines and exit; treat any FAIL in TestAll output
  as a broken build.
- Car model packs (`chicane_*_models_*.zip`) are optional, gitignored, and
  auto-installed at startup by `_auto_install_models` in `scripts/main.gd`;
  everything must keep working without them (procedural car bodies).
- Update `chicane3d/CHANGELOG.md` for player-visible changes.
