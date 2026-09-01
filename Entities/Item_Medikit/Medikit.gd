@tool
class_name Medikit
extends Area3D
## Item Medikit de salud:
## - Cura 1 corazón al jugador y a todas las defensoras aliadas vivas al recogerlo.
## - Puede revivir a defensoras aliadas fijas caídas (arqueras y ballesteras fijas).
## - Si el jugador y todas las aliadas tienen la salud completa, NO se consume automáticamente y permanece en el escenario.
## - Si el jugador entra en contacto estando dañado (o si está en contacto y recibe daño, o si hay aliadas caídas/dañadas), se consume de inmediato.
## - Efecto visual: Color rojo rubí/médico, luz, partículas, contracción y expansión elástica (squash & stretch pop) al usarse.
## - Si no se consume, desaparece al finalizar la oleada.

# ═══════════════════════════════════════════════════════════════════════════════
# SEÑALES Y ENUMS
# ═══════════════════════════════════════════════════════════════════════════════
signal picked_up(player: Node)

enum State { IDLE, DISSOLVING }

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Curación")
@export var vida_a_restaurar: int = 1
@export var tiempo_escala_spawn: float = 0.3

@export_category("Luz Roja Médica")
@export var medikit_color: Color = Color(1.0, 0.15, 0.25)
@export var light_energy_min: float = 1.0
@export var light_energy_max: float = 4.5
@export var light_flicker_speed: float = 5.0

@export_category("Movimiento y Visual")
@export var float_amplitude: float = 0.04
@export var float_speed: float = 1.8
@export var rotation_speed: float = 0.8  ## Gira más lento
@export var escala_modelo: float = 0.45

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTES
# ═══════════════════════════════════════════════════════════════════════════════
const SONIDO_CURACION: String = "res://TEST_/Posion curativa.wav"
const SONIDO_APARECE_POCION: String = "res://TEST_/Aparece pocion.wav"

var dissolve_shader: Shader = preload("res://System/Shaders/dissolve.gdshader")

# ═══════════════════════════════════════════════════════════════════════════════
# ESTADO INTERNO
# ═══════════════════════════════════════════════════════════════════════════════
var current_state: State = State.IDLE
var _initial_model_y: float = 0.0
var _nodes_checked: bool = false
var _is_falling: bool = false
var _player_en_contacto: Node3D = null

var model_root: Node3D = null
var medikit_light: OmniLight3D = null
var medikit_particles: GPUParticles3D = null

# ═══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_obtener_nodos_directos()

	add_to_group("pickups")
	add_to_group("medikits")

	if model_root:
		_initial_model_y = model_root.position.y
		model_root.scale = Vector3(escala_modelo, escala_modelo, escala_modelo)

	if medikit_light:
		medikit_light.light_color = medikit_color
		medikit_light.light_energy = light_energy_min

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)

	if not Engine.is_editor_hint():
		scale = Vector3(0.001, 0.001, 0.001)
		var spawn_tween := create_tween()
		spawn_tween.tween_property(self, "scale", Vector3.ONE, tiempo_escala_spawn) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		var sombra := SombraPersonaje.new()
		sombra.tamano = Vector2(0.35, 0.35)
		sombra.opacidad = 0.6
		sombra.altura_max_desvanecimiento = 5.0
		add_child(sombra)

		call_deferred("_comprobar_caida_al_suelo")
		call_deferred("_conectar_eventos_oleada")
		_reproducir_sonido_aparece()


func _obtener_nodos_directos() -> void:
	if not model_root:
		model_root = get_node_or_null("ModelRoot") as Node3D
	if not medikit_light:
		medikit_light = get_node_or_null("MedikitLight") as OmniLight3D
	if not medikit_particles:
		medikit_particles = get_node_or_null("MedikitParticles") as GPUParticles3D


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
		if global_position.y > suelo_y + 0.3:
			_is_falling = true
			var tween := create_tween()
			var dist: float = global_position.y - suelo_y
			var duracion: float = clamp(dist * 0.25, 0.5, 1.2)
			tween.tween_property(self, "global_position:y", suelo_y + 0.1, duracion) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.finished.connect(func(): _is_falling = false)


func _conectar_eventos_oleada() -> void:
	var spawner := _get_cached_wave_spawner()
	if spawner and spawner.has_signal("oleada_completada"):
		if not spawner.oleada_completada.is_connected(_on_oleada_completada):
			spawner.oleada_completada.connect(_on_oleada_completada)


func _get_cached_wave_spawner() -> Node:
	var spawners := get_tree().get_nodes_in_group("wave_spawner")
	if not spawners.is_empty():
		return spawners[0]
	var root := get_tree().current_scene
	if root and "wave_spawner" in root and root.wave_spawner:
		return root.wave_spawner
	return null


func _on_oleada_completada(_numero_oleada: int) -> void:
	if current_state == State.IDLE:
		_iniciar_desintegracion(0.6)


# ═══════════════════════════════════════════════════════════════════════════════
# PROCESO Y DETECCIÓN ACTIVA
# ═══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if not _nodes_checked:
		_obtener_nodos_directos()
		_nodes_checked = true

	_bucle_parpadeo_luz()

	if current_state == State.IDLE:
		_bucle_animacion_flotacion_y_giro(delta)

		# Comprobación de proximidad y contacto activo con el jugador
		var player_node: Node3D = _player_en_contacto
		if not is_instance_valid(player_node):
			var players := get_tree().get_nodes_in_group("player")
			for p in players:
				if is_instance_valid(p) and p is Node3D and p.is_inside_tree():
					var dist_xz = Vector2(global_position.x - p.global_position.x, global_position.z - p.global_position.z).length()
					var dist_y = absf(global_position.y - p.global_position.y)
					if dist_xz <= 1.2 and dist_y <= 2.5:
						player_node = p as Node3D
						break

		if is_instance_valid(player_node):
			if _necesita_curacion(player_node) or _hay_aliadas_que_necesitan_curacion_o_revivir():
				_intentar_consumir(player_node)
			else:
				_player_en_contacto = player_node


func _bucle_parpadeo_luz() -> void:
	if not medikit_light:
		return
	var tiempo: float = Time.get_ticks_msec() * 0.001
	var onda1: float = (sin(tiempo * light_flicker_speed) + 1.0) * 0.5
	var onda2: float = (sin(tiempo * light_flicker_speed * 1.85) + 1.0) * 0.5
	medikit_light.light_energy = lerp(light_energy_min, light_energy_max, onda1 * 0.6 + onda2 * 0.4)


func _bucle_animacion_flotacion_y_giro(delta: float) -> void:
	if not model_root or _is_falling:
		return
	var tiempo: float = Time.get_ticks_msec() * 0.001
	model_root.position.y = _initial_model_y + sin(tiempo * float_speed) * float_amplitude
	model_root.rotation.y += rotation_speed * delta
	model_root.scale = Vector3(escala_modelo, escala_modelo, escala_modelo)


# ═══════════════════════════════════════════════════════════════════════════════
# DETECCIÓN DE CONTACTO
# ═══════════════════════════════════════════════════════════════════════════════

func _on_body_entered(body: Node) -> void:
	_manejar_contacto(body)


func _on_body_exited(body: Node) -> void:
	if body == _player_en_contacto:
		_player_en_contacto = null


func _on_area_entered(area: Area3D) -> void:
	var parent := area.get_parent()
	if parent:
		_manejar_contacto(parent)


func _manejar_contacto(node: Node) -> void:
	if current_state != State.IDLE:
		return

	if node.is_in_group("player") or node.name == "Player" or node is Player:
		var player := node as Node3D
		if _necesita_curacion(player) or _hay_aliadas_que_necesitan_curacion_o_revivir():
			_intentar_consumir(player)
		else:
			_player_en_contacto = player


func _necesita_curacion(player: Node3D) -> bool:
	if not is_instance_valid(player):
		return false
	if "health" in player and "vida_maxima" in player:
		return int(player.health) < int(player.vida_maxima)
	return false


func _hay_aliadas_que_necesitan_curacion_o_revivir() -> bool:
	var aliados := get_tree().get_nodes_in_group("allies")
	for aliado in aliados:
		if not is_instance_valid(aliado) or not (aliado is Node3D) or not aliado.is_inside_tree():
			continue
		var esta_caida: bool = false
		if "current_state" in aliado and "State" in aliado:
			if aliado.current_state == aliado.State.DYING or aliado.current_state == aliado.State.DEAD:
				esta_caida = true
		elif "health" in aliado and aliado.health <= 0:
			esta_caida = true

		if esta_caida:
			if not aliado.get("es_movil") and not aliado.get("es_mensajera"):
				return true
		elif "health" in aliado and "vida_maxima" in aliado:
			if int(aliado.health) < int(aliado.vida_maxima):
				return true
	return false


func _curar_o_revivir_aliadas() -> void:
	var aliados := get_tree().get_nodes_in_group("allies")
	for aliado in aliados:
		if not is_instance_valid(aliado) or not (aliado is Node3D) or not aliado.is_inside_tree():
			continue
		var esta_caida: bool = false
		if "current_state" in aliado and "State" in aliado:
			if aliado.current_state == aliado.State.DYING or aliado.current_state == aliado.State.DEAD:
				esta_caida = true
		elif "health" in aliado and aliado.health <= 0:
			esta_caida = true

		if esta_caida:
			# Revivir defensoras fijas caídas
			if not aliado.get("es_movil") and not aliado.get("es_mensajera"):
				if aliado.has_method("revivir"):
					aliado.revivir()
				elif "health" in aliado and "vida_maxima" in aliado:
					aliado.health = 1
					if "current_state" in aliado and "State" in aliado and "GETTING_UP" in aliado.State:
						aliado.current_state = aliado.State.GETTING_UP
		else:
			# Curar 1 corazón a aliadas vivas
			if aliado.has_method("curar"):
				aliado.curar(vida_a_restaurar)
			elif "health" in aliado and "vida_maxima" in aliado:
				aliado.health = min(aliado.health + vida_a_restaurar, aliado.vida_maxima)


func _intentar_consumir(player: Node3D) -> bool:
	if current_state != State.IDLE:
		return false

	current_state = State.DISSOLVING
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	# 1. Curar 1 corazón al jugador inmediatamente (sin exceder salud máxima)
	if is_instance_valid(player):
		if player.has_method("curar"):
			player.curar(vida_a_restaurar)
		elif "health" in player and "vida_maxima" in player:
			player.health = min(player.health + vida_a_restaurar, player.vida_maxima)
			if player.has_signal("health_changed"):
				player.health_changed.emit(player.health)

	# 2. Curar 1 corazón a defensoras aliadas vivas y revivir defensoras fijas caídas
	_curar_o_revivir_aliadas()

	picked_up.emit(player)
	_play_pickup_sound()
	_iniciar_desintegracion(0.42)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CONTRACCIÓN, EXPANSIÓN, DESINTEGRACIÓN Y AUDIO
# ═══════════════════════════════════════════════════════════════════════════════

func _iniciar_desintegracion(duracion: float) -> void:
	current_state = State.DISSOLVING
	if medikit_particles:
		medikit_particles.emitting = true

	# 1. Efecto de Contracción y Expansión Elástica (Squash & Stretch Pop)
	if model_root:
		var s0: float = escala_modelo
		var tw_scale := create_tween()
		# Paso 1: Contracción rápida en Y y expansión en X/Z (Squash)
		tw_scale.tween_property(model_root, "scale", Vector3(s0 * 1.35, s0 * 0.45, s0 * 1.35), 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Paso 2: Expansión elástica estirada en Y (Stretch Pop)
		tw_scale.tween_property(model_root, "scale", Vector3(s0 * 0.65, s0 * 1.6, s0 * 0.65), 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Paso 3: Desvanecimiento / encogimiento final
		tw_scale.tween_property(model_root, "scale", Vector3.ZERO, max(0.1, duracion - 0.22)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 2. Shader de disolución
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
		mat.set_shader_parameter("glow_color", medikit_color)
		mat.set_shader_parameter("glow_intensity", 5.0)
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

	if medikit_light:
		tween.parallel().tween_property(medikit_light, "light_energy", 0.0, duracion)

	tween.finished.connect(queue_free)


func _play_pickup_sound() -> void:
	var stream := load(SONIDO_CURACION) as AudioStream
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
