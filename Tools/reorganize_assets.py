#!/usr/bin/env python3
"""
Reorganiza los assets del proyecto Godot agrupándolos por elemento.
Mueve archivos + .import/.uid y actualiza TODAS las rutas res:// en el proyecto.

USO: python Tools/reorganize_assets.py
(Ejecutar desde la raíz del proyecto)
"""

import os
import re
import shutil
import sys
from pathlib import Path

# ─── CONFIG ───────────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent
DRY_RUN = False  # Cambiar a True para solo ver qué haría sin mover nada

# ─── MAPEO DE ARCHIVOS: ruta_vieja → ruta_nueva (relativa a PROJECT_ROOT) ────
# Solo archivos principales (sin .import ni .uid — se mueven automáticamente)
MOVE_MAP = {
    # ═══════════════════════════════════════════════════════════════════════════
    # CHARACTERS / PLAYER
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Arquera/GEO_ARQUERA_FINAL_ANIMATION.fbx":
        "Assets/Characters/Player/GEO_ARQUERA_FINAL_ANIMATION.fbx",
    "Assets/Materials/ARQUERA_MATERIAL.tres":
        "Assets/Characters/Player/ARQUERA_MATERIAL.tres",
    "Assets/Textures/Characters/DIFUSE_ARQUERA.png":
        "Assets/Characters/Player/DIFUSE_ARQUERA.png",
    "Assets/Audio/SFX/Player/DAÑO_PERSONAJE0.mp3":
        "Assets/Characters/Player/DAÑO_PERSONAJE0.mp3",
    "Assets/Audio/SFX/Player/DAÑO_PERSONAJE1.mp3":
        "Assets/Characters/Player/DAÑO_PERSONAJE1.mp3",
    "Assets/Audio/SFX/Player/DAÑO_PERSONAJE3.mp3":
        "Assets/Characters/Player/DAÑO_PERSONAJE3.mp3",
    "Assets/Audio/SFX/Player/DISPARO_FLECHA1.mp3":
        "Assets/Characters/Player/DISPARO_FLECHA1.mp3",
    "Assets/Audio/SFX/Player/DISPARO_FLECHA2.mp3":
        "Assets/Characters/Player/DISPARO_FLECHA2.mp3",
    "Assets/Audio/SFX/Player/MANTENER_ARCO.mp3":
        "Assets/Characters/Player/MANTENER_ARCO.mp3",
    "Assets/Audio/SFX/Player/RISA_PERSONAJE.mp3":
        "Assets/Characters/Player/RISA_PERSONAJE.mp3",
    "Assets/Audio/SFX/Player/SFX_player_death.mp3":
        "Assets/Characters/Player/SFX_player_death.mp3",
    "Assets/Audio/SFX/Player/TENSADO_CUERDA1.mp3":
        "Assets/Characters/Player/TENSADO_CUERDA1.mp3",
    "Assets/Audio/SFX/Player/TENSADO_CUERDA2.mp3":
        "Assets/Characters/Player/TENSADO_CUERDA2.mp3",

    # ═══════════════════════════════════════════════════════════════════════════
    # CHARACTERS / ALLY ARCHER
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Arquera_Aliada/ARQUERA_ALIADA.glb":
        "Assets/Characters/AllyArcher/ARQUERA_ALIADA.glb",
    "Assets/Models/Arquera_Aliada/ARQUERA_ALIADA_MATERIAL.tres":
        "Assets/Characters/AllyArcher/ARQUERA_ALIADA_MATERIAL.tres",
    "Assets/Models/Arquera_Aliada/ARQUERA_ALIADA_modddif_image_0.png":
        "Assets/Characters/AllyArcher/ARQUERA_ALIADA_modddif_image_0.png",

    # ═══════════════════════════════════════════════════════════════════════════
    # CHARACTERS / GOBLIN
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Goblin/GOBLING_REMASTER_ANIMACIONES.glb":
        "Assets/Characters/Goblin/GOBLING_REMASTER_ANIMACIONES.glb",
    "Assets/Models/Goblin/GOBLING_MATERIAL.tres":
        "Assets/Characters/Goblin/GOBLING_MATERIAL.tres",
    "Assets/Models/Goblin/GOBLING_REMASTER_ANIMACIONES_modddif_image_0.png":
        "Assets/Characters/Goblin/GOBLING_REMASTER_ANIMACIONES_modddif_image_0.png",
    "Assets/Textures/Characters/TEX_GOBLING.png":
        "Assets/Characters/Goblin/TEX_GOBLING.png",
    "Assets/Audio/SFX/Enemies/MUERTE_GOBLING1.mp3":
        "Assets/Characters/Goblin/MUERTE_GOBLING1.mp3",
    "Assets/Audio/SFX/Enemies/MUERTE_GOBLING2.mp3":
        "Assets/Characters/Goblin/MUERTE_GOBLING2.mp3",
    "Assets/Audio/SFX/Enemies/MUERTE_GOBLING3.mp3":
        "Assets/Characters/Goblin/MUERTE_GOBLING3.mp3",
    "Assets/Audio/SFX/Enemies/SFX_goblin_death01.mp3":
        "Assets/Characters/Goblin/SFX_goblin_death01.mp3",
    "Assets/Audio/SFX/Enemies/SFX_goblin_death02.mp3":
        "Assets/Characters/Goblin/SFX_goblin_death02.mp3",
    "Assets/Audio/SFX/Enemies/SFX_goblin_death03.mp3":
        "Assets/Characters/Goblin/SFX_goblin_death03.mp3",
    "Assets/Audio/SFX/Enemies/DISPARO_Ballesta 1.mp3":
        "Assets/Characters/Goblin/DISPARO_Ballesta 1.mp3",
    "Assets/Audio/SFX/Enemies/DISPARO_Ballesta 2.mp3":
        "Assets/Characters/Goblin/DISPARO_Ballesta 2.mp3",
    "Assets/Audio/SFX/Enemies/DISPARO_Ballesta 3.mp3":
        "Assets/Characters/Goblin/DISPARO_Ballesta 3.mp3",
    "Assets/Audio/SFX/Enemies/EXPLOCION_Muerte 1.mp3":
        "Assets/Characters/Goblin/EXPLOCION_Muerte 1.mp3",
    "Assets/Audio/SFX/Enemies/EXPLOCION_Muerte 2.mp3":
        "Assets/Characters/Goblin/EXPLOCION_Muerte 2.mp3",
    "Assets/Audio/SFX/Enemies/EXPLOCION_Muerte 3.mp3":
        "Assets/Characters/Goblin/EXPLOCION_Muerte 3.mp3",

    # ═══════════════════════════════════════════════════════════════════════════
    # CHARACTERS / GOBLIN GIRL
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Goblin/GEO_GOBLIN_GIRL.fbx":
        "Assets/Characters/GoblinGirl/GEO_GOBLIN_GIRL.fbx",
    "Assets/Materials/MAT_GOBLIN_GIRL.tres":
        "Assets/Characters/GoblinGirl/MAT_GOBLIN_GIRL.tres",
    "Assets/Textures/Characters/TEX_GOBLIN_GIRL.jpg":
        "Assets/Characters/GoblinGirl/TEX_GOBLIN_GIRL.jpg",
    "Assets/Audio/SFX/Enemies/SFX_goblin_girl_death1.mp3":
        "Assets/Characters/GoblinGirl/SFX_goblin_girl_death1.mp3",
    "Assets/Audio/SFX/Enemies/SFX_goblin_girl_death2.mp3":
        "Assets/Characters/GoblinGirl/SFX_goblin_girl_death2.mp3",
    "Assets/Audio/SFX/Enemies/SFX_goblin_girl_death3.mp3":
        "Assets/Characters/GoblinGirl/SFX_goblin_girl_death3.mp3",

    # ═══════════════════════════════════════════════════════════════════════════
    # CHARACTERS / IMP
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Imp/IMP_ENEMIGO.glb":
        "Assets/Characters/Imp/IMP_ENEMIGO.glb",
    "Assets/Materials/MAT_IMP.tres":
        "Assets/Characters/Imp/MAT_IMP.tres",
    "Assets/Models/Imp/IMP_ENEMIGO_texture_pbr_20250901.png":
        "Assets/Characters/Imp/IMP_ENEMIGO_texture_pbr_20250901.png",
    "Assets/Audio/SFX/Enemies/MUERTE_IMP1.mp3":
        "Assets/Characters/Imp/MUERTE_IMP1.mp3",
    "Assets/Audio/SFX/Enemies/MUERTE_IMP2.mp3":
        "Assets/Characters/Imp/MUERTE_IMP2.mp3",
    "Assets/Audio/SFX/TRIDENTE_SHOT.mp3":
        "Assets/Characters/Imp/TRIDENTE_SHOT.mp3",

    # ═══════════════════════════════════════════════════════════════════════════
    # CHARACTERS / IMP SHIELD GIRL
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/IMP_ESCUDO_GIRL/GIRL_IMP_ESCUDO.glb":
        "Assets/Characters/ImpShieldGirl/GIRL_IMP_ESCUDO.glb",
    "Assets/Models/IMP_ESCUDO_GIRL/ESCUDO_IMP.glb":
        "Assets/Characters/ImpShieldGirl/ESCUDO_IMP.glb",
    "Assets/Models/IMP_ESCUDO_GIRL/ESCUDO_IMP_MAT.tres":
        "Assets/Characters/ImpShieldGirl/ESCUDO_IMP_MAT.tres",
    "Assets/Models/IMP_ESCUDO_GIRL/GIRL_IMP_ESCUDO.tres":
        "Assets/Characters/ImpShieldGirl/GIRL_IMP_ESCUDO.tres",
    "Assets/Models/IMP_ESCUDO_GIRL/TEX_IMP_SHIELDDIFUSO.jpg":
        "Assets/Characters/ImpShieldGirl/TEX_IMP_SHIELDDIFUSO.jpg",
    "Assets/Models/IMP_ESCUDO_GIRL/ESCUDO_IMP_TEX.jpg":
        "Assets/Characters/ImpShieldGirl/ESCUDO_IMP_TEX.jpg",
    "Assets/Models/IMP_ESCUDO_GIRL/A.jpg":
        "Assets/Characters/ImpShieldGirl/A.jpg",
    "Assets/Models/IMP_ESCUDO_GIRL/IMPACTO_IMP_ESCUDO_01.mp3":
        "Assets/Characters/ImpShieldGirl/IMPACTO_IMP_ESCUDO_01.mp3",
    "Assets/Models/IMP_ESCUDO_GIRL/IMPACTO_IMP_ESCUDO_02.mp3":
        "Assets/Characters/ImpShieldGirl/IMPACTO_IMP_ESCUDO_02.mp3",
    "Assets/Models/IMP_ESCUDO_GIRL/MUERTE_IMP_ESCUDO_01.mp3":
        "Assets/Characters/ImpShieldGirl/MUERTE_IMP_ESCUDO_01.mp3",
    "Assets/Models/IMP_ESCUDO_GIRL/MUERTE_IMP_ESCUDO_2.mp3":
        "Assets/Characters/ImpShieldGirl/MUERTE_IMP_ESCUDO_2.mp3",

    # ═══════════════════════════════════════════════════════════════════════════
    # PROJECTILES / ARROW (Flecha del jugador)
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Armas y Projectiles/FLECHA.fbx":
        "Assets/Projectiles/Arrow/FLECHA.fbx",
    "Assets/Materials/Arrows.tres":
        "Assets/Projectiles/Arrow/Arrows.tres",
    "Assets/Textures/Armas y Projectiles/Arrows_Base_color.jpg":
        "Assets/Projectiles/Arrow/Arrows_Base_color.jpg",
    "Assets/Models/Armas y Projectiles/VIROTE_BALLESTA_Arrows_Base_color.jpg":
        "Assets/Projectiles/Arrow/VIROTE_BALLESTA_Arrows_Base_color.jpg",

    # ═══════════════════════════════════════════════════════════════════════════
    # PROJECTILES / GOBLIN CROSSBOW (Ballesta goblin)
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Armas y Projectiles/BALLES_GOBLING.glb":
        "Assets/Projectiles/GoblinCrossbow/BALLES_GOBLING.glb",
    "Assets/Models/Armas y Projectiles/VIROTE_BALLESTA.glb":
        "Assets/Projectiles/GoblinCrossbow/VIROTE_BALLESTA.glb",
    "Assets/Materials/Hand Crossbow.tres":
        "Assets/Projectiles/GoblinCrossbow/Hand Crossbow.tres",
    "Assets/Models/Armas y Projectiles/BALLESTA_GOBLING.png":
        "Assets/Projectiles/GoblinCrossbow/BALLESTA_GOBLING.png",
    "Assets/Textures/Armas y Projectiles/TEX_BALLESTA.png":
        "Assets/Projectiles/GoblinCrossbow/TEX_BALLESTA.png",

    # ═══════════════════════════════════════════════════════════════════════════
    # PROJECTILES / IMP TRIDENT
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Imp/TRIDENTE PROYECTIL.fbx":
        "Assets/Projectiles/ImpTrident/TRIDENTE PROYECTIL.fbx",

    # ═══════════════════════════════════════════════════════════════════════════
    # WEAPONS / PLAYER BOW
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Armas y Projectiles/GEO_ARCO_ANIMADO.fbx":
        "Assets/Weapons/PlayerBow/GEO_ARCO_ANIMADO.fbx",
    "Assets/Materials/Recurve Bow 2.tres":
        "Assets/Weapons/PlayerBow/Recurve Bow 2.tres",
    "Assets/Textures/Armas y Projectiles/DIF_ARCO_PROTA.jpg":
        "Assets/Weapons/PlayerBow/DIF_ARCO_PROTA.jpg",

    # ═══════════════════════════════════════════════════════════════════════════
    # WEAPONS / GOBLIN BOW
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Armas y Projectiles/ARCO_GOBLING_GIRL.glb":
        "Assets/Weapons/GoblinBow/ARCO_GOBLING_GIRL.glb",
    "Assets/Materials/ARCO_GIRL_GOBLING.tres":
        "Assets/Weapons/GoblinBow/ARCO_GIRL_GOBLING.tres",
    "Assets/Models/Armas y Projectiles/ARCO_GOBLING_GIRL_texture_20250901.png":
        "Assets/Weapons/GoblinBow/ARCO_GOBLING_GIRL_texture_20250901.png",

    # ═══════════════════════════════════════════════════════════════════════════
    # ENVIRONMENT / TOWER
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Environment/MDL_tower.fbx":
        "Assets/Environment/Tower/MDL_tower.fbx",
    "Assets/Materials/MAT_tower.tres":
        "Assets/Environment/Tower/MAT_tower.tres",
    "Assets/Textures/Environment/TEX_tower_basecolor.png":
        "Assets/Environment/Tower/TEX_tower_basecolor.png",
    "Assets/Textures/Tower/001_TORRE_Normal.png":
        "Assets/Environment/Tower/001_TORRE_Normal.png",
    "Assets/Textures/Tower/001_TORRE_Roughness.png":
        "Assets/Environment/Tower/001_TORRE_Roughness.png",

    # ═══════════════════════════════════════════════════════════════════════════
    # ENVIRONMENT / PLATFORM
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Environment/MDL_platform.fbx":
        "Assets/Environment/Platform/MDL_platform.fbx",
    "Assets/Materials/MAT_platform.tres":
        "Assets/Environment/Platform/MAT_platform.tres",
    "Assets/Textures/Environment/TEX_platform_basecolor.png":
        "Assets/Environment/Platform/TEX_platform_basecolor.png",

    # ═══════════════════════════════════════════════════════════════════════════
    # ENVIRONMENT / SHIELD
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Environment/MDL_shield.fbx":
        "Assets/Environment/Shield/MDL_shield.fbx",
    "Assets/Models/Environment/escudo_partes.glb":
        "Assets/Environment/Shield/escudo_partes.glb",
    "Assets/Materials/MAT_shield.tres":
        "Assets/Environment/Shield/MAT_shield.tres",
    "Assets/Materials/ESCUDO_INT.tres":
        "Assets/Environment/Shield/ESCUDO_INT.tres",
    "Assets/Textures/Environment/TEX_shield_basecolor.png":
        "Assets/Environment/Shield/TEX_shield_basecolor.png",
    "Assets/Models/Environment/escudo_partes_escudo_partes_TEX_shield_basecolor.png":
        "Assets/Environment/Shield/escudo_partes_escudo_partes_TEX_shield_basecolor.png",
    "Assets/Audio/SFX/Environment/ESCUDO_ROTO.mp3":
        "Assets/Environment/Shield/ESCUDO_ROTO.mp3",
    "Assets/Audio/SFX/Environment/IMPACTO_ESCUDO_BALLESTA.mp3":
        "Assets/Environment/Shield/IMPACTO_ESCUDO_BALLESTA.mp3",
    "Assets/Audio/SFX/Environment/IMPACTO_ESCUDO_FLECHA.mp3":
        "Assets/Environment/Shield/IMPACTO_ESCUDO_FLECHA.mp3",

    # ═══════════════════════════════════════════════════════════════════════════
    # ENVIRONMENT / SPIKE TRAP
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Environment/MDL_spike_trap.fbx":
        "Assets/Environment/SpikeTrap/MDL_spike_trap.fbx",
    "Assets/Models/Environment/PINCHO.glb":
        "Assets/Environment/SpikeTrap/PINCHO.glb",
    "Assets/Materials/MAT_spike_trap.tres":
        "Assets/Environment/SpikeTrap/MAT_spike_trap.tres",
    "Assets/Materials/PINCHO_MATERIAL.tres":
        "Assets/Environment/SpikeTrap/PINCHO_MATERIAL.tres",
    "Assets/Textures/Environment/TEX_spike_trap_basecolor.png":
        "Assets/Environment/SpikeTrap/TEX_spike_trap_basecolor.png",
    "Assets/Textures/Environment/PINCHO_modddif_image_2.png":
        "Assets/Environment/SpikeTrap/PINCHO_modddif_image_2.png",

    # ═══════════════════════════════════════════════════════════════════════════
    # ENVIRONMENT / TREE
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Environment/ARBOL.glb":
        "Assets/Environment/Tree/ARBOL.glb",
    "Assets/Models/Environment/ARBOL_modddif_image_5.png":
        "Assets/Environment/Tree/ARBOL_modddif_image_5.png",
    "Assets/Textures/Environment/ARBOL_modddif_image_5.png":
        "Assets/Environment/Tree/ARBOL_modddif_image_5_tex.png",

    # ═══════════════════════════════════════════════════════════════════════════
    # ENVIRONMENT / LOG (TRONCO)
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Environment/TRONCO.glb":
        "Assets/Environment/Log/TRONCO.glb",
    "Assets/Models/Environment/TRONCO_modddif_image_0.png":
        "Assets/Environment/Log/TRONCO_modddif_image_0.png",
    "Assets/Textures/Environment/TRONCO_modddif_image_0.png":
        "Assets/Environment/Log/TRONCO_modddif_image_0_tex.png",

    # ═══════════════════════════════════════════════════════════════════════════
    # ENVIRONMENT / PILLAR
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Environment/pilar beta.glb":
        "Assets/Environment/Pillar/pilar beta.glb",
    "Assets/Models/Environment/MDL_column.fbx":
        "Assets/Environment/Pillar/MDL_column.fbx",
    "Assets/Models/Environment/pilar beta_modddif_image_0.png":
        "Assets/Environment/Pillar/pilar beta_modddif_image_0.png",
    "Assets/Models/Environment/pilar beta_modddif_image_1.png":
        "Assets/Environment/Pillar/pilar beta_modddif_image_1.png",
    "Assets/Textures/Environment/pilar beta_modddif_image_0.png":
        "Assets/Environment/Pillar/pilar beta_modddif_image_0_tex.png",
    "Assets/Textures/Environment/pilar beta_modddif_image_1.png":
        "Assets/Environment/Pillar/pilar beta_modddif_image_1_tex.png",

    # ═══════════════════════════════════════════════════════════════════════════
    # ENVIRONMENT / STATUE (ESTATUA MEDEA)
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Environment/ESTATUA_.MEDEA.glb":
        "Assets/Environment/Statue/ESTATUA_.MEDEA.glb",
    "Assets/Materials/MATERIAL_ESTATUA_MEDEA.tres":
        "Assets/Environment/Statue/MATERIAL_ESTATUA_MEDEA.tres",
    "Assets/Textures/Environment/ESTAUTA_MEDEA_TEXTURA.png":
        "Assets/Environment/Statue/ESTAUTA_MEDEA_TEXTURA.png",
    "Assets/Textures/estatua.png":
        "Assets/Environment/Statue/estatua.png",
    "Assets/Textures/ARTERA_TEs.png":
        "Assets/Environment/Statue/ARTERA_TEs.png",

    # ═══════════════════════════════════════════════════════════════════════════
    # ENVIRONMENT / HELMET (YELMO)
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Environment/Yelmo fachero.glb":
        "Assets/Environment/Helmet/Yelmo fachero.glb",
    "Assets/Materials/MATERIAL_YELMO.tres":
        "Assets/Environment/Helmet/MATERIAL_YELMO.tres",
    "Assets/Textures/Environment/TEXTURA_YELMO.png":
        "Assets/Environment/Helmet/TEXTURA_YELMO.png",

    # ═══════════════════════════════════════════════════════════════════════════
    # ENVIRONMENT / LADDER (ESCALERA)
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Models/Ladder/GEO_ESCALERA.fbx":
        "Assets/Environment/Ladder/GEO_ESCALERA.fbx",
    "Assets/Materials/ESCALERAS.tres":
        "Assets/Environment/Ladder/ESCALERAS.tres",
    "Assets/Textures/Environment/COLOR_ESCALERA.png":
        "Assets/Environment/Ladder/COLOR_ESCALERA.png",

    # ═══════════════════════════════════════════════════════════════════════════
    # ENVIRONMENT / FLOOR (PISO)
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Textures/Floor/COLOR PISO 1.jpeg":
        "Assets/Environment/Floor/COLOR PISO 1.jpeg",
    "Assets/Textures/Floor/PISO-01_DISPLACEMENT.jpeg":
        "Assets/Environment/Floor/PISO-01_DISPLACEMENT.jpeg",
    "Assets/Textures/Floor/PISO-01_NORMAL.jpeg":
        "Assets/Environment/Floor/PISO-01_NORMAL.jpeg",
    "Assets/Textures/Environment/DIFUSO01.jpeg":
        "Assets/Environment/Floor/DIFUSO01.jpeg",
    "Assets/Textures/Environment/ALTURA01.jpeg":
        "Assets/Environment/Floor/ALTURA01.jpeg",

    # ═══════════════════════════════════════════════════════════════════════════
    # ENVIRONMENT / GRASS (PASTO)
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Textures/Grass/GRASS_COLOR.jpeg":
        "Assets/Environment/Grass/GRASS_COLOR.jpeg",
    "Assets/Textures/Grass/GRASS_DIF.jpeg":
        "Assets/Environment/Grass/GRASS_DIF.jpeg",
    "Assets/Textures/Grass/GRASS_DISPLACEMENT.jpeg":
        "Assets/Environment/Grass/GRASS_DISPLACEMENT.jpeg",
    "Assets/Textures/Grass/GRASS_NORMAL.jpg":
        "Assets/Environment/Grass/GRASS_NORMAL.jpg",

    # ═══════════════════════════════════════════════════════════════════════════
    # ENVIRONMENT / WATER
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Materials/Water.tres":
        "Assets/Environment/Water/Water.tres",

    # ═══════════════════════════════════════════════════════════════════════════
    # ENVIRONMENT / FOG PLANE
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Materials/MAT_fog_plane.tres":
        "Assets/Environment/FogPlane/MAT_fog_plane.tres",

    # ═══════════════════════════════════════════════════════════════════════════
    # ENVIRONMENT / BACKGROUND
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Textures/Environment/background_mountains.png":
        "Assets/Environment/Background/background_mountains.png",
    "Assets/Textures/Environment/background_mountains_02.jpeg":
        "Assets/Environment/Background/background_mountains_02.jpeg",
    "Assets/Textures/Environment/mountain_transparency.png":
        "Assets/Environment/Background/mountain_transparency.png",
    "Assets/Textures/Environment/sky_2.png":
        "Assets/Environment/Background/sky_2.png",

    # ═══════════════════════════════════════════════════════════════════════════
    # AUDIO / MUSIC (se mantiene agrupada)
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Audio/Music/BGM_battle.mp3":
        "Assets/Audio/Music/BGM_battle.mp3",
    "Assets/Audio/Music/BGM_main_theme.mp3":
        "Assets/Audio/Music/BGM_main_theme.mp3",

    # ═══════════════════════════════════════════════════════════════════════════
    # UI TEXTURES
    # ═══════════════════════════════════════════════════════════════════════════
    "Assets/Textures/UI/1frame.png":
        "Assets/UI/1frame.png",
    "Assets/Textures/UI/CARGA 01.png.import":
        "Assets/UI/CARGA 01.png.import",
    "Assets/Textures/UI/menu.jpg.import":
        "Assets/UI/menu.jpg.import",
    "Assets/Textures/UI/SPLASH_SCREEN.jpeg":
        "Assets/UI/SPLASH_SCREEN.jpeg",

    # ═══════════════════════════════════════════════════════════════════════════
    # VIDEOS (se mantienen)
    # ═══════════════════════════════════════════════════════════════════════════
    # Videos stay in Assets/Videos/ — no move needed
}

# Quitar entradas donde origen == destino
MOVE_MAP = {k: v for k, v in MOVE_MAP.items() if k != v}


def to_res_path(rel: str) -> str:
    """Convierte ruta relativa del proyecto a ruta res:// de Godot (siempre forward slashes)."""
    return "res://" + rel.replace("\\", "/")


def get_companion_files(base_path: Path) -> list[Path]:
    """Devuelve archivos asociados (.import, .uid) que acompañan a un archivo base."""
    companions = []
    for suffix in [".import", ".uid"]:
        companion = base_path.parent / (base_path.name + suffix)
        if companion.exists():
            companions.append(companion)
    return companions


def move_file_with_companions(src: Path, dst: Path) -> list[tuple[str, str]]:
    """
    Mueve un archivo y sus .import/.uid al destino.
    Retorna lista de (old_res_path, new_res_path) para actualizar referencias.
    """
    moves = []

    # Crear directorio destino
    dst.parent.mkdir(parents=True, exist_ok=True)

    # Archivo principal
    if src.exists():
        if DRY_RUN:
            print(f"  [DRY] {src} → {dst}")
        else:
            shutil.move(str(src), str(dst))
        old_res = to_res_path(str(src.relative_to(PROJECT_ROOT)))
        new_res = to_res_path(str(dst.relative_to(PROJECT_ROOT)))
        moves.append((old_res, new_res))

    # Companions (.import, .uid)
    for companion in get_companion_files(src):
        comp_dst = dst.parent / (dst.name + companion.suffix.replace(src.name, dst.name))
        # El companion tiene nombre = base_name + ext + .import (ej: FLECHA.fbx.import)
        comp_suffix = companion.name[len(src.name):]  # ".import" o ".uid"
        comp_dst = dst.parent / (dst.name + comp_suffix)

        if DRY_RUN:
            print(f"  [DRY] {companion} → {comp_dst}")
        else:
            shutil.move(str(companion), str(comp_dst))

        old_res = to_res_path(str(companion.relative_to(PROJECT_ROOT)))
        new_res = to_res_path(str(comp_dst.relative_to(PROJECT_ROOT)))
        moves.append((old_res, new_res))

    return moves


def update_references_in_file(filepath: Path, replacements: dict[str, str]) -> int:
    """
    Reemplaza todas las rutas res:// viejas por las nuevas en un archivo.
    Retorna el número de reemplazos realizados.
    """
    try:
        content = filepath.read_text(encoding="utf-8", errors="replace")
    except (PermissionError, OSError):
        return 0

    original = content
    count = 0

    # Ordenar reemplazos por longitud de clave descendente para evitar reemplazos parciales
    # (ej: res://Assets/Models/Goblin/ antes que res://Assets/Models/)
    for old_path, new_path in sorted(replacements.items(), key=lambda x: -len(x[0])):
        if old_path in content:
            content = content.replace(old_path, new_path)
            count += content.count(new_path)  # Rough count

    if content != original:
        if DRY_RUN:
            print(f"  [DRY] Actualizaría referencias en: {filepath}")
        else:
            filepath.write_text(content, encoding="utf-8")
        return count
    return 0


def update_import_file_content(import_path: Path, replacements: dict[str, str]):
    """Actualiza las rutas dentro de archivos .import."""
    if not import_path.exists():
        return
    try:
        content = import_path.read_text(encoding="utf-8", errors="replace")
    except (PermissionError, OSError):
        return

    original = content
    for old_path, new_path in sorted(replacements.items(), key=lambda x: -len(x[0])):
        content = content.replace(old_path, new_path)

    if content != original and not DRY_RUN:
        import_path.write_text(content, encoding="utf-8")


def find_project_files(root: Path) -> list[Path]:
    """Encuentra todos los archivos del proyecto que pueden contener rutas res://."""
    extensions = {
        ".tscn", ".tres", ".gd", ".import", ".godot", ".cfg",
        ".gdshader", ".uid", ".csv", ".md", ".txt", ".json"
    }
    skip_dirs = {".godot", ".git", "__pycache__", "Assets_Backup"}
    result = []

    for dirpath, dirnames, filenames in os.walk(root):
        # Evitar directorios que no necesitamos
        dirnames[:] = [d for d in dirnames if d not in skip_dirs]

        for fname in filenames:
            fpath = Path(dirpath) / fname
            if fpath.suffix.lower() in extensions:
                result.append(fpath)

    return result


def cleanup_empty_dirs(root: Path):
    """Elimina directorios vacíos dentro de Assets/ después de mover archivos."""
    assets_dir = root / "Assets"
    # Recorrer de abajo hacia arriba
    for dirpath, dirnames, filenames in os.walk(assets_dir, topdown=False):
        dp = Path(dirpath)
        if dp == assets_dir:
            continue
        # No eliminar carpetas de la nueva estructura
        try:
            if not any(dp.iterdir()):
                if DRY_RUN:
                    print(f"  [DRY] Eliminaría directorio vacío: {dp}")
                else:
                    dp.rmdir()
                    print(f"  🗑️  Directorio vacío eliminado: {dp.relative_to(root)}")
        except OSError:
            pass


def main():
    print("=" * 70)
    print("  REORGANIZACIÓN DE ASSETS — Arrow of Anathema")
    print("=" * 70)

    if DRY_RUN:
        print("\n⚠️  MODO DRY RUN — No se moverá ningún archivo\n")

    os.chdir(PROJECT_ROOT)

    # ─── PASO 1: Validar que los archivos origen existen ─────────────────────
    print("\n📋 Paso 1: Validando archivos origen...")
    missing = []
    # Manejar el caso especial de archivos .import huérfanos (CARGA 01.png.import, menu.jpg.import)
    special_import_only = set()
    for old_rel in MOVE_MAP:
        old_path = PROJECT_ROOT / old_rel
        if not old_path.exists():
            # Puede ser un .import huérfano que se mapea directamente
            if old_rel.endswith(".import"):
                special_import_only.add(old_rel)
                continue
            missing.append(old_rel)
    
    if missing:
        print(f"\n❌ {len(missing)} archivos no encontrados:")
        for m in missing:
            print(f"   - {m}")
        print("\nSe continuará sin estos archivos.\n")
    else:
        print(f"   ✅ Todos los archivos origen existen ({len(MOVE_MAP)} archivos)")

    # ─── PASO 2: Construir mapa de rutas res:// ─────────────────────────────
    print("\n📋 Paso 2: Construyendo mapa de rutas res://...")
    res_replacements: dict[str, str] = {}

    for old_rel, new_rel in MOVE_MAP.items():
        if old_rel in missing:
            continue
        old_path = PROJECT_ROOT / old_rel
        new_path = PROJECT_ROOT / new_rel

        # Ruta principal
        old_res = to_res_path(old_rel)
        new_res = to_res_path(new_rel)
        res_replacements[old_res] = new_res

        # También mapear companion .import y .uid paths
        for suffix in [".import", ".uid"]:
            old_comp = old_rel + suffix
            new_comp = new_rel + suffix
            if (PROJECT_ROOT / old_comp).exists() or old_rel in special_import_only:
                res_replacements[to_res_path(old_comp)] = to_res_path(new_comp)

    print(f"   ✅ {len(res_replacements)} rutas res:// mapeadas")

    # ─── PASO 3: Actualizar referencias en TODOS los archivos del proyecto ──
    print("\n📋 Paso 3: Actualizando referencias en archivos del proyecto...")
    project_files = find_project_files(PROJECT_ROOT)
    updated_count = 0
    for pf in project_files:
        n = update_references_in_file(pf, res_replacements)
        if n > 0:
            updated_count += 1
            print(f"   📝 Actualizado: {pf.relative_to(PROJECT_ROOT)}")

    print(f"   ✅ {updated_count} archivos actualizados con nuevas rutas")

    # ─── PASO 4: Mover archivos ─────────────────────────────────────────────
    print("\n📋 Paso 4: Moviendo archivos...")
    moved_count = 0
    for old_rel, new_rel in MOVE_MAP.items():
        if old_rel in missing:
            continue

        old_path = PROJECT_ROOT / old_rel
        new_path = PROJECT_ROOT / new_rel

        if not old_path.exists():
            continue

        moves = move_file_with_companions(old_path, new_path)
        moved_count += len(moves)

    # Mover archivos .import huérfanos especiales
    for old_rel in special_import_only:
        old_path = PROJECT_ROOT / old_rel
        new_rel = MOVE_MAP[old_rel]
        new_path = PROJECT_ROOT / new_rel
        if old_path.exists():
            new_path.parent.mkdir(parents=True, exist_ok=True)
            if not DRY_RUN:
                shutil.move(str(old_path), str(new_path))
            moved_count += 1

    print(f"   ✅ {moved_count} archivos movidos (incluyendo .import/.uid)")

    # ─── PASO 5: Actualizar contenido de archivos .import en nueva ubicación
    print("\n📋 Paso 5: Actualizando contenido de archivos .import en nuevas ubicaciones...")
    import_files = list(PROJECT_ROOT.rglob("*.import"))
    import_updated = 0
    for imp in import_files:
        if ".godot" in str(imp) or "Assets_Backup" in str(imp):
            continue
        try:
            content = imp.read_text(encoding="utf-8", errors="replace")
        except (PermissionError, OSError):
            continue
        original = content
        for old_res, new_res in sorted(res_replacements.items(), key=lambda x: -len(x[0])):
            content = content.replace(old_res, new_res)
        if content != original:
            if not DRY_RUN:
                imp.write_text(content, encoding="utf-8")
            import_updated += 1

    print(f"   ✅ {import_updated} archivos .import actualizados internamente")

    # ─── PASO 6: Limpiar directorios vacíos ────────────────────────────────
    print("\n📋 Paso 6: Limpiando directorios vacíos...")
    cleanup_empty_dirs(PROJECT_ROOT)

    # ─── PASO 7: Sugerir limpiar caché de Godot ────────────────────────────
    print("\n" + "=" * 70)
    print("  ✅ REORGANIZACIÓN COMPLETADA")
    print("=" * 70)
    print(f"""
📌 Resumen:
   • {moved_count} archivos movidos
   • {updated_count} archivos de proyecto actualizados
   • {import_updated} archivos .import parcheados

⚠️  PRÓXIMOS PASOS:
   1. Elimina la carpeta .godot/imported/ para forzar reimportación
   2. Abre el proyecto en Godot Editor
   3. Godot reimportará todos los assets automáticamente
   4. Verifica que todo funciona antes de hacer commit
""")


if __name__ == "__main__":
    main()
