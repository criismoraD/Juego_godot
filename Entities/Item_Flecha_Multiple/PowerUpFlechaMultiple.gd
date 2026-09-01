@tool
class_name PowerUpFlechaMultiple
extends Area3D

## Power-Up de Flecha Múltiple con rotación continua 360°, luz mágica parpadeante y animación procedimental.
## Se consume al contacto del jugador (o automáticamente tras 3 segundos) otorgando un stack de 20 municiones
## de flechas múltiples al jugador y 10 a las arqueras aliadas.
## Al obtenerse, reemplaza cualquier otro power-up activo.
## Caída con aceleración realista (EASE_IN) y frenado al tocar el suelo.

# ═══════════════════════════════════════════════════════════════════════════════
# SEÑALES Y ENUMS
# ═══════════════════════════════════════════════════════════════════════════════
signal picked_up(player: Node)

enum State { IDLE, DISSOLVING }

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTES
# ═══════════════════════════════════════════════════════════════════════════════
const ESCALA_BASE: float = 0.63  ## Escala base (+40% idéntica a Flecha Explosiva)
const SONIDO_PICKUP: String = "res://TEST_/Obtener arma.mp3"

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Munición")
@export var municion_a_otorgar_jugador: int = 6  ## Otorga 6 disparos múltiples al jugador
@export var municion_a_otorgar_aliadas: int = 3  ## Otorga 3 disparos múltiples a cada aliada
@export var tiempo_en_pantalla: float = 3.0  ## Segundos antes de auto-consumirse
@export var tiempo_escala_spawn: float = 0.4  ## Duración del escalado orgánico (0 a 1) al aparecer

@export_category("Luz Mágica")
@export var light_color: Color = Color(0.25, 0.75, 1.0, 1.0)
@export var light_energy_min: float = 1.2
@export var light_energy_max: float = 4.8
@export var light_flicker_speed: float = 8.0

@export_category("Rotación y Animación")
@export var velocidad_rotacion_y: float = 3.0  ## Velocidad de giro continuo 360 grados
@export var float_amplitude: float = 0.05
@export var float_speed: float = 2.5

# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES PÚBLICAS Y PRIVADAS
# ═══════════════════════════════════════════════════════════════════════════════
var current_state: State = State.IDLE
var dissolve_shader: Shader = preload("res://System/Shaders/dissolve.gdshader")

var _initial_model_y: float = 0.0
var _nodes_checked: bool = false
var _is_falling: bool = false
var _model_centered: bool = false

var model_root: Node3D = null
var magic_light: OmniLight3D = null
var magic_particles: GPUParticles3D = null

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIONES BUILT-IN
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_obtener_nodos_directos()
	_centrar_modelo()

	add_to_group("pickups")
	add_to_group("power_ups_flecha_multiple")

	if model_root:
		_initial_model_y = model_root.position.y
		model_root.scale = Vector3(ESCALA_BASE, ESCALA_BASE, ESCALA_BASE)

	if magic_light:
		magic_light.light_color = light_color
		magic_light.light_energy = light_energy_min

	body_entered.connect(_on_body_entered)

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

		# Timer de auto-consumo a los 3 segundos
		var timer := get_tree().create_timer(tiempo_en_pantalla)
		timer.timeout.connect(_auto_consumir)


func _process(delta: float) -> void:
	if not _nodes_checked:
		_obtener_nodos_directos()
		_centrar_modelo()
		_nodes_checked = true

	_bucle_parpadeo_luz()

	if current_state == State.IDLE:
		_bucle_rotacion_360(delta)
		if not _is_falling:
			_bucle_flotacion()


# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIONES PÚBLICAS
# ═══════════════════════════════════════════════════════════════════════════════

## Consume el power up, otorgando las flechas múltiples y disolviéndose
func consumir_powerup() -> void:
	_auto_consumir()


# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIONES PRIVADAS
# ═══════════════════════════════════════════════════════════════════════════════

func _obtener_nodos_directos() -> void:
	if not model_root:
		model_root = get_node_or_null("ModelRoot") as Node3D
	if not magic_light:
		magic_light = get_node_or_null("MagicLight") as OmniLight3D
	if not magic_particles:
		magic_particles = get_node_or_null("MagicParticles") as GPUParticles3D


## Centra el modelo de la malla en el origen (0,0,0) de ModelRoot para que gire sobre su propio eje
func _centrar_modelo() -> void:
	if _model_centered or not model_root:
		return

	var child_model: Node3D = null
	for child in model_root.get_children():
		if child is Node3D:
			child_model = child
			break

	if not child_model:
		return

	var meshes: Array[Node] = child_model.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return

	var combined_aabb: AABB
	var first: bool = true
	for mesh_node in meshes:
		var mi := mesh_node as MeshInstance3D
		if not mi or not mi.mesh:
			continue
		var xform: Transform3D = model_root.global_transform.affine_inverse() * mi.global_transform
		var local_aabb: AABB = xform * mi.mesh.get_aabb()
		if first:
			combined_aabb = local_aabb
			first = false
		else:
			combined_aabb = combined_aabb.merge(local_aabb)

	if not first:
		var center_offset: Vector3 = combined_aabb.get_center()
		child_model.position -= center_offset
		_model_centered = true


func _comprobar_caida_al_suelo() -> void:
	if Engine.is_editor_hint():
		return

	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return

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
			var duracion: float = clamp(dist * 0.25, 0.5, 1.2)
			tween.tween_property(self, "global_position:y", suelo_y + 0.1, duracion) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.finished.connect(func() -> void: _is_falling = false)


func _bucle_rotacion_360(delta: float) -> void:
	if not model_root:
		return
	model_root.rotate_y(velocidad_rotacion_y * delta)


func _bucle_parpadeo_luz() -> void:
	if not magic_light:
		return
	var tiempo: float = Time.get_ticks_msec() * 0.001
	var onda1: float = (sin(tiempo * light_flicker_speed) + 1.0) * 0.5
	var onda2: float = (sin(tiempo * light_flicker_speed * 2.37) + 1.0) * 0.5
	magic_light.light_energy = lerp(light_energy_min, light_energy_max, onda1 * 0.6 + onda2 * 0.4)


func _bucle_flotacion() -> void:
	if not model_root:
		return
	var tiempo: float = Time.get_ticks_msec() * 0.001
	var float_offset: float = sin(tiempo * float_speed) * float_amplitude
	model_root.position.y = _initial_model_y + float_offset
	if magic_light:
		magic_light.position.y = _initial_model_y + float_offset
	if magic_particles:
		magic_particles.position.y = _initial_model_y + float_offset


func _on_body_entered(body: Node3D) -> void:
	if current_state == State.DISSOLVING:
		return
	if body.is_in_group("player"):
		_auto_consumir()


func _auto_consumir() -> void:
	if current_state == State.DISSOLVING:
		return
	current_state = State.DISSOLVING

	var player: Node3D = _buscar_jugador()
	if is_instance_valid(player):
		if player.has_method("agregar_flechas_multiples"):
			player.agregar_flechas_multiples(municion_a_otorgar_jugador)
		elif "flechas_multiples" in player:
			player.flechas_multiples += municion_a_otorgar_jugador
			if player.has_signal("flechas_multiples_changed"):
				player.flechas_multiples_changed.emit(player.flechas_multiples)
		picked_up.emit(player)
		_play_pickup_sound()

	# También otorgar a las arqueras aliadas
	_otorgar_municion_a_aliadas()

	_iniciar_desintegracion(0.8)


func _otorgar_municion_a_aliadas() -> void:
	var processed: Dictionary = {}
	for ally: Node in AllyArcher.active_allies_cache:
		if not is_instance_valid(ally):
			continue
		if ally.has_meta("es_mensajera") and ally.get_meta("es_mensajera"):
			continue
		processed[ally] = true
		if ally.has_method("agregar_flechas_multiples"):
			ally.agregar_flechas_multiples(municion_a_otorgar_aliadas)
		elif "flechas_multiples" in ally:
			ally.set("flechas_multiples", int(ally.get("flechas_multiples")) + municion_a_otorgar_aliadas)

	var aliadas: Array[Node] = get_tree().get_nodes_in_group("allies")
	for aliada: Node in aliadas:
		if not is_instance_valid(aliada) or processed.has(aliada):
			continue
		if aliada.has_meta("es_mensajera") and aliada.get_meta("es_mensajera"):
			continue
		if aliada.has_method("agregar_flechas_multiples"):
			aliada.agregar_flechas_multiples(municion_a_otorgar_aliadas)
		elif "flechas_multiples" in aliada:
			aliada.set("flechas_multiples", int(aliada.get("flechas_multiples")) + municion_a_otorgar_aliadas)


func _buscar_jugador() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node3D
	return null


func _iniciar_desintegracion(duracion: float) -> void:
	if magic_particles:
		magic_particles.emitting = true

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
		mat.set_shader_parameter("glow_color", Color(0.2, 0.8, 1.0))
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

	if magic_light:
		tween.parallel().tween_property(magic_light, "light_energy", 0.0, duracion)

	tween.finished.connect(queue_free)


func _play_pickup_sound() -> void:
	var stream := load(SONIDO_PICKUP) as AudioStream
	if not stream:
		return
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = 6.0
	sfx.pitch_scale = 1.45  ## Tono más agudo/mágico para diferenciar de la flecha explosiva
	sfx.bus = "Master"
	var root := get_tree().current_scene
	if root:
		root.add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)
	else:
		sfx.queue_free()
