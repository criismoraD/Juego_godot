class_name GestorDeMuerte
extends RefCounted


## Configuración para el efecto de disolución
class ConfigDisolucion:
	extends RefCounted
	var duracion: float = 1.0
	var color_borde: Color = Color(1.0, 0.2, 0.2)
	var intensidad_emision: float = 3.0
	var shader_disolucion: Shader = preload("res://Assets/Shaders/Dissolve.gdshader")

	# Opciones de partículas
	var Generar_particulas: bool = false
	var particulas_Cantidad: int = 30
	var particulas_Vida: float = 1.0
	var particulas_Caja: Vector3 = Vector3(0.5, 0.5, 0.5)
	var particulas_Dispersion: float = 45.0
	var particulas_Velocidad_Min: float = 1.0
	var particulas_Velocidad_Max: float = 2.0
	var particulas_Gravedad: Vector3 = Vector3(0, 1, 0)
	var particulas_Escala_Min: float = 0.02
	var particulas_Escala_Max: float = 0.05
	var Posicion_particulas: Vector3 = Vector3.ZERO
	var detener_emision_porcentaje: float = 0.7


static func iniciar_efecto_disolucion(
	nodo_raiz: Node, meshes: Array, configuracion: ConfigDisolucion, callback_al_terminar: Callable
) -> void:
	var materiales_guardados: Array = []

	# Configurar ShaderMaterial para cada mesh
	for mesh_actual in meshes:
		if not is_instance_valid(mesh_actual):
			continue

		var nuevo_material = ShaderMaterial.new()
		if configuracion.shader_disolucion != null:
			nuevo_material.shader = configuracion.shader_disolucion

		nuevo_material.set_shader_parameter("dissolve_amount", 0.0)
		nuevo_material.set_shader_parameter("glow_color", configuracion.color_borde)
		nuevo_material.set_shader_parameter("glow_intensity", configuracion.intensidad_emision)
		nuevo_material.set_shader_parameter("edge_thickness", 0.05)
		nuevo_material.set_shader_parameter("noise_scale", 20.0)

		var material_original = mesh_actual.get_surface_override_material(0)
		if (
			material_original == null
			and mesh_actual.mesh
			and mesh_actual.mesh.get_surface_count() > 0
		):
			material_original = mesh_actual.mesh.surface_get_material(0)

		if material_original and material_original is StandardMaterial3D:
			if material_original.albedo_texture:
				nuevo_material.set_shader_parameter(
					"albedo_texture", material_original.albedo_texture
				)
			var color_albedo = material_original.albedo_color
			nuevo_material.set_shader_parameter(
				"albedo_tint", Vector3(color_albedo.r, color_albedo.g, color_albedo.b)
			)

		mesh_actual.material_override = nuevo_material
		materiales_guardados.append({"Mesh": mesh_actual, "Material": nuevo_material})

	var nodo_particulas: GPUParticles3D = null
	if configuracion.Generar_particulas:
		nodo_particulas = _crear_particulas(nodo_raiz, configuracion)

		# Detener emisión antes de terminar
		var tiempo_detener = configuracion.duracion * configuracion.detener_emision_porcentaje
		nodo_raiz.get_tree().create_timer(tiempo_detener).timeout.connect(
			func():
				if is_instance_valid(nodo_particulas):
					nodo_particulas.emitting = false
		)

	var animacion_tween = nodo_raiz.create_tween()
	animacion_tween.tween_method(
		func(valor: float):
			for item in materiales_guardados:
				if is_instance_valid(item["Mesh"]):
					item["Material"].set_shader_parameter("dissolve_amount", valor),
		0.0,
		1.0,
		configuracion.duracion
	)

	animacion_tween.tween_callback(
		func(): _finalizar_disolucion(materiales_guardados, nodo_particulas, callback_al_terminar)
	)


static func _finalizar_disolucion(
	materiales_guardados: Array, nodo_particulas: GPUParticles3D, callback_al_terminar: Callable
) -> void:
	# Limpiar materiales
	for item in materiales_guardados:
		if is_instance_valid(item["Mesh"]):
			item["Mesh"].material_override = null
			if item["Mesh"].mesh:
				for indice_superficie in range(item["Mesh"].mesh.get_surface_count()):
					item["Mesh"].set_surface_override_material(indice_superficie, null)
			item["Mesh"].visible = false

	# Mover partículas a la raíz del árbol para que terminen su ciclo
	if is_instance_valid(nodo_particulas) and nodo_particulas.is_inside_tree():
		var arbol = nodo_particulas.get_tree()
		var posicion_global = nodo_particulas.global_position
		var vida_particulas = nodo_particulas.lifetime

		nodo_particulas.get_parent().remove_child(nodo_particulas)
		arbol.root.add_child(nodo_particulas)
		nodo_particulas.global_position = posicion_global
		nodo_particulas.emitting = false

		arbol.create_timer(vida_particulas + 0.5).timeout.connect(
			func():
				if is_instance_valid(nodo_particulas) and nodo_particulas.is_inside_tree():
					nodo_particulas.queue_free()
		)

	if callback_al_terminar:
		callback_al_terminar.call()


static func _crear_particulas(nodo_raiz: Node, configuracion: ConfigDisolucion) -> GPUParticles3D:
	var particulas = GPUParticles3D.new()
	particulas.name = "particulas_Disolucion"
	particulas.amount = configuracion.particulas_Cantidad
	particulas.lifetime = configuracion.particulas_Vida
	particulas.one_shot = false
	particulas.explosiveness = 0.0
	particulas.randomness = 0.3

	var proceso_mat = ParticleProcessMaterial.new()
	proceso_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proceso_mat.emission_box_extents = configuracion.particulas_Caja
	proceso_mat.direction = Vector3(0, 1, 0)
	proceso_mat.spread = configuracion.particulas_Dispersion
	proceso_mat.initial_velocity_min = configuracion.particulas_Velocidad_Min
	proceso_mat.initial_velocity_max = configuracion.particulas_Velocidad_Max
	proceso_mat.gravity = configuracion.particulas_Gravedad
	proceso_mat.scale_min = configuracion.particulas_Escala_Min * 0.5
	proceso_mat.scale_max = configuracion.particulas_Escala_Max * 0.5

	var gradiente = Gradient.new()
	gradiente.set_color(0, configuracion.color_borde)
	gradiente.set_color(
		1,
		Color(
			configuracion.color_borde.r,
			configuracion.color_borde.g,
			configuracion.color_borde.b,
			0.0
		)
	)
	var textura_gradiente = GradientTexture1D.new()
	textura_gradiente.gradient = gradiente
	proceso_mat.color_ramp = textura_gradiente

	var curva_escala = Curve.new()
	curva_escala.add_point(Vector2(0, 0.2))
	curva_escala.add_point(Vector2(0.3, 1.0))
	curva_escala.add_point(Vector2(1.0, 0.0))
	var textura_escala = CurveTexture.new()
	textura_escala.curve = curva_escala
	proceso_mat.scale_curve = textura_escala

	particulas.process_material = proceso_mat

	var malla_esfera = SphereMesh.new()
	malla_esfera.radius = 0.025
	malla_esfera.height = 0.05

	var material_particula = StandardMaterial3D.new()
	material_particula.albedo_color = configuracion.color_borde
	material_particula.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material_particula.emission_enabled = true
	material_particula.emission = configuracion.color_borde
	material_particula.emission_energy_multiplier = configuracion.intensidad_emision * 0.5
	material_particula.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	malla_esfera.material = material_particula

	particulas.draw_pass_1 = malla_esfera

	nodo_raiz.add_child(particulas)
	if configuracion.Posicion_particulas != Vector3.ZERO:
		particulas.global_position = configuracion.Posicion_particulas
	else:
		particulas.position = Vector3(0, 0.3, 0)

	particulas.emitting = true
	return particulas
