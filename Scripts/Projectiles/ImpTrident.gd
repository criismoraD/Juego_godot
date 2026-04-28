extends Area3D
class_name ImpTridentProjectile
const CameraUtilsRef = preload("res://Scripts/Utils/CameraUtils.gd")

## Tridente del Imp: Proyectil parabólico con modelo 3D.
## Color rojo incandescente, se clava en superficies.

# === CONFIGURACIÓN ===
@export_category("Movimiento")
@export var velocidad: float = 8.0  ## Velocidad inicial
@export var gravedad: float = 1.2  ## Gravedad aplicada (parábola)
@export var tiempo_vida: float = 10.0
@export var tiempo_pegada: float = 5.0

@export_category("Visual")
@export var color_proyectil: Color = Color(1.0, 0.15, 0.05)  ## Rojo incandescente

# === ESTADO ===
var direction: Vector3 = Vector3.LEFT
var is_stuck: bool = false
var _destroying: bool = false

# === MATERIAL ===
var projectile_material: StandardMaterial3D

# === PARTÍCULAS ===
var trail_particles: GPUParticles3D

var _cached_mesh_instances: Array[Node] = []


func _ready():
	add_to_group("enemy_projectiles")

	_cached_mesh_instances = find_children("*", "MeshInstance3D", true, false)

	# Material rojo incandescente
	_create_material()
	_apply_material()

	# Crear trail de partículas
	_create_trail_particles()

	# Delay breve para no chocar con el Imp que lanza
	monitoring = false
	get_tree().create_timer(0.1).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				monitoring = true
	)

	# Timer de destrucción
	get_tree().create_timer(tiempo_vida).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_check_destroy()
	)

	# Conectar colisiones
	body_entered.connect(_on_body_entered)


func _physics_process(delta):
	if is_stuck:
		return

	# Trayectoria parabólica
	direction.y -= gravedad * delta
	global_position += direction * velocidad * delta

	# Forzar Z = 0 (2.5D)
	global_position.z = 0

	# Rotar para seguir la dirección de movimiento
	if direction.length_squared() > 0.01:
		var angle = atan2(direction.y, direction.x)
		rotation = Vector3(0, 0, angle)

	_check_off_screen()


# ═══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ═══════════════════════════════════════════════════════════════════════════════


func initialize(shoot_direction: Vector3, potencia: float = 1.0):
	direction = Vector3(shoot_direction.x, shoot_direction.y, 0).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector3.LEFT
	velocidad *= potencia
	var angle = atan2(direction.y, direction.x)
	rotation = Vector3(0, 0, angle)


# ═══════════════════════════════════════════════════════════════════════════════
# MATERIAL / VISUAL
# ═══════════════════════════════════════════════════════════════════════════════


func _create_material():
	projectile_material = StandardMaterial3D.new()
	projectile_material.albedo_color = color_proyectil
	projectile_material.emission_enabled = true
	projectile_material.emission = color_proyectil
	projectile_material.emission_energy_multiplier = 4.0
	projectile_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _apply_material():
	for mesh in _cached_mesh_instances:
		if is_instance_valid(mesh):
			mesh.add_to_group("outline_meshes")
			mesh.material_override = projectile_material


func _create_trail_particles():
	trail_particles = GPUParticles3D.new()
	trail_particles.name = "TrailParticles"
	trail_particles.amount = 20
	trail_particles.lifetime = 0.4
	trail_particles.one_shot = false
	trail_particles.explosiveness = 0.0
	trail_particles.randomness = 0.2
	trail_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process_mat.direction = Vector3(0, 0, 0)
	process_mat.spread = 30.0
	process_mat.initial_velocity_min = 0.1
	process_mat.initial_velocity_max = 0.3
	process_mat.gravity = Vector3(0, -0.5, 0)
	process_mat.scale_min = 0.00375
	process_mat.scale_max = 0.0075

	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.4, 0.1, 1.0))
	gradient.set_color(1, Color(1.0, 0.1, 0.0, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	trail_particles.process_material = process_mat

	var sphere = SphereMesh.new()
	sphere.radius = 0.025
	sphere.height = 0.05
	var part_mat = StandardMaterial3D.new()
	part_mat.albedo_color = Color(1.0, 0.3, 0.05)
	part_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	part_mat.emission_enabled = true
	part_mat.emission = Color(1.0, 0.3, 0.05)
	part_mat.emission_energy_multiplier = 3.0
	part_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	part_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = part_mat

	trail_particles.draw_pass_1 = sphere
	add_child(trail_particles)


# ═══════════════════════════════════════════════════════════════════════════════
# COLISIONES
# ═══════════════════════════════════════════════════════════════════════════════


func _on_body_entered(body):
	if is_stuck:
		return

	# Aliados (NPC) — verificar antes que StaticBody3D
	if body.is_in_group("allies"):
		var target = (
			body.get_parent()
			if body.get_parent() and body.get_parent().has_method("take_damage")
			else body
		)
		if target.has_method("take_damage"):
			target.take_damage(1.0)
		elif target.has_method("recibir_dano"):
			target.recibir_dano(1)
		_safe_destroy()
		return

	# Superficies / escudos / plataformas
	if body is StaticBody3D or body is AnimatableBody3D:
		if body.has_method("recibir_golpe"):
			body.recibir_golpe()
			_stick_to_shield(body)
			return
		_stick_to_surface()
		return

	# Jugador
	if body.is_in_group("player"):
		if body.has_method("recibir_dano"):
			body.recibir_dano(1)
		elif body.has_method("take_damage"):
			body.take_damage(1.0)
		_safe_destroy()


# ═══════════════════════════════════════════════════════════════════════════════
# PEGARSE / DESTRUIR
# ═══════════════════════════════════════════════════════════════════════════════


func _stick_to_surface():
	is_stuck = true
	direction = Vector3.ZERO
	if trail_particles:
		trail_particles.emitting = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	get_tree().create_timer(tiempo_pegada).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_cleanup_materials()
				queue_free()
	)


func _stick_to_shield(shield_body):
	is_stuck = true
	direction = Vector3.ZERO
	if trail_particles:
		trail_particles.emitting = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	if is_instance_valid(shield_body):
		var saved_transform = global_transform
		var old_parent = get_parent()
		if old_parent:
			old_parent.remove_child(self)
		shield_body.add_child(self)
		global_transform = saved_transform  # Preservar escala y posición global

	get_tree().create_timer(tiempo_pegada).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_cleanup_materials()
				queue_free()
	)


func _safe_destroy():
	if _destroying:
		return
	_destroying = true
	if trail_particles:
		trail_particles.emitting = false
	_cleanup_materials()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_physics_process(false)
	get_tree().create_timer(0.3).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				queue_free()
	)


func _cleanup_materials():
	for mesh in _cached_mesh_instances:
		if is_instance_valid(mesh):
			mesh.material_override = null
			if mesh.mesh:
				for si in range(mesh.mesh.get_surface_count()):
					mesh.set_surface_override_material(si, null)
			mesh.visible = false


func _check_destroy():
	if not is_stuck:
		_safe_destroy()


func _check_off_screen():
	var camera = CameraUtilsRef.obtener_camara_juego(self)
	if not camera:
		return
	var screen_pos = camera.unproject_position(global_position)
	var viewport_size = get_viewport().get_visible_rect().size
	var margin_x = 400.0
	var margin_top = 2000.0
	var margin_bottom = 300.0

	if screen_pos.x < -margin_x or screen_pos.x > viewport_size.x + margin_x:
		_safe_destroy()
	elif screen_pos.y < -margin_top:
		_safe_destroy()
	elif screen_pos.y > viewport_size.y + margin_bottom:
		_safe_destroy()
	elif global_position.y < -20:
		_safe_destroy()
