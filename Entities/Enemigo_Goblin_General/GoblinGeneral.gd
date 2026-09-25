class_name GoblinGeneral
extends "res://System/Core/EnemyBase.gd"

## Goblin General: Variante de élite que entra corriendo a alta velocidad,
## puede rodar durante la carrera para evadir flechas normales (siendo vulnerable solo
## a flechas cargadas y explosivas mientras rueda), y desata un ataque definitivo de
## 2 flechas dispersas cada 6 disparos.

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTES Y RECURSOS
# ═══════════════════════════════════════════════════════════════════════════════

const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")
const GoblinGirlArrowProjectile = preload("res://Entities/Proyectil_Flecha_Goblin_Girl/GoblinGirlArrow.gd")
const TEXTURA_HUMO_PISADAS: Texture2D = preload("res://VFX/Textures/Smoke/Humo_Pisadas_1A-1.png")
const HUMO_PISADAS_FRAMES_H: int = 9
const HUMO_PISADAS_FRAMES_V: int = 1
const DISPAROS_PARA_ULT: int = 6

const EnemyProjectileBaseRef = preload("res://System/Core/EnemyProjectileBase.gd")

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════

@export_category("Movimiento - Goblin General")
@export var velocidad_correr: float = 2.2  ## Velocidad de avance corriendo (mayor a GoblinGirl)
@export var velocidad_rodar: float = 2.8   ## Velocidad de avance al rodar
@export_range(0.1, 1.0, 0.05) var frenado_final_rodar: float = 0.35  ## Fracción final con frenado en seco

@export_category("Evasión - Rodar")
@export var tiempo_entre_rodadas_min: float = 0.8
@export var tiempo_entre_rodadas_max: float = 1.8
@export var probabilidad_rodar: float = 0.85
@export var duracion_rodar_override: float = -1.0  ## -1 para usar duración de la animación "Rodar"

@export_category("Combate - Goblin General")
@export var tiempo_inicio_tensa_normal: float = 0.55  ## Momento en que la mano izquierda alcanza la cuerda en animación 'disparo'
@export var tiempo_disparo_normal: float = 1.052      ## Momento exacto en que la cuerda alcanza máxima tensión y suelta la flecha en 'disparo'
@export var tiempo_inicio_tensa_ult: float = 3.17     ## Momento en que la mano izquierda toma la cuerda en la animación 'Ult' (inicio del gesto rápido de tensado)
@export var tiempo_cuerda_tensa_ult: float = 3.40     ## Momento en que la cuerda alcanza máxima tensión junto con la mano (3.40s) y se mantiene durante el apuntado
@export var tiempo_disparo_ult: float = 3.70          ## Momento exacto en que suelta la flecha del Ult a máxima tensión (3.70s, frame de suelta)
@export var pausa_entre_disparos: float = 0.95        ## Pausa entre ciclos de disparo (ligeramente reducida velocidad de ataque)
@export var pausa_recuperacion_post_ult: float = 0.6  ## Breve asentamiento tras el follow-through del Ult antes de retomar el ritmo normal (sin congelar el frame)
@export var potencia_disparo_min: float = 1.1
@export var potencia_disparo_max: float = 2.1
@export var radio_buff_arqueras_ult: float = 25.0       ## Radio en metros para bufar arqueras goblin con el Ult
@export var duracion_buff_arqueras: float = 10.0        ## Duración en segundos del bufo a las arqueras (10s)
@export var multiplicador_cadencia_arqueras: float = 3.0 ## Multiplicador de velocidad de ataque para arqueras (el triple)

@export_category("Drops")
@export var power_up_fuego_rapido_scene: PackedScene = preload("res://Entities/Item_Fuego_Rapido/PowerUpFuegoRapido.tscn")
@export_range(0.0, 1.0, 0.01) var probabilidad_drop_fuego_rapido: float = 0.03  ## 3% de probabilidad de drop de Fuego Rápido al morir

@export_category("Efectos Muerte")
@export var tamano_charco_sangre: Vector2 = Vector2(1.2, 1.2)
@export var vida_charco_sangre: float = 8.0

@export_category("Visual - Flecha en Mano")
@export var mostrar_flecha_en_mano: bool = true
@export var escala_flecha_disparo: Vector3 = Vector3(0.7865, 0.7865, 0.7865)

@export_category("Apuntado Orgánico Torso")
@export var velocidad_apuntado_torso: float = 7.0

# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES DE ESTADO
# ═══════════════════════════════════════════════════════════════════════════════

var esta_rodando: bool = false
var contador_disparos: int = 0
var en_animacion_ult: bool = false
var anim_timer: float = 0.0
var has_fired_this_cycle: bool = false
var ha_iniciado_tensado: bool = false
var _mano_visible_ult: bool = false
var _mano_tintada: bool = false
var _recupero_post_ult: bool = false
var _drop_realizado: bool = false
var murio_por_explosion: bool = false
var _impulso_explosivo_activo: bool = false
var _timer_proxima_rodada: float = 1.0
var _duracion_rodar: float = 1.66
var _tiempo_ultimo_fallaste: float = -10.0

# Variables de articulación del torso (Spine1 y Spine2 distribuidos como el jugador)
var spine1_bone_idx: int = -1
var spine2_bone_idx: int = -1
var _current_pitch: float = 0.0
var _aim_weight: float = 0.0

# Referencias específicas
var goblin_girl_arrow_scene: PackedScene = preload("res://Entities/Proyectil_Flecha_Goblin_Girl/GoblinGirlArrow.tscn")
var bow_anim_player: AnimationPlayer = null
var flecha_visual_mano: Node3D = null
var _pose_base_flecha_mano: Transform3D = Transform3D.IDENTITY
var _particulas_pisada: GPUParticles3D = null

# ═══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN (HOOKS ENEMYBASE)
# ═══════════════════════════════════════════════════════════════════════════════

func _on_enemy_ready() -> void:
	color_borde_disolucion = Color(0.8, 0.2, 0.8)  # Morado de muerte del General
	vida_maxima = 1
	health = vida_maxima

	# Distancia efectiva similar al Goblin ballestero (avanzar más cerca de la torre)
	distancia_minima_caminar = 3.0
	distancia_maxima_caminar = 9.0
	target_walk_distance = randf_range(distancia_minima_caminar, distancia_maxima_caminar)

	# Rango de apuntado vertical para seguir al jugador en la torre
	angulo_apuntado_minimo = -65.0
	angulo_apuntado_maximo = 45.0

	_configurar_flecha_visual_mano()
	_actualizar_visibilidad_flecha_mano(false)

	# Localizar vértebras del torso para distribuir curvatura natural
	if skeleton:
		spine1_bone_idx = skeleton.find_bone("mixamorig_Spine1")
		spine2_bone_idx = skeleton.find_bone("mixamorig_Spine2")
		if spine1_bone_idx == -1:
			spine1_bone_idx = skeleton.find_bone("mixamorig_Spine")
		spine_bone_idx = spine1_bone_idx

	# Buscar AnimationPlayer del arco
	var bow_node := find_child("ARCO_GOBLING_GIRL", true, false)
	if bow_node:
		var bow_players := bow_node.find_children("*", "AnimationPlayer", true, false)
		if not bow_players.is_empty():
			bow_anim_player = bow_players[0] as AnimationPlayer

	# Verificar que anim_player es el del personaje principal
	if anim_player and not _has_main_animation(anim_player):
		var all_players := find_children("*", "AnimationPlayer", true, false)
		for p in all_players:
			var ap := p as AnimationPlayer
			if ap != bow_anim_player and _has_main_animation(ap):
				anim_player = ap
				break

	# Configurar loop en animación de correr
	if anim_player and anim_player.has_animation("Correr"):
		var a_correr := anim_player.get_animation("Correr")
		if a_correr:
			a_correr.loop_mode = Animation.LOOP_LINEAR

	_duracion_rodar = _get_animation_duration("Rodar")
	if duracion_rodar_override > 0.0:
		_duracion_rodar = duracion_rodar_override

	_timer_proxima_rodada = randf_range(tiempo_entre_rodadas_min, tiempo_entre_rodadas_max)

	_play_animation("Correr")
	_play_bow_animation("ARCO_IDLE")
	_configurar_particulas_pisada()
	set_process(true)


func _configurar_particulas_pisada() -> void:
	if _particulas_pisada and is_instance_valid(_particulas_pisada):
		return
	_particulas_pisada = GPUParticles3D.new()
	_particulas_pisada.name = "Particulas_Pisada"
	_particulas_pisada.emitting = false
	_particulas_pisada.amount = 12
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
	mesh.size = Vector2(0.45, 0.45)
	_particulas_pisada.draw_pass_1 = mesh

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 45.0
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.35
	pm.gravity = Vector3(0.0, 0.15, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 0.9
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.1, 0.015, 0.1)
	pm.anim_speed_min = 1.0
	pm.anim_speed_max = 1.0

	var grad := Gradient.new()
	grad.set_color(0, Color(0.6, 0.55, 0.5, 0.7))
	grad.set_color(1, Color(0.6, 0.55, 0.5, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pm.color_ramp = grad_tex
	_particulas_pisada.process_material = pm


func _particulas_pisada_emitir() -> void:
	if not _particulas_pisada or not is_instance_valid(_particulas_pisada):
		return
	var corriendo := (current_state == State.WALKING or velocity.length_squared() > 0.04) and not esta_rodando
	_particulas_pisada.emitting = corriendo and current_state != State.DYING and current_state != State.DEAD


# ═══════════════════════════════════════════════════════════════════════════════
# CICLO PRINCIPAL (PROCESS & FSM)
# ═══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	super._process(delta)
	if _particulas_pisada:
		_particulas_pisada_emitir()
	_actualizar_apuntado_torso(delta)


func _on_state_walking() -> void:
	esta_rodando = false
	_actualizar_visibilidad_flecha_mano(false)
	_play_animation("Correr", 0.2)
	_play_bow_animation("ARCO_IDLE", 0.2)


func _process_walking(delta: float) -> void:
	if modo_pacifico:
		velocity.x = -velocidad_correr
		walked_distance += velocidad_correr * delta
		if global_position.x <= limite_pacifico_x:
			velocity.x = 0
			if not pacifico_detenido:
				pacifico_detenido = true
				_on_pacifico_detenido()
		return

	# Límite infranqueable de la isla enemiga (borde izquierdo) o borde de plataforma
	var limite_izq: float = _obtener_limite_izquierdo_x()
	var en_borde_plataforma: bool = evitar_caer_plataformas and is_on_floor() and not hay_suelo_adelante(-1.0)
	if (limite_izq != -INF and global_position.x <= limite_izq) or en_borde_plataforma:
		velocity.x = 0
		if limite_izq != -INF:
			global_position.x = max(global_position.x, limite_izq)
		if esta_rodando:
			_terminar_rodar()
		_change_state(State.SHOOTING)
		return

	# Lógica de rodar durante la carrera con aceleración integrada
	if esta_rodando:
		if evitar_caer_plataformas and is_on_floor() and not hay_suelo_adelante(-1.0):
			velocity.x = 0
			_terminar_rodar()
			_change_state(State.SHOOTING)
			return
		var restante: float = clampf(1.0 - anim_timer / maxf(_duracion_rodar, 0.01), 0.0, 1.0)
		var objetivo: float = -velocidad_rodar * clampf(restante / frenado_final_rodar, 0.0, 1.0)
		velocity.x = move_toward(velocity.x, objetivo, delta * 14.0)
		walked_distance += absf(velocity.x) * delta
		anim_timer += delta
		if anim_timer >= _duracion_rodar:
			_terminar_rodar()
		return

	# Carrera normal hacia la posición de combate con aceleración suave
	velocity.x = move_toward(velocity.x, -velocidad_correr, delta * 14.0)
	walked_distance += absf(velocity.x) * delta

	# Temporizador para activar una voltereta (rodar)
	_timer_proxima_rodada -= delta
	if _timer_proxima_rodada <= 0.0:
		_timer_proxima_rodada = randf_range(tiempo_entre_rodadas_min, tiempo_entre_rodadas_max)
		if randf() <= probabilidad_rodar and walked_distance < (target_walk_distance - 0.5):
			_iniciar_rodar()
			return

	# Llegó a su distancia objetivo de tiro
	if walked_distance >= target_walk_distance:
		if _check_spacing():
			velocity.x = 0
			_change_state(State.SHOOTING)
		else:
			if global_position.x - 0.3 > limite_izq:
				target_walk_distance += 0.3
			else:
				velocity.x = 0
				_change_state(State.SHOOTING)


func _iniciar_rodar() -> void:
	esta_rodando = true
	anim_timer = 0.0
	# Transición suave (crossfade 0.22s) para entrar en el giro sin tosquedad
	_play_animation("Rodar", 0.22)
	AudioManager.play_sfx("rodar_goblin")
	_play_bow_animation("ARCO_IDLE", 0.2)
	_actualizar_visibilidad_flecha_mano(false)


func _terminar_rodar() -> void:
	esta_rodando = false
	anim_timer = 0.0
	VFXFactory.spawn_shield_break_smoke(self, global_position + Vector3(0.0, 0.1, 0.0))
	var limite_izq: float = _obtener_limite_izquierdo_x()
	if global_position.x <= limite_izq:
		velocity.x = 0
		global_position.x = max(global_position.x, limite_izq)
		_change_state(State.SHOOTING)
	elif walked_distance >= target_walk_distance:
		velocity.x = 0
		_change_state(State.SHOOTING)
	else:
		# Transición suave (crossfade 0.22s) al reanudar la carrera
		_play_animation("Correr", 0.22)


## Apuntado orgánico del torso hacia el jugador/defensoras, similar a la protagonista y aliadas.
## Distribuye la flexión entre Spine1 y Spine2 para una curvatura suave y natural.
func _actualizar_apuntado_torso(delta: float) -> void:
	if not skeleton:
		return

	# Si terminó la animación del Ult y está en la breve recuperación, mantener la pose estable
	if en_animacion_ult and anim_timer >= _get_animation_duration("Ult"):
		return

	var apuntar_activo: bool = (
		current_state == State.SHOOTING
		and rastrear_jugador
		and not esta_rodando
		and current_state != State.DYING
		and current_state != State.DEAD
	)

	if apuntar_activo:
		_aim_weight = move_toward(_aim_weight, 1.0, delta * 5.0)
	else:
		_aim_weight = move_toward(_aim_weight, 0.0, delta * 7.0)

	if _aim_weight <= 0.001:
		if spine1_bone_idx != -1:
			skeleton.set_bone_global_pose_override(spine1_bone_idx, Transform3D.IDENTITY, 0.0, false)
		if spine2_bone_idx != -1:
			skeleton.set_bone_global_pose_override(spine2_bone_idx, Transform3D.IDENTITY, 0.0, false)
		_current_pitch = 0.0
		return

	var target_pitch: float = 0.0
	if apuntar_activo:
		var my_pos: Vector3 = global_position + Vector3(0.0, 0.5, 0.0)
		var target_pos: Vector3 = _obtener_punto_mira_disparo(0.5)
		var dy: float = target_pos.y - my_pos.y
		var dx: float = absf(target_pos.x - my_pos.x)
		var angle_to_target: float = atan2(dy, maxf(dx, 0.1))

		# Inclinación: -angle_to_target orienta la columna hacia arriba en el rig
		target_pitch = -angle_to_target
		target_pitch = clampf(target_pitch, deg_to_rad(-65.0), deg_to_rad(30.0))

		# Sutil variación orgánica / respiración al tensar el arco
		var sway: float = sin(Time.get_ticks_msec() * 0.001 * 2.5) * deg_to_rad(0.8)
		target_pitch += sway

	var smooth_factor: float = 1.0 - exp(-velocidad_apuntado_torso * delta)
	_current_pitch = lerpf(_current_pitch, target_pitch, smooth_factor)

	# Distribuir la curvatura entre ambas vértebras con ponderación de blend
	var half_pitch: float = _current_pitch * 0.5
	var pitch_rot := Quaternion(Vector3.RIGHT, half_pitch)
	var pitch_basis := Basis(pitch_rot)

	if spine1_bone_idx != -1 and spine2_bone_idx != -1:
		skeleton.set_bone_global_pose_override(spine1_bone_idx, Transform3D.IDENTITY, 0.0, false)
		var pose1: Transform3D = skeleton.get_bone_global_pose(spine1_bone_idx)
		skeleton.set_bone_global_pose_override(
			spine1_bone_idx, Transform3D(pitch_basis * pose1.basis, pose1.origin), _aim_weight, false
		)

		skeleton.set_bone_global_pose_override(spine2_bone_idx, Transform3D.IDENTITY, 0.0, false)
		var pose2: Transform3D = skeleton.get_bone_global_pose(spine2_bone_idx)
		skeleton.set_bone_global_pose_override(
			spine2_bone_idx, Transform3D(pitch_basis * pose2.basis, pose2.origin), _aim_weight, false
		)
	elif spine1_bone_idx != -1:
		var full_pitch_basis := Basis(Quaternion(Vector3.RIGHT, _current_pitch))
		skeleton.set_bone_global_pose_override(spine1_bone_idx, Transform3D.IDENTITY, 0.0, false)
		var pose1: Transform3D = skeleton.get_bone_global_pose(spine1_bone_idx)
		skeleton.set_bone_global_pose_override(
			spine1_bone_idx, Transform3D(full_pitch_basis * pose1.basis, pose1.origin), _aim_weight, false
		)


func _track_player() -> void:
	# Manejado de manera fluida y continua en _actualizar_apuntado_torso()
	pass


# ═══════════════════════════════════════════════════════════════════════════════
# ESTADO SHOOTING & ATAQUE DEFINITIVO (ULT)
# ═══════════════════════════════════════════════════════════════════════════════

func _on_state_shooting() -> void:
	velocity.x = 0
	esta_rodando = false
	anim_timer = 0.0
	has_fired_this_cycle = false
	ha_iniciado_tensado = false
	_mano_visible_ult = false

	if not puede_atacar():
		_play_bow_animation("ARCO_IDLE", 0.1)
		_actualizar_visibilidad_flecha_mano(false)
		if anim_player and anim_player.has_animation("Idle"):
			_play_animation("Idle", 0.2)
		else:
			_play_animation("Correr", -1.0, 0.0)
		return

	# El 6º disparo es el Ataque Definitivo (Ult)
	en_animacion_ult = (contador_disparos + 1) >= DISPAROS_PARA_ULT
	shoot_timer = pausa_recuperacion_post_ult if en_animacion_ult else pausa_entre_disparos
	_recupero_post_ult = false
	if en_animacion_ult:
		_play_animation("Ult", 0.2)
		AudioManager.play_sfx("ult_goblin_general")
	else:
		_play_animation("disparo", 0.2)

	# El arco inicia en reposo y la flecha oculta hasta que la mano alcance la cuerda
	_play_bow_animation("ARCO_IDLE", 0.1)
	_actualizar_visibilidad_flecha_mano(false)


func _process_shooting(delta: float) -> void:
	velocity.x = 0

	if not puede_atacar():
		_actualizar_visibilidad_flecha_mano(false)
		_play_bow_animation("ARCO_IDLE", 0.1)
		return

	if anim_timer == 0.0 and not ha_iniciado_tensado and anim_player and anim_player.current_animation != "disparo" and anim_player.current_animation != "Ult":
		en_animacion_ult = (contador_disparos + 1) >= DISPAROS_PARA_ULT
		shoot_timer = pausa_recuperacion_post_ult if en_animacion_ult else pausa_entre_disparos
		_recupero_post_ult = false
		if en_animacion_ult:
			_play_animation("Ult", 0.2)
			AudioManager.play_sfx("ult_goblin_general")
		else:
			_play_animation("disparo", 0.2)

	anim_timer += delta

	var tiempo_inicio_tensa: float = tiempo_inicio_tensa_ult if en_animacion_ult else tiempo_inicio_tensa_normal
	var tiempo_disparo: float = tiempo_disparo_ult if en_animacion_ult else tiempo_disparo_normal
	var tiempo_cuerda_tensa: float = tiempo_disparo
	if en_animacion_ult:
		# La cuerda acompaña el gesto rápido de la mano (3.17→3.40) y se mantiene
		# en máxima tensión durante el apuntado (3.40→3.70), en vez de seguir
		# tensándose mientras la mano ya está quieta. En disparo normal la cuerda
		# sigue llegando a tope justo en la suelta (como antes).
		tiempo_cuerda_tensa = clampf(tiempo_cuerda_tensa_ult, tiempo_inicio_tensa + 0.05, tiempo_disparo - 0.05)
	var anim_nombre: String = "Ult" if en_animacion_ult else "disparo"
	var duracion_anim: float = _get_animation_duration(anim_nombre)

	# Inicio del tensado coordinado exactamente cuando la mano toma la cuerda
	if not ha_iniciado_tensado and anim_timer >= tiempo_inicio_tensa and anim_timer < tiempo_disparo:
		ha_iniciado_tensado = true
		var duracion_tensado: float = maxf(tiempo_cuerda_tensa - tiempo_inicio_tensa, 0.05)
		var duracion_anim_arco: float = _duracion_anim_arco("ARCO_TENSAR")
		if duracion_anim_arco <= 0.0:
			duracion_anim_arco = 1.29166
		var velocidad_tensar: float = duracion_anim_arco / duracion_tensado
		# Entrada más suave en el Ult (blend 0.18) para que el tirón no se vea brusco
		var blend_tensar: float = 0.18 if en_animacion_ult else 0.05
		_play_bow_animation("ARCO_TENSAR", blend_tensar, velocidad_tensar)
		_actualizar_visibilidad_flecha_mano(true)

	# Cuerda en espera a máxima tensión (solo Ult): congelar la pose de tensado
	# hasta la suelta para que no siga moviéndose durante el apuntado.
	if en_animacion_ult and ha_iniciado_tensado and not has_fired_this_cycle and anim_timer >= tiempo_cuerda_tensa:
		if bow_anim_player and bow_anim_player.is_playing() and "TENSAR" in str(bow_anim_player.current_animation):
			bow_anim_player.pause()

	# Flecha en mano gobernada por ventana cada frame (igual que GoblinGirl):
	# visible desde que la mano toma la cuerda hasta la suelta. Se re-aplica
	# siempre para que ningún reordenamiento la deje oculta a mitad del gesto.
	var debe_mostrar_flecha: bool = (
		anim_timer >= tiempo_inicio_tensa
		and anim_timer < tiempo_disparo
		and not has_fired_this_cycle
	)
	if flecha_visual_mano and is_instance_valid(flecha_visual_mano) and flecha_visual_mano.visible != debe_mostrar_flecha:
		_actualizar_visibilidad_flecha_mano(debe_mostrar_flecha)

	# Momento exacto de soltar flecha(s)
	if not has_fired_this_cycle and anim_timer >= tiempo_disparo:
		has_fired_this_cycle = true
		if en_animacion_ult:
			_disparar_ult()
			contador_disparos = 0
		else:
			_disparar_flecha_normal()
			contador_disparos += 1
		_soltar_cuerda_arco()
		_actualizar_visibilidad_flecha_mano(false)

	# Transición de regreso a reposo del arco tras el chasquido del disparo
	if has_fired_this_cycle and anim_timer >= (tiempo_disparo + 0.12):
		if bow_anim_player and bow_anim_player.current_animation != "":
			if "DISPARO" in bow_anim_player.current_animation:
				_play_bow_animation("ARCO_IDLE", 0.1)

	# Ciclo completo de la animación: al terminar el follow-through natural del Ult
	# (sin congelar el último frame) se descuenta una breve recuperación y se
	# enlaza suave con el siguiente ciclo de disparo.
	if anim_timer >= duracion_anim:
		shoot_timer -= delta
		if shoot_timer <= 0.0:
			_on_state_shooting()


func _soltar_cuerda_arco() -> void:
	_play_bow_animation("ARCO_DISPARO", -1.0, 1.5)
	if bow_anim_player and bow_anim_player.current_animation != "":
		bow_anim_player.seek(0.166, true)


func _disparar_flecha_normal() -> void:
	if not puede_atacar():
		return
	if not goblin_girl_arrow_scene:
		return
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return
	if player_ref.get("is_dead"):
		return

	var spawn_pos: Vector3 = _obtener_spawn_pos()
	var target_pos: Vector3 = _obtener_punto_mira_disparo(0.5)
	var diff: Vector3 = target_pos - spawn_pos
	var base_direction: Vector3 = diff.normalized()

	var horizontal_dist: float = absf(diff.x)
	var arc_compensation: float = clampf(horizontal_dist * 0.15, 0.1, 0.5)
	var direction: Vector3 = Vector3(base_direction.x, base_direction.y + arc_compensation, 0.0).normalized()
	var potencia: float = randf_range(potencia_disparo_min, potencia_disparo_max)

	_instanciar_y_lanzar_flecha(spawn_pos, direction, potencia)
	AudioManager.play_sfx("goblin_girl_shoot")


func _disparar_ult() -> void:
	if not puede_atacar():
		return
	if not goblin_girl_arrow_scene:
		return
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return
	if player_ref.get("is_dead"):
		return

	# Ahora el Ult dispara una flecha normal
	_disparar_flecha_normal()

	# Aplica el buff de frenesí a las arqueras goblin cercanas (3x cadencia por 10s)
	_aplicar_buff_arqueras_cercanas()

	# Screen shake o feel especial para el Ult
	if game_feel and game_feel.has_method("on_player_shoot"):
		game_feel.on_player_shoot()


func _aplicar_buff_arqueras_cercanas() -> void:
	if not is_inside_tree():
		return
	var enemigos: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for nodo in enemigos:
		if not is_instance_valid(nodo) or nodo == self:
			continue
		if nodo is GoblinGirl or nodo.has_method("aplicar_buff_frenesi"):
			var dist: float = global_position.distance_to((nodo as Node3D).global_position)
			if dist <= radio_buff_arqueras_ult:
				if nodo.has_method("aplicar_buff_frenesi"):
					nodo.aplicar_buff_frenesi(duracion_buff_arqueras, multiplicador_cadencia_arqueras)


func _instanciar_y_lanzar_flecha(spawn_pos: Vector3, direction: Vector3, potencia: float) -> void:
	var arrow := PROJECTILE_POOL_REF.acquire(goblin_girl_arrow_scene) as GoblinGirlArrowProjectile
	if not arrow:
		return

	arrow.scale = escala_flecha_disparo
	arrow.color_proyectil = GoblinGirlArrowProjectile.GOBLIN_GIRL_ARROW_MAGENTA
	arrow.initialize(direction, potencia)
	arrow.set_meta("shooter", self)
	PROJECTILE_POOL_REF.activate(arrow, get_tree().root, spawn_pos)


func _obtener_spawn_pos() -> Vector3:
	var arco := find_child("ARCO_GOBLING_GIRL", true, false) as Node3D
	if arco and is_instance_valid(arco):
		return arco.global_position
	if flecha_visual_mano and is_instance_valid(flecha_visual_mano) and flecha_visual_mano.visible:
		return flecha_visual_mano.global_position
	return global_position + Vector3(-0.4, altura_spawn_flecha, 0.0)


# ═══════════════════════════════════════════════════════════════════════════════
# SISTEMA DE EVASIÓN E INMUNIDAD (INTERACCIÓN CON FLECHAS)
# ═══════════════════════════════════════════════════════════════════════════════

## Devuelve true si el proyectil fue repelido / evadido sin daño.
## Mientras rueda: flechas normales son repelidas (true).
## Solo flechas cargadas (sobrecarga_max) y explosivas (es_explosiva) penetran (false).
func manejar_impacto_aura(flecha: Node) -> bool:
	if not esta_rodando:
		return false

	# 1. Flechas cargadas (sobrecarga morada al 100%) impactan y pueden matarlo
	if is_instance_valid(flecha):
		if flecha.has_meta("sobrecarga_max") and bool(flecha.get_meta("sobrecarga_max")):
			return false

	# 2. Flechas explosivas o ult de Perrena penetran y detonan
	if is_instance_valid(flecha):
		if ("es_explosiva" in flecha and bool(flecha.get("es_explosiva"))) or ("es_hacha_especial" in flecha and bool(flecha.get("es_hacha_especial"))) or (flecha.has_meta("es_explosiva") and bool(flecha.get_meta("es_explosiva"))):
			return false

	# 3. Flecha normal durante la voltereta: la atraviesa sin daño y sale "Fallaste"
	if is_instance_valid(flecha) and flecha.has_method("set_meta"):
		flecha.set_meta("atravesar_rodando", true)
	_mostrar_texto_fallaste()
	return false


## Texto flotante blanco FALLASTE (como el CRITICO de la moradita): sube y se desvanece.
func _mostrar_texto_fallaste() -> void:
	if get_tree() == null:
		return
	var ahora: float = Time.get_ticks_msec() / 1000.0
	if ahora - _tiempo_ultimo_fallaste < 0.5:
		return
	_tiempo_ultimo_fallaste = ahora
	AudioManager.play_sfx("fallar")
	var lbl := Label3D.new()
	lbl.text = tr("Fallaste")
	lbl.font_size = 48
	lbl.pixel_size = 0.003
	lbl.modulate = Color(1.0, 1.0, 1.0, 1.0)
	lbl.outline_size = 0
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	raiz.add_child(lbl)
	lbl.global_position = global_position + Vector3(0.0, 2.0, 0.0)
	var tw := lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 0.6, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_LINEAR)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(lbl):
			lbl.queue_free()
	)


func take_damage(amount: float) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	# Si está rodando, solo acepta daño de flecha explosiva, sobrecarga o daño masivo/crítico
	if esta_rodando:
		var es_explosiva: bool = murio_por_explosion
		var es_dano_alto_o_cargado: bool = amount >= 2.0
		if not es_explosiva and not es_dano_alto_o_cargado:
			# Las flechas normales no le impactan mientras rueda
			return

	en_animacion_ult = false
	_actualizar_visibilidad_flecha_mano(false)
	super.take_damage(amount)


# ═══════════════════════════════════════════════════════════════════════════════
# MUERTE & EFECTOS EXPLOSIVOS
# ═══════════════════════════════════════════════════════════════════════════════

func _on_state_dying() -> void:
	esta_rodando = false
	super._on_state_dying()
	_spawn_blood_splash()
	_actualizar_visibilidad_flecha_mano(false)
	_dropear_power_up()
	AudioManager.play_sfx("goblin_girl_death")

	if murio_por_explosion:
		_aplicar_impulso_explosivo()
		_lanzar_arco_explosivo()
		_crear_charco_sangre()
		murio_por_explosion = false

	var death_anims: Array[String] = ["muerte", "muerte 2"]
	var chosen_death: String = death_anims[randi() % death_anims.size()]
	var anim_length: float = _get_animation_duration(chosen_death)
	_play_animation(chosen_death)

	get_tree().create_timer(anim_length + 0.5).timeout.connect(
		func() -> void:
			if is_instance_valid(self) and is_inside_tree():
				_die()
	)


func _dropear_power_up() -> void:
	# Nivel del río: sin drops, solo la vasija contenedora otorga power-ups
	if EnemyBase.drops_bloqueados_en_nivel(get_tree()):
		return
	if _drop_realizado:
		return
	_drop_realizado = true

	if not power_up_fuego_rapido_scene:
		return

	if randf() > probabilidad_drop_fuego_rapido:
		return

	var power_up := power_up_fuego_rapido_scene.instantiate() as Node3D
	if not power_up:
		return

	var target_parent: Node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else (get_tree().root if get_tree() else null)
	if not target_parent and get_parent():
		target_parent = get_parent()
	if target_parent:
		target_parent.add_child(power_up)
		power_up.global_position = global_position + Vector3(0.0, 0.4, 0.0)


func _aplicar_impulso_explosivo() -> void:
	_impulso_explosivo_activo = true
	set_physics_process(true)
	collision_layer = 0
	collision_mask = 1

	var push_dir: float = 1.0
	if last_hit_position != Vector3.ZERO:
		var dx: float = global_position.x - last_hit_position.x
		if absf(dx) > 0.05:
			push_dir = signf(dx)

	velocity.x = push_dir * randf_range(1.6, 2.4)
	velocity.y = randf_range(2.0, 2.8)
	velocity.z = 0.0


func _process_dying(delta: float) -> void:
	if not _impulso_explosivo_activo:
		velocity.x = 0
		return

	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 0.8)


## Charco de sangre en el piso al morir por flecha explosiva: la misma mancha
## del Imp (Mancha_Sangre_Suelo con desvanecido en el tiempo).
func _crear_charco_sangre() -> void:
	VFXFactory.spawn_ground_blood_splatter(
		self, global_position, Color(0.85, 0.3, 1.0, 0.95),
		tamano_charco_sangre, vida_charco_sangre, 2.5
	)


func _lanzar_arco_explosivo() -> void:
	var arco := find_child("ArcoGoblinGirl", true, false) as Node3D
	if arco == null:
		arco = find_child("ARCO_GOBLING_GIRL", true, false) as Node3D
	if arco == null:
		return

	var root_scene := get_tree().current_scene
	if not root_scene:
		root_scene = get_tree().root

	var push_dir: float = 1.0
	if last_hit_position != Vector3.ZERO:
		var dx: float = global_position.x - last_hit_position.x
		if absf(dx) > 0.05:
			push_dir = signf(dx)

	var tr_arco: Transform3D = arco.global_transform
	arco.get_parent().remove_child(arco)

	var contenedor := GoblinPiezaFisica.new()
	root_scene.add_child(contenedor)
	contenedor.global_transform = tr_arco

	arco.transform = Transform3D.IDENTITY
	arco.visible = true
	for m in arco.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.visible = true
		mi.material_override = null
	contenedor.add_child(arco)

	contenedor.iniciar_vuelo(
		Vector3(push_dir * randf_range(2.0, 3.6), randf_range(3.8, 5.6), 0.0),
		randf_range(-14.0, 14.0)
	)


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS DE ANIMACIÓN Y ARCO
# ═══════════════════════════════════════════════════════════════════════════════

func _has_main_animation(player: AnimationPlayer) -> bool:
	if not player:
		return false
	var list := player.get_animation_list()
	return ("Correr" in list or "disparo" in list or "Ult" in list)


## Duración real de una animación del arco (misma resolución que _play_bow_animation).
func _duracion_anim_arco(anim_name: String) -> float:
	if bow_anim_player == null:
		return 0.0
	var prefixes: Array[String] = ["", "ENEMY|", "ENEMY| ", "Recurve Bow 2 Armature|"]
	for prefix in prefixes:
		var full_name: String = prefix + anim_name
		if bow_anim_player.has_animation(full_name):
			return bow_anim_player.get_animation(full_name).length
	for a in bow_anim_player.get_animation_list():
		if anim_name in a:
			return bow_anim_player.get_animation(a).length
	return 0.0


func _play_bow_animation(anim_name: String, custom_blend: float = -1.0, custom_speed: float = 1.0) -> void:
	if not bow_anim_player:
		return
	var prefixes: Array[String] = ["", "ENEMY|", "ENEMY| ", "Recurve Bow 2 Armature|"]
	for prefix in prefixes:
		var full_name: String = prefix + anim_name
		if bow_anim_player.has_animation(full_name):
			bow_anim_player.play(full_name, custom_blend, custom_speed)
			return
	for a in bow_anim_player.get_animation_list():
		if anim_name in a:
			bow_anim_player.play(a, custom_blend, custom_speed)
			return


func _configurar_flecha_visual_mano() -> void:
	flecha_visual_mano = find_child("FlechaMano", true, false) as Node3D
	if flecha_visual_mano:
		_pose_base_flecha_mano = flecha_visual_mano.transform


func _actualizar_visibilidad_flecha_mano(p_visible: bool) -> void:
	if flecha_visual_mano and is_instance_valid(flecha_visual_mano):
		flecha_visual_mano.visible = p_visible
		if p_visible:
			flecha_visual_mano.transform = _pose_base_flecha_mano
			_teñir_flecha_mano_magenta()


## Tiñe la flecha de la mano del mismo magenta brillante exacto que las disparadas, con contorno negro unshaded.
func _teñir_flecha_mano_magenta() -> void:
	if _mano_tintada:
		return
	if not flecha_visual_mano or not is_instance_valid(flecha_visual_mano):
		return
	var mat: StandardMaterial3D = EnemyProjectileBaseRef._get_shared_projectile_material(
		GoblinGirlArrowProjectile.GOBLIN_GIRL_ARROW_MAGENTA, 3.0, 20.0
	)
	for m in flecha_visual_mano.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null:
			continue
		mi.material_override = mat
	_mano_tintada = true
