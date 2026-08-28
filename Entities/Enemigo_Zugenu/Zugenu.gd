class_name Zugenu
extends "res://System/Core/EnemyBase.gd"

const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")
const PROJECTILE_SCALE: Vector3 = Vector3.ONE

## Zugenu: Enemigo goblin de asalto que avanza corriendo y dispara ráfagas de 5 flechas.
## Utiliza los efectos de audio de la arquera goblin y el set completo de animaciones de TEST_/Zugenu.

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTES & MAPAS
# ═══════════════════════════════════════════════════════════════════════════════
const ANIM_FBX_MAP: Dictionary = {
	"CORRER": "res://TEST_/Zugenu/Animaciones/correr.fbx",
	"CAMINAR": "res://TEST_/Zugenu/Animaciones/correr.fbx",
	"DISPARO": "res://TEST_/Zugenu/Animaciones/disparo.fbx",
	"DISPARO_COBERTURA": "res://TEST_/Zugenu/Animaciones/disparo en covertura.fbx",
	"MUERTE_NORMAL": "res://TEST_/Zugenu/Animaciones/muerte normal.fbx",
	"MUERTE_EXPLOSIVA": "res://TEST_/Zugenu/Animaciones/muerte explosiva.fbx",
	"SALTAR": "res://TEST_/Zugenu/Animaciones/saltar.fbx",
	"SUBIR_ESCALERA": "res://TEST_/Zugenu/Animaciones/subir escalera.fbx",
	"VOLTEARSE": "res://TEST_/Zugenu/Animaciones/voltearse.fbx",
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Combate - Zugenu")
@export var intervalo_disparo: float = 3.5
@export var velocidad_flecha: float = 8.0
@export var cantidad_flechas_rafaga: int = 5  ## 5 disparos por ráfaga como el power-up flecha múltiple
@export var intervalo_flechas_rafaga: float = 0.055  ## Intervalo rápido de ~55ms entre flechas
@export var poder_disparo_spread: float = 0.05  ## Dispersión leve entre flechas de la ráfaga
@export var velocidad_recarga: float = 2.0  ## Multiplicador de velocidad de recarga

@export_category("Drops - Zugenu")
@export var power_up_multiple_scene: PackedScene = preload("res://Entities/Item_Flecha_Multiple/PowerUpFlechaMultiple.tscn")
@export_range(0.0, 1.0, 0.01) var drop_chance_flecha_multiple: float = 0.08  ## 8% de drop
@export var municion_drop_jugador: int = 6

# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES
# ═══════════════════════════════════════════════════════════════════════════════
var goblin_arrow_scene: PackedScene = preload("res://Entities/Proyectil_Flecha_Goblin/GoblinArrow.tscn")
var is_reloading: bool = false
var is_shooting_burst: bool = false
var murio_por_explosion: bool = false

# ═══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN Y HOOKS DE ENEMYBASE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	super._ready()
	_cargar_biblioteca_animaciones()
	_play_animation("CORRER")


func _on_enemy_ready() -> void:
	_play_animation("CORRER")


func _on_state_walking() -> void:
	_play_animation("CORRER")


func _on_state_shooting() -> void:
	_play_animation("DISPARO")
	shoot_timer = 0.5


func _on_state_dying() -> void:
	if murio_por_explosion:
		_ejecutar_muerte_explosiva()
		return

	super._on_state_dying()
	AudioManager.play_sfx("goblin_girl_death")
	_drop_power_up()

	var anim_length := _get_animation_duration("MUERTE_NORMAL")
	_play_animation("MUERTE_NORMAL")

	get_tree().create_timer(anim_length + 0.5).timeout.connect(
		func() -> void:
			if is_instance_valid(self) and is_inside_tree():
				_die()
	)


func _ejecutar_muerte_explosiva() -> void:
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

	AudioManager.play_sfx("sangre_splash")
	AudioManager.play_sfx("goblin_explosive_death", 2.3)
	_drop_power_up()

	_play_animation("MUERTE_EXPLOSIVA")
	var anim_length := _get_animation_duration("MUERTE_EXPLOSIVA")

	get_tree().create_timer(anim_length + 0.3).timeout.connect(
		func() -> void:
			if is_instance_valid(self) and is_inside_tree():
				_die()
	)


# ═══════════════════════════════════════════════════════════════════════════════
# CARGA Y REPRODUCCIÓN DE ANIMACIONES
# ═══════════════════════════════════════════════════════════════════════════════

static var _shared_animation_library: AnimationLibrary = null


func _cargar_biblioteca_animaciones() -> void:
	if not anim_player:
		_buscar_animation_player()
	if not anim_player:
		return

	if _shared_animation_library != null:
		if not anim_player.has_animation_library(""):
			anim_player.add_animation_library("", _shared_animation_library)
		return

	_shared_animation_library = AnimationLibrary.new()

	for key_name in ANIM_FBX_MAP.keys():
		var anim_key := str(key_name)
		var fbx_path := str(ANIM_FBX_MAP[key_name])
		if not ResourceLoader.exists(fbx_path):
			continue
		var fbx_scene: PackedScene = load(fbx_path)
		if not fbx_scene:
			continue
		var fbx_inst := fbx_scene.instantiate()
		if not fbx_inst:
			continue
		var player_fbx := fbx_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player_fbx:
			for a_name in player_fbx.get_animation_list():
				var anim_res := player_fbx.get_animation(a_name)
				if anim_res:
					var anim_dup := anim_res.duplicate() as Animation
					if anim_key in ["CORRER", "CAMINAR"]:
						anim_dup.loop_mode = Animation.LOOP_LINEAR
					_shared_animation_library.add_animation(anim_key, anim_dup)
					break
		fbx_inst.free()

	if not anim_player.has_animation_library(""):
		anim_player.add_animation_library("", _shared_animation_library)


func _play_animation(anim_name: String, custom_blend: float = -1.0, speed: float = 1.0) -> void:
	if not anim_player:
		_buscar_animation_player()
	if not anim_player:
		return

	if anim_name == "CORRER" or anim_name == "CAMINAR":
		if anim_player.has_animation("CORRER"):
			var anim = anim_player.get_animation("CORRER")
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play("CORRER", custom_blend, speed)
			return
		for a in anim_player.get_animation_list():
			if "correr" in a.to_lower() or "mixamo" in a.to_lower() or "run" in a.to_lower():
				var anim = anim_player.get_animation(a)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR
				anim_player.play(a, custom_blend, speed)
				return

	super._play_animation(anim_name, custom_blend, speed)


# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO EN RÁFAGA MÚLTIPLE
# ═══════════════════════════════════════════════════════════════════════════════

func _process_shooting(delta: float) -> void:
	velocity.x = 0.0

	if rastrear_jugador:
		_track_player()

	if is_shooting_burst or is_reloading:
		return

	shoot_timer -= delta
	if shoot_timer <= 0.0:
		_disparar_rafaga_multiple()


func _disparar_rafaga_multiple() -> void:
	if is_shooting_burst or not goblin_arrow_scene:
		return

	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return

	if player_ref.get("is_dead"):
		return

	is_shooting_burst = true
	_play_animation("DISPARO")

	for i in range(cantidad_flechas_rafaga):
		if not is_instance_valid(self) or not is_inside_tree() or current_state != State.SHOOTING:
			break
		if player_ref and player_ref.get("is_dead"):
			break

		_disparar_flecha_individual()

		if i < cantidad_flechas_rafaga - 1:
			await get_tree().create_timer(intervalo_flechas_rafaga, false).timeout

	is_shooting_burst = false
	if is_instance_valid(self) and is_inside_tree() and current_state == State.SHOOTING:
		_start_reload()


func _disparar_flecha_individual() -> void:
	if not goblin_arrow_scene:
		return
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return

	var arrow := PROJECTILE_POOL_REF.acquire(goblin_arrow_scene) as GoblinArrowProjectile
	if not arrow:
		return

	arrow.scale = PROJECTILE_SCALE
	AudioManager.play_sfx("goblin_girl_shoot")

	var spawn_pos: Vector3 = global_position + Vector3(-0.3, altura_spawn_flecha, 0.0)
	var target_pos: Vector3 = player_ref.global_position + Vector3(0.0, 0.5, 0.0)

	var spread := Vector3(
		randf_range(-poder_disparo_spread, poder_disparo_spread),
		randf_range(-poder_disparo_spread, poder_disparo_spread),
		0.0
	)
	var direction: Vector3 = (target_pos + spread - spawn_pos).normalized()
	var power: float = (velocidad_flecha - 10.0) / 20.0
	arrow.initialize(direction, power)
	arrow.speed = velocidad_flecha

	PROJECTILE_POOL_REF.activate(arrow, get_tree().root, spawn_pos)


# ═══════════════════════════════════════════════════════════════════════════════
# RECARGA
# ═══════════════════════════════════════════════════════════════════════════════

func _start_reload() -> void:
	is_reloading = true
	_play_animation("CORRER", 0.2, velocidad_recarga)

	var reload_dur := 1.2 / velocidad_recarga
	get_tree().create_timer(reload_dur).timeout.connect(
		func() -> void:
			if is_instance_valid(self) and is_inside_tree() and current_state == State.SHOOTING:
				_play_animation("DISPARO", 0.3)
				is_reloading = false
				shoot_timer = intervalo_disparo
	)


# ═══════════════════════════════════════════════════════════════════════════════
# DROPS
# ═══════════════════════════════════════════════════════════════════════════════

func _drop_power_up() -> void:
	if not power_up_multiple_scene:
		return
	if randf() > drop_chance_flecha_multiple:
		return
	var item := power_up_multiple_scene.instantiate() as Node3D
	if not item:
		return
	if "municion_a_otorgar_jugador" in item:
		item.municion_a_otorgar_jugador = municion_drop_jugador

	var target_parent := get_tree().current_scene
	if target_parent:
		target_parent.add_child(item)
	elif get_parent():
		get_parent().add_child(item)
	item.global_position = global_position + Vector3(0.0, 0.5, 0.0)
