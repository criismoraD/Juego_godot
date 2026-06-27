class_name EnemyProjectileBase
extends Area3D

const CAMERA_UTILS_REF = preload("res://System/Utils/CameraUtils.gd")
const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")
const DEFAULT_OFFSCREEN_MARGIN_X: float = 200.0
const DEFAULT_OFFSCREEN_MARGIN_TOP: float = 200.0
const DEFAULT_OFFSCREEN_MARGIN_BOTTOM: float = 200.0
const MIN_WORLD_Y: float = -20.0
const SPAWN_COLLISION_DELAY: float = 0.1
const DESTROY_DELAY: float = 0.3
const MIN_DIRECTION_LENGTH_SQUARED: float = 0.01
const ARROW_TIP_OFFSET: float = 0.165

@export_category("Tiempo")
@export var tiempo_vida: float = 10.0
@export var tiempo_pegada: float = 5.0

@export_category("Visual")
@export var color_proyectil: Color = Color.WHITE

var direction: Vector3 = Vector3.LEFT
var is_stuck: bool = false
var projectile_material: StandardMaterial3D
var trail_particles: GPUParticles3D

var offscreen_margin_x: float = DEFAULT_OFFSCREEN_MARGIN_X
var offscreen_margin_top: float = DEFAULT_OFFSCREEN_MARGIN_TOP
var offscreen_margin_bottom: float = DEFAULT_OFFSCREEN_MARGIN_BOTTOM

var _cached_mesh_instances: Array[Node] = []
var _destroying: bool = false
var _lifecycle_id: int = 0
var gameplay_z_plane: float = 0.0

static var _projectile_material_cache: Dictionary = {}
static var _trail_process_material_cache: Dictionary = {}
static var _trail_mesh_cache: Dictionary = {}
static var _body_mesh: CylinderMesh = null
static var _tip_mesh: CylinderMesh = null


func _ready() -> void:
	# Si somos una flecha en mano (por ejemplo, nos llamamos FlechaMano o tenemos un ancestro BoneAttachment3D),
	# no nos comportamos como proyectil.
	var es_flecha_mano := false
	if name == "FlechaMano":
		es_flecha_mano = true
	else:
		var parent_node := get_parent()
		while parent_node:
			if parent_node is BoneAttachment3D or "Attachment" in parent_node.name or "Mano" in parent_node.name or "Hand" in parent_node.name:
				es_flecha_mano = true
				break
			parent_node = parent_node.get_parent()

	if es_flecha_mano:
		set_physics_process(false)
		monitoring = false
		monitorable = false
		visible = false
		_preparar_visuales()
		_cached_mesh_instances = find_children("*", "MeshInstance3D", true, false)
		_aplicar_visuales_cacheados()
		_restaurar_visuales_desde_pool()
		if trail_particles:
			trail_particles.emitting = false
		return

	add_to_group("enemy_projectiles")
	var player = get_tree().get_first_node_in_group("player")
	if player:
		gameplay_z_plane = player.global_position.z
	else:
		gameplay_z_plane = 0.0

	_preparar_visuales()
	_cached_mesh_instances = find_children("*", "MeshInstance3D", true, false)
	_aplicar_visuales_cacheados()
	_activar_desde_pool()


func _physics_process(delta: float) -> void:
	if is_stuck:
		return

	_actualizar_movimiento(delta)
	_check_off_screen()


func initialize(shoot_direction: Vector3, _potencia: float = 1.0) -> void:
	_inicializar_direccion(shoot_direction)


func _actualizar_movimiento(_delta: float) -> void:
	pass


func _preparar_visuales() -> void:
	pass


func _aplicar_visuales_cacheados() -> void:
	pass


func _restaurar_visuales_desde_pool() -> void:
	_create_material()
	for mesh in _cached_mesh_instances:
		if not is_instance_valid(mesh):
			continue

		if mesh is MeshInstance3D:
			mesh.visible = true
			mesh.material_override = projectile_material

	if trail_particles:
		trail_particles.process_material = _get_shared_trail_process_material(color_proyectil)
		trail_particles.draw_pass_1 = _get_shared_trail_mesh(color_proyectil)
		trail_particles.emitting = true


func _on_impacto_con_dano(_body: Node) -> void:
	pass


func _on_impacto_con_escudo(_body: Node) -> void:
	pass


func _inicializar_direccion(shoot_direction: Vector3) -> void:
	direction = Vector3(shoot_direction.x, shoot_direction.y, 0.0).normalized()
	if direction.length_squared() < MIN_DIRECTION_LENGTH_SQUARED:
		direction = Vector3.LEFT

	_actualizar_rotacion_por_direccion()


func _aplicar_movimiento_recto(delta: float, velocidad_actual: float) -> void:
	global_position += direction * velocidad_actual * delta
	_forzar_plano_y_rotacion()


func _aplicar_movimiento_parabolico(delta: float, velocidad_actual: float, gravedad_actual: float) -> void:
	direction.y -= gravedad_actual * delta
	global_position += direction * velocidad_actual * delta
	_forzar_plano_y_rotacion()


func _forzar_plano_y_rotacion() -> void:
	global_position.z = gameplay_z_plane
	_actualizar_rotacion_por_direccion()


func _actualizar_rotacion_por_direccion() -> void:
	if direction.length_squared() <= MIN_DIRECTION_LENGTH_SQUARED:
		return

	rotation = Vector3(0.0, 0.0, atan2(direction.y, direction.x))


func _activar_desde_pool() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		gameplay_z_plane = player.global_position.z
	else:
		gameplay_z_plane = 0.0

	_lifecycle_id += 1
	_destroying = false
	is_stuck = false
	visible = true
	monitorable = true
	set_physics_process(true)
	_restaurar_visuales_desde_pool()
	_configurar_ciclo_de_vida(_lifecycle_id)


func _desactivar_para_pool() -> void:
	_lifecycle_id += 1
	_destroying = false
	is_stuck = true
	visible = false
	_detener_trail()
	monitoring = false
	monitorable = false
	set_physics_process(false)


func _configurar_ciclo_de_vida(lifecycle_id: int) -> void:
	monitoring = false
	get_tree().create_timer(SPAWN_COLLISION_DELAY).timeout.connect(
		func() -> void:
			if is_instance_valid(self ) and is_inside_tree() and _lifecycle_id == lifecycle_id:
				monitoring = true
	)

	get_tree().create_timer(tiempo_vida).timeout.connect(
		func() -> void:
			if is_instance_valid(self ) and is_inside_tree() and _lifecycle_id == lifecycle_id:
				_check_destroy()
	)

	var collision_callback := Callable(self , "_on_body_entered")
	if not body_entered.is_connected(collision_callback):
		body_entered.connect(collision_callback)


func _on_body_entered(body: Node) -> void:
	if is_stuck:
		return

	if body.is_in_group("allies"):
		_aplicar_dano_a_objetivo(body)
		_on_impacto_con_dano(body)
		_safe_destroy()
		return

	if body is StaticBody3D or body is AnimatableBody3D:
		if body.has_method("recibir_golpe"):
			if "es_escudo_enemigo" in body and body.es_escudo_enemigo:
				return # Pasa a través del escudo enemigo
			
			body.recibir_golpe()
			_on_impacto_con_escudo(body)
			_stick_to_shield(body)
			return

		_stick_to_surface()
		return

	if body.is_in_group("player"):
		_aplicar_dano_a_objetivo(body)
		_on_impacto_con_dano(body)
		_safe_destroy()


func _aplicar_dano_a_objetivo(body: Node) -> void:
	var target := _obtener_objetivo_dano(body)
	if target.has_method("take_damage"):
		target.take_damage(1.0)
		return

	if target.has_method("recibir_dano"):
		target.recibir_dano(1)


func _obtener_objetivo_dano(body: Node) -> Node:
	var parent := body.get_parent()
	if parent and parent.has_method("take_damage"):
		return parent

	return body


func _stick_to_surface() -> void:
	_marcar_como_pegado()
	_programar_destruccion_pegada()


func _stick_to_shield(shield: Node3D) -> void:
	_marcar_como_pegado()
	var saved_global_transform := global_transform
	call_deferred("_reparent_to_shield", shield, saved_global_transform)
	_programar_destruccion_pegada()


func _marcar_como_pegado() -> void:
	is_stuck = true
	direction = Vector3.ZERO
	_detener_trail()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


func _programar_destruccion_pegada() -> void:
	var lifecycle_id := _lifecycle_id
	get_tree().create_timer(tiempo_pegada).timeout.connect(
		func() -> void:
			if is_instance_valid(self ) and is_inside_tree() and _lifecycle_id == lifecycle_id:
				_devolver_o_liberar()
	)


func _reparent_to_shield(shield: Node3D, saved_transform: Transform3D) -> void:
	if not is_instance_valid(shield):
		_devolver_o_liberar()
		return

	var current_parent := get_parent()
	if current_parent:
		current_parent.remove_child(self )

	shield.add_child(self )
	global_transform = saved_transform

	if shield.has_signal("destruido"):
		var lifecycle_id := _lifecycle_id
		shield.destruido.connect(
			func() -> void:
				if is_instance_valid(self ) and is_inside_tree() and _lifecycle_id == lifecycle_id:
					_devolver_o_liberar()
		)


func _safe_destroy() -> void:
	if _destroying:
		return

	_destroying = true
	_detener_trail()
	_cleanup_materials()
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_physics_process(false)
	var lifecycle_id := _lifecycle_id
	get_tree().create_timer(DESTROY_DELAY).timeout.connect(
		func() -> void:
			if is_instance_valid(self ) and is_inside_tree() and _lifecycle_id == lifecycle_id:
				_devolver_o_liberar()
	)


func _devolver_o_liberar() -> void:
	if has_meta(PROJECTILE_POOL_REF.META_SCENE_PATH):
		PROJECTILE_POOL_REF.release(self )
		return

	_cleanup_materials()
	queue_free()


func _detener_trail() -> void:
	if not trail_particles:
		return

	trail_particles.emitting = false
	trail_particles.draw_pass_1 = null


func _cleanup_materials() -> void:
	for mesh in _cached_mesh_instances:
		if not is_instance_valid(mesh):
			continue

		if mesh is MeshInstance3D:
			mesh.material_override = null
			if mesh.mesh:
				for surface_index in range(mesh.mesh.get_surface_count()):
					mesh.set_surface_override_material(surface_index, null)
			mesh.visible = false


func _check_destroy() -> void:
	if not is_stuck:
		_safe_destroy()


func _check_off_screen() -> void:
	var camera := CAMERA_UTILS_REF.obtener_camara_juego(self )
	if not camera:
		return

	var screen_pos := camera.unproject_position(global_position)
	var viewport_size := get_viewport().get_visible_rect().size
	if screen_pos.x < -offscreen_margin_x or screen_pos.x > viewport_size.x + offscreen_margin_x:
		_safe_destroy()
	elif screen_pos.y < -offscreen_margin_top:
		_safe_destroy()
	elif screen_pos.y > viewport_size.y + offscreen_margin_bottom:
		_safe_destroy()
	elif global_position.y < MIN_WORLD_Y:
		_safe_destroy()


func _remove_glb_model() -> void:
	for child_name in ["VIROTE_BALLESTA", "Model"]:
		var node := find_child(child_name, false, false)
		if node:
			node.queue_free()

	for child in get_children():
		if child.is_queued_for_deletion():
			continue
		if not (child is Node3D):
			continue
		if child is CollisionShape3D or child is MeshInstance3D or child is GPUParticles3D:
			continue

		child.queue_free()


func _create_material(emission_energy: float = 3.0) -> void:
	projectile_material = _get_shared_projectile_material(color_proyectil, emission_energy)


func _create_procedural_arrow() -> void:
	var body_mesh := MeshInstance3D.new()
	body_mesh.name = "Body"
	body_mesh.mesh = _get_shared_body_mesh()
	body_mesh.material_override = projectile_material
	body_mesh.add_to_group("outline_meshes")
	body_mesh.rotation = Vector3(0.0, 0.0, -PI / 2.0)

	var tip_mesh := MeshInstance3D.new()
	tip_mesh.name = "Tip"
	tip_mesh.mesh = _get_shared_tip_mesh()
	tip_mesh.material_override = projectile_material
	tip_mesh.add_to_group("outline_meshes")
	tip_mesh.rotation = Vector3(0.0, 0.0, -PI / 2.0)
	tip_mesh.position = Vector3(ARROW_TIP_OFFSET, 0.0, 0.0)

	var mesh_container := Node3D.new()
	mesh_container.name = "ArrowModel"
	mesh_container.add_child(body_mesh)
	mesh_container.add_child(tip_mesh)
	add_child(mesh_container)


func _create_trail_particles() -> void:
	trail_particles = GPUParticles3D.new()
	trail_particles.name = "TrailVFX"
	trail_particles.emitting = true
	trail_particles.one_shot = false
	trail_particles.amount = 15
	trail_particles.lifetime = 0.25
	trail_particles.preprocess = 0.0
	trail_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_particles.process_material = _get_shared_trail_process_material(color_proyectil)
	trail_particles.draw_pass_1 = _get_shared_trail_mesh(color_proyectil)
	add_child(trail_particles)


static func _get_color_key(color: Color) -> String:
	return "%.3f_%.3f_%.3f_%.3f" % [color.r, color.g, color.b, color.a]


static func _get_shared_projectile_material(
	color: Color,
	emission_energy: float = 3.0
) -> StandardMaterial3D:
	var key := "%s_%.3f" % [_get_color_key(color), emission_energy]
	if _projectile_material_cache.has(key):
		return _projectile_material_cache[key]

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var shader = load("res://System/Shaders/TOON_PROYECTIL_LINEA.gdshader") as Shader
	if shader:
		var outline_mat = ShaderMaterial.new()
		outline_mat.shader = shader
		outline_mat.set_shader_parameter("outline_color", Color(0, 0, 0, 1))
		outline_mat.set_shader_parameter("outline_width", 20.0)
		material.next_pass = outline_mat

	_projectile_material_cache[key] = material
	return material


static func _get_shared_body_mesh() -> CylinderMesh:
	if _body_mesh:
		return _body_mesh

	_body_mesh = CylinderMesh.new()
	_body_mesh.top_radius = 0.025
	_body_mesh.bottom_radius = 0.025
	_body_mesh.height = 0.25
	_body_mesh.radial_segments = 6
	_body_mesh.rings = 1
	return _body_mesh


static func _get_shared_tip_mesh() -> CylinderMesh:
	if _tip_mesh:
		return _tip_mesh

	_tip_mesh = CylinderMesh.new()
	_tip_mesh.top_radius = 0.0
	_tip_mesh.bottom_radius = 0.03
	_tip_mesh.height = 0.08
	_tip_mesh.radial_segments = 6
	_tip_mesh.rings = 1
	return _tip_mesh


static func _get_shared_trail_process_material(color: Color) -> ParticleProcessMaterial:
	var key := _get_color_key(color)
	if _trail_process_material_cache.has(key):
		return _trail_process_material_cache[key]

	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process_mat.direction = Vector3.ZERO
	process_mat.spread = 10.0
	process_mat.initial_velocity_min = 0.0
	process_mat.initial_velocity_max = 0.2
	process_mat.gravity = Vector3.ZERO
	process_mat.scale_min = 0.005
	process_mat.scale_max = 0.01

	var gradient := Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 0.8))
	gradient.set_color(1, Color(color.r * 0.8, color.g * 0.6, color.b * 0.5, 0.0))

	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))

	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	process_mat.scale_curve = scale_tex

	_trail_process_material_cache[key] = process_mat
	return process_mat


static func _get_shared_trail_mesh(color: Color) -> SphereMesh:
	var key := _get_color_key(color)
	if _trail_mesh_cache.has(key):
		return _trail_mesh_cache[key]

	var mesh := SphereMesh.new()
	mesh.radius = 0.0125
	mesh.height = 0.025

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 4.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material

	_trail_mesh_cache[key] = mesh
	return mesh
