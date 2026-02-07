extends Area3D
class_name GoblinGirlArrowProjectile

# === CONFIGURACIÓN (Español) ===
@export_category("Movimiento")
@export var velocidad: float = 8.0 # Velocidad inicial del proyectil
@export var escala_gravedad: float = 1.0 # Multiplicador de gravedad (proyectil parabólico)
@export var tiempo_vida: float = 10.0 # Tiempo antes de destruirse
@export var tiempo_pegada: float = 5.0 # Tiempo antes de desaparecer cuando está pegada

# === ESTADO ===
var velocity: Vector3 = Vector3.ZERO
var is_stuck: bool = false
var world_gravity: float = 0.0

func _ready():
	add_to_group("enemy_projectiles")
	world_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	
	# Desactivar brevemente para no chocar con el goblin que dispara
	monitoring = false
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			monitoring = true
	)
	
	# Timer de destrucción
	get_tree().create_timer(tiempo_vida).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_check_destroy()
	)
	
	# Conectar colisiones
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	if is_stuck:
		return
	
	# FÍSICA PARABÓLICA: Aplicar gravedad
	velocity.y -= world_gravity * escala_gravedad * delta
	
	# Forzar Z = 0 (2.5D)
	velocity.z = 0
	
	# Mover
	global_position += velocity * delta
	
	# Rotar para apuntar en la dirección de movimiento
	if velocity.length_squared() > 0.01:
		var angle = atan2(velocity.y, velocity.x)
		rotation = Vector3(0, 0, angle)
	
	# Verificar si está fuera de pantalla
	_check_off_screen()

func _check_off_screen():
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	var screen_pos = camera.unproject_position(global_position)
	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 200.0
	
	if screen_pos.x < -margin or screen_pos.x > viewport_size.x + margin:
		queue_free()
	elif screen_pos.y < -margin or screen_pos.y > viewport_size.y + margin:
		queue_free()
	elif global_position.y < -20:
		queue_free()

func _on_body_entered(body):
	if is_stuck:
		return
	
	# Ignorar al shooter (GoblinGirl que disparó)
	if has_meta("shooter"):
		var shooter = get_meta("shooter")
		if is_instance_valid(shooter) and body == shooter:
			return
	
	# Ignorar otros enemigos
	if body.is_in_group("enemies"):
		return
	
	# Si es suelo sin recibir_golpe, pegarse
	if body is StaticBody3D:
		# Verificar si es un escudo primero
		if body.has_method("recibir_golpe"):
			body.recibir_golpe()
			_stick_to_shield(body)
			return
		_stick_to_surface()
		return
	
	# AnimatableBody3D (plataformas)
	if body is AnimatableBody3D:
		_stick_to_surface()
		return
	
	# Si es el jugador, hacer daño
	if body.is_in_group("player"):
		if body.has_method("recibir_dano"):
			body.recibir_dano(1)
		elif body.has_method("take_damage"):
			body.take_damage(1.0)
		queue_free()

func _stick_to_surface():
	is_stuck = true
	velocity = Vector3.ZERO
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	get_tree().create_timer(tiempo_pegada).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			queue_free()
	)

func _stick_to_shield(shield: Node3D):
	"""Pegar la flecha al escudo visualmente"""
	is_stuck = true
	velocity = Vector3.ZERO
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Calcular posición relativa al escudo
	var relative_pos = global_position - shield.global_position
	
	# Reparentar al escudo
	call_deferred("_reparent_to_shield", shield, relative_pos)
	
	# Destruir después de un tiempo
	get_tree().create_timer(tiempo_pegada).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			queue_free()
	)

func _reparent_to_shield(shield: Node3D, relative_pos: Vector3):
	if not is_instance_valid(shield):
		queue_free()
		return
	
	var current_parent = get_parent()
	if current_parent:
		current_parent.remove_child(self)
	
	shield.add_child(self)
	position = relative_pos
	
	# Conectar señal de destrucción del escudo
	if shield.has_signal("destruido"):
		shield.destruido.connect(func():
			if is_instance_valid(self) and is_inside_tree():
				queue_free()
		)

func _check_destroy():
	if not is_stuck:
		queue_free()

func initialize(shoot_direction: Vector3, power: float = 1.0):
	"""Inicializar proyectil con dirección y potencia"""
	velocity = shoot_direction.normalized() * velocidad * power
	velocity.z = 0
	
	# Rotación inicial
	if velocity.length_squared() > 0.01:
		var angle = atan2(velocity.y, velocity.x)
		rotation = Vector3(0, 0, angle)
