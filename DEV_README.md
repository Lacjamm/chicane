# Chicane: Full Throttle 3D — VS Code dev workspace

Godot 4.3 GDScript project wrapped in a VS Code workspace with a devcontainer.

## Quick start
1. Install VS Code + the Dev Containers extension + Docker Desktop.
2. Open this folder in VS Code -> "Reopen in Container" (first build downloads
   Godot 4.3 into the image; assets import automatically).
3. Terminal -> Run Task:
   - "Test: validation suite (232 checks)"  <- default test task (Ctrl+Shift+P -> Run Test Task)
   - "Test: scripted bot races"
   - "Benchmark: world gen + frame cost"
   - "Run game (xvfb, ...)" runs the game against a virtual display — good
     for smoke tests; to actually PLAY, open chicane3d/project.godot in the
     Godot editor on your host machine (see chicane3d/README.md).

## Car model packs
The imported car models ship separately (transfer size limits). Drop the
`chicane_*_models_*.zip` files anywhere in this folder — the game installs
them from the zips at startup (`_auto_install_models` in scripts/main.gd).
Without them everything still runs; cars use procedural bodies and the
validation suite passes either way (models are optional assets).

## Layout
- `chicane3d/` — the Godot project (scripts/, scenes/, assets/)
- `chicane3d/scripts/d.gd` — all game data (cars, events, MODEL_SKINS)
- `chicane3d/scripts/tests/` + `chicane3d/scenes/tests/` — validation suite,
  bot races, benchmark, screenshot scenes
- `chicane3d/CHANGELOG.md`, `KNOWN_ISSUES.md` — history + honest limits
- `tools/` — Python asset generators (write into chicane3d/assets/)
- `CLAUDE.md` — project context for Claude Code

## Claude Code
The container ships with the Claude Code CLI (`claude` in the terminal) and
the VS Code extension. Login/config persists across rebuilds in the
`chicane-claude-config` Docker volume (mounted at `~/.claude`).
The GitHub CLI (`gh`) is also installed for PR/issue work — run
`gh auth login` once inside the container.

GDScript LSP: start the Godot editor once (host or container) so the
godot-tools extension can connect on port 6005; plain text editing works
without it.
