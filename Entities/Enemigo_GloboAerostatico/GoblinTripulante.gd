class_name GoblinTripulante
extends Node3D

## Tripulante Goblin artillero que va montado en la canasta del Globo Aerostático.
## No tiene físicas de suelo en vuelo. Controla sus animaciones de disparo y recarga,
## y al morir siempre detona el efecto de desmembramiento explosivo con piezas físicas y gravedad.

signal disparo_realizado
signal muerto

const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")
const PROJECTILE_SCALE: Vector3 = Vector3.ONE
const ANIM_DISPARO: String = "Armature|Armature|ENEMIGO_GOBLING_DISPARO"
const ANIM_RECARGA: String = "Armature|Armature|ENEMIGO_GOBLING_RECARGA"

@export_category("Combate - Tripulante")
@export var intervalo_disparo: float = 3.5
@export var velocidad_flecha: float = 8.0
@export var velocidad_recarga: float = 1.8
@export var altura_spawn_flecha: float = 0.4
@export var auto_disparar: bool = true

@export_category("Referencias")
@export var goblin_arrow_scene: PackedScene = preload("res://Entities/Proyectil_Flecha_Goblin/GoblinArrow.tscn")

var is_reloading: bool = false
var is_dead: bool = false
var shoot_timer: float = 1.0

var _anim_player: AnimationPlayer = null
var _player_ref: Node3D = null


func _ready() -> void:
	_buscar_anim_player()
	_player_ref = get_tree().get_first_node_in_group("player") as Node3D
	_play_animation(ANIM_DISPARO)
	shoot_timer = randf_range(1.0, 2.0)


func _physics_process(delta: float) -> void:
	if is_dead or not auto_disparar:
		return

	if is_reloading:
		return

	shoot_timer -= delta
	if shoot_timer <= 0.0:
		disparar()


func disparar() -> void:
	if is_dead:
		return

	_shoot_arrow()
	_start_reload()
	emit_signal("disparo_realizado")


func _shoot_arrow() -> void:
	if not goblin_arrow_scene:
		return

	if not _player_ref or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node3D
		if not _player_ref:
			return

	if _player_ref.get("is_dead"):
		return

	var arrow := PROJECTILE_POOL_REF.acquire(goblin_arrow_scene) as GoblinArrowProjectile
	if not arrow:
		return

	arrow.scale = PROJECTILE_SCALE
	AudioManager.play_sfx("goblin_shoot")

	var spawn_pos: Vector3 = global_position + Vector3(-0.25, altura_spawn_flecha, 0.0)
	var target_pos: Vector3 = _player_ref.global_position + Vector3(0.0, 0.5, 0.0)
	var direction: Vector3 = (target_pos - spawn_pos).normalized()

	var power: float = (velocidad_flecha - 10.0) / 20.0
	arrow.initialize(direction, power)
	arrow.speed = velocidad_flecha

	var root_target: Node = get_tree().current_scene
	if not root_target:
		root_target = get_tree().root
	PROJECTILE_POOL_REF.activate(arrow, root_target, spawn_pos)


func _start_reload() -> void:
	is_reloading = true
	_play_animation(ANIM_RECARGA, 0.2, velocidad_recarga)

	var reload_duration: float = _get_animation_duration(ANIM_RECARGA) / velocidad_recarga
	get_tree().create_timer(maxf(0.1, reload_duration - 0.2), false).timeout.connect(
		func() -> void:
			if is_instance_valid(self) and not is_dead:
				_play_animation(ANIM_DISPARO, 0.3)
				is_reloading = false
				shoot_timer = intervalo_disparo
	)


func morir() -> void:
	if is_dead:
		return
	is_dead = true
	set_physics_process(false)

	var root_scene: Node = get_tree().current_scene
	if not root_scene:
		root_scene = get_tree().root

	# Despedazar las partes configuradas en la escena con físicas y gravedad (sin sangre)
	_eyectar_partes_explotadas(root_scene)

	emit_signal("muerto")
	queue_free()


func _eyectar_partes_explotadas(root_scene: Node) -> void:
	var partes_root: Node3D = get_node_or_null("PartesExplotadas") as Node3D
	if not partes_root:
		return

	partes_root.visible = true
	var piezas_data: Array[Dictionary] = [
		{
			"nodo": partes_root.get_node_or_null("Piernas"),
			"vel": Vector3(randf_range(-1.8, 1.8), randf_range(3.0, 5.0), 0.0),
			"rot": randf_range(-14.0, 14.0),
			"es_piernas": false
		},
		{
			"nodo": partes_root.get_node_or_null("Cabeza"),
			"vel": Vector3(randf_range(-2.0, 2.0), randf_range(4.5, 6.5), 0.0),
			"rot": randf_range(-16.0, 16.0),
			"es_piernas": false
		},
		{
			"nodo": partes_root.get_node_or_null("Brazo_01"),
			"vel": Vector3(randf_range(-3.5, -1.0), randf_range(3.5, 5.5), 0.0),
			"rot": randf_range(-18.0, 18.0),
			"es_piernas": false
		},
		{
			"nodo": partes_root.get_node_or_null("Brazo_02"),
			"vel": Vector3(randf_range(1.0, 3.5), randf_range(3.5, 5.5), 0.0),
			"rot": randf_range(-18.0, 18.0),
			"es_piernas": false
		}
	]

	for data in piezas_data:
		var p_nodo: Node3D = data["nodo"]
		if not p_nodo:
			continue

		var global_tr: Transform3D = p_nodo.global_transform
		if p_nodo.get_parent():
			p_nodo.get_parent().remove_child(p_nodo)

		var contenedor := GoblinPiezaFisica.new()
		contenedor.es_piernas = data["es_piernas"]
		root_scene.add_child(contenedor)
		contenedor.global_transform = global_tr

		p_nodo.transform = Transform3D.IDENTITY
		p_nodo.visible = true
		for m in p_nodo.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi:
				mi.visible = true
				mi.material_override = null
		contenedor.add_child(p_nodo)

		contenedor.iniciar_vuelo(data["vel"], data["rot"])


func _buscar_anim_player() -> void:
	_anim_player = find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer


func _play_animation(anim_name: String, blend_time: float = -1.0, custom_speed: float = 1.0) -> void:
	if not _anim_player:
		_buscar_anim_player()
	if not _anim_player:
		return

	var target_anim := anim_name
	if not _anim_player.has_animation(target_anim):
		for a in _anim_player.get_animation_list():
			if a.ends_with(anim_name) or anim_name.ends_with(a):
				target_anim = a
				break

	if _anim_player.has_animation(target_anim):
		_anim_player.play(target_anim, blend_time, custom_speed)


func _get_animation_duration(anim_name: String) -> float:
	if not _anim_player:
		_buscar_anim_player()
	if not _anim_player:
		return 1.0

	var target_anim := anim_name
	if not _anim_player.has_animation(target_anim):
		for a in _anim_player.get_animation_list():
			if a.ends_with(anim_name) or anim_name.ends_with(a):
				target_anim = a
				break

	if _anim_player.has_animation(target_anim):
		var anim := _anim_player.get_animation(target_anim)
		if anim:
			return anim.length
	return 1.0
