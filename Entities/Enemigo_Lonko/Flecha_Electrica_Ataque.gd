class_name FlechaElectricaAtaque
extends EnemyProjectileBase
## Proyectil de la Habilidad Definitiva (Ult) de Lonko: Jabalina Mágica (MProjectileJavelinVFX_02).
## Fase SUBIDA: asciende verticalmente hacia el cielo.
## Fase ESPERA_MARCA: muestra la marca con el cráneo y aros verdes en la posición de la jugadora.
## Fase CAIDA: cae en picada vertical directamente al suelo, impactando y detonando en el piso.

const MARCA_ZONA_CAIDA_REF = preload("res://Entities/Enemigo_Lonko/Marca_Zona_Caida.gd")
const VFX_IMPACTO_AREA_REF = preload("res://assets/BinbunVFX/magic_areas/effects/pulse_area/pulse_area_vfx_02.tscn")
const SFX_RAYO_ULT_STREAM = preload("res://Entities/Enemigo_Lonko/Sonido rayo ult.mp3")
const TEXTURA_ROCAS_IMPACTO = preload("res://Entities/Enemigo_Lonko/ROCAS.png")
const TEXTURA_HUMO_SALTO = preload("res://TEST_/SmokeFX Lite SpriteSheet 2A-2.png")
const SHADER_HUMO_ONDULANTE = preload("res://Entities/Enemigo_Lonko/humo_ondulante_impacto.gdshader")
const ALTURA_IMPACTO_SUELO: float = 0.15  ## Impacta contra la superficie del suelo

const COLOR_PRIMARIO_VERDE: Color = Color(0.45, 1.0, 0.45, 1.0)
const COLOR_SECUNDARIO_VERDE: Color = Color(0.08, 0.95, 0.22, 1.0)
const COLOR_TERCIARIO_VERDE: Color = Color(0.02, 0.65, 0.12, 1.0)
const COLOR_LUZ_VERDE: Color = Color(0.15, 1.0, 0.30, 1.0)

enum Fase { SUBIDA, ESPERA_MARCA, CAIDA }

@export_category("Ataque Mágico - Trayectoria")
@export var altura_cielo: float = 26.0  ## Altura a la que el proyectil sale de pantalla y espera
@export var velocidad_subida: float = 45.0  ## Velocidad vertical de ascenso
@export var velocidad_caida: float = 36.0  ## Velocidad vertical de caída

@export_category("Ataque Mágico - Zona de Caída")
@export var zona_caida_x_min: float = -10.0
@export var zona_caida_x_max: float = -6.5
@export var zona_caida_z: float = 0.0

@export_category("Ataque Mágico - Marca")
@export var segundos_marca: float = 1.4  ## Tiempo de aviso con el cráneo antes de caer
@export var radio_marca: float = 0.55

@export_category("Ataque Mágico - Daño")
@export var dano: float = 1.0

@export_category("Ataque Mágico - Quemadura en Suelo")
@export var habilitar_quemadura_suelo: bool = true
@export var tamano_quemadura: Vector2 = Vector2(1.3, 1.3)
@export var tiempo_vida_quemadura: float = 3.5
@export var tiempo_desvanecimiento_quemadura: float = 2.5

@export_category("Ataque Mágico - Onda de Choque")
@export var escala_onda_impacto: float = 0.20  ## Escala reducida de la onda de impacto (~0.9m)

var fase: Fase = Fase.SUBIDA
var _punto_caida: Vector3 = Vector3.ZERO
var _marca: Node3D = null
var _gravedad: float = 0.0
var _fase_iniciada: bool = false
var _cuerpos_danados_caida: Dictionary = {}
var _estela_verde: GPUParticles3D = null


func _ready() -> void:
	tiempo_vida = 20.0
	_gravedad = ProjectSettings.get_setting("physics/3d/default_gravity")
	super._ready()
	_cached_mesh_instances.clear()
	_configurar_javelin_vfx()
	_configurar_estela_verde()


func _preparar_visuales() -> void:
	# Anular para no sobreescribir los materiales shader del VFX con el StandardMaterial3D base
	pass


func _aplicar_visuales_cacheados() -> void:
	# Anular para proteger los shaders del proyectil
	pass


func _restaurar_visuales_desde_pool() -> void:
	# Anular para proteger los shaders del proyectil
	pass


func _configurar_javelin_vfx() -> void:
	var javelin := find_child("MProjectileJavelinVFX_02", true, false)
	if javelin and is_instance_valid(javelin):
		if "primary_color" in javelin:
			javelin.set("primary_color", COLOR_PRIMARIO_VERDE)
			javelin.set("secondary_color", COLOR_SECUNDARIO_VERDE)
			javelin.set("tertiary_color", COLOR_TERCIARIO_VERDE)
			javelin.set("light_color", COLOR_LUZ_VERDE)


func _configurar_estela_verde() -> void:
	if _estela_verde and is_instance_valid(_estela_verde):
		return

	_estela_verde = GPUParticles3D.new()
	_estela_verde.name = "EstelaVerdeCaida"
	_estela_verde.amount = 55
	_estela_verde.lifetime = 0.32
	_estela_verde.local_coords = false  ## Deja el rastro en el espacio del mundo al caer a gran velocidad
	_estela_verde.emitting = false
	_estela_verde.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.08, 0.45, 0.08)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 8.0
	pmat.initial_velocity_min = 0.5
	pmat.initial_velocity_max = 1.8
	pmat.gravity = Vector3(0, 0, 0)
	pmat.scale_min = 0.22
	pmat.scale_max = 0.42

	# Gradiente de color verde mágico eléctrico resplandeciente
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 1.0, 0.85, 0.95))
	grad.add_point(0.35, Color(0.18, 1.0, 0.32, 0.85))
	grad.add_point(0.75, Color(0.04, 0.75, 0.15, 0.40))
	grad.set_color(3, Color(0.02, 0.45, 0.08, 0.0))  # Fade suave a transparente
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pmat.color_ramp = grad_tex

	# Curva de reducción de tamaño a lo largo del tiempo
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.55, 0.75))
	curve.add_point(Vector2(1.0, 0.0))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	pmat.scale_curve = curve_tex

	_estela_verde.process_material = pmat

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  ## Brillo aditivo para destello mágico
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.render_priority = 5

	# Textura suave de energía radial
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var center := Vector2(15.5, 15.5)
	for y in range(32):
		for x in range(32):
			var d := Vector2(x, y).distance_to(center) / 15.5
			var a := clampf(1.0 - d * d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	mat.albedo_texture = ImageTexture.create_from_image(img)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	quad.material = mat
	_estela_verde.draw_pass_1 = quad

	add_child(_estela_verde)


func _check_off_screen() -> void:
	pass


func _actualizar_movimiento(delta: float) -> void:
	match fase:
		Fase.SUBIDA:
			global_position += Vector3.UP * velocidad_subida * delta
			_rotar_hacia(Vector3.UP)
			if global_position.y >= altura_cielo:
				_iniciar_fase_espera()
		Fase.ESPERA_MARCA:
			pass
		Fase.CAIDA:
			if not _fase_iniciada:
				_iniciar_fase_caida()
			global_position.y -= velocidad_caida * delta
			velocidad_caida += _gravedad * delta
			_rotar_hacia(Vector3.DOWN)
			if global_position.y <= ALTURA_IMPACTO_SUELO:
				_explotar_en_impacto()
				_safe_destroy()


func _rotar_hacia(dir: Vector3) -> void:
	if dir.y > 0.1:
		rotation_degrees = Vector3(0.0, 0.0, 90.0)
	elif dir.y < -0.1:
		rotation_degrees = Vector3(0.0, 0.0, -90.0)
	elif dir.length_squared() > 0.01:
		rotation = Vector3(0.0, 0.0, atan2(dir.y, dir.x))


func _iniciar_fase_espera() -> void:
	fase = Fase.ESPERA_MARCA
	visible = false
	monitoring = false
	monitorable = false
	if _estela_verde and is_instance_valid(_estela_verde):
		_estela_verde.emitting = false

	# Buscar posición actual de la jugadora en el nivel
	var objetivo: Node3D = null
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		objetivo = players[0] as Node3D
	if objetivo and is_instance_valid(objetivo) and objetivo.is_inside_tree():
		_punto_caida = Vector3(objetivo.global_position.x, 0.0, objetivo.global_position.z)
	else:
		_punto_caida = Vector3(randf_range(zona_caida_x_min, zona_caida_x_max), 0.0, zona_caida_z)

	# Instanciar el marcador del cráneo en la escena principal del nivel
	var root := get_tree().current_scene
	if not root:
		root = get_tree().root

	var marca := MARCA_ZONA_CAIDA_REF.new()
	marca.radio_marca = radio_marca
	marca.duracion_marca = segundos_marca
	_marca = marca
	root.add_child(marca)
	marca.iniciar(_punto_caida)

	await get_tree().create_timer(segundos_marca, false).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return

	# Posicionar la jabalina en el cielo sobre el cráneo y caer
	global_position = Vector3(_punto_caida.x, altura_cielo, _punto_caida.z)
	fase = Fase.CAIDA
	visible = true
	monitoring = true
	monitorable = true
	_rotar_hacia(Vector3.DOWN)
	if _estela_verde and is_instance_valid(_estela_verde):
		_estela_verde.restart()
		_estela_verde.emitting = true


func _iniciar_fase_caida() -> void:
	_fase_iniciada = true
	if _estela_verde and is_instance_valid(_estela_verde):
		_estela_verde.restart()
		_estela_verde.emitting = true


func _on_body_entered(body: Node) -> void:
	if fase != Fase.CAIDA or is_stuck:
		return

	if body.is_in_group("allies") or body.is_in_group("player"):
		if not _cuerpos_danados_caida.has(body):
			_cuerpos_danados_caida[body] = true
			if body.has_method("take_damage"):
				body.take_damage(dano)
			elif body.has_method("recibir_dano"):
				body.recibir_dano(dano)
			# El aturdimiento solo afecta a la protagonista, no a las defensoras aliadas
			if body.is_in_group("player") and body.has_method("aplicar_paralisis"):
				body.aplicar_paralisis(4.0)
			elif body.is_in_group("player") and body.has_method("aplicar_estado_paralisis"):
				body.aplicar_estado_paralisis(4.0)
			_reproducir_sonido_rayo()


func _explotar_en_impacto() -> void:
	_reproducir_sonido_rayo()

	if _estela_verde and is_instance_valid(_estela_verde):
		_estela_verde.emitting = false

	# 1. Rastro de quemadura / ceniza y columna de humo ondulante en el suelo
	if habilitar_quemadura_suelo:
		_crear_rastro_quemadura_suelo(global_position)
		_crear_columna_humo_ondulante(global_position)

	# 2. Rocas pequeñas expulsadas por la fuerza del impacto (mismas del pilar)
	_crear_particulas_rocas_impacto(global_position)

	# 3. Humo a ambos lados del impacto (estilo salto de la protagonista)
	_crear_humo_impacto_lados(global_position)

	# 4. Destruir la marca del cráneo al impactar en el suelo
	if _marca and is_instance_valid(_marca):
		if _marca.has_method("explotar_y_destruir"):
			_marca.call("explotar_y_destruir")
		else:
			_marca.queue_free()
		_marca = null

	# 5. Detonación de onda mágica verde en el piso (PulseAreaVFX_02)
	if VFX_IMPACTO_AREA_REF:
		var vfx_impacto := VFX_IMPACTO_AREA_REF.instantiate() as Node3D
		if vfx_impacto:
			# Duplicar materiales y asignar parámetros verdes luminosos directamente a los shaders
			for m in vfx_impacto.find_children("*", "MeshInstance3D", true, false):
				var mi := m as MeshInstance3D
				if mi and mi.material_override:
					var dup_mat: Material = mi.material_override.duplicate()
					if dup_mat is ShaderMaterial:
						dup_mat.render_priority = 10
						dup_mat.set_shader_parameter("primary_color", COLOR_PRIMARIO_VERDE)
						dup_mat.set_shader_parameter("secondary_color", COLOR_SECUNDARIO_VERDE)
						dup_mat.set_shader_parameter("tertiary_color", COLOR_TERCIARIO_VERDE)
						dup_mat.set_shader_parameter("use_tertiary", false)
						dup_mat.set_shader_parameter("emission_strength", 4.0)
					mi.material_override = dup_mat

			var light := vfx_impacto.get_node_or_null("Light") as OmniLight3D
			if light:
				light.light_color = COLOR_LUZ_VERDE
				light.light_energy = 4.0
				light.omni_range = 3.5

			if "one_shot" in vfx_impacto:
				vfx_impacto.set("one_shot", true)
			if "primary_color" in vfx_impacto:
				vfx_impacto.set("primary_color", COLOR_PRIMARIO_VERDE)
			if "secondary_color" in vfx_impacto:
				vfx_impacto.set("secondary_color", COLOR_SECUNDARIO_VERDE)
			if "tertiary_color" in vfx_impacto:
				vfx_impacto.set("tertiary_color", COLOR_TERCIARIO_VERDE)
			if "light_color" in vfx_impacto:
				vfx_impacto.set("light_color", COLOR_LUZ_VERDE)

			var root := get_tree().current_scene
			if not root:
				root = get_tree().root
			root.add_child(vfx_impacto)
			vfx_impacto.global_position = Vector3(global_position.x, 0.06, global_position.z)
			vfx_impacto.scale = Vector3.ONE * escala_onda_impacto
			if vfx_impacto.has_method("play"):
				vfx_impacto.call("play")

			get_tree().create_timer(1.4, false).timeout.connect(func():
				if is_instance_valid(vfx_impacto):
					vfx_impacto.queue_free()
			)


func _crear_particulas_rocas_impacto(pos: Vector3) -> void:
	var floor_pos := Vector3(pos.x, 0.0, pos.z)
	var space_state := get_world_3d().direct_space_state
	if space_state:
		var query := PhysicsRayQueryParameters3D.create(pos + Vector3(0.0, 0.5, 0.0), pos + Vector3(0.0, -6.0, 0.0))
		query.collision_mask = 1
		var hit := space_state.intersect_ray(query)
		if hit and hit.has("position"):
			floor_pos = hit.position

	var parts := GPUParticles3D.new()
	parts.name = "ParticulasRocasImpactoUlt"
	parts.amount = 16
	parts.lifetime = 2.0
	parts.one_shot = true
	parts.explosiveness = 0.9

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.25, 0.05, 0.25)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 45.0
	pmat.initial_velocity_min = 4.0
	pmat.initial_velocity_max = 7.5
	pmat.gravity = Vector3(0, -14.0, 0)
	pmat.scale_min = 0.18
	pmat.scale_max = 0.42
	pmat.color = Color(1.0, 1.0, 1.0, 1.0)

	# Seleccionar aleatoriamente una de las 4 rocas del atlas ROCAS.png
	pmat.anim_offset_min = 0.0
	pmat.anim_offset_max = 1.0
	pmat.angle_min = 0.0
	pmat.angle_max = 360.0
	pmat.angular_velocity_min = -240.0
	pmat.angular_velocity_max = 240.0
	parts.process_material = pmat

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = TEXTURA_ROCAS_IMPACTO
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.particles_anim_h_frames = 4
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = false
	mat.render_priority = 1

	var quad := QuadMesh.new()
	quad.size = Vector2(0.26, 0.26)
	quad.material = mat
	parts.draw_pass_1 = quad

	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	root.add_child(parts)
	parts.global_position = floor_pos + Vector3(0.0, 0.05, 0.0)
	parts.restart()
	parts.emitting = true

	get_tree().create_timer(2.2, false).timeout.connect(func():
		if is_instance_valid(parts):
			parts.queue_free()
	)


func _crear_humo_impacto_lados(pos: Vector3) -> void:
	var floor_pos := Vector3(pos.x, 0.0, pos.z)
	var space_state := get_world_3d().direct_space_state
	if space_state:
		var query := PhysicsRayQueryParameters3D.create(pos + Vector3(0.0, 0.5, 0.0), pos + Vector3(0.0, -6.0, 0.0))
		query.collision_mask = 1
		var hit := space_state.intersect_ray(query)
		if hit and hit.has("position"):
			floor_pos = hit.position

	var root := get_tree().current_scene
	if not root:
		root = get_tree().root

	for side in [-1, 1]:
		var puf := GPUParticles3D.new()
		puf.name = "HumoImpactoUltSide"
		puf.amount = 4
		puf.lifetime = 0.75
		puf.one_shot = true
		puf.explosiveness = 0.35
		puf.randomness = 0.3
		puf.visibility_aabb = AABB(Vector3(-1.5, -1.2, -1.5), Vector3(3, 3, 3))

		var pmat := ParticleProcessMaterial.new()
		pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		pmat.direction = Vector3(side * 1.0, 0.3, 0.0)
		pmat.spread = 22.0
		pmat.initial_velocity_min = 1.0
		pmat.initial_velocity_max = 2.0
		pmat.gravity = Vector3(0, -0.2, 0)
		pmat.scale_min = 0.55
		pmat.scale_max = 0.85
		pmat.anim_speed_min = 1.0
		pmat.anim_speed_max = 1.2
		pmat.anim_offset_min = 0.0
		pmat.anim_offset_max = 0.3

		var grad := Gradient.new()
		grad.set_color(0, Color(0.96, 0.94, 0.88, 0.85))
		grad.set_color(1, Color(0.96, 0.94, 0.88, 0.0))
		var grad_tex := GradientTexture1D.new()
		grad_tex.gradient = grad
		pmat.color_ramp = grad_tex

		pmat.turbulence_enabled = true
		pmat.turbulence_noise_strength = 0.008
		puf.process_material = pmat

		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = TEXTURA_HUMO_SALTO
		mat.particles_anim_h_frames = 6
		mat.particles_anim_v_frames = 1
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.billboard_keep_scale = true
		mat.render_priority = 2

		var quad := QuadMesh.new()
		quad.size = Vector2(0.8, 0.8)
		quad.material = mat
		puf.draw_pass_1 = quad

		root.add_child(puf)
		puf.global_position = floor_pos + Vector3(side * 0.25, 0.05, 0.0)
		puf.restart()
		puf.emitting = true

		get_tree().create_timer(1.2, false).timeout.connect(func():
			if is_instance_valid(puf):
				puf.queue_free()
		)


func _crear_rastro_quemadura_suelo(pos: Vector3) -> void:
	var floor_pos := Vector3(pos.x, 0.0, pos.z)
	var floor_normal := Vector3.UP
	var space_state := get_world_3d().direct_space_state
	if space_state:
		var query := PhysicsRayQueryParameters3D.create(pos + Vector3(0.0, 0.5, 0.0), pos + Vector3(0.0, -6.0, 0.0))
		query.collision_mask = 65  # Capa 1 (Mundo) y Capa 7 (Plataformas/Rampas)
		var hit := space_state.intersect_ray(query)
		if hit and hit.has("position"):
			floor_pos = hit.position
			if hit.has("normal") and hit.normal.length_squared() > 0.001:
				floor_normal = hit.normal

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "RastroQuemaduraUltLonko"
	var quad := QuadMesh.new()
	quad.size = tamano_quemadura
	mesh_inst.mesh = quad

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.06, 0.05, 0.04, 0.82)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = -2

	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(31.5, 31.5)
	for y in range(64):
		for x in range(64):
			var dist: float = Vector2(x, y).distance_to(center) / 31.0
			var alpha: float = clamp(1.0 - dist * dist, 0.0, 1.0)
			var noise_factor: float = sin(float(x) * 1.5) * cos(float(y) * 1.5) * 0.12
			alpha = clamp(alpha + noise_factor, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.05, 0.04, 0.03, alpha))
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mesh_inst.material_override = mat

	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	root.add_child(mesh_inst)

	VFXFactory.align_decal_to_surface(mesh_inst, floor_pos, floor_normal, 0.015)

	var tween := mesh_inst.create_tween()
	tween.tween_interval(tiempo_vida_quemadura)
	tween.tween_property(mat, "albedo_color:a", 0.0, tiempo_desvanecimiento_quemadura) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if is_instance_valid(mesh_inst):
			mesh_inst.queue_free()
	)


func _crear_columna_humo_ondulante(pos: Vector3) -> void:
	var floor_pos := Vector3(pos.x, 0.0, pos.z)
	var space_state := get_world_3d().direct_space_state
	if space_state:
		var query := PhysicsRayQueryParameters3D.create(pos + Vector3(0.0, 0.5, 0.0), pos + Vector3(0.0, -6.0, 0.0))
		query.collision_mask = 1
		var hit := space_state.intersect_ray(query)
		if hit and hit.has("position"):
			floor_pos = hit.position

	var root := get_tree().current_scene
	if not root:
		root = get_tree().root

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "ColumnaHumoOndulanteUlt"

	var quad := QuadMesh.new()
	quad.size = Vector2(0.85, 2.2)
	quad.center_offset = Vector3(0.0, 1.1, 0.0)  ## Base del quad anclada directamente en la superficie del suelo
	mesh_inst.mesh = quad

	var mat := ShaderMaterial.new()
	mat.shader = SHADER_HUMO_ONDULANTE
	mat.render_priority = 3
	mat.set_shader_parameter("smoke_color", Color(0.42, 0.40, 0.38, 0.78))
	mat.set_shader_parameter("speed", 3.4)
	mat.set_shader_parameter("wave_amplitude", 0.12)
	mat.set_shader_parameter("wave_freq", 10.0)
	mat.set_shader_parameter("column_width", 0.09)
	mat.set_shader_parameter("fade_alpha", 1.0)
	mat.set_shader_parameter("growth", 0.0)
	mesh_inst.material_override = mat

	root.add_child(mesh_inst)
	mesh_inst.global_position = floor_pos + Vector3(0.0, -0.05, 0.0)

	# Secuencia de animación de la columna de humo con duración reducida
	var tween := mesh_inst.create_tween()
	# 1. Fase de crecimiento: el humo emerge y sube ondulando desde la tierra
	tween.tween_property(mat, "shader_parameter/growth", 1.0, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 2. Fase de ondulación activa sostenida (1.2 segundos)
	tween.tween_interval(1.2)
	# 3. Fase de desvanecimiento suave y rápido
	tween.tween_property(mat, "shader_parameter/fade_alpha", 0.0, 0.85) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func():
		if is_instance_valid(mesh_inst):
			mesh_inst.queue_free()
	)


func _reproducir_sonido_rayo() -> void:
	if not SFX_RAYO_ULT_STREAM:
		return
	var player := AudioStreamPlayer.new()
	player.add_to_group("pausable_audio")
	player.stream = SFX_RAYO_ULT_STREAM
	player.volume_db = -2.5
	player.bus = "Master"
	var root := get_tree().current_scene
	if root:
		root.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
	else:
		player.queue_free()
	AudioManager.play_sfx("shield_hit_arrow")
