# ═══════════════════════════════════════════════════════════════════════════════
#                         VFX FACTORY
# ═══════════════════════════════════════════════════════════════════════════════
# Fábrica de efectos visuales procedurales para Game Feel.
# Crea partículas, trails, y efectos sin necesidad de escenas pre-hechas.
#
# USO: VFXFactory.spawn_impact(position, Color.RED)
# ═══════════════════════════════════════════════════════════════════════════════
extends Node
class_name VFXFactory

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN GLOBAL
# ═══════════════════════════════════════════════════════════════════════════════

## Multiplicador global de cantidad de partículas (para ajustar rendimiento)
static var particle_amount_multiplier: float = 0.4

## Activar/desactivar VFX globalmente
static var vfx_enabled: bool = true

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

	print("[VFXFactory] Shader warm-up completado (%d tipos)" % types.size())


# ═══════════════════════════════════════════════════════════════════════════════
# EFECTOS DE IMPACTO
# ═══════════════════════════════════════════════════════════════════════════════


## Crear partículas de impacto (cuando la flecha golpea algo)
static func spawn_impact(
	world: Node, position: Vector3, color: Color = Color.WHITE, amount: int = 15, size: float = 0.05
) -> GPUParticles3D:
	if not vfx_enabled:
		return null

	var particles = GPUParticles3D.new()
	particles.name = "ImpactVFX"
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = int(amount * particle_amount_multiplier)
	particles.lifetime = 0.4

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

	# Mesh (pequeñas esferas)
	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.01

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mesh.material = mat

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

	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process_mat.direction = direction
	process_mat.spread = 25.0
	process_mat.initial_velocity_min = 3.0
	process_mat.initial_velocity_max = 6.0
	process_mat.gravity = Vector3.ZERO
	process_mat.scale_min = 0.02
	process_mat.scale_max = 0.05

	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.9, 0.3, 1.0))  # Amarillo brillante incandescente
	gradient.set_color(1, Color(1.0, 0.5, 0.0, 0.0))  # Naranja que se desvanece
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	particles.process_material = process_mat

	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.01

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat

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

	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 0.1
	process_mat.direction = direction
	process_mat.spread = 45.0
	process_mat.initial_velocity_min = 3.0
	process_mat.initial_velocity_max = 7.0
	process_mat.gravity = Vector3(0, -15, 0)
	process_mat.scale_min = 0.02
	process_mat.scale_max = 0.06

	var gradient = Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	particles.process_material = process_mat

	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.01

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat

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

	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(0.2, 0.05, 0.1)
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 60.0
	process_mat.initial_velocity_min = 0.5
	process_mat.initial_velocity_max = 1.5
	process_mat.gravity = Vector3(0, -1, 0)
	process_mat.scale_min = 0.05
	process_mat.scale_max = 0.15

	var gradient = Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	particles.process_material = process_mat

	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.01

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat

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
	scale_min: float = 0.05,
	scale_max: float = 0.15
) -> GPUParticles3D:
	if not vfx_enabled:
		return null

	var particles = GPUParticles3D.new()
	particles.name = "JumpVFX"
	particles.one_shot = true
	particles.explosiveness = 0.7
	particles.amount = int(12 * particle_amount_multiplier)
	particles.lifetime = 0.5

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

	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.01

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat

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
	process_mat.scale_min = 0.03
	process_mat.scale_max = 0.1

	var color = Color(0.6, 0.55, 0.45, 0.6)
	var gradient = Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	particles.process_material = process_mat

	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.01

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat

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
	process_mat.scale_min = 0.03
	process_mat.scale_max = 0.08

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 0.8, 1.0))  # Centro brillante
	gradient.add_point(0.3, color)
	gradient.add_point(1.0, Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	particles.process_material = process_mat

	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.01

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat

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

	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process_mat.direction = direction
	process_mat.spread = 50.0
	process_mat.initial_velocity_min = 5.0
	process_mat.initial_velocity_max = 12.0
	process_mat.gravity = Vector3(0, -15, 0)
	process_mat.scale_min = 0.01
	process_mat.scale_max = 0.03

	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(color.r, color.g * 0.5, 0.0, 0.0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	particles.process_material = process_mat

	# Usar mesh alargado para simular líneas de chispa
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.01, 0.05, 0.01)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0
	mesh.material = mat

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

	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process_mat.direction = Vector3(0, 0, 0)
	process_mat.spread = 5.0
	process_mat.initial_velocity_min = 0.0
	process_mat.initial_velocity_max = 0.1
	process_mat.gravity = Vector3.ZERO
	process_mat.scale_min = 0.01
	process_mat.scale_max = 0.02

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

	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.01

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat

	particles.draw_pass_1 = mesh

	arrow.add_child(particles)

	return particles
