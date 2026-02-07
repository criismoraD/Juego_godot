extends Node3D

# === Parámetros asignados desde Escudo.gd (NO exportar aquí) ===
# Física
var fuerza_explosion: float = 1.5
var fuerza_horizontal: float = 0.5
var fuerza_vertical: float = 1.0
var torque_min: float = -4.0
var torque_max: float = 4.0

# Tiempos
var tiempo_congelar: float = 2.0
var tiempo_antes_disolver: float = 1.5

# Disolución
var duracion_disolucion: float = 1.0
var color_borde_disolucion: Color = Color(1.0, 0.6, 0.2)
var intensidad_emision: float = 3.0

# Partículas
var particulas_cantidad: int = 60
var particulas_vida: float = 1.5
var particulas_caja: Vector3 = Vector3(0.3, 0.3, 0.1)
var particulas_dispersion: float = 25.0
var particulas_velocidad_min: float = 0.1
var particulas_velocidad_max: float = 0.8
var particulas_gravedad: Vector3 = Vector3(0, 0.1, 0)
var particulas_escala_min: float = 0.01
var particulas_escala_max: float = 0.03

# Color de daño heredado del escudo intacto
var color_dano_heredado: Color = Color.WHITE
var progreso_dano: float = 0.0
var intensidad_tinte_heredado: float = 0.5

# Material del escudo (fallback)
var material_escudo = preload("res://Assets/Materials/MAT_shield.tres")
var dissolve_shader = preload("res://Assets/Shaders/dissolve.gdshader")

# Estado interno
var _rigid_bodies: Array[RigidBody3D] = []
var _meshes: Array[MeshInstance3D] = []
var _dissolve_materials: Array = []
var _dissolve_particles: GPUParticles3D = null

func _ready():
	call_deferred("_iniciar_conversion")

func _iniciar_conversion():
	if not is_inside_tree():
		return
	
	_procesar_hijos(self)
	
	# Fase 1: Congelar piezas después de que caigan
	await get_tree().create_timer(tiempo_congelar).timeout
	if not is_instance_valid(self):
		return
	for rb in _rigid_bodies:
		if is_instance_valid(rb):
			rb.freeze = true
	
	# Fase 2: Esperar antes de disolver
	await get_tree().create_timer(tiempo_antes_disolver).timeout
	if not is_instance_valid(self):
		return
	
	# Fase 3: Efecto de disolución (igual que los enemigos)
	_start_dissolve_effect()

func _procesar_hijos(nodo: Node):
	var hijos = nodo.get_children()
	for hijo in hijos:
		if hijo is MeshInstance3D:
			_convertir_a_rigidbody(hijo)
		elif hijo.get_child_count() > 0:
			_procesar_hijos(hijo)

func _convertir_a_rigidbody(mesh_instance: MeshInstance3D):
	if not mesh_instance.mesh:
		return
	
	var rb = RigidBody3D.new()
	rb.name = mesh_instance.name + "_RB"
	
	# Colisión: nadie me detecta, yo detecto TODO (máxima compatibilidad)
	rb.collision_layer = 0
	rb.collision_mask = 0xFFFFFFFF  # Detectar TODAS las capas
	
	# Prevenir tunneling
	rb.continuous_cd = true
	
	# Reducir gravedad y velocidad para que no atraviesen plataformas delgadas
	rb.gravity_scale = 0.6
	rb.linear_damp = 1.0
	
	# Guardar la transform global del mesh ANTES de modificar la jerarquía
	var mesh_global_pos = mesh_instance.global_position
	var mesh_global_rot = mesh_instance.global_rotation
	var mesh_global_scale = mesh_instance.global_transform.basis.get_scale()
	
	# Collision shape: usar la geometría real del mesh (ConvexPolygonShape3D)
	# para que cada pieza colisione con su forma real, no como un cubo genérico.
	var col_shape = CollisionShape3D.new()
	var convex_shape = mesh_instance.mesh.create_convex_shape(true, true)
	if convex_shape and convex_shape is ConvexPolygonShape3D and convex_shape.points.size() >= 4:
		# Escalar los puntos del convex hull para que coincidan con la escala visual del mesh
		var scaled_points = PackedVector3Array()
		for point in convex_shape.points:
			scaled_points.append(point * mesh_global_scale)
		convex_shape.points = scaled_points
		col_shape.shape = convex_shape
	else:
		# Fallback: box pequeño si no se puede generar convex hull
		var box = BoxShape3D.new()
		box.size = Vector3(0.08, 0.08, 0.04) * mesh_global_scale
		col_shape.shape = box
	rb.add_child(col_shape)
	
	# IMPORTANTE: Añadir el RB al ROOT de la escena (NO a un nodo padre escalado).
	# Godot no maneja bien los RigidBody3D bajo transforms escalados:
	# las collision shapes no escalan correctamente en el motor de física.
	var scene_root = get_tree().current_scene
	scene_root.add_child(rb)
	# Empezar ligeramente por ENCIMA de la posición original para evitar overlap inicial
	rb.global_position = mesh_global_pos + Vector3.UP * 0.15
	rb.global_rotation = mesh_global_rot
	# RB.scale queda en (1,1,1) — correcto para el motor de física
	
	# Reparentar el mesh al RB, centrándolo pero preservando su escala visual
	mesh_instance.reparent(rb)
	mesh_instance.position = Vector3.ZERO
	mesh_instance.rotation = Vector3.ZERO
	mesh_instance.scale = mesh_global_scale
	
	# Material: aplicar tinte de daño heredado (SIN transparencia)
	var mat = StandardMaterial3D.new()
	if material_escudo is StandardMaterial3D:
		mat.albedo_texture = material_escudo.albedo_texture
		mat.albedo_color = material_escudo.albedo_color
	else:
		mat.albedo_color = Color.WHITE
	
	if progreso_dano > 0.0:
		mat.albedo_color = mat.albedo_color.lerp(color_dano_heredado, progreso_dano * intensidad_tinte_heredado)
	
	mesh_instance.material_override = mat
	
	# Física: explosión con impulso vertical y dispersión horizontal
	var dispersion = Vector3(
		randf_range(-fuerza_horizontal, fuerza_horizontal),
		randf_range(0.3, 0.7),
		randf_range(-fuerza_horizontal * 0.6, fuerza_horizontal * 0.6)
	)
	rb.apply_impulse(dispersion.normalized() * fuerza_explosion + Vector3.UP * fuerza_vertical, Vector3.ZERO)
	
	rb.apply_torque_impulse(Vector3(
		randf_range(torque_min, torque_max),
		randf_range(torque_min, torque_max),
		randf_range(torque_min, torque_max)
	))
	
	_rigid_bodies.append(rb)
	_meshes.append(mesh_instance)

# === EFECTO DE DISOLUCIÓN (mismo sistema que los enemigos) ===

func _start_dissolve_effect():
	# Aplicar dissolve shader a cada pieza
	for mesh in _meshes:
		if not is_instance_valid(mesh):
			continue
		
		var shader_mat = ShaderMaterial.new()
		shader_mat.shader = dissolve_shader
		shader_mat.set_shader_parameter("dissolve_amount", 0.0)
		shader_mat.set_shader_parameter("glow_color", color_borde_disolucion)
		shader_mat.set_shader_parameter("glow_intensity", intensidad_emision)
		shader_mat.set_shader_parameter("edge_thickness", 0.05)
		shader_mat.set_shader_parameter("noise_scale", 20.0)
		
		# Copiar la textura y tinte del material actual
		var current_mat = mesh.material_override
		if current_mat is StandardMaterial3D:
			if current_mat.albedo_texture:
				shader_mat.set_shader_parameter("albedo_texture", current_mat.albedo_texture)
			var col = current_mat.albedo_color
			shader_mat.set_shader_parameter("albedo_tint", Vector3(col.r, col.g, col.b))
		
		mesh.material_override = shader_mat
		_dissolve_materials.append({"mesh": mesh, "material": shader_mat})
	
	# Crear partículas de disolución
	_create_dissolve_particles()
	
	# Detener emisión de partículas al 70% de la disolución
	get_tree().create_timer(duracion_disolucion * 0.7).timeout.connect(func():
		if _dissolve_particles and is_instance_valid(_dissolve_particles) and is_instance_valid(self):
			_dissolve_particles.emitting = false
	)
	
	# Animar la disolución de 0 a 1
	var tween = create_tween()
	tween.tween_method(_update_dissolve, 0.0, 1.0, duracion_disolucion)
	tween.tween_callback(_finish_dissolve)

func _update_dissolve(value: float):
	for item in _dissolve_materials:
		if is_instance_valid(item["mesh"]):
			item["material"].set_shader_parameter("dissolve_amount", value)

func _finish_dissolve():
	# Mover partículas al root para que no se destruyan con nosotros
	if _dissolve_particles and is_instance_valid(_dissolve_particles):
		var global_pos = _dissolve_particles.global_position
		remove_child(_dissolve_particles)
		get_tree().root.add_child(_dissolve_particles)
		_dissolve_particles.global_position = global_pos
		_dissolve_particles.emitting = false
		var particles_ref = _dissolve_particles
		get_tree().create_timer(particulas_vida + 0.5).timeout.connect(func():
			if is_instance_valid(particles_ref) and particles_ref.is_inside_tree():
				particles_ref.queue_free()
		)
	
	# Eliminar los RigidBody3D de los trozos (están en el scene root, no son hijos nuestros)
	for rb in _rigid_bodies:
		if is_instance_valid(rb):
			rb.queue_free()
	_rigid_bodies.clear()
	
	queue_free()

func _create_dissolve_particles():
	var particles = GPUParticles3D.new()
	particles.name = "DissolveParticles"
	particles.amount = particulas_cantidad
	particles.lifetime = particulas_vida
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.3
	
	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = particulas_caja
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = particulas_dispersion
	process_mat.initial_velocity_min = particulas_velocidad_min
	process_mat.initial_velocity_max = particulas_velocidad_max
	process_mat.gravity = particulas_gravedad
	process_mat.scale_min = particulas_escala_min
	process_mat.scale_max = particulas_escala_max
	
	# Gradiente de color: del color de borde a transparente
	var gradient = Gradient.new()
	gradient.set_color(0, color_borde_disolucion)
	gradient.set_color(1, Color(color_borde_disolucion.r, color_borde_disolucion.g, color_borde_disolucion.b, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex
	
	# Curva de escala
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 0.2))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex = CurveTexture.new()
	scale_tex.curve = scale_curve
	process_mat.scale_curve = scale_tex
	
	particles.process_material = process_mat
	
	# Mesh de partícula (esfera pequeña)
	var sphere = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	
	var part_mat = StandardMaterial3D.new()
	part_mat.albedo_color = color_borde_disolucion
	part_mat.emission_enabled = true
	part_mat.emission = color_borde_disolucion
	part_mat.emission_energy_multiplier = intensidad_emision * 0.5
	part_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = part_mat
	
	particles.draw_pass_1 = sphere
	particles.position = Vector3(0, 0.3, 0)
	
	add_child(particles)
	particles.emitting = true
	_dissolve_particles = particles
