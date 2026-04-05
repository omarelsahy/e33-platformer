# E33 Platformer

Godot **4.6** 2D precision platformer: rooftop graybox levels, **33-second countdown** (starts on first move or jump), fall death, **R** to restart, five levels with a **moving platform** from level 3 onward.

## Run

Open the folder in Godot 4.6+ and press **F5**, or set the main scene to `scenes/main_menu.tscn` (already set in `project.godot`).

## Controls

| Action | Keys |
|--------|------|
| Move | **A / D** or **Left / Right** |
| Jump | **Space**, **W**, or **Up** |
| Restart level | **R** |
| Start (menu) | **Space**, **Enter**, or jump |
| Quit (menu) | **Esc** |

## Optional audio

Drop **`jump.wav`**, **`land.wav`**, and **`fail.wav`** into `res://audio/` (imported by Godot). If they are missing, the game stays silent for those events.

## Project layout

- `scripts/player.gd` — run, jump, variable jump height, coyote time, jump buffer  
- `scripts/level.gd` — timer, kill zone, goal, fail flash  
- `scripts/game_flow.gd` — level order and scene changes (autoload **GameFlow**)  
- `scripts/sfx.gd` — optional one-shot SFX (autoload **Sfx**)  
- `scripts/moving_platform.gd` — horizontal sine motion (`AnimatableBody2D`)  
- `scenes/levels/level_01.tscn` … `level_05.tscn` — playable rooftops  
