@tool
extends Area3D
class_name BarreraEscalera

## Barrera especial para escaleras
## - Bloquea bajar por la escalera cuando el jugador está escalando y dentro de la zona
## - Permite subir la escalera sin restricción
## - NO afecta al jugador que camina sobre la plataforma

@export_category("Dimensiones")
@export var tamano: Vector3 = Vector3(1.0, 0.3, 1.0):
	set(value):
		tamano = value
		_actualizar_tamano()

@export_category("Comportamiento")
@export var solo_jugador: bool = true
@export_range(0.0, 2.0) var cooldown_escalera: float = 0.2  # Tiempo de espera antes de poder volver a usar la escalera

# Referencias
var collision_shape: CollisionShape3D
var player_inside: bool = false
var player_ref: CharacterBody3D = null


func _ready():
	# Configurar layers de colisión
	if solo_jugador:
		collision_layer = 0
		collision_mask = 1

	# Conectar señales
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Buscar collision shape
	_buscar_componentes()
	_actualizar_tamano()


func _buscar_componentes():
	for child in get_children():
		if child is CollisionShape3D:
			collision_shape = child
			break

	# Crear CollisionShape si no existe
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

	# Verificar input de movimiento vertical
	var pressing_down = Input.is_action_pressed("move_back") or Input.is_action_pressed("ui_down")
	var pressing_up = Input.is_action_pressed("move_forward") or Input.is_action_pressed("ui_up")

	# Si presiona abajo:
	# 1. Aplicar cooldown constantemente (PREVIENE ENTRAR a la escalera con glitch)
	# 2. Si YA está escalando, soltarlo
	if pressing_down:
		if "ladder_cooldown" in player_ref:
			player_ref.ladder_cooldown = cooldown_escalera

		# Solo soltar si está actualmente escalando y no intentando subir
		if not pressing_up and _esta_en_escalera(player_ref):
			_soltar_solo_escalera(player_ref)


func _on_body_entered(body):
	if not body.is_in_group("player"):
		return

	player_ref = body
	player_inside = true

	# Solo actuar si viene CAYENDO desde arriba Y está escalando
	if not _esta_en_escalera(body):
		return  # No hacer nada si no está escalando

	var barrier_top = global_position.y + (tamano.y / 2.0)
	var player_bottom = body.global_position.y
	var player_velocity_y = body.velocity.y if "velocity" in body else 0.0

	if player_bottom > barrier_top and player_velocity_y < -0.5:
		_soltar_solo_escalera(body)


func _on_body_exited(body):
	if body == player_ref:
		player_ref = null
		player_inside = false


func _soltar_solo_escalera(player):
	"""Desconecta al jugador de la escalera"""
	# Verificar DOBLEMENTE que está escalando antes de hacer algo
	if not _esta_en_escalera(player):
		return

	# Aplicar cooldown para no reconectar inmediatamente
	if "ladder_cooldown" in player:
		player.ladder_cooldown = cooldown_escalera

	# Ya no modificamos is_near_ladder ni current_ladder
	# PlataformaOneway se encargará de verificar el ladder_cooldown

	# Cambiar estado a AIR
	player.current_move_state = player.MoveState.AIR

	# Restaurar rotación del armature
	if player.has_method("_reset_armature_rotation"):
		player._reset_armature_rotation()

	# Pequeño impulso
	if "velocity" in player:
		player.velocity.x = 0.5


func _esta_en_escalera(player) -> bool:
	"""Verifica si el jugador está escalando"""
	if "current_move_state" in player:
		return player.current_move_state == player.MoveState.CLIMBING
	return false
