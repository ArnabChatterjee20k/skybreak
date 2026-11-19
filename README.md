# Skybreak

A full-3D anime arena fighter with free flight, built in Godot 4. Personal,
non-commercial project. Working title.

- Engine: Godot 4.7.2 (Forward+), GDScript
- Tests: GUT, run headless in CI on every PR
- Status and tasks: [`TODO.md`](TODO.md)
- How to contribute (humans and agents): [`AGENTS.md`](AGENTS.md)
- Plan and decisions: [`docs/handoff.md`](docs/handoff.md)

## Run

Open the folder in Godot 4.7.2 and press F5. The grey-box test arena runs with
the debug overlay (F3 toggles it).

## Test

```sh
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```
