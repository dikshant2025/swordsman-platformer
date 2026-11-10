# Swordsman Platformer

A 2D action platformer built in **Godot 4.4** with **GDScript**. Fight slimes, collect crystals to power up, travel through portals, and defeat an orc boss.

Built as a team project for a game development course at Jacksonville State University. **I wrote the game's code (GDScript).**

## Features
- **Player combat:** melee sword attacks through a hitbox and ranged projectiles, each on its own cooldown timer
- **Three slime enemy types** with their own behavior
- **Orc boss AI:** random roaming, chases the player within range, attack wind-up timed to the animation, hit stagger, health bar
- **Crystal upgrade tiers** that heal the player and permanently raise melee and ranged damage
- **Saved state between levels:** the `GameState` autoload keeps health, damage and crystals when you go through a portal
- Spawn points, portals, UI, sound effects, and levels built from Tiled maps

## Controls
| Action | Input |
|---|---|
| Move | `move_left` / `move_right` |
| Jump | `jump` |
| Melee / ranged attack | `attack_melee` / `attack_ranged` |
| Pick up | `interact_grab` |

(See **Project → Project Settings → Input Map** for the exact keys.)

## Run it
1. Install [Godot 4.4](https://godotengine.org/download).
2. Clone this repo, open Godot, click **Import**, and select `project.godot`.
3. Press **F5**.
