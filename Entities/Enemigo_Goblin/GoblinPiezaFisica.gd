class_name GoblinPiezaFisica
extends Node3D

## Maneja el vuelo parabólico, colisión con el suelo, interacción con flechas y disolución automática con partículas.

const DISSOLVE_SHADER: Shader = preload("res://System/Shaders/dissolve.gdshader")

@export var es_piernas: bool = false
@export var humo_al_aterrizar: bool = false  ## Humo a ambos lados al tocar el suelo (escudo pesado)
var velocity: Vector3 = Vector3.ZERO
var rot_speed_z: float = 0.0
var active: bool = false
var gravity: float = 14.0
var resting: bool = false
var es_escudo_enemigo: bool = true  ## Permite que las flechas del jugador o aliadas se claven
var _dissolve_materials: Array[Dictionary] = []
var _static_body: StaticBody3D = null
var _tiempo_vida: float = 0.0
var _disolviendo: bool = false
var _tiempo_para_disolver: float = 2.5  ## Tiempo de reposo antes de disolverse
var _humo_impacto_hecho: bool = false  ## Un solo estallido de humo al aterrizar


func _ready() -> void:
	if es_piernas:
		_crear_colisionador_flechas()


func iniciar_vuelo(initial_vel: Vector3, initial_rot_z: float) -> void:
	velocity = Vector3(initial_vel.x, initial_vel.y, 0.0)
	rot_speed_z = initial_rot_z
	active = true
	resting = false


func _crear_colisionador_flechas() -> void:
	if _static_body and is_instance_valid(_static_body):
		return
	_static_body = StaticBody3D.new()
	_static_body.name = "PiernasHitbox"
	_static_body.collision_layer = 2  ## Capa 2 (Escudos/Defensas) - Exclusivo para interactuar con flechas
	_static_body.collision_mask = 0
	_static_body.set("es_escudo_enemigo", true)

	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45, 0.55, 0.4)
	col_shape.shape = box
	col_shape.position = Vector3(0, 0.25, 0)
	_static_body.add_child(col_shape)
	add_child(_static_body)

	# Excluir explícitamente a todos los enemigos presentes para que jamás les corte el paso
	for enemigo in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemigo) and enemigo is CollisionObject3D:
			_static_body.add_collision_exception_with(enemigo)
			if enemigo is PhysicsBody3D:
				enemigo.add_collision_exception_with(_static_body)



func _physics_process(delta: float) -> void:
	_tiempo_vida += delta

	# Iniciar disolución automática a los 2.5 segundos
	if _tiempo_vida >= _tiempo_para_disolver and not _disolviendo:
		_disolviendo = true
		iniciar_disolucion(1.2)

	if not active or resting or es_piernas:
		return

	velocity.y -= gravity * delta
	velocity.z = 0.0  # Mantener siempre en el plano 2.5D

	var move_step := velocity * delta
	var target_pos := global_position + move_step

	# Raycast contra el suelo (Capa 1 y Capa 512 de límites/escenario)
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.2, 0), target_pos)
	query.collision_mask = 1 | 512
	if _static_body and is_instance_valid(_static_body):
		query.exclude = [_static_body.get_rid()]

	var hit := space_state.intersect_ray(query)
	if hit and hit.has("position"):
		global_position.y = hit.position.y
		global_position.x = hit.position.x
		# Humo a ambos lados en el primer impacto contra el suelo (escudo pesado)
		if humo_al_aterrizar and not _humo_impacto_hecho:
			_humo_impacto_hecho = true
			VFXFactory.spawn_shield_break_smoke(self, global_position)
		var normal: Vector3 = hit.normal
		if normal.dot(velocity) < 0:
			velocity = velocity.bounce(normal) * 0.3
			rot_speed_z *= 0.4

		if velocity.length() < 0.3:
			velocity = Vector3.ZERO
			rot_speed_z = 0.0
			resting = true
			active = false
	else:
		global_position = target_pos

	if not resting:
		rotate_z(rot_speed_z * delta)


func recibir_golpe(_amount: float = 1.0) -> void:
	# Receptor para que las flechas del jugador o aliadas se claven
	pass


func iniciar_disolucion(duracion: float = 1.2, color_disolucion: Color = Color(0.2, 0.85, 0.2)) -> void:
	_dissolve_materials.clear()
	var meshes := find_children("*", "MeshInstance3D", true, false)

	for m in meshes:
		var mesh_inst := m as MeshInstance3D
		if not is_instance_valid(mesh_inst):
			continue

		var mat := ShaderMaterial.new()
		mat.shader = DISSOLVE_SHADER
		mat.set_shader_parameter("dissolve_amount", 0.0)
		mat.set_shader_parameter("glow_color", color_disolucion)
		mat.set_shader_parameter("glow_intensity", 6.0)
		mat.set_shader_parameter("edge_thickness", 0.05)
		mat.set_shader_parameter("noise_scale", 20.0)

		var orig_mat: Material = mesh_inst.get_surface_override_material(0)
		if orig_mat == null and mesh_inst.mesh:
			orig_mat = mesh_inst.mesh.surface_get_material(0)
		if orig_mat is StandardMaterial3D:
			var std_mat := orig_mat as StandardMaterial3D
			if std_mat.albedo_texture:
				mat.set_shader_parameter("albedo_texture", std_mat.albedo_texture)
			var col := std_mat.albedo_color
			mat.set_shader_parameter("albedo_tint", Vector3(col.r, col.g, col.b))

		mesh_inst.material_override = mat
		_dissolve_materials.append({"mesh": mesh_inst, "mat": mat})

	# Crear partículas de disolución individuales para esta pieza
	_crear_particulas_disolucion(color_disolucion, duracion)

	# Animar disolución de 0 a 1 y desvanecer escala
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(val: float):
		for item in _dissolve_materials:
			if is_instance_valid(item["mesh"]) and is_instance_valid(item["mat"]):
				item["mat"].set_shader_parameter("dissolve_amount", val)
	, 0.0, 1.0, duracion)

	tween.tween_property(self, "scale", Vector3.ZERO, duracion * 0.6) \
		.set_delay(duracion * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.finished.connect(func():
		queue_free()
	)


func _crear_particulas_disolucion(color_part: Color, duracion: float) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 24
	particles.lifetime = 0.6
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.5

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.08, 0.08, 0.08)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 30.0
	pmat.initial_velocity_min = 0.3
	pmat.initial_velocity_max = 0.8
	pmat.gravity = Vector3(0, 0.5, 0)
	# Tamaños más pequeños y variados
	pmat.scale_min = 0.15
	pmat.scale_max = 0.65

	var grad := Gradient.new()
	grad.set_color(0, color_part)
	grad.set_color(1, Color(color_part.r, color_part.g, color_part.b, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pmat.color_ramp = grad_tex

	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.15))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	pmat.scale_curve = curve_tex

	particles.process_material = pmat

	# Esfera reducida a más de la mitad para partículas diminutas
	var sphere := SphereMesh.new()
	sphere.radius = 0.012
	sphere.height = 0.024

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color_part
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.emission_enabled = true
	mat.emission = color_part
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = mat
	particles.draw_pass_1 = sphere

	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	root.add_child(particles)
	particles.global_position = global_position

	get_tree().create_timer(duracion).timeout.connect(func():
		if is_instance_valid(particles):
			particles.emitting = false
			get_tree().create_timer(0.7).timeout.connect(func():
				if is_instance_valid(particles):
					particles.queue_free()
			)
	)
