extends CharacterBody3D
class_name EnemyBase

## Clase base para todos los enemigos.
## Contiene la lógica compartida: vida, disolución, flash de daño,
## tracking de jugador, partículas, espaciado, etc.
## Los enemigos concretos (Goblin, GoblinGirl) heredan de esta clase.

# === CONFIGURACIÓN - MOVIMIENTO ===
@export_category("Movimiento")
@export var velocidad_caminar: float = 1.0
@export var distancia_minima_caminar: float = 1.0
@export var distancia_maxima_caminar: float = 6.0

# === CONFIGURACIÓN - COMBATE ===
@export_category("Combate")
@export var vida_maxima: int = 2
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
@export var particulas_cantidad: int = 100
@export var particulas_vida: float = 2.0
@export var particulas_posicion: Vector3 = Vector3(-0.5, 0.1, 0)
@export var particulas_caja: Vector3 = Vector3(0.2, 0.5, 0.1)
@export var particulas_dispersion: float = 20.0
@export var particulas_velocidad_min: float = 0.1
@export var particulas_velocidad_max: float = 1.0
@export var particulas_gravedad: Vector3 = Vector3(0, 0.1, 0)
@export var particulas_escala_min: float = 0.01
@export var particulas_escala_max: float = 0.03
@export_range(0.0, 1.0, 0.1) var particulas_detener_emision: float = 0.7

# === REFERENCIAS ===
var anim_player: AnimationPlayer
var player_ref: Node3D = null
var skeleton: Skeleton3D = null
var spine_bone_idx: int = -1

# === ESTADO ===
enum State {WALKING, SHOOTING, DYING, DEAD}
var current_state: State = State.WALKING
var health: int = 2
var walked_distance: float = 0.0
var target_walk_distance: float = 0.0
var shoot_timer: float = 0.0
var original_materials: Array = []

# === EFECTO DE DISOLUCIÓN ===
var dissolve_shader = preload("res://Assets/Shaders/dissolve.gdshader")
var is_dissolving: bool = false
var dissolve_materials: Array = []
var dissolve_particles: GPUParticles3D = null

# === SEÑALES ===
signal died

# ═══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ═══════════════════════════════════════════════════════════════════════════════

func _ready():
	add_to_group("enemies")
	health = vida_maxima
	target_walk_distance = randf_range(distancia_minima_caminar, distancia_maxima_caminar)

	_desactivar_bones_fisicos()
	_buscar_animation_player()
	_store_original_materials()
	_buscar_skeleton()
	_buscar_jugador()
	_on_enemy_ready() # Hook para subclases

func _desactivar_bones_fisicos():
	var bone_simulator = find_child("PhysicalBoneSimulat*", true, false)
	if bone_simulator and bone_simulator is PhysicalBoneSimulator3D:
		bone_simulator.physical_bones_stop_simulation()
		for child in bone_simulator.get_children():
			if child is PhysicalBone3D:
				child.set_physics_process(false)

func _buscar_animation_player():
	anim_player = find_child("AnimationPlayer", true, false)
	if anim_player:
		for anim_name in anim_player.get_animation_list():
			if "CORRER" in anim_name or "CAMINAR" in anim_name or "CAMINA" in anim_name \
				or "RUN" in anim_name or "WALK" in anim_name:
				var anim = anim_player.get_animation(anim_name)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR

func _buscar_skeleton():
	skeleton = find_child("Skeleton3D", true, false)
	if skeleton:
		spine_bone_idx = skeleton.find_bone("mixamorig_Spine1")
		if spine_bone_idx == -1:
			spine_bone_idx = skeleton.find_bone("mixamorig_Spine")

func _buscar_jugador():
	await get_tree().process_frame
	player_ref = get_tree().get_first_node_in_group("player")

## Hook para que las subclases ejecuten lógica adicional en _ready()
func _on_enemy_ready():
	pass

# ═══════════════════════════════════════════════════════════════════════════════
# MATERIALES
# ═══════════════════════════════════════════════════════════════════════════════

func _store_original_materials():
	var mesh_instances = find_children("*", "MeshInstance3D", true, false)
	for mesh in mesh_instances:
		if mesh.get_surface_override_material_count() > 0:
			for i in range(mesh.get_surface_override_material_count()):
				original_materials.append({
					"mesh": mesh,
					"index": i,
					"material": mesh.get_surface_override_material(i)
				})

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

func _check_spacing() -> bool:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy):
			continue
		if enemy.current_state == State.SHOOTING:
			var dist = abs(global_position.x - enemy.global_position.x)
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
			queue_free()

## Hooks para subclases
func _on_state_walking():
	pass

func _on_state_shooting():
	pass

func _on_state_dying():
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

# ═══════════════════════════════════════════════════════════════════════════════
# ANIMACIÓN
# ═══════════════════════════════════════════════════════════════════════════════

func _play_animation(anim_name: String):
	if not anim_player:
		return

	var possible_names = [anim_name, "Armature|" + anim_name]
	for possible_anim in possible_names:
		if anim_player.has_animation(possible_anim):
			anim_player.play(possible_anim)
			return

func _get_animation_duration(anim_name: String) -> float:
	if not anim_player:
		return 2.0

	var possible_names = [anim_name, "Armature|" + anim_name]
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

	health -= int(amount)
	_flash_red()

	if has_node("/root/GameFeel"):
		get_node("/root/GameFeel").on_enemy_hurt()

	if health <= 0:
		if has_node("/root/GameFeel"):
			get_node("/root/GameFeel").on_enemy_death()
		_change_state(State.DYING)
		died.emit()

func _flash_red():
	var red_material = StandardMaterial3D.new()
	red_material.albedo_color = Color(1, 0, 0)
	red_material.emission_enabled = true
	red_material.emission = Color(1, 0, 0)
	red_material.emission_energy_multiplier = 2.0

	var mesh_instances = find_children("*", "MeshInstance3D", true, false)
	for mesh in mesh_instances:
		for i in range(mesh.get_surface_override_material_count()):
			mesh.set_surface_override_material(i, red_material)
		if mesh.get_surface_override_material_count() == 0:
			mesh.material_override = red_material

	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_reset_materials()
	)

func _reset_materials():
	var mesh_instances = find_children("*", "MeshInstance3D", true, false)
	for mesh in mesh_instances:
		mesh.material_override = null
		for i in range(mesh.get_surface_override_material_count()):
			mesh.set_surface_override_material(i, null)

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
	pitch_angle = clamp(pitch_angle, deg_to_rad(angulo_apuntado_minimo), deg_to_rad(angulo_apuntado_maximo))

	skeleton.set_bone_global_pose_override(spine_bone_idx, Transform3D.IDENTITY, 0.0, false)
	var current_pose = skeleton.get_bone_global_pose(spine_bone_idx)

	var pitch_rotation = Quaternion(Vector3.FORWARD, pitch_angle)
	var new_basis = current_pose.basis * Basis(pitch_rotation)

	skeleton.set_bone_global_pose_override(spine_bone_idx, Transform3D(new_basis, current_pose.origin), 1.0, false)

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

	var mesh_instances = find_children("*", "MeshInstance3D", true, false)
	for mesh in mesh_instances:
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

	get_tree().create_timer(duracion_disolucion * particulas_detener_emision).timeout.connect(func():
		if dissolve_particles and is_instance_valid(dissolve_particles) and is_instance_valid(self):
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
	var particles_node = get_node_or_null("DissolveParticles")
	if particles_node:
		var global_pos = particles_node.global_position
		remove_child(particles_node)
		get_tree().root.add_child(particles_node)
		particles_node.global_position = global_pos
		particles_node.emitting = false
		get_tree().create_timer(particulas_vida + 0.5).timeout.connect(func():
			if is_instance_valid(particles_node) and particles_node.is_inside_tree():
				particles_node.queue_free()
		)

	current_state = State.DEAD
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

	var gradient = Gradient.new()
	gradient.set_color(0, color_borde_disolucion)
	gradient.set_color(1, Color(color_borde_disolucion.r, color_borde_disolucion.g, color_borde_disolucion.b, 0.0))
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
	particles.position = particulas_posicion

	add_child(particles)
	particles.emitting = true
	dissolve_particles = particles
