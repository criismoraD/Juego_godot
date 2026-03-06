# Arrow of Anathema — Copilot Instructions

## Project Overview
**Godot 4.6** (Forward Plus renderer) 2.5D tower-defense/archer game. The player defends a pass against waves of enemies (Goblin, GoblinGirl, Imp). Written in **GDScript**; all code comments and variable names are in **Spanish**. Physics engine: **Jolt Physics**.

## Architecture

### Directory Layout
- `Scripts/` — All GDScript files, mirrored by domain: `Characters/`, `Core/`, `Environment/`, `Levels/`, `Projectiles/`, `UI/`, `Utils/`
- `Scenes/` — `.tscn` files, same subdirectory structure as Scripts
- `Assets/` — Models (`.glb`), Materials (`.tres`), Shaders (`.gdshader`), Textures, Audio, Icons, Videos
- `Translations/` — CSV-based i18n (`translations.csv` → `.translation` resources)
- `Tools/` — Python utilities for FBX/animation pipeline

### Scene Flow
`SplashScreen.tscn` → `LanguageSelector.tscn` → `IntroScene.tscn` → `NIVEL01.tscn` (main gameplay)

### Core Systems
| System | File | Role |
|---|---|---|
| Player | `Scripts/Characters/Player.gd` (extends `CharacterBody3D`) | Movement, aiming, bow combat, ladder climbing, health. AnimationTree built **dynamically in code** (not editor) to avoid corruption |
| Enemy Base | `Scripts/Characters/EnemyBase.gd` (`class_name EnemyBase`) | Shared enemy logic: health, dissolve death shader, damage flash, player tracking. Concrete enemies (`Goblin`, `GoblinGirl`, `ImpEnemy`) **extend** this class via hook methods (`_on_enemy_ready`, `_on_state_walking`, `_on_state_shooting`, `_on_state_dying`) |
| Wave Spawner | `Scripts/Core/WaveSpawner.gd` (`class_name WaveSpawner`) | Spawns enemies in configurable waves with probability rolls |
| Audio | `Scripts/Core/AudioManager.gd` | **Autoload singleton**. Call `AudioManager.play_sfx("key")` / `AudioManager.play_sfx_3d("key", pos)` / `AudioManager.play_music(index)` |
| VFX | `Scripts/Utils/VFXFactory.gd` (`class_name VFXFactory`) | **Static** factory — all methods are `static func`. Procedural GPU particles. Call `VFXFactory.spawn_impact(world, pos)` etc. Includes shader warm-up via `warmup_shaders()` |
| Game UI | `Scripts/UI/GameUI.gd` (extends `CanvasLayer`) | Entire HUD/pause menu created **programmatically** — no `.tscn` UI nodes. Contains resolution selector, volume sliders, debug toggles |

## Conventions & Patterns

### Naming
- **Variables/exports:** Spanish snake_case (`velocidad_caminar`, `vida_maxima`, `fuerza_salto`)
- **Signals:** Spanish snake_case (`oleada_iniciada`, `health_changed`, `died`)
- **Classes:** PascalCase English (`EnemyBase`, `ArrowProjectile`, `WaveSpawner`)
- **Animation names:** SCREAMING_SNAKE with `Armature|` prefix (`Armature|Armature|IDLE`, `ENEMIGO_GOBLING_CORRER`)
- **Files:** PascalCase for scripts/scenes (`GoblinGirl.gd`), SCREAMING_CASE for levels (`NIVEL01.gd`)

### Export Categories
Group `@export` vars with `@export_category("Nombre")` and `@export_subgroup()`. Always include a Spanish comment:
```gdscript
@export_category("Movimiento")
@export var velocidad_caminar: float = 1.0 # Velocidad al caminar
```

### Enemy Inheritance Pattern
New enemies **must extend `EnemyBase`** and override these hooks:
```gdscript
extends EnemyBase
class_name MiEnemigo

func _on_enemy_ready(): ...
func _on_state_walking(): ...
func _on_state_shooting(): ...
func _on_state_dying(): ...
func _process_shooting(delta): ...
```

### Projectile Pattern
Projectiles extend `Area3D` with `class_name`. They use `RayCast3D` CCD (anti-tunneling) and enforce `velocity.z = 0` (2.5D constraint). Stuck arrows self-destruct via timer.

### UI — Programmatic Construction
All UI in `GameUI.gd` is built in code (`_create_ui()`), not in the scene editor. Use `StyleBoxFlat` for consistent medieval dark theme (dark backgrounds, gold/amber borders, rounded corners).

### Dissolve Death Effect
Enemies use a shared dissolve shader (`Assets/Shaders/dissolve.gdshader`) applied at runtime. Materials are cloned and animated via tween. GPU particles accompany the effect.

### i18n
Translations live in `Translations/translations.csv` (14 languages). Use `tr("KEY")` for translated strings. The language selector is a standalone scene.

## Input Map
| Action | Key | Usage |
|---|---|---|
| `move_left` / `move_right` | A / D | Horizontal movement |
| `move_forward` / `move_back` | W / S | Ladder climbing |
| `jump` | Space | Jump |
| `click_izquierdo` | Left Mouse | Aim & shoot bow |

## Key Technical Details
- **Resolution:** 1920×1080 viewport, `canvas_items` stretch mode, fullscreen mode 4
- **FPS cap:** 60 (`run/max_fps=60`)
- **Anti-aliasing:** MSAA 3D level 2 + Screen-space AA
- **Shadow quality:** Directional shadow size 8192, soft shadow quality 3
- **Groups:** `"player"`, `"enemies"`, `"wave_spawners"`
- **Custom shaders:** `dissolve`, `fog_plane`, `TOON_LINEANEGRA` (outline), `Water`, `Displacement`
- **Animation tree:** Player's AnimationTree is constructed in `setup_animation_tree_dynamic()` — never edit it in the Godot editor

## Don'ts
- Do NOT edit the Player's AnimationTree in the editor — it's built dynamically
- Do NOT create UI nodes in `.tscn` for GameUI — everything is code-generated
- Do NOT use `&&` in terminal commands (use `;` for PowerShell)
- Do NOT forget `velocity.z = 0` in projectile physics (2.5D game)
- Do NOT hardcode strings — use `tr("KEY")` and add entries to `translations.csv`
