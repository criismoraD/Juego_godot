@tool
extends Area3D
class_name BarreraEscaleraSuperior

## Barrera SUPERIOR para escaleras
## - Bloquea subir (suelta la escalera) si intentas seguir subiendo
## - Permite bajar sin problemas

@export_category("Dimensiones")
@export var tamano: Vector3 = Vector3(1.0, 0.3, 1.0):
	set(value):
		tamano = value
		_actualizar_tamano()

@export_category("Comportamiento")
@export var solo_jugador: bool = true
@export_range(0.0, 2.0) var cooldown_escalera: float = 0.5

# Referencias
var collision_shape: CollisionShape3D
var player_inside: bool = false
var player_ref: CharacterBody3D = null


func _ready():
	if solo_jugador:
		collision_layer = 0
		collision_mask = 1

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_buscar_componentes()
	_actualizar_tamano()


func _buscar_componentes():
	for child in get_children():
		if child is CollisionShape3D:
			collision_shape = child
			break

	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var box = BoxShape3D.new()
		box.size = tamano
		collision_shape.shape = box
		add_child(collision_shape)


func _actualizar_tamano():
	if not collision_shape:
		_buscar_componentes()

	if collision_shape and collision_shape.shape is BoxShape3D:
		collision_shape.shape.size = tamano


func _physics_process(_delta):
	if not player_inside or not is_instance_valid(player_ref):
		return

	# Detectar inputs
	var pressing_up = Input.is_action_pressed("move_forward") or Input.is_action_pressed("ui_up")

	# Si intenta SUBIR ("move_forward") mientras está en la barrera:
	# 1. Aplicamos cooldown SIEMPRE para evitar que la escalera "chupe" al jugador
	# 2. Si ya estaba escalando, lo soltamos
	if pressing_up:
		# Aplicar cooldown preventivo (clave para no quedarse pegado al salir)
		if "ladder_cooldown" in player_ref:
			player_ref.ladder_cooldown = cooldown_escalera

		if _esta_en_escalera(player_ref):
			_soltar_solo_escalera(player_ref)


func _on_body_entered(body):
	if not body.is_in_group("player"):
		return

	player_ref = body
	player_inside = true


func _on_body_exited(body):
	if body == player_ref:
		player_ref = null
		player_inside = false


func _soltar_solo_escalera(player):
	if not _esta_en_escalera(player):
		return

	# Estado AIR
	player.current_move_state = player.MoveState.AIR

	# Reset rotación
	if player.has_method("_reset_armature_rotation"):
		player._reset_armature_rotation()

	# Pequeño empujón opcional para despegarse
	if "velocity" in player:
		pass  # No empujamos horizontalmente necesariamente, solo soltamos


func _esta_en_escalera(player) -> bool:
	if "current_move_state" in player:
		return player.current_move_state == player.MoveState.CLIMBING
	return false
