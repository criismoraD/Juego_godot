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
@export var es_movil: bool = false  ## Defensora móvil asignada a plataformas (no refuerza escudos, suelta ballesta al morir)
@export var es_mensajera: bool = false  ## Mensajera temporal que entrega items y se retira
@export var plano_profundidad_z: float = 0.02  ## Plano Z prioritario frente a arqueras aliadas
var en_despliegue: bool = false  ## Bloquea la FSM de combate y apuntado mientras camina o escala hacia su puesto
var plataforma_asignada: int = 1  ## Plataforma a la que fue asignada la defensora móvil

@export_category("Vida")
@export var vida_maxima: int = 4  ## 4 de vida para la ballestera defensora

@export_category("Disparo y Cadencia")
@export var velocidad_virote: float = 24.0  ## Virotes rápidos directos
@export var tiempo_carga_min: float = 0.8  ## Cadencia más lenta y pausada
@export var tiempo_carga_max: float = 1.3
@export var tiempo_recarga: float = 0.6
@export var altura_spawn_flecha: float = 0.95
@export var punto_pose_disparo: float = 0.35  ## Fracción (0-1) de DISPARO_01 congelada como postura de apuntado al fijarse en el puesto
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
var dissolve_shader: Shader = preload("res://System/Shaders/dissolve.gdshader")

const TEXTURA_HUMO_PISADAS: Texture2D = preload("res://VFX/Textures/Smoke/Humo_Pisadas_1A-1.png")
const TEXTURA_ICONO_ATURDIMIENTO: Texture2D = preload("res://UI/Icons/Icono_aturdimiento.png")
const HUMO_PISADAS_FRAMES_H: int = 9
const HUMO_PISADAS_FRAMES_V: int = 1
const PUEDE_ATACAR_INTERVAL: float = 0.1

var _puede_atacar_timer: float = 0.0
var _puede_atacar_cached: bool = false
var _particulas_pisada: GPUParticles3D = null
var _sfx_correr: AudioStreamPlayer = null  ## Loop de armadura mientras corre
const SONIDO_CORRER_ARMADURA: String = "res://TEST_/sonido_correr_armadura.wav"
const VOLUMEN_CORRER_DB: float = 8.0  ## Fuente muy silenciosa (RMS 0.7%): +8 dB audible sin saturar

var anim_player: AnimationPlayer
var skeleton: Skeleton3D
var model_root: Node3D
var hitbox_body: StaticBody3D
var _original_model_y_rot: float = 0.0
var ultima_muerte_anim: String = ""

# ═══════════════════════════════════════════════════════════════════════════════
# ESTADO Y CICLO DE DISPARO
# ═══════════════════════════════════════════════════════════════════════════════
var _icono_aturdimiento: Sprite3D = null
var _icono_aturdimiento_tween: Tween = null

var current_state: State = State.IDLE
var state_timer: float = 0.0
var _blink_timer: float = 0.0
var charge_duration: float = 0.0
var health: int = 4
var paralisis_timer: float = 0.0  ## Tiempo restante de parálisis (4 segundos sin atacar)
var _paralisis_vfx_timer: float = 0.0
var _impacto_timer: float = 0.0
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
	_configurar_particulas_pisada()
	_configurar_sonido_correr()

	var _sombra := SombraPersonaje.new()
	add_child(_sombra)

	if is_zero_approx(global_position.z):
		global_position.z = plano_profundidad_z
	_aplicar_prioridad_renderizado(2.0)

	call_deferred("_vincular_escudo_piso")
	call_deferred("_conectar_eventos_oleada")
	call_deferred("_iniciar")


func _aplicar_prioridad_renderizado(offset: float) -> void:
	for node in find_children("*", "VisualInstance3D", true, false):
		if node is VisualInstance3D:
			node.sorting_offset = offset


func _configurar_particulas_pisada() -> void:
	if _particulas_pisada and is_instance_valid(_particulas_pisada):
		return
	_particulas_pisada = GPUParticles3D.new()
	_particulas_pisada.name = "Particulas_Pisada"
	_particulas_pisada.emitting = false
	_particulas_pisada.amount = 8
	_particulas_pisada.lifetime = 0.8
	_particulas_pisada.visibility_aabb = AABB(Vector3(-1, -0.2, -1), Vector3(2, 1.5, 2))
	add_child(_particulas_pisada)
	_particulas_pisada.position = Vector3(0, 0.05, 0)

	var mat := StandardMaterial3D.new()
	if TEXTURA_HUMO_PISADAS:
		mat.albedo_texture = TEXTURA_HUMO_PISADAS
		mat.particles_anim_h_frames = HUMO_PISADAS_FRAMES_H
		mat.particles_anim_v_frames = HUMO_PISADAS_FRAMES_V
		mat.particles_anim_loop = false
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.render_priority = 2

	var mesh := QuadMesh.new()
	mesh.material = mat
	mesh.size = Vector2(0.3276, 0.3276)
	_particulas_pisada.draw_pass_1 = mesh

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 50.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0.0, 0.1, 0.0)
	pm.scale_min = 0.4
	pm.scale_max = 0.657
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.08, 0.01, 0.08)
	pm.anim_speed_min = 1.0
	pm.anim_speed_max = 1.0
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0

	var grad := Gradient.new()
	grad.set_color(0, Color(0.5, 0.5, 0.5, 0.6))
	grad.set_color(1, Color(0.5, 0.5, 0.5, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pm.color_ramp = grad_tex

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.25), 0.0, 1.2)
	curve.add_point(Vector2(0.3, 1.0), 0.2, -0.4)
	curve.add_point(Vector2(0.65, 0.6), -0.6, -0.8)
	curve.add_point(Vector2(1.0, 0.0), -1.2, 0.0)
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	pm.scale_curve = curve_tex

	_particulas_pisada.process_material = pm


func _particulas_pisada_emitir() -> void:
	if not _particulas_pisada or not is_instance_valid(_particulas_pisada):
		return
	var corriendo := en_despliegue or (anim_player and anim_player.current_animation.contains("CORRER"))
	_particulas_pisada.emitting = corriendo and current_state != State.DYING and current_state != State.DEAD and paralisis_timer <= 0.0


## Loop de sonido de armadura mientras la ballestera corre (entrada y retirada).
func _configurar_sonido_correr() -> void:
	if _sfx_correr and is_instance_valid(_sfx_correr):
		return
	var stream: AudioStream = load(SONIDO_CORRER_ARMADURA)
	if not stream:
		return
	_sfx_correr = AudioStreamPlayer.new()
	_sfx_correr.name = "SfxCorrerArmadura"
	_sfx_correr.stream = stream
	_sfx_correr.volume_db = VOLUMEN_CORRER_DB
	_sfx_correr.bus = "Master"
	_sfx_correr.add_to_group("pausable_audio")
	add_child(_sfx_correr)


## Enciende o apaga el loop según si está corriendo (anim CORRER).
func _actualizar_sonido_correr() -> void:
	if not _sfx_correr or not is_instance_valid(_sfx_correr):
		return
	var corriendo: bool = (
		(anim_player and anim_player.current_animation.contains("CORRER"))
		and current_state != State.DYING
		and current_state != State.DEAD
	)
	if corriendo and not _sfx_correr.playing:
		_sfx_correr.play()
	elif not corriendo and _sfx_correr.playing:
		_sfx_correr.stop()


func _exit_tree():
	AllyArcher.active_allies_cache.erase(self)


func _iniciar():
	_importar_animaciones_jugador()
	if anim_player:
		anim_player.active = true
	if not en_despliegue:
		_cambiar_estado(State.IDLE)
	set_process(true)


func _conectar_eventos_oleada() -> void:
	var spawner = _get_cached_wave_spawner()
	if spawner and spawner.has_signal("oleada_completada"):
		if not spawner.oleada_completada.is_connected(_on_oleada_completada):
			spawner.oleada_completada.connect(_on_oleada_completada)


func _on_oleada_completada(_numero_oleada: int) -> void:
	if not _puede_celebrar():
		return
	if es_movil:
		# Las defensoras moviles festejan y luego se retiran
		if current_state != State.DYING and current_state != State.DEAD:
			_loops_victoria_restantes = randi_range(repeticiones_victoria_min, repeticiones_victoria_max)
			_cambiar_estado(State.CELEBRATING)
			# Esperar que termine la celebracion completa antes de retirarse
			# (duración del clip REAL en loop, no el valor export fijo)
			var dur_clip_victoria: float = maxf(_get_anim_length("VICTORIA"), 0.3)
			var duracion_festejo: float = dur_clip_victoria * float(_loops_victoria_restantes) + 0.5
			await get_tree().create_timer(duracion_festejo).timeout
		if is_instance_valid(self) and current_state != State.DYING and current_state != State.DEAD:
			retirarse_y_bajar_escaleras()
	else:
		celebrar_victoria()


func celebrar_victoria() -> void:
	# Solo festeja si está activa, visible y viva (nada de risas fuera de pantalla)
	if not _puede_celebrar():
		return
	_loops_victoria_restantes = randi_range(repeticiones_victoria_min, repeticiones_victoria_max)
	_cambiar_estado(State.CELEBRATING)


## True si la defensora está activa, visible y viva para festejar y sonar
func _puede_celebrar() -> bool:
	if not is_inside_tree() or not visible:
		return false
	if not is_processing() and not is_physics_processing():
		return false
	if current_state == State.DYING or current_state == State.DEAD:
		return false
	if health <= 0:
		return false
	return true


func probar_animacion_victoria() -> void:
	celebrar_victoria()


func _vincular_escudo_piso() -> void:
	if es_movil or es_mensajera:
		_escudo_piso_ref = null
		_tiene_escudo_frente = false
		return

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

	_generar_poses_apuntado()


## Genera poses estáticas continuas para apuntar de pie y agachada a partir
## de los clips de disparo, permitiendo crossfades suaves sin congelar AnimationMixer.
func _generar_poses_apuntado() -> void:
	if not anim_player:
		return
	_extraer_pose_estatica("DISPARO_01", "POSE_APUNTAR", punto_pose_disparo)
	_extraer_pose_estatica("DISPARO_AGACHADO", "POSE_APUNTAR_AGACHADO", 0.0)


func _extraer_pose_estatica(origen_nombre: String, destino_nombre: String, ratio_tiempo: float) -> void:
	if not anim_player:
		return
	var anim_fuente: Animation = null
	var lib_fuente: AnimationLibrary = null

	for lib_name in anim_player.get_animation_library_list():
		var lib: AnimationLibrary = anim_player.get_animation_library(lib_name)
		if not lib:
			continue
		for anim_name in lib.get_animation_list():
			var an_str := str(anim_name).to_lower()
			if an_str == origen_nombre.to_lower() or an_str.ends_with("/" + origen_nombre.to_lower()):
				anim_fuente = lib.get_animation(anim_name)
				lib_fuente = lib
				break
		if anim_fuente:
			break

	if not anim_fuente or not lib_fuente:
		return
	if lib_fuente.has_animation(destino_nombre):
		return

	var t_muestra: float = clampf(ratio_tiempo, 0.0, 1.0) * anim_fuente.length
	var pose := Animation.new()
	pose.length = 1.0
	pose.loop_mode = Animation.LOOP_LINEAR

	for track_idx in range(anim_fuente.get_track_count()):
		var path := anim_fuente.track_get_path(track_idx)
		var type := anim_fuente.track_get_type(track_idx)
		var new_track := pose.add_track(type)
		pose.track_set_path(new_track, path)
		pose.track_set_interpolation_type(new_track, Animation.INTERPOLATION_LINEAR)

		var count := anim_fuente.track_get_key_count(track_idx)
		if count == 0:
			continue
		var best_k := 0
		for k in range(count):
			if anim_fuente.track_get_key_time(track_idx, k) <= t_muestra:
				best_k = k
			else:
				break
		var val = anim_fuente.track_get_key_value(track_idx, best_k)
		pose.track_insert_key(new_track, 0.0, val)
		pose.track_insert_key(new_track, 1.0, val)

	lib_fuente.add_animation(destino_nombre, pose)


func _crear_hitbox():
	hitbox_body = StaticBody3D.new()
	hitbox_body.name = "HitboxBody"
	hitbox_body.add_to_group("allies")
	hitbox_body.set_meta("defensora_owner", self)  ## Permite a los proyectiles aplicar estados sobre la defensora dueña de esta hitbox
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
	if _puede_atacar_timer > 0.0:
		_puede_atacar_timer -= delta
	if _particulas_pisada:
		_particulas_pisada_emitir()
	_actualizar_sonido_correr()
	if current_state == State.DYING or current_state == State.DEAD:
		_restaurar_torso()
		_ocultar_icono_aturdimiento()
		if _sfx_correr and _sfx_correr.playing:
			_sfx_correr.stop()
		return

	if en_despliegue:
		_restaurar_torso()
		return

	if _impacto_timer > 0.0:
		_impacto_timer -= delta
		_restaurar_torso()
		if _impacto_timer <= 0.0:
			_impacto_timer = 0.0
			if current_state != State.DYING and current_state != State.DEAD:
				_cambiar_estado(current_state)
		return

	if paralisis_timer > 0.0:
		paralisis_timer -= delta
		_restaurar_torso()
		if _icono_aturdimiento and _icono_aturdimiento.visible:
			var t := Time.get_ticks_msec() / 1000.0
			_icono_aturdimiento.position.y = 3.6 + sin(t * 3.8) * 0.12
		if paralisis_timer <= 0.0:
			paralisis_timer = 0.0
			_ocultar_icono_aturdimiento()
			_play_anim(["IDLE", "IDLE_001"], 0.25)
		else:
			_paralisis_vfx_timer += delta
			_mantener_anim_electrocutada()

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
	# Apuntado visual del torso hacia el objetivo activo o elevación natural
	if paralisis_timer <= 0.0 and current_state != State.CELEBRATING:
		_actualizar_apuntado_torso(delta)


## Aplica el estado de parálisis/aturdimiento por la duración indicada (4s por defecto):
## No es acumulable (debe pasar el efecto para volver a aplicarse).
## No puede atacar, reproduce animación ELECTROCUTADA, muestra el icono flotante de aturdimiento y restaura el torso.
func aplicar_paralisis(duracion: float = 4.0) -> void:
	if current_state == State.DYING or current_state == State.DEAD or esta_paralizada() or paralisis_timer > 0.0:
		return
	paralisis_timer = duracion
	_restaurar_torso()
	if _sfx_correr and _sfx_correr.playing:
		_sfx_correr.stop()
	# Cambiar a IDLE PRIMERO para que su handler no pise la electrocución
	if current_state != State.IDLE and current_state != State.GETTING_UP and current_state != State.CELEBRATING:
		_cambiar_estado(State.IDLE)
	_configurar_electrocutada_loop()
	_play_anim(["ELECTROCUTAR", "ELECTROCUTADA"], 0.15, 1.0)
	_mostrar_icono_aturdimiento()


func _setup_icono_aturdimiento() -> void:
	if _icono_aturdimiento:
		return

	_icono_aturdimiento = Sprite3D.new()
	_icono_aturdimiento.name = "IconoAturdimiento"
	_icono_aturdimiento.texture = TEXTURA_ICONO_ATURDIMIENTO
	_icono_aturdimiento.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icono_aturdimiento.pixel_size = 0.0016
	_icono_aturdimiento.shaded = false
	_icono_aturdimiento.no_depth_test = true
	_icono_aturdimiento.render_priority = 12
	_icono_aturdimiento.position = Vector3(0.0, 3.6, 0.1)  # Flota claramente por encima de la cabeza
	_icono_aturdimiento.modulate = Color(0.25, 1.2, 0.35, 0.0)  # Color verde brillante
	_icono_aturdimiento.visible = false
	add_child(_icono_aturdimiento)


func _mostrar_icono_aturdimiento() -> void:
	_setup_icono_aturdimiento()
	if not _icono_aturdimiento:
		return

	_icono_aturdimiento.visible = true
	if _icono_aturdimiento_tween and _icono_aturdimiento_tween.is_valid():
		_icono_aturdimiento_tween.kill()

	_icono_aturdimiento.scale = Vector3.ZERO
	_icono_aturdimiento.modulate = Color(0.25, 1.2, 0.35, 0.0)

	_icono_aturdimiento_tween = create_tween()
	_icono_aturdimiento_tween.set_parallel(true)
	_icono_aturdimiento_tween.tween_property(_icono_aturdimiento, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_icono_aturdimiento_tween.tween_property(_icono_aturdimiento, "modulate:a", 1.0, 0.18)


func _ocultar_icono_aturdimiento() -> void:
	if not _icono_aturdimiento or not _icono_aturdimiento.visible:
		return

	if _icono_aturdimiento_tween and _icono_aturdimiento_tween.is_valid():
		_icono_aturdimiento_tween.kill()

	_icono_aturdimiento_tween = create_tween()
	_icono_aturdimiento_tween.set_parallel(true)
	_icono_aturdimiento_tween.tween_property(_icono_aturdimiento, "scale", Vector3.ZERO, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_icono_aturdimiento_tween.tween_property(_icono_aturdimiento, "modulate:a", 0.0, 0.18)
	_icono_aturdimiento_tween.chain().tween_callback(func():
		if is_instance_valid(_icono_aturdimiento):
			_icono_aturdimiento.visible = false
	)


func esta_paralizada() -> bool:
	return paralisis_timer > 0.0


## Pone el clip ELECTROCUTADA en LOOP para que el aturdimiento (4s) se vea
## continuo y no se congele al terminar el clip
func _configurar_electrocutada_loop() -> void:
	if not anim_player:
		return
	for a in anim_player.get_animation_list():
		if "electrocut" in String(a).to_lower():
			var anim := anim_player.get_animation(a)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			return


## Reanuda suave la electrocución si otro estado la pisó (impacto, celebración):
## solo re-dispara si el clip actual no es de electrocución.
func _mantener_anim_electrocutada() -> void:
	if not anim_player:
		return
	var actual: String = str(anim_player.current_animation).to_lower()
	if "electrocut" not in actual:
		_play_anim(["ELECTROCUTAR", "ELECTROCUTADA"], 0.25, 1.0)


func _actualizar_rotacion_modelo(delta: float) -> void:
	if not model_root:
		return

	var target_y_rot: float = _original_model_y_rot
	if current_state == State.CELEBRATING:
		target_y_rot = _original_model_y_rot + deg_to_rad(rotacion_victoria_grados)

	model_root.rotation.y = lerp_angle(model_root.rotation.y, target_y_rot, 1.0 - exp(-velocidad_giro_victoria * delta))


func _actualizar_apuntado_torso(delta: float) -> void:
	if not skeleton or paralisis_timer > 0.0 or _impacto_timer > 0.0:
		_restaurar_torso()
		return

	if current_state == State.DYING or current_state == State.DEAD or current_state == State.CELEBRATING or current_state == State.RELOADING:
		_restaurar_torso()
		return

	# Actualizar o refrescar objetivo prioritario
	if not is_instance_valid(objetivo_actual) or _es_enemigo_muerto(objetivo_actual):
		objetivo_actual = _obtener_objetivo_prioritario()

	var target_pitch: float = 0.0
	if is_instance_valid(objetivo_actual) and not _es_objetivo_azar_ballestera(objetivo_actual):
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
			_cambiar_estado(State.AIMING)
		else:
			state_timer = 0.6


func _process_reloading(delta: float):
	state_timer -= delta
	if state_timer <= 0:
		_cambiar_estado(State.AIMING)


func _process_aiming(delta: float):
	state_timer -= delta
	if state_timer <= 0:
		if not _puede_atacar():
			state_timer = 0.25
			return
		# Prioridad 2 apuntada o, si solo hay hostiles de prioridad 0 (Lonko, voladores,
		# escudo, rosada con aura), disparo al azar en cualquier ángulo
		if not is_instance_valid(_obtener_objetivo_prioritario()) and not _hay_objetivo_azar():
			# Si no hay enemigos activos, mantenerse apuntando y en guardia sin disparar
			state_timer = 0.25
			return
		_disparar()
		_cambiar_estado(State.SHOOTING)


func _process_shooting(delta: float):
	state_timer -= delta
	if state_timer <= 0:
		_cambiar_estado(State.RELOADING)


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
			var _dur_clip: float = _get_anim_length("VICTORIA")
			state_timer = maxf(_dur_clip, 0.3)
			return
		_loops_victoria_restantes = 0
		# Defensoras moviles quedan en IDLE: el timer del await maneja la retirada
		# Defensoras fijas vuelven a apuntar directamente
		if es_movil or es_mensajera:
			_cambiar_estado(State.IDLE)
		else:
			_cambiar_estado(State.AIMING)


## Busca el clip VICTORIA real y lo configura en LOOP_LINEAR para que la
## celebración se repita sin cortes (el re-loop manual con blend cortaba el
## levantamiento de brazos a mitad, pareciendo que faltan frames).
func _configurar_victoria_loop() -> void:
	if not anim_player:
		return
	for a in anim_player.get_animation_list():
		if "victoria" in a.to_lower():
			var anim := anim_player.get_animation(a)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			return


func _cambiar_estado(nuevo: State):
	if nuevo != State.GETTING_UP and model_root:
		model_root.visible = true

	current_state = nuevo
	if en_despliegue and (nuevo == State.IDLE or nuevo == State.AIMING or nuevo == State.RELOADING or nuevo == State.SHOOTING):
		return

	match nuevo:
		State.IDLE:
			objetivo_actual = _obtener_objetivo_prioritario() if _puede_atacar() else null
			_fijar_pose_combate(0.35)
			state_timer = randf_range(idle_min, idle_max)
		State.RELOADING:
			objetivo_actual = _obtener_objetivo_prioritario()
			_reproducir_sonido_recarga()
			_restaurar_torso()
			_play_anim(["Recargar", "RECARGAR"], 0.15, 1.0)
			var dur_recarga: float = _get_anim_length("Recargar")
			state_timer = dur_recarga if dur_recarga > 0.1 else tiempo_recarga
		State.AIMING:
			if not is_instance_valid(objetivo_actual):
				objetivo_actual = _obtener_objetivo_prioritario()
			_fijar_pose_combate(0.25)
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
			# Victoria fluida: clip en LOOP (sin re-plays que cortan los brazos a mitad)
			_configurar_victoria_loop()
			_play_anim("VICTORIA", 0.25, 1.0)
			if _puede_celebrar():
				AudioManager.play_sfx("risa_victoria_ballestera")
			var _dur_clip: float = _get_anim_length("VICTORIA")
			state_timer = maxf(_dur_clip, 0.3)


func _fijar_pose_combate(blend_time: float = 0.25) -> void:
	if not anim_player:
		return
	if fase_agachada:
		_play_anim(["POSE_APUNTAR_AGACHADO", "DISPARO_AGACHADO"], blend_time, 1.0)
	else:
		_play_anim(["POSE_APUNTAR", "DISPARO_01"], blend_time, 1.0)



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
	if objetivo == null or _es_objetivo_azar_ballestera(objetivo):
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
	if es_movil or es_mensajera:
		return
	AudioManager.play_sfx("refuerzo_escudo")
	if _escudo_piso_ref and is_instance_valid(_escudo_piso_ref) and _escudo_piso_ref.is_inside_tree():
		if _escudo_piso_ref.has_method("activar_modo_metalico"):
			_escudo_piso_ref.activar_modo_metalico(2)
	else:
		_regenerar_escudo_piso()


func _regenerar_escudo_piso(forzar_enemigo: bool = false):
	## Solo regenera escudos aliados de piso; los escudos enemigos NUNCA se regeneran aquí
	## a menos que forzar_enemigo==true se indique explícitamente (ej. evento de oleada).
	if not escudo_scene:
		return

	var nuevo_escudo = escudo_scene.instantiate()
	# Seguridad: los escudos regenerados por la ballestera son siempre aliados salvo indicación explícita
	if "es_escudo_enemigo" in nuevo_escudo:
		if not forzar_enemigo and nuevo_escudo.es_escudo_enemigo:
			nuevo_escudo.es_escudo_enemigo = false
		elif forzar_enemigo:
			nuevo_escudo.es_escudo_enemigo = true
	if "golpes_para_destruir" in nuevo_escudo:
		nuevo_escudo.golpes_para_destruir = 1

	var parent = _escudo_piso_parent if is_instance_valid(_escudo_piso_parent) else get_parent()
	if parent:
		parent.add_child(nuevo_escudo)
		nuevo_escudo.global_transform = _escudo_piso_transform
		_escudo_piso_ref = nuevo_escudo

		if nuevo_escudo.has_method("_flash_dano"):
			nuevo_escudo._flash_dano()


## API explícita para regenerar un escudo enemigo en su nivel correspondiente (usar solo cuando el diseño lo indique)
func regenerar_escudo_enemigo_explicito() -> void:
	_regenerar_escudo_piso(true)


func _reproducir_sonido_recarga() -> void:
	AudioManager.play_sfx("recarga_ballesta")


func _reproducir_sonido_disparo() -> void:
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
	if _puede_atacar_timer > 0.0:
		return _puede_atacar_cached

	_puede_atacar_timer = PUEDE_ATACAR_INTERVAL

	var spawner = _get_cached_wave_spawner()
	var enemies: Array = []
	if spawner and spawner.has_method("get_active_enemies"):
		if "is_wave_active" in spawner and not spawner.is_wave_active:
			var hay_hostiles := false
			for e in spawner.get_active_enemies():
				if is_instance_valid(e) and not _es_pacifico_intacto(e) and not _es_enemigo_muerto(e) and not _es_imp_escudo(e):
					hay_hostiles = true
					break
			if not hay_hostiles:
				_puede_atacar_cached = false
				return false
		enemies = spawner.get_active_enemies()
	else:
		enemies = get_tree().get_nodes_in_group("enemies")

	var hostiles_activos: int = 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy is Node3D and enemy.global_position.x > global_position.x:
			if not _es_pacifico_intacto(enemy) and not _es_enemigo_muerto(enemy) and not _es_imp_escudo(enemy):
				hostiles_activos += 1
				if hostiles_activos >= enemigos_minimos:
					_puede_atacar_cached = true
					return true

	_puede_atacar_cached = false
	return false


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


## Clases: Voladores (Gárgola, Globo) / Básicos (Imp, Goblin arquero, Goblin ballestero) / Elite (Lonko, Rosada) / Guardian (Imp escudo)
## Ballestera: Voladores 0 (azar), Básicos 2 (fija y apunta), Elite 0 (Rosada sin aura 2), Guardian 0 (azar)
func _es_volador_ballestera(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	var n: String = enemy.name.to_lower()
	var s: String = enemy.get_script().resource_path.to_lower() if enemy.get_script() else ""
	return enemy.is_in_group("flying_enemies") or ("gargola" in n) or ("gargola" in s) or ("gargoyle" in n) or ("globo" in n) or ("globo" in s)

func _es_basico_ballestera(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	if _es_imp_escudo(enemy):
		return false
	var n: String = enemy.name.to_lower()
	var s: String = enemy.get_script().resource_path.to_lower() if enemy.get_script() else ""
	# Imp, Goblin arquero (GoblinGirl), Goblin ballestero (Goblin) y Limo cuadrado
	if "arquera_rosa" in n or "arquera_rosa" in s or "rosa" in n or "rosa" in s:
		return false
	if "lonko" in n or "lonko" in s:
		return false
	if _es_volador_ballestera(enemy):
		return false
	return ("imp" in n or "imp" in s or "goblin" in n or "goblin" in s or "limo" in n or "limo" in s)

func _es_rosada(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	var n: String = enemy.name.to_lower()
	var s: String = enemy.get_script().resource_path.to_lower() if enemy.get_script() else ""
	return "rosa" in n or "rosa" in s or "arquera_rosa" in n or "arquera_rosa" in s

func _es_rosada_sin_aura(enemy: Node) -> bool:
	if not _es_rosada(enemy):
		return false
	# aura_vida <=0 indica barrera rota (ver ArqueraRosa.gd)
	var vida = enemy.get("aura_vida")
	if vida is int or vida is float:
		return int(vida) <= 0
	# Fallback: si no expone aura_vida, considerar sin aura solo si el vfx no está visible
	var vfx = enemy.get("aura_vfx_node")
	if vfx is Node3D:
		return not vfx.visible
	return false

func _es_objetivo_azar_ballestera(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return true
	if _es_volador_ballestera(enemy):
		return true  # Voladores 0
	if _es_imp_escudo(enemy):
		return true  # Guardian 0
	if _es_rosada(enemy) and not _es_rosada_sin_aura(enemy):
		return true  # Rosada con aura 0
	var s: String = enemy.get_script().resource_path.to_lower() if enemy.get_script() else ""
	if "lonko" in enemy.name.to_lower() or "lonko" in s:
		return true  # Lonko 0 para ballestera
	return false


## Prioridad 0: hostiles que no merecen apuntado preciso (Lonko, voladores, guardianes,
## rosada con aura) pero ante los que la ballestera igual dispara al azar en cualquier ángulo.
func _hay_objetivo_azar() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not (enemy is Node3D) or not enemy.is_inside_tree():
			continue
		if enemy.global_position.x <= global_position.x:
			continue
		if _es_enemigo_muerto(enemy) or _es_pacifico_intacto(enemy):
			continue
		if _es_objetivo_azar_ballestera(enemy):
			return true
	return false


func _obtener_enemigos_terrestres_candidatos() -> Array[Node3D]:
	var candidatos: Array[Node3D] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not (enemy is Node3D) or not enemy.is_inside_tree():
			continue
		if _es_enemigo_muerto(enemy):
			continue
		if enemy.global_position.x <= global_position.x:
			continue
		if _es_pacifico_intacto(enemy):
			continue
		if _es_objetivo_azar_ballestera(enemy):
			continue
		# Solo Básicos 2 y Rosada sin aura 2
		if not (_es_basico_ballestera(enemy) or _es_rosada_sin_aura(enemy)):
			continue
		candidatos.append(enemy)
	return candidatos


func _obtener_objetivo_prioritario() -> Node3D:
	# Prioridad 2: Básicos y Rosada sin aura (ambos máxima)
	var candidatos := _obtener_enemigos_terrestres_candidatos()
	if candidatos.is_empty():
		return null
	# Todos los candidatos ya son prioridad 2, elegir el más cercano
	var mejor: Node3D = null
	var menor_dist: float = INF
	for enemy in candidatos:
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
		_impacto_timer = 0.0
		_cambiar_estado(State.DYING)
	else:
		_blink_timer = 0.0
		var dur: float = _get_anim_length("Impacto")
		_impacto_timer = dur if dur > 0.05 else 0.5
		_restaurar_torso()
		_play_anim(["Impacto", "IMPACTO"], 0.08, 1.0)
		if get_tree():
			get_tree().create_timer(_impacto_timer).timeout.connect(func():
				if not is_instance_valid(self):
					return
				if current_state == State.DYING or current_state == State.DEAD:
					return
				if _impacto_timer <= 0.05:
					_impacto_timer = 0.0
					_cambiar_estado(current_state)
			)


func take_damage(amount: int = 1):
	recibir_dano(amount)


func _on_dying():
	var muertes := ["MUERTE_01", "MUERTE02"]
	ultima_muerte_anim = muertes[randi() % muertes.size()]
	_play_anim(ultima_muerte_anim, 0.1)

	AudioManager.play_sfx("muerte_ballestera")

	if es_movil:
		_desprender_ballesta_fisica()
		_iniciar_desintegracion_celeste()
		return

	var dur = _get_anim_length(ultima_muerte_anim)
	get_tree().create_timer(dur + 0.1).timeout.connect(func():
		if is_instance_valid(self) and current_state == State.DYING:
			current_state = State.DEAD
	)


## Desprende la ballesta del modelo y la hace volar y rebotar físicamente en 2.5D
func _desprender_ballesta_fisica() -> void:
	var attachment = find_child("BoneAttachment3D", true, false)
	var ballesta: Node3D = null
	if attachment:
		ballesta = attachment.find_child("BALLES_GOBLING", true, false) as Node3D
		if not ballesta:
			ballesta = attachment.find_child("*ballest*", true, false) as Node3D
	if not ballesta:
		ballesta = find_child("BALLES_GOBLING", true, false) as Node3D

	if ballesta:
		var tr_ballesta: Transform3D = ballesta.global_transform
		if ballesta.get_parent():
			ballesta.get_parent().remove_child(ballesta)

		var cont_ballesta := GoblinPiezaFisica.new()
		var scene_root: Node = get_tree().current_scene if get_tree() else get_parent()
		if scene_root:
			scene_root.add_child(cont_ballesta)
			cont_ballesta.global_transform = tr_ballesta

			ballesta.transform = Transform3D.IDENTITY
			ballesta.visible = true
			for m in ballesta.find_children("*", "MeshInstance3D", true, false):
				m.visible = true
				m.material_override = null
			cont_ballesta.add_child(ballesta)

			cont_ballesta.iniciar_vuelo(
				Vector3(randf_range(-1.5, 1.5), randf_range(3.5, 5.5), 0.0),
				randf_range(-14.0, 14.0)
			)


## Inicia el efecto de desintegración con shader y partículas celestes idéntico al de los enemigos (GoblinGirl)
func _iniciar_desintegracion_celeste() -> void:
	var color_celeste := Color(0.25, 0.85, 1.0, 1.0)
	var duracion: float = 1.0

	# 1. Aplicar Shader de disolución a todos los MeshInstance3D del cuerpo
	var meshes: Array[Node] = []
	if model_root:
		meshes = model_root.find_children("*", "MeshInstance3D", true, false)
	else:
		meshes = find_children("*", "MeshInstance3D", true, false)

	var dissolve_mats: Array = []
	for node in meshes:
		if not is_instance_valid(node):
			continue
		if node.find_parent("BALLES_GOBLING") != null:
			continue
		var mi := node as MeshInstance3D
		var mat := ShaderMaterial.new()
		mat.shader = dissolve_shader
		mat.set_shader_parameter("dissolve_amount", 0.0)
		mat.set_shader_parameter("glow_color", color_celeste)
		mat.set_shader_parameter("glow_intensity", 4.0)
		mat.set_shader_parameter("edge_thickness", 0.05)
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

	# 2. Generar partículas de disolución idénticas a EnemyBase (GoblinGirl) en color celeste
	var p := GPUParticles3D.new()
	p.name = "ParticulasMuerteCeleste"
	p.amount = 180
	p.lifetime = 2.0
	p.one_shot = false
	p.explosiveness = 0.0
	p.randomness = 0.3

	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p_mat.emission_box_extents = Vector3(0.2, 0.5, 0.1)
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.spread = 20.0
	p_mat.initial_velocity_min = 0.1
	p_mat.initial_velocity_max = 1.0
	p_mat.gravity = Vector3(0, 0.1, 0)
	p_mat.scale_min = 0.5
	p_mat.scale_max = 1.5

	var gradient := Gradient.new()
	gradient.set_color(0, color_celeste)
	gradient.set_color(1, Color(color_celeste.r, color_celeste.g, color_celeste.b, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	p_mat.color_ramp = gradient_tex

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 0.2))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	p_mat.scale_curve = scale_tex

	p.process_material = p_mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.0125
	sphere.height = 0.025

	var part_mat := StandardMaterial3D.new()
	part_mat.albedo_color = color_celeste
	part_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	part_mat.emission_enabled = true
	part_mat.emission = color_celeste
	part_mat.emission_energy_multiplier = 4.0
	part_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	part_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = part_mat

	p.draw_pass_1 = sphere

	var scene_root: Node = get_tree().current_scene if get_tree() else get_parent()
	if scene_root:
		scene_root.add_child(p)
		p.global_position = global_position + Vector3(0, 0.4, 0)
		p.emitting = true
	else:
		add_child(p)
		p.position = Vector3(0, 0.4, 0)
		p.emitting = true

	# 3. Tween de disolución y finalización
	var tw := create_tween()
	tw.tween_method(
		func(val: float) -> void:
			for m in dissolve_mats:
				if is_instance_valid(m):
					m.set_shader_parameter("dissolve_amount", val),
		0.0, 1.0, duracion)

	# Detener emisión al 70% del tiempo
	if get_tree():
		get_tree().create_timer(duracion * 0.7).timeout.connect(func():
			if is_instance_valid(p):
				p.emitting = false
		)
		get_tree().create_timer(duracion + 2.0).timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free()
		)

	tw.finished.connect(queue_free)


## Genera un estallido de partículas celestes al morir la defensora móvil (legacy / fallback)
func _spawn_particulas_muerte_celeste() -> void:
	_iniciar_desintegracion_celeste()


## Importa animaciones de la protagonista (subir escaleras, correr, etc.) para utilizarlas en los desplazamientos
func _importar_animaciones_jugador() -> void:
	if not anim_player or not get_tree():
		return
	var prota = get_tree().get_first_node_in_group("player")
	if prota:
		var prota_ap: AnimationPlayer = null
		var all_prota_players = prota.find_children("*", "AnimationPlayer", true, false)
		for p in all_prota_players:
			var anims = p.get_animation_list()
			var is_character := false
			for a in anims:
				if a.begins_with("Recurve Bow") or "ARCO" in a:
					continue
				if "IDLE" in a or "DISPARO" in a or "TOMAR_FLECHA" in a or "CAMINAR" in a or "SUBIR" in a:
					is_character = true
					break
			if is_character:
				prota_ap = p
				break
		if not prota_ap:
			prota_ap = prota.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if prota_ap:
			for lib_name in prota_ap.get_animation_library_list():
				if "Recurve Bow" in lib_name or "ARCO" in lib_name:
					continue
				var lib = prota_ap.get_animation_library(lib_name)
				if lib and not anim_player.has_animation_library(lib_name):
					var has_bow := false
					for an in lib.get_animation_list():
						if "ARCO" in an or an.begins_with("Recurve Bow"):
							has_bow = true
							break
					if has_bow:
						continue
					anim_player.add_animation_library(lib_name, lib)
			for lib_name in anim_player.get_animation_library_list():
				if "Recurve Bow" in lib_name or "ARCO" in lib_name:
					anim_player.remove_animation_library(lib_name)

	# Asegurar looping en todas las animaciones de movimiento y escaleras (incluye CORRER para refuerzo)
	for a in anim_player.get_animation_list():
		var a_low := a.to_lower()
		if "caminar" in a_low or "escalera" in a_low or "escalar" in a_low or "run" in a_low or "walk" in a_low or "subir" in a_low or "correr" in a_low:
			var anim = anim_player.get_animation(a)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR


## Despliega a la ballestera móvil caminando y subiendo escaleras con la velocidad
## y forma natural de la protagonista (CAMINAR_01 para andar, SUBIR_ESCALERA para trepar).
func desplegar_a_plataforma(indice_plataforma: int, destino_x: float = NAN) -> void:
	es_movil = true
	en_despliegue = true
	plataforma_asignada = indice_plataforma
	vida_maxima = 2
	health = 2
	scale = Vector3(0.3, 0.3, 0.3)
	_setup_animation_player()
	_importar_animaciones_jugador()
	_restaurar_torso()

	var walk_speed: float = 1.7  ## Punto medio: igual que la mensajera (antes 2.4)
	var climb_speed: float = 1.1  ## Subida de llegada un poco más lenta

	# Alturas reales de piso y plataformas en el mundo (en el mismo plano Z = 0.0 que la protagonista)
	var floor_y: float = 0.185
	var p1_top_y: float = 1.585
	var p2_top_y: float = 3.143
	var p3_top_y: float = 4.60

	var p1_ladder_x: float = -7.58
	var p1_shoot_x: float = -7.25 if is_nan(destino_x) else destino_x

	var p2_ladder_x: float = -8.33
	var p2_shoot_x: float = -8.05 if is_nan(destino_x) else destino_x

	var p3_ladder_x: float = -9.11
	var p3_shoot_x: float = -8.85 if is_nan(destino_x) else destino_x

	global_position.y = floor_y
	if is_zero_approx(global_position.z):
		global_position.z = plano_profundidad_z

	# 1. Caminar por el suelo hacia la Escalera 1
	if model_root:
		model_root.rotation.y = _original_model_y_rot
	_play_anim("CORRER", 0.15, 1.0)

	var dist1: float = absf(p1_ladder_x - global_position.x)
	var tw1 := create_tween()
	tw1.tween_property(self, "global_position:x", p1_ladder_x, dist1 / walk_speed)
	await tw1.finished
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# 2. Subir Escalera 1 (espalda visible a la cámara con rotation.y = 0.0)
	if model_root:
		model_root.rotation.y = 0.0
	_play_anim(["SUbIR_ESCALERA", "SUBIR_ESCALERA", "Armature|Armature|SUBIR_ESCALERA", "ESCALAR"], 0.15, 1.0)

	var climb_dist1: float = absf(p1_top_y - global_position.y)
	var tw_climb1 := create_tween()
	tw_climb1.tween_property(self, "global_position:y", p1_top_y, climb_dist1 / climb_speed)
	await tw_climb1.finished
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# Desmontar escalera / paso suave en plataforma
	_play_anim(["EN_EL_AIRE", "CAMINAR_01"], 0.2, 1.0)
	await get_tree().create_timer(0.18).timeout
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	if indice_plataforma <= 1:
		# Posicionarse en Plataforma 1
		if model_root:
			model_root.rotation.y = _original_model_y_rot
		_play_anim("CORRER", 0.15, 1.0)
		var tw_pos := create_tween()
		tw_pos.tween_property(self, "global_position:x", p1_shoot_x, absf(p1_shoot_x - global_position.x) / walk_speed)
		await tw_pos.finished
		if is_instance_valid(self):
			_finalizar_despliegue_plataforma()
		return

	# 3. Caminar por Plataforma 1 hacia Escalera 2 (hacia la izquierda)
	if model_root:
		model_root.rotation.y = _original_model_y_rot + PI
	_play_anim("CORRER", 0.15, 1.0)
	var dist2: float = absf(p2_ladder_x - global_position.x)
	var tw2 := create_tween()
	tw2.tween_property(self, "global_position:x", p2_ladder_x, dist2 / walk_speed)
	await tw2.finished
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# 4. Subir Escalera 2 hasta Plataforma 2 (espalda visible a la cámara)
	if model_root:
		model_root.rotation.y = 0.0
	_play_anim(["SUbIR_ESCALERA", "SUBIR_ESCALERA", "Armature|Armature|SUBIR_ESCALERA", "ESCALAR"], 0.15, 1.0)
	var climb_dist2: float = absf(p2_top_y - global_position.y)
	var tw_climb2 := create_tween()
	tw_climb2.tween_property(self, "global_position:y", p2_top_y, climb_dist2 / climb_speed)
	await tw_climb2.finished
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# Desmontar escalera / paso suave en plataforma
	_play_anim(["EN_EL_AIRE", "CAMINAR_01"], 0.2, 1.0)
	await get_tree().create_timer(0.18).timeout
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	if indice_plataforma == 2:
		# Posicionarse en Plataforma 2
		if model_root:
			model_root.rotation.y = _original_model_y_rot
		_play_anim("CORRER", 0.15, 1.0)
		var tw_pos := create_tween()
		tw_pos.tween_property(self, "global_position:x", p2_shoot_x, absf(p2_shoot_x - global_position.x) / walk_speed)
		await tw_pos.finished
		if is_instance_valid(self):
			_finalizar_despliegue_plataforma()
		return

	# 5. Caminar por Plataforma 2 hacia Escalera 3 (hacia la izquierda)
	if model_root:
		model_root.rotation.y = _original_model_y_rot + PI
	_play_anim("CORRER", 0.15, 1.0)
	var dist3: float = absf(p3_ladder_x - global_position.x)
	var tw3 := create_tween()
	tw3.tween_property(self, "global_position:x", p3_ladder_x, dist3 / walk_speed)
	await tw3.finished
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# 6. Subir Escalera 3 hasta Plataforma 3 (la más alta, espalda visible a la cámara)
	if model_root:
		model_root.rotation.y = 0.0
	_play_anim(["SUbIR_ESCALERA", "SUBIR_ESCALERA", "Armature|Armature|SUBIR_ESCALERA", "ESCALAR"], 0.15, 1.0)
	var climb_dist3: float = absf(p3_top_y - global_position.y)
	var tw_climb3 := create_tween()
	tw_climb3.tween_property(self, "global_position:y", p3_top_y, climb_dist3 / climb_speed)
	await tw_climb3.finished
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# Desmontar escalera / paso suave en plataforma 3
	_play_anim(["EN_EL_AIRE", "CAMINAR_01"], 0.2, 1.0)
	await get_tree().create_timer(0.18).timeout
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# 7. Posicionarse en Plataforma 3 (la más alta)
	if model_root:
		model_root.rotation.y = _original_model_y_rot
	_play_anim("CORRER", 0.15, 1.0)
	var tw_pos3 := create_tween()
	tw_pos3.tween_property(self, "global_position:x", p3_shoot_x, absf(p3_shoot_x - global_position.x) / walk_speed)
	await tw_pos3.finished
	if is_instance_valid(self):
		_finalizar_despliegue_plataforma()


func _finalizar_despliegue_plataforma() -> void:
	# Mantener en_despliegue activo durante la secuencia de llegada para que
	# los frames del proceso de combate no interrumpan ni congelen la pose de carrera
	en_despliegue = true
	_restaurar_torso()

	if model_root:
		var tween_rot := create_tween()
		tween_rot.tween_property(model_root, "rotation:y", _original_model_y_rot, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 1. Agacharse una vez al llegar al puesto (baja y apoya la pierna de CORRER al suelo limpiamente)
	fase_agachada = true
	_play_anim(["DISPARO_AGACHADO", "AGACHARSE"], 0.25, 1.0)
	await get_tree().create_timer(0.55).timeout
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# 2. Levantarse suavemente hacia la postura de combate de pie
	fase_agachada = false
	disparos_en_fase = 0
	_play_anim("DISPARO_01", 0.3, 1.0)
	await get_tree().create_timer(0.25).timeout
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# 3. Adoptar la postura fija de combate y habilitar el ciclo de ataque
	_fijar_pose_combate(0.2)
	en_despliegue = false
	_cambiar_estado(State.RELOADING)
	state_timer = 0.3


## Al terminar la oleada, la defensora móvil baja las escaleras y se retira por donde vino
func retirarse_y_bajar_escaleras() -> void:
	if not es_movil or current_state == State.DYING or current_state == State.DEAD:
		return

	en_despliegue = true
	_restaurar_torso()
	_importar_animaciones_jugador()

	var walk_speed: float = 1.7  ## Igual que la llegada (punto medio unificado)
	var climb_speed: float = 1.4

	var floor_y: float = 0.185
	var p1_top_y: float = 1.585
	var p2_top_y: float = 3.143
	var p3_top_y: float = 4.60

	var p1_ladder_x: float = -7.58
	var p2_ladder_x: float = -8.33
	var p3_ladder_x: float = -9.11
	var exit_x: float = -14.0

	if plataforma_asignada >= 3:
		# 1. En Plataforma 3: caminar hacia la Escalera 3 (hacia la izquierda)
		if model_root:
			model_root.rotation.y = _original_model_y_rot + PI
		_play_anim("CORRER", 0.15, 1.0)
		var tw_to_l3 := create_tween()
		tw_to_l3.tween_property(self, "global_position:x", p3_ladder_x, absf(p3_ladder_x - global_position.x) / walk_speed)
		await tw_to_l3.finished
		if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
			return

		# 2. Bajar Escalera 3 de espaldas (rotation.y = 0.0)
		if model_root:
			model_root.rotation.y = 0.0
		_play_anim(["SUbIR_ESCALERA", "SUBIR_ESCALERA", "Armature|Armature|SUBIR_ESCALERA", "ESCALAR"], 0.15, 1.0)
		var tw_down3 := create_tween()
		tw_down3.tween_property(self, "global_position:y", p2_top_y, absf(p3_top_y - p2_top_y) / climb_speed)
		await tw_down3.finished
		if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
			return

		# Paso de transición en Plataforma 2
		_play_anim(["EN_EL_AIRE", "CAMINAR_01"], 0.2, 1.0)
		await get_tree().create_timer(0.18).timeout
		if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
			return

		# 3. En Plataforma 2: caminar hacia la Escalera 2 (hacia la derecha)
		if model_root:
			model_root.rotation.y = _original_model_y_rot
		_play_anim("CORRER", 0.15, 1.0)
		var tw_to_l2 := create_tween()
		tw_to_l2.tween_property(self, "global_position:x", p2_ladder_x, absf(p2_ladder_x - global_position.x) / walk_speed)
		await tw_to_l2.finished
		if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
			return

		# 4. Bajar Escalera 2 de espaldas (rotation.y = 0.0)
		if model_root:
			model_root.rotation.y = 0.0
		_play_anim(["SUbIR_ESCALERA", "SUBIR_ESCALERA", "Armature|Armature|SUBIR_ESCALERA", "ESCALAR"], 0.15, 1.0)
		var tw_down2 := create_tween()
		tw_down2.tween_property(self, "global_position:y", p1_top_y, absf(p2_top_y - p1_top_y) / climb_speed)
		await tw_down2.finished
		if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
			return

		# Paso de transición en Plataforma 1
		_play_anim(["EN_EL_AIRE", "CAMINAR_01"], 0.2, 1.0)
		await get_tree().create_timer(0.18).timeout
		if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
			return

		# 5. En Plataforma 1: caminar hacia la Escalera 1 (hacia la derecha)
		if model_root:
			model_root.rotation.y = _original_model_y_rot
		_play_anim("CORRER", 0.15, 1.0)
		var tw_to_l1 := create_tween()
		tw_to_l1.tween_property(self, "global_position:x", p1_ladder_x, absf(p1_ladder_x - global_position.x) / walk_speed)
		await tw_to_l1.finished
		if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
			return

		# 6. Bajar Escalera 1 de espaldas (rotation.y = 0.0)
		if model_root:
			model_root.rotation.y = 0.0
		_play_anim(["SUbIR_ESCALERA", "SUBIR_ESCALERA", "Armature|Armature|SUBIR_ESCALERA", "ESCALAR"], 0.15, 1.0)
		var tw_down1 := create_tween()
		tw_down1.tween_property(self, "global_position:y", floor_y, absf(p1_top_y - floor_y) / climb_speed)
		await tw_down1.finished
		if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
			return

	elif plataforma_asignada == 2:
		# En Plataforma 2: caminar a Escalera 2
		if model_root:
			model_root.rotation.y = _original_model_y_rot
		_play_anim("CORRER", 0.15, 1.0)
		var tw_to_l2 := create_tween()
		tw_to_l2.tween_property(self, "global_position:x", p2_ladder_x, absf(p2_ladder_x - global_position.x) / walk_speed)
		await tw_to_l2.finished
		if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
			return

		# Bajar Escalera 2 de espaldas
		if model_root:
			model_root.rotation.y = 0.0
		_play_anim(["SUbIR_ESCALERA", "SUBIR_ESCALERA", "Armature|Armature|SUBIR_ESCALERA", "ESCALAR"], 0.15, 1.0)
		var tw_down2 := create_tween()
		tw_down2.tween_property(self, "global_position:y", p1_top_y, absf(p2_top_y - p1_top_y) / climb_speed)
		await tw_down2.finished
		if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
			return

		_play_anim(["EN_EL_AIRE", "CAMINAR_01"], 0.2, 1.0)
		await get_tree().create_timer(0.18).timeout
		if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
			return

		# En Plataforma 1: caminar a Escalera 1
		if model_root:
			model_root.rotation.y = _original_model_y_rot
		_play_anim("CORRER", 0.15, 1.0)
		var tw_to_l1 := create_tween()
		tw_to_l1.tween_property(self, "global_position:x", p1_ladder_x, absf(p1_ladder_x - global_position.x) / walk_speed)
		await tw_to_l1.finished
		if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
			return

		# Bajar Escalera 1 de espaldas
		if model_root:
			model_root.rotation.y = 0.0
		_play_anim(["SUbIR_ESCALERA", "SUBIR_ESCALERA", "Armature|Armature|SUBIR_ESCALERA", "ESCALAR"], 0.15, 1.0)
		var tw_down1 := create_tween()
		tw_down1.tween_property(self, "global_position:y", floor_y, absf(p1_top_y - floor_y) / climb_speed)
		await tw_down1.finished
		if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
			return

	else:
		# En Plataforma 1: caminar hacia Escalera 1 (hacia la izquierda)
		if model_root:
			model_root.rotation.y = _original_model_y_rot + PI
		_play_anim("CORRER", 0.15, 1.0)
		var tw_to_l1 := create_tween()
		tw_to_l1.tween_property(self, "global_position:x", p1_ladder_x, absf(p1_ladder_x - global_position.x) / walk_speed)
		await tw_to_l1.finished
		if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
			return

		# Bajar Escalera 1 de espaldas
		if model_root:
			model_root.rotation.y = 0.0
		_play_anim(["SUbIR_ESCALERA", "SUBIR_ESCALERA", "Armature|Armature|SUBIR_ESCALERA", "ESCALAR"], 0.15, 1.0)
		var tw_down1 := create_tween()
		tw_down1.tween_property(self, "global_position:y", floor_y, absf(p1_top_y - floor_y) / climb_speed)
		await tw_down1.finished
		if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
			return

	# Paso de transición al llegar al suelo
	_play_anim(["EN_EL_AIRE", "CAMINAR_01"], 0.2, 1.0)
	await get_tree().create_timer(0.18).timeout
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# Caminar hacia la izquierda por donde vino y retirarse
	if model_root:
		model_root.rotation.y = _original_model_y_rot + PI
	_play_anim("CORRER", 0.15, 1.0)
	var tw_exit := create_tween()
	tw_exit.tween_property(self, "global_position:x", exit_x, absf(exit_x - global_position.x) / walk_speed)
	await tw_exit.finished
	if is_instance_valid(self):
		queue_free()


func curar(cantidad: int = 1) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return
	health = min(health + cantidad, vida_maxima)


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
		var cand_str := str(cand).to_lower()
		for a in all_anims:
			var a_str := a.to_lower()
			if a_str == cand_str or a_str.ends_with("/" + cand_str) or cand_str in a_str:
				anim_player.speed_scale = 1.0
				anim_player.play(a, blend, speed)
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


var speech_bubble: Node = null

## Muestra un diálogo en el globo de este personaje
func decir(clave_o_texto: String, duracion: float = -1.0) -> void:
	if not visible or current_state == State.DYING or current_state == State.DEAD or health <= 0:
		return
	if GameUI.es_dialogo_defensora_unico(clave_o_texto) and GameUI.dialogo_defensora_ya_dicho(clave_o_texto):
		return
	if not speech_bubble or not is_instance_valid(speech_bubble):
		speech_bubble = get_node_or_null("SpeechBubbleComponent")
	if not speech_bubble:
		var sb_scene = load("res://Components/Dialogue/SpeechBubbleComponent.tscn")
		if sb_scene:
			speech_bubble = sb_scene.instantiate()
			speech_bubble.name = "SpeechBubbleComponent"
			add_child(speech_bubble)
			if "offset_globo" in speech_bubble:
				speech_bubble.offset_globo = Vector3(0.0, 2.2, 0.0)
	if speech_bubble and is_instance_valid(speech_bubble):
		if GameUI.es_dialogo_defensora_unico(clave_o_texto):
			GameUI.marcar_dialogo_defensora_dicho(clave_o_texto)
		speech_bubble.decir(clave_o_texto, duracion)


## Retorna true si la ballestera está mostrando un diálogo
func esta_hablando() -> bool:
	if not speech_bubble or not is_instance_valid(speech_bubble):
		return false
	if speech_bubble.has_method("esta_hablando"):
		return speech_bubble.esta_hablando()
	return false
