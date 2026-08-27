@tool
class_name BarreraEscaleraBase
extends Area3D

@export_category("Dimensiones")
@export var tamano: Vector3 = Vector3(1.0, 0.3, 1.0):
	set(value):
		tamano = value
		_actualizar_tamano()

@export_category("Comportamiento")
@export var solo_jugador: bool = true
@export_range(0.0, 2.0) var cooldown_escalera: float = 0.2

var collision_shape: CollisionShape3D
var player_inside: bool = false
var player_ref: CharacterBody3D = null


func _ready() -> void:
	if solo_jugador:
		collision_layer = 0
		collision_mask = 1

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_buscar_componentes()
	_actualizar_tamano()


func _buscar_componentes() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			collision_shape = child
			break

	if collision_shape:
		return

	collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = tamano
	collision_shape.shape = box
	add_child(collision_shape)


func _actualizar_tamano() -> void:
	if not collision_shape:
		_buscar_componentes()

	if collision_shape and collision_shape.shape is BoxShape3D:
		(collision_shape.shape as BoxShape3D).size = tamano


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	player_ref = body as CharacterBody3D
	player_inside = true
	_on_player_entered(body)


func _on_body_exited(body: Node3D) -> void:
	if body == player_ref:
		player_ref = null
		player_inside = false


func _on_player_entered(_player: Node3D) -> void:
	pass


func _aplicar_cooldown(player: Node) -> void:
	if "ladder_cooldown" in player:
		player.ladder_cooldown = cooldown_escalera


func _soltar_solo_escalera(player: Node, impulso_x: float = 0.0) -> void:
	if not _esta_en_escalera(player):
		return

	_aplicar_cooldown(player)

	if player.has_method("dismount_ladder_top"):
		player.dismount_ladder_top(impulso_x)
		return

	if player.is_on_floor():
		player.current_move_state = player.MoveState.GROUND
		if player.has_method("set_motion_anim"):
			player.set_motion_anim("ground")
		if "velocity" in player:
			player.velocity.y = 0.0
	else:
		player.current_move_state = player.MoveState.AIR
		if player.has_method("set_motion_anim"):
			player.set_motion_anim("air")

	if player.has_method("_reset_armature_rotation"):
		player._reset_armature_rotation(false)

	if not is_zero_approx(impulso_x) and "velocity" in player:
		player.velocity.x = impulso_x


func _esta_en_escalera(player: Node) -> bool:
	if "current_move_state" in player:
		return player.current_move_state == player.MoveState.CLIMBING
	return false
