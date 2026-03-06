# Plataforma que se puede atravesar desde abajo pero es sólida desde arriba
# También permite pasar si el jugador está en una escalera y presiona abajo
# Las flechas pueden pegarse desde cualquier dirección
extends AnimatableBody3D
class_name PlataformaOneway

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
		debris_catcher.collision_mask = 0    # No detecta nada
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
			new_shape.shape = key_shape # Fallback
			
		new_shape.transform = collision_shape.transform
		
		# Reducir ligeramente el tamaño para que solo detecte cuando realmente está DENTRO
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
	arrow_detector.collision_layer = 1 # Layer 1 para que las flechas la detecten
	arrow_detector.collision_mask = 4 # Detectar flechas (layer 3)
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
		body.is_inside_platform = true
		
		# Si el jugador está escalando, centrarlo suavemente en la escalera (prioridad) o plataforma
		if body.get("current_move_state") == 3: # MoveState.CLIMBING
			var tween = create_tween()
			var target_x = global_position.x
			
			# Usar la posición X de la escalera actual si existe, para mantener la alineación
			var ladder = body.get("current_ladder")
			if ladder:
				target_x = ladder.global_position.x
			elif collision_shape:
				target_x = collision_shape.global_position.x
				
			tween.tween_property(body, "global_position:x", target_x, 0.2)

func _on_body_exited(body):
	if body.is_in_group("player") and body.get("is_inside_platform") != null:
		body.is_inside_platform = false

func _physics_process(_delta):
	if not player_ref or not collision_shape:
		return
	
	# Calcular alturas de la plataforma
	var player_feet_y = player_ref.global_position.y
	var half_height = 0.05
	if collision_shape.shape is BoxShape3D:
		half_height = collision_shape.shape.size.y / 2.0
	
	var platform_top_y = global_position.y + collision_shape.position.y + half_height
	var platform_bottom_y = global_position.y + collision_shape.position.y - half_height
	
	# 1. Si el jugador está DEBAJO de esta plataforma - dejarlo pasar (subir)
	if player_feet_y < platform_bottom_y:
		set_collision_layer_value(1, false)
		return
	
	# 2. Verificar si el jugador está CERCA del tope de ESTA plataforma específica
	# (dentro de 0.5 unidades del tope)
	var near_this_platform_top = player_feet_y >= platform_top_y - 0.2 and player_feet_y <= platform_top_y + 0.5
	
	# 3. Obtener estado del jugador
	var current_state = player_ref.get("current_move_state")
	var is_climbing = current_state == 3 # MoveState.CLIMBING
	
	# FIX: Si estamos escalando, ignorar colisión de plataforma para evitar teletransportes
	if is_climbing:
		set_collision_layer_value(1, false)
		return
	var is_near_ladder = player_ref.get("is_near_ladder")
	var pressing_down = Input.is_action_pressed("ui_down") or Input.is_action_pressed("move_back")
	
	# 4. Solo permitir atravesar si:
	#    - El jugador está CERCA del tope de ESTA plataforma
	#    - Y está escalando O cerca de escalera
	#    - Y presiona abajo
	#    - Y NO tiene cooldown de escalera (para evitar loops con barreras)
	var cooldown_ok = true
	if player_ref.get("ladder_cooldown") != null:
		cooldown_ok = player_ref.ladder_cooldown <= 0
		
	if near_this_platform_top and (is_climbing or is_near_ladder) and pressing_down and cooldown_ok:
		set_collision_layer_value(1, false)
	else:
		# Mantener sólida para cualquier otra situación
		set_collision_layer_value(1, true)
