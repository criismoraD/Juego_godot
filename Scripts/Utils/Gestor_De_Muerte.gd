class_name GestorDeMuerte
extends Object

static func iniciar_disolucion(
	node: Node3D,
	dissolve_shader: Shader,
	color_borde_disolucion: Color,
	intensidad_emision: float,
	duracion_disolucion: float,
	particulas_detener_emision: float,
	mesh_instances: Array,
	dissolve_materials: Array,
	particulas_config: Dictionary = {}
) -> Dictionary:

	if not is_instance_valid(node) or not node.is_inside_tree():
		return {}

	for mesh in mesh_instances:
		if not is_instance_valid(mesh):
			continue
		if mesh is MeshInstance3D:
			var material = ShaderMaterial.new()
			material.shader = dissolve_shader
			material.set_shader_parameter("dissolve_amount", 0.0)
			material.set_shader_parameter("glow_color", color_borde_disolucion)
			material.set_shader_parameter("glow_intensity", intensidad_emision)
			material.set_shader_parameter("edge_thickness", 0.05)
			material.set_shader_parameter("noise_scale", 20.0)

			var original_mat = mesh.get_surface_override_material(0)
			if original_mat == null and mesh.mesh:
				original_mat = mesh.mesh.surface_get_material(0)
			if original_mat and original_mat is StandardMaterial3D:
				var tex = original_mat.albedo_texture
				if tex:
					material.set_shader_parameter("albedo_texture", tex)
				var col = original_mat.albedo_color
				material.set_shader_parameter("albedo_tint", Vector3(col.r, col.g, col.b))

			mesh.material_override = material
			dissolve_materials.append({"mesh": mesh, "material": material})

	var dissolve_particles = _crear_particulas_disolucion(
		node, color_borde_disolucion, intensidad_emision, particulas_config
	)

	var timer = node.get_tree().create_timer(duracion_disolucion * particulas_detener_emision)
	timer.timeout.connect(
		func():
			if is_instance_valid(dissolve_particles) and is_instance_valid(node):
				dissolve_particles.emitting = false
	)

	var tween = node.create_tween()
	tween.tween_method(
		func(value: float):
			for item in dissolve_materials:
				if is_instance_valid(item["mesh"]):
					item["material"].set_shader_parameter("dissolve_amount", value)
		, 0.0, 1.0, duracion_disolucion
	)

	return {"tween": tween, "particles": dissolve_particles}


static func finalizar_disolucion(
	node: Node3D,
	dissolve_materials: Array,
	particles_node: GPUParticles3D,
	particulas_vida: float
):
	if not is_instance_valid(node):
		return

	for item in dissolve_materials:
		if is_instance_valid(item["mesh"]):
			item["mesh"].material_override = null
			if item["mesh"].mesh:
				for si in range(item["mesh"].mesh.get_surface_count()):
					item["mesh"].set_surface_override_material(si, null)
			item["mesh"].visible = false

	if is_instance_valid(particles_node) and particles_node.is_inside_tree():
		var global_pos = particles_node.global_position
		if particles_node.get_parent():
			particles_node.get_parent().remove_child(particles_node)
		node.get_tree().root.add_child(particles_node)
		particles_node.global_position = global_pos
		particles_node.emitting = false

		node.get_tree().create_timer(particulas_vida + 0.5).timeout.connect(
			func():
				if is_instance_valid(particles_node) and particles_node.is_inside_tree():
					particles_node.queue_free()
		)

	node.queue_free()

static func _crear_particulas_disolucion(
	node: Node3D,
	color: Color,
	emision: float,
	config: Dictionary
) -> GPUParticles3D:

	var particulas_cantidad = config.get("cantidad", 20)
	var particulas_vida = config.get("vida", 1.5)
	var particulas_caja = config.get("caja", Vector3(0.5, 0.5, 0.5))
	var particulas_dispersion = config.get("dispersion", 45.0)
	var particulas_vel_min = config.get("vel_min", 0.5)
	var particulas_vel_max = config.get("vel_max", 1.5)
	var particulas_gravedad = config.get("gravedad", Vector3(0, 1, 0))
	var particulas_esc_min = config.get("esc_min", 0.5)
	var particulas_esc_max = config.get("esc_max", 1.5)
	var particulas_posicion = config.get("posicion", Vector3(0, 1, 0))

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
	process_mat.initial_velocity_min = particulas_vel_min
	process_mat.initial_velocity_max = particulas_vel_max
	process_mat.gravity = particulas_gravedad
	process_mat.scale_min = particulas_esc_min * 0.5
	process_mat.scale_max = particulas_esc_max * 0.5

	var gradient = Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 0.2))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex = CurveTexture.new()
	scale_tex.curve = scale_curve
	process_mat.scale_curve = scale_tex

	particles.process_material = process_mat

	var sphere = SphereMesh.new()
	sphere.radius = 0.025
	sphere.height = 0.05

	var part_mat = StandardMaterial3D.new()
	part_mat.albedo_color = color
	part_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	part_mat.emission_enabled = true
	part_mat.emission = color
	part_mat.emission_energy_multiplier = emision * 0.5
	part_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = part_mat

	particles.draw_pass_1 = sphere

	node.add_child(particles)

	if node.has_method("_get_hips_global_position"):
		var bone_pos = node.call("_get_hips_global_position")
		if bone_pos != Vector3.ZERO:
			particles.global_position = bone_pos
		else:
			particles.position = particulas_posicion
	else:
		particles.position = particulas_posicion

	particles.emitting = true
	return particles
