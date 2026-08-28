class_name AllyBallestera
extends Node3D

## Ballestera Aliada: Defensora con ballesta medieval realista y 4 de vida.
## Mantiene postura de combate fija de pie, cadencia de ataque lenta y pesada, ciclo de 5 disparos
## de pie y luego 5 disparos agachada reforzando el escudo de piso.
## Apuntado orgánico y suave multi-hueso con suavizado exponencial y micro-respiración.
## No reconoce a la Imp de escudo como objetivo directo (solo la daña por casualidad de trayectoria).
## No hace fijación precisa a enemigos voladores ni arqueras Lonko (dispara al azar hacia el frente),
## y celebra con animación VICTORIA al finalizar una oleada.

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN
# ═══════════════════════════════════════════════════════════════════════════════
enum State { IDLE, AIMING, SHOOTING, RELOADING, DYING, DEAD, GETTING_UP, CELEBRATING }

@export_category("Activación")
@export var enemigos_minimos: int = 1  ## Cantidad mínima de enemigos hostiles para empezar a disparar

@export_category("Vida")
@export var vida_maxima: int = 4  ## 4 de vida para la ballestera defensora

@export_category("Disparo y Cadencia")
@export var velocidad_virote: float = 24.0  ## Virotes rápidos directos
@export var tiempo_carga_min: float = 0.8  ## Cadencia más lenta y pausada
@export var tiempo_carga_max: float = 1.3
@export var tiempo_recarga: float = 0.6
@export var altura_spawn_flecha: float = 0.95
@export var disparos_por_fase: int = 5  ## 5 disparos de pie y luego 5 disparos agachada

@export_category("Tiempos de Espera (Cadencia Lenta)")
@export var idle_min: float = 2.0  ## Pausa prolongada entre disparos
@export var idle_max: float = 3.2

@export_category("Apuntado y Seguimiento")
@export var invertir_pitch: bool = true  ## Invertir el sentido de giro del hueso para apuntar hacia abajo/arriba
@export var offset_pitch_animacion: float = 35.0  ## Compensación en grados del ángulo hacia arriba de la animación base
@export var velocidad_seguimiento: float = 8.0  ## Velocidad de suavizado para apuntar al objetivo
@export var angulo_pitch_min: float = -15.0  ## Límite de ángulo hacia arriba (grados)
@export var angulo_pitch_max: float = 60.0  ## Límite de ángulo hacia abajo (grados)
@export var balanceo_apuntado_grados: float = 1.5  ## Variación/balanceo natural de 1 a 2 grados al apuntar
@export var velocidad_balanceo: float = 2.2  ## Velocidad de la oscilación de balanceo

@export_category("Celebración de Victoria")
@export var repeticiones_victoria_min: int = 3  ## Mínimo de loops de la animación de victoria tras oleada
@export var repeticiones_victoria_max: int = 4  ## Máximo de loops de la animación de victoria tras oleada
@export var duracion_animacion_victoria: float = 1.0  ## Tiempo en segundos de cada loop de victoria (1.0s sutil y suavizado)
@export var rotacion_victoria_grados: float = 15.0  ## Grados de giro del personaje durante la celebración de victoria
@export var velocidad_giro_victoria: float = 4.5  ## Velocidad de rotación suave para la celebración
@export var probar_victoria: bool = false:  ## Botón para reproducir la animación de victoria desde el Inspector
	set(val):
		if val:
			probar_victoria = false
			celebrar_victoria()

@export_category("Debug")
@export var debug_logs_enabled: bool = false

# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCIAS
# ═══════════════════════════════════════════════════════════════════════════════
var arrow_scene = preload("res://Entities/Proyectil_Virote_Aliado/AllyBolt.tscn")
var escudo_scene: PackedScene = preload("res://Entities/Ambiente_Escudo/Escudo.tscn")
var ballesta_scene: PackedScene = preload("res://Entities/Enemigo_Goblin/BALLES_GOBLING.glb")

var anim_player: AnimationPlayer
var skeleton: Skeleton3D
var model_root: Node3D
var hitbox_body: StaticBody3D
var _original_model_y_rot: float = 0.0
var ultima_muerte_anim: String = ""

# ═══════════════════════════════════════════════════════════════════════════════
# ESTADO Y CICLO DE DISPARO
# ═══════════════════════════════════════════════════════════════════════════════
var current_state: State = State.IDLE
var state_timer: float = 0.0
var _blink_timer: float = 0.0
var charge_duration: float = 0.0
var health: int = 4
var paralisis_timer: float = 0.0  ## Tiempo restante de parálisis (4 segundos sin atacar)
var _paralisis_vfx_timer: float = 0.0
var is_dissolving: bool = false

# Ciclo: 5 disparos de pie -> 5 disparos agachada -> repite
var fase_agachada: bool = false
var disparos_en_fase: int = 0
var objetivo_actual: Node3D = null

# Referencia y anclaje al escudo de piso asignado
var _escudo_piso_ref: Node = null
var _escudo_piso_transform: Transform3D
var _escudo_piso_parent: Node = null
var _tiene_escudo_frente: bool = false

static var _cached_wave_spawner: Node = null
var _spine_bone_idx: int = -1
var _spine1_bone_idx: int = -1
var _spine2_bone_idx: int = -1
var _current_pitch: float = 0.0
var _loops_victoria_restantes: int = 0


func _ready():
	if not AllyArcher.active_allies_cache.has(self):
		AllyArcher.active_allies_cache.append(self)
	add_to_group("allies")
	health = vida_maxima
	set_physics_process(false)

	model_root = find_child("BallesteraModel", false, false)
	if not model_root:
		model_root = find_child("BALLESTERA_ALIADA", true, false)
	if model_root:
		_original_model_y_rot = model_root.rotation.y

	skeleton = find_child("Skeleton3D", true, false)
	if skeleton:
		_spine_bone_idx = _find_bone_fuzzy(skeleton, ["Spine", "mixamorig_Spine", "mixamorig:Spine"])
		_spine1_bone_idx = _find_bone_fuzzy(skeleton, ["Spine1", "mixamorig_Spine1", "mixamorig:Spine1"])
		_spine2_bone_idx = _find_bone_fuzzy(skeleton, ["Spine2", "mixamorig_Spine2", "mixamorig:Spine2"])

	_setup_animation_player()
	_configurar_arma_ballesta()
	_crear_hitbox()

	var _sombra := SombraPersonaje.new()
	add_child(_sombra)

	call_deferred("_vincular_escudo_piso")
	call_deferred("_conectar_eventos_oleada")
	call_deferred("_iniciar")


func _exit_tree():
	AllyArcher.active_allies_cache.erase(self)


func _iniciar():
	if anim_player:
		anim_player.active = true
	_cambiar_estado(State.IDLE)
	set_process(true)


func _conectar_eventos_oleada() -> void:
	var spawner = _get_cached_wave_spawner()
	if spawner and spawner.has_signal("oleada_completada"):
		if not spawner.oleada_completada.is_connected(_on_oleada_completada):
			spawner.oleada_completada.connect(_on_oleada_completada)


func _on_oleada_completada(_numero_oleada: int) -> void:
	celebrar_victoria()


func celebrar_victoria() -> void:
	if current_state != State.DYING and current_state != State.DEAD:
		_loops_victoria_restantes = randi_range(repeticiones_victoria_min, repeticiones_victoria_max)
		_cambiar_estado(State.CELEBRATING)


func probar_animacion_victoria() -> void:
	celebrar_victoria()


func _vincular_escudo_piso() -> void:
	var mejor_escudo: Node = null
	var menor_dist: float = 3.5
	for esc in get_tree().get_nodes_in_group("escudos"):
		if not is_instance_valid(esc) or not (esc is Node3D):
			continue
		if "es_escudo_enemigo" in esc and esc.es_escudo_enemigo:
			continue
		var dist = global_position.distance_to(esc.global_position)
		if dist < menor_dist:
			menor_dist = dist
			mejor_escudo = esc

	if mejor_escudo and is_instance_valid(mejor_escudo):
		_escudo_piso_ref = mejor_escudo
		_escudo_piso_transform = mejor_escudo.global_transform
		_escudo_piso_parent = mejor_escudo.get_parent()
		_tiene_escudo_frente = true
	else:
		_escudo_piso_transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.55, 0.0, 0.0))
		_escudo_piso_parent = get_parent()
		_tiene_escudo_frente = true


func _find_bone_fuzzy(skel: Skeleton3D, names: Array) -> int:
	for n in names:
		var idx = skel.find_bone(str(n))
		if idx != -1:
			return idx
	for i in range(skel.get_bone_count()):
		var bname = skel.get_bone_name(i)
		for n in names:
			if str(n).to_lower() == bname.to_lower():
				return i
	for i in range(skel.get_bone_count()):
		var bname = skel.get_bone_name(i)
		for n in names:
			if str(n).to_lower() in bname.to_lower():
				return i
	return -1


func _configurar_arma_ballesta() -> void:
	if not skeleton:
		return

	var hand_idx := _find_bone_fuzzy(skeleton, [
		"mixamorig_RightHandIndex1",
		"RightHandIndex1",
		"mixamorig_RightHand",
		"RightHand",
		"hand_r",
		"hand.r"
	])
	if hand_idx == -1:
		return

	var attachment := skeleton.find_child("BoneAttachment3D", false, false) as BoneAttachment3D
	if not attachment:
		attachment = BoneAttachment3D.new()
		attachment.name = "BoneAttachment3D"
		skeleton.add_child(attachment)

	attachment.bone_name = skeleton.get_bone_name(hand_idx)
	attachment.bone_idx = hand_idx

	var ballesta := attachment.find_child("BALLES_GOBLING", true, false) as Node3D
	if not ballesta:
		ballesta = attachment.find_child("*ballest*", true, false) as Node3D

	if not ballesta and ballesta_scene:
		ballesta = ballesta_scene.instantiate() as Node3D
		ballesta.name = "BALLES_GOBLING"
		attachment.add_child(ballesta)

	if ballesta:
		ballesta.visible = true
		for m in ballesta.find_children("*", "MeshInstance3D", true, false):
			m.visible = true


func _setup_animation_player():
	var trees = find_children("*", "AnimationTree", true, false)
	for tree in trees:
		tree.active = false

	var all_players = find_children("*", "AnimationPlayer", true, false)
	for player in all_players:
		var anims = player.get_animation_list()
		var has_anim = false
		for a in anims:
			if "DISPARO" in a or "IDLE" in a or "MUERTE" in a or "VICTORIA" in a:
				has_anim = true
				break
		if has_anim:
			anim_player = player
			break

	if not anim_player and all_players.size() > 0:
		anim_player = all_players[0]


func _crear_hitbox():
	hitbox_body = StaticBody3D.new()
	hitbox_body.name = "HitboxBody"
	hitbox_body.add_to_group("allies")
	hitbox_body.collision_layer = 2
	hitbox_body.collision_mask = 0

	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.6
	col.shape = shape
	col.position = Vector3(0, 0.8, 0)

	hitbox_body.add_child(col)
	add_child(hitbox_body)


# ═══════════════════════════════════════════════════════════════════════════════
# PROCESO Y APUNTADO ORGÁNICO
# ═══════════════════════════════════════════════════════════════════════════════

func _process(delta: float):
	if current_state == State.DYING or current_state == State.DEAD:
		_restaurar_torso()
		return

	if paralisis_timer > 0.0:
		paralisis_timer -= delta
		_restaurar_torso()
		if paralisis_timer <= 0.0:
			paralisis_timer = 0.0
		else:
			_paralisis_vfx_timer += delta

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.RELOADING:
			_process_reloading(delta)
		State.AIMING:
			_process_aiming(delta)
		State.SHOOTING:
			_process_shooting(delta)
		State.GETTING_UP:
			_process_getting_up(delta)
		State.CELEBRATING:
			_process_celebrating(delta)

	_actualizar_rotacion_modelo(delta)
	if paralisis_timer <= 0.0:
		_actualizar_apuntado_torso(delta)


## Aplica el estado de parálisis por la duración indicada (4s por defecto):
## No puede atacar, cancela recargas/apuntados y restaura el torso.
func aplicar_paralisis(duracion: float = 4.0) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return
	paralisis_timer = maxf(paralisis_timer, duracion)
	_restaurar_torso()
	if current_state != State.IDLE and current_state != State.GETTING_UP and current_state != State.CELEBRATING:
		_cambiar_estado(State.IDLE)


func esta_paralizada() -> bool:
	return paralisis_timer > 0.0


func _actualizar_rotacion_modelo(delta: float) -> void:
	if not model_root:
		return

	var target_y_rot: float = _original_model_y_rot
	if current_state == State.CELEBRATING:
		target_y_rot = _original_model_y_rot + deg_to_rad(rotacion_victoria_grados)

	model_root.rotation.y = lerp_angle(model_root.rotation.y, target_y_rot, 1.0 - exp(-velocidad_giro_victoria * delta))


func _actualizar_apuntado_torso(delta: float) -> void:
	if not skeleton or paralisis_timer > 0.0:
		_restaurar_torso()
		return

	if current_state == State.DYING or current_state == State.DEAD or current_state == State.CELEBRATING:
		_restaurar_torso()
		return

	# Actualizar o refrescar objetivo prioritario
	if not is_instance_valid(objetivo_actual) or _es_enemigo_muerto(objetivo_actual):
		objetivo_actual = _obtener_objetivo_prioritario()

	var target_pitch: float = 0.0
	if is_instance_valid(objetivo_actual) and not _es_objetivo_azar(objetivo_actual):
		var my_pos: Vector3 = global_position + Vector3(0, 0.75, 0)
		if fase_agachada:
			my_pos.y -= 0.35
		var target_pos: Vector3 = objetivo_actual.global_position + Vector3(0, 0.45, 0)
		var dy: float = target_pos.y - my_pos.y
		var dx: float = absf(target_pos.x - my_pos.x)
		var angle_to_target: float = atan2(dy, maxf(dx, 0.2))

		# Girar el hueso hacia el objetivo compensando la inclinación hacia arriba de la animación
		var base_offset: float = deg_to_rad(offset_pitch_animacion)
		target_pitch = base_offset - angle_to_target
		target_pitch = clampf(target_pitch, deg_to_rad(angulo_pitch_min), deg_to_rad(angulo_pitch_max))

		if invertir_pitch:
			target_pitch = -target_pitch

		# Balanceo y variación natural de 1 a 2 grados al apuntar
		var sway := sin(Time.get_ticks_msec() * 0.001 * velocidad_balanceo) * deg_to_rad(balanceo_apuntado_grados)
		target_pitch += sway
	elif _puede_atacar():
		# Si hay combate activo pero el objetivo es lejano o temporal, mantener ángulo frontal con leve balanceo
		var base_pitch = deg_to_rad(offset_pitch_animacion)
		target_pitch = -base_pitch if invertir_pitch else base_pitch
		var sway := sin(Time.get_ticks_msec() * 0.001 * velocidad_balanceo) * deg_to_rad(balanceo_apuntado_grados * 0.5)
		target_pitch += sway

	# Suavizado exponencial orgánico e independiente del framerate
	var smooth_factor: float = 1.0 - exp(-velocidad_seguimiento * delta)
	_current_pitch = lerpf(_current_pitch, target_pitch, smooth_factor)

	if absf(_current_pitch) > 0.001:
		# Distribuir la curvatura del torso naturalmente entre las vértebras
		var half_pitch: float = _current_pitch * 0.5
		var pitch_basis := Basis(Quaternion(Vector3.FORWARD, half_pitch))

		if _spine1_bone_idx != -1 and _spine2_bone_idx != -1:
			skeleton.set_bone_global_pose_override(_spine1_bone_idx, Transform3D.IDENTITY, 0.0, false)
			var pose1 := skeleton.get_bone_global_pose(_spine1_bone_idx)
			skeleton.set_bone_global_pose_override(
				_spine1_bone_idx, Transform3D(pose1.basis * pitch_basis, pose1.origin), 1.0, false
			)

			skeleton.set_bone_global_pose_override(_spine2_bone_idx, Transform3D.IDENTITY, 0.0, false)
			var pose2 := skeleton.get_bone_global_pose(_spine2_bone_idx)
			skeleton.set_bone_global_pose_override(
				_spine2_bone_idx, Transform3D(pose2.basis * pitch_basis, pose2.origin), 1.0, false
			)
		elif _spine1_bone_idx != -1:
			var full_basis := Basis(Quaternion(Vector3.FORWARD, _current_pitch))
			skeleton.set_bone_global_pose_override(_spine1_bone_idx, Transform3D.IDENTITY, 0.0, false)
			var pose1 := skeleton.get_bone_global_pose(_spine1_bone_idx)
			skeleton.set_bone_global_pose_override(
				_spine1_bone_idx, Transform3D(pose1.basis * full_basis, pose1.origin), 1.0, false
			)
		elif _spine_bone_idx != -1:
			var full_basis := Basis(Quaternion(Vector3.FORWARD, _current_pitch))
			skeleton.set_bone_global_pose_override(_spine_bone_idx, Transform3D.IDENTITY, 0.0, false)
			var pose0 := skeleton.get_bone_global_pose(_spine_bone_idx)
			skeleton.set_bone_global_pose_override(
				_spine_bone_idx, Transform3D(pose0.basis * full_basis, pose0.origin), 1.0, false
			)
	else:
		_restaurar_torso()


func _restaurar_torso() -> void:
	if not skeleton:
		return
	if _spine_bone_idx != -1:
		skeleton.set_bone_global_pose_override(_spine_bone_idx, Transform3D.IDENTITY, 0.0, false)
	if _spine1_bone_idx != -1:
		skeleton.set_bone_global_pose_override(_spine1_bone_idx, Transform3D.IDENTITY, 0.0, false)
	if _spine2_bone_idx != -1:
		skeleton.set_bone_global_pose_override(_spine2_bone_idx, Transform3D.IDENTITY, 0.0, false)


func _process_idle(delta: float):
	if paralisis_timer > 0.0:
		state_timer = 0.4
		return

	state_timer -= delta
	if state_timer <= 0:
		if _puede_atacar():
			_cambiar_estado(State.RELOADING)
		else:
			state_timer = 0.6


func _process_reloading(delta: float):
	state_timer -= delta
	if state_timer <= 0:
		_cambiar_estado(State.AIMING)


func _process_aiming(delta: float):
	state_timer -= delta
	if state_timer <= 0:
		if not _puede_atacar() or not is_instance_valid(_obtener_objetivo_prioritario()):
			# Si no hay enemigos activos, mantenerse apuntando y en guardia sin disparar
			state_timer = 0.25
			return
		_disparar()
		_cambiar_estado(State.SHOOTING)


func _process_shooting(delta: float):
	state_timer -= delta
	if state_timer <= 0:
		_cambiar_estado(State.IDLE)


func _process_getting_up(delta: float):
	state_timer -= delta
	_blink_timer += delta
	if _blink_timer >= 0.16:
		_blink_timer = 0.0
		if model_root:
			model_root.visible = not model_root.visible

	if state_timer <= 0:
		if model_root:
			model_root.visible = true
		_cambiar_estado(State.IDLE)


func _process_celebrating(delta: float):
	state_timer -= delta
	if state_timer <= 0:
		if _loops_victoria_restantes > 1:
			_loops_victoria_restantes -= 1
			if anim_player:
				anim_player.seek(0.0, true)
			_play_anim("VICTORIA", 0.35, 1.0)
			state_timer = duracion_animacion_victoria
		else:
			_loops_victoria_restantes = 0
			# Transición directa y suave a la postura de apuntado (sin pasar por IDLE)
			_cambiar_estado(State.AIMING)


func _cambiar_estado(nuevo: State):
	if nuevo != State.GETTING_UP and model_root:
		model_root.visible = true

	current_state = nuevo
	match nuevo:
		State.IDLE:
			objetivo_actual = _obtener_objetivo_prioritario() if _puede_atacar() else null
			if fase_agachada:
				_play_anim("DISPARO_AGACHADO", 0.35, 0.001)
			else:
				_fijar_pose_combate(0.35)
			state_timer = randf_range(idle_min, idle_max)
		State.RELOADING:
			objetivo_actual = _obtener_objetivo_prioritario()
			AudioManager.play_sfx("bow_tension", -6.0)
			if fase_agachada:
				_play_anim("DISPARO_AGACHADO", 0.15, 0.001)
			else:
				_fijar_pose_combate(0.2)
			state_timer = tiempo_recarga
		State.AIMING:
			if not is_instance_valid(objetivo_actual):
				objetivo_actual = _obtener_objetivo_prioritario()
			if fase_agachada:
				_play_anim("DISPARO_AGACHADO", 0.35, 1.0)
			else:
				_fijar_pose_combate(0.35)
			charge_duration = randf_range(tiempo_carga_min, tiempo_carga_max)
			state_timer = charge_duration
		State.SHOOTING:
			if fase_agachada:
				_play_anim("DISPARO_AGACHADO", 0.06, 1.2)
			else:
				_play_anim("DISPARO_01", 0.06, 1.0)
			state_timer = 0.45
		State.DYING:
			_on_dying()
		State.DEAD:
			pass
		State.GETTING_UP:
			_fijar_pose_combate(0.3)
			state_timer = 1.0
			_blink_timer = 0.0
		State.CELEBRATING:
			_restaurar_torso()
			_play_anim("VICTORIA", 0.25, 1.0)
			state_timer = duracion_animacion_victoria


func _fijar_pose_combate(blend_time: float = 0.35):
	if not anim_player:
		return
	_play_anim("DISPARO_01", blend_time, 0.001)


# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO DE VIROTES, CICLO DE 5 TIROS Y TIRO AL AZAR
# ═══════════════════════════════════════════════════════════════════════════════

func _disparar():
	_reproducir_sonido_disparo()

	var objetivo := objetivo_actual if is_instance_valid(objetivo_actual) else _obtener_objetivo_prioritario()
	var spawn_pos := global_position + Vector3(0.35, altura_spawn_flecha, 0)
	if fase_agachada:
		spawn_pos.y -= 0.35

	var dir: Vector3
	# Si no hay objetivo terrestre estándar (solo hay voladores, Lonko, o se dispara al azar)
	if objetivo == null or _es_objetivo_azar(objetivo):
		# Disparo al azar en abanico frontal con variación aleatoria de elevación
		var elevacion := deg_to_rad(randf_range(-5.0, 10.0))
		dir = Vector3(cos(elevacion), sin(elevacion), 0.0).normalized()
	else:
		var target_pos := objetivo.global_position + Vector3(0, 0.45, 0)
		dir = (target_pos - spawn_pos).normalized()

	_spawnear_virote(spawn_pos, dir, velocidad_virote)

	# Si está en fase agachada, aplica/refuerza el efecto de escudo
	if fase_agachada:
		_aplicar_efecto_escudo_piso()

	# Gestión del ciclo: 5 disparos de pie -> 5 disparos agachada -> repite
	disparos_en_fase += 1
	if disparos_en_fase >= disparos_por_fase:
		disparos_en_fase = 0
		fase_agachada = not fase_agachada


func _spawnear_virote(spawn_pos: Vector3, dir: Vector3, speed: float):
	if not arrow_scene:
		return

	var arrow = arrow_scene.instantiate()

	if arrow.has_method("initialize"):
		arrow.initialize(dir, speed)
	elif "velocity" in arrow:
		arrow.velocity = dir * speed

	var root = get_tree().current_scene
	if not root:
		root = get_parent()
	root.add_child(arrow)

	arrow.global_position = spawn_pos

	for esc in get_tree().get_nodes_in_group("escudos"):
		if is_instance_valid(esc):
			if "es_escudo_enemigo" not in esc or not esc.es_escudo_enemigo:
				if "_ray_ccd" in arrow and arrow._ray_ccd:
					arrow._ray_ccd.add_exception(esc)


func _aplicar_efecto_escudo_piso():
	if _escudo_piso_ref and is_instance_valid(_escudo_piso_ref) and _escudo_piso_ref.is_inside_tree():
		if _escudo_piso_ref.has_method("activar_modo_metalico"):
			_escudo_piso_ref.activar_modo_metalico(2)
	else:
		_regenerar_escudo_piso()


func _regenerar_escudo_piso():
	if not escudo_scene:
		return

	var nuevo_escudo = escudo_scene.instantiate()
	if "golpes_para_destruir" in nuevo_escudo:
		nuevo_escudo.golpes_para_destruir = 1

	var parent = _escudo_piso_parent if is_instance_valid(_escudo_piso_parent) else get_parent()
	if parent:
		parent.add_child(nuevo_escudo)
		nuevo_escudo.global_transform = _escudo_piso_transform
		_escudo_piso_ref = nuevo_escudo

		if nuevo_escudo.has_method("_flash_dano"):
			nuevo_escudo._flash_dano()


func _reproducir_sonido_disparo():
	AudioManager.play_sfx("player_shoot", -6.0)


# ═══════════════════════════════════════════════════════════════════════════════
# CONDICIÓN DE COMBATE Y TARGETING
# ═══════════════════════════════════════════════════════════════════════════════

func _es_imp_escudo(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy is ImpShieldGirl or enemy.is_in_group("shield_imps"):
		return true
	var n: String = enemy.name.to_lower()
	var s: String = enemy.get_script().resource_path.to_lower() if enemy.get_script() else ""
	return ("imp" in n and "escudo" in n) or ("impshield" in n) or ("impshield" in s) or ("imp_escudo" in s)


func _puede_atacar() -> bool:
	var spawner = _get_cached_wave_spawner()
	if spawner:
		if "is_wave_active" in spawner and not spawner.is_wave_active:
			var hay_hostiles = false
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and not _es_pacifico_intacto(e) and not _es_enemigo_muerto(e) and not _es_imp_escudo(e):
					hay_hostiles = true
					break
			if not hay_hostiles:
				return false

	var hostiles_activos: int = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy is Node3D and enemy.global_position.x > global_position.x:
			if not _es_pacifico_intacto(enemy) and not _es_enemigo_muerto(enemy) and not _es_imp_escudo(enemy):
				hostiles_activos += 1

	return hostiles_activos >= enemigos_minimos


func _es_enemigo_muerto(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return true
	if enemy.get("is_dead") == true or enemy.get("is_dying") == true or enemy.get("muerto") == true:
		return true
	if enemy.get("current_state") != null:
		var st = enemy.current_state
		if str(st) in ["DYING", "DEAD", "MUERTO"]:
			return true
		if enemy is EnemyBase and (st == EnemyBase.State.DYING or st == EnemyBase.State.DEAD):
			return true
		if enemy is ImpShieldGirl and (st == ImpShieldGirl.State.DYING or st == ImpShieldGirl.State.DEAD):
			return true
	return false


func _es_pacifico_intacto(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy.get("es_pacifico") == true or enemy.get("is_peaceful") == true:
		return true
	if "max_health" in enemy and "health" in enemy:
		if enemy.name.begins_with("Pacifico") and enemy.health >= enemy.max_health:
			return true
	return false


## Determina si un enemigo debe ser tratado como objetivo al azar (voladores o Lonko)
func _es_objetivo_azar(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return true
	var n: String = enemy.name.to_lower()
	var s: String = enemy.get_script().resource_path.to_lower() if enemy.get_script() else ""
	var es_volador = enemy.is_in_group("flying_enemies") or ("gargola" in n) or ("gargola" in s)
	var es_lonko = "lonko" in n or "lonko" in s
	return es_volador or es_lonko


func _obtener_enemigos_terrestres_candidatos() -> Array[Node3D]:
	var candidatos: Array[Node3D] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not (enemy is Node3D) or not enemy.is_inside_tree():
			continue
		if _es_imp_escudo(enemy):
			continue  # No reconocer a la Imp de escudo como objetivo directo (se daña por casualidad)
		if _es_enemigo_muerto(enemy):
			continue
		if enemy.global_position.x <= global_position.x:
			continue
		if _es_pacifico_intacto(enemy):
			continue
		if _es_objetivo_azar(enemy):
			continue

		candidatos.append(enemy)

	return candidatos


func _obtener_objetivo_prioritario() -> Node3D:
	var candidatos := _obtener_enemigos_terrestres_candidatos()
	if candidatos.is_empty():
		return null

	var grupo_prioridad_1: Array[Node3D] = []
	var grupo_prioridad_2: Array[Node3D] = []

	for enemy in candidatos:
		var n: String = enemy.name.to_lower()
		var s: String = enemy.get_script().resource_path.to_lower() if enemy.get_script() else ""
		var es_imp: bool = ("imp" in n or "imp" in s) and not _es_imp_escudo(enemy)
		var es_ballestero: bool = "ballest" in n or "ballest" in s or ("goblin" in n and "girl" not in n)
		if es_imp or es_ballestero:
			grupo_prioridad_1.append(enemy)
		else:
			grupo_prioridad_2.append(enemy)

	var grupo_elegido = grupo_prioridad_1 if not grupo_prioridad_1.is_empty() else grupo_prioridad_2

	var mejor: Node3D = null
	var menor_dist: float = INF
	for enemy in grupo_elegido:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < menor_dist:
			menor_dist = dist
			mejor = enemy

	return mejor


func _get_cached_wave_spawner() -> Node:
	if is_instance_valid(_cached_wave_spawner):
		return _cached_wave_spawner
	if get_tree() == null:
		return null
	_cached_wave_spawner = get_tree().get_first_node_in_group("wave_spawners")
	if _cached_wave_spawner:
		return _cached_wave_spawner
	var scene_root = get_tree().current_scene
	if scene_root:
		_cached_wave_spawner = scene_root.find_child("WaveSpawner", true, false)
	return _cached_wave_spawner


# ═══════════════════════════════════════════════════════════════════════════════
# DAÑO, VIDA Y POWER-UPS
# ═══════════════════════════════════════════════════════════════════════════════

func recibir_dano(cantidad: int = 1):
	if current_state == State.DYING or current_state == State.DEAD or current_state == State.GETTING_UP:
		return

	health = max(0, health - cantidad)
	AudioManager.play_sfx("player_hurt")

	if health <= 0:
		_cambiar_estado(State.DYING)
	else:
		_blink_timer = 0.0


func take_damage(amount: int = 1):
	recibir_dano(amount)


func _on_dying():
	var muertes := ["MUERTE_01", "MUERTE02"]
	ultima_muerte_anim = muertes[randi() % muertes.size()]
	_play_anim(ultima_muerte_anim, 0.1)

	AudioManager.play_sfx("player_death")
	var dur = _get_anim_length(ultima_muerte_anim)
	get_tree().create_timer(dur + 0.1).timeout.connect(func():
		if is_instance_valid(self) and current_state == State.DYING:
			current_state = State.DEAD
	)


func revivir(nueva_vida: int = -1):
	if nueva_vida <= 0:
		nueva_vida = vida_maxima
	health = nueva_vida
	if model_root:
		model_root.visible = true
	_cambiar_estado(State.GETTING_UP)


func apply_death_dissolve(duration: float = 1.0):
	if is_dissolving:
		return
	is_dissolving = true
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func agregar_flechas_explosivas(_cantidad: int) -> void:
	pass


func agregar_flechas_multiples(_cantidad: int) -> void:
	pass


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMACIONES
# ═══════════════════════════════════════════════════════════════════════════════

func _play_anim(anim_target, blend: float = 0.2, speed: float = 1.0):
	if not anim_player:
		return

	var candidates: Array = []
	if anim_target is Array:
		candidates = anim_target
	else:
		candidates = [str(anim_target)]

	var all_anims = anim_player.get_animation_list()
	for cand in candidates:
		for a in all_anims:
			if a == cand or a.ends_with("/" + cand) or cand in a:
				anim_player.play(a, blend, speed)
				anim_player.speed_scale = speed
				return


func _get_anim_length(anim_target: String) -> float:
	if not anim_player:
		return 1.0
	for a in anim_player.get_animation_list():
		if a == anim_target or anim_target in a:
			var anim = anim_player.get_animation(a)
			if anim:
				return anim.length
	return 1.0
