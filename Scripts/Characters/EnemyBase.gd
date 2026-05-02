class_name EnemyBase
extends CharacterBody3D
## Clase base para todos los enemigos.
## Contiene la lógica compartida: vida, disolución, flash de daño,
## tracking de jugador, partículas, espaciado, etc.
## Los enemigos concretos (Goblin, GoblinGirl) heredan de esta clase.
# === CONFIGURACIÓN - MOVIMIENTO ===
signal died
signal pacifico_danado  ## Emitida cuando un enemigo pacífico recibe daño
enum State { WALKING, SHOOTING, DYING, DEAD }
@export_category("Movimiento")
@export var velocidad_caminar: float = 1.0
@export var distancia_minima_caminar: float = 1.0
@export var distancia_maxima_caminar: float = 6.0
# === CONFIGURACIÓN - COMBATE ===
@export_category("Combate")
@export var vida_maxima: int = 1
@export var altura_spawn_flecha: float = 0.5
# === CONFIGURACIÓN - APUNTADO ===
@export_category("Apuntado")
@export var rastrear_jugador: bool = true
@export_range(-90, 90, 1.0) var angulo_apuntado_minimo: float = -45.0
@export_range(-90, 90, 1.0) var angulo_apuntado_maximo: float = 45.0
# === CONFIGURACIÓN - ESPACIADO ===
@export_category("Espaciado")
@export var distancia_minima_entre_enemigos: float = 0.5
# === CONFIGURACIÓN - EFECTO DE MUERTE ===
@export_category("Efecto de Muerte")
@export var duracion_disolucion: float = 1.0
@export var color_borde_disolucion: Color = Color(1.0, 0.6, 0.2)
@export var intensidad_emision: float = 3.0
# === CONFIGURACIÓN - PARTÍCULAS DE DISOLUCIÓN ===
@export_category("Partículas de Disolución")
@export var particulas_cantidad: int = 25
@export var particulas_vida: float = 2.0
@export var particulas_posicion: Vector3 = Vector3(-0.5, 0.1, 0)
@export var particulas_caja: Vector3 = Vector3(0.2, 0.5, 0.1)
@export var particulas_dispersion: float = 20.0
@export var particulas_velocidad_min: float = 0.1
@export var particulas_velocidad_max: float = 1.0
@export var particulas_gravedad: Vector3 = Vector3(0, 0.1, 0)
@export var particulas_escala_min: float = 0.005
@export var particulas_escala_max: float = 0.015
@export_range(0.0, 1.0, 0.1) var particulas_detener_emision: float = 0.7
# === REFERENCIAS ===
var anim_player: AnimationPlayer
var player_ref: Node3D = null
var skeleton: Skeleton3D = null
var spine_bone_idx: int = -1
var hips_bone_idx: int = -1
# === ESTADO ===
var current_state: State = State.WALKING
var health: int = 2
var modo_pacifico: bool = false  ## Si true, el enemigo solo camina sin atacar
var limite_pacifico_x: float = -10.0  ## Posición X donde se detiene en modo pacífico
var pacifico_detenido: bool = false  ## True cuando ya se detuvo en el borde
var walked_distance: float = 0.0
var target_walk_distance: float = 0.0
var shoot_timer: float = 0.0
var original_materials: Array = []
# === EFECTO DE DISOLUCIÓN ===
var dissolve_shader = preload("res://Assets/Shaders/dissolve.gdshader")
var is_dissolving: bool = false
var dissolve_materials: Array = []
var dissolve_particles: GPUParticles3D = null
# === CACHÉ DE NODOS ===
var _cached_mesh_instances: Array[Node] = []
var _cached_particles: Array[Node] = []
var _red_flash_material: StandardMaterial3D = null
# === SEÑALES ===
var game_feel: Node = null
# ═══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ═══════════════════════════════════════════════════════════════════════════════


func _ready():
	game_feel = get_node_or_null("/root/GameFeel")
	add_to_group("enemies")
	active_enemies_cache.append(self)
	health = vida_maxima
	target_walk_distance = randf_range(distancia_minima_caminar, distancia_maxima_caminar)

	_cached_mesh_instances = find_children("*", "MeshInstance3D", true, false)
	_cached_particles = find_children("*", "GPUParticles3D", true, false)

	_red_flash_material = StandardMaterial3D.new()
	_red_flash_material.albedo_color = Color(1, 0, 0)
	_red_flash_material.emission_enabled = true
	_red_flash_material.emission = Color(1, 0, 0)
	_red_flash_material.emission_energy_multiplier = 2.0

	_desactivar_bones_fisicos()
	_buscar_animation_player()
	_store_original_materials()
	_buscar_skeleton()
	_buscar_jugador()
	_on_enemy_ready()  # Hook para subclases


func _desactivar_bones_fisicos():
	var bone_simulator = find_child("PhysicalBoneSimulat*", true, false)
	if bone_simulator and bone_simulator is PhysicalBoneSimulator3D:
		bone_simulator.physical_bones_stop_simulation()
		for child in bone_simulator.get_children():
			if child is PhysicalBone3D:
				child.set_physics_process(false)


func _buscar_animation_player():
	var candidatos = find_children("*", "AnimationPlayer", true, false)
	if candidatos.is_empty():
		anim_player = null
		return

	# Cuando hay accesorios instanciados (por ejemplo, arco), elegir el
	# AnimationPlayer con más animaciones evita capturar el del accesorio.
	var mejor_player: AnimationPlayer = null
	var max_anims := -1
	for candidato in candidatos:
		var player := candidato as AnimationPlayer
		if not player:
			continue
		var total_anims := player.get_animation_list().size()
		if total_anims > max_anims:
			max_anims = total_anims
			mejor_player = player

	anim_player = mejor_player
	if anim_player:
		for anim_name in anim_player.get_animation_list():
			if (
				"CORRER" in anim_name
				or "CAMINAR" in anim_name
				or "CAMINA" in anim_name
				or "RUN" in anim_name
				or "WALK" in anim_name
				or "IDLE" in anim_name
			):
				var anim = anim_player.get_animation(anim_name)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR


func _buscar_skeleton():
	skeleton = find_child("Skeleton3D", true, false)
	if skeleton:
		spine_bone_idx = skeleton.find_bone("mixamorig_Spine1")
		if spine_bone_idx == -1:
			spine_bone_idx = skeleton.find_bone("mixamorig_Spine")
		hips_bone_idx = skeleton.find_bone("mixamorig_Hips")
		if hips_bone_idx == -1:
			hips_bone_idx = skeleton.find_bone("Hips")


func _buscar_jugador():
	await get_tree().process_frame
	player_ref = get_tree().get_first_node_in_group("player")


func _process(delta):
	# Actualizar posición de partículas de disolución para seguir el centro del cuerpo
	if is_dissolving and dissolve_particles and is_instance_valid(dissolve_particles):
		var bone_pos = _get_hips_global_position()
		if bone_pos != Vector3.ZERO:
			dissolve_particles.global_position = bone_pos


func _get_hips_global_position() -> Vector3:
	if skeleton and is_instance_valid(skeleton) and hips_bone_idx != -1:
		var bone_pose = skeleton.get_bone_global_pose(hips_bone_idx)
		return skeleton.global_transform * bone_pose.origin
	# Fallback: usar spine si no hay hips
	if skeleton and is_instance_valid(skeleton) and spine_bone_idx != -1:
		var bone_pose = skeleton.get_bone_global_pose(spine_bone_idx)
		return skeleton.global_transform * bone_pose.origin
	return Vector3.ZERO


## Hook para que las subclases ejecuten lógica adicional en _ready()
func _on_enemy_ready():
	# Virtual method: override in subclasses to add initialization logic.
	pass


## Hook para cuando el enemigo se detiene en modo pacífico.
## Las subclases pueden overridear para poses específicas.
func _on_pacifico_detenido():
	# Virtual method: override in subclasses if a specific stop animation is needed.
	_play_animation("IDLE")


# ═══════════════════════════════════════════════════════════════════════════════
# MATERIALES
# ═══════════════════════════════════════════════════════════════════════════════


func _store_original_materials():
	for mesh in _cached_mesh_instances:
		mesh.add_to_group("outline_meshes")
		if mesh.get_surface_override_material_count() > 0:
			for i in range(mesh.get_surface_override_material_count()):
				original_materials.append(
					{"mesh": mesh, "index": i, "material": mesh.get_surface_override_material(i)}
				)


# ═══════════════════════════════════════════════════════════════════════════════
# FÍSICA Y ESTADOS
# ═══════════════════════════════════════════════════════════════════════════════


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	match current_state:
		State.WALKING:
			_process_walking(delta)
		State.SHOOTING:
			_process_shooting(delta)
		State.DYING:
			_process_dying(delta)
		State.DEAD:
			pass

	move_and_slide()


func _process_walking(delta):
	velocity.x = -velocidad_caminar
	walked_distance += velocidad_caminar * delta

	# En modo pacífico, solo camina y se detiene al llegar al borde
	if modo_pacifico:
		if global_position.x <= limite_pacifico_x:
			velocity.x = 0
			if not pacifico_detenido:
				pacifico_detenido = true
				_on_pacifico_detenido()
		return

	if walked_distance >= target_walk_distance:
		if _check_spacing():
			_change_state(State.SHOOTING)
		else:
			target_walk_distance += 0.3


func _process_dying(_delta):
	velocity.x = 0


## Override en subclases para lógica de disparo específica
func _process_shooting(_delta):
	velocity.x = 0


static var _cached_wave_spawner: Node = null
static var active_enemies_cache: Array[Node] = []
static var active_shield_imps_cache: Array[Node] = []


func _get_cached_wave_spawner() -> Node:
	if is_instance_valid(_cached_wave_spawner):
		return _cached_wave_spawner

	if get_tree() == null:
		return null

	_cached_wave_spawner = get_tree().get_first_node_in_group("wave_spawners")
	if _cached_wave_spawner:
		return _cached_wave_spawner

	var scene_root = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)

	var wave_spawner = scene_root.find_child("WaveSpawner", true, false)
	if wave_spawner:
		_cached_wave_spawner = wave_spawner
	return _cached_wave_spawner


func _check_spacing() -> bool:
	# Intentar obtener listas cacheadas del WaveSpawner para mayor rendimiento
	var enemies = []
	var shield_imps = []

	var wave_spawner = _get_cached_wave_spawner()
	if wave_spawner and wave_spawner.has_method("get_active_enemies"):
		enemies = wave_spawner.get_active_enemies()
		shield_imps = wave_spawner.get_active_shield_imps()
	else:
		# Fallback: Usar arrays estáticos O(1) si no existe WaveSpawner
		enemies = active_enemies_cache
		shield_imps = active_shield_imps_cache

	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy):
			continue
		if enemy.current_state == State.SHOOTING:
			var dist = abs(global_position.x - enemy.global_position.x)
			if dist < distancia_minima_entre_enemigos:
				return false

	# Verificar distancia a ImpShieldGirls posicionadas
	for si in shield_imps:
		if not is_instance_valid(si) or si == self:
			continue
		if si.current_state == si.State.DEFENDING or si.current_state == si.State.SHIELD_HIT:
			var dist = abs(global_position.x - si.global_position.x)
			if dist < distancia_minima_entre_enemigos:
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CAMBIO DE ESTADO (override parcial en subclases)
# ═══════════════════════════════════════════════════════════════════════════════


func _change_state(new_state: State):
	current_state = new_state

	match new_state:
		State.WALKING:
			_on_state_walking()
		State.SHOOTING:
			_on_state_shooting()
		State.DYING:
			_on_state_dying()
		State.DEAD:
			_cleanup_all_materials()
			queue_free()


## Hooks para subclases
func _on_state_walking():
	# Virtual method: override in subclasses to handle walking state transitions.
	pass


func _on_state_shooting():
	# Virtual method: override in subclasses to handle shooting state transitions.
	pass


func _on_state_dying():
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMACIÓN
# ═══════════════════════════════════════════════════════════════════════════════


func _play_animation(anim_name: String, custom_blend: float = -1.0, speed: float = 1.0):
	if not anim_player:
		return

	var possible_names = [anim_name, "Armature|" + anim_name, "Armature|Armature|" + anim_name]
	for possible_anim in possible_names:
		if anim_player.has_animation(possible_anim):
			anim_player.play(possible_anim, custom_blend, speed)
			return


func _get_animation_duration(anim_name: String) -> float:
	if not anim_player:
		return 2.0

	var possible_names = [anim_name, "Armature|" + anim_name, "Armature|Armature|" + anim_name]
	for possible_anim in possible_names:
		if anim_player.has_animation(possible_anim):
			return anim_player.get_animation(possible_anim).length

	return 2.0


# ═══════════════════════════════════════════════════════════════════════════════
# DAÑO Y MUERTE
# ═══════════════════════════════════════════════════════════════════════════════


func take_damage(amount: float):
	if current_state == State.DYING or current_state == State.DEAD:
		return

	if modo_pacifico:
		pacifico_danado.emit()

	health -= int(amount)

	if has_node("/root/GameFeel"):
		if game_feel:
			game_feel.on_enemy_hurt()

	if health <= 0:
		if has_node("/root/GameFeel"):
			if game_feel:
				game_feel.on_enemy_death()
		_change_state(State.DYING)
		died.emit()


func _flash_red():
	for mesh in _cached_mesh_instances:
		if not is_instance_valid(mesh):
			continue
		for i in range(mesh.get_surface_override_material_count()):
			mesh.set_surface_override_material(i, _red_flash_material)
		if mesh.get_surface_override_material_count() == 0:
			mesh.material_override = _red_flash_material

	get_tree().create_timer(0.08).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_reset_materials()
	)


func _reset_materials():
	# Restaurar los materiales originales guardados en _store_original_materials()
	for item in original_materials:
		if is_instance_valid(item["mesh"]):
			item["mesh"].set_surface_override_material(item["index"], item["material"])


## Limpia TODOS los materiales del nodo y sus hijos antes de queue_free()
## para evitar errores "Parameter 'material' is null" del RenderingServer.
func _exit_tree():
	active_enemies_cache.erase(self)


func _cleanup_all_materials():
	for mesh in _cached_mesh_instances:
		if is_instance_valid(mesh):
			mesh.material_override = null
			if mesh.mesh:
				for si in range(mesh.mesh.get_surface_count()):
					mesh.set_surface_override_material(si, null)
			mesh.visible = false

	# Detener todas las partículas y limpiar sus materiales de draw_pass
	for p in _cached_particles:
		if is_instance_valid(p):
			p.emitting = false
			if p.draw_pass_1 and p.draw_pass_1 is Mesh:
				p.draw_pass_1.material = null
			p.draw_pass_1 = null

	dissolve_materials.clear()
	original_materials.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# TRACKING DEL JUGADOR (Rotación de torso)
# ═══════════════════════════════════════════════════════════════════════════════


func _track_player():
	if not skeleton or spine_bone_idx == -1 or not player_ref:
		return
	if not is_instance_valid(player_ref) or not player_ref.is_inside_tree():
		return
	if not is_inside_tree():
		return

	var my_pos = global_position + Vector3(0, 0.5, 0)
	var target_pos = player_ref.global_position + Vector3(0, 0.8, 0)
	var direction = (target_pos - my_pos).normalized()

	var pitch_angle = -asin(clamp(direction.y, -1.0, 1.0))
	pitch_angle = clamp(
		pitch_angle, deg_to_rad(angulo_apuntado_minimo), deg_to_rad(angulo_apuntado_maximo)
	)

	skeleton.set_bone_global_pose_override(spine_bone_idx, Transform3D.IDENTITY, 0.0, false)
	var current_pose = skeleton.get_bone_global_pose(spine_bone_idx)

	var pitch_rotation = Quaternion(Vector3.FORWARD, pitch_angle)
	var new_basis = current_pose.basis * Basis(pitch_rotation)

	skeleton.set_bone_global_pose_override(
		spine_bone_idx, Transform3D(new_basis, current_pose.origin), 1.0, false
	)


func _reset_spine_rotation():
	if skeleton and spine_bone_idx != -1:
		skeleton.set_bone_global_pose_override(spine_bone_idx, Transform3D.IDENTITY, 0.0, false)


# ═══════════════════════════════════════════════════════════════════════════════
# DISOLUCIÓN Y MUERTE
# ═══════════════════════════════════════════════════════════════════════════════


func _die():
	for child in get_children():
		if child is Area3D and child.name.contains("Arrow"):
			child.queue_free()

	_start_dissolve_effect()


func _start_dissolve_effect():
	if is_dissolving:
		return
	is_dissolving = true

	for mesh in _cached_mesh_instances:
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

	_create_dissolve_particles()

	get_tree().create_timer(duracion_disolucion * particulas_detener_emision).timeout.connect(
		func():
			if (
				dissolve_particles
				and is_instance_valid(dissolve_particles)
				and is_instance_valid(self)
			):
				dissolve_particles.emitting = false
	)

	var tween = create_tween()
	tween.tween_method(_update_dissolve, 0.0, 1.0, duracion_disolucion)
	tween.tween_callback(_finish_dissolve)


func _update_dissolve(value: float):
	for item in dissolve_materials:
		if is_instance_valid(item["mesh"]):
			item["material"].set_shader_parameter("dissolve_amount", value)


func _finish_dissolve():
	# Limpiar materiales de TODOS los meshes antes de queue_free
	# para evitar "Parameter 'material' is null" en el RenderingServer
	for item in dissolve_materials:
		if is_instance_valid(item["mesh"]):
			item["mesh"].material_override = null
			if item["mesh"].mesh:
				for si in range(item["mesh"].mesh.get_surface_count()):
					item["mesh"].set_surface_override_material(si, null)
			item["mesh"].visible = false

	var particles_node = get_node_or_null("DissolveParticles")
	if particles_node:
		var global_pos = particles_node.global_position
		remove_child(particles_node)
		get_tree().root.add_child(particles_node)
		particles_node.global_position = global_pos
		particles_node.emitting = false
		get_tree().create_timer(particulas_vida + 0.5).timeout.connect(
			func():
				if is_instance_valid(particles_node) and particles_node.is_inside_tree():
					particles_node.queue_free()
		)

	current_state = State.DEAD
	_cleanup_all_materials()
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
	process_mat.scale_min = particulas_escala_min * 0.5
	process_mat.scale_max = particulas_escala_max * 0.5

	var gradient = Gradient.new()
	gradient.set_color(0, color_borde_disolucion)
	gradient.set_color(
		1, Color(color_borde_disolucion.r, color_borde_disolucion.g, color_borde_disolucion.b, 0.0)
	)
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
	part_mat.albedo_color = color_borde_disolucion
	part_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	part_mat.emission_enabled = true
	part_mat.emission = color_borde_disolucion
	part_mat.emission_energy_multiplier = intensidad_emision * 0.5
	part_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = part_mat

	particles.draw_pass_1 = sphere

	add_child(particles)
	# Posicionar en el centro del cuerpo (hueso Hips) en vez de offset fijo
	var bone_pos = _get_hips_global_position()
	if bone_pos != Vector3.ZERO:
		particles.global_position = bone_pos
	else:
		particles.position = particulas_posicion
	particles.emitting = true
	dissolve_particles = particles
