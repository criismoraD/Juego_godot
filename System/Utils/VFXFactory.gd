class_name VFXFactory
extends Node
# ═══════════════════════════════════════════════════════════════════════════════
#                         VFX FACTORY
# ═══════════════════════════════════════════════════════════════════════════════
# Fábrica de efectos visuales procedurales para Game Feel.
# Crea partículas, trails, y efectos sin necesidad de escenas pre-hechas.
#
# USO: VFXFactory.spawn_impact(position, Color.RED)
# ═══════════════════════════════════════════════════════════════════════════════


static func _desactivar_sombra_particula(particles: GPUParticles3D) -> void:
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN GLOBAL
# ═══════════════════════════════════════════════════════════════════════════════

## Multiplicador global de cantidad de partículas (para ajustar rendimiento)
static var particle_amount_multiplier: float = 0.4

## Activar/desactivar VFX globalmente
static var vfx_enabled: bool = true

## Mostrar logs de diagnóstico de la fábrica de VFX
static var debug_logs_enabled: bool = false

# === OPTIMIZACIÓN: Caché de materiales compartidos ===
static var _mat_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}


static func _get_shared_material(
	color: Color, emission: bool = false, emission_energy: float = 2.0, transparency: bool = false
) -> StandardMaterial3D:
	var key := "%s_%s_%s_%s" % [color.to_html(), emission, emission_energy, transparency]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_energy
	if transparency:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = mat
	return mat


static func _get_shared_mesh(radius: float = 0.0125, height: float = 0.025) -> SphereMesh:
	var key := "%s_%s" % [radius, height]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	_mesh_cache[key] = mesh
	return mesh


# ═══════════════════════════════════════════════════════════════════════════════
# WARM-UP DE SHADERS (evita stutter en la primera aparición de partículas)
# ═══════════════════════════════════════════════════════════════════════════════


## Crea partículas invisibles fuera de cámara para forzar la compilación
## de shaders de GPU al inicio. Llamar una vez desde _ready() del nivel.
static func warmup_shaders(world: Node) -> void:
	# Posición fuera de vista (muy lejos y abajo)
	var hidden_pos := Vector3(0, -1000, 0)

	# Crear una partícula de cada tipo para compilar sus shaders
	var types: Array[Callable] = [
		func(): return spawn_impact(world, hidden_pos),
		func(): return spawn_muzzle_flash(world, hidden_pos, Vector3.UP),
		func(): return spawn_blood(world, hidden_pos),
		func(): return spawn_dust(world, hidden_pos),
		func(): return spawn_jump(world, hidden_pos),
		func(): return spawn_landing(world, hidden_pos),
		func(): return spawn_death_explosion(world, hidden_pos),
		func(): return spawn_sparks(world, hidden_pos),
	]

	for creator in types:
		var p = creator.call()
		if p and is_instance_valid(p):
			# Emitir un solo frame y destruir inmediatamente tras terminar
			p.emitting = true

	if debug_logs_enabled:
		print("[VFXFactory] Shader warm-up completado (%d tipos)" % types.size())


# ═══════════════════════════════════════════════════════════════════════════════
# EFECTOS DE IMPACTO
# ═══════════════════════════════════════════════════════════════════════════════


## Crear partículas de impacto (cuando la flecha golpea algo)
static func spawn_impact(
	world: Node,
	position: Vector3,
	color: Color = Color.WHITE,
	amount: int = 15,
	size: float = 0.0125
) -> GPUParticles3D:
	if not vfx_enabled:
		return null

	var particles = GPUParticles3D.new()
	particles.name = "ImpactVFX"
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = int(amount * particle_amount_multiplier)
	particles.lifetime = 0.4
	_desactivar_sombra_particula(particles)

	# Material de proceso
	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 0.1
	process_mat.direction = Vector3(0, 0, 0)
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 2.0
	process_mat.initial_velocity_max = 5.0
	process_mat.gravity = Vector3(0, -8, 0)
	process_mat.damping_min = 2.0
	process_mat.damping_max = 4.0
	process_mat.scale_min = size * 0.5
	process_mat.scale_max = size

	# Color con fade out
	var gradient = Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	particles.process_material = process_mat

	# Mesh compartido
	var mesh = _get_shared_mesh()
	mesh.material = _get_shared_material(color, true, 2.0, false)

	particles.draw_pass_1 = mesh

	world.add_child(particles)
	particles.global_position = position
	particles.emitting = true

	# Auto-destruir después de terminar
	particles.finished.connect(func(): particles.queue_free())

	return particles


## Crear partículas de disparo (cuando el jugador o enemigo dispara)
static func spawn_muzzle_flash(
	world: Node, position: Vector3, direction: Vector3, color: Color = Color(1.0, 0.7, 0.0)
) -> GPUParticles3D:  # Amarillo incandescente
	if not vfx_enabled:
		return null

	var particles = GPUParticles3D.new()
	particles.name = "MuzzleFlashVFX"
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = int(8 * particle_amount_multiplier)
	particles.lifetime = 0.15
	_desactivar_sombra_particula(particles)

	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process_mat.direction = direction
	process_mat.spread = 25.0
	process_mat.initial_velocity_min = 3.0
	process_mat.initial_velocity_max = 6.0
	process_mat.gravity = Vector3.ZERO
	process_mat.scale_min = 0.00625
	process_mat.scale_max = 0.0125

	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.9, 0.3, 1.0))  # Amarillo brillante incandescente
	gradient.set_color(1, Color(1.0, 0.5, 0.0, 0.0))  # Naranja que se desvanece
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	particles.process_material = process_mat

	# Mesh compartido
	var mesh = _get_shared_mesh()
	mesh.material = _get_shared_material(color, true, 5.0, true)

	particles.draw_pass_1 = mesh

	world.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	particles.finished.connect(func(): particles.queue_free())

	return particles


## Crear partículas de sangre/daño
static func spawn_blood(
	world: Node,
	position: Vector3,
	direction: Vector3 = Vector3.LEFT,
	color: Color = Color(0.8, 0.1, 0.1)
) -> GPUParticles3D:
	if not vfx_enabled:
		return null

	var particles = GPUParticles3D.new()
	particles.name = "BloodVFX"
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = int(20 * particle_amount_multiplier)
	particles.lifetime = 0.6
	_desactivar_sombra_particula(particles)

	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 0.1
	process_mat.direction = direction
	process_mat.spread = 45.0
	process_mat.initial_velocity_min = 3.0
	process_mat.initial_velocity_max = 7.0
	process_mat.gravity = Vector3(0, -15, 0)
	process_mat.scale_min = 0.0075
	process_mat.scale_max = 0.015

	var gradient = Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	particles.process_material = process_mat

	# Mesh compartido
	var mesh = _get_shared_mesh()
	mesh.material = _get_shared_material(color, false, 0.0, false)

	particles.draw_pass_1 = mesh

	world.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	particles.finished.connect(func(): particles.queue_free())

	return particles


# ═══════════════════════════════════════════════════════════════════════════════
# EFECTOS DE MOVIMIENTO
# ═══════════════════════════════════════════════════════════════════════════════


## Crear partículas de polvo al correr/aterrizar
static func spawn_dust(
	world: Node, position: Vector3, color: Color = Color(0.6, 0.5, 0.4, 0.7)
) -> GPUParticles3D:
	if not vfx_enabled:
		return null

	var particles = GPUParticles3D.new()
	particles.name = "DustVFX"
	particles.one_shot = true
	particles.explosiveness = 0.7
	particles.amount = int(12 * particle_amount_multiplier)
	particles.lifetime = 0.5
	_desactivar_sombra_particula(particles)

	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(0.2, 0.05, 0.1)
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 60.0
	process_mat.initial_velocity_min = 0.5
	process_mat.initial_velocity_max = 1.5
	process_mat.gravity = Vector3(0, -1, 0)
	process_mat.scale_min = 0.01875
	process_mat.scale_max = 0.0375

	var gradient = Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	particles.process_material = process_mat

	# Mesh compartido
	var mesh = _get_shared_mesh()
	mesh.material = _get_shared_material(color, false, 0.0, true)

	particles.draw_pass_1 = mesh

	world.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	particles.finished.connect(func(): particles.queue_free())

	return particles


## Crear partículas de salto
## Parámetros configurables: color, escala_min, escala_max
static func spawn_jump(
	world: Node,
	position: Vector3,
	color: Color = Color(0.7, 0.65, 0.5, 0.5),
	scale_min: float = 0.0125,
	scale_max: float = 0.0375
) -> GPUParticles3D:
	if not vfx_enabled:
		return null

	var particles = GPUParticles3D.new()
	particles.name = "JumpVFX"
	particles.one_shot = true
	particles.explosiveness = 0.7
	particles.amount = int(12 * particle_amount_multiplier)
	particles.lifetime = 0.5
	_desactivar_sombra_particula(particles)

	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(0.2, 0.05, 0.1)
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 60.0
	process_mat.initial_velocity_min = 0.5
	process_mat.initial_velocity_max = 1.5
	process_mat.gravity = Vector3(0, -1, 0)
	process_mat.scale_min = scale_min
	process_mat.scale_max = scale_max

	var gradient = Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	particles.process_material = process_mat

	# Mesh compartido
	var mesh = _get_shared_mesh()
	mesh.material = _get_shared_material(color, false, 0.0, true)

	particles.draw_pass_1 = mesh

	world.add_child(particles)
	particles.global_position = position + Vector3(0, 0.1, 0)
	particles.emitting = true
	particles.finished.connect(func(): particles.queue_free())

	return particles


## Crear partículas de aterrizaje (más intensas)
static func spawn_landing(world: Node, position: Vector3, intensity: float = 1.0) -> GPUParticles3D:
	if not vfx_enabled:
		return null

	var particles = GPUParticles3D.new()
	particles.name = "LandingVFX"
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = int(20 * intensity * particle_amount_multiplier)
	particles.lifetime = 0.6
	_desactivar_sombra_particula(particles)

	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process_mat.emission_ring_axis = Vector3(0, 1, 0)
	process_mat.emission_ring_height = 0.1
	process_mat.emission_ring_radius = 0.3
	process_mat.emission_ring_inner_radius = 0.1
	process_mat.direction = Vector3(0, 0.3, 0)
	process_mat.spread = 80.0
	process_mat.initial_velocity_min = 1.0 * intensity
	process_mat.initial_velocity_max = 3.0 * intensity
	process_mat.gravity = Vector3(0, -3, 0)
	process_mat.scale_min = 0.0125
	process_mat.scale_max = 0.025

	var color = Color(0.6, 0.55, 0.45, 0.6)
	var gradient = Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	particles.process_material = process_mat

	# Mesh compartido
	var mesh = _get_shared_mesh()
	mesh.material = _get_shared_material(color, false, 0.0, true)

	particles.draw_pass_1 = mesh

	world.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	particles.finished.connect(func(): particles.queue_free())

	return particles


# ═══════════════════════════════════════════════════════════════════════════════
# EFECTOS ESPECIALES
# ═══════════════════════════════════════════════════════════════════════════════


## Crear explosión de partículas (para muertes)
static func spawn_death_explosion(
	world: Node, position: Vector3, color: Color = Color(1.0, 0.6, 0.2)
) -> GPUParticles3D:
	if not vfx_enabled:
		return null

	var particles = GPUParticles3D.new()
	particles.name = "DeathExplosionVFX"
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = int(50 * particle_amount_multiplier)
	particles.lifetime = 1.0
	_desactivar_sombra_particula(particles)

	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 0.2
	process_mat.direction = Vector3(0, 0, 0)
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 3.0
	process_mat.initial_velocity_max = 8.0
	process_mat.gravity = Vector3(0, -5, 0)
	process_mat.damping_min = 1.0
	process_mat.damping_max = 3.0
	process_mat.scale_min = 0.01
	process_mat.scale_max = 0.02

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 0.8, 1.0))  # Centro brillante
	gradient.add_point(0.3, color)
	gradient.add_point(1.0, Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	particles.process_material = process_mat

	# Mesh compartido con emisión
	var mesh = _get_shared_mesh()
	mesh.material = _get_shared_material(color, true, 3.0, true)

	particles.draw_pass_1 = mesh

	world.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	particles.finished.connect(func(): particles.queue_free())

	return particles


## Crear chispas (para impactos contra metal/escudo)
static func spawn_sparks(
	world: Node,
	position: Vector3,
	direction: Vector3 = Vector3.UP,
	color: Color = Color(1.0, 0.9, 0.5)
) -> GPUParticles3D:
	if not vfx_enabled:
		return null

	var particles = GPUParticles3D.new()
	particles.name = "SparksVFX"
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = int(25 * particle_amount_multiplier)
	particles.lifetime = 0.4
	_desactivar_sombra_particula(particles)

	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process_mat.direction = direction
	process_mat.spread = 50.0
	process_mat.initial_velocity_min = 5.0
	process_mat.initial_velocity_max = 12.0
	process_mat.gravity = Vector3(0, -15, 0)
	process_mat.scale_min = 0.00375
	process_mat.scale_max = 0.0075

	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(color.r, color.g * 0.5, 0.0, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	particles.process_material = process_mat

	# Usar BoxMesh alargado para chispas — crear uno compartido
	var spark_key := "spark_box"
	if not _mesh_cache.has(spark_key):
		var spark_mesh := BoxMesh.new()
		spark_mesh.size = Vector3(0.01, 0.05, 0.01)
		_mesh_cache[spark_key] = spark_mesh
	var mesh: BoxMesh = _mesh_cache[spark_key]
	mesh.material = _get_shared_material(color, true, 5.0, false)

	particles.draw_pass_1 = mesh

	world.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	particles.finished.connect(func(): particles.queue_free())

	return particles


## Crear estela de flecha (trail continuo)
static func create_arrow_trail(
	arrow: Node3D, color: Color = Color(0.8, 0.9, 1.0, 0.5)
) -> GPUParticles3D:
	if not vfx_enabled:
		return null

	var particles = GPUParticles3D.new()
	particles.name = "ArrowTrailVFX"
	particles.emitting = true
	particles.one_shot = false
	particles.amount = int(20 * particle_amount_multiplier)
	particles.lifetime = 0.3
	particles.preprocess = 0.0
	_desactivar_sombra_particula(particles)

	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process_mat.direction = Vector3(0, 0, 0)
	process_mat.spread = 5.0
	process_mat.initial_velocity_min = 0.0
	process_mat.initial_velocity_max = 0.1
	process_mat.gravity = Vector3.ZERO
	process_mat.scale_min = 0.0025
	process_mat.scale_max = 0.005

	var gradient = Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
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

	particles.process_material = process_mat

	# Mesh compartido
	var mesh = _get_shared_mesh()
	mesh.material = _get_shared_material(color, false, 0.0, true)

	particles.draw_pass_1 = mesh

	arrow.add_child(particles)

	return particles


const TEXTURA_MANCHA_SANGRE: String = "res://Entities/Enemigo_Goblin/Muerte_Explotado/Mancha_Sangre_Suelo.png"

## Alinea la orientación y posición de un MeshInstance3D (QuadMesh) exactamente
## a la normal de la superficie impactada (suelos planos, rampas inclinadas o plataformas).
static func align_decal_to_surface(
	mesh_inst: MeshInstance3D,
	pos: Vector3,
	normal: Vector3,
	offset_dist: float = 0.015,
	rotacion_plana: float = 0.0
) -> void:
	var n := normal.normalized()
	if n.length_squared() < 0.001:
		n = Vector3.UP

	# Vector de referencia "arriba" en el plano 2.5D
	var up_hint := Vector3.FORWARD
	if absf(n.dot(up_hint)) > 0.95:
		up_hint = Vector3.RIGHT

	var x_axis := up_hint.cross(n).normalized()
	var y_axis := n.cross(x_axis).normalized()
	var b := Basis(x_axis, y_axis, n)

	if rotacion_plana != 0.0:
		b = b.rotated(n, rotacion_plana)

	mesh_inst.global_transform = Transform3D(b, pos + n * offset_dist)


## Crea una mancha de sangre en el suelo tras una explosión (Goblin/Imp/Cañonero).
## Detecta el suelo/rampa mediante raycast, se alinea a su inclinación y se desvanece suavemente.
static func spawn_ground_blood_splatter(
	source_node: Node,
	pos: Vector3,
	color_modulate: Color = Color(1.0, 1.0, 1.0, 0.95),
	tamano: Vector2 = Vector2(1.35, 1.35),
	tiempo_vida: float = 3.5,
	tiempo_desvanecimiento: float = 2.5
) -> MeshInstance3D:
	if not is_instance_valid(source_node) or not source_node.is_inside_tree():
		return null

	var tree := source_node.get_tree()
	var root := tree.current_scene if tree else null
	if not root:
		root = tree.root if tree else null
	if not root:
		return null

	var floor_pos := Vector3(pos.x, 0.0, pos.z)
	var floor_normal := Vector3.UP
	var world_3d: World3D = null
	if source_node is Node3D:
		world_3d = (source_node as Node3D).get_world_3d()

	if world_3d and world_3d.direct_space_state:
		var query := PhysicsRayQueryParameters3D.create(pos + Vector3(0.0, 0.5, 0.0), pos + Vector3(0.0, -6.0, 0.0))
		query.collision_mask = 65  # Capa 1 (Mundo) y Capa 7 (Plataformas/Rampas)
		var hit := world_3d.direct_space_state.intersect_ray(query)
		if hit and hit.has("position"):
			floor_pos = hit.position
			if hit.has("normal") and hit.normal.length_squared() > 0.001:
				floor_normal = hit.normal

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "ManchaSangreSuelo"
	var quad := QuadMesh.new()
	var escala_aleatoria := randf_range(0.9, 1.2)
	quad.size = tamano * escala_aleatoria
	mesh_inst.mesh = quad

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color_modulate
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = -2

	if ResourceLoader.exists(TEXTURA_MANCHA_SANGRE):
		mat.albedo_texture = load(TEXTURA_MANCHA_SANGRE)

	mesh_inst.material_override = mat

	root.add_child(mesh_inst)
	align_decal_to_surface(mesh_inst, floor_pos, floor_normal, 0.015, randf_range(0.0, TAU))

	var tween := mesh_inst.create_tween()
	tween.tween_interval(tiempo_vida)
	tween.tween_property(mat, "albedo_color:a", 0.0, tiempo_desvanecimiento) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if is_instance_valid(mesh_inst):
			mesh_inst.queue_free()
	)

	return mesh_inst


const TEXTURA_HUMO_SALTO_DEFENSORA: String = "res://TEST_/SmokeFX Lite SpriteSheet 2A-2.png"

## Crea la animación de humo de salto de la defensora expandiéndose a ambos lados
## cuando se rompe un escudo enemigo.
static func spawn_shield_break_smoke(source_node: Node, pos: Vector3) -> void:
	if not is_instance_valid(source_node) or not source_node.is_inside_tree():
		return

	var tree := source_node.get_tree()
	var root := tree.current_scene if tree else null
	if not root:
		root = tree.root if tree else null
	if not root:
		return

	var floor_pos := Vector3(pos.x, 0.0, pos.z)
	var world_3d: World3D = null
	if source_node is Node3D:
		world_3d = (source_node as Node3D).get_world_3d()

	if world_3d and world_3d.direct_space_state:
		var query := PhysicsRayQueryParameters3D.create(pos + Vector3(0.0, 0.5, 0.0), pos + Vector3(0.0, -6.0, 0.0))
		query.collision_mask = 1  # Capa de suelo
		var hit := world_3d.direct_space_state.intersect_ray(query)
		if hit and hit.has("position"):
			floor_pos = hit.position

	var tex: Texture2D = null
	if ResourceLoader.exists(TEXTURA_HUMO_SALTO_DEFENSORA):
		tex = load(TEXTURA_HUMO_SALTO_DEFENSORA)
	if not tex:
		return

	for side in [-1, 1]:
		var puf := GPUParticles3D.new()
		puf.name = "HumoEscudoRoto"
		puf.amount = 4
		puf.lifetime = 0.75
		puf.one_shot = true
		puf.explosiveness = 0.3
		puf.randomness = 0.3
		puf.visibility_aabb = AABB(Vector3(-1.5, -1.2, -1.5), Vector3(3, 3, 3))

		var pmat := ParticleProcessMaterial.new()
		pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		pmat.direction = Vector3(side * 0.85, 0.35, 0.0)
		pmat.spread = 20.0
		pmat.initial_velocity_min = 0.8
		pmat.initial_velocity_max = 1.6
		pmat.gravity = Vector3(0, -0.3, 0)
		pmat.scale_min = 0.55
		pmat.scale_max = 0.85
		pmat.anim_speed_min = 1.0
		pmat.anim_speed_max = 1.2
		pmat.anim_offset_min = 0.0
		pmat.anim_offset_max = 0.25

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
		mat.albedo_texture = tex
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
		puf.global_position = floor_pos + Vector3(side * 0.25, 0.04, 0.0)
		puf.emitting = true

		tree.create_timer(1.2, false).timeout.connect(func():
			if is_instance_valid(puf):
				puf.queue_free()
		)


