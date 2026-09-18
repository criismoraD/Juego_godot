class_name PowerUpFuegoRapido
extends Area3D

## Power-Up de Fuego Rápido con rotación continua 360°, luz parpadeante y animación procedimental.
## Se consume al contacto del jugador (o automáticamente tras 3 segundos) otorgando el buff
## de Fuego Rápido durante 10 segundos (inmortalidad, disparos normales al máximo poder, 30% mayor velocidad de disparo,
## aura rosada sutil y SFX ambiental en bucle).
## Caída con aceleración realista (EASE_IN) y frenado al tocar el suelo.

# ═══════════════════════════════════════════════════════════════════════════════
# SEÑALES Y ENUMS
# ═══════════════════════════════════════════════════════════════════════════════
signal picked_up(player: Node)

enum State { IDLE, DISSOLVING }

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTES
# ═══════════════════════════════════════════════════════════════════════════════
const ESCALA_BASE: float = 0.63  ## Escala base (+40% estandarizada)
const ESCALA_SPAWN_MINIMA: float = 0.05  ## Escala inicial segura: Jolt rechaza transforms singulares
const SONIDO_PICKUP: String = "res://TEST_/Obtener arma.wav"
const RADIO_PICKUP_JUGADOR: float = 2.0  ## Pickup por proximidad horizontal
const RADIO_PICKUP_Y: float = 2.5  ## Margen vertical para plataformas/saltos
const DURACION_DESINTEGRACION: float = 0.6  ## Duración del shader dissolve

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Efecto Fuego Rápido")
@export var duracion_buff: float = 10.0  ## Duración en segundos del buff
@export var tiempo_en_pantalla: float = 3.0  ## Segundos antes de auto-consumirse
@export var tiempo_escala_spawn: float = 0.4  ## Duración del escalado orgánico al aparecer

@export_category("Luz y Partículas")
@export var light_color: Color = Color(1.0, 0.35, 0.8, 1.0)
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
var _is_falling: bool = false
var _tween_caida: Tween = null
var _suelo_alcanzado: bool = false
var _tiempo_para_check_suelo: float = 0.0
var _model_centered: bool = false
var _tiempo_vivo: float = 0.0
var _desintegracion_iniciada: bool = false

var model_root: Node3D = null
var fire_light: OmniLight3D = null
var fire_particles: GPUParticles3D = null

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIONES BUILT-IN
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_obtener_nodos_directos()
	_centrar_modelo()

	add_to_group("pickups")
	add_to_group("power_ups_fuego_rapido")

	if model_root:
		_initial_model_y = model_root.position.y
		model_root.scale = Vector3(ESCALA_BASE, ESCALA_BASE, ESCALA_BASE)

	if fire_light:
		fire_light.light_color = light_color
		fire_light.light_energy = light_energy_min

	body_entered.connect(_on_body_entered)

	# Escalado orgánico al aparecer
	scale = Vector3(ESCALA_SPAWN_MINIMA, ESCALA_SPAWN_MINIMA, ESCALA_SPAWN_MINIMA)
	var spawn_tween := create_tween()
	if spawn_tween:
		spawn_tween.tween_property(self, "scale", Vector3.ONE, tiempo_escala_spawn) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var sombra := SombraPersonaje.new()
	sombra.tamano = Vector2(0.25, 0.25)
	sombra.opacidad = 0.6
	sombra.altura_max_desvanecimiento = 5.0
	add_child(sombra)

	call_deferred("_comprobar_caida_al_suelo")

	# Timer de auto-consumo a los 3 segundos
	if is_inside_tree() and get_tree():
		var timer := get_tree().create_timer(tiempo_en_pantalla)
		timer.timeout.connect(_auto_consumir)

		# Failsafe incondicional
		get_tree().create_timer(tiempo_en_pantalla + 2.5, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(self):
				if current_state != State.DISSOLVING:
					_auto_consumir()
				else:
					queue_free()
		)


func _process(delta: float) -> void:
	if current_state == State.IDLE:
		_bucle_rotacion_360(delta)
		_bucle_parpadeo_luz()
		if not _is_falling:
			_bucle_flotacion()

		# Watchdog de caída
		if _is_falling and (_tween_caida == null or not _tween_caida.is_valid()):
			_is_falling = false

		if not _suelo_alcanzado and not _is_falling:
			_tiempo_para_check_suelo += delta
			if _tiempo_para_check_suelo >= 0.1:
				_tiempo_para_check_suelo = 0.0
				_comprobar_caida_al_suelo()

		_verificar_proximidad_jugador()

		if get_tree() and not get_tree().paused:
			_tiempo_vivo += delta
		if _tiempo_vivo >= tiempo_en_pantalla + 0.8:
			_auto_consumir()

		if _tiempo_vivo >= tiempo_escala_spawn + 0.5 and scale.x < 0.9:
			scale = Vector3.ONE


# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIONES PÚBLICAS
# ═══════════════════════════════════════════════════════════════════════════════

## Consume el power up, otorgando fuego rápido y disolviéndose
func consumir_powerup() -> void:
	_auto_consumir()


# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIONES PRIVADAS
# ═══════════════════════════════════════════════════════════════════════════════

func _obtener_nodos_directos() -> void:
	if not model_root:
		model_root = get_node_or_null("ModelRoot") as Node3D
	if not fire_light:
		fire_light = get_node_or_null("FireLight") as OmniLight3D
	if not fire_particles:
		fire_particles = get_node_or_null("FireParticles") as GPUParticles3D


## Centra el modelo de la malla en el origen (0,0,0) de ModelRoot
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
	if current_state != State.IDLE or _is_falling or not is_inside_tree() or get_world_3d() == null:
		return

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.2, 0),
		global_position + Vector3(0, -25, 0))
	query.collision_mask = 1 | 2 | 64 | 512
	var result := space_state.intersect_ray(query)

	if result and result.has("position"):
		var suelo_y: float = result.position.y
		if global_position.y > suelo_y + 0.35:
			_is_falling = true
			var dist: float = global_position.y - suelo_y
			var duracion: float = clampf(dist * 0.25, 0.3, 0.8)
			_tween_caida = create_tween()
			if _tween_caida:
				_tween_caida.tween_property(self, "global_position:y", suelo_y + 0.15, duracion) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				_tween_caida.finished.connect(func() -> void:
					_is_falling = false
					_suelo_alcanzado = true
					_initial_model_y = model_root.position.y if model_root else 0.0
				)
		else:
			_suelo_alcanzado = true
	else:
		_suelo_alcanzado = true


func _bucle_rotacion_360(delta: float) -> void:
	if not model_root:
		return
	model_root.rotate_y(velocidad_rotacion_y * delta)


func _bucle_parpadeo_luz() -> void:
	if not fire_light:
		return
	var tiempo: float = Time.get_ticks_msec() * 0.001
	var onda1: float = (sin(tiempo * light_flicker_speed) + 1.0) * 0.5
	var onda2: float = (sin(tiempo * light_flicker_speed * 2.37) + 1.0) * 0.5
	fire_light.light_energy = lerpf(light_energy_min, light_energy_max, onda1 * 0.6 + onda2 * 0.4)


func _bucle_flotacion() -> void:
	if not model_root:
		return
	var tiempo: float = Time.get_ticks_msec() * 0.001
	var float_offset: float = sin(tiempo * float_speed) * float_amplitude
	model_root.position.y = _initial_model_y + float_offset
	if fire_light:
		fire_light.position.y = _initial_model_y + float_offset
	if fire_particles:
		fire_particles.position.y = _initial_model_y + float_offset


func _on_body_entered(body: Node3D) -> void:
	if current_state == State.DISSOLVING:
		return
	if body.is_in_group("player") or body.name == "Player" or body.has_method("activar_fuego_rapido"):
		_auto_consumir(body)


func _verificar_proximidad_jugador() -> void:
	if current_state != State.IDLE or not is_inside_tree() or get_tree() == null:
		return
	var player: Node = _buscar_jugador()
	if not is_instance_valid(player) or not (player is Node3D):
		return
	var player_3d := player as Node3D
	var diff_x: float = absf(global_position.x - player_3d.global_position.x)
	var diff_y: float = absf(global_position.y - player_3d.global_position.y)
	if diff_x <= RADIO_PICKUP_JUGADOR and diff_y <= RADIO_PICKUP_Y:
		_auto_consumir(player_3d)


func _auto_consumir(collector: Node = null) -> void:
	if current_state == State.DISSOLVING:
		return
	current_state = State.DISSOLVING

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	# 1. Otorgar buff al jugador INMEDIATAMENTE
	_otorgar_al_jugador(collector)

	# 2. Disolución visual y liberación garantizada
	_iniciar_desintegracion(DURACION_DESINTEGRACION)


func _otorgar_al_jugador(collector: Node = null) -> void:
	var player: Node = collector if is_instance_valid(collector) else _buscar_jugador()
	if not is_instance_valid(player):
		push_warning("[PowerUpFuegoRapido] Sin jugador válido al consumirse; no se activó el buff")
		return

	if player.has_method("activar_fuego_rapido"):
		player.activar_fuego_rapido(duracion_buff)

	picked_up.emit(player)
	_play_pickup_sound()


func _buscar_jugador() -> Node:
	if not is_inside_tree() or get_tree() == null:
		return null

	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p.has_method("activar_fuego_rapido"):
			return p

	var root: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	if root:
		for target_name in ["Player", "Perrena"]:
			var prota: Node = root.find_child(target_name, true, false)
			if is_instance_valid(prota) and prota.has_method("activar_fuego_rapido"):
				return prota

	for p in players:
		if is_instance_valid(p):
			return p

	if root:
		for target_name in ["Player", "Perrena"]:
			var prota_fallback: Node = root.find_child(target_name, true, false)
			if is_instance_valid(prota_fallback):
				return prota_fallback

	return null


func _iniciar_desintegracion(duracion: float) -> void:
	if _desintegracion_iniciada:
		return
	_desintegracion_iniciada = true

	if fire_particles:
		fire_particles.emitting = false

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
		mat.set_shader_parameter("glow_color", Color(1.0, 0.35, 0.8))
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
	if tween:
		var update_dissolve := func(val: float) -> void:
			for m in dissolve_mats:
				if is_instance_valid(m):
					m.set_shader_parameter("dissolve_amount", val)
		tween.tween_method(update_dissolve, 0.0, 1.0, duracion)
		tween.parallel().tween_property(self, "scale", Vector3(ESCALA_SPAWN_MINIMA, ESCALA_SPAWN_MINIMA, ESCALA_SPAWN_MINIMA), duracion) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if fire_light:
			tween.parallel().tween_property(fire_light, "light_energy", 0.0, duracion)
		tween.finished.connect(queue_free)
	else:
		queue_free()

	if is_inside_tree() and get_tree():
		get_tree().create_timer(duracion + 0.3, true, false, true).timeout.connect(queue_free)


func _play_pickup_sound() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var stream := load(SONIDO_PICKUP) as AudioStream
	if not stream:
		return
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = 6.0
	sfx.pitch_scale = 1.35  ## Tono característico para Fuego Rápido
	sfx.bus = "Master"
	var root := get_tree().current_scene
	if root:
		root.add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)
	else:
		sfx.queue_free()
