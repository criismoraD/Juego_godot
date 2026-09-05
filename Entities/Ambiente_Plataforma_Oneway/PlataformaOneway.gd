class_name PlataformaOneway
extends AnimatableBody3D
# Plataforma que se puede atravesar desde abajo pero es sólida desde arriba
# También permite pasar si el jugador está en una escalera y presiona abajo
# Las flechas pueden pegarse desde cualquier dirección
# Referencia al collision shape
var collision_shape: CollisionShape3D
var player_ref: CharacterBody3D = null
var arrow_detector: Area3D = null


func _ready():
	# Layer 6 = debris/trozos - siempre activa para que los trozos colisionen
	set_collision_layer_value(6, true)
	# Layer 7 = superficie permanente para proyectiles (nunca se desactiva)
	set_collision_layer_value(7, true)

	# Buscar el collision shape principal
	for child in get_children():
		if child is CollisionShape3D:
			collision_shape = child
			break

	# Crear un StaticBody3D hijo con un collider MÁS GRUESO solo en layer 6.
	# Esto asegura que los trozos de escudo (RigidBody3D) siempre colisionen,
	# incluso si el AnimatableBody3D principal tiene el layer 1 desactivado.
	if collision_shape and collision_shape.shape is BoxShape3D:
		var debris_catcher = StaticBody3D.new()
		debris_catcher.name = "DebrisCatcher"
		debris_catcher.collision_layer = 32  # Solo layer 6 (bit 6 = valor 32)
		debris_catcher.collision_mask = 0  # No detecta nada
		add_child(debris_catcher)

		var catcher_col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		# Mismo ancho/profundidad que la plataforma pero MUCHO más grueso en Y
		box.size = Vector3(collision_shape.shape.size.x, 1.0, collision_shape.shape.size.z)
		catcher_col.shape = box
		# Posicionar igual que el shape original pero un poco más abajo para que la
		# superficie superior coincida con el tope de la plataforma
		catcher_col.position = collision_shape.position + Vector3(0, -0.4, 0)
		debris_catcher.add_child(catcher_col)

	# Crear Area3D para detectar si el jugador está dentro (para bloquear movimiento lateral)
	if collision_shape:
		var area = Area3D.new()
		area.name = "InsideDetector"
		add_child(area)

		# Duplicar el shape
		# Duplicar el shape para poder modificarlo sin afectar el original
		var key_shape = collision_shape.shape
		var new_shape = CollisionShape3D.new()
		# IMPORTANTE: Duplicar el recurso Shape para modificarlo independientemente
		if key_shape.has_method("duplicate"):
			new_shape.shape = key_shape.duplicate()
		else:
			new_shape.shape = key_shape  # Fallback

		new_shape.transform = collision_shape.transform

		# Reducir ligeramente el tamano para que solo detecte cuando realmente está DENTRO
		# y no cuando está de pie encima
		if new_shape.shape is BoxShape3D:
			# Reducir altura (Y) al 80% y anchura (X) al 90%
			new_shape.shape.size.y *= 0.8
			new_shape.shape.size.x *= 0.9

		area.add_child(new_shape)

		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

		# Crear Area3D secundaria para detectar flechas (siempre activa)
		_create_arrow_detector()

	# Buscar jugador
	await get_tree().process_frame
	player_ref = get_tree().get_first_node_in_group("player")


func _create_arrow_detector():
	"""Crea un área que siempre detecta flechas, independiente del estado del collision_shape"""
	arrow_detector = Area3D.new()
	arrow_detector.name = "ArrowDetector"
	# Detectar solo flechas (layer 3 = mask 4)
	arrow_detector.collision_layer = 1  # Layer 1 para que las flechas la detecten
	arrow_detector.collision_mask = 4  # Detectar flechas (layer 3)
	add_child(arrow_detector)

	# Duplicar shape pero mantenerlo siempre activo
	var arrow_shape = CollisionShape3D.new()
	arrow_shape.shape = collision_shape.shape.duplicate()
	arrow_shape.transform = collision_shape.transform
	arrow_detector.add_child(arrow_shape)

	# Conectar señal para pegar flechas
	arrow_detector.area_entered.connect(_on_arrow_entered)


func _on_arrow_entered(area: Area3D):
	"""Cuando una flecha entra en contacto con la plataforma"""
	# Verificar si es una flecha del jugador
	if area.is_in_group("player_arrows") or area.has_method("_stick_to_surface"):
		# La flecha se encargará de pegarse sola al detectar el body
		pass


func _on_body_entered(body):
	if body.is_in_group("player") and body.get("is_inside_platform") != null:
		var feet_y: float = body.global_position.y
		var shape_y: float = collision_shape.global_position.y if collision_shape else global_position.y
		if feet_y < shape_y:
			body.is_inside_platform = true


func _on_body_exited(body):
	if body.is_in_group("player") and body.get("is_inside_platform") != null:
		body.is_inside_platform = false


func _physics_process(_delta):
	if not is_instance_valid(player_ref) or not player_ref.is_in_group("player"):
		player_ref = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player_ref or not collision_shape:
		return

	# Calcular alturas de la plataforma usando coordenadas globales reales
	var player_feet_y: float = player_ref.global_position.y
	var half_height: float = 0.05
	if collision_shape.shape is BoxShape3D:
		half_height = (collision_shape.shape.size.y * collision_shape.global_transform.basis.get_scale().y) / 2.0

	var shape_global_y: float = collision_shape.global_position.y
	var platform_top_y: float = shape_global_y + half_height
	var platform_bottom_y: float = shape_global_y - half_height

	# 1. Obtener estado del jugador
	var current_state = player_ref.get("current_move_state")
	var is_climbing: bool = current_state == Player.MoveState.CLIMBING

	# Si los pies ya alcanzaron el tope, liberar is_inside_platform para permitir movimiento lateral
	if "is_inside_platform" in player_ref and player_ref.is_inside_platform:
		if player_feet_y >= platform_top_y - 0.02 or not is_climbing:
			player_ref.is_inside_platform = false

	# 2. Atravesar hacia arriba:
	# Permitir pasar si los pies están debajo del tope de la plataforma mientras escala o salta hacia arriba,
	# o si está por debajo de la plataforma.
	var player_vel_y: float = player_ref.velocity.y if "velocity" in player_ref else 0.0
	var traversing_up: bool = (
		(is_climbing and player_feet_y < platform_top_y - 0.02) or
		(player_vel_y > 0.01 and player_feet_y < platform_top_y) or
		(player_feet_y < platform_bottom_y - 0.05)
	)

	if traversing_up:
		set_collision_layer_value(1, false)
		return

	# 3. Verificar si el jugador está CERCA del tope de ESTA plataforma específica
	# (dentro de 0.5 unidades del tope)
	var near_this_platform_top: bool = (
		player_feet_y >= platform_top_y - 0.2 and player_feet_y <= platform_top_y + 0.5
	)

	var is_near_ladder: bool = bool(player_ref.get("is_near_ladder"))
	var pressing_down: bool = Input.is_action_pressed("ui_down") or Input.is_action_pressed("move_back")

	var cooldown_ok: bool = true
	if player_ref.get("ladder_cooldown") != null:
		cooldown_ok = player_ref.ladder_cooldown <= 0

	# Comprobar si la escalera activa realmente desciende a través de esta plataforma
	# (el centro de la escalera debe estar por debajo del tope de esta plataforma)
	var ladder_goes_down: bool = false
	var cur_ladder = player_ref.get("current_ladder")
	if cur_ladder and is_instance_valid(cur_ladder):
		var ladder_col = cur_ladder.get_node_or_null("ESCALERA")
		var ladder_center_y: float = ladder_col.global_position.y if ladder_col else cur_ladder.global_position.y
		ladder_goes_down = ladder_center_y < platform_top_y

	# 4. Solo permitir atravesar hacia abajo si:
	#    - El jugador está CERCA del tope de ESTA plataforma
	#    - Y está cerca de una escalera que desciende a través de esta plataforma
	#    - Y presiona abajo
	#    - Y NO tiene cooldown de escalera (para evitar loops con barreras)
	if near_this_platform_top and is_near_ladder and ladder_goes_down and pressing_down and cooldown_ok:
		set_collision_layer_value(1, false)
	else:
		# Mantener sólida para cualquier otra situación
		set_collision_layer_value(1, true)
