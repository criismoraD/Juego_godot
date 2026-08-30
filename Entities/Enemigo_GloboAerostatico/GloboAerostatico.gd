class_name GloboAerostatico
extends "res://System/Core/EnemyBase.gd"

## Vehículo volador enemigo: globo aerostático goblin.
## Transporta una arquera goblin en el canasto con tamaño regular (idéntico a la versión a pie).
## Vuela a la altura de la Gárgola y posee bamboleo suave vía Tween.
## Patrón de vuelo: avanza lentamente, se detiene 18 s en el punto medio de la
## isla enemiga y continúa hasta el límite establecido para los enemigos.
## La arquera dispara con la animación Armature|GIRL_GOB_DISPARO mientras el
## globo avanza, con la misma fuerza y el mismo proyectil que GoblinGirl.
## 5 puntos de vida.

# ==============================================================================
# CONFIGURACIÓN
# ==============================================================================

@export_category("Vuelo - Globo")
## Alturas entre las que varía naturalmente el globo mientras avanza (igual que Gárgola)
@export var altura_spawn_baja: float = 3.3
@export var altura_spawn_alta: float = 5.2
## Amplitud de la oscilación vertical suave (metros)
@export var amplitud_oscilacion: float = 0.08
## Velocidad de la oscilación vertical (rad/s)
@export var velocidad_oscilacion: float = 0.9
## Velocidad de variación natural de altura entre baja y alta (rad/s) - 0 desactiva
@export var velocidad_variacion_altura: float = 0.35
## Duración de la pausa en el punto medio de la isla enemiga (segundos)
@export var pausa_isla_segundos: float = 18.0

@export_category("Bamboleo Visual - Globo")
## Ángulo máximo de balanceo en Z (grados) — simula viento
@export_range(1.0, 12.0, 0.5) var angulo_bamboleo_z: float = 4.5
## Período del bamboleo principal (segundos)
@export_range(1.5, 6.0, 0.1) var periodo_bamboleo: float = 3.2
## Deformación de escala X/Y (fracción de escala base, ej: 0.02 = +-2%)
@export_range(0.005, 0.05, 0.005) var deformacion_escala: float = 0.018
## Período de la deformación de escala (segundos, asimétrico al bamboleo)
@export_range(1.0, 5.0, 0.1) var periodo_deformacion: float = 2.1

@export_category("Combate - Globo")
## Tiempo de espera entre disparos (segundos)
@export var intervalo_disparo_globo: float = 2.8
## Tiempo de tensado/anticipación antes de soltar la flecha
@export var tiempo_tensado_arco: float = 0.7
## Potencia mínima de disparo (igual que GoblinGirl)
@export var potencia_disparo_min: float = 1.0
## Potencia máxima de disparo (igual que GoblinGirl)
@export var potencia_disparo_max: float = 2.0
## Dispersión del disparo en radianes (GoblinGirl no aplica dispersión: 0.0)
@export_range(0.0, 0.3, 0.01) var dispersion: float = 0.0
## Escala de la flecha disparada (igual que la flecha disparada por GoblinGirl: x1.10)
@export var escala_flecha_disparo: Vector3 = Vector3(1.1, 1.1, 1.1)

@export_category("Explosion - Globo")
## Cantidad de explosiones encadenadas al morir (como el pilar de Lonko)
@export_range(1, 5, 1) var cantidad_explosiones: int = 3
## Segundos entre explosión y explosión
@export var intervalo_explosiones: float = 0.7
## Escala de cada explosión VFX (el pilar de Lonko usa 0.75)
@export var escala_explosion: float = 0.75

@export_category("Drops")
@export var posion_scene: PackedScene = preload("res://Entities/Item_Pocion/Posion.tscn")
@export_range(0.0, 1.0, 0.01) var posion_drop_chance: float = 0.05
@export var power_up_multiple_scene: PackedScene = preload("res://Entities/Item_Flecha_Multiple/PowerUpFlechaMultiple.tscn")
@export_range(0.0, 1.0, 0.01) var multiple_drop_chance: float = 0.30

@export_category("Caída Destruido - Globo")
## Factor de gravedad durante la caída (menor = más lento). El normal es 0.35
@export_range(0.05, 0.5, 0.01) var gravedad_caida_destruido: float = 0.12
## Velocidad de deriva lateral hacia la derecha (m/s)
@export var deriva_lateral: float = 0.4
## Ángulo de inclinación en Z al caer (grados, positivo = derecha)
@export_range(5.0, 45.0, 1.0) var inclinacion_caida: float = 18.0
## Duración del tween de inclinación (segundos)
@export var duracion_inclinacion: float = 2.0
## Escala final del modelo destruido al desinflarse (fracción de la escala original) - sutil
@export_range(0.3, 0.95, 0.05) var escala_desinflado: float = 0.85
## Duración del tween de desinflado (segundos)
@export var duracion_desinflado: float = 2.5

# ==============================================================================
# ESTADO INTERNO
# ==============================================================================

enum FaseCombate { IDLE, TENSANDO, DISPARANDO }
## Fases del avance del globo: avanzar, pausa en el medio de la isla, detenido en el límite
enum FaseVuelo { AVANZANDO, PAUSA_ISLA, DETENIDO }

## Compensación de arco parabólico: valores idénticos a los de GoblinGirl
const ARC_COMPENSACION_DIST_MULT: float = 0.15
const ARC_COMPENSACION_MIN: float = 0.1
const ARC_COMPENSACION_MAX: float = 0.5
## Color del proyectil: idéntico al de la flecha de GoblinGirl
const COLOR_FLECHA: Color = GoblinGirlArrowProjectile.GOBLIN_GIRL_ARROW_MAGENTA

var _altura_base: float = 4.3
var _oscilacion_fase: float = 0.0
var _variacion_altura_fase: float = 0.0
var _fase_combate: FaseCombate = FaseCombate.IDLE
var _timer_combate: float = 0.0
var _ha_disparado: bool = false
var _fase_vuelo: FaseVuelo = FaseVuelo.AVANZANDO
var _timer_pausa_isla: float = 0.0
## X de partida del avance (spawn) para calcular el punto medio de la isla
var _x_inicio_avance: float = 0.0
## X donde el globo se detiene pausa_isla_segundos (punto medio del recorrido)
var _x_pausa_isla: float = 0.0
var _pausa_isla_preparada: bool = false

var _pivot_bamboleo: Node3D = null
var _tween_bamboleo: Tween = null
var _tween_deformacion: Tween = null

var _goblin_anim_player: AnimationPlayer = null
var _bow_anim_player: AnimationPlayer = null
var _punto_disparo: Node3D = null
var _modelo_globo_node: Node3D = null
var _modelo_canasta_node: Node3D = null  ## Referencia al nodo ModeloCanasta (Canasta.glb)
var _arquera_goblin_node: Node3D = null  ## Referencia al nodo ArqueraGoblin (GEO_GOBLIN_GIRL)
var murio_por_explosion: bool = false  ## Marcado por FlechaExplosiva: arquera es eyectada a la izquierda

# ==============================================================================
# RECURSOS
# ==============================================================================

var _escena_flecha: PackedScene = preload(
	"res://Entities/Proyectil_Flecha_Goblin_Girl/GoblinGirlArrow.tscn"
)
const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")

## VFX, SFX y textura de la explosión en cadena: idénticos a los del pilar de Lonko
const ALTURAS_RELATIVAS_EXPLOSION: Array[float] = [0.75, 0.45, 0.15]
## Alto del cuerpo del globo usado para repartir las explosiones (canasto a copa)
const ALTO_CUERPO_EXPLOSION: float = 1.6
const TEXTURA_PIEDRAS_NEGRAS_RES: Texture2D = preload(
	"res://Entities/Enemigo_Lonko/PIEDRAS_NEGRAS_ DESTRUCION.png"
)
var explocion_pilar_scene: PackedScene = preload("res://Entities/Enemigo_Lonko/Explocion_Pilar.tscn")
var sfx_explosion_01: AudioStream = preload("res://Entities/Enemigo_Lonko/EXPLOSION01.mp3")
var sfx_explosion_02: AudioStream = preload("res://Entities/Enemigo_Lonko/EXPLOSION02.mp3")
var sfx_globo_callendo: AudioStream = preload("res://TEST_/Sonido globo callendo.mp3")
var sfx_fuego1: AudioStream = preload("res://TEST_/Fuego1.mp3")

var _modelo_globo_destruido_node: Node3D = null

# ==============================================================================
# HOOKS DE ENEMYBASE
# ==============================================================================


func _on_enemy_ready() -> void:
	vida_maxima = 3
	health = 3
	rastrear_jugador = false
	tiene_sangre = false
	color_borde_disolucion = Color(0.8, 0.2, 0.8)

	# Altura inicial aleatoria entre baja y alta, luego varía naturalmente entre ambas
	if randf() < 0.5:
		_altura_base = altura_spawn_baja
	else:
		_altura_base = altura_spawn_alta

	_oscilacion_fase = randf() * TAU
	_variacion_altura_fase = randf() * TAU

	_buscar_nodos_visuales()
	_iniciar_tween_bamboleo()
	_iniciar_tween_deformacion()
	_poner_postura_idle()


func _on_state_walking() -> void:
	_fase_combate = FaseCombate.IDLE
	_timer_combate = 0.0
	_poner_postura_idle()


func _on_state_shooting() -> void:
	_fase_combate = FaseCombate.IDLE
	_timer_combate = randf_range(0.2, 0.6)
	_ha_disparado = false
	_fase_vuelo = FaseVuelo.DETENIDO
	_poner_postura_idle()


# ==============================================================================
# FÍSICA
# ==============================================================================


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	if current_state == State.DYING:
		# Caída lenta de globo desinflándose: gravedad reducida + deriva a la derecha
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta * gravedad_caida_destruido
		velocity.x = move_toward(velocity.x, deriva_lateral, delta * 0.8)
		velocity.z = 0.0
		move_and_slide()
		return

	# Altura varía naturalmente entre baja y alta mientras avanza + oscilación suave
	_oscilacion_fase += delta * velocidad_oscilacion
	if velocidad_variacion_altura > 0.0:
		_variacion_altura_fase += delta * velocidad_variacion_altura
		var t: float = (sin(_variacion_altura_fase) + 1.0) * 0.5
		_altura_base = lerp(altura_spawn_baja, altura_spawn_alta, t)
	velocity.y = 0.0
	velocity.z = 0.0
	global_position.y = _altura_base + sin(_oscilacion_fase) * amplitud_oscilacion

	match current_state:
		State.WALKING:
			_procesar_vuelo(delta)
			# La arquera dispara también mientras el globo avanza (y en la pausa media)
			if current_state == State.WALKING and not modo_pacifico:
				_procesar_combate(delta)
		State.SHOOTING:
			_procesar_combate(delta)

	_empujar_si_en_barrera()
	move_and_slide()


func _procesar_vuelo(delta: float) -> void:
	if modo_pacifico:
		velocity.x = -velocidad_caminar
		walked_distance += velocidad_caminar * delta
		if global_position.x <= limite_pacifico_x:
			velocity.x = 0.0
			if not pacifico_detenido:
				pacifico_detenido = true
				_on_pacifico_detenido()
		return

	var limite_izq: float = _obtener_limite_izquierdo_x()
	# Límite infranqueable de la isla enemiga: detenerse definitivamente aquí
	if global_position.x <= limite_izq:
		velocity.x = 0.0
		global_position.x = max(global_position.x, limite_izq)
		_fase_vuelo = FaseVuelo.DETENIDO
		_change_state(State.SHOOTING)
		return

	_preparar_pausa_isla(limite_izq)

	match _fase_vuelo:
		FaseVuelo.AVANZANDO:
			# Avance lento hacia el límite; la arquera dispara en paralelo
			if global_position.x <= _x_pausa_isla:
				_fase_vuelo = FaseVuelo.PAUSA_ISLA
				_timer_pausa_isla = 0.0
				velocity.x = 0.0
				return
			velocity.x = -velocidad_caminar
			walked_distance += velocidad_caminar * delta
		FaseVuelo.PAUSA_ISLA:
			# Pausa larga en el punto medio de la isla enemiga
			velocity.x = 0.0
			_timer_pausa_isla += delta
			if _timer_pausa_isla >= pausa_isla_segundos:
				_fase_vuelo = FaseVuelo.AVANZANDO
				# La pausa ya se realizo: invalidar el punto para no repetirla
				_x_pausa_isla = -INF
		_:
			velocity.x = 0.0


## Calcula una sola vez el punto medio entre el inicio del avance (spawn) y el
## límite de la isla enemiga. Si el recorrido es degenerado (límite a la derecha
## del spawn o globo ya pasado el punto medio), la pausa se desactiva.
func _preparar_pausa_isla(limite_izq: float) -> void:
	if _pausa_isla_preparada:
		return
	_pausa_isla_preparada = true
	_x_inicio_avance = global_position.x
	_x_pausa_isla = (_x_inicio_avance + limite_izq) * 0.5
	if _x_pausa_isla >= _x_inicio_avance or global_position.x <= _x_pausa_isla:
		_x_pausa_isla = -INF


func _procesar_combate(delta: float) -> void:
	# velocity.x lo gestiona _procesar_vuelo (avanzar, pausar, detener);
	# el combate NO debe frenar al globo para poder disparar mientras avanza.
	_timer_combate += delta

	match _fase_combate:
		FaseCombate.IDLE:
			if _timer_combate >= intervalo_disparo_globo:
				_fase_combate = FaseCombate.TENSANDO
				_timer_combate = 0.0
				_ha_disparado = false
				_play_animacion_goblin("Armature|GIRL_GOB_DISPARO")
				_play_animacion_arco("ARCO_TENSAR")

		FaseCombate.TENSANDO:
			if _timer_combate >= tiempo_tensado_arco:
				_fase_combate = FaseCombate.DISPARANDO
				_timer_combate = 0.0

		FaseCombate.DISPARANDO:
			if not _ha_disparado:
				_disparar_flecha()
				_play_animacion_arco("ARCO_DISPARO")
				_ha_disparado = true
			if _timer_combate >= 0.5:
				_fase_combate = FaseCombate.IDLE
				_timer_combate = 0.0
				_poner_postura_idle()


func _empujar_si_en_barrera() -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return
	var barreras: Array[Node] = []
	barreras.assign(get_tree().get_nodes_in_group("barrera_destruye_flechas"))
	for barrera_untyped in barreras:
		if not is_instance_valid(barrera_untyped):
			continue
		var barrera := barrera_untyped as Node3D
		if not barrera:
			continue
		var tam_x: float = 1.0
		if "tamano" in barrera:
			tam_x = barrera.tamano.x
		var limite_izquierdo: float = barrera.global_position.x - (tam_x * 0.5)
		if global_position.x >= limite_izquierdo - 0.5:
			if current_state != State.WALKING:
				_change_state(State.WALKING)
			velocity.x = -velocidad_caminar
			return


func _obtener_limite_izquierdo_x() -> float:
	var barreras := get_tree().get_nodes_in_group("barrera_limite")
	var limite: float = -20.0
	for b in barreras:
		if b is Node3D:
			limite = max(limite, (b as Node3D).global_position.x)
	return limite


# ==============================================================================
# DISPARO
# ==============================================================================


func _disparar_flecha() -> void:
	if not _escena_flecha:
		return

	if not player_ref or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return

	if player_ref.get("is_dead"):
		return

	var spawn_pos: Vector3 = global_position + Vector3(-0.35, 0.35, 0.0)
	if _punto_disparo and is_instance_valid(_punto_disparo):
		spawn_pos = _punto_disparo.global_position

	var target_pos: Vector3 = player_ref.global_position + Vector3(0.0, 0.5, 0.0)
	var diff: Vector3 = target_pos - spawn_pos
	var base_direction: Vector3 = diff.normalized()

	# Compensación de arco parabólico según distancia (idéntica a GoblinGirl)
	var horizontal_dist: float = absf(diff.x)
	var arc_compensation: float = clampf(
		horizontal_dist * ARC_COMPENSACION_DIST_MULT, ARC_COMPENSACION_MIN, ARC_COMPENSACION_MAX
	)
	var direction: Vector3 = Vector3(base_direction.x, base_direction.y + arc_compensation, 0.0).normalized()

	# Dispersión (GoblinGirl no aplica dispersión: dispersion == 0.0 por defecto)
	if dispersion > 0.0:
		var angulo_disp: float = randf_range(-dispersion, dispersion)
		direction = direction.rotated(Vector3.FORWARD, angulo_disp)

	# Instanciar proyectil
	var arrow = PROJECTILE_POOL_REF.acquire(_escena_flecha) as Node3D
	if not arrow:
		arrow = _escena_flecha.instantiate() as Node3D
		if not arrow:
			return

	# Mismo proyectil que GoblinGirl: color magenta y escala idéntica
	if "color_proyectil" in arrow:
		arrow.set("color_proyectil", COLOR_FLECHA)
	arrow.scale = escala_flecha_disparo

	var potencia: float = randf_range(potencia_disparo_min, potencia_disparo_max)
	if arrow.has_method("initialize"):
		arrow.call("initialize", direction, potencia)
		arrow.set_meta("shooter", self)
		PROJECTILE_POOL_REF.activate(arrow, get_tree().root, spawn_pos)
	else:
		get_tree().root.add_child(arrow)
		arrow.global_position = spawn_pos
		if direction.length_squared() > 0.01:
			arrow.look_at(spawn_pos + direction, Vector3.UP)
		if "velocidad" in arrow:
			arrow.set("velocidad", potencia)
		elif arrow is CharacterBody3D:
			(arrow as CharacterBody3D).velocity = direction * potencia

	AudioManager.play_sfx("goblin_girl_shoot")


# ==============================================================================
# BAMBOLEO & ANIMACIONES
# ==============================================================================


func _buscar_nodos_visuales() -> void:
	_pivot_bamboleo = get_node_or_null("PivotBamboleo") as Node3D
	_punto_disparo = get_node_or_null("PuntoDisparo") as Node3D
	_modelo_globo_node = get_node_or_null("PivotBamboleo/ModeloGlobo") as Node3D
	_modelo_globo_destruido_node = get_node_or_null("PivotBamboleo/ModeloGloboDestruido") as Node3D
	_modelo_canasta_node = get_node_or_null("PivotBamboleo/ModeloCanasta") as Node3D
	# Eliminar sombra de Canasta.glb (visible=false hasta destrucción, y sin sombra al caer)
	if _modelo_canasta_node:
		for mi in _modelo_canasta_node.find_children("*", "MeshInstance3D", true, false):
			if mi is MeshInstance3D:
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for sombra in _modelo_canasta_node.find_children("*", "SombraPersonaje", true, false):
			if is_instance_valid(sombra):
				sombra.queue_free()

	var arquera = find_child("ArqueraGoblin", true, false) as Node3D
	_arquera_goblin_node = arquera
	if arquera:
		_goblin_anim_player = arquera.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if _goblin_anim_player:
			# Configurar todas las animaciones de la goblin arquera (no modelo estático)
			# Ataque siempre será Ataque 1 (GIRL_GOB_DISPARO), pero debe tener disponibles todas
			for anim_name_full in _goblin_anim_player.get_animation_list():
				var anim = _goblin_anim_player.get_animation(anim_name_full)
				if not anim:
					continue
				if "MUERTE" in anim_name_full or "Muerte" in anim_name_full:
					anim.loop_mode = Animation.LOOP_NONE
				elif "CAMINA" in anim_name_full or "CAMINAR" in anim_name_full or "IDLE" in anim_name_full or "Caminar" in anim_name_full:
					anim.loop_mode = Animation.LOOP_LINEAR
				elif "DISPARO" in anim_name_full or "ATAQUE" in anim_name_full or "Attack" in anim_name_full:
					anim.loop_mode = Animation.LOOP_NONE
				# Otras animaciones (AGACHADA, etc.) se dejan por defecto pero disponibles

	var arco = find_child("ARCO_GOBLING_GIRL", true, false)
	if arco:
		_bow_anim_player = arco.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if _bow_anim_player:
			for anim_name_full in _bow_anim_player.get_animation_list():
				if "IDLE" in anim_name_full:
					var anim = _bow_anim_player.get_animation(anim_name_full)
					if anim:
						anim.loop_mode = Animation.LOOP_LINEAR


func _poner_postura_idle() -> void:
	_play_animacion_goblin("Armature|GIRL_GOB_CAMINA")
	_play_animacion_arco("ARCO_IDLE")


func _play_animacion_goblin(anim_name: String) -> void:
	if not _goblin_anim_player or not is_instance_valid(_goblin_anim_player):
		return
	for a in _goblin_anim_player.get_animation_list():
		if a == anim_name or anim_name in a:
			_goblin_anim_player.play(a)
			return


func _play_animacion_arco(anim_name: String) -> void:
	if not _bow_anim_player or not is_instance_valid(_bow_anim_player):
		return
	for a in _bow_anim_player.get_animation_list():
		if a == anim_name or anim_name in a:
			_bow_anim_player.play(a)
			return


func _iniciar_tween_bamboleo() -> void:
	if not _pivot_bamboleo:
		return

	var fase_inicio: float = randf_range(-angulo_bamboleo_z, angulo_bamboleo_z)
	_pivot_bamboleo.rotation_degrees.z = fase_inicio

	_tween_bamboleo = create_tween()
	_tween_bamboleo.set_loops()
	_tween_bamboleo.set_ease(Tween.EASE_IN_OUT)
	_tween_bamboleo.set_trans(Tween.TRANS_SINE)

	var mitad: float = periodo_bamboleo * 0.5
	_tween_bamboleo.tween_property(
		_pivot_bamboleo, "rotation_degrees:z", angulo_bamboleo_z, mitad
	)
	_tween_bamboleo.tween_property(
		_pivot_bamboleo, "rotation_degrees:z", -angulo_bamboleo_z, mitad
	)


func _iniciar_tween_deformacion() -> void:
	if not _pivot_bamboleo:
		return

	_tween_deformacion = create_tween()
	_tween_deformacion.set_loops()
	_tween_deformacion.set_ease(Tween.EASE_IN_OUT)
	_tween_deformacion.set_trans(Tween.TRANS_SINE)

	var escala_base: Vector3 = _pivot_bamboleo.scale
	var escala_expandida: Vector3 = Vector3(
		escala_base.x * (1.0 + deformacion_escala),
		escala_base.y * (1.0 - deformacion_escala * 0.5),
		escala_base.z
	)
	var escala_comprimida: Vector3 = Vector3(
		escala_base.x * (1.0 - deformacion_escala),
		escala_base.y * (1.0 + deformacion_escala * 0.5),
		escala_base.z
	)

	var mitad: float = periodo_deformacion * 0.5
	_tween_deformacion.tween_property(_pivot_bamboleo, "scale", escala_expandida, mitad)
	_tween_deformacion.tween_property(_pivot_bamboleo, "scale", escala_comprimida, mitad)


# ==============================================================================
# DAÑO Y MUERTE
# ==============================================================================


func take_damage(amount: float) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return
	_flash_red()
	AudioManager.play_sfx("shield_hit_arrow")
	super.take_damage(amount)


func _on_state_dying() -> void:
	super._on_state_dying()
	set_physics_process(true)

	# Detener bamboleo
	if _tween_bamboleo and _tween_bamboleo.is_valid():
		_tween_bamboleo.kill()
	if _tween_deformacion and _tween_deformacion.is_valid():
		_tween_deformacion.kill()

	# Intercambiar modelo intacto por el modelo destruido
	_intercambiar_modelo_destruido()

	# La arquera es eyectada hacia la izquierda con animación de muerte explosiva
	# y caída parabólica hasta el suelo (GoblinPiezaFisica). Siempre al destruirse,
	# independientemente del tipo de daño, para cumplir el requisito visual.
	_eyectar_arquera_explosiva()
	# Canasta.glb cae en ese lugar con física y colisión, mata con 5 de daño explosivo
	_eyectar_canasta()
	murio_por_explosion = false
	AudioManager.play_sfx("goblin_girl_death")
	_reproducir_sonido_globo_callendo()
	_reproducir_sonido_fuego1()

	# Cadena de 3 explosiones rápidas (como el pilar de Lonko al destruirse)
	_explotar_en_cadena()

	# Inclinación progresiva hacia la derecha (globo desinflándose)
	if _pivot_bamboleo:
		var tween_inclinacion := create_tween()
		tween_inclinacion.set_ease(Tween.EASE_IN_OUT)
		tween_inclinacion.set_trans(Tween.TRANS_SINE)
		tween_inclinacion.tween_property(
			_pivot_bamboleo, "rotation_degrees:z", -inclinacion_caida, duracion_inclinacion
		)

	# Desinflado: el modelo destruido se encoge progresivamente
	_iniciar_desinflado()

	_drop_posion()
	_drop_power_up_multiple()

	# Disolucion con particulas moradas mientras cae (igual que enemigos) - antes para no sobreencoger
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if is_instance_valid(self) and not is_dissolving:
			_die()
	)


func _drop_posion() -> void:
	if not posion_scene:
		return
	if randf() > posion_drop_chance:
		return
	var posion := posion_scene.instantiate() as Node3D
	if not posion:
		return
	var padre := get_tree().current_scene if get_tree().current_scene else get_parent()
	if padre:
		padre.add_child(posion)
	posion.global_position = global_position + Vector3(0.0, 0.2, 0.0)


func _drop_power_up_multiple() -> void:
	if not power_up_multiple_scene:
		return
	if randf() > multiple_drop_chance:
		return
	var power := power_up_multiple_scene.instantiate() as Node3D
	if not power:
		return
	var padre := get_tree().current_scene if get_tree().current_scene else get_parent()
	if padre:
		padre.add_child(power)
	power.global_position = global_position + Vector3(0.0, 0.3, 0.0)


# ==============================================================================
# INTERCAMBIO DE MODELO DESTRUIDO
# ==============================================================================


## Oculta el globo intacto y muestra el destruido (ambos ya están en la escena).
## Actualiza el caché de meshes de EnemyBase para que la disolución posterior
## aplique solo al modelo destruido (el intacto ya está oculto).
func _intercambiar_modelo_destruido() -> void:
	if not _modelo_globo_node or not is_instance_valid(_modelo_globo_node):
		return
	if not _modelo_globo_destruido_node or not is_instance_valid(_modelo_globo_destruido_node):
		return

	_modelo_globo_node.visible = false
	_modelo_globo_destruido_node.visible = true

	# Reconstruir caché: excluir meshes del intacto, mantener el resto (incluido el destruido)
	var nuevos_meshes: Array[Node] = []
	for mesh in _cached_mesh_instances:
		if not is_instance_valid(mesh):
			continue
		if _es_descendiente_de(mesh, _modelo_globo_node):
			continue
		nuevos_meshes.append(mesh)
	_cached_mesh_instances = nuevos_meshes


## Verifica si un nodo es descendiente de otro recorriendo la cadena de padres.
func _es_descendiente_de(nodo: Node, ancestro: Node) -> bool:
	var actual: Node = nodo.get_parent()
	while actual:
		if actual == ancestro:
			return true
		actual = actual.get_parent()
	return false


## Tween de desinflado: encoge el modelo destruido con deformación asimétrica
## (más compresión vertical que horizontal) para simular un globo perdiendo aire.
func _iniciar_desinflado() -> void:
	if not _modelo_globo_destruido_node or not is_instance_valid(_modelo_globo_destruido_node):
		return

	var escala_actual: Vector3 = _modelo_globo_destruido_node.scale
	# Deformación asimétrica: más aplastamiento vertical, leve ensanchamiento horizontal
	var escala_final: Vector3 = Vector3(
		escala_actual.x * (escala_desinflado + 0.15),
		escala_actual.y * escala_desinflado,
		escala_actual.z * (escala_desinflado + 0.1)
	)

	var tween_desinflado := create_tween()
	tween_desinflado.set_ease(Tween.EASE_IN_OUT)
	tween_desinflado.set_trans(Tween.TRANS_SINE)
	tween_desinflado.tween_property(
		_modelo_globo_destruido_node, "scale", escala_final, duracion_desinflado
	)


# ==============================================================================
# EYECIÓN DE ARQUERA - MUERTE EXPLOSIVA (hacia la izquierda)
# ==============================================================================


## Eyecta la arquera goblin hacia la izquierda con animacion de muerte
## explosiva y caida parabolica hasta el suelo (GoblinPiezaFisica).
## Se activa siempre al destruirse el globo, con impulso a la izquierda.
func _eyectar_arquera_explosiva() -> void:
	if not _arquera_goblin_node or not is_instance_valid(_arquera_goblin_node):
		_arquera_goblin_node = find_child("ArqueraGoblin", true, false) as Node3D
		if not _arquera_goblin_node:
			return

	var arquera: Node3D = _arquera_goblin_node

	# Recolectar meshes de la arquera antes de desparentar para filtrar la caché
	var meshes_arquera: Array[Node] = []
	for m in arquera.find_children("*", "MeshInstance3D", true, false):
		meshes_arquera.append(m)

	var tr_global: Transform3D = arquera.global_transform
	var padre_previo: Node = arquera.get_parent()
	if padre_previo:
		padre_previo.remove_child(arquera)

	var root_scene: Node = get_tree().current_scene
	if root_scene == null:
		root_scene = get_tree().root

	var contenedor := GoblinPiezaFisica.new()
	# Diferenciar visualmente la muerte de la arquera del globo
	contenedor.name = "ArqueraGloboEyectada"
	root_scene.add_child(contenedor)
	contenedor.global_transform = tr_global

	# La arquera queda centrada en el contenedor (su transform local pasa a ser identidad)
	arquera.transform = Transform3D.IDENTITY
	arquera.visible = true
	# Limpiar overrides de dano/disulocion para que conserve sus materiales originales
	for mesh in arquera.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		if mi:
			mi.visible = true
			mi.material_override = null

	contenedor.add_child(arquera)

	# Filtrar meshes de la arquera de la caché del globo para que la disolución
	# del globo no intente disolver también a la arquera eyectada
	var nuevos: Array[Node] = []
	for mesh in _cached_mesh_instances:
		if not is_instance_valid(mesh):
			continue
		var es_de_arquera: bool = false
		for ma in meshes_arquera:
			if mesh == ma:
				es_de_arquera = true
				break
		if es_de_arquera:
			continue
		nuevos.append(mesh)
	_cached_mesh_instances = nuevos

	# Animacion de muerte fija: Armature|MUERTE1 - no estática, re-resuelve player tras reparent
	var ap_actual: AnimationPlayer = arquera.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap_actual and is_instance_valid(ap_actual):
		_goblin_anim_player = ap_actual
		var anim_objetivo: StringName = &""
		for a in ap_actual.get_animation_list():
			if a == "Armature|MUERTE1" or a.ends_with("|MUERTE1") or a == "MUERTE1":
				anim_objetivo = a
				break
		if anim_objetivo == &"":
			for a in ap_actual.get_animation_list():
				if "MUERTE1" in a:
					anim_objetivo = a
					break
		if anim_objetivo != &"":
			ap_actual.stop()
			ap_actual.speed_scale = 1.0
			ap_actual.play(anim_objetivo)
			ap_actual.advance(0.0)
		else:
			_play_animacion_goblin("Armature|MUERTE1")
	elif _goblin_anim_player and is_instance_valid(_goblin_anim_player):
		_play_animacion_goblin("Armature|MUERTE1")

	# Impulso hacia la izquierda (X negativo) con elevación y caída parabólica
	var vel_x: float = -randf_range(1.8, 2.6)
	if last_hit_position != Vector3.ZERO:
		var dx: float = global_position.x - last_hit_position.x
		vel_x = -absf(vel_x) if dx > 0.05 else -absf(vel_x)
	var vel_y: float = randf_range(2.0, 2.8)
	var rot_z: float = randf_range(-12.0, 12.0)
	contenedor.iniciar_vuelo(Vector3(vel_x, vel_y, 0.0), rot_z)

	# Limpiar referencia local (ya no pertenece al globo) - mantener player vivo en contenedor
	var _ap_cache := _goblin_anim_player
	_arquera_goblin_node = null
	_goblin_anim_player = null
	_bow_anim_player = null


## Canasta.glb cae en el lugar de destrucción con física y colisión, mata con 5 de daño explosivo
func _eyectar_canasta() -> void:
	if not _modelo_canasta_node or not is_instance_valid(_modelo_canasta_node):
		_modelo_canasta_node = get_node_or_null("PivotBamboleo/ModeloCanasta") as Node3D
		if not _modelo_canasta_node:
			return
	var canasta: Node3D = _modelo_canasta_node
	var meshes_canasta: Array[Node] = []
	for m in canasta.find_children("*", "MeshInstance3D", true, false):
		meshes_canasta.append(m)
	var tr_global: Transform3D = canasta.global_transform
	var padre_previo: Node = canasta.get_parent()
	if padre_previo:
		padre_previo.remove_child(canasta)
	var root_scene: Node = get_tree().current_scene
	if root_scene == null:
		root_scene = get_tree().root
	var contenedor := CanastaCaida.new()
	contenedor.name = "CanastaGloboCaida"
	root_scene.add_child(contenedor)
	contenedor.global_transform = tr_global
	canasta.transform = Transform3D.IDENTITY
	canasta.visible = true
	for mesh in canasta.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		if mi:
			mi.visible = true
			mi.material_override = null
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sombra in canasta.find_children("*", "SombraPersonaje", true, false):
		if is_instance_valid(sombra):
			sombra.queue_free()
	contenedor.add_child(canasta)
	# Asegurar que el contenedor tampoco genere sombra
	for mi2 in contenedor.find_children("*", "MeshInstance3D", true, false):
		if mi2 is MeshInstance3D:
			(mi2 as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var nuevos: Array[Node] = []
	for mesh in _cached_mesh_instances:
		if not is_instance_valid(mesh):
			continue
		var es_de_canasta: bool = false
		for ma in meshes_canasta:
			if mesh == ma:
				es_de_canasta = true
				break
		if es_de_canasta:
			continue
		nuevos.append(mesh)
	_cached_mesh_instances = nuevos
	# Caída vertical en el lugar donde se destruyó el globo
	contenedor.iniciar_vuelo(Vector3(randf_range(-0.3, 0.3), -0.8, 0.0), randf_range(-5.0, 5.0))
	_modelo_canasta_node = null


# ==============================================================================
# EXPLOSIÓN EN CADENA (similar al pilar de Lonko al destruirse)
# ==============================================================================

## Lanza la cadena de explosiones al morir: 3 estallidos rápidos en sucesión
## con el mismo VFX, rocas negras y SFX de la destrucción del pilar de Lonko.
func _explotar_en_cadena() -> void:
	_explotar_paso(0)


## Un paso de la cadena: estalla la explosión del índice actual y agenda la
## siguiente tras intervalo_explosiones. Con timers encadenados en vez de
## corrutina para que no haya reanudaciones sobre un objeto ya liberado.
func _explotar_paso(indice: int) -> void:
	if indice >= cantidad_explosiones:
		return
	if not is_inside_tree():
		return

	_spawn_explosion(indice)
	get_tree().create_timer(intervalo_explosiones).timeout.connect(_explotar_paso.bind(indice + 1))


## Una explosión individual: VFX Explocion_Pilar a escala configurada, situada
## a lo largo del cuerpo (copa -> canasto) siguiendo la caída del globo.
func _spawn_explosion(indice: int) -> void:
	var root_scene: Node = get_tree().current_scene
	if root_scene == null:
		root_scene = get_tree().root
	if not explocion_pilar_scene:
		return

	var exp_node := explocion_pilar_scene.instantiate() as Node3D
	if not exp_node:
		return
	root_scene.add_child(exp_node)
	exp_node.scale = Vector3(escala_explosion, escala_explosion, escala_explosion)
	var fraccion: float = ALTURAS_RELATIVAS_EXPLOSION[mini(indice, ALTURAS_RELATIVAS_EXPLOSION.size() - 1)]
	var exp_y: float = global_position.y + (ALTO_CUERPO_EXPLOSION * fraccion)
	var rand_offset := Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
	var spawn_p: Vector3 = Vector3(global_position.x, exp_y, global_position.z) + rand_offset
	exp_node.global_position = spawn_p

	# Ráfaga de rocas negras y sonido de explosión (el mismo dúo del pilar de Lonko)
	_crear_particulas_rocas_destruccion(spawn_p)
	_reproducir_sonido_explosion(spawn_p)

	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(exp_node):
			exp_node.queue_free()
	)


## Ráfaga de rocas negras idéntica a la de la destrucción del pilar de Lonko
func _crear_particulas_rocas_destruccion(spawn_pos: Vector3) -> void:
	var parts := GPUParticles3D.new()
	parts.name = "ParticulasRocasDestruccion"
	parts.amount = 12
	parts.lifetime = 2.5
	parts.one_shot = true
	parts.explosiveness = 0.85

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.3, 0.1, 0.3)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 45.0
	pmat.initial_velocity_min = 2.5
	pmat.initial_velocity_max = 5.5
	pmat.gravity = Vector3(0, -11.0, 0)
	pmat.scale_min = 0.25
	pmat.scale_max = 0.65
	pmat.anim_offset_min = 0.0
	pmat.anim_offset_max = 1.0
	pmat.angle_min = 0.0
	pmat.angle_max = 360.0
	pmat.angular_velocity_min = -180.0
	pmat.angular_velocity_max = 180.0
	parts.process_material = pmat

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = TEXTURA_PIEDRAS_NEGRAS_RES
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.particles_anim_h_frames = 4
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = false
	mat.render_priority = -1

	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	quad.material = mat
	parts.draw_pass_1 = quad

	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(parts)
	parts.global_position = spawn_pos
	parts.emitting = true

	get_tree().create_timer(3.5).timeout.connect(func() -> void:
		if is_instance_valid(parts):
			parts.queue_free()
	)


## Sonido de explosión aleatorio (EXPLOSION01/02), igual que en el pilar de Lonko
func _reproducir_sonido_explosion(spawn_pos: Vector3) -> void:
	var stream: AudioStream = sfx_explosion_01 if randf() < 0.5 else sfx_explosion_02
	if not stream:
		return

	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = -2.5
	player.unit_size = 10.0
	player.max_distance = 50.0
	player.bus = "Master"

	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(player)
	player.global_position = spawn_pos
	player.play()
	player.finished.connect(player.queue_free)


## Sonido de globo cayendo al destruirse (TEST_/Sonido globo callendo.mp3)
func _reproducir_sonido_globo_callendo() -> void:
	if not sfx_globo_callendo:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = sfx_globo_callendo
	player.volume_db = 4.0
	player.unit_size = 14.0
	player.max_distance = 70.0
	player.bus = "Master"
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(player)
	player.global_position = global_position
	player.play()
	player.finished.connect(player.queue_free)


## Sonido Fuego1 al destruirse el globo (TEST_/Fuego1.mp3)
func _reproducir_sonido_fuego1() -> void:
	if not sfx_fuego1:
		push_warning("[GloboAerostatico] sfx_fuego1 nulo")
		return
	var player := AudioStreamPlayer.new()
	player.stream = sfx_fuego1
	player.volume_db = -4.0
	player.bus = "Master"
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)