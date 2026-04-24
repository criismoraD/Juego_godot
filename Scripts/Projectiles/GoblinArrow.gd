extends Area3D
class_name GoblinArrowProjectile
const CameraUtilsRef = preload("res://Scripts/Utils/CameraUtils.gd")

# === CONFIGURACIÓN (Español) ===
@export_category("Movimiento")
@export var speed: float = 8.0 # Velocidad de la flecha
@export var tiempo_vida: float = 10.0 # Tiempo antes de destruirse
@export var tiempo_pegada: float = 5.0 # Tiempo antes de desaparecer cuando está pegada

@export_category("Visual")
## Color del proyectil (material + partículas). Naranja = Goblin, Púrpura = GoblinGirl
@export var color_proyectil: Color = Color(1.0, 0.5, 0.0)

# === ESTADO ===
var direction: Vector3 = Vector3.LEFT
var is_stuck: bool = false
var _destroying: bool = false

# === MATERIAL ===
var projectile_material: StandardMaterial3D

# === PARTÍCULAS ===
var trail_particles: GPUParticles3D

# === MESH PROCEDURAL ===
var arrow_mesh_instance: MeshInstance3D

func _ready():
	add_to_group("enemy_projectiles")
	
	# Eliminar cualquier modelo GLB que venga de la escena
	_remove_glb_model()
	
	# Crear material incandescente con el color configurado
	_create_material()
	
	# Crear mesh procedural (cilindro + cono = flecha)
	_create_procedural_arrow()
	
	# Crear partículas de trail incandescente
	_create_trail_particles()
	
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
	
	# Movimiento recto (sin gravedad - es una ballesta)
	global_position += direction * speed * delta
	
	# Forzar Z = 0 (2.5D)
	global_position.z = 0
	
	# Rotar para apuntar en la dirección de movimiento
	if direction.length_squared() > 0.01:
		var angle = atan2(direction.y, direction.x)
		rotation = Vector3(0, 0, angle)
	
	# Verificar si está fuera de pantalla
	_check_off_screen()

func _check_off_screen():
	var camera = CameraUtilsRef.obtener_camara_juego(self)
	if not camera:
		return
	
	var screen_pos = camera.unproject_position(global_position)
	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 200.0
	
	if screen_pos.x < -margin or screen_pos.x > viewport_size.x + margin:
		_safe_destroy()
	elif screen_pos.y < -margin or screen_pos.y > viewport_size.y + margin:
		_safe_destroy()
	elif global_position.y < -20:
		_safe_destroy()

func _on_body_entered(body):
	if is_stuck:
		return
	
	# Si es un aliado (NPC), hacer daño (verificar ANTES de StaticBody3D)
	if body.is_in_group("allies"):
		var target = body.get_parent() if body.get_parent() and body.get_parent().has_method("take_damage") else body
		if target.has_method("take_damage"):
			target.take_damage(1.0)
		elif target.has_method("recibir_dano"):
			target.recibir_dano(1)
		AudioManager.play_goblin_laugh()
		_safe_destroy()
		return
	
	# Si es suelo / plataforma, pegarse
	if body is StaticBody3D or body is AnimatableBody3D:
		# Verificar si es un escudo primero
		if body.has_method("recibir_golpe"):
			body.recibir_golpe()
			AudioManager.play_goblin_laugh()
			# Pegar la flecha al escudo en lugar de destruirla
			_stick_to_shield(body)
			return
		_stick_to_surface()
		return
	
	# Si es el jugador, hacer daño
	if body.is_in_group("player"):
		if body.has_method("recibir_dano"):
			body.recibir_dano(1)
		elif body.has_method("take_damage"):
			body.take_damage(1.0)
		AudioManager.play_goblin_laugh()
		_safe_destroy()

func _stick_to_surface():
	is_stuck = true
	direction = Vector3.ZERO
	# Detener partículas de trail
	if trail_particles:
		trail_particles.emitting = false
	# Usar set_deferred para evitar errores durante señales
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	get_tree().create_timer(tiempo_pegada).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_cleanup_materials()
			queue_free()
	)

func _stick_to_shield(shield: Node3D):
	"""Pegar la flecha al escudo visualmente"""
	is_stuck = true
	direction = Vector3.ZERO
	# Detener partículas de trail
	if trail_particles:
		trail_particles.emitting = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Guardar transform global completa (incluye escala) antes de reparentar
	var saved_global_transform = global_transform
	
	# Reparentar al escudo
	call_deferred("_reparent_to_shield", shield, saved_global_transform)
	
	# Destruir después de un tiempo
	get_tree().create_timer(tiempo_pegada).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_cleanup_materials()
			queue_free()
	)

func _reparent_to_shield(shield: Node3D, saved_transform: Transform3D):
	if not is_instance_valid(shield):
		_cleanup_materials()
		queue_free()
		return
	
	var current_parent = get_parent()
	if current_parent:
		current_parent.remove_child(self)
	
	shield.add_child(self)
	global_transform = saved_transform
	
	# Conectar señal de destrucción del escudo
	if shield.has_signal("destruido"):
		shield.destruido.connect(func():
			if is_instance_valid(self) and is_inside_tree():
				_cleanup_materials()
				queue_free()
		)

func _safe_destroy():
	if _destroying:
		return
	_destroying = true
	# Detener trail antes de liberar para evitar "Parameter material is null"
	if trail_particles:
		trail_particles.emitting = false
		if trail_particles.draw_pass_1 and trail_particles.draw_pass_1 is Mesh:
			trail_particles.draw_pass_1.material = null
		trail_particles.draw_pass_1 = null
	# Limpiar materiales de meshes procedurales
	_cleanup_materials()
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_physics_process(false)
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			queue_free()
	)

func _cleanup_materials():
	var meshes = find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		if is_instance_valid(mesh):
			mesh.material_override = null
			if mesh.mesh:
				for si in range(mesh.mesh.get_surface_count()):
					mesh.set_surface_override_material(si, null)
			mesh.visible = false

func _check_destroy():
	if not is_stuck:
		_safe_destroy()

func initialize(shoot_direction: Vector3, power: float = 1.0):
	# Garantizar que el proyectil se mueva en el plano XY (2.5D)
	direction = Vector3(shoot_direction.x, shoot_direction.y, 0).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector3.LEFT
	
	# Calcular velocidad usando la lógica solicitada (lerp de 10.0 a 30.0)
	speed = lerp(10.0, 30.0, clamp(power, 0.0, 1.0))
	
	# Rotación inicial para que el proyectil mire hacia donde viaja
	var angle = atan2(direction.y, direction.x)
	rotation = Vector3(0, 0, angle)

func _remove_glb_model():
	# Eliminar nodo "Model" o cualquier nodo instanciado del GLB
	var model = find_child("Model", false, false)
	if model:
		model.queue_free()
	# También buscar VIROTE_BALLESTA u otros modelos GLB
	for child in get_children():
		if child is Node3D and not (child is CollisionShape3D) and child.name != "TrailVFX":
			if not (child is MeshInstance3D): # No borrar meshes propios
				child.queue_free()

func _create_material():
	projectile_material = StandardMaterial3D.new()
	projectile_material.albedo_color = color_proyectil
	projectile_material.emission_enabled = true
	projectile_material.emission = color_proyectil
	projectile_material.emission_energy_multiplier = 3.0
	projectile_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _create_procedural_arrow():
	# --- Cuerpo: Cilindro ---
	var body = CylinderMesh.new()
	body.top_radius = 0.015
	body.bottom_radius = 0.015
	body.height = 0.25
	body.radial_segments = 6
	body.rings = 1
	
	# --- Punta: Cono ---
	var tip = CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.03
	tip.height = 0.08
	tip.radial_segments = 6
	tip.rings = 1
	
	# Crear nodos separados para posicionarlos
	var body_mesh = MeshInstance3D.new()
	body_mesh.name = "Body"
	body_mesh.mesh = body
	body_mesh.material_override = projectile_material
	body_mesh.add_to_group("outline_meshes")
	# Rotar para que el eje Y (altura) apunte hacia X (dirección de movimiento)
	body_mesh.rotation = Vector3(0, 0, -PI / 2.0)
	
	var tip_mesh = MeshInstance3D.new()
	tip_mesh.name = "Tip"
	tip_mesh.mesh = tip
	tip_mesh.material_override = projectile_material
	tip_mesh.add_to_group("outline_meshes")
	# Rotar y posicionar la punta al frente del cilindro
	tip_mesh.rotation = Vector3(0, 0, -PI / 2.0)
	tip_mesh.position = Vector3(0.165, 0, 0) # Medio cilindro + medio cono
	
	# Contenedor para el mesh completo
	var mesh_container = Node3D.new()
	mesh_container.name = "ArrowModel"
	mesh_container.add_child(body_mesh)
	mesh_container.add_child(tip_mesh)
	
	add_child(mesh_container)

func _create_trail_particles():
	trail_particles = GPUParticles3D.new()
	trail_particles.name = "TrailVFX"
	trail_particles.emitting = true
	trail_particles.one_shot = false
	trail_particles.amount = 15
	trail_particles.lifetime = 0.25
	trail_particles.preprocess = 0.0
	
	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process_mat.direction = Vector3(0, 0, 0)
	process_mat.spread = 10.0
	process_mat.initial_velocity_min = 0.0
	process_mat.initial_velocity_max = 0.2
	process_mat.gravity = Vector3.ZERO
	process_mat.scale_min = 0.02
	process_mat.scale_max = 0.04
	
	# Color del trail = color del proyectil
	var gradient = Gradient.new()
	gradient.set_color(0, Color(color_proyectil.r, color_proyectil.g, color_proyectil.b, 0.8))
	gradient.set_color(1, Color(color_proyectil.r * 0.8, color_proyectil.g * 0.6, color_proyectil.b * 0.5, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex
	
	# Escala decreciente
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 1.0))
	scale_curve.add_point(Vector2(1, 0.0))
	var scale_tex = CurveTexture.new()
	scale_tex.curve = scale_curve
	process_mat.scale_curve = scale_tex
	
	trail_particles.process_material = process_mat
	
	# Mesh de partícula (esfera pequeña)
	var mesh = QuadMesh.new()
	mesh.size = Vector2(1.0, 1.0)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color_proyectil
	mat.emission_enabled = true
	mat.emission = color_proyectil
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	
	trail_particles.draw_pass_1 = mesh
	
	add_child(trail_particles)
