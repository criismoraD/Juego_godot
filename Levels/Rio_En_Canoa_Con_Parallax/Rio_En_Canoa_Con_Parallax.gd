class_name RioEnCanoaConParallax
extends Node3D

## Controlador del escenario 'Rio en canoa con paralax'.
## Combina la iluminación, cámara, agua y peces de NIVEL01 con un sistema
## de fondo con doble profundidad parallax (cielo atardecer y terreno rocoso en loop)
## y una canoa aliada que transporta a la protagonista hacia la derecha.


# === SIGNALS ===
signal nivel_completado

# === CONSTANTES ===
const VELOCIDAD_CANOA_DEFECTO: float = 0.65
const VELOCIDAD_PARALLAX_DEFECTO: float = 1.0
const ANCHO_AGUA_AMPLIADO: float = 120.0
const MUSICA_VIAJE_RIO: int = 7       ## Índice en AudioManager de "Viaje por el rio"
const MUSICA_JEFE_RIO: int = 8        ## Índice en AudioManager de "Jefe rio"
const MUSICA_JEFE_DESTRUIDO: int = 9  ## Índice en AudioManager de "Jefe destruido"
const MULTIPLICADOR_ACELERACION_DEFECTO: float = 6.0
const ESCENA_MINI_SPLASH = preload("res://TEST_/swimming-in-godot-from-scracth/SCENES/splash_vfx.tscn")
const UMBRAL_CAIDA_AGUA_ENEMIGO_Y: float = -0.45  ## Cota Y bajo la cual un enemigo sin suelo se considera caído al agua
const TIEMPO_GRACIA_INICIO_RIO: float = 0.8  ## Segundos de espera al arrancar el nivel para que la física se asiente
const DISTANCIA_MAX_SFX_SPLASH: float = 24.0  ## Distancia horizontal máxima a la cámara para emitir sonido de splash
const SFX_SPLASH_AGUA: String = "splash_agua"
const INTERVALO_CHECK_AGUA: float = 0.1  ## Intervalo mínimo entre comprobaciones de enemigos caídos al agua (s)

# === EXPORTS ===
@export_category("Fin de Nivel")
@export var x_fin_nivel: float = 184.0  ## Coordenada X donde se activa la transición final del nivel
@export var escena_siguiente: String = "res://Levels/Player_Interior.tscn"  ## Escena de destino al presionar Continuar
@export var duracion_transicion_fin: float = 1.4  ## Duración del barrido de transición de derecha a izquierda
@export var clave_titulo_fin: String = "RIO_ASALTO_SUPERADO"  ## Título de la cortinilla final ("Asalto al rio Superado")

@export_category("Control de Travesía")
@export var velocidad_canoa: float = VELOCIDAD_CANOA_DEFECTO  ## Velocidad de avance de la canoa (m/s)
@export var velocidad_parallax: float = VELOCIDAD_PARALLAX_DEFECTO  ## Velocidad del fondo rocoso
@export var travesia_activa: bool = true  ## Si false, detiene el avance de la canoa y el parallax
@export var duracion_transicion_travesia: float = 0.8  ## Rampa suave de frenado/arranque al pausar o reanudar (s, sin cortes)
@export var camara_sigue_canoa: bool = true  ## Si true, la cámara principal sigue el avance de la canoa aliada
@export var musica_viaje_rio: bool = true  ## Si true, suena "Viaje por el rio" al entrar al nivel
@export var distancia_activacion_batalla_naval: float = 14.0  ## La batalla naval del nivel 5 arranca al acercarse la cámara
@export var focos_fijos_a_camara: bool = true  ## Si true, todos los focos LuzCentroPiso*/LuzTorre* acompañan a la cámara en X como un sol fijo mientras la cordillera hace scroll

@export_category("Tramo Acelerado Fluvial")
@export var tramo_acelerado_activo: bool = true  ## Si true, la canoa acelera entre el puente y el barco si no hay enemigos
@export var velocidad_canoa_tramo_acelerado: float = 1.8  ## Velocidad de la canoa en el tramo sin enemigos (m/s)
@export var nombre_referencia_inicio_aceleracion: String = "PuenteMaderaParaPosicionar8 aceleracion"  ## Referencia de inicio
@export var escala_mini_splash_agua: float = 0.18  ## Escala del mini-splash de agua (más pequeño que el de Azulina 0.35)
@export var duracion_mini_splash_agua: float = 1.5  ## Tiempo de vida del efecto de splash antes de queue_free

@export_category("Música y Audio del Jefe")
@export var musica_jefe_activa: bool = true  ## Si true, reproduce "Jefe rio" en el combate y "Jefe destruido" al vencerlo
@export var requerir_barco_checkpoint_para_musica_jefe: bool = true  ## Si true, "Jefe rio" solo suena tras destruir el BarcoCombatePirata3 Check point
@export var nombre_barco_checkpoint: String = "BarcoCombatePirata3 Check point"  ## Nodo que debe destruirse antes de la música del jefe
@export var distancia_area_jefe: float = 22.0  ## Distancia en X a la que la canoa se considera en el área del jefe
@export var duracion_fade_out_musica_nivel: float = 1.8  ## Segundos para disminuir la música del nivel al acercarse al jefe
@export var duracion_fade_in_musica_jefe: float = 1.8   ## Segundos para elevar la música del jefe
@export var duracion_corte_musica_jefe: float = 0.35    ## Segundos para desvanecer "Jefe rio" al morir el jefe
@export var pausa_post_jefe_destruido: float = 1.2      ## Pausa breve tras sonar "Jefe destruido" antes de reanudar música del nivel
@export var duracion_fade_in_musica_nivel: float = 2.0  ## Segundos para volver a sonar la música normal del nivel

@export_category("Debug / Testeo de Recorrido")
@export var permitir_aceleracion_debug: bool = true  ## Si true, permite acelerar el recorrido con la tecla Z para testeo
@export var multiplicador_aceleracion: float = MULTIPLICADOR_ACELERACION_DEFECTO  ## Multiplicador de velocidad al presionar la tecla Z
@export var modo_toggle_z: bool = false  ## Si true, la tecla Z conmuta el modo rápido; si false, acelera mientras se mantenga presionada
@export var permitir_teletransporte_jefe_debug: bool = true  ## Si true, la tecla B salta directo al combate con el jefe para testeo
@export var distancia_previa_jefe: float = 12.0  ## La canoa aparece esta distancia antes del jefe para verlo emerger

# === ONREADY ===
@onready var parallax_fondo: Node3D = find_child("ParallaxFondo", true, false) as Node3D
@onready var canoa_protagonista: Node3D = find_child("CanoaProtagonistaRio", true, false) as Node3D
@onready var camara_principal: Camera3D = find_child("CamaraPrincipal", true, false) as Camera3D
@onready var batalla_naval_rio: ControladorTrayectoriaEmbarcaciones = find_child("TrayectoriaEmbarcacionesRio", true, false) as ControladorTrayectoriaEmbarcaciones
@onready var water_plane: Node3D = find_child("WaterPlane", true, false) as Node3D
@onready var pez_1: Node3D = find_child("Pez", true, false) as Node3D
@onready var pez_2: Node3D = find_child("Pez2", true, false) as Node3D

# === VARIABLES PRIVADAS ===
var _offset_camara_x: float = 2.9400935
var _offset_water_x: float = 0.0675573
var _batalla_naval_activada: bool = false
var _focos_fijos: Array[SpotLight3D] = []
var _offsets_focos_x: Array[float] = []
var _segmentos_agua: Array[Node3D] = []
var _acelerando_debug: bool = false
var _velocidad_canoa_base: float = VELOCIDAD_CANOA_DEFECTO
var _velocidad_parallax_base: float = VELOCIDAD_PARALLAX_DEFECTO
var _factor_travesia_suave: float = 1.0  ## 1 = avance pleno, 0 = reposo; rampa continua sin cortes
var _jefe_submarino_ref: Node = null
var _musica_jefe_iniciada: bool = false
var _musica_jefe_finalizada: bool = false
var _barco_checkpoint_ref: Node = null
var _barco_checkpoint_destruido: bool = false
var _tiempo_nivel_rio: float = 0.0
var _nivel_terminado: bool = false
var _pantalla_fin_nivel: PantallaFinNivel = null
var _timer_check_agua: float = 0.0  ## Acumulador para el throttle del check de caída al agua

# === ESTADO ESTÁTICO DE CHECKPOINT (PERSISTE TRAS REINTENTAR) ===
static var checkpoint_rio_activo: bool = false
static var checkpoint_rio_pos_x: float = 0.0


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	ShaderGlobals.asegurar_outline_global(true)
	ShaderGlobals.asegurar_outline_proyectiles(true)
	_velocidad_canoa_base = velocidad_canoa
	_velocidad_parallax_base = velocidad_parallax
	_factor_travesia_suave = 1.0 if travesia_activa else 0.0
	_buscar_y_conectar_jefe()
	_buscar_y_conectar_barco_checkpoint()
	_inicializar_tramo_aceleracion()

	if is_instance_valid(canoa_protagonista):
		var canoa_x: float = canoa_protagonista.global_position.x
		if is_instance_valid(camara_principal):
			_offset_camara_x = camara_principal.global_position.x - canoa_x
		if is_instance_valid(water_plane):
			_offset_water_x = water_plane.global_position.x - canoa_x
	_inicializar_focos_fijos()

	if is_instance_valid(parallax_fondo):
		if parallax_fondo.has_method("fijar_camara_referencia") and is_instance_valid(camara_principal):
			parallax_fondo.call("fijar_camara_referencia", camara_principal)
		if parallax_fondo.has_method("_inicializar_capa_piso_aliado"):
			parallax_fondo.call("_inicializar_capa_piso_aliado")
		if parallax_fondo.has_method("_inicializar_capa_agua_textura"):
			parallax_fondo.call("_inicializar_capa_agua_textura")
		if parallax_fondo.has_method("_inicializar_capa_reflejo"):
			parallax_fondo.call("_inicializar_capa_reflejo")
		if parallax_fondo.has_method("_inicializar_capa_casa_boneta"):
			parallax_fondo.call("_inicializar_capa_casa_boneta")
		if parallax_fondo.has_method("_inicializar_capa_bosque_rojo"):
			parallax_fondo.call("_inicializar_capa_bosque_rojo")
		if parallax_fondo.has_method("_inicializar_capa_montana_beta"):
			parallax_fondo.call("_inicializar_capa_montana_beta")
		if parallax_fondo.has_method("_inicializar_capa_niebla"):
			parallax_fondo.call("_inicializar_capa_niebla")
		if parallax_fondo.has_method("_inicializar_capa_arbol_cordillera"):
			parallax_fondo.call("_inicializar_capa_arbol_cordillera")
		if parallax_fondo.has_method("aplicar_capas_fondo"):
			parallax_fondo.call("aplicar_capas_fondo")

	_inicializar_agua()
	_inicializar_escenario()

	if checkpoint_rio_activo:
		_aplicar_checkpoint_rio()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo and event.pressed:
		var es_tecla_b: bool = (event.keycode == KEY_B or event.physical_keycode == KEY_B)
		if es_tecla_b and permitir_teletransporte_jefe_debug:
			_teletransportar_a_jefe()
			return

		var es_tecla_x: bool = (event.keycode == KEY_X or event.physical_keycode == KEY_X)
		if es_tecla_x:
			var jefe: Node3D = null
			if get_tree() != null:
				jefe = get_tree().get_first_node_in_group("jefe_submarino") as Node3D
			if not is_instance_valid(jefe):
				jefe = find_child("JefeSubmarino", true, false) as Node3D
			if is_instance_valid(jefe) and jefe.has_method("explotar_debug"):
				jefe.call("explotar_debug")
				return

		var es_tecla_n: bool = (event.keycode == KEY_N or event.physical_keycode == KEY_N)
		if es_tecla_n and permitir_teletransporte_jefe_debug:
			_teletransportar_a_fin_nivel()
			return

	if not permitir_aceleracion_debug or not travesia_activa:
		return

	if event is InputEventKey and not event.echo:
		var es_tecla_z: bool = (event.keycode == KEY_Z or event.physical_keycode == KEY_Z)
		if es_tecla_z:
			if modo_toggle_z:
				if event.pressed:
					set_aceleracion_debug(not _acelerando_debug)
			else:
				set_aceleracion_debug(event.pressed)


func _process(_delta: float) -> void:
	_comprobar_liberacion_aceleracion()

	# Transición continua de la travesía: frenado y arranque por rampa, sin cortes.
	if _delta > 0.0:
		var objetivo_factor: float = 1.0 if travesia_activa else 0.0
		_factor_travesia_suave = move_toward(_factor_travesia_suave, objetivo_factor, _delta / maxf(duracion_transicion_travesia, 0.2))

	if camara_sigue_canoa and is_instance_valid(canoa_protagonista):
		var canoa_x: float = canoa_protagonista.global_position.x
		if is_instance_valid(camara_principal):
			camara_principal.global_position.x = canoa_x + _offset_camara_x
		if is_instance_valid(water_plane):
			water_plane.global_position.x = canoa_x + _offset_water_x

	_procesar_activacion_batalla_naval()

	if is_instance_valid(parallax_fondo) and is_instance_valid(canoa_protagonista):
		var vel_efectiva: float = canoa_protagonista.obtener_velocidad_efectiva() if canoa_protagonista.has_method("obtener_velocidad_efectiva") else velocidad_canoa
		var ratio_velocidad: float = 1.0
		if canoa_protagonista.has_method("esta_navegando") and canoa_protagonista.call("esta_navegando") and vel_efectiva > 0.0:
			ratio_velocidad = vel_efectiva / maxf(_velocidad_canoa_base, 0.01)
		else:
			var factor_presencia: float = canoa_protagonista.obtener_factor_velocidad_actual() if canoa_protagonista.has_method("obtener_factor_velocidad_actual") else 1.0
			ratio_velocidad = (velocidad_canoa / maxf(_velocidad_canoa_base, 0.01)) * factor_presencia

		var vel_parallax_efectiva: float = _velocidad_parallax_base * ratio_velocidad * _factor_travesia_suave
		parallax_fondo.set("velocidad_terroso", vel_parallax_efectiva)
		if parallax_fondo.has_method("set_desplazamiento_activo"):
			parallax_fondo.call("set_desplazamiento_activo", _factor_travesia_suave > 0.02 and ratio_velocidad > 0.01)

	_actualizar_focos_fijos()
	_procesar_musica_area_jefe()
	_procesar_enemigos_caidos_al_agua(_delta)
	_procesar_fin_de_nivel()


## La batalla naval (nivel 5) arranca sola al acercarse la cámara centrada.
## En NIVEL01 la dispara el código de oleadas; aquí no hay oleadas.
func _procesar_activacion_batalla_naval() -> void:
	if _batalla_naval_activada:
		return
	if not is_instance_valid(batalla_naval_rio):
		return
	if batalla_naval_rio.esta_activo():
		_batalla_naval_activada = true
		return
	if not is_instance_valid(camara_principal):
		return
	var dx: float = batalla_naval_rio.global_position.x - camara_principal.global_position.x
	if dx <= distancia_activacion_batalla_naval and dx >= -8.0:
		batalla_naval_rio.spawnear_ambas()
		_batalla_naval_activada = true


## Localiza el nodo del Jefe Submarino en la escena y se suscribe a sus señales de combate y derrota.
func _buscar_y_conectar_jefe() -> void:
	if is_instance_valid(_jefe_submarino_ref):
		return
	var jefe_encontrado: Node = null
	if get_tree() != null:
		jefe_encontrado = get_tree().get_first_node_in_group("jefe_submarino")
	if not is_instance_valid(jefe_encontrado):
		jefe_encontrado = find_child("JefeSubmarino", true, false)
	if is_instance_valid(jefe_encontrado):
		_jefe_submarino_ref = jefe_encontrado
		if _jefe_submarino_ref.has_signal("combate_iniciado"):
			if not _jefe_submarino_ref.is_connected("combate_iniciado", _al_iniciar_combate_jefe):
				_jefe_submarino_ref.connect("combate_iniciado", _al_iniciar_combate_jefe)
		if _jefe_submarino_ref.has_signal("jefe_derrotado"):
			if not _jefe_submarino_ref.is_connected("jefe_derrotado", _al_derrotar_jefe):
				_jefe_submarino_ref.connect("jefe_derrotado", _al_derrotar_jefe)


## Localiza el BarcoCombatePirata3 Check point y se suscribe a su
## destrucción: la música del jefe solo puede sonar después de hundirlo.
func _buscar_y_conectar_barco_checkpoint() -> void:
	if _barco_checkpoint_destruido:
		return
	if not requerir_barco_checkpoint_para_musica_jefe:
		return
	var barco: Node = find_child(nombre_barco_checkpoint, true, false)
	if not is_instance_valid(barco):
		barco = find_child("BarcoCombatePirata3*", true, false)
	if not is_instance_valid(barco) and get_tree() != null:
		for candidato in get_tree().get_nodes_in_group("barco_checkpoint_musica_jefe"):
			if is_instance_valid(candidato):
				barco = candidato
				break
	if not is_instance_valid(barco):
		return
	if barco.has_method("esta_destruida") and bool(barco.call("esta_destruida")):
		_barco_checkpoint_destruido = true
		_barco_checkpoint_ref = barco
		return
	if barco.is_queued_for_deletion():
		_barco_checkpoint_destruido = true
		return
	_barco_checkpoint_ref = barco
	if _barco_checkpoint_ref.has_signal("balsa_destruida"):
		if not _barco_checkpoint_ref.is_connected("balsa_destruida", _al_destruir_barco_checkpoint):
			_barco_checkpoint_ref.connect("balsa_destruida", _al_destruir_barco_checkpoint)


## True cuando ya se puede sonar la música del jefe (checkpoint hundido o sin checkpoint en escena).
func _puerta_checkpoint_superada() -> bool:
	if not requerir_barco_checkpoint_para_musica_jefe:
		return true
	if _barco_checkpoint_destruido:
		return true
	if is_instance_valid(_barco_checkpoint_ref):
		if _barco_checkpoint_ref.has_method("esta_destruida") and bool(_barco_checkpoint_ref.call("esta_destruida")):
			_barco_checkpoint_destruido = true
			return true
		return false
	_buscar_y_conectar_barco_checkpoint()
	if not is_instance_valid(_barco_checkpoint_ref):
		return true
	return _barco_checkpoint_destruido


## Callback al hundirse el BarcoCombatePirata3 Check point:
## 1. Guarda el punto de control del nivel y muestra en texto blanco "Punto de guardado" (traducción).
## 2. Libera la música del jefe y la arranca de inmediato si la canoa ya está en el área.
func _al_destruir_barco_checkpoint() -> void:
	_barco_checkpoint_destruido = true
	_activar_checkpoint()
	_procesar_musica_area_jefe()


## Guarda el estado del checkpoint y despliega la notificación en pantalla.
func _activar_checkpoint() -> void:
	checkpoint_rio_activo = true
	if is_instance_valid(canoa_protagonista):
		checkpoint_rio_pos_x = canoa_protagonista.global_position.x
	elif is_instance_valid(_barco_checkpoint_ref):
		checkpoint_rio_pos_x = (_barco_checkpoint_ref as Node3D).global_position.x - 2.0
	else:
		checkpoint_rio_pos_x = 124.0

	_mostrar_notificacion_checkpoint()


## Muestra en pantalla en texto blanco "Punto de guardado" (sujeto a traducción).
func _mostrar_notificacion_checkpoint() -> void:
	if get_tree() == null:
		return

	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "NotificacionCheckpoint"
	canvas_layer.layer = 100

	var control := Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(control)

	var label := Label.new()
	label.name = "LabelPuntoGuardado"
	label.text = tr("Punto de guardado")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 180.0
	label.offset_bottom = 260.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var font_res: Font = load("res://assets/Fuentes/Ravenna.ttf") as Font
	if font_res == null:
		font_res = load("res://assets/Fuentes/HyliaSerif.ttf") as Font
	if font_res != null:
		label.add_theme_font_override("font", font_res)

	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 4)

	control.add_child(label)

	var root_node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	if root_node:
		root_node.add_child(canvas_layer)
	else:
		add_child(canvas_layer)

	label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_property(label, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(canvas_layer):
			canvas_layer.queue_free()
	)


## Reposiciona la canoa y cámara en el checkpoint y elimina obstáculos y barcos superados.
func _aplicar_checkpoint_rio() -> void:
	_barco_checkpoint_destruido = true
	var destino_x: float = checkpoint_rio_pos_x if checkpoint_rio_pos_x > 0.0 else 124.0
	_teletransportar_canoa_x(destino_x)

	# 1. Ocultar o eliminar título del nivel
	var titulo: Node = find_child("TituloRio", true, false)
	if is_instance_valid(titulo):
		titulo.queue_free()

	# 2. Eliminar barcos y enemigos anteriores al checkpoint
	if get_tree() != null:
		var barcos = get_tree().get_nodes_in_group("barco_combate")
		for b in barcos:
			if is_instance_valid(b) and (b as Node3D).global_position.x <= destino_x + 5.0:
				b.queue_free()

		for nombre in ["BarcoCombatePirata", "BarcoCombatePirata2", "BarcoCombatePirata3 Check point", "BarcoCombatePirata3*"]:
			var b_node: Node = find_child(nombre, true, false)
			if is_instance_valid(b_node):
				b_node.queue_free()

		for grp in ["enemies", "enemigos"]:
			for e in get_tree().get_nodes_in_group(grp):
				if is_instance_valid(e) and (e as Node3D).global_position.x <= destino_x + 5.0:
					e.queue_free()

	set_travesia_activa(true)
	if is_instance_valid(canoa_protagonista) and canoa_protagonista.has_method("reanudar_navegacion"):
		canoa_protagonista.call("reanudar_navegacion")


## Limpia el estado persistente del punto de control del río.
static func reset_checkpoint() -> void:
	checkpoint_rio_activo = false
	checkpoint_rio_pos_x = 0.0


## Rellena los corazones del jugador y la vida de Perrena al 100% cuando el jefe es destruido.
func curar_jugador_y_perrena_al_derrotar_jefe() -> void:
	if get_tree() == null:
		return

	# 1. Rellenar corazones del jugador
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty() and is_instance_valid(canoa_protagonista):
		var p = canoa_protagonista.find_child("Protagonista", true, false)
		if is_instance_valid(p):
			players.append(p)

	for p in players:
		if not is_instance_valid(p):
			continue
		if p.has_method("curar_completo"):
			p.call("curar_completo")
		elif p.has_method("curar") and "vida_maxima" in p:
			p.call("curar", p.get("vida_maxima"))
		elif "vida_maxima" in p and "health" in p:
			p.set("health", p.get("vida_maxima"))
			if p.has_signal("health_changed"):
				p.emit_signal("health_changed", p.get("health"))

	get_tree().call_group("ui_vida_protagonista", "reconectar_player")

	# 2. Rellenar vida de Perrena (defensora y/o jugable)
	var perrenas: Array[Node] = []
	perrenas.append_array(get_tree().get_nodes_in_group("defensora_perrena"))
	perrenas.append_array(get_tree().get_nodes_in_group("defensoras"))
	if is_instance_valid(canoa_protagonista):
		var def_p = canoa_protagonista.find_child("DefensoraPerrena", true, false)
		if is_instance_valid(def_p) and not perrenas.has(def_p):
			perrenas.append(def_p)

	for perrena in perrenas:
		if not is_instance_valid(perrena):
			continue
		if perrena is DefensoraPerrena or perrena.name.to_lower().contains("perrena"):
			if perrena.has_method("curar_completo"):
				perrena.call("curar_completo")
			elif perrena.has_method("curar") and "vida_maxima" in perrena:
				perrena.call("curar", perrena.get("vida_maxima"))
			elif "vida_maxima" in perrena and "health" in perrena:
				perrena.set("health", perrena.get("vida_maxima"))
				if perrena.has_signal("vida_cambiada"):
					perrena.emit_signal("vida_cambiada", perrena.get("health"))


## Monitoriza la posición de la canoa respecto al área del jefe para activar la transición musical.
## La transición queda bloqueada hasta destruir el BarcoCombatePirata3 Check point.
func _procesar_musica_area_jefe() -> void:
	if not musica_jefe_activa or _musica_jefe_iniciada or _musica_jefe_finalizada:
		return
	if not _puerta_checkpoint_superada():
		return
	if not is_instance_valid(_jefe_submarino_ref):
		_buscar_y_conectar_jefe()
		if not is_instance_valid(_jefe_submarino_ref):
			return

	if not is_instance_valid(canoa_protagonista):
		return

	var canoa_x: float = canoa_protagonista.global_position.x
	var jefe_x: float = (_jefe_submarino_ref as Node3D).global_position.x
	var dx: float = jefe_x - canoa_x

	if dx <= distancia_area_jefe and dx >= -20.0:
		_iniciar_musica_jefe()


## Comienza la transición suave: la música actual disminuye y comienza la canción "Jefe rio".
## Si forzar_debug es true (tecla B de testeo) se omite la puerta del checkpoint.
func _iniciar_musica_jefe(forzar_debug: bool = false) -> void:
	if not musica_jefe_activa or _musica_jefe_iniciada or _musica_jefe_finalizada:
		return
	if not forzar_debug and not _puerta_checkpoint_superada():
		return
	_musica_jefe_iniciada = true

	if AudioManager.has_method("crossfade_music"):
		AudioManager.crossfade_music(
			MUSICA_JEFE_RIO,
			duracion_fade_out_musica_nivel,
			duracion_fade_in_musica_jefe
		)
	else:
		AudioManager.play_music(MUSICA_JEFE_RIO)


func _al_iniciar_combate_jefe() -> void:
	_iniciar_musica_jefe()


## Apenas el jefe pierde su último punto de salud: se detiene "Jefe rio",
## suena inmediatamente "Jefe destruido" (sin loop) y, tras una pausa breve,
## comienza nuevamente la música normal del nivel con fade in suave.
func _al_derrotar_jefe() -> void:
	# 0. Al morir el jefe, los corazones del jugador y la vida de Perrena se rellenan al 100%
	curar_jugador_y_perrena_al_derrotar_jefe()
	reset_checkpoint()

	if not musica_jefe_activa or _musica_jefe_finalizada:
		return
	_musica_jefe_finalizada = true

	# 1. Transición inmediata hacia "Jefe destruido" (sin loop)
	if AudioManager.has_method("crossfade_music"):
		AudioManager.crossfade_music(
			MUSICA_JEFE_DESTRUIDO,
			duracion_corte_musica_jefe,
			0.15,
			0.0,
			false
		)
	else:
		AudioManager.play_music(MUSICA_JEFE_DESTRUIDO, false)

	# 2. Calcular la duración de la pista "Jefe destruido" (5.82s) más la pausa breve
	var duracion_audio_destruido: float = 5.82
	if AudioManager.bgm_streams.size() > MUSICA_JEFE_DESTRUIDO:
		var st: AudioStream = AudioManager.bgm_streams[MUSICA_JEFE_DESTRUIDO]
		if is_instance_valid(st) and st.get_length() > 0.0:
			duracion_audio_destruido = st.get_length()

	var tiempo_espera_total: float = duracion_audio_destruido + maxf(pausa_post_jefe_destruido, 0.2)
	var tree: SceneTree = get_tree()
	if tree == null:
		return

	# 3. Tras la fanfarria y la pausa breve, reiniciar la música normal del nivel
	tree.create_timer(tiempo_espera_total).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		if AudioManager.has_method("crossfade_music"):
			AudioManager.crossfade_music(
				MUSICA_VIAJE_RIO,
				0.0,
				duracion_fade_in_musica_nivel,
				0.0,
				true
			)
		else:
			AudioManager.play_music(MUSICA_VIAJE_RIO, true)
	)


## Debug (tecla B): salta directo al combate con el jefe para testearlo.
## Coloca la canoa justo antes del jefe; la cámara y el agua la siguen solas
## en el _process y el jefe emerge al acercarse.
func _teletransportar_a_jefe() -> void:
	var jefe: Node3D = null
	if get_tree() != null:
		jefe = get_tree().get_first_node_in_group("jefe_submarino") as Node3D
	if not is_instance_valid(jefe):
		jefe = find_child("JefeSubmarino", true, false) as Node3D
	if not is_instance_valid(jefe) or not is_instance_valid(canoa_protagonista):
		return
	var destino_x: float = (jefe as Node3D).global_position.x - distancia_previa_jefe
	_teletransportar_canoa_x(destino_x)
	set_travesia_activa(true)
	if canoa_protagonista.has_method("reanudar_navegacion"):
		canoa_protagonista.call("reanudar_navegacion")
	_iniciar_musica_jefe(true)


## Debug (tecla N): salta directo al área de fin de nivel para probar la transición y pantalla final.
func _teletransportar_a_fin_nivel() -> void:
	_teletransportar_canoa_x(x_fin_nivel - 2.5)
	set_travesia_activa(true)
	if is_instance_valid(canoa_protagonista) and canoa_protagonista.has_method("reanudar_navegacion"):
		canoa_protagonista.call("reanudar_navegacion")


## Monitorea el avance de la canoa para disparar la transición de fin de nivel al llegar a la meta.
func _procesar_fin_de_nivel() -> void:
	if _nivel_terminado:
		return
	if not is_instance_valid(canoa_protagonista):
		return
	if canoa_protagonista.global_position.x >= x_fin_nivel:
		terminar_nivel()


## Mueve la canoa en X manteniendo coherentes su posición base y visual.
func _teletransportar_canoa_x(destino_x: float) -> void:
	if not is_instance_valid(canoa_protagonista):
		return
	var val = canoa_protagonista.get("_posicion_base")
	var base: Vector3 = val if (val is Vector3) else canoa_protagonista.position
	base.x = destino_x
	if "_posicion_base" in canoa_protagonista:
		canoa_protagonista.set("_posicion_base", base)
	canoa_protagonista.position.x = base.x
	canoa_protagonista.global_position.x = destino_x
	if is_instance_valid(camara_principal):
		camara_principal.global_position.x = destino_x + _offset_camara_x
	if is_instance_valid(water_plane):
		water_plane.global_position.x = destino_x + _offset_water_x


# === FUNCIONES PÚBLICAS ===
## Finaliza el nivel fluvial activando la transición modular de derecha a izquierda y la pantalla de victoria.
func terminar_nivel(escena_destino: String = "") -> void:
	if _nivel_terminado:
		return
	_nivel_terminado = true
	nivel_completado.emit()

	# 1. Frenar la navegación de la canoa suavemente
	set_travesia_activa(false)

	# 2. Desactivar agresión de posibles enemigos en pantalla
	var enemigos := find_children("*", "EnemyBase", true, false)
	for e in enemigos:
		if is_instance_valid(e) and e is EnemyBase:
			e.set("solo_atacar_en_pantalla", false)

	# 3. Instanciar pantalla y transición cinemática
	var pantalla := PantallaFinNivel.new()
	pantalla.duracion_transicion = duracion_transicion_fin
	pantalla.clave_traduccion_titulo = clave_titulo_fin
	if escena_destino != "":
		pantalla.escena_siguiente = escena_destino
	elif escena_siguiente != "":
		pantalla.escena_siguiente = escena_siguiente

	# 3b. Garantizar la música del nivel bajo la cortinilla (pudo quedar el
	# gap tras la fanfarria del jefe; si ya suena algo no se interrumpe).
	if has_node("/root/AudioManager"):
		var reproductor: AudioStreamPlayer = get_node("/root/AudioManager").get_music_player()
		if reproductor == null or not reproductor.playing:
			AudioManager.play_music(MUSICA_VIAJE_RIO, true)

	_pantalla_fin_nivel = pantalla
	var raiz: Node = get_tree().current_scene if (get_tree() != null and get_tree().current_scene != null) else self
	raiz.add_child(pantalla)
	pantalla.iniciar_transicion()


## Retorna true si el nivel ya concluyó su recorrido y está en transición o pantalla final.
func esta_nivel_terminado() -> bool:
	return _nivel_terminado


## Retorna la instancia de PantallaFinNivel si fue desplegada.
func obtener_pantalla_fin_nivel() -> PantallaFinNivel:
	return _pantalla_fin_nivel


## Configura la velocidad conjunta de navegación y desplazamiento parallax.
func fijar_velocidad_travesia(nueva_vel_canoa: float, nueva_vel_parallax: float) -> void:
	velocidad_canoa = nueva_vel_canoa
	velocidad_parallax = nueva_vel_parallax

	if not _acelerando_debug:
		_velocidad_canoa_base = nueva_vel_canoa
		_velocidad_parallax_base = nueva_vel_parallax

	if is_instance_valid(canoa_protagonista):
		canoa_protagonista.set("velocidad_avance", nueva_vel_canoa)
		if travesia_activa and canoa_protagonista.has_method("iniciar_travesia"):
			canoa_protagonista.call("iniciar_travesia", nueva_vel_canoa)

	if is_instance_valid(parallax_fondo):
		parallax_fondo.set("velocidad_terroso", nueva_vel_parallax)


## Pausa o reanuda la travesía del nivel con transición suave y continua:
## al pausar la canoa frena por rampa manteniendo la flotación (sin
## reposicionamiento de golpe); al reanudar acelera igual de progresivo.
## El parallax se atenúa por rampa en _process.
func set_travesia_activa(activo: bool) -> void:
	travesia_activa = activo
	if not activo and _acelerando_debug:
		set_aceleracion_debug(false)

	if is_instance_valid(canoa_protagonista):
		if activo:
			if canoa_protagonista.has_method("flotar"):
				canoa_protagonista.call("flotar")
			if canoa_protagonista.has_method("iniciar_travesia"):
				canoa_protagonista.call("iniciar_travesia", velocidad_canoa)
		else:
			if canoa_protagonista.has_method("flotar"):
				canoa_protagonista.call("flotar")
			if canoa_protagonista.has_method("detener_navegacion_suave"):
				canoa_protagonista.call("detener_navegacion_suave")
			elif canoa_protagonista.has_method("detener_navegacion"):
				canoa_protagonista.call("detener_navegacion")


## Activa o desactiva la aceleración rápida de debug para testear el recorrido del río.
func set_aceleracion_debug(activa: bool) -> void:
	if _acelerando_debug == activa:
		return

	_acelerando_debug = activa
	var mult: float = multiplicador_aceleracion if _acelerando_debug else 1.0
	var nueva_canoa: float = _velocidad_canoa_base * mult
	var nueva_parallax: float = _velocidad_parallax_base * mult

	fijar_velocidad_travesia(nueva_canoa, nueva_parallax)

	if is_instance_valid(canoa_protagonista) and canoa_protagonista.has_method("set_efecto_viento_activo"):
		canoa_protagonista.call("set_efecto_viento_activo", activa)


## Indica si la aceleración debug con tecla Z está actualmente activa.
func esta_acelerando_debug() -> bool:
	return _acelerando_debug


## Retorna la velocidad base de la canoa antes de cualquier aceleración.
func obtener_velocidad_canoa_base() -> float:
	return _velocidad_canoa_base


## Retorna la velocidad base del parallax antes de cualquier aceleración.
func obtener_velocidad_parallax_base() -> float:
	return _velocidad_parallax_base


## Retorna la referencia viva a la canoa de la protagonista.
func obtener_canoa() -> CanoaAliada:
	return canoa_protagonista


## Retorna la referencia al controlador de parallax de fondo.
func obtener_parallax() -> Node3D:
	return parallax_fondo


## Retorna la referencia a la cámara principal del escenario.
func obtener_camara() -> Camera3D:
	return camara_principal


## Retorna la referencia al plano de agua principal.
func obtener_water_plane() -> Node3D:
	return water_plane


## Retorna los focos que acompañan a la cámara como sol fijo.
func obtener_focos_fijos() -> Array[SpotLight3D]:
	return _focos_fijos


## Retorna el foco del piso 2 si existe en la escena.
func obtener_luz_piso2() -> SpotLight3D:
	return find_child("LuzCentroPiso2", true, false) as SpotLight3D


## Retorna los segmentos de agua que componen el río infinito en repetición.
func obtener_segmentos_agua() -> Array[Node3D]:
	return _segmentos_agua


## Retorna los segmentos de piso aliado sincronizados con la cordillera.
func obtener_segmentos_piso_aliado() -> Array[Node3D]:
	if is_instance_valid(parallax_fondo) and parallax_fondo.has_method("obtener_segmentos_piso_aliado"):
		return parallax_fondo.call("obtener_segmentos_piso_aliado")
	return []


## Retorna la referencia a la Montaña Beta si existe en el escenario.
func obtener_montana_beta() -> Node3D:
	return find_child("MontanaBeta", true, false) as Node3D


## Muestra el HUD de vida (en el nivel 1 lo revelan las instrucciones, aquí no existen).
func mostrar_hud() -> void:
	_mostrar_hud()


func _comprobar_liberacion_aceleracion() -> void:
	if not _acelerando_debug or modo_toggle_z:
		return
	if not (Input.is_key_pressed(KEY_Z) or Input.is_physical_key_pressed(KEY_Z)):
		set_aceleracion_debug(false)


func _mostrar_hud() -> void:
	if get_tree() == null:
		return
	var hud_vida: Node = get_tree().get_first_node_in_group("ui_vida_protagonista")
	if is_instance_valid(hud_vida) and hud_vida.has_method("mostrar"):
		hud_vida.call("mostrar")


func _inicializar_focos_fijos() -> void:
	_focos_fijos.clear()
	_offsets_focos_x.clear()
	if not is_instance_valid(camara_principal):
		return
	var candidatos: Array[Node] = find_children("*", "SpotLight3D", true, false)
	for candidato in candidatos:
		var foco: SpotLight3D = candidato as SpotLight3D
		if foco == null or not _es_foco_fijo(foco):
			continue
		_focos_fijos.append(foco)
		_offsets_focos_x.append(foco.global_position.x - camara_principal.global_position.x)


func _actualizar_focos_fijos() -> void:
	if not focos_fijos_a_camara or not is_instance_valid(camara_principal):
		return
	var camara_x: float = camara_principal.global_position.x
	for i in range(_focos_fijos.size()):
		var foco: SpotLight3D = _focos_fijos[i]
		if is_instance_valid(foco):
			foco.global_position.x = camara_x + _offsets_focos_x[i]


func _es_foco_fijo(foco: SpotLight3D) -> bool:
	var nombre: String = foco.name.to_lower()
	if nombre.begins_with("luzcentropiso"):
		return true
	if nombre.begins_with("luztorre"):
		return true
	return false


func _inicializar_agua() -> void:
	_segmentos_agua.clear()
	# Asegurar que solo el WaterPlane principal esté activo y amplio
	for hijo in get_children():
		if hijo is Node3D and hijo.name.begins_with("WaterPlane"):
			if hijo == water_plane or hijo.name == "WaterPlane":
				hijo.visible = true
				hijo.scale.x = 4.0  # 120 metros de cauce sin cortes
				hijo.scale.z = 3.2  # Extensión hasta la base de la cordillera
				_segmentos_agua.append(hijo)
			else:
				# Desactivar planos duplicados para evitar cortes visuales
				hijo.visible = false

	if is_instance_valid(water_plane):
		water_plane.visible = true
		water_plane.scale.x = 4.0
		water_plane.scale.z = 3.2
		if not _segmentos_agua.has(water_plane):
			_segmentos_agua.append(water_plane)


func _inicializar_escenario() -> void:
	if musica_viaje_rio:
		AudioManager.play_music(MUSICA_VIAJE_RIO)

	_mostrar_hud()

	if is_instance_valid(canoa_protagonista):
		canoa_protagonista.set("velocidad_avance", velocidad_canoa)
		if travesia_activa:
			if canoa_protagonista.has_method("iniciar_travesia"):
				canoa_protagonista.call("iniciar_travesia", velocidad_canoa)
		else:
			if canoa_protagonista.has_method("detener"):
				canoa_protagonista.call("detener")
		if canoa_protagonista.has_method("set_efecto_viento_activo"):
			canoa_protagonista.call("set_efecto_viento_activo", _acelerando_debug)

	if is_instance_valid(parallax_fondo):
		parallax_fondo.set("velocidad_terroso", velocidad_parallax)
		if parallax_fondo.has_method("set_desplazamiento_activo"):
			parallax_fondo.call("set_desplazamiento_activo", travesia_activa)

	_configurar_enemigos_para_camara()


## Configura a todos los enemigos del nivel río para que solo puedan atacar cuando estén en pantalla/rango de cámara
## y no se caigan de las plataformas mientras estén vivos.
func _configurar_enemigos_para_camara() -> void:
	var enemigos := find_children("*", "EnemyBase", true, false)
	for e in enemigos:
		if is_instance_valid(e) and e is EnemyBase:
			e.solo_atacar_en_pantalla = true
			e.set("evitar_caer_plataformas", true)
			if "activar_al_entrar_en_camara" in e:
				e.set("activar_al_entrar_en_camara", true)
			if is_instance_valid(camara_principal):
				e.set("_camara_cache_pantalla", camara_principal)
			_desactivar_drops_enemigo(e)

	if get_tree():
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e is EnemyBase:
				e.solo_atacar_en_pantalla = true
				e.set("evitar_caer_plataformas", true)
				if "activar_al_entrar_en_camara" in e:
					e.set("activar_al_entrar_en_camara", true)
				if is_instance_valid(camara_principal):
					e.set("_camara_cache_pantalla", camara_principal)
				_desactivar_drops_enemigo(e)
		if not get_tree().node_added.is_connected(_on_node_added_nivel_rio):
			get_tree().node_added.connect(_on_node_added_nivel_rio)


func _on_node_added_nivel_rio(node: Node) -> void:
	if node is EnemyBase:
		(node as EnemyBase).solo_atacar_en_pantalla = true
		(node as EnemyBase).set("evitar_caer_plataformas", true)
		if "activar_al_entrar_en_camara" in node:
			node.set("activar_al_entrar_en_camara", true)
		if is_instance_valid(camara_principal):
			node.set("_camara_cache_pantalla", camara_principal)
		_desactivar_drops_enemigo(node)


## En el nivel del río los enemigos no deben soltar power-ups (solo la vasija contenedora).
func _desactivar_drops_enemigo(e: Node) -> void:
	if not is_instance_valid(e):
		return
	if "probabilidad_drop_fuego_rapido" in e:
		e.set("probabilidad_drop_fuego_rapido", 0.0)
	if "probabilidad_drop_arco_triple" in e:
		e.set("probabilidad_drop_arco_triple", 0.0)
	if "probabilidad_drop_flecha_explosiva" in e:
		e.set("probabilidad_drop_flecha_explosiva", 0.0)
	if "drop_chance_flecha_explosiva" in e:
		e.set("drop_chance_flecha_explosiva", 0.0)
	if "probabilidad_drop" in e:
		e.set("probabilidad_drop", 0.0)
	if "drop_chance_power_up" in e:
		e.set("drop_chance_power_up", 0.0)


## Localiza los puntos de referencia del tramo fluvial acelerado y se los transfiere a la canoa.
func _inicializar_tramo_aceleracion() -> void:
	if not is_instance_valid(canoa_protagonista):
		return
	var x_inicio: float = 60.395
	var x_fin: float = 126.01

	var puente_ref: Node = find_child(nombre_referencia_inicio_aceleracion, true, false)
	if not is_instance_valid(puente_ref):
		puente_ref = find_child("PuenteMaderaParaPosicionar8*", true, false)
	if is_instance_valid(puente_ref) and puente_ref is Node3D:
		x_inicio = (puente_ref as Node3D).global_position.x

	var barco_ref: Node = find_child(nombre_barco_checkpoint, true, false)
	if not is_instance_valid(barco_ref):
		barco_ref = find_child("BarcoCombatePirata3*", true, false)
	if is_instance_valid(barco_ref) and barco_ref is Node3D:
		x_fin = (barco_ref as Node3D).global_position.x

	# El tramo llega hasta el fin del nivel: pasado el barco, sin enemigos
	# cerca la canoa sigue rápida con viento hasta la cortinilla final.
	x_fin = maxf(x_fin, x_fin_nivel)

	if canoa_protagonista.has_method("configurar_tramo_aceleracion"):
		canoa_protagonista.call("configurar_tramo_aceleracion", x_inicio, x_fin, velocidad_canoa_tramo_acelerado)


## Escanea periódicamente las entidades enemigas activas: si alguna cae al agua (sin suelo y Y <= UMBRAL),
## la ahoga de inmediato para evitar que bloquee o detenga la canoa erróneamente.
func _procesar_enemigos_caidos_al_agua(delta: float = 0.016) -> void:
	if get_tree() == null:
		return

	_tiempo_nivel_rio += delta
	# Esperar a que la física y las plataformas se asienten al arrancar el nivel (evita falsos splashes de inicio)
	if _tiempo_nivel_rio < TIEMPO_GRACIA_INICIO_RIO:
		return

	# Throttle: comprobar caídas al agua máximo 10 veces/segundo (83% menos CPU)
	_timer_check_agua += delta
	if _timer_check_agua < INTERVALO_CHECK_AGUA:
		return
	_timer_check_agua = 0.0

	var grupos: Array[String] = ["enemies", "enemigos"]
	for grupo in grupos:
		var lista: Array[Node] = get_tree().get_nodes_in_group(grupo)
		for nodo in lista:
			if not is_instance_valid(nodo) or not (nodo is Node3D):
				continue
			var enemigo := nodo as Node3D
			if enemigo.has_meta("ahogado_en_agua"):
				continue
			# Solo entidades con física dinámica o personajes pueden caer al agua;
			# nunca estructuras estáticas como pilares, escudos o defensas.
			if not (enemigo is CharacterBody3D or enemigo is RigidBody3D):
				continue
			if _es_entidad_acuatica_excluida(enemigo):
				continue

			# Si el enemigo está apoyado sobre suelo/plataforma/barco, NO ha caído al agua
			if enemigo.has_method("is_on_floor") and bool(enemigo.call("is_on_floor")):
				continue

			if enemigo.global_position.y <= UMBRAL_CAIDA_AGUA_ENEMIGO_Y:
				_ahogar_enemigo_en_agua(enemigo)


## Determina si la entidad es acuática legítima (submarino, mina, pez, balsa) o estructura que no debe morir al estar en agua.
func _es_entidad_acuatica_excluida(nodo: Node) -> bool:
	if not is_instance_valid(nodo):
		return true
	if nodo is SubmarinoRio or nodo.name.begins_with("Submarino") or nodo.name.begins_with("JefeSubmarino"):
		return true
	if nodo is MinaAcuatica or nodo.is_in_group("mina_acuatica") or nodo.is_in_group("minas"):
		return true
	if nodo is PezDeRio or nodo.name.begins_with("Pez"):
		return true
	if nodo is BalsaPirata or nodo is BalsaPirataCombate:
		return true
	if nodo.name.begins_with("BalsaPirata") or nodo.name.begins_with("BarcoCombatePirata"):
		return true
	if nodo is PilarLonkoBody or "es_pilar_enemigo" in nodo or nodo.is_in_group("escudos") or nodo.name.begins_with("Pilar"):
		return true
	var padre: Node = nodo.get_parent()
	while is_instance_valid(padre):
		if padre is SubmarinoRio or padre is BalsaPirata or padre is BalsaPirataCombate or padre.name.begins_with("Pilar"):
			return true
		padre = padre.get_parent()
	return false


## Ejecuta la muerte instantánea del enemigo caído al agua:
## 1. Genera el mini-splash y animación de onda acuática estilo Azulina pero más pequeño (0.18).
## 2. Emite SFX de splash de agua.
## 3. Lo retira de inmediato de los grupos de enemigos y de la canoa para que no bloquee el paso.
## 4. Hunde y libera al enemigo limpiamente.
func _ahogar_enemigo_en_agua(enemigo: Node3D) -> void:
	if not is_instance_valid(enemigo):
		return
	enemigo.set_meta("ahogado_en_agua", true)

	var pos_enemigo: Vector3 = enemigo.global_position
	var altura_agua: float = -0.22
	if is_instance_valid(water_plane):
		altura_agua = water_plane.global_position.y + 0.01

	var punto_splash: Vector3 = Vector3(pos_enemigo.x, altura_agua, pos_enemigo.z)
	_generar_mini_splash_agua(punto_splash)

	# Desvincular de inmediato de los grupos de enemigos para que la canoa no se detenga
	if enemigo.is_in_group("enemies"):
		enemigo.remove_from_group("enemies")
	if enemigo.is_in_group("enemigos"):
		enemigo.remove_from_group("enemigos")

	# Limpiar bloqueo en la canoa si este enemigo la estaba frenando
	if is_instance_valid(canoa_protagonista):
		if "_enemigos_en_area_contacto" in canoa_protagonista:
			var area_enemigos: Array = canoa_protagonista.get("_enemigos_en_area_contacto")
			area_enemigos.erase(enemigo)
		if "_enemigo_bloqueando" in canoa_protagonista and canoa_protagonista.get("_enemigo_bloqueando") == enemigo:
			canoa_protagonista.set("_enemigo_bloqueando", null)
			canoa_protagonista.set("_detenida_por_contacto", false)

	# Desactivar física y colisiones
	if enemigo is CollisionObject3D:
		var co := enemigo as CollisionObject3D
		co.collision_layer = 0
		co.collision_mask = 0
	for col_child in enemigo.find_children("*", "CollisionShape3D", true, false):
		var cs := col_child as CollisionShape3D
		if cs:
			cs.set_deferred("disabled", true)

	enemigo.set_physics_process(false)
	enemigo.set_process(false)

	# Notificar muerte si tiene señal died
	if enemigo.has_signal("died") and not bool(enemigo.get("_died_signal_emitted")):
		enemigo.set("_died_signal_emitted", true)
		enemigo.emit_signal("died")

	# Animación de hundimiento y liberación
	if is_inside_tree() and get_tree() != null:
		var tween: Tween = create_tween()
		if is_instance_valid(tween):
			tween.set_parallel(true)
			tween.tween_property(enemigo, "global_position:y", enemigo.global_position.y - 0.7, 0.5)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(enemigo, "scale", Vector3.ZERO, 0.5)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tween.chain().tween_callback(enemigo.queue_free)
		else:
			enemigo.queue_free()
	else:
		enemigo.queue_free()


## Instancia el efecto de salpicadura y onda acuática idéntico al de Azulina
## pero a una escala reducida (mini splash 0.18 vs 0.35 de Azulina).
func _generar_mini_splash_agua(punto_rotura: Vector3) -> void:
	if not ESCENA_MINI_SPLASH or not is_inside_tree() or get_tree() == null:
		return

	var splash := ESCENA_MINI_SPLASH.instantiate() as Node3D
	if splash == null:
		return

	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	if raiz == null:
		splash.queue_free()
		return

	raiz.add_child(splash)
	splash.global_position = punto_rotura
	splash.scale = Vector3.ONE * escala_mini_splash_agua

	_asegurar_capa_visual_splash(splash)

	if splash.has_method("play_splash"):
		splash.play_splash()

	var dist_camara: float = INF
	if is_instance_valid(camara_principal):
		dist_camara = absf(punto_rotura.x - camara_principal.global_position.x)
	elif is_instance_valid(canoa_protagonista):
		dist_camara = absf(punto_rotura.x - canoa_protagonista.global_position.x)

	if dist_camara <= DISTANCIA_MAX_SFX_SPLASH:
		if has_node("/root/AudioManager"):
			var audio_mgr = get_node("/root/AudioManager")
			if audio_mgr.has_method("play_sfx_3d"):
				audio_mgr.play_sfx_3d(SFX_SPLASH_AGUA, punto_rotura)
			elif audio_mgr.has_method("play_sfx"):
				audio_mgr.play_sfx(SFX_SPLASH_AGUA)

	get_tree().create_timer(duracion_mini_splash_agua).timeout.connect(func():
		if is_instance_valid(splash):
			splash.queue_free()
	)


func _asegurar_capa_visual_splash(nodo: Node) -> void:
	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = 1
	for hijo: Node in nodo.get_children():
		_asegurar_capa_visual_splash(hijo)
