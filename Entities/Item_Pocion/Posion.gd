@tool
class_name Posion
extends Area3D
## Poción de vida con luz rubí parpadeante, partículas dispersas, squash & stretch procedimental.
## Se consume AUTOMÁTICAMENTE después de 3 segundos (no requiere que el jugador la toque).
## Caída con aceleración realista (EASE_IN) y frenado de golpe al tocar el suelo.

# ═══════════════════════════════════════════════════════════════════════════════
# SEÑALES Y ENUMS
# ═══════════════════════════════════════════════════════════════════════════════
@warning_ignore("unused_signal")
signal picked_up(player: Node)

enum State { IDLE, DISSOLVING }

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Curación")
@export var vida_a_restaurar: int = 1
@export var tiempo_en_pantalla: float = 3.0  ## Segundos antes de auto-consumirse
@export var tiempo_escala_spawn: float = 0.4  ## Duración del escalado orgánico (0 a 1) al aparecer

@export_category("Luz Rubí")
@export var ruby_color: Color = Color(1.0, 0.08, 0.25)
@export var light_energy_min: float = 1.0
@export var light_energy_max: float = 5.0
@export var light_flicker_speed: float = 8.0

@export_category("Squash & Stretch")
@export var float_amplitude: float = 0.05   ## Balanceo reducido 50%
@export var float_speed: float = 2.5
@export var squash_stretch_amplitude: float = 0.25

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTES
# ═══════════════════════════════════════════════════════════════════════════════
const ESCALA_BASE: float = 0.5
const SONIDO_POSION: String = "res://TEST_/Posion curativa.wav"
const SONIDO_APARECE_POCION: String = "res://TEST_/Aparece pocion.wav"

var dissolve_shader: Shader = preload("res://System/Shaders/dissolve.gdshader")

# ═══════════════════════════════════════════════════════════════════════════════
# ESTADO INTERNO
# ═══════════════════════════════════════════════════════════════════════════════
var current_state: State = State.IDLE
var _initial_model_y: float = 0.0
var _nodes_checked: bool = false
var _is_falling: bool = false

var model_root: Node3D = null
var ruby_light: OmniLight3D = null
var ruby_particles: GPUParticles3D = null

# ═══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_obtener_nodos_directos()
	
	add_to_group("pickups")
	add_to_group("pociones")

	if model_root:
		_initial_model_y = model_root.position.y
		model_root.scale = Vector3(ESCALA_BASE, ESCALA_BASE, ESCALA_BASE)
		model_root.rotation.y = 0.0

	if ruby_light:
		ruby_light.light_color = ruby_color
		ruby_light.light_energy = light_energy_min

	if not Engine.is_editor_hint():
		# Escalado orgánico de 0 a 1 al aparecer
		scale = Vector3(0.001, 0.001, 0.001)
		var spawn_tween := create_tween()
		spawn_tween.tween_property(self, "scale", Vector3.ONE, tiempo_escala_spawn) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		var sombra := SombraPersonaje.new()
		sombra.tamano = Vector2(0.25, 0.25)
		sombra.opacidad = 0.6
		sombra.altura_max_desvanecimiento = 5.0
		add_child(sombra)

		call_deferred("_comprobar_caida_al_suelo")
		_reproducir_sonido_aparece()

		# Timer de auto-consumo a los 3 segundos
		var timer := get_tree().create_timer(tiempo_en_pantalla)
		timer.timeout.connect(_auto_consumir)


func _obtener_nodos_directos() -> void:
	if not model_root:
		model_root = get_node_or_null("ModelRoot") as Node3D
	if not ruby_light:
		ruby_light = get_node_or_null("RubyLight") as OmniLight3D
	if not ruby_particles:
		ruby_particles = get_node_or_null("RubyParticles") as GPUParticles3D


func _comprobar_caida_al_suelo() -> void:
	if Engine.is_editor_hint():
		return

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.2, 0),
		global_position + Vector3(0, -25, 0))
	query.collision_mask = 1 | 64
	var result := space_state.intersect_ray(query)

	if result and result.has("position"):
		var suelo_y: float = result.position.y
		if global_position.y > suelo_y + 0.4:
			_is_falling = true
			var tween := create_tween()
			var dist: float = global_position.y - suelo_y
			# Caída con aceleración gravitacional (EASE_IN) y frenado de golpe al tocar el suelo
			var duracion: float = clamp(dist * 0.25, 0.5, 1.2)
			tween.tween_property(self, "global_position:y", suelo_y + 0.1, duracion) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.finished.connect(func(): _is_falling = false)


# ═══════════════════════════════════════════════════════════════════════════════
# PROCESO
# ═══════════════════════════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	if not _nodes_checked:
		_obtener_nodos_directos()
		_nodes_checked = true

	_bucle_parpadeo_luz()

	if current_state == State.IDLE and not _is_falling:
		_bucle_animacion_squash_and_stretch()


func _bucle_parpadeo_luz() -> void:
	if not ruby_light:
		return
	var tiempo: float = Time.get_ticks_msec() * 0.001
	var onda1: float = (sin(tiempo * light_flicker_speed) + 1.0) * 0.5
	var onda2: float = (sin(tiempo * light_flicker_speed * 2.37) + 1.0) * 0.5
	ruby_light.light_energy = lerp(light_energy_min, light_energy_max, onda1 * 0.6 + onda2 * 0.4)


func _bucle_animacion_squash_and_stretch() -> void:
	if not model_root:
		return
	var tiempo: float = Time.get_ticks_msec() * 0.001
	model_root.position.y = _initial_model_y + sin(tiempo * float_speed) * float_amplitude
	model_root.rotation.y = 0.0
	var sq: float = sin(tiempo * float_speed * 2.0) * squash_stretch_amplitude
	model_root.scale = Vector3(
		ESCALA_BASE * (1.0 - sq * 0.6),
		ESCALA_BASE * (1.0 + sq * 1.2),
		ESCALA_BASE * (1.0 - sq * 0.6))


# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-CONSUMO DESPUÉS DE 3 SEGUNDOS
# ═══════════════════════════════════════════════════════════════════════════════

func _auto_consumir() -> void:
	if current_state == State.DISSOLVING:
		return
	current_state = State.DISSOLVING

	var player: Node3D = _buscar_jugador()

	var curo: bool = false
	if is_instance_valid(player) and "health" in player and "vida_maxima" in player:
		if int(player.health) < int(player.vida_maxima):
			if player.has_method("curar"):
				player.curar(vida_a_restaurar)
			else:
				player.health = min(player.health + vida_a_restaurar, player.vida_maxima)
				if player.has_signal("health_changed"):
					player.health_changed.emit(player.health)
			curo = true

	if curo:
		_play_pickup_sound()

	_iniciar_desintegracion(1.0)


func _buscar_jugador() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node3D
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# DESINTEGRACIÓN CON SHADER
# ═══════════════════════════════════════════════════════════════════════════════

func _iniciar_desintegracion(duracion: float) -> void:
	if ruby_particles:
		ruby_particles.emitting = true

	var meshes: Array[Node] = []
	if model_root:
		meshes = model_root.find_children("*", "MeshInstance3D", true, false)
	var dissolve_mats: Array = []

	for mesh in meshes:
		if not is_instance_valid(mesh):
			continue
		var mi := mesh as MeshInstance3D
		var mat := ShaderMaterial.new()
		mat.shader = dissolve_shader
		mat.set_shader_parameter("dissolve_amount", 0.0)
		mat.set_shader_parameter("glow_color", Color(1.0, 0.08, 0.25))
		mat.set_shader_parameter("glow_intensity", 6.0)
		mat.set_shader_parameter("edge_thickness", 0.06)
		mat.set_shader_parameter("noise_scale", 20.0)

		var orig: Material = mi.material_override
		if orig == null and mi.mesh and mi.mesh.get_surface_count() > 0:
			orig = mi.mesh.surface_get_material(0)
		if orig and orig is StandardMaterial3D:
			var std := orig as StandardMaterial3D
			if std.albedo_texture:
				mat.set_shader_parameter("albedo_texture", std.albedo_texture)
			var col := std.albedo_color
			mat.set_shader_parameter("albedo_tint", Vector3(col.r, col.g, col.b))

		mi.material_override = mat
		dissolve_mats.append(mat)

	var tween := create_tween()
	tween.tween_method(
		func(val: float) -> void:
			for m in dissolve_mats:
				if is_instance_valid(m):
					m.set_shader_parameter("dissolve_amount", val),
		0.0, 1.0, duracion)

	if ruby_light:
		tween.parallel().tween_property(ruby_light, "light_energy", 0.0, duracion)

	tween.finished.connect(queue_free)


# ═══════════════════════════════════════════════════════════════════════════════
# SONIDO
# ═══════════════════════════════════════════════════════════════════════════════

func _play_pickup_sound() -> void:
	var stream := load(SONIDO_POSION) as AudioStream
	if not stream:
		return
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = 6.0
	sfx.bus = "Master"
	var root := get_tree().current_scene
	if root:
		root.add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)


func _reproducir_sonido_aparece() -> void:
	var stream := load(SONIDO_APARECE_POCION) as AudioStream
	if not stream:
		return
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = 2.0
	sfx.bus = "Master"
	var root := get_tree().current_scene
	if root:
		root.add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)
	else:
		sfx.queue_free()
