extends Node3D
## Script principal del nivel. Controla el flujo:
## Nivel 0 (pacifista) → Nivel 1 (combate, 2 oleadas)
# === CONFIGURACIÓN GENERAL ===
enum NivelEstado {NIVEL_0, TRANSICION, NIVEL_1, VICTORIA_PACIFISTA, VICTORIA_NIVEL1, OLEADAS_LIBRES}
const RUTA_SHADER_OUTLINE := "res://System/Shaders/TOON_LINEANEGRA.gdshader"
const CAPA_VISUAL_FONDO_DOF := 2
const MONITOR_INTERVAL: float = 0.3  # Chequear estado de oleada ~3 veces por segundo
const TAMANO_MINIMO_SUBVIEWPORT: int = 1
const TAMANO_MINIMO_TEXTURA_FONDO: float = 1.0
const PROFUNDIDAD_MINIMA_FONDO: float = 0.01
const PIXEL_SIZE_MINIMO_FONDO: float = 0.0001
const GRUPOS_LIMPIEZA_COMBATE: Array[String] = [
	"enemy_projectiles", "enemies", "shield_imps", "pickups", "power_ups_flecha_explosiva"
]
@export_category("Configuración General")
@export var limite_fin_mapa_x: float = -5.0  ## Posición X donde el Imp se detiene
@export var total_enemigos_nivel1: int = 15  ## Enemigos totales en la Oleada 1 (12 en cola + 3 pacíficos convertidos)
@export var total_enemigos_oleada_2: int = 25  ## Enemigos totales en la Oleada 2
@export var total_enemigos_oleada_3: int = 30  ## Enemigos totales en la Oleada 3
@export var total_enemigos_oleada_4: int = 45  ## Enemigos totales en la Oleada 4 (35 base + 10 refuerzos cuerno)
@export var total_enemigos_oleada_5: int = 50  ## Enemigos totales en la Oleada 5 (40 base + 10 refuerzos cuerno)
@export_category("Rendimiento")
@export_range(0.5, 1.0, 0.05) var escala_render_subviewport_fondo_3d: float = 0.95
@export_range(0.75, 1.0, 0.05) var escala_render_subviewport_frente_3d: float = 1.0
@export_range(1.0, 1.4, 0.01) var escala_cobertura_fondo_animado: float = 1.18
@export var limitar_fps_subviewport_fondo_3d: bool = true
@export_range(15, 60, 1) var fps_subviewport_fondo_3d: int = 30
@export var pausar_video_fondo_en_combate: bool = false
@export_category("Debug")
@export var debug_logs_enabled: bool = false
# === CONFIGURACIÓN NIVEL 0 (PACIFISTA) ===
@export_category("Nivel 0 — Pacifista")
@export var velocidad_pacificos: float = 0.5  ## Velocidad de caminata de los pacíficos
@export var offset_entre_pacificos: float = 0.4  ## Separación X entre cada pacífico al spawnear
@export var tamano_imagen_emisario: Vector2 = Vector2(180, 180)  ## Tamaño del icono del emisario en el diálogo
@export var tamano_imagen_protagonista: Vector2 = Vector2(180, 180)  ## Tamaño del icono de la protagonista en el diálogo inicial
@export var retroceso_parada_arqueras: float = 0.2  ## Cada arquera se para 0.2u más adelante que la anterior
@export var delay_dialogo_inicio: float = 1.0  ## Segundos antes de mostrar el mensaje inicial de protagonista
@export var delay_dialogo_pacifico: float = 2.0  ## Segundos de espera antes de mostrar el diálogo pacifista
@export_range(0.005, 0.08, 0.005) var velocidad_texto_novela: float = 0.02  ## Velocidad del reveal del texto (segundos por caracter)
@export_range(0.9, 2.0, 0.05) var pitch_habla_protagonista: float = 1.1  ## Pitch del tecleo metálico del diálogo inicial
@export var volumen_habla_protagonista_db: float = -16.0  ## Volumen del tecleo metálico en diálogo inicial
@export_range(2, 20, 1) var chars_por_habla_protagonista: int = 7  ## Frecuencia del tecleo metálico
@export_range(0.05, 0.5, 0.01) var intervalo_min_habla_protagonista: float = 0.18  ## Intervalo mínimo entre sonidos de habla
# === ESTADO DEL NIVEL ===
var estado_actual: int = NivelEstado.NIVEL_0
var enemigos_pacificos: Array = []  ## Los 3 enemigos del nivel 0
var imp_estandarte: Node3D = null  ## Referencia al imp que lleva el estandarte
var oleada_debug_pendiente: int = 0  ## Oleada solicitada por debug: se aplica tras el intro y el evento del embajador
var oleada_combate_actual: int = 1
var transicion_carteles_en_progreso: bool = false
var _aliadas_activas: bool = true  ## Estado de aliadas para modo debug
# === REFERENCIAS ===
const ESCENA_TRIDENTE_IMP: PackedScene = preload("res://Entities/Proyectil_Tridente_Imp/ImpTrident.tscn")
const ESCENA_FLECHA_GOBLIN: PackedScene = preload("res://Entities/Proyectil_Flecha_Goblin/GoblinArrow.tscn")
const ESCENA_PROYECTIL_GARGOLA: PackedScene = preload("res://Entities/Proyectil_Gargola/GargolaProjectile.tscn")
const ESCENA_GOBLIN_BALLESTA: PackedScene = preload("res://Entities/Enemigo_Goblin/Goblin.tscn")
const ESCALA_PRECALENTA: float = 0.05  ## Escala mini de las instancias de warm-up (caben dentro del HUD)
var _viewport_precarga: SubViewport = null  ## Viewport invisible para compilar shaders sin mostrar nada
@onready
var busto_bronce_fondo: Node3D = _buscar_nodo_fondo_multiple(["BUSTO_BRONCE", "BUSTO_BRONCE2"])
var escena_imp_estandarte: PackedScene = preload("res://Entities/Enemigo_Imp_Estandarte/ImpEnemyEstandarte.tscn")
var escena_dialogo_inicio_protagonista: PackedScene = preload(
	"res://UI/Dialogo_Protagonista.tscn"
)
var escena_instrucciones_mouse: PackedScene = preload(
	"res://UI/Instrucciones/UI_INSTRUCCIONES_Mouse.tscn"
)
var escena_dialogo_emisario_parte1: PackedScene = preload(
	"res://UI/Dialogo_Emisario_Parte1.tscn"
)
var escena_resultado_pacifista: PackedScene = preload("res://UI/Resultado_Pacifista.tscn")
var sfx_habla_dialogo: AudioStream = preload(
	"res://Entities/Ambiente_Escudo/IMPACTO_ESCUDO_BALLESTA.mp3"
)
var estados_proceso_jugador: Dictionary = {}
var estados_proceso_dialogo: Dictionary = {}
var estado_spawner_dialogo: Dictionary = {}
var _dialogo_audio_player: AudioStreamPlayer
var _cached_players: Array[Node] = []
var _fondo_render_timer: float = 0.0
var _escala_base_fondo_animado: Vector3 = Vector3.ONE
# === OPTIMIZACIÓN: Monitoreo de oleadas con timer ===
var _monitor_timer: float = 0.0
@onready var wave_spawner: WaveSpawner = $WaveSpawner
@onready var game_ui = $GameUI
@onready var fondo_3d_rect: TextureRect = (
	get_node_or_null("Compositor3D/Fondo3DRect") as TextureRect
)
@onready var medio_3d_rect: TextureRect = (
	get_node_or_null("Compositor3D/Fondo3DRect/Medio3DRect") as TextureRect
)
@onready var frente_3d_rect: TextureRect = (
	get_node_or_null("Compositor3D/Fondo3DRect/Medio3DRect/Frente3DRect") as TextureRect
)
@onready var texture_rect: TextureRect = (
	get_node_or_null("SubViewportFondo3D/SubViewport/TextureRect") as TextureRect
)
@onready var subviewport_fondo_3d: SubViewport = $SubViewportFondo3D
@onready var subviewport_medio_3d: SubViewport = $SubViewportMedio3D
@onready var subviewport_frente_3d: SubViewport = $SubViewportFrente3D
@onready var fondo_animado_sprite: Sprite3D = (
	get_node_or_null("SubViewportFondo3D/FONDO ANIMADO") as Sprite3D
)
@onready var camara_fondo_3d: Camera3D = (
	get_node_or_null("SubViewportFondo3D/CamaraFondoDOF") as Camera3D
)
@onready var subviewport_video_fondo: SubViewport = (
	get_node_or_null("SubViewportFondo3D/SubViewport") as SubViewport
)
@onready var video_fondo: VideoStreamPlayer = (
	get_node_or_null("SubViewportFondo3D/SubViewport/VideoStreamPlayer") as VideoStreamPlayer
)
@onready var torre2_fondo: Node3D = _buscar_nodo_fondo_multiple(["TORRE", "TORRE2", "TORRE3"])
@onready var escena_rampa_nivel3: Node3D = $EscenaRampaNivel3
@onready var muro_plataforma: StaticBody3D = $Muro_Plataforma
@onready var muro_plataforma2: StaticBody3D = $Muro_Plataforma2
var escudo_enemigo: EscudoDestruible:
	get:
		return get_node_or_null("Escudo_enemigo") as EscudoDestruible
var escudo_enemigo2: EscudoDestruible:
	get:
		return get_node_or_null("NIVEL_2_Escudo_enemigo2") as EscudoDestruible
var escudo_enemigo3: EscudoDestruible:
	get:
		return get_node_or_null("NIVEL_2_Escudo_enemigo3") as EscudoDestruible
# === ESCENAS ===


func _ready():
	_dialogo_audio_player = AudioStreamPlayer.new()
	_dialogo_audio_player.bus = "Master"
	add_child(_dialogo_audio_player)
	
	# Ocultar elementos de la oleada 2, 3 y 4 al inicio
	if is_instance_valid(escena_rampa_nivel3):
		_set_elemento_nivel3_activo(escena_rampa_nivel3, false)
	if is_instance_valid(muro_plataforma):
		_set_elemento_nivel3_activo(muro_plataforma, false)
	if is_instance_valid(muro_plataforma2):
		_set_elemento_nivel3_activo(muro_plataforma2, false)
	if is_instance_valid(escudo_enemigo):
		_set_elemento_nivel3_activo(escudo_enemigo, false)
	if is_instance_valid(escudo_enemigo2):
		_set_elemento_nivel3_activo(escudo_enemigo2, false)
	if is_instance_valid(escudo_enemigo3):
		_set_elemento_nivel3_activo(escudo_enemigo3, false)

	_forzar_refresco_outline_global()
	_configurar_compositor_3d()
	_configurar_render_subviewports()
	_configurar_fondo_3d()

	# Ocultar TextureRect del SubViewport solo si hay un video de fondo activo
	if texture_rect:
		texture_rect.visible = (video_fondo == null)

	_ajustar_subviewports_3d()
	_configurar_capas_dof_fondo()
	if not get_viewport().size_changed.is_connected(_ajustar_subviewports_3d):
		get_viewport().size_changed.connect(_ajustar_subviewports_3d)

	# Warm-up de shaders
	VFXFactory.warmup_shaders(self)

	# Sonido ambiente desde el arranque del juego
	AudioManager.play_music(3, true, 12.0)  # SONIDO BOSQUE.mp3

	# Esperar un frame para que todos los nodos estén listos
	_precalentar_vfx_shaders()

	await get_tree().process_frame

	# --- MODO DEBUG solicitado desde menú escape (botón Nivel Debug) ---
	# Predominancia NIVEL01: si se entra por el botón debug del pause, se activa
	# el panel de control de spawn flotante y el modo oleadas libres directamente,
	# sin pasar por el diálogo pacifista. El panel solo aparece en este modo.
	if GameUI.modo_debug_solicitado:
		GameUI.modo_debug_solicitado = false
		GameUI.oleada_inicial_solicitada = 0
		oleada_debug_pendiente = 0
		# UI debug mínima
		if game_ui:
			game_ui.set_bottom_panel_visible(true)
			if game_ui.has_method("set_modo_minimo"):
				game_ui.set_modo_minimo(false)
		var _dbg_player = get_tree().get_first_node_in_group("player")
		if _dbg_player:
			if "flechas_explosivas" in _dbg_player:
				_dbg_player.flechas_explosivas = 5
				if _dbg_player.has_signal("flechas_explosivas_changed"):
					_dbg_player.flechas_explosivas_changed.emit(5)
			if "disparo_bloqueado_por_ui" in _dbg_player:
				_dbg_player.disparo_bloqueado_por_ui = true
		for ally in AllyArcher.active_allies_cache:
			if is_instance_valid(ally) and ally is AllyArcher:
				ally.flechas_explosivas = 5
		get_tree().call_group("ui_vida_protagonista", "mostrar")
		_set_aliadas_activas(true)
		AudioManager.play_music(2)
		_iniciar_oleadas_libres()
		_crear_panel_controles_spawn()
		if wave_spawner and not wave_spawner.oleada_iniciada.is_connected(_on_oleada_iniciada_eliminar_defensas):
			wave_spawner.oleada_iniciada.connect(_on_oleada_iniciada_eliminar_defensas)
		return

	# --- CONTINUAR DESDE GAME OVER: reinicia directo en la oleada donde murió ---
	if GameUI.continuar_desde_oleada > 0:
		var oleada_continuar: int = clamp(GameUI.continuar_desde_oleada, 1, 5)
		GameUI.continuar_desde_oleada = 0
		GameUI.oleada_inicial_solicitada = 0
		oleada_debug_pendiente = 0
		oleada_combate_actual = oleada_continuar
		if game_ui and game_ui.has_method("set_modo_minimo"):
			game_ui.set_modo_minimo(false)
		get_tree().call_group("ui_vida_protagonista", "mostrar")
		_set_aliadas_activas(true)
		AudioManager.play_music(2)
		var total_continuar: int = total_enemigos_nivel1
		match oleada_continuar:
			2: total_continuar = total_enemigos_oleada_2
			3: total_continuar = total_enemigos_oleada_3
			4: total_continuar = total_enemigos_oleada_4
			5: total_continuar = total_enemigos_oleada_5
		_configurar_oleada_combate(total_continuar, oleada_continuar)
		if wave_spawner and not wave_spawner.oleada_iniciada.is_connected(_on_oleada_iniciada_eliminar_defensas):
			wave_spawner.oleada_iniciada.connect(_on_oleada_iniciada_eliminar_defensas)
		return

	# Si se solicitó una oleada específica desde el menú de pausa / debug, se
	# DIFIERE: primero se reproducen el diálogo inicial y el evento del goblin
	# embajador; el salto de oleada se aplica al comenzar el combate.
	oleada_debug_pendiente = GameUI.oleada_inicial_solicitada
	GameUI.oleada_inicial_solicitada = 0

	# Detener el spawner automático desde el inicio para evitar aparición previa al diálogo.
	wave_spawner.detener_spawning()

	# Espera inicial solicitada antes del cuadro de diálogo
	await get_tree().create_timer(delay_dialogo_inicio).timeout

	# Warm-up de shaders durante el diálogo: instancia brevemente los enemigos
	# y proyectiles del nivel en un punto CUBIERTO por el panel del diálogo,
	# para que la GPU compile sus pipelines sin tirones en combate.
	_precalentar_combate_con_retraso(0.5)

	# Mensaje inicial de protagonista antes de iniciar el flujo pacifista
	await _mostrar_dialogo_inicio_protagonista()

	# Mostrar instrucciones de mouse inmediatamente tras cerrar el diálogo
	_mostrar_instrucciones_mouse()

	# Iniciar Nivel 0
	_iniciar_nivel_0()


## Precalienta y compila en GPU los shaders de efectos para evitar tirones y asegurar tamaño correcto en el primer tiro
func _precalentar_vfx_shaders() -> void:
	var explosion_scene := preload("res://assets/BinbunVFX_Vol2/ExplosionFX/effects/air/vfx_air_explosion_01.tscn")
	if explosion_scene:
		var vfx := explosion_scene.instantiate() as Node3D
		if vfx:
			add_child(vfx)
			vfx.global_position = Vector3(0.0, -200.0, 0.0)
			get_tree().create_timer(0.2).timeout.connect(func():
				if is_instance_valid(vfx):
					vfx.queue_free()
			)


func _mostrar_instrucciones_mouse() -> void:
	# El panel de instrucciones solo debe aparecer al inicio del Nivel 1 (oleada 1).
	# Si se está en oleadas 2, 3, 4 o cualquier otro nivel, no se muestra.
	if oleada_combate_actual != 1:
		return

	if escena_instrucciones_mouse:
		var inst = escena_instrucciones_mouse.instantiate()
		add_child(inst)


func _ajustar_subviewports_3d() -> void:
	var tamano_viewport := get_viewport().get_visible_rect().size
	var tamano_render_fondo := _calcular_tamano_render(
		tamano_viewport, escala_render_subviewport_fondo_3d
	)
	var tamano_render_frente := _calcular_tamano_render(
		tamano_viewport, escala_render_subviewport_frente_3d
	)

	if subviewport_fondo_3d:
		subviewport_fondo_3d.size = tamano_render_fondo

	if subviewport_medio_3d:
		subviewport_medio_3d.size = tamano_render_frente
		subviewport_medio_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	if subviewport_frente_3d:
		subviewport_frente_3d.size = tamano_render_frente
		subviewport_frente_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_ajustar_subviewport_video_fondo(tamano_render_fondo)
	_aplicar_cobertura_fondo_animado()


func _calcular_tamano_render(tamano_viewport: Vector2, escala_render: float) -> Vector2i:
	var escala_clampeada: float = clamp(escala_render, 0.5, 1.0)
	return Vector2i(
		max(TAMANO_MINIMO_SUBVIEWPORT, int(tamano_viewport.x * escala_clampeada)),
		max(TAMANO_MINIMO_SUBVIEWPORT, int(tamano_viewport.y * escala_clampeada))
	)


func _configurar_render_subviewports() -> void:
	if subviewport_fondo_3d:
		subviewport_fondo_3d.render_target_update_mode = (
			SubViewport.UPDATE_ONCE if limitar_fps_subviewport_fondo_3d else SubViewport.UPDATE_ALWAYS
		)

	if subviewport_video_fondo:
		subviewport_video_fondo.render_target_update_mode = (
			SubViewport.UPDATE_ONCE if limitar_fps_subviewport_fondo_3d else SubViewport.UPDATE_ALWAYS
		)

	if subviewport_medio_3d:
		subviewport_medio_3d.msaa_3d = Viewport.MSAA_4X
		subviewport_medio_3d.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		subviewport_medio_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	if subviewport_frente_3d:
		subviewport_frente_3d.msaa_3d = Viewport.MSAA_4X
		subviewport_frente_3d.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		subviewport_frente_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _configurar_compositor_3d() -> void:
	_configurar_texture_rect_fullscreen(fondo_3d_rect)
	_configurar_texture_rect_fullscreen(frente_3d_rect)


func _configurar_texture_rect_fullscreen(rect: TextureRect) -> void:
	if rect == null:
		return

	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _configurar_fondo_3d() -> void:
	if fondo_animado_sprite:
		_escala_base_fondo_animado = fondo_animado_sprite.scale
		_aplicar_cobertura_fondo_animado()

	_desactivar_sombras_recursivas(subviewport_fondo_3d)

	if texture_rect:
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE


func _aplicar_cobertura_fondo_animado() -> void:
	if not fondo_animado_sprite:
		return

	var tamano_visible := _obtener_tamano_visible_fondo_en_mundo()
	var tamano_textura := _obtener_tamano_textura_fondo()
	if tamano_visible == Vector2.ZERO or tamano_textura == Vector2.ZERO:
		fondo_animado_sprite.scale = Vector3(
			_escala_base_fondo_animado.x * escala_cobertura_fondo_animado,
			_escala_base_fondo_animado.y * escala_cobertura_fondo_animado,
			_escala_base_fondo_animado.z
		)
		return

	var pixel_size: float = max(PIXEL_SIZE_MINIMO_FONDO, fondo_animado_sprite.pixel_size)
	var ancho_base: float = max(TAMANO_MINIMO_TEXTURA_FONDO, tamano_textura.x * pixel_size)
	var alto_base: float = max(TAMANO_MINIMO_TEXTURA_FONDO, tamano_textura.y * pixel_size)
	var escala_x: float = (tamano_visible.x * escala_cobertura_fondo_animado) / ancho_base
	var escala_y: float = (tamano_visible.y * escala_cobertura_fondo_animado) / alto_base

	fondo_animado_sprite.scale = Vector3(
		max(_escala_base_fondo_animado.x, escala_x),
		max(_escala_base_fondo_animado.y, escala_y),
		_escala_base_fondo_animado.z
	)


func _obtener_tamano_visible_fondo_en_mundo() -> Vector2:
	if not camara_fondo_3d or not fondo_animado_sprite or not subviewport_fondo_3d:
		return Vector2.ZERO

	var direccion_camara := -camara_fondo_3d.global_transform.basis.z.normalized()
	var distancia_a_fondo := (
		fondo_animado_sprite.global_position - camara_fondo_3d.global_position
	).dot(direccion_camara)
	if distancia_a_fondo <= PROFUNDIDAD_MINIMA_FONDO:
		return Vector2.ZERO

	var tamano_viewport := Vector2(subviewport_fondo_3d.size)
	var esquina_superior_izquierda := camara_fondo_3d.project_position(
		Vector2.ZERO, distancia_a_fondo
	)
	var esquina_superior_derecha := camara_fondo_3d.project_position(
		Vector2(tamano_viewport.x, 0.0), distancia_a_fondo
	)
	var esquina_inferior_izquierda := camara_fondo_3d.project_position(
		Vector2(0.0, tamano_viewport.y), distancia_a_fondo
	)

	return Vector2(
		esquina_superior_izquierda.distance_to(esquina_superior_derecha),
		esquina_superior_izquierda.distance_to(esquina_inferior_izquierda)
	)


func _obtener_tamano_textura_fondo() -> Vector2:
	if fondo_animado_sprite.texture:
		var tamano_textura := fondo_animado_sprite.texture.get_size()
		if (
			tamano_textura.x >= TAMANO_MINIMO_TEXTURA_FONDO
			and tamano_textura.y >= TAMANO_MINIMO_TEXTURA_FONDO
		):
			return tamano_textura

	if subviewport_video_fondo:
		return Vector2(subviewport_video_fondo.size)

	return Vector2.ZERO


func _log_debug(message: String) -> void:
	if not debug_logs_enabled:
		return

	print(message)


func _desactivar_sombras_recursivas(nodo: Node) -> void:
	if nodo == null:
		return

	if nodo is GeometryInstance3D:
		(nodo as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for hijo in nodo.get_children():
		_desactivar_sombras_recursivas(hijo)


func _ajustar_subviewport_video_fondo(tamano_base: Vector2i) -> void:
	if not subviewport_video_fondo:
		return

	var relacion_video: float = 1505.0 / 1080.0
	var alto_video: int = max(TAMANO_MINIMO_SUBVIEWPORT, tamano_base.y)
	var ancho_video: int = max(TAMANO_MINIMO_SUBVIEWPORT, int(float(alto_video) * relacion_video))
	var tamano_video := Vector2i(ancho_video, alto_video)

	subviewport_video_fondo.size = tamano_video

	for hijo in subviewport_video_fondo.get_children():
		if hijo is Control:
			var control := hijo as Control
			control.custom_minimum_size = Vector2(tamano_video)
			control.size = Vector2(tamano_video)


func _configurar_capas_dof_fondo() -> void:
	_asignar_capa_visual_recursiva(busto_bronce_fondo, CAPA_VISUAL_FONDO_DOF)
	_asignar_capa_visual_recursiva(torre2_fondo, CAPA_VISUAL_FONDO_DOF)


func _buscar_nodo_fondo_multiple(nombres_nodo: Array[String]) -> Node3D:
	for nombre_nodo in nombres_nodo:
		var nodo := find_child(nombre_nodo, true, false)
		if nodo is Node3D:
			return nodo
	return null


func _asignar_capa_visual_recursiva(nodo: Node, capa: int) -> void:
	if nodo == null:
		return

	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = capa

	for hijo in nodo.get_children():
		_asignar_capa_visual_recursiva(hijo, capa)


func _forzar_refresco_outline_global() -> void:
	# Mantiene compatibilidad con versiones antiguas del shader que dependen de un global uniform.
	ShaderGlobals.asegurar_outline_global(true)

	if not ResourceLoader.exists(RUTA_SHADER_OUTLINE):
		push_warning("[NIVEL01] No se encontró TOON_LINEANEGRA.gdshader para refresco.")
		return

	var shader_outline := ResourceLoader.load(
		RUTA_SHADER_OUTLINE, "Shader", ResourceLoader.CACHE_MODE_REPLACE
	)
	if shader_outline == null:
		push_warning("[NIVEL01] No se pudo recargar TOON_LINEANEGRA.gdshader en cache.")


func _mostrar_dialogo_inicio_protagonista():
	_set_juego_pausado_dialogo(true)
	await _mostrar_dialogo_escena(
		escena_dialogo_inicio_protagonista,
		velocidad_texto_novela,
		chars_por_habla_protagonista,
		intervalo_min_habla_protagonista,
		sfx_habla_dialogo,
		pitch_habla_protagonista,
		volumen_habla_protagonista_db
	)
	_set_juego_pausado_dialogo(false)


func _reproducir_habla_femenina():
	if not sfx_habla_dialogo or not _dialogo_audio_player:
		return
	_dialogo_audio_player.stream = sfx_habla_dialogo
	_dialogo_audio_player.volume_db = volumen_habla_protagonista_db
	_dialogo_audio_player.pitch_scale = pitch_habla_protagonista
	_dialogo_audio_player.play()


func _mostrar_dialogo_escena(
	escena: PackedScene,
	velocidad: float,
	chars_por_sonido: int,
	intervalo_min_sonido: float,
	audio_stream: AudioStream,
	pitch_scale: float,
	volumen_db: float
) -> bool:
	if not escena:
		push_warning("[NIVEL01] No se encontró la escena de diálogo.")
		return false

	var dialogo_escena := escena.instantiate() as DialogoComic
	if not dialogo_escena:
		push_warning("[NIVEL01] La escena de diálogo no usa DialogoComic.")
		return false

	dialogo_escena.velocidad_texto = velocidad
	dialogo_escena.chars_por_sonido = chars_por_sonido
	dialogo_escena.intervalo_min_sonido = intervalo_min_sonido
	if audio_stream != null:
		dialogo_escena.audio_stream = audio_stream
		dialogo_escena.audio_pitch_scale = pitch_scale
		dialogo_escena.audio_volume_db = volumen_db
	add_child(dialogo_escena)

	await dialogo_escena.continuado

	if is_instance_valid(dialogo_escena):
		dialogo_escena.queue_free()

	return true


func _process(delta):
	_actualizar_render_subviewport_fondo(delta)

	# OPT: Monitoreo de oleadas con timer en vez de cada frame
	_monitor_timer += delta
	if _monitor_timer < MONITOR_INTERVAL:
		return
	_monitor_timer = 0.0

	match estado_actual:
		NivelEstado.NIVEL_0:
			_monitorear_nivel_0()
		NivelEstado.NIVEL_1:
			_monitorear_nivel_1()


func _actualizar_render_subviewport_fondo(delta: float) -> void:
	if not limitar_fps_subviewport_fondo_3d:
		return

	_fondo_render_timer -= delta
	if _fondo_render_timer > 0.0:
		return

	var fps_objetivo: float = max(1.0, float(fps_subviewport_fondo_3d))
	_fondo_render_timer = 1.0 / fps_objetivo

	if subviewport_video_fondo:
		subviewport_video_fondo.render_target_update_mode = SubViewport.UPDATE_ONCE
	if subviewport_fondo_3d:
		subviewport_fondo_3d.render_target_update_mode = SubViewport.UPDATE_ONCE


# ═══════════════════════════════════════════════════════════════════════════════
# NIVEL 0 — PACIFISTA
# ═══════════════════════════════════════════════════════════════════════════════


func _iniciar_nivel_0():
	estado_actual = NivelEstado.NIVEL_0

	# UI mínimo (solo corazones)
	await get_tree().process_frame
	if game_ui and game_ui.has_method("set_modo_minimo"):
		game_ui.set_modo_minimo(true)

	# Arqueras aliadas visibles pero sin disparar (solo pose IDLE)
	_set_aliadas_modo_pacifico()

	# Spawnear 3 enemigos pacíficos tras aceptar: 1 Imp con estandarte + 2 GoblinGirl.
	var escenas: Array[PackedScene] = [
		escena_imp_estandarte,
		wave_spawner.escena_goblin_girl,
		wave_spawner.escena_goblin_girl,
	]
	enemigos_pacificos = wave_spawner.spawn_pacificos(
		escenas, velocidad_pacificos, offset_entre_pacificos
	)

	# Asignar límite de parada escalonado: Imp en -5.0, arqueras en -4.8 y -4.6.
	for i in range(enemigos_pacificos.size()):
		var enemigo = enemigos_pacificos[i]
		if is_instance_valid(enemigo):
			enemigo.limite_pacifico_x = limite_fin_mapa_x + (i * retroceso_parada_arqueras)

	# Conectar señal de daño pacífico
	for enemigo in enemigos_pacificos:
		if is_instance_valid(enemigo) and enemigo.has_signal("pacifico_danado"):
			enemigo.pacifico_danado.connect(_on_pacifico_danado, CONNECT_ONE_SHOT)

	# Guardar referencia al imp del estandarte
	imp_estandarte = enemigos_pacificos[0]


func _monitorear_nivel_0():
	# Limpiar enemigos inválidos
	# Opt: Iteración inversa in-place en lugar de Array.filter() para evitar allocations de memoria/GC en _process
	for i in range(enemigos_pacificos.size() - 1, -1, -1):
		if not is_instance_valid(enemigos_pacificos[i]):
			enemigos_pacificos.remove_at(i)

	if enemigos_pacificos.is_empty():
		return

	# Verificar si todos se detuvieron en el borde
	var todos_detenidos := true
	for enemigo in enemigos_pacificos:
		if not enemigo.pacifico_detenido:
			todos_detenidos = false
			break

	if todos_detenidos:
		_victoria_pacifista()


# ═══════════════════════════════════════════════════════════════════════════════
# TRANSICIÓN: PACIFISTA → COMBATE
# ═══════════════════════════════════════════════════════════════════════════════


func _on_pacifico_danado():
	if estado_actual != NivelEstado.NIVEL_0:
		return
	estado_actual = NivelEstado.TRANSICION

	# Desintegrar estandarte del imp si aún existe (cualquier impacto en pacíficos lo destruye)
	if (
		is_instance_valid(imp_estandarte)
		and imp_estandarte.has_method("_desaparecer_estandarte_con_particulas")
	):
		imp_estandarte._desaparecer_estandarte_con_particulas()

	# Convertir pacíficos supervivientes en hostiles
	var supervivientes := 0
	for enemigo in enemigos_pacificos:
		if (
			is_instance_valid(enemigo)
			and enemigo.current_state != EnemyBase.State.DYING
			and enemigo.current_state != EnemyBase.State.DEAD
		):
			enemigo.modo_pacifico = false
			# Forzar que se detengan y empiecen a atacar
			enemigo.target_walk_distance = enemigo.walked_distance
			supervivientes += 1

	# Música de batalla
	AudioManager.play_music(2)  # BGM_battle.mp3

	# Restaurar UI completo
	if game_ui and game_ui.has_method("set_modo_minimo"):
		game_ui.set_modo_minimo(false)

	# Activar arqueras aliadas
	_set_aliadas_activas(true)

	# Mostrar cartel Level 01
	await _mostrar_cartel_level_01()

	# Iniciar Nivel 1: oleada de 13 enemigos (los supervivientes cuentan)
	_iniciar_nivel_1(supervivientes)


# ═══════════════════════════════════════════════════════════════════════════════
# NIVEL 1 — COMBATE (13 enemigos: Imp + GoblinGirl)
# ═══════════════════════════════════════════════════════════════════════════════


func _iniciar_nivel_1(supervivientes_pacificos: int = 0):
	# Salto de oleada por debug: se aplica recién aquí, tras el diálogo inicial
	# y el evento del goblin embajador. Los pacíficos (imp embajador + 2
	# arqueras) quedan EXCLUIDOS de la limpieza para que no desaparezcan al
	# convertirse en hostiles.
	if oleada_debug_pendiente > 0:
		var oleada_destino: int = oleada_debug_pendiente
		oleada_debug_pendiente = 0
		_iniciar_oleada_debug(oleada_destino, enemigos_pacificos)
		return

	oleada_combate_actual = 1
	_aplicar_perfil_render_combate()
	# Los 3 pacíficos convertidos ya están en active_goblins y cuentan dentro de total_enemigos_nivel1 (15 = 12 en cola + 3).
	# No se descuentan del total; WaveSpawner los cuenta como ya spawneados (goblins_spawned = 3) y genera 12 más.
	# Así el contador de la UI (total - muertos) incluye correctamente a los pacíficos.
	_configurar_oleada_combate(total_enemigos_nivel1, 1)


func _aplicar_perfil_render_combate() -> void:
	if video_fondo and pausar_video_fondo_en_combate:
		video_fondo.paused = true


func _configurar_oleada_combate(total_enemigos: int, numero_oleada: int = 1) -> void:
	estado_actual = NivelEstado.NIVEL_1

	# Si se avanza a la oleada 2, 3 o 4 (o cualquier otra oleada que no sea la inicial), remover instrucciones
	if numero_oleada > 1:
		get_tree().call_group("ui_instrucciones", "queue_free")
		get_tree().call_group("ui_vida_protagonista", "mostrar")

	oleada_combate_actual = numero_oleada
	wave_spawner.oleada_combate = numero_oleada
	wave_spawner.enemigos_por_oleada = total_enemigos
	wave_spawner.probabilidad_canonero = 0.0
	wave_spawner.probabilidad_igual = false
	wave_spawner.forzar_tipo_enemigo = -1  # Normal

	# Mostrar escudos de la oleada 2 (visibles ÚNICAMENTE en la oleada 2)
	var activa_oleada2 := (numero_oleada == 2)
	if is_instance_valid(escudo_enemigo2):
		_set_elemento_nivel3_activo(escudo_enemigo2, activa_oleada2)
	if is_instance_valid(escudo_enemigo3):
		_set_elemento_nivel3_activo(escudo_enemigo3, activa_oleada2)

	# Mostrar elementos del nivel 3 en oleadas 3 y 4 (en oleada 5 permanecen ocultos)
	var activa_nivel3 := (numero_oleada == 3 or numero_oleada == 4)
	if is_instance_valid(escena_rampa_nivel3):
		_set_elemento_nivel3_activo(escena_rampa_nivel3, activa_nivel3)
	if is_instance_valid(muro_plataforma):
		_set_elemento_nivel3_activo(muro_plataforma, activa_nivel3)
	if is_instance_valid(muro_plataforma2):
		_set_elemento_nivel3_activo(muro_plataforma2, activa_nivel3)
	if is_instance_valid(escudo_enemigo):
		_set_elemento_nivel3_activo(escudo_enemigo, activa_nivel3)

	# Oleada 5 en adelante: SIN defensas en terreno enemigo, sin excepciones.
	# Se OCULTAN (no se eliminan) para que las oleadas 3 y 4 puedan volver a
	# mostrarlas al saltar desde el menú de pausa; el escudo enemigo flotante
	# se previene porque la reconstrucción lo omite desde la oleada 5.
	if numero_oleada >= 5:
		if is_instance_valid(escudo_enemigo):
			_set_elemento_nivel3_activo(escudo_enemigo, false)
		if is_instance_valid(escena_rampa_nivel3):
			_set_elemento_nivel3_activo(escena_rampa_nivel3, false)
		if is_instance_valid(muro_plataforma):
			_set_elemento_nivel3_activo(muro_plataforma, false)
		if is_instance_valid(muro_plataforma2):
			_set_elemento_nivel3_activo(muro_plataforma2, false)

	if numero_oleada == 1:
		# Oleada 1: solo Imp + GoblinGirl
		wave_spawner.probabilidad_imp = 0.5
		wave_spawner.probabilidad_goblin_girl = 0.5
		# Desactivar goblin base (redirigir a goblin_girl)
		wave_spawner.escena_goblin = wave_spawner.escena_goblin_girl
		wave_spawner.max_shield_imps_to_spawn_this_wave = 0
		wave_spawner.max_imp_escudo_activos = 1
		wave_spawner.intervalo_check_escudo = 8.0
	elif numero_oleada == 2:
		# Oleada 2: Imp + GoblinGirl + Goblin (ballesta)
		wave_spawner.probabilidad_imp = 0.33
		wave_spawner.probabilidad_goblin_girl = 0.33
		# Restaurar goblin base (ballesta)
		wave_spawner.escena_goblin = preload("res://Entities/Enemigo_Goblin/Goblin.tscn")
		wave_spawner.max_shield_imps_to_spawn_this_wave = 0
		wave_spawner.max_imp_escudo_activos = 1
		wave_spawner.intervalo_check_escudo = 8.0
	elif numero_oleada == 3:
		# Oleada 3: 2 imp escudos activos a la vez, spawneados dinámicamente cada 6 seg
		wave_spawner.probabilidad_imp = 0.0
		wave_spawner.probabilidad_canonero = 0.0
		wave_spawner.probabilidad_goblin_girl = 0.5
		wave_spawner.escena_goblin = preload("res://Entities/Enemigo_Goblin/Goblin.tscn")
		wave_spawner.max_shield_imps_to_spawn_this_wave = 0
		wave_spawner.max_imp_escudo_activos = 2
		wave_spawner.intervalo_check_escudo = 6.0
	elif numero_oleada == 4:
		# Oleada 4: 10 Imp + 10 Goblin ballesta (reemplaza arquera) + 10 Gárgola + 5 Imp escudo 100%.
		wave_spawner.probabilidad_imp = 0.0
		wave_spawner.probabilidad_goblin_girl = 0.0
		wave_spawner.probabilidad_canonero = 0.0
		wave_spawner.escena_goblin = preload("res://Entities/Enemigo_Goblin/Goblin.tscn")  # ballesta
		# 5 imp escudo garantizados vía cola, sin spawn dinámico extra
		wave_spawner.max_shield_imps_to_spawn_this_wave = 0
		wave_spawner.max_imp_escudo_activos = 0
		wave_spawner.intervalo_check_escudo = 999.0
		# Activar assets visibles del nivel 3 / oleada 4
		_set_elemento_nivel3_activo(escena_rampa_nivel3, true)
		_set_elemento_nivel3_activo(muro_plataforma, true)
		_set_elemento_nivel3_activo(muro_plataforma2, true)
		if is_instance_valid(escudo_enemigo):
			_set_elemento_nivel3_activo(escudo_enemigo, true)
		# Spawnear Medikit en la puerta de la torre al inicio de la oleada 4
		_spawn_medikit_puerta_torre()
	elif numero_oleada == 5:
		# Oleada 5: 40 enemigos (11 Lonko, 4 Imp Escudo, 7 Gárgolas, 9 GoblinGirl, 9 Goblin)
		wave_spawner.probabilidad_imp = 0.0
		wave_spawner.probabilidad_goblin_girl = 0.0
		wave_spawner.probabilidad_canonero = 0.0
		wave_spawner.escena_goblin = preload("res://Entities/Enemigo_Goblin/Goblin.tscn")
		wave_spawner.max_shield_imps_to_spawn_this_wave = 0
		wave_spawner.max_imp_escudo_activos = 2
		wave_spawner.intervalo_check_escudo = 999.0
		# EXCEPCIÓN: Lonko siempre aparecen cuando se indica oleada 5 (bypass de filtros)
		if wave_spawner.has_method("solicitar_excepcion_lonko"):
			wave_spawner.solicitar_excepcion_lonko(11)
		# En la Oleada 5 las defensas enemigas permanecen OCULTAS
		_set_elemento_nivel3_activo(escena_rampa_nivel3, false)
		_set_elemento_nivel3_activo(muro_plataforma, false)
		_set_elemento_nivel3_activo(muro_plataforma2, false)
		if is_instance_valid(escudo_enemigo):
			_set_elemento_nivel3_activo(escudo_enemigo, false)
		if is_instance_valid(escudo_enemigo2):
			_set_elemento_nivel3_activo(escudo_enemigo2, false)
		if is_instance_valid(escudo_enemigo3):
			_set_elemento_nivel3_activo(escudo_enemigo3, false)

		# Spawnear icono de mensajera: el jugador lo activa al pasar sobre él
		_spawn_icono_mensajera_oleada_5()

	# Música según la oleada: Oleada 5 usa "Noche Aplastante" (índice 5), anteriores usan música de batalla (índice 2)
	if numero_oleada == 5:
		AudioManager.play_music(5)
	else:
		AudioManager.play_music(2)

	# Conectar señal de oleada completada
	if not wave_spawner.oleada_completada.is_connected(_on_nivel1_completado):
		wave_spawner.oleada_completada.connect(_on_nivel1_completado)
	# Conectado DESPUÉS del handler de reconstrucción de GameUI (hijo listo antes):
	# garantiza que en oleada 5+ se ELIMINEN los escudos enemigos aunque la
	# reconstrucción los haya re-instanciado un instante antes.
	if not wave_spawner.oleada_iniciada.is_connected(_on_oleada_iniciada_eliminar_defensas):
		wave_spawner.oleada_iniciada.connect(_on_oleada_iniciada_eliminar_defensas)

	# Iniciar el spawning (los enemigos pacíficos supervivientes ya cuentan)
	wave_spawner.current_wave = 0
	wave_spawner.goblins_spawned_in_wave = wave_spawner.active_goblins.size()
	wave_spawner.is_wave_active = false
	wave_spawner.wave_cooldown = 1.0


func _monitorear_nivel_1():
	if not is_instance_valid(wave_spawner):
		return

	# Limpiar referencias inválidas o enemigos muertos/muriendo
	for i in range(wave_spawner.active_goblins.size() - 1, -1, -1):
		var g = wave_spawner.active_goblins[i]
		if not is_instance_valid(g) or not g.is_inside_tree():
			wave_spawner.active_goblins.remove_at(i)
			continue
		if "current_state" in g:
			if g is EnemyBase and (g.current_state == EnemyBase.State.DYING or g.current_state == EnemyBase.State.DEAD):
				wave_spawner.active_goblins.remove_at(i)
			elif g is ImpShieldGirl and (g.current_state == ImpShieldGirl.State.DYING or g.current_state == ImpShieldGirl.State.DEAD):
				wave_spawner.active_goblins.remove_at(i)

	var cola_agotada: bool = wave_spawner.cola_spawn.is_empty()
	var sin_enemigos: bool = wave_spawner.active_goblins.is_empty()
	var todos_spawneados: bool = (wave_spawner.goblins_spawned_in_wave >= wave_spawner.enemigos_por_oleada)
	var muertes_completadas: bool = (wave_spawner.enemigos_por_oleada > 0 and wave_spawner.enemigos_muertos_en_oleada >= wave_spawner.enemigos_por_oleada)

	if wave_spawner.is_wave_active and cola_agotada and sin_enemigos and (todos_spawneados or muertes_completadas):
		wave_spawner.is_wave_active = false
		wave_spawner.detener_spawning()
		_on_nivel1_completado(wave_spawner.oleada_combate)


## Garantiza que los escudos enemigos solo estén visibles en sus oleadas respectivas
## y no se regeneren en otras a menos que se indique explícitamente.
## Se ejecuta tras la reconstrucción de GameUI, así que corrige cualquier regeneración indebida.
func _on_oleada_iniciada_eliminar_defensas(_num_oleada: int) -> void:
	if wave_spawner == null or not is_instance_valid(wave_spawner):
		return
	var num: int = wave_spawner.oleada_combate
	# Oleada 5+: eliminar definitivamente todos los escudos enemigos (no hay defensas en terreno enemigo)
	if num >= 5:
		for nodo in [escudo_enemigo, escudo_enemigo2, escudo_enemigo3]:
			if is_instance_valid(nodo):
				nodo.queue_free()
		# También limpiar cualquier escudo enemigo huérfano que GameUI haya podido dejar (excluir pilares)
		for esc in get_tree().get_nodes_in_group("escudos"):
			if is_instance_valid(esc) and esc.get("es_escudo_enemigo") == true and esc.get("es_pilar_enemigo") != true:
				esc.queue_free()
		return
	# Oleadas 1-4: ocultar/actuar solo sobre los no pertenecientes (GameUI ya filtró la reconstrucción,
	# pero este es el respaldo por si queda alguno visible tras debug o regeneración manual)
	# Excluir pilares de Lonko
	for esc in get_tree().get_nodes_in_group("escudos"):
		if not is_instance_valid(esc) or esc.get("es_escudo_enemigo") != true or esc.get("es_pilar_enemigo") == true:
			continue
		var permitido := false
		if esc.name == "Escudo_enemigo":
			permitido = (num == 3 or num == 4)
		elif esc.name == "NIVEL_2_Escudo_enemigo2" or esc.name == "NIVEL_2_Escudo_enemigo3":
			permitido = (num == 2)
		if not permitido:
			# En oleadas 1-4 no se elimina, solo se oculta para poder volver a mostrarse al regresar a su oleada
			_set_elemento_nivel3_activo(esc, false)


func _on_nivel1_completado(_numero_oleada: int):
	if estado_actual != NivelEstado.NIVEL_1:
		return

	if is_instance_valid(wave_spawner):
		wave_spawner.detener_spawning()

	var oleada_actual: int = wave_spawner.oleada_combate if is_instance_valid(wave_spawner) and wave_spawner.oleada_combate > 0 else oleada_combate_actual

	if oleada_actual in [1, 2, 3, 4]:
		if transicion_carteles_en_progreso:
			return
		transicion_carteles_en_progreso = true
		_mostrar_inter_nivel_continuar()
		return

	estado_actual = NivelEstado.VICTORIA_NIVEL1
	_log_debug("[NIVEL01] ¡Oleada 5 completada! Mostrando victoria con botón continuar...")
	_mostrar_victoria_con_continuar(
		(
			tr("NIVEL_1_COMPLETADO")
			if TranslationServer.get_locale() != ""
			else "¡Oleadas completadas!"
		)
	)


# ═══════════════════════════════════════════════════════════════════════════════
# CARTELES DE TRANSICIÓN (SIN FONDO NEGRO — con contorno y animación)
# ═══════════════════════════════════════════════════════════════════════════════


func _crear_label_settings_contorno(
	tamano_contorno: int = 8, color_contorno: Color = Color(0, 0, 0, 1)
) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.outline_size = tamano_contorno
	ls.outline_color = color_contorno
	ls.font_size = 64
	return ls


func _crear_label_transicion(texto: String, color_texto: Color) -> Label:
	var label := Label.new()
	label.text = texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.label_settings = _crear_label_settings_contorno(10, Color(0, 0, 0, 1))
	label.add_theme_color_override("font_color", color_texto)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return label


func _mostrar_cartel_nivel1_completado() -> void:
	_limpiar_carteles_transicion()
	var overlay := CanvasLayer.new()
	overlay.layer = 205
	overlay.name = "CartelNivel1Completado"
	add_child(overlay)

	var label := _crear_label_transicion(
		tr("NIVEL_1_COMPLETADO") if TranslationServer.get_locale() != "" else "NIVEL 1\nCOMPLETADO",
		Color(0.2, 1.0, 0.35)  # Verde brillante
	)
	overlay.add_child(label)
	label.modulate = Color(1, 1, 1, 1)
	label.scale = Vector2.ONE
	await get_tree().create_timer(1.5).timeout

	if is_instance_valid(overlay):
		overlay.queue_free()
	await get_tree().process_frame


func _mostrar_cartel_level_01() -> void:
	_limpiar_carteles_transicion()
	var overlay := CanvasLayer.new()
	overlay.layer = 205
	overlay.name = "CartelNivel1"
	add_child(overlay)

	var texto = tr("CARTEL_LEVEL_01")
	if texto == "CARTEL_LEVEL_01":
		texto = "Level 01"

	var label := _crear_label_transicion(texto, Color(1.0, 0.85, 0.2))
	overlay.add_child(label)
	label.modulate = Color(1, 1, 1, 1)
	label.scale = Vector2.ONE
	await get_tree().create_timer(1.2).timeout

	if is_instance_valid(overlay):
		overlay.queue_free()


func _mostrar_inter_nivel_continuar():
	var msg = ""
	if oleada_combate_actual == 1:
		msg = tr("NIVEL_1_COMPLETADO") if TranslationServer.get_locale() != "" else "¡Oleada 1 completada!"
	elif oleada_combate_actual == 2:
		msg = "¡Oleada 2 completada!"
	elif oleada_combate_actual == 3:
		msg = "¡Oleada 3 completada!"
	else:
		msg = "¡Oleada 4 completada!"

	if game_ui:
		game_ui.mostrar_pantalla_victoria(msg, func():
			# Revivir aliadas al pasar de nivel
			for ally in AllyArcher.active_allies_cache:
				if ally is AllyArcher and (ally.current_state == AllyArcher.State.DEAD or ally.current_state == AllyArcher.State.DYING):
					ally.revivir()
			
			if oleada_combate_actual == 1:
				_mostrar_cartel_nivel_2()
				oleada_combate_actual = 2
				_configurar_oleada_combate(total_enemigos_oleada_2, 2)
			elif oleada_combate_actual == 2:
				_mostrar_cartel_nivel_3()
				oleada_combate_actual = 3
				_configurar_oleada_combate(total_enemigos_oleada_3, 3)
			elif oleada_combate_actual == 3:
				_mostrar_cartel_nivel_4()
				oleada_combate_actual = 4
				_configurar_oleada_combate(total_enemigos_oleada_4, 4)
			elif oleada_combate_actual == 4:
				_mostrar_cartel_nivel_5()
				oleada_combate_actual = 5
				_configurar_oleada_combate(total_enemigos_oleada_5, 5)
			transicion_carteles_en_progreso = false
		)
	else:
		for ally in AllyArcher.active_allies_cache:
			if ally is AllyArcher and (ally.current_state == AllyArcher.State.DEAD or ally.current_state == AllyArcher.State.DYING):
				ally.revivir()
		if oleada_combate_actual == 1:
			_mostrar_cartel_nivel_2()
			oleada_combate_actual = 2
			_configurar_oleada_combate(total_enemigos_oleada_2, 2)
		elif oleada_combate_actual == 2:
			_mostrar_cartel_nivel_3()
			oleada_combate_actual = 3
			_configurar_oleada_combate(total_enemigos_oleada_3, 3)
		elif oleada_combate_actual == 3:
			_mostrar_cartel_nivel_4()
			oleada_combate_actual = 4
			_configurar_oleada_combate(total_enemigos_oleada_4, 4)
		elif oleada_combate_actual == 4:
			_mostrar_cartel_nivel_5()
			oleada_combate_actual = 5
			_configurar_oleada_combate(total_enemigos_oleada_5, 5)
		transicion_carteles_en_progreso = false


## Precalienta en segundo plano los enemigos NUEVOS de la oleada que viene,
## mientras el cartel de transición está en pantalla (evita tirones y caídas
## de FPS al aparecer por primera vez: compila shaders y carga dependencias).
func _precargar_elementos_oleada(numero_oleada_siguiente: int) -> void:
	match numero_oleada_siguiente:
		3:
			_precalentar_instancia_breve(wave_spawner.escena_imp_escudo)
		4:
			_precalentar_instancia_breve(wave_spawner.escena_gargola)
			# El primer ataque de la gárgola compila el pipeline de su proyectil
			_precalentar_instancia_breve(ESCENA_PROYECTIL_GARGOLA)
			_precalentar_instancia_breve(wave_spawner.escena_imp_escudo)
		5:
			_precalentar_instancia_breve(wave_spawner.escena_lonko)
			_precalentar_instancia_breve(wave_spawner.escena_imp_escudo)
		_:
			pass


## Warm-up de shaders durante el diálogo de intro: instancia brevemente los
## enemigos y proyectiles del nivel.
func _precalentar_combate_con_retraso(delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(
		func():
			if not is_inside_tree():
				return
			for escena in [
				wave_spawner.escena_imp,
				wave_spawner.escena_goblin_girl,
				ESCENA_GOBLIN_BALLESTA,
				wave_spawner.escena_imp_escudo,
				ESCENA_TRIDENTE_IMP,
				ESCENA_FLECHA_GOBLIN,
			]:
				_precalentar_instancia_breve(escena)
	)


## Instancia una escena brevemente (0.35 s) dentro de un SubViewport INVISIBLE:
## se dibuja (compila sus shaders y sube texturas) pero su salida jamás se
## muestra en pantalla. Proceso congelado: sin gravedad ni animación.
func _precalentar_instancia_breve(escena: PackedScene) -> void:
	if not escena:
		return
	if _viewport_precarga == null or not is_instance_valid(_viewport_precarga):
		_crear_viewport_precarga()

	var instancia = escena.instantiate()
	_viewport_precarga.add_child(instancia)
	instancia.position = Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.2), randf_range(-0.3, 0.3))
	instancia.scale = Vector3.ONE * ESCALA_PRECALENTA
	instancia.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().create_timer(0.35).timeout.connect(
		func():
			if is_instance_valid(instancia):
				instancia.queue_free()
	)


## Crea el SubViewport de precarga: cámara y luz propias, mundo aislado
## (own_world_3d) y sin contenedor que muestre su textura.
func _crear_viewport_precarga() -> void:
	_viewport_precarga = SubViewport.new()
	_viewport_precarga.name = "ViewportPrecargaShaders"
	_viewport_precarga.size = Vector2i(256, 256)
	_viewport_precarga.transparent_bg = true
	_viewport_precarga.own_world_3d = true
	_viewport_precarga.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport_precarga)

	var camara := Camera3D.new()
	camara.position = Vector3(0, 0, 2.5)
	_viewport_precarga.add_child(camara)
	camara.make_current()

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	_viewport_precarga.add_child(luz)


func _mostrar_cartel_nivel_2() -> void:
	_limpiar_carteles_transicion()
	var overlay := CanvasLayer.new()
	overlay.layer = 205
	overlay.name = "CartelNivel2"
	add_child(overlay)

	var texto = tr("CARTEL_LEVEL_02")
	if texto == "CARTEL_LEVEL_02":
		texto = "Level 02"

	var label := _crear_label_transicion(texto, Color(1.0, 0.85, 0.2))  # Dorado
	overlay.add_child(label)
	label.modulate = Color(1, 1, 1, 1)
	label.scale = Vector2.ONE
	await get_tree().create_timer(1.2).timeout

	if is_instance_valid(overlay):
		overlay.queue_free()


func _mostrar_cartel_nivel_3() -> void:
	_limpiar_carteles_transicion()
	var overlay := CanvasLayer.new()
	overlay.layer = 205
	overlay.name = "CartelNivel3"
	add_child(overlay)

	var texto = "Level 03"

	var label := _crear_label_transicion(texto, Color(1.0, 0.85, 0.2))  # Dorado
	overlay.add_child(label)
	label.modulate = Color(1, 1, 1, 1)
	label.scale = Vector2.ONE
	await get_tree().create_timer(1.2).timeout

	if is_instance_valid(overlay):
		overlay.queue_free()


func _mostrar_cartel_nivel_4() -> void:
	_limpiar_carteles_transicion()
	var overlay := CanvasLayer.new()
	overlay.layer = 205
	overlay.name = "CartelNivel4"
	add_child(overlay)

	var texto = "Level 04"

	var label := _crear_label_transicion(texto, Color(1.0, 0.85, 0.2))  # Dorado
	overlay.add_child(label)
	label.modulate = Color(1, 1, 1, 1)
	label.scale = Vector2.ONE
	await get_tree().create_timer(1.2).timeout

	if is_instance_valid(overlay):
		overlay.queue_free()


func _mostrar_cartel_nivel_5() -> void:
	_limpiar_carteles_transicion()
	var overlay := CanvasLayer.new()
	overlay.layer = 205
	overlay.name = "CartelNivel5"
	add_child(overlay)

	var texto = "Level 05"

	var label := _crear_label_transicion(texto, Color(1.0, 0.85, 0.2))  # Dorado
	overlay.add_child(label)
	label.modulate = Color(1, 1, 1, 1)
	label.scale = Vector2.ONE
	await get_tree().create_timer(1.2).timeout

	if is_instance_valid(overlay):
		overlay.queue_free()


func _limpiar_carteles_transicion() -> void:
	var cartel_1 = get_node_or_null("CartelNivel1Completado")
	if is_instance_valid(cartel_1):
		cartel_1.queue_free()
	var cartel_2 = get_node_or_null("CartelNivel2")
	if is_instance_valid(cartel_2):
		cartel_2.queue_free()
	var cartel_3 = get_node_or_null("CartelNivel3")
	if is_instance_valid(cartel_3):
		cartel_3.queue_free()
	var cartel_4 = get_node_or_null("CartelNivel4")
	if is_instance_valid(cartel_4):
		cartel_4.queue_free()
	var cartel_5 = get_node_or_null("CartelNivel5")
	if is_instance_valid(cartel_5):
		cartel_5.queue_free()


func debug_mostrar_carteles_transicion() -> void:
	if transicion_carteles_en_progreso:
		return
	transicion_carteles_en_progreso = true
	await _mostrar_cartel_nivel1_completado()
	await _mostrar_cartel_nivel_2()
	await _mostrar_cartel_nivel_3()
	await _mostrar_cartel_nivel_4()
	await _mostrar_cartel_nivel_5()
	transicion_carteles_en_progreso = false


func debug_ir_a_oleada_1() -> void:
	_iniciar_oleada_debug(1)


func debug_ir_a_oleada_2() -> void:
	_iniciar_oleada_debug(2)


func debug_ir_a_oleada_3() -> void:
	_iniciar_oleada_debug(3)


func debug_ir_a_oleada_4() -> void:
	_iniciar_oleada_debug(4)


func debug_ir_a_oleada_5() -> void:
	_iniciar_oleada_debug(5)


func _iniciar_oleada_debug(numero_oleada: int, excluir_de_limpieza: Array = []) -> void:
	if not is_instance_valid(wave_spawner):
		return

	# Si se usan botones debug para saltar a cualquier oleada, remover instrucciones y revelar vida
	get_tree().call_group("ui_instrucciones", "queue_free")
	get_tree().call_group("ui_vida_protagonista", "mostrar")

	# Los excluidos (embajadores convertidos en hostiles) sobreviven a la limpieza
	_limpiar_nodos_combate_spawneados(excluir_de_limpieza)

	enemigos_pacificos.clear()
	imp_estandarte = null
	wave_spawner.active_goblins.clear()
	wave_spawner.shield_imps_activos.clear()

	if game_ui and game_ui.has_method("set_modo_minimo"):
		game_ui.set_modo_minimo(false)

	_set_aliadas_activas(true)
	if numero_oleada == 5:
		AudioManager.play_music(5)
	else:
		AudioManager.play_music(2)

	if numero_oleada == 5:
		oleada_combate_actual = 5
		_configurar_oleada_combate(total_enemigos_oleada_5, 5)
	elif numero_oleada == 4:
		oleada_combate_actual = 4
		_configurar_oleada_combate(total_enemigos_oleada_4, 4)
	elif numero_oleada == 3:
		oleada_combate_actual = 3
		_configurar_oleada_combate(total_enemigos_oleada_3, 3)
	elif numero_oleada == 2:
		oleada_combate_actual = 2
		_configurar_oleada_combate(total_enemigos_oleada_2, 2)
	else:
		oleada_combate_actual = 1
		_configurar_oleada_combate(total_enemigos_nivel1, 1)

	# Reconstrucción inmediata de escudos para el selector de pausa: garantiza que
	# los escudos del nivel seleccionado aparezcan al instante aunque hubieran sido destruidos/queue_free.
	if game_ui and game_ui.has_method("_reconstruir_todos_escudos"):
		game_ui._reconstruir_todos_escudos(numero_oleada >= 5, numero_oleada)
		if game_ui.has_method("_sincronizar_visibilidad_escudos_por_oleada"):
			game_ui._sincronizar_visibilidad_escudos_por_oleada(numero_oleada)
	# Re-aplicar visibilidad local (el getter puede ahora resolver nodos recién reconstruidos)
	var _activa_oleada2 := (numero_oleada == 2)
	var _activa_nivel3 := (numero_oleada == 3 or numero_oleada == 4)
	_set_elemento_nivel3_activo(get_node_or_null("NIVEL_2_Escudo_enemigo2"), _activa_oleada2)
	_set_elemento_nivel3_activo(get_node_or_null("NIVEL_2_Escudo_enemigo3"), _activa_oleada2)
	_set_elemento_nivel3_activo(get_node_or_null("Escudo_enemigo"), _activa_nivel3)
	if numero_oleada >= 5:
		_set_elemento_nivel3_activo(get_node_or_null("Escudo_enemigo"), false)
		_set_elemento_nivel3_activo(get_node_or_null("NIVEL_2_Escudo_enemigo2"), false)
		_set_elemento_nivel3_activo(get_node_or_null("NIVEL_2_Escudo_enemigo3"), false)


# ═══════════════════════════════════════════════════════════════════════════════
# VICTORIA PACIFISTA
# ═══════════════════════════════════════════════════════════════════════════════


func _victoria_pacifista():
	if estado_actual != NivelEstado.NIVEL_0:
		return
	estado_actual = NivelEstado.VICTORIA_PACIFISTA

	wave_spawner.detener_spawning()

	# Ocultar la UI del tutorial para que el diálogo pacifista se aprecie sin obstáculos
	get_tree().call_group("ui_instrucciones", "queue_free")

	# Reproducir música de victoria (sin loop)
	AudioManager.play_music(4, false)  # VICTORY.mp3

	# Mostrar diálogo tipo novela visual tras un delay
	await get_tree().create_timer(delay_dialogo_pacifico).timeout
	_mostrar_dialogo_pacifista()


func _mostrar_dialogo_pacifista():
	_set_juego_pausado_dialogo(true)
	await _mostrar_dialogo_escena(
		escena_dialogo_emisario_parte1, velocidad_texto_novela, 4, 0.18, null, 1.0, -18.0
	)

	_mostrar_resultado_pacifista_pantalla_negra()


func _mostrar_resultado_pacifista_pantalla_negra():
	if not escena_resultado_pacifista:
		push_warning("[NIVEL01] No se encontró la escena del resultado pacifista.")
		_set_juego_pausado_dialogo(false)
		return

	var resultado_escena := escena_resultado_pacifista.instantiate() as ResultadoPacifista
	if not resultado_escena:
		push_warning("[NIVEL01] La escena del resultado pacifista no usa ResultadoPacifista.")
		_set_juego_pausado_dialogo(false)
		return

	add_child(resultado_escena)
	var opcion: String = await resultado_escena.opcion_elegida

	if is_instance_valid(resultado_escena):
		resultado_escena.queue_free()

	_set_juego_pausado_dialogo(false)

	if opcion == "reiniciar":
		_reiniciar_nivel01_limpio()


func _reiniciar_nivel01_limpio():
	_limpiar_nodos_combate_spawneados()

	# Esperar a que queue_free se aplique para evitar residuos entre recargas.
	await get_tree().process_frame
	await get_tree().process_frame

	get_tree().change_scene_to_file(scene_file_path)


# ═══════════════════════════════════════════════════════════════════════════════
# OLEADAS LIBRES (post Nivel 1)
# ═══════════════════════════════════════════════════════════════════════════════


func _mostrar_victoria_con_continuar(mensaje: String):
	if game_ui:
		game_ui.mostrar_pantalla_victoria(mensaje, func():
			_iniciar_oleadas_libres()
		)
	else:
		_iniciar_oleadas_libres()


func _iniciar_oleadas_libres():
	estado_actual = NivelEstado.OLEADAS_LIBRES
	_log_debug("[NIVEL01] Oleadas libres iniciadas — 10 Gárgolas en bucle")

	# Forzar tipo de enemigo 5 (Gárgola) en bucle de 10 gárgolas
	wave_spawner.forzar_tipo_enemigo = 5
	wave_spawner.probabilidad_igual = false
	wave_spawner.enemigos_por_oleada = 10
	wave_spawner.intervalo_aparicion = 4.0
	wave_spawner.spawn_infinito = true

	# Reiniciar wave y arrancar
	wave_spawner.oleada_combate = 0
	wave_spawner.current_wave = 0
	wave_spawner.goblins_spawned_in_wave = 0
	wave_spawner.enemigos_muertos_en_oleada = 0
	wave_spawner.is_wave_active = false
	wave_spawner.wave_cooldown = 1.0


# ═══════════════════════════════════════════════════════════════════════════════
# UTILIDADES
# ═══════════════════════════════════════════════════════════════════════════════


func _set_aliadas_activas(activas: bool):
	for ally in AllyArcher.active_allies_cache:
		if ally is AllyArcher:
			ally.visible = activas
			ally.set_process(activas)
			ally.set_physics_process(activas)
			var hitbox = ally.get("hitbox_body")
			if hitbox and is_instance_valid(hitbox):
				hitbox.collision_layer = 2 if activas else 0


## Arqueras visibles en pose IDLE pero sin disparar
func _set_aliadas_modo_pacifico():
	for ally in AllyArcher.active_allies_cache:
		if ally is AllyArcher:
			ally.visible = true
			ally.set_process(false)  # No disparan
			ally.set_physics_process(false)
			var hitbox = ally.get("hitbox_body")
			if hitbox and is_instance_valid(hitbox):
				hitbox.collision_layer = 0  # Sin colisión


func _toggle_aliadas_visibles() -> void:
	_aliadas_activas = not _aliadas_activas
	_set_aliadas_activas(_aliadas_activas)


func _revivir_aliadas_debug() -> void:
	for ally in AllyArcher.active_allies_cache:
		if not is_instance_valid(ally) or not (ally is AllyArcher):
			continue
		if ally.current_state == AllyArcher.State.DEAD or ally.current_state == AllyArcher.State.DYING:
			ally.revivir()
		else:
			ally.health = ally.vida_maxima
		if _aliadas_activas:
			ally.visible = true


func _crear_panel_controles_spawn() -> void:
	if not game_ui:
		return
	var btn_toggle := Button.new()
	btn_toggle.name = "BtnToggleDebugPanel"
	btn_toggle.text = "🛠️ DEBUG"
	btn_toggle.custom_minimum_size = Vector2(90, 30)
	btn_toggle.anchor_left = 1.0
	btn_toggle.anchor_top = 0.0
	btn_toggle.anchor_right = 1.0
	btn_toggle.offset_left = -98
	btn_toggle.offset_top = 8
	btn_toggle.offset_right = -8
	btn_toggle.offset_bottom = 38
	var toggle_style := StyleBoxFlat.new()
	toggle_style.bg_color = Color(0.18, 0.20, 0.28, 0.95)
	toggle_style.set_corner_radius_all(6)
	toggle_style.set_border_width_all(2)
	toggle_style.border_color = Color(0.45, 0.5, 0.7, 0.9)
	btn_toggle.add_theme_stylebox_override("normal", toggle_style)
	game_ui.add_child(btn_toggle)
	var panel := PanelContainer.new()
	panel.name = "DebugSpawnPanel"
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.offset_left = -295
	panel.offset_top = 44
	panel.offset_right = -8
	panel.custom_minimum_size = Vector2(285, 0)
	panel.visible = true
	btn_toggle.pressed.connect(func():
		panel.visible = not panel.visible
		btn_toggle.text = "✖ OCULTAR" if panel.visible else "🛠️ DEBUG"
	)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.12, 0.96)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(10)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.35, 0.38, 0.55, 0.9)
	panel.add_theme_stylebox_override("panel", panel_style)
	var vbox_main := VBoxContainer.new()
	vbox_main.add_theme_constant_override("separation", 6)
	panel.add_child(vbox_main)
	var label_titulo := Label.new()
	label_titulo.text = "🛠️ CONTROL DE SPAWN & DEBUG"
	label_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox_main.add_child(label_titulo)
	vbox_main.add_child(HSeparator.new())
	var hbox_status := HBoxContainer.new()
	hbox_status.add_theme_constant_override("separation", 6)
	vbox_main.add_child(hbox_status)
	var btn_pausar := Button.new()
	btn_pausar.text = "⏸️ PAUSAR"
	btn_pausar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_pausar.pressed.connect(func():
		wave_spawner.detener_spawning()
		_actualizar_estado_spawner_label("PAUSADO")
	)
	hbox_status.add_child(btn_pausar)
	var btn_reanudar := Button.new()
	btn_reanudar.text = "▶️ INICIAR"
	btn_reanudar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reanudar.pressed.connect(func():
		wave_spawner.iniciar_spawning()
		wave_spawner.is_wave_active = true
		_actualizar_estado_spawner_label("ACTIVO")
	)
	hbox_status.add_child(btn_reanudar)
	var label_estado := Label.new()
	label_estado.name = "LabelEstadoSpawner"
	label_estado.text = "Estado: PAUSADO"
	label_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_estado.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	vbox_main.add_child(label_estado)
	vbox_main.add_child(HSeparator.new())
	wave_spawner.forzar_tipo_enemigo = 2
	wave_spawner.probabilidad_igual = false
	var label_tipo := Label.new()
	label_tipo.text = "Tipo a spawnear:\n😈 Imp Normal"
	label_tipo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label_tipo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox_main.add_child(label_tipo)
	var grid_tipos := GridContainer.new()
	grid_tipos.columns = 2
	grid_tipos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_tipos.add_theme_constant_override("h_separation", 6)
	grid_tipos.add_theme_constant_override("v_separation", 6)
	vbox_main.add_child(grid_tipos)
	var opciones = [
		{"nombre": "🎲 Todos (Azar)", "id": -1},
		{"nombre": "🏹 Gob Ballesta", "id": 0},
		{"nombre": "👧 Goblin Girl", "id": 1},
		{"nombre": "😈 Imp Normal", "id": 2},
		{"nombre": "💣 Cañonero", "id": 3},
		{"nombre": "🛡️ Imp Escudo", "id": 4},
		{"nombre": "🦅 Gárgola", "id": 5},
		{"nombre": "🏹 Lonko", "id": 6},
		{"nombre": "🌸 Arquera Rosa", "id": 7}
	]
	for opt in opciones:
		var btn := Button.new()
		btn.text = opt["nombre"]
		btn.custom_minimum_size = Vector2(125, 28)
		btn.add_theme_font_size_override("font_size", 11)
		btn.focus_mode = Control.FOCUS_NONE
		btn.set_meta("tipo_id", opt["id"])
		btn.set_meta("tipo_nombre", opt["nombre"])
		var init_style := StyleBoxFlat.new()
		if opt["id"] == 2:
			init_style.bg_color = Color(0.2, 0.5, 0.8, 1.0)
			init_style.set_border_width_all(2)
			init_style.border_color = Color(1.0, 1.0, 1.0, 0.9)
		else:
			init_style.bg_color = Color(0.18, 0.18, 0.22, 0.95)
		init_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", init_style)
		btn.pressed.connect(func():
			var tid: int = btn.get_meta("tipo_id")
			var tnombre: String = btn.get_meta("tipo_nombre")
			if wave_spawner:
				wave_spawner.cola_spawn.clear()
				wave_spawner.evento_cuerno_en_progreso = false
				if tid == -1:
					wave_spawner.forzar_tipo_enemigo = -1
					wave_spawner.probabilidad_igual = true
				else:
					wave_spawner.forzar_tipo_enemigo = tid
			label_tipo.text = "Tipo a spawnear:\n" + tnombre
			for b in grid_tipos.get_children():
				if b is Button:
					var b_id: int = b.get_meta("tipo_id")
					var b_style := StyleBoxFlat.new()
					if b_id == tid:
						b_style.bg_color = Color(0.2, 0.5, 0.8, 1.0)
						b_style.set_border_width_all(2)
						b_style.border_color = Color(1.0, 1.0, 1.0, 0.9)
					else:
						b_style.bg_color = Color(0.18, 0.18, 0.22, 0.95)
					b_style.set_corner_radius_all(4)
					b.add_theme_stylebox_override("normal", b_style)
		)
		grid_tipos.add_child(btn)
	var btn_spawn_uno := Button.new()
	btn_spawn_uno.text = "➕ SPAWNEAR UNO"
	btn_spawn_uno.custom_minimum_size = Vector2(0, 30)
	var style_spawn := StyleBoxFlat.new()
	style_spawn.bg_color = Color(0.2, 0.5, 0.2, 1.0)
	style_spawn.set_corner_radius_all(4)
	btn_spawn_uno.add_theme_stylebox_override("normal", style_spawn)
	btn_spawn_uno.pressed.connect(func():
		wave_spawner.forzar_spawn()
	)
	vbox_main.add_child(btn_spawn_uno)
	vbox_main.add_child(HSeparator.new())
	var label_ammo_sec := Label.new()
	label_ammo_sec.text = "🏹 MUNICIÓN EXPLOSIVA"
	label_ammo_sec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_ammo_sec.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	vbox_main.add_child(label_ammo_sec)
	var hbox_ammo := HBoxContainer.new()
	hbox_ammo.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_ammo.add_theme_constant_override("separation", 6)
	vbox_main.add_child(hbox_ammo)
	var label_ammo := Label.new()
	label_ammo.name = "LabelAmmoDebug"
	var p_cur = get_tree().get_first_node_in_group("player")
	var ammo_count: int = p_cur.flechas_explosivas if p_cur and "flechas_explosivas" in p_cur else 5
	label_ammo.text = "💥 Flechas: " + str(ammo_count)
	label_ammo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label_ammo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_ammo.add_child(label_ammo)
	var btn_ammo_minus := Button.new()
	btn_ammo_minus.text = "-1"
	btn_ammo_minus.custom_minimum_size = Vector2(30, 24)
	btn_ammo_minus.pressed.connect(func():
		var p = get_tree().get_first_node_in_group("player")
		if p and "flechas_explosivas" in p:
			p.flechas_explosivas = max(0, p.flechas_explosivas - 1)
			if p.has_signal("flechas_explosivas_changed"):
				p.flechas_explosivas_changed.emit(p.flechas_explosivas)
			for ally in AllyArcher.active_allies_cache:
				if is_instance_valid(ally) and ally is AllyArcher:
					ally.flechas_explosivas = p.flechas_explosivas
	)
	hbox_ammo.add_child(btn_ammo_minus)
	var btn_ammo_plus := Button.new()
	btn_ammo_plus.text = "+1"
	btn_ammo_plus.custom_minimum_size = Vector2(30, 24)
	btn_ammo_plus.pressed.connect(func():
		var p = get_tree().get_first_node_in_group("player")
		if p and "flechas_explosivas" in p:
			p.flechas_explosivas += 1
			if p.has_signal("flechas_explosivas_changed"):
				p.flechas_explosivas_changed.emit(p.flechas_explosivas)
			for ally in AllyArcher.active_allies_cache:
				if is_instance_valid(ally) and ally is AllyArcher:
					ally.flechas_explosivas = p.flechas_explosivas
	)
	hbox_ammo.add_child(btn_ammo_plus)
	var btn_ammo_plus5 := Button.new()
	btn_ammo_plus5.text = "+5"
	btn_ammo_plus5.custom_minimum_size = Vector2(32, 24)
	btn_ammo_plus5.pressed.connect(func():
		var p = get_tree().get_first_node_in_group("player")
		if p and "flechas_explosivas" in p:
			p.flechas_explosivas += 5
			if p.has_signal("flechas_explosivas_changed"):
				p.flechas_explosivas_changed.emit(p.flechas_explosivas)
			for ally in AllyArcher.active_allies_cache:
				if is_instance_valid(ally) and ally is AllyArcher:
					ally.flechas_explosivas = p.flechas_explosivas
	)
	hbox_ammo.add_child(btn_ammo_plus5)
	if p_cur and p_cur.has_signal("flechas_explosivas_changed"):
		p_cur.flechas_explosivas_changed.connect(func(cnt: int):
			if is_instance_valid(label_ammo):
				label_ammo.text = "💥 Flechas: " + str(cnt)
		)
	vbox_main.add_child(HSeparator.new())
	var label_acciones := Label.new()
	label_acciones.text = "⚡ ACCIONES & DEFENSAS"
	label_acciones.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_acciones.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox_main.add_child(label_acciones)
	var grid_items := GridContainer.new()
	grid_items.columns = 3
	grid_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_items.add_theme_constant_override("h_separation", 4)
	grid_items.add_theme_constant_override("v_separation", 4)
	vbox_main.add_child(grid_items)
	var btn_pocion := Button.new()
	btn_pocion.text = "🧪 Poción"
	btn_pocion.custom_minimum_size = Vector2(84, 26)
	btn_pocion.add_theme_font_size_override("font_size", 11)
	btn_pocion.pressed.connect(func(): if game_ui: game_ui._spawn_posion_debug())
	grid_items.add_child(btn_pocion)
	var btn_flecha_exp := Button.new()
	btn_flecha_exp.text = "💥 Flecha Exp"
	btn_flecha_exp.custom_minimum_size = Vector2(84, 26)
	btn_flecha_exp.add_theme_font_size_override("font_size", 11)
	btn_flecha_exp.pressed.connect(func(): if game_ui: game_ui._spawn_flecha_explosiva_debug())
	grid_items.add_child(btn_flecha_exp)
	var btn_flecha_mult := Button.new()
	btn_flecha_mult.text = "🏹 Flecha Mult"
	btn_flecha_mult.custom_minimum_size = Vector2(84, 26)
	btn_flecha_mult.add_theme_font_size_override("font_size", 11)
	btn_flecha_mult.pressed.connect(func(): if game_ui: game_ui._spawn_flecha_multiple_debug())
	grid_items.add_child(btn_flecha_mult)
	var btn_debug_exp := Button.new()
	var update_exp_btn := func():
		if ExplosionFlechaExplosiva.debug_collider_global:
			btn_debug_exp.text = "🎯 Col Exp: ON"
			btn_debug_exp.add_theme_color_override("font_color", Color(1.0, 0.4, 1.0))
		else:
			btn_debug_exp.text = "🎯 Col Exp: OFF"
			btn_debug_exp.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	update_exp_btn.call()
	btn_debug_exp.custom_minimum_size = Vector2(84, 26)
	btn_debug_exp.add_theme_font_size_override("font_size", 11)
	btn_debug_exp.pressed.connect(func():
		ExplosionFlechaExplosiva.debug_collider_global = not ExplosionFlechaExplosiva.debug_collider_global
		update_exp_btn.call()
	)
	grid_items.add_child(btn_debug_exp)
	var btn_cuerno := Button.new()
	btn_cuerno.text = "📯 Cuerno"
	btn_cuerno.custom_minimum_size = Vector2(84, 26)
	btn_cuerno.add_theme_font_size_override("font_size", 11)
	btn_cuerno.pressed.connect(func(): if wave_spawner and wave_spawner.has_method("_iniciar_evento_cuerno"): wave_spawner._iniciar_evento_cuerno())
	grid_items.add_child(btn_cuerno)
	var btn_destr_escudos := Button.new()
	btn_destr_escudos.text = "💥 -Escudos"
	btn_destr_escudos.custom_minimum_size = Vector2(84, 26)
	btn_destr_escudos.add_theme_font_size_override("font_size", 11)
	btn_destr_escudos.pressed.connect(func(): if game_ui: game_ui._destruir_todos_escudos())
	grid_items.add_child(btn_destr_escudos)
	var btn_reconst_escudos := Button.new()
	btn_reconst_escudos.text = "🛡️ +Escudos"
	btn_reconst_escudos.custom_minimum_size = Vector2(84, 26)
	btn_reconst_escudos.add_theme_font_size_override("font_size", 11)
	btn_reconst_escudos.pressed.connect(func(): if game_ui: game_ui._reconstruir_todos_escudos())
	grid_items.add_child(btn_reconst_escudos)
	var btn_god := Button.new()
	btn_god.text = "🛡️ God Mode"
	btn_god.custom_minimum_size = Vector2(84, 26)
	btn_god.add_theme_font_size_override("font_size", 11)
	btn_god.pressed.connect(func(): if game_ui: game_ui._toggle_god_mode())
	grid_items.add_child(btn_god)
	var btn_toggle_aliadas := Button.new()
	var update_aliadas_btn := func():
		if _aliadas_activas:
			btn_toggle_aliadas.text = "🏹 Aliadas: ON"
			btn_toggle_aliadas.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			btn_toggle_aliadas.text = "🏹 Aliadas: OFF"
			btn_toggle_aliadas.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	update_aliadas_btn.call()
	btn_toggle_aliadas.custom_minimum_size = Vector2(84, 26)
	btn_toggle_aliadas.add_theme_font_size_override("font_size", 11)
	btn_toggle_aliadas.pressed.connect(func():
		_toggle_aliadas_visibles()
		update_aliadas_btn.call()
	)
	grid_items.add_child(btn_toggle_aliadas)
	var btn_revivir_aliadas := Button.new()
	btn_revivir_aliadas.text = "❤️ Revivir"
	btn_revivir_aliadas.custom_minimum_size = Vector2(84, 26)
	btn_revivir_aliadas.add_theme_font_size_override("font_size", 11)
	btn_revivir_aliadas.pressed.connect(func():
		_revivir_aliadas_debug()
	)
	grid_items.add_child(btn_revivir_aliadas)
	var btn_cortinilla := Button.new()
	btn_cortinilla.text = "🎭 Cortinilla"
	btn_cortinilla.custom_minimum_size = Vector2(84, 26)
	btn_cortinilla.add_theme_font_size_override("font_size", 11)
	btn_cortinilla.pressed.connect(func():
		if game_ui and game_ui.has_method("mostrar_cortinilla_debug"):
			game_ui.mostrar_cortinilla_debug(3.0)
	)
	grid_items.add_child(btn_cortinilla)
	var btn_victoria := Button.new()
	btn_victoria.text = "🎉 Victoria"
	btn_victoria.custom_minimum_size = Vector2(84, 26)
	btn_victoria.add_theme_font_size_override("font_size", 11)
	btn_victoria.pressed.connect(func():
		if game_ui and game_ui.has_method("_probar_victoria_aliadas_debug"):
			game_ui._probar_victoria_aliadas_debug()
	)
	grid_items.add_child(btn_victoria)
	var btn_saltar_oleada := Button.new()
	btn_saltar_oleada.text = "⏩ +Oleada"
	btn_saltar_oleada.custom_minimum_size = Vector2(84, 26)
	btn_saltar_oleada.add_theme_font_size_override("font_size", 11)
	btn_saltar_oleada.pressed.connect(func():
		if game_ui and game_ui.has_method("_completar_oleada_actual_debug"):
			game_ui._completar_oleada_actual_debug()
	)
	grid_items.add_child(btn_saltar_oleada)
	vbox_main.add_child(HSeparator.new())
	var hbox_sistema := HBoxContainer.new()
	hbox_sistema.add_theme_constant_override("separation", 6)
	vbox_main.add_child(hbox_sistema)
	var btn_pausa := Button.new()
	btn_pausa.text = "⏸️ PAUSA"
	btn_pausa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_pausa.pressed.connect(func(): if game_ui: game_ui._toggle_pause())
	hbox_sistema.add_child(btn_pausa)
	var btn_reiniciar := Button.new()
	btn_reiniciar.text = "🔄 REINICIAR"
	btn_reiniciar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reiniciar.pressed.connect(func(): if game_ui: game_ui._restart_game())
	hbox_sistema.add_child(btn_reiniciar)
	var btn_salir := Button.new()
	btn_salir.text = "❌ SALIR"
	btn_salir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_salir.pressed.connect(func(): if game_ui: game_ui._quit_game())
	hbox_sistema.add_child(btn_salir)
	game_ui.add_child(panel)
	wave_spawner.iniciar_spawning()
	wave_spawner.is_wave_active = true
	_actualizar_estado_spawner_label("ACTIVO")


func _actualizar_estado_spawner_label(estado: String) -> void:
	var panel = game_ui.get_node_or_null("DebugSpawnPanel") if game_ui else null
	if not panel:
		return
	var label = panel.find_child("LabelEstadoSpawner", true, false) as Label
	if label:
		label.text = "Estado: " + estado
		if estado == "ACTIVO":
			label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))


func _limpiar_nodos_combate_spawneados(excluir: Array = []) -> void:
	# IDs a preservar (ej.: los pacíficos/embajadores que acaban de volverse hostiles)
	var ids_excluidos: Dictionary = {}
	for nodo in excluir:
		if is_instance_valid(nodo):
			ids_excluidos[nodo.get_instance_id()] = true

	var nodos_limpiados: Dictionary = {}
	for grupo in GRUPOS_LIMPIEZA_COMBATE:
		for nodo in get_tree().get_nodes_in_group(grupo):
			if not is_instance_valid(nodo):
				continue

			var id_nodo: int = nodo.get_instance_id()
			if nodos_limpiados.has(id_nodo):
				continue
			if ids_excluidos.has(id_nodo):
				continue

			nodos_limpiados[id_nodo] = true
			nodo.queue_free()


func _get_players_cached() -> Array[Node]:
	if _cached_players.is_empty():
		_cached_players.append_array(get_tree().get_nodes_in_group("player"))
	else:
		for i in range(_cached_players.size() - 1, -1, -1):
			if not is_instance_valid(_cached_players[i]):
				_cached_players.remove_at(i)
	return _cached_players


func _set_movimiento_jugador_bloqueado(bloqueado: bool):
	for jugador in _get_players_cached():
		if not is_instance_valid(jugador):
			continue

		var id_jugador: int = jugador.get_instance_id()
		if bloqueado:
			if not estados_proceso_jugador.has(id_jugador):
				estados_proceso_jugador[id_jugador] = {
					"process": jugador.is_processing(), "physics": jugador.is_physics_processing()
				}
			jugador.set_process(false)
			jugador.set_physics_process(false)
		else:
			var estado = estados_proceso_jugador.get(id_jugador, {"process": true, "physics": true})
			jugador.set_process(bool(estado["process"]))
			jugador.set_physics_process(bool(estado["physics"]))

	if not bloqueado:
		estados_proceso_jugador.clear()


func _set_juego_pausado_dialogo(bloqueado: bool):
	_set_movimiento_jugador_bloqueado(bloqueado)

	if not is_instance_valid(wave_spawner):
		return

	var id_spawner: int = wave_spawner.get_instance_id()
	if bloqueado:
		if not estado_spawner_dialogo.has(id_spawner):
			estado_spawner_dialogo[id_spawner] = {
				"process": wave_spawner.is_processing(),
				"physics": wave_spawner.is_physics_processing()
			}
		wave_spawner.set_process(false)
		wave_spawner.set_physics_process(false)
	else:
		var estado_spawner = estado_spawner_dialogo.get(
			id_spawner, {"process": true, "physics": true}
		)
		wave_spawner.set_process(bool(estado_spawner["process"]))
		wave_spawner.set_physics_process(bool(estado_spawner["physics"]))
		estado_spawner_dialogo.clear()

	if bloqueado:
		var grupos_a_pausar: Array[String] = [
			"enemies", "enemy_projectiles", "allies", "shield_imps"
		]
		var nodos_procesados: Dictionary = {}

		for grupo in grupos_a_pausar:
			for nodo in get_tree().get_nodes_in_group(grupo):
				if not is_instance_valid(nodo):
					continue

				var id_nodo = nodo.get_instance_id()
				if nodos_procesados.has(id_nodo):
					continue

				nodos_procesados[id_nodo] = true

				if not estados_proceso_dialogo.has(id_nodo):
					estados_proceso_dialogo[id_nodo] = {
						"process": nodo.is_processing(), "physics": nodo.is_physics_processing()
					}
				nodo.set_process(false)
				nodo.set_physics_process(false)
	else:
		for id_nodo in estados_proceso_dialogo.keys():
			var nodo = instance_from_id(id_nodo)
			if is_instance_valid(nodo):
				var estado_nodo = estados_proceso_dialogo[id_nodo]
				nodo.set_process(bool(estado_nodo["process"]))
				nodo.set_physics_process(bool(estado_nodo["physics"]))

		estados_proceso_dialogo.clear()


func _set_elemento_nivel3_activo(nodo, activo: bool) -> void:
	# Sin tipado en el parámetro: los nodos pueden estar previamente liberados
	# (eliminados en oleada 5+); is_instance_valid filtra ese caso de forma segura.
	if not is_instance_valid(nodo):
		return
	nodo.visible = activo
	nodo.process_mode = Node.PROCESS_MODE_INHERIT if activo else Node.PROCESS_MODE_DISABLED
	_set_collision_recursivo(nodo, activo)


func _set_collision_recursivo(nodo: Node, activo: bool) -> void:
	if nodo is CollisionShape3D:
		nodo.set_deferred("disabled", not activo)
	elif nodo is CollisionObject3D:
		nodo.process_mode = Node.PROCESS_MODE_INHERIT if activo else Node.PROCESS_MODE_DISABLED
	for child in nodo.get_children():
		_set_collision_recursivo(child, activo)


func _spawn_medikit_puerta_torre() -> void:
	# Limpiar medikits previos si existieran
	for m in get_tree().get_nodes_in_group("medikits"):
		if is_instance_valid(m):
			m.queue_free()
	for child in find_children("*", "Medikit", true, false):
		if is_instance_valid(child):
			child.queue_free()

	var medikit_scene: PackedScene = preload("res://Entities/Item_Medikit/Medikit.tscn")
	if not medikit_scene:
		return
	var medikit: Node3D = medikit_scene.instantiate() as Node3D
	if not medikit:
		return
	medikit.add_to_group("medikits")
	add_child(medikit)
	# Ubicado en el suelo directamente frente a la puerta de la torre (-9.7)
	medikit.global_position = Vector3(-9.7, 0.25, 0.0)


func _spawn_icono_mensajera_oleada_5() -> void:
	# Asegurar que solo exista 1 icono de mensajera en todo el nivel
	for n in get_tree().get_nodes_in_group("icono_mensajera"):
		if is_instance_valid(n):
			n.queue_free()
	for child in find_children("*", "IconoMensajeraFX", true, false):
		if is_instance_valid(child):
			child.queue_free()

	# Icono flotante que invoca a la mensajera al que el jugador pase por encima
	var icono_scene: PackedScene = preload("res://Entities/Item_Mensajera/IconoMensajeraFX.tscn")
	if not icono_scene:
		return
	var icono: Node3D = icono_scene.instantiate() as Node3D
	if not icono:
		return
	icono.add_to_group("icono_mensajera")
	var pos := Vector3(-9.2, 0.185, 0.0)
	add_child(icono)
	icono.global_position = pos
	if icono.has_signal("activada") and not icono.activada.is_connected(_iniciar_mensajera_oleada_5):
		icono.activada.connect(_iniciar_mensajera_oleada_5)


func _iniciar_mensajera_oleada_5() -> void:
	# Nivel 5: Defensora de ballesta aliada entra por izquierda, se agacha, deja flecha explosiva, dispara 5 tiros y se marcha.
	# Seguido aparecen 2 defensoras de ballesta móviles que escalan a las plataformas 1 y 3 (la más alta).
	var ballestera_scene: PackedScene = preload("res://Entities/Aliada_Ballestera/AllyBallestera.tscn")
	var power_up_scene: PackedScene = preload("res://Entities/Item_Flecha_Explosiva/PowerUpFlechaExplosiva.tscn")
	if not ballestera_scene or not power_up_scene:
		return
	var ballestera: AllyBallestera = ballestera_scene.instantiate() as AllyBallestera
	if not ballestera:
		return
	ballestera.enemigos_minimos = 999
	ballestera.es_mensajera = true
	ballestera.es_movil = false
	ballestera.en_despliegue = true
	ballestera.vida_maxima = 999
	ballestera.health = 999
	ballestera.set_meta("es_mensajera", true)

	var start_pos: Vector3 = Vector3(-12.8, 0.185, 0.0)
	var entrega_pos: Vector3 = Vector3(-7.4, 0.185, 0.0)

	add_child(ballestera)
	ballestera.scale = Vector3(0.3, 0.3, 0.3)
	ballestera.global_position = start_pos
	ballestera._setup_animation_player()
	ballestera._importar_animaciones_jugador()

	# Caminar hasta el punto de entrega
	ballestera._play_anim("CAMINAR_01", 0.15, 1.0)
	var tween_in: Tween = create_tween()
	var dist_in: float = absf(entrega_pos.x - start_pos.x)
	tween_in.tween_property(ballestera, "global_position:x", entrega_pos.x, dist_in / 1.0)
	await tween_in.finished
	if not is_instance_valid(ballestera):
		return

	ballestera.en_despliegue = false

	# Animación de agacharse y dejar el ítem de flecha explosiva
	ballestera.fase_agachada = true
	ballestera._play_anim("DISPARO_AGACHADO", 0.25, 1.0)
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(ballestera):
		return

	var power_up: Node3D = power_up_scene.instantiate() as Node3D
	if power_up:
		if "municion_a_otorgar_jugador" in power_up:
			power_up.municion_a_otorgar_jugador = 10
		if "municion_a_otorgar_aliadas" in power_up:
			power_up.municion_a_otorgar_aliadas = 5
		add_child(power_up)
		power_up.global_position = ballestera.global_position + Vector3(0.7, 0.3, 0.0)
		var base_y: float = power_up.global_position.y
		var tw: Tween = create_tween()
		tw.tween_property(power_up, "global_position:y", base_y + 0.35, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(power_up, "global_position:y", base_y, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# Iniciar el despliegue de las 2 defensoras móviles en paralelo
	_desplegar_defensoras_moviles_plataformas()

	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(ballestera):
		return

	# 1. Ponerse de pie y disparar 5 tiros con su velocidad base de ataque
	ballestera.fase_agachada = false
	ballestera.enemigos_minimos = 1
	for i in range(5):
		if not is_instance_valid(ballestera):
			break
		ballestera._fijar_pose_combate(0.25)
		AudioManager.play_sfx("bow_tension", -6.0)
		await get_tree().create_timer(ballestera.tiempo_recarga).timeout
		if not is_instance_valid(ballestera):
			break
		var tiempo_carga: float = randf_range(ballestera.tiempo_carga_min, ballestera.tiempo_carga_max)
		await get_tree().create_timer(tiempo_carga).timeout
		if not is_instance_valid(ballestera):
			break
		ballestera._disparar()
		ballestera._play_anim("DISPARO_01", 0.06, 1.0)
		await get_tree().create_timer(0.45).timeout
		if not is_instance_valid(ballestera):
			break
		var idle_wait: float = randf_range(ballestera.idle_min * 0.45, ballestera.idle_max * 0.45)
		await get_tree().create_timer(idle_wait).timeout

	# 2. Agacharse y disparar 3 tiros con su velocidad base de ataque
	if is_instance_valid(ballestera):
		ballestera.fase_agachada = true
		for i in range(3):
			if not is_instance_valid(ballestera):
				break
			ballestera._play_anim("DISPARO_AGACHADO", 0.2, 0.001)
			AudioManager.play_sfx("bow_tension", -6.0)
			await get_tree().create_timer(ballestera.tiempo_recarga).timeout
			if not is_instance_valid(ballestera):
				break
			var tiempo_carga: float = randf_range(ballestera.tiempo_carga_min, ballestera.tiempo_carga_max)
			await get_tree().create_timer(tiempo_carga).timeout
			if not is_instance_valid(ballestera):
				break
			ballestera._disparar()
			ballestera._play_anim("DISPARO_AGACHADO", 0.06, 1.2)
			await get_tree().create_timer(0.45).timeout
			if not is_instance_valid(ballestera):
				break
			var idle_wait: float = randf_range(ballestera.idle_min * 0.45, ballestera.idle_max * 0.45)
			await get_tree().create_timer(idle_wait).timeout

	if not is_instance_valid(ballestera):
		return

	# 3. Ponerse de pie, girar a la izquierda y marcharse por donde apareció
	ballestera.en_despliegue = true
	ballestera.fase_agachada = false
	ballestera.enemigos_minimos = 999
	ballestera._play_anim("CAMINAR_01", 0.15, 1.0)
	var model_out: Node3D = ballestera.get_node_or_null("BallesteraModel") as Node3D
	if not model_out:
		model_out = ballestera.find_child("BallesteraModel", true, false) as Node3D
	if model_out:
		model_out.rotation.y = ballestera._original_model_y_rot + PI

	var tween_out: Tween = create_tween()
	var dist_out: float = absf(start_pos.x - entrega_pos.x)
	tween_out.tween_property(ballestera, "global_position:x", start_pos.x, dist_out / 1.0)
	await tween_out.finished
	if is_instance_valid(ballestera):
		ballestera.queue_free()


## Despliega 2 defensoras de ballesta móviles que caminan y escalan a las plataformas 1 y 3
func _desplegar_defensoras_moviles_plataformas() -> void:
	var ballestera_scene: PackedScene = preload("res://Entities/Aliada_Ballestera/AllyBallestera.tscn")
	if not ballestera_scene:
		return

	var start_pos := Vector3(-12.8, 0.185, 0.0)

	# Exactamente 2 defensoras móviles: Defensora 1 a Plataforma 1 (baja), Defensora 2 a Plataforma 3 (la más alta)
	var plataformas_destino: Array[int] = [1, 3]
	for idx_plat in plataformas_destino:
		var defensora := ballestera_scene.instantiate() as AllyBallestera
		if not defensora:
			continue
		defensora.es_movil = true
		defensora.vida_maxima = 2
		defensora.health = 2
		defensora.enemigos_minimos = 1
		add_child(defensora)
		defensora.scale = Vector3(0.3, 0.3, 0.3)
		defensora.global_position = start_pos

		defensora.desplegar_a_plataforma(idx_plat)
		await get_tree().create_timer(2.2).timeout
