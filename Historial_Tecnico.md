## Estado
- Plugin Level Designer creado para configurar 30 niveles.
- Oleada 2 configurada con Imp + GoblinGirl + GoblinBallesta. Cañonero removido del spawn.
- Carpeta Assets reorganizada por entidades (sin subcarpetas).

## Completado
- **Plugin Level Designer** (`addons/level_designer/`):
  - `plugin.cfg` + `plugin.gd`: Entry point, registra dock en el editor.
  - `level_data.gd`: Resource principal, guarda oleadas, elementos y fondo por nivel.
  - `oleada_data.gd`: Resource de oleada, lista de enemigos con % probabilidad.
  - `enemigo_data.gd`: Resource de enemigo, path de escena + probabilidad.
  - `level_data_store.gd`: Autoload que carga/guarda 30 niveles (.tres) en `res://Levels/`.
  - `editor_panel.gd` + `.tscn`: UI con grid de niveles (1-30), tabs de Oleadas/Enemigos/Elementos/Fondo.
  - Integrado en `project.godot` (editor_plugins).
  - Ejemplo: `Levels/level_01.tres` con 1 oleada (Imp + GoblinGirl 50/50).
- Añadidas claves `CARTEL_LEVEL_01` y `CARTEL_LEVEL_02` en `Translations/translations.csv`.
- Modificado `Scripts/Levels/NIVEL01.gd`:
  - Cartel "Level 01" al dañar pacíficos.
  - UI interactiva "Level 1 Complete" + Botón Continuar (sin fondo negro, texto blanco).
  - Cartel "Level 02" tras continuar.
- **Oleada 2 (`_configurar_oleada_combate`)**:
  - Ahora recibe parámetro `numero_oleada`.
  - Oleada 1: Imp 50% + GoblinGirl 50%, sin Goblin base.
  - Oleada 2: Imp 33% + GoblinGirl 33% + Goblin (ballesta) 33%.
  - `probabilidad_canonero = 0.0` en ambas oleadas (cañonero removido del spawn).
- **Reorganización Assets**:
  - `Assets/Canonero/` → modelo + textura del cañonero.
  - `Assets/Protagonista/` → PROTA_*.png, IMP_ICON.png, PASIFISTA.jpeg, CAPA1_V.png.
  - `Assets/Piso/` → PISO.glb, PISO_D.jpg, PISO_M.tres, PISO_MAT.tres.
  - `Assets/Characters/Player/` → modelo, texturas, sonidos, arco (GEO_ARCO_ANIMADO), flecha (FLECHA.fbx).
  - `Assets/Characters/Goblin/` → modelo, texturas, sonidos, ballesta (BALLES_GOBLING), virote.
  - `Assets/Characters/GoblinGirl/` → modelo, texturas, sonidos, arco (ARCO_GOBLING_GIRL).
  - `Assets/Characters/Imp/` → modelo, texturas, sonidos, tridente (TRIDENTE PROYECTIL).
  - Eliminadas carpetas vacías: `Assets/Weapons/`, `Assets/Projectiles/`.
  - Todas las referencias en `.tscn`, `.gd`, `.tres`, `.import` actualizadas a las nuevas rutas.

- **Contador de enemigos**: Fix del bug que mostraba valores incorrectos (20/16, 16/15). Ahora usa `enemigos_muertos_en_oleada` en `WaveSpawner` y el cálculo es `total - muertos`, garantizando siempre el valor correcto (ej. 15/15).
- **Skip diálogos con ESC**: Añadido `_unhandled_input` en `DialogoComic.gd` para saltar el reveal de texto o cerrar el diálogo con la tecla ESC (`ui_cancel`).
- **Fix nivel no termina al matar 15 enemigos**:
  - `_start_wave()` preserva `goblins_spawned_in_wave = active_goblins.size()` para que los pacíficos convertidos cuenten como ya spawneados.
  - `_spawn_shield_imp()` ya NO incrementa `goblins_spawned_in_wave` (los escudos son spawns independientes).
  - `_check_wave_complete()` ignora los escudos al contar enemigos vivos.
  - `_monitorear_nivel_1()` en `NIVEL01.gd` también ignora escudos al verificar victoria.
- **Eliminadas partículas trail del proyectil ImpTrident** (`Scripts/Projectiles/ImpTrident.gd`): removida toda la lógica de `GPUParticles3D` del tridente.

## Pendiente
- Asegurar soporte de traducción.
- Reimportar assets en Godot para regenerar caché.
