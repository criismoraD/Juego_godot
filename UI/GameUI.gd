class_name GameUI
extends CanvasLayer
## UI del Juego - Separada del Player
## Contiene: Vida, God Mode, Reiniciar, BGM, Volumen, Pausa, Toggle Bordes
# === REFERENCIAS ===
const WAVE_UPDATE_INTERVAL: float = 0.25  # Actualizar progreso de oleada 4 veces por segundo en vez de cada frame
# === ESCUDOS ===
const RUTA_SHADER_OUTLINE := "res://System/Shaders/TOON_LINEANEGRA.gdshader"
const SHADER_OUTLINE := preload(RUTA_SHADER_OUTLINE)
const OUTLINE_WIDTH_RUNTIME := 20.0
static var oleada_inicial_solicitada: int = 0
static var modo_debug_solicitado: bool = false  ## Activar panel debug en NIVEL01 al entrar por menú escape
static var continuar_desde_oleada: int = 0  ## Game Over → Continuar desde la oleada donde se murió (histéresis 1-5)
static var regreso_desde_interior_oleada: int = 0  ## Regreso desde el cuarto interior: oleada completada cuya cortinilla de continuar hay que restaurar (1-5, 0=desactivado)
static var regreso_flechas_explosivas: int = 0  ## Power-ups al entrar al interior: flechas explosivas del jugador
static var regreso_flechas_multiples: int = 0  ## Power-ups al entrar al interior: flechas múltiples del jugador
static var regreso_municion_activa: int = 0  ## Power-ups al entrar al interior: tipo de munición activa del jugador (enum como int)
## Configuración de defensoras asignadas en la torre (1: Plataforma inferior, 2: Plataforma superior)
## Valores posibles: "arquera" o "ballestera"
static var defensoras_config: Dictionary = {
	1: "arquera",
	2: "arquera",
}
## Diálogos de defensoras ya dichos: sobreviven a la recarga de escena al entrar/salir
## de la torre para que no se reinicien si ya se dijeron en oleadas pasadas.
## Solo cubre los 6 diálogos de oleada (el resto de claves sigue repitiéndose normal).
static var dialogos_defensoras_dichos: Dictionary = {}
const DIALOGOS_DEFENSORAS_UNICOS: Array[String] = [
	"DIALOGO_ARQUERA_ARRIBA_CAMBIO_ARMA",
	"DIALOGO_ARQUERA_ABAJO_3",
	"DIALOGO_ARQUERA_ABAJO_15_Y_TU",
	"DIALOGO_ARQUERA_ARRIBA_TENIA_QUE_CONTARLAS",
	"DIALOGO_ARQUERA_ARRIBA_PESADA",
	"DIALOGO_ARQUERA_ABAJO_ESPERANDO",
]


## True si es un diálogo de oleada con memoria anti-reinicio.
static func es_dialogo_defensora_unico(clave: String) -> bool:
	return clave in DIALOGOS_DEFENSORAS_UNICOS


## True si esta clave de diálogo de defensora ya se mostró en la sesión actual.
static func dialogo_defensora_ya_dicho(clave: String) -> bool:
	return bool(dialogos_defensoras_dichos.get(clave, false))


## Marca una clave de diálogo de defensora como ya dicha.
static func marcar_dialogo_defensora_dicho(clave: String) -> void:
	if not clave.is_empty():
		dialogos_defensoras_dichos[clave] = true


## Limpia la memoria de diálogos (inicio fresco de nivel, no regreso de torre).
static func limpiar_dialogos_defensoras() -> void:
	dialogos_defensoras_dichos.clear()

@export_category("Debug")
@export var debug_ui_enabled: bool = true

var player: Node = null
var health_container: HBoxContainer
var heart_icons: Array = []
var pause_panel: Panel
# === NODOS UI ===
var wave_progress: ProgressBar
var wave_progress_label: Label
var wave_container: VBoxContainer
var god_mode_btn: Button
var restart_btn: Button
var pause_btn: Button
var outline_btn: Button
var outline_proy_btn: Button
var quit_btn: Button
# === SLIDERS ===
var bgm_slider: HSlider
var sfx_slider: HSlider
# === SPAWN CONTROL ===
var wave_spawner: Node = null
var btn_iguales: Button
var btn_solo_imp: Button
var btn_solo_goblin: Button
var btn_solo_ggirl: Button
var btn_solo_lonko: Button
var btn_solo_arquera_rosa: Button
var btn_solo_globo: Button
var btn_spawn_escudo: Button
var btn_spawn_posion: Button
var btn_spawn_flecha_explosiva: Button
var flecha_explosiva_scene_debug: PackedScene = preload("res://Entities/Item_Flecha_Explosiva/PowerUpFlechaExplosiva.tscn")
var flecha_multiple_scene_debug: PackedScene = preload("res://Entities/Item_Flecha_Multiple/PowerUpFlechaMultiple.tscn")
var vignette_rect: ColorRect = null
var _vignette_tween: Tween = null
const TEXTURA_ICONO_PUERTA: Texture2D = preload("res://UI/Icons/Flecha_Roja_Abajo.svg")
var _icono_puerta: TextureRect = null
var _tween_icono_puerta: Tween = null
var marco_texto_defensora: Control = null
var texto_defensora: Label = null
var _tween_marco_defensora: Tween = null
var _tween_texto_defensora: Tween = null
var min_ancho_marco_defensora: float = 240.0
var max_ancho_marco_defensora: float = 750.0
var min_alto_marco_defensora: float = 70.0
var padding_defensora: Vector2 = Vector2(28.0, 18.0)
var texto_defensora_personalizado: String = "¡Distingo varias siluetas en el horizonte!"
var velocidad_escritura_defensora: float = 0.025
var duracion_defensora_defecto: float = 4.5
# === TOGGLE UI ===
var bottom_panel: Control
var toggle_ui_btn: Button
# === ESTADO ===
var outlines_enabled: bool = true
var outline_proy_enabled: bool = true
var is_paused: bool = false
var effects_enabled: bool = true  # Fog y DOF habilitados por defecto
var shields_enabled: bool = true
var allies_enabled: bool = true
# === OPTIMIZACIÓN ===
var _wave_update_timer: float = 0.0
var escudo_scene: PackedScene = preload("res://Entities/Ambiente_Escudo/Escudo.tscn")
var posion_scene_debug: PackedScene = preload("res://Entities/Item_Pocion/Posion.tscn")
var escudos_originales: Array = []  # [{transform, parent_path}]
var _escudos_cache: Array[Node] = []
var btn_toggle_shields: Button
var btn_toggle_allies: Button
var btn_revive_allies: Button
var btn_kill_allies: Button
var btn_tipo_defensoras: Button
const ESCENA_BALLESTERA_ALIADA: PackedScene = preload("res://Entities/Aliada_Ballestera/AllyBallestera.tscn")
const ESCENA_ARQUERA_ALIADA: PackedScene = preload("res://Entities/Aliada_Arquera/AllyArcher.tscn")
static var usar_ballesteras: bool = false
var plantillas_aliadas: Array = []  # [{name, parent_path, global_transform, template}]
# === NODOS DE EFECTOS ===
var world_environment: WorldEnvironment = null
var effects_btn: Button
var dof_slider: HSlider
var dof_value_label: Label
var fog_density_slider: HSlider
var fog_density_value_label: Label
var capa001_opacity_slider: HSlider
var capa001_opacity_value_label: Label
var layers_btn: Button
var layers_enabled: bool = true
# === PLANOS DE EFECTOS ===
var fog_plane: Node3D = null
var fog_material: ShaderMaterial = null
var capa001_sprite: Sprite3D = null
# === MATERIALES CON OUTLINE ===
var materials_with_outline: Array = []
# === CALIDAD ===
var Opcion_Calidad: OptionButton
var Indice_Calidad_Actual: int = 1
var Etiquetas_Calidad: Array = [
	"Bajo (Mínimo - 30 FPS)",
	"Medio (60 FPS)",
	"Alto (Sin Límite)"
]

# === RESOLUCIÓN ===
var resolution_option: OptionButton
var fullscreen_check: CheckButton
var resolutions: Array = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]
var resolution_labels: Array = [
	"1280×720 (HD)",
	"1366×768",
	"1600×900",
	"1920×1080 (Full HD)",
	"2560×1440 (2K)",
	"3840×2160 (4K)"
]


func _ready():
	add_to_group("game_ui")
	layer = 100
	_asegurar_marco_texto_defensora()
	_Aplicar_Calidad(1)
	outlines_enabled = true
	outline_proy_enabled = true
	ShaderGlobals.asegurar_outline_global(outlines_enabled)
	ShaderGlobals.asegurar_outline_proyectiles(outline_proy_enabled)

	# Buscar al player
	await get_tree().process_frame
	_find_player()

	# Buscar WorldEnvironment
	_find_world_environment()
	_find_capa001()

	# Escanear materiales con outline
	_scan_outline_materials()

	# Escaneo inicial de mallas para el sistema de outlines optimizado
	var scene_root = _get_scene_root()
	for mesh in scene_root.find_children("*", "MeshInstance3D", true, false):
		mesh.add_to_group("outline_meshes")

	# Crear la UI
	_create_ui()
	_aplicar_toggle_outline_global()
	_aplicar_toggle_outline_proyectiles()

	# Buscar WaveSpawner
	_find_wave_spawner()

	# Guardar posiciones originales de escudos
	_guardar_posiciones_escudos()
	_guardar_plantillas_aliadas()

	# Conectar señales del player
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_health_changed)
		if player.has_signal("died"):
			player.died.connect(_on_player_died)


func _get_scene_root() -> Node:
	if get_tree().current_scene:
		return get_tree().current_scene
	return get_tree().root.get_child(get_tree().root.get_child_count() - 1)


func _find_player():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		# Buscar por nombre
		var root_node = _get_scene_root()
		player = root_node.find_child("Player", true, false)


func _find_world_environment():
	var root_node = _get_scene_root()
	# Buscar el WorldEnvironment en la escena
	world_environment = root_node.find_child("WorldEnvironment", true, false)

	# Buscar plano de niebla
	fog_plane = root_node.find_child("FogPlane", true, false)

	# Obtener el material del fog plane para modificar fog_density
	if fog_plane and fog_plane is MeshInstance3D:
		fog_material = fog_plane.get_surface_override_material(0)


func _find_capa001():
	var root_node = _get_scene_root()
	var nodo = root_node.find_child("CAPA001", true, false)
	if nodo and nodo is Sprite3D:
		capa001_sprite = nodo
	else:
		capa001_sprite = null


func _scan_outline_materials():
	# Lista de materiales conocidos con outline (Preload para evitar E/S síncrona en runtime)
	var materials = [
		preload("res://Entities/Jugador_Arquera/ARQUERA_MATERIAL.tres"),
		preload("res://Entities/Jugador_Arquera/Arrows.tres"),
		preload("res://Entities/Ambiente_Escalera/ESCALERAS.tres"),
		preload("res://Entities/Enemigo_Goblin/Hand Crossbow.tres"),
		preload("res://Entities/Enemigo_Goblin/GOBLING_MATERIAL.tres"),
		preload("res://Entities/Enemigo_Goblin_Girl/MAT_GOBLIN_GIRL.tres"),
		preload("res://Entities/Ambiente_Plataforma/MAT_platform.tres"),
		preload("res://Entities/Ambiente_Escudo/MAT_shield.tres"),
		preload("res://Entities/Ambiente_Pinchos/MAT_spike_trap.tres"),
		preload("res://Entities/Jugador_Arquera/Recurve Bow 2.tres")
	]

	for mat in materials:
		if mat and mat.next_pass:
			materials_with_outline.append({"material": mat, "outline": mat.next_pass})


func _create_ui():
	# ═══════════════════════════════════════════════════════════════════════════
	# VIÑETEADO EN LOS BORDES DE LA PANTALLA (Activo solo en Evento Cuerno)
	# ═══════════════════════════════════════════════════════════════════════════
	vignette_rect = ColorRect.new()
	vignette_rect.name = "VignetteOverlay"
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_mat := ShaderMaterial.new()
	vignette_mat.shader = preload("res://System/Shaders/vignette.gdshader")
	vignette_mat.set_shader_parameter("vignette_color", Color(0.28, 0.04, 0.42, 1.0))
	vignette_mat.set_shader_parameter("vignette_opacity", 0.75)
	vignette_rect.material = vignette_mat
	vignette_rect.modulate.a = 0.0  # Oculto por defecto
	add_child(vignette_rect)

	# ═══════════════════════════════════════════════════════════════════════════
	# PANEL SUPERIOR - VIDA
	# ═══════════════════════════════════════════════════════════════════════════
	health_container = HBoxContainer.new()
	health_container.name = "HealthUI"
	health_container.position = Vector2(10, 10)
	health_container.add_theme_constant_override("separation", 5)
	add_child(health_container)

	_update_health_ui()

	# ═══════════════════════════════════════════════════════════════════════════
	# PROGRESO DE OLEADA
	# ═══════════════════════════════════════════════════════════════════════════
	wave_container = VBoxContainer.new()
	wave_container.name = "WaveProgressUI"
	wave_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wave_container.offset_top = 20
	wave_container.offset_left = -200
	wave_container.offset_right = 200
	wave_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wave_container.alignment = BoxContainer.ALIGNMENT_CENTER
	wave_container.visible = false
	add_child(wave_container)

	wave_progress_label = Label.new()
	wave_progress_label.text = "Oleada en progreso..."
	wave_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_progress_label.add_theme_font_size_override("font_size", 20)
	var label_outline = LabelSettings.new()
	label_outline.outline_size = 4
	label_outline.outline_color = Color.BLACK
	label_outline.font_size = 20
	wave_progress_label.label_settings = label_outline
	wave_container.add_child(wave_progress_label)

	wave_progress = ProgressBar.new()
	wave_progress.custom_minimum_size = Vector2(400, 20)
	wave_progress.show_percentage = false
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	bg_style.set_border_width_all(2)
	bg_style.border_color = Color.BLACK
	var fg_style = StyleBoxFlat.new()
	fg_style.bg_color = Color(0.8, 0.15, 0.15, 0.9)
	fg_style.set_border_width_all(2)
	fg_style.border_color = Color.BLACK
	wave_progress.add_theme_stylebox_override("background", bg_style)
	wave_progress.add_theme_stylebox_override("fill", fg_style)
	wave_container.add_child(wave_progress)

	# ═══════════════════════════════════════════════════════════════════════════
	# PANEL DE PAUSA (OCULTO POR DEFECTO)
	# ═══════════════════════════════════════════════════════════════════════════
	_create_pause_panel()


func _create_pause_panel():
	pause_panel = Panel.new()
	pause_panel.name = "PausePanel"
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	pause_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.add_theme_constant_override("separation", 20)
	pause_panel.add_child(vbox)

	var title = Label.new()
	title.text = "⏸️ PAUSA"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var resume_btn = Button.new()
	resume_btn.text = "▶️ CONTINUAR"
	resume_btn.custom_minimum_size = Vector2(200, 50)
	resume_btn.pressed.connect(_toggle_pause)
	_style_button(resume_btn, Color(0.2, 0.6, 0.3))
	vbox.add_child(resume_btn)

	var restart_pause_btn = Button.new()
	restart_pause_btn.text = "🔄 REINICIAR"
	restart_pause_btn.custom_minimum_size = Vector2(200, 50)
	restart_pause_btn.pressed.connect(
		func():
			_toggle_pause()
			_restart_game()
	)
	_style_button(restart_pause_btn, Color(0.7, 0.3, 0.2))
	vbox.add_child(restart_pause_btn)

	var menu_btn = Button.new()
	menu_btn.text = "🏠 MENÚ PRINCIPAL"
	menu_btn.custom_minimum_size = Vector2(200, 50)
	menu_btn.pressed.connect(_go_to_main_menu)
	_style_button(menu_btn, Color(0.3, 0.4, 0.7))
	vbox.add_child(menu_btn)

	var quit_pause_btn = Button.new()
	quit_pause_btn.text = "❌ SALIR DEL JUEGO"
	quit_pause_btn.custom_minimum_size = Vector2(200, 50)
	quit_pause_btn.pressed.connect(_quit_game)
	_style_button(quit_pause_btn, Color(0.8, 0.2, 0.2))
	vbox.add_child(quit_pause_btn)

	# ═══════════════ CAMBIO DE PERSONAJE ═══════════════
	var sep_personaje = HSeparator.new()
	sep_personaje.custom_minimum_size = Vector2(200, 10)
	vbox.add_child(sep_personaje)

	var btn_perrena := Button.new()
	btn_perrena.name = "BtnControlarPerrena"
	btn_perrena.text = "🦊 CONTROLAR PERRENA"
	btn_perrena.custom_minimum_size = Vector2(200, 44)
	_style_button(btn_perrena, Color(0.55, 0.4, 0.25))
	btn_perrena.pressed.connect(
		func():
			_toggle_pause()
			_cambiar_personaje_controlable()
	)
	vbox.add_child(btn_perrena)

	# ═══════════════ AUDIO ═══════════════
	var sep_audio = HSeparator.new()
	sep_audio.custom_minimum_size = Vector2(200, 10)
	vbox.add_child(sep_audio)

	var audio_label = Label.new()
	audio_label.text = "🔊 AUDIO"
	audio_label.add_theme_font_size_override("font_size", 22)
	audio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(audio_label)

	var _sfx_row = HBoxContainer.new()
	_sfx_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_sfx_row.add_theme_constant_override("separation", 10)
	vbox.add_child(_sfx_row)

	var _sfx_label = Label.new()
	_sfx_label.text = "Volumen general"
	_sfx_label.custom_minimum_size = Vector2(110, 0)
	_sfx_row.add_child(_sfx_label)

	var _sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 100.0
	_sfx_slider.step = 1.0
	_sfx_slider.custom_minimum_size = Vector2(180, 0)
	_sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if AudioManager:
		_sfx_slider.value = clamp(((AudioManager.sfx_volume_db + 40.0) / 40.0) * 100.0, 0.0, 100.0)
	_sfx_slider.value_changed.connect(func(v: float) -> void:
		if AudioManager:
			AudioManager.set_sfx_volume(v)
	)
	_sfx_row.add_child(_sfx_slider)

	var _musica_row = HBoxContainer.new()
	_musica_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_musica_row.add_theme_constant_override("separation", 10)
	vbox.add_child(_musica_row)

	var _musica_label = Label.new()
	_musica_label.text = "Música"
	_musica_label.custom_minimum_size = Vector2(110, 0)
	_musica_row.add_child(_musica_label)

	var _musica_slider = HSlider.new()
	_musica_slider.min_value = 0.0
	_musica_slider.max_value = 100.0
	_musica_slider.step = 1.0
	_musica_slider.custom_minimum_size = Vector2(180, 0)
	_musica_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if AudioManager:
		_musica_slider.value = clamp(((AudioManager.music_volume_db + 40.0) / 40.0) * 100.0, 0.0, 100.0)
	_musica_slider.value_changed.connect(func(v: float) -> void:
		if AudioManager:
			AudioManager.set_music_volume(v)
	)
	_musica_row.add_child(_musica_slider)

	# ═══════════════ SEPARADOR VISUAL ═══════════════
	var sep_lvl = HSeparator.new()
	sep_lvl.custom_minimum_size = Vector2(200, 10)
	sep_lvl.visible = debug_ui_enabled
	vbox.add_child(sep_lvl)

	# ═══════════════ SELECTOR DE OLEADAS Y NIVELES (DEBUG) ═══════════════
	var lvl_label = Label.new()
	lvl_label.text = "⚙️ CONTROLES DE DESARROLLADOR"
	lvl_label.add_theme_font_size_override("font_size", 22)
	lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_label.visible = debug_ui_enabled
	vbox.add_child(lvl_label)

	var hbox_levels = HBoxContainer.new()
	hbox_levels.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_levels.add_theme_constant_override("separation", 10)
	hbox_levels.visible = debug_ui_enabled
	vbox.add_child(hbox_levels)

	var btn_oleada_1 = Button.new()
	btn_oleada_1.text = "Oleada 1"
	btn_oleada_1.custom_minimum_size = Vector2(110, 40)
	btn_oleada_1.pressed.connect(
		func():
			_toggle_pause()
			_ejecutar_cambio_oleada_debug(1)
	)
	_style_button(btn_oleada_1, Color(0.1, 0.4, 0.6))
	hbox_levels.add_child(btn_oleada_1)

	var btn_oleada_2 = Button.new()
	btn_oleada_2.text = "Oleada 2"
	btn_oleada_2.custom_minimum_size = Vector2(110, 40)
	btn_oleada_2.pressed.connect(
		func():
			_toggle_pause()
			_ejecutar_cambio_oleada_debug(2)
	)
	_style_button(btn_oleada_2, Color(0.6, 0.2, 0.4))
	hbox_levels.add_child(btn_oleada_2)

	var btn_oleada_3 = Button.new()
	btn_oleada_3.text = "Oleada 3"
	btn_oleada_3.custom_minimum_size = Vector2(110, 40)
	btn_oleada_3.pressed.connect(
		func():
			_toggle_pause()
			_ejecutar_cambio_oleada_debug(3)
	)
	_style_button(btn_oleada_3, Color(0.5, 0.3, 0.6))
	hbox_levels.add_child(btn_oleada_3)

	var btn_oleada_4 = Button.new()
	btn_oleada_4.text = "Oleada 4"
	btn_oleada_4.custom_minimum_size = Vector2(110, 40)
	btn_oleada_4.pressed.connect(
		func():
			_toggle_pause()
			_ejecutar_cambio_oleada_debug(4)
	)
	_style_button(btn_oleada_4, Color(0.3, 0.5, 0.7))
	hbox_levels.add_child(btn_oleada_4)

	var btn_oleada_5 = Button.new()
	btn_oleada_5.text = "Oleada 5"
	btn_oleada_5.custom_minimum_size = Vector2(110, 40)
	btn_oleada_5.pressed.connect(
		func():
			_toggle_pause()
			_ejecutar_cambio_oleada_debug(5)
	)
	_style_button(btn_oleada_5, Color(0.7, 0.2, 0.5))
	hbox_levels.add_child(btn_oleada_5)

	var btn_oleada_6 = Button.new()
	btn_oleada_6.text = "Oleada 6"
	btn_oleada_6.custom_minimum_size = Vector2(110, 40)
	btn_oleada_6.pressed.connect(
		func():
			_toggle_pause()
			_ejecutar_cambio_oleada_debug(6)
	)
	_style_button(btn_oleada_6, Color(0.8, 0.25, 0.2))
	hbox_levels.add_child(btn_oleada_6)

	# Fila de Navegación de Nivees (Debug)
	var hbox_nav_debug = HBoxContainer.new()
	hbox_nav_debug.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_nav_debug.add_theme_constant_override("separation", 10)
	hbox_nav_debug.visible = debug_ui_enabled
	vbox.add_child(hbox_nav_debug)

	var btn_ir_nivel6 = Button.new()
	btn_ir_nivel6.text = "⚔️ Ir al Nivel 6 (anterior 5)"
	btn_ir_nivel6.custom_minimum_size = Vector2(210, 40)
	btn_ir_nivel6.pressed.connect(
		func():
			_toggle_pause()
			_ejecutar_cambio_oleada_debug(6)
	)
	_style_button(btn_ir_nivel6, Color(0.75, 0.25, 0.2))
	hbox_nav_debug.add_child(btn_ir_nivel6)

	var lvl_beta_btn = Button.new()
	lvl_beta_btn.text = "🏆 Ir al Nivel Beta"
	lvl_beta_btn.custom_minimum_size = Vector2(170, 40)
	lvl_beta_btn.pressed.connect(
		func():
			if is_paused:
				is_paused = false
				get_tree().paused = false
			AudioManager.stop_all()
			if has_node("/root/SceneManager"):
				get_node("/root/SceneManager").change_scene("res://Levels/NIVEL06_ASALTO/NIVEL06_ASALTO.tscn")
			else:
				get_tree().change_scene_to_file("res://Levels/NIVEL06_ASALTO/NIVEL06_ASALTO.tscn")
	)
	_style_button(lvl_beta_btn, Color(0.6, 0.4, 0.1))
	hbox_nav_debug.add_child(lvl_beta_btn)


	var debug_btn = Button.new()
	debug_btn.text = "🔧 Modo Debug (NIVEL01)"
	debug_btn.custom_minimum_size = Vector2(190, 40)
	debug_btn.pressed.connect(
		func():
			if is_paused:
				is_paused = false
				get_tree().paused = false
			AudioManager.stop_all()
			GameUI.modo_debug_solicitado = true
			if has_node("/root/SceneManager"):
				get_node("/root/SceneManager").change_scene("res://Levels/NIVEL01/NIVEL01.tscn")
			else:
				get_tree().change_scene_to_file("res://Levels/NIVEL01/NIVEL01.tscn")
	)
	_style_button(debug_btn, Color(0.4, 0.4, 0.4))
	hbox_nav_debug.add_child(debug_btn)

	btn_tipo_defensoras = Button.new()
	btn_tipo_defensoras.text = "🏹 DEFENSORAS: BALLESTERAS" if usar_ballesteras else "🏹 DEFENSORAS: ARQUERAS"
	btn_tipo_defensoras.custom_minimum_size = Vector2(235, 40)
	btn_tipo_defensoras.pressed.connect(_alternar_tipo_defensoras)
	_style_button(btn_tipo_defensoras, Color(0.2, 0.55, 0.75) if usar_ballesteras else Color(0.7, 0.35, 0.15))
	hbox_nav_debug.add_child(btn_tipo_defensoras)

	# Fila de Acciones de Oleada y Victoria (Debug)
	var hbox_acciones_oleada = HBoxContainer.new()
	hbox_acciones_oleada.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_acciones_oleada.add_theme_constant_override("separation", 10)
	hbox_acciones_oleada.visible = debug_ui_enabled
	vbox.add_child(hbox_acciones_oleada)

	var btn_completar_oleada = Button.new()
	btn_completar_oleada.text = "⏩ Completar Oleada y Siguiente"
	btn_completar_oleada.custom_minimum_size = Vector2(250, 40)
	btn_completar_oleada.pressed.connect(_completar_oleada_actual_debug)
	_style_button(btn_completar_oleada, Color(0.2, 0.65, 0.4))
	hbox_acciones_oleada.add_child(btn_completar_oleada)

	var btn_probar_victoria = Button.new()
	btn_probar_victoria.text = "🎉 Animación Victoria Aliadas"
	btn_probar_victoria.custom_minimum_size = Vector2(240, 40)
	btn_probar_victoria.pressed.connect(_probar_victoria_aliadas_debug)
	_style_button(btn_probar_victoria, Color(0.85, 0.55, 0.15))
	hbox_acciones_oleada.add_child(btn_probar_victoria)

	var btn_test_dialogos = Button.new()
	btn_test_dialogos.text = "💬 Test Boton"
	btn_test_dialogos.custom_minimum_size = Vector2(240, 40)
	btn_test_dialogos.pressed.connect(_probar_dialogos_ambas_arqueras)
	_style_button(btn_test_dialogos, Color(0.7, 0.25, 0.55))
	hbox_acciones_oleada.add_child(btn_test_dialogos)

	# ═══════════════ CALIDAD GRÁFICA ═══════════════
	var sep_calidad = HSeparator.new()
	sep_calidad.custom_minimum_size = Vector2(200, 10)
	vbox.add_child(sep_calidad)

	var qual_label = Label.new()
	qual_label.text = "⚙️ CALIDAD GRÁFICA"
	qual_label.add_theme_font_size_override("font_size", 22)
	qual_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(qual_label)

	Opcion_Calidad = OptionButton.new()
	Opcion_Calidad.custom_minimum_size = Vector2(250, 40)
	Opcion_Calidad.alignment = HORIZONTAL_ALIGNMENT_CENTER
	Opcion_Calidad.focus_mode = Control.FOCUS_NONE
	for i in range(Etiquetas_Calidad.size()):
		Opcion_Calidad.add_item(Etiquetas_Calidad[i], i)
	Opcion_Calidad.selected = Indice_Calidad_Actual
	Opcion_Calidad.item_selected.connect(_Al_Cambiar_Calidad)
	vbox.add_child(Opcion_Calidad)

	# ═══════════════ SEPARADOR VISUAL ═══════════════
	var sep_res = HSeparator.new()
	sep_res.custom_minimum_size = Vector2(200, 10)
	vbox.add_child(sep_res)

	# ═══════════════ RESOLUCIÓN ═══════════════
	var res_label = Label.new()
	res_label.text = "🖥️ RESOLUCIÓN"
	res_label.add_theme_font_size_override("font_size", 22)
	res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(res_label)

	resolution_option = OptionButton.new()
	resolution_option.custom_minimum_size = Vector2(250, 40)
	resolution_option.alignment = HORIZONTAL_ALIGNMENT_CENTER
	resolution_option.focus_mode = Control.FOCUS_NONE
	for i in range(resolution_labels.size()):
		resolution_option.add_item(resolution_labels[i], i)
	# Seleccionar la resolución actual
	var current_size = DisplayServer.window_get_size()
	for i in range(resolutions.size()):
		if resolutions[i] == current_size:
			resolution_option.selected = i
			break
		elif resolutions[i] == Vector2i(1920, 1080):
			resolution_option.selected = i
	resolution_option.item_selected.connect(_on_resolution_changed)
	vbox.add_child(resolution_option)

	# ═══════════════ PANTALLA COMPLETA ═══════════════
	fullscreen_check = CheckButton.new()
	fullscreen_check.text = "Pantalla Completa"
	fullscreen_check.button_pressed = (
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	fullscreen_check.custom_minimum_size = Vector2(200, 40)
	fullscreen_check.focus_mode = Control.FOCUS_NONE
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(fullscreen_check)

	var pause_layer: CanvasLayer = CanvasLayer.new()
	pause_layer.name = "PauseLayer"
	pause_layer.layer = 210
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	pause_layer.add_child(pause_panel)


# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIONES DE UI
# ═══════════════════════════════════════════════════════════════════════════════


func _update_health_ui():
	# La UI de vida anterior (corazones emoji) fue reemplazada por UIVidaProtagonista.tscn
	for icon in heart_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	heart_icons.clear()


func _on_health_changed(_new_health: int):
	_update_health_ui()


func _process(delta):
	if not wave_spawner or not is_instance_valid(wave_spawner):
		if wave_container:
			wave_container.visible = false
		return

	# OPT: Solo actualizar UI de oleada cada WAVE_UPDATE_INTERVAL en vez de cada frame
	_wave_update_timer += delta
	if _wave_update_timer < WAVE_UPDATE_INTERVAL:
		return
	_wave_update_timer = 0.0

	if wave_spawner.get("is_wave_active"):
		var total = wave_spawner.get("enemigos_por_oleada")
		var muertos = wave_spawner.get("enemigos_muertos_en_oleada")
		if total != null and muertos != null:
			var restantes = max(0, total - muertos)

			wave_progress.max_value = total
			wave_progress.value = max(0, total - restantes)
			wave_progress_label.text = "ENEMIGOS RESTANTES: %d / %d" % [restantes, total]
			wave_container.visible = true
	else:
		if wave_container:
			wave_container.visible = false


func _on_player_died():
	# Esperar 2.5 segundos para ver la animación de muerte y su audio completo antes del degradado
	await get_tree().create_timer(2.5).timeout
	if not is_instance_valid(self):
		return

	# Ocultar la barra de progreso de oleadas y contenedor de UI
	if wave_container:
		wave_container.visible = false
	visible = false

	# Instanciar y mostrar la pantalla de Game Over centrada con pantalla negra opaca
	var game_over_screen := UIGameOver.new()
	var root := get_tree().current_scene
	if root:
		root.add_child(game_over_screen)
	else:
		add_child(game_over_screen)


func _ejecutar_cambio_oleada_debug(numero_oleada: int) -> void:
	var current_scene = get_tree().current_scene
	var current_scene_path: String = current_scene.scene_file_path if current_scene else ""

	if not current_scene_path.ends_with("NIVEL01.tscn"):
		oleada_inicial_solicitada = numero_oleada
		if is_paused:
			is_paused = false
			get_tree().paused = false
		AudioManager.stop_all()
		if has_node("/root/SceneManager"):
			get_node("/root/SceneManager").change_scene("res://Levels/NIVEL01/NIVEL01.tscn")
		else:
			get_tree().change_scene_to_file("res://Levels/NIVEL01/NIVEL01.tscn")
		return

	var root_node = _get_scene_root()
	if not is_instance_valid(root_node):
		return

	# "Ir a la Oleada 1" desde NIVEL01 = reiniciar el nivel completo:
	# reproduce el diálogo inicial y el evento del imp embajador.
	if numero_oleada == 1:
		oleada_inicial_solicitada = 1
		if is_paused:
			is_paused = false
			get_tree().paused = false
		AudioManager.stop_all()
		get_tree().reload_current_scene()
		return

	if numero_oleada == 6:
		if root_node.has_method("debug_ir_a_oleada_6"):
			root_node.call("debug_ir_a_oleada_6")
	elif numero_oleada == 5:
		if root_node.has_method("debug_ir_a_oleada_5"):
			root_node.call("debug_ir_a_oleada_5")

	elif numero_oleada == 4:
		if root_node.has_method("debug_ir_a_oleada_4"):
			root_node.call("debug_ir_a_oleada_4")
	elif numero_oleada == 3:
		if root_node.has_method("debug_ir_a_oleada_3"):
			root_node.call("debug_ir_a_oleada_3")
	elif numero_oleada == 2:
		if root_node.has_method("debug_ir_a_oleada_2"):
			root_node.call("debug_ir_a_oleada_2")
	else:
		if root_node.has_method("debug_ir_a_oleada_1"):
			root_node.call("debug_ir_a_oleada_1")


func _probar_victoria_aliadas_debug() -> void:
	if is_paused:
		_toggle_pause()
	for ally in get_tree().get_nodes_in_group("allies"):
		if is_instance_valid(ally) and ally.has_method("celebrar_victoria"):
			ally.celebrar_victoria()


func _probar_dialogos_ambas_arqueras() -> void:
	if is_paused:
		_toggle_pause()
	for ally in get_tree().get_nodes_in_group("allies"):
		if not is_instance_valid(ally):
			continue
		if ally.name == "AllyArcher" and ally.has_method("decir"):
			ally.decir("texto corto", 3.5)
		elif ally.name == "AllyArcher2" and ally.has_method("decir"):
			ally.decir("este es un text con texto largo", 3.5)
		elif ally.has_method("decir"):
			ally.decir("este es un text con texto largo", 3.5)


func _completar_oleada_actual_debug() -> void:
	if is_paused:
		_toggle_pause()

	var root_node = _get_scene_root()
	var spawner: WaveSpawner = null
	for node in get_tree().get_nodes_in_group("wave_spawners"):
		if is_instance_valid(node) and node is WaveSpawner:
			spawner = node
			break

	# Eliminar enemigos hostiles activos en pantalla
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			if enemy.has_method("take_damage"):
				enemy.take_damage(9999)
			elif enemy.has_method("recibir_dano"):
				enemy.recibir_dano(9999)
			else:
				enemy.queue_free()

	if is_instance_valid(spawner):
		spawner.active_goblins.clear()
		spawner.shield_imps_activos.clear()
		spawner.cola_spawn.clear()
		spawner.goblins_spawned_in_wave = spawner.enemigos_por_oleada

	# Si estamos en NIVEL01, ejecutar la secuencia de cortinilla primero
	if is_instance_valid(root_node):
		var oleada_actual: int = 1
		if "oleada_combate_actual" in root_node:
			oleada_actual = root_node.oleada_combate_actual
		elif is_instance_valid(spawner) and spawner.oleada_combate > 0:
			oleada_actual = spawner.oleada_combate

		if root_node.has_method("_mostrar_inter_nivel_continuar"):
			root_node.call("_mostrar_inter_nivel_continuar")
		elif root_node.has_method("_on_nivel1_completado"):
			root_node.call("_on_nivel1_completado", oleada_actual)
		elif is_instance_valid(spawner):
			spawner.oleada_completada.emit(oleada_actual)
	elif is_instance_valid(spawner):
		spawner.oleada_completada.emit(spawner.current_wave)


func _ejecutar_carteles_debug() -> void:
	var root_node = _get_scene_root()
	if not is_instance_valid(root_node):
		return

	if root_node.has_method("debug_mostrar_carteles_transicion"):
		root_node.call("debug_mostrar_carteles_transicion")


func _style_button(btn: Button, color: Color):
	# Desactivar foco para que Space/Enter no activen botones de la UI
	btn.focus_mode = Control.FOCUS_NONE
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 8
	style.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = color.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)


# ═══════════════════════════════════════════════════════════════════════════════
# ACCIONES
# ═══════════════════════════════════════════════════════════════════════════════


func _toggle_bottom_panel():
	if not is_instance_valid(bottom_panel):
		return

	bottom_panel.visible = not bottom_panel.visible
	if is_instance_valid(toggle_ui_btn):
		toggle_ui_btn.text = "🔽 UI" if bottom_panel.visible else "🔼 UI"


func set_bottom_panel_visible(p_visible: bool) -> void:
	if not is_instance_valid(bottom_panel):
		return
	bottom_panel.visible = p_visible
	if is_instance_valid(toggle_ui_btn):
		toggle_ui_btn.text = "🔽 UI" if p_visible else "🔼 UI"


func _toggle_pause():
	is_paused = not is_paused
	get_tree().paused = is_paused
	if is_instance_valid(pause_panel):
		pause_panel.visible = is_paused

	if is_instance_valid(pause_btn):
		if is_paused:
			pause_btn.text = "▶️ PLAY"
			_style_button(pause_btn, Color(0.2, 0.6, 0.3))
			AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
		else:
			pause_btn.text = "⏸️ PAUSA"
			_style_button(pause_btn, Color(0.5, 0.3, 0.6))
			AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)


func _toggle_god_mode():
	if not player:
		return

	player.modo_dios = not player.modo_dios

	if is_instance_valid(god_mode_btn):
		if player.modo_dios:
			god_mode_btn.text = "GOD: ON"
			_style_button(god_mode_btn, Color(0.8, 0.6, 0.1))
		else:
			god_mode_btn.text = "GOD: OFF"
			_style_button(god_mode_btn, Color(0.2, 0.4, 0.8))


func _restart_game():
	# Desactivar pausa si está activa
	if is_paused:
		is_paused = false
		get_tree().paused = false

	# Eliminar enemigos
	# OPT: Cachear el grupo para evitar múltiples accesos al tree
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()

	# Eliminar proyectiles enemigos
	# OPT: Cachear el grupo para evitar múltiples accesos al tree
	var projectiles = get_tree().get_nodes_in_group("enemy_projectiles")
	for proj in projectiles:
		if is_instance_valid(proj):
			proj.queue_free()

	# Reiniciar escena
	get_tree().reload_current_scene()


func _go_to_main_menu():
	# Desactivar pausa y volver al menú principal
	if is_paused:
		is_paused = false
		get_tree().paused = false
	# Detener todos los sonidos del nivel
	AudioManager.stop_all()
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")


func _quit_game():
	AudioManager.stop_all()
	get_tree().quit()


## Alterna el control entre la protagonista y Perrena (defensora con jabalina).
## El personaje que queda sin control se oculta y sale del grupo "player";
## el HUD de corazones se reconecta automáticamente al nuevo "player".
static var _perrena_instanciada: Node3D = null
static var _protagonista_reservada: Node3D = null

func _cambiar_personaje_controlable() -> void:
	var tree := get_tree()
	var actual := tree.get_first_node_in_group("player")
	if not actual:
		return

	var es_perrena_activa: bool = actual is Perrena

	if es_perrena_activa:
		# Volver a la protagonista
		if _protagonista_reservada and is_instance_valid(_protagonista_reservada):
			_activar_personaje(_protagonista_reservada)
			_desactivar_personaje(actual)
			_perrena_instanciada = null
			get_tree().call_group("ui_vida_protagonista", "reconectar_player")
		return

	# Cambiar a Perrena: instanciarla (o reusarla) en la posición de la protagonista
	if not _perrena_instanciada or not is_instance_valid(_perrena_instanciada):
		var escena_perrena: PackedScene = load("res://Entities/Jugador_Perrena/Perrena.tscn")
		if not escena_perrena:
			return
		_perrena_instanciada = escena_perrena.instantiate() as Node3D
		if not _perrena_instanciada:
			return
		var root := tree.current_scene
		if root:
			root.add_child(_perrena_instanciada)
		else:
			return
	_perrena_instanciada.scale = actual.scale
	_perrena_instanciada.global_position = actual.global_position

	_protagonista_reservada = actual
	_desactivar_personaje(actual)
	_activar_personaje(_perrena_instanciada)
	# El HUD de corazones sigue al "player" activo
	get_tree().call_group("ui_vida_protagonista", "reconectar_player")


func _activar_personaje(personaje: Node3D) -> void:
	personaje.visible = true
	personaje.set_physics_process(true)
	personaje.set_process(true)
	if not personaje.is_in_group("player"):
		personaje.add_to_group("player")


func _desactivar_personaje(personaje: Node3D) -> void:
	personaje.visible = false
	personaje.set_physics_process(false)
	personaje.set_process(false)
	if personaje.is_in_group("player"):
		personaje.remove_from_group("player")


func _play_music(index: int):
	AudioManager.play_music(index)


func _on_bgm_volume_changed(value: float):
	AudioManager.set_music_volume(value)


func _on_sfx_volume_changed(value: float):
	AudioManager.set_sfx_volume(value)


# ═══════════════════════════════════════════════════════════════════════════════
# CONTROL DE SPAWN
# ═══════════════════════════════════════════════════════════════════════════════


func _find_wave_spawner() -> Node:
	"""Busca el WaveSpawner en la escena si aún no se tiene referencia"""
	if wave_spawner and is_instance_valid(wave_spawner):
		return wave_spawner

	# Buscar mediante grupo (Optimizado)
	wave_spawner = get_tree().get_first_node_in_group("wave_spawners")
	if not wave_spawner:
		# Fallback: Buscar por nombre en la raíz de la escena
		var root = get_tree().current_scene
		if root:
			wave_spawner = root.find_child("WaveSpawner", true, false)

	if wave_spawner and wave_spawner.has_signal("oleada_iniciada"):
		if not wave_spawner.oleada_iniciada.is_connected(_on_oleada_iniciada_reconstruir_escudos):
			wave_spawner.oleada_iniciada.connect(_on_oleada_iniciada_reconstruir_escudos)

	# Marcar Lonko (tipo 6) por defecto si aún no está forzado
	if wave_spawner and wave_spawner.get("forzar_tipo_enemigo") == -1:
		wave_spawner.forzar_tipo_enemigo = 6

	return wave_spawner


func _es_escudo_enemigo_permitido_en_oleada(nombre_escudo: String, numero_oleada: int) -> bool:
	"""Retorna true solo si el escudo enemigo pertenece a la oleada indicada.
	Escudo_enemigo -> oleadas 3 y 4 | NIVEL_2_Escudo_enemigo2/3 -> oleada 2 | 5+ nunca."""
	if numero_oleada >= 5:
		return false
	if nombre_escudo == "Escudo_enemigo":
		return numero_oleada == 3 or numero_oleada == 4
	if nombre_escudo == "NIVEL_2_Escudo_enemigo2" or nombre_escudo == "NIVEL_2_Escudo_enemigo3":
		return numero_oleada == 2
	if "enemigo" in nombre_escudo.to_lower():
		return false
	return false


func _on_oleada_iniciada_reconstruir_escudos(num_oleada: int) -> void:
	var oleada_real: int = num_oleada
	if wave_spawner and is_instance_valid(wave_spawner) and "oleada_combate" in wave_spawner:
		var oc: int = wave_spawner.oleada_combate
		if oc > 0:
			oleada_real = oc
	var omitir_enemigos := oleada_real >= 5
	_reconstruir_todos_escudos(omitir_enemigos, oleada_real)


	_sincronizar_visibilidad_escudos_por_oleada(oleada_real)
	_ocultar_icono_puerta()


func _sincronizar_visibilidad_escudos_por_oleada(numero_oleada: int) -> void:
	for esc in get_tree().get_nodes_in_group("escudos"):
		if not is_instance_valid(esc) or esc.get("es_escudo_enemigo") != true or esc.get("es_pilar_enemigo") == true:
			continue
		if esc is EnemyBase or esc.is_in_group("enemies") or esc is EscudoPesadoArea:
			continue
		if esc.owner and esc.owner.is_in_group("enemies"):
			continue
		if esc.get_parent() and esc.get_parent().is_in_group("enemies"):
			continue
		var permitido: bool = _es_escudo_enemigo_permitido_en_oleada(esc.name, numero_oleada)

		esc.visible = permitido
		esc.process_mode = Node.PROCESS_MODE_INHERIT if permitido else Node.PROCESS_MODE_DISABLED
		for child in esc.get_children():
			if child is CollisionShape3D:
				child.disabled = not permitido
			elif child is CollisionObject3D:
				child.process_mode = Node.PROCESS_MODE_INHERIT if permitido else Node.PROCESS_MODE_DISABLED
		for child in esc.get_children():
			if child is Node:
				_sincronizar_visibilidad_recursiva(child, permitido)


func _sincronizar_visibilidad_recursiva(nodo: Node, permitido: bool) -> void:
	for child in nodo.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = not permitido
		elif child is CollisionObject3D:
			(child as CollisionObject3D).process_mode = Node.PROCESS_MODE_INHERIT if permitido else Node.PROCESS_MODE_DISABLED
		_sincronizar_visibilidad_recursiva(child, permitido)


## Icono puerta delegado al PuertaTrigger 3D en la escena
func _mostrar_icono_puerta(_overlay: CanvasLayer = null) -> void:
	_ocultar_icono_puerta()


## Oculta el icono puerta si estuviera activo
func _ocultar_icono_puerta() -> void:
	if _tween_icono_puerta and _tween_icono_puerta.is_valid():
		_tween_icono_puerta.kill()
	_tween_icono_puerta = null
	if _icono_puerta and is_instance_valid(_icono_puerta):
		_icono_puerta.visible = false
		if _icono_puerta.is_inside_tree() and (_icono_puerta == get_node_or_null("%IconoPuerta") or _icono_puerta.name == "IconoPuerta"):
			_icono_puerta.visible = false
		else:
			_icono_puerta.queue_free()
		_icono_puerta = null


func _toggle_equal_spawn():
	var spawner = _find_wave_spawner()
	if not spawner:
		push_warning("[GameUI] No se encontró WaveSpawner")
		return
	spawner.probabilidad_igual = not spawner.probabilidad_igual
	spawner.forzar_tipo_enemigo = -1  # Desactivar forzado
	_update_spawn_buttons()


func _set_spawn_type(tipo: int):
	var spawner = _find_wave_spawner()
	if not spawner:
		push_warning("[GameUI] No se encontró WaveSpawner")
		return
	# Toggle: si ya está forzado al mismo tipo, volver a normal
	if spawner.forzar_tipo_enemigo == tipo:
		spawner.forzar_tipo_enemigo = -1
	else:
		spawner.forzar_tipo_enemigo = tipo
		spawner.probabilidad_igual = false
	_update_spawn_buttons()


func _update_spawn_buttons():
	if not is_instance_valid(btn_iguales):
		return

	var spawner = _find_wave_spawner()
	var igual_on = spawner and spawner.probabilidad_igual
	var tipo = spawner.forzar_tipo_enemigo if spawner else -1

	# Botón IGUALES
	if is_instance_valid(btn_iguales):
		if igual_on:
			btn_iguales.text = "⚖️ IGUALES: ON"
			_style_button(btn_iguales, Color(0.2, 0.7, 0.3))
		else:
			btn_iguales.text = "⚖️ IGUALES"
			_style_button(btn_iguales, Color(0.4, 0.4, 0.5))

	# Botón IMP
	if is_instance_valid(btn_solo_imp):
		if tipo == 2:
			btn_solo_imp.text = "👹 IMP ✓"
			_style_button(btn_solo_imp, Color(0.7, 0.2, 0.2))
		else:
			btn_solo_imp.text = "👹 IMP"
			_style_button(btn_solo_imp, Color(0.4, 0.4, 0.5))

	# Botón GOBLIN
	if is_instance_valid(btn_solo_goblin):
		if tipo == 0:
			btn_solo_goblin.text = "🧟 GOBLIN ✓"
			_style_button(btn_solo_goblin, Color(0.3, 0.6, 0.2))
		else:
			btn_solo_goblin.text = "🧟 GOBLIN"
			_style_button(btn_solo_goblin, Color(0.4, 0.4, 0.5))

	# Botón G.GIRL
	if is_instance_valid(btn_solo_ggirl):
		if tipo == 1:
			btn_solo_ggirl.text = "🧝 G.GIRL ✓"
			_style_button(btn_solo_ggirl, Color(0.6, 0.2, 0.6))
		else:
			btn_solo_ggirl.text = "🧝 G.GIRL"
			_style_button(btn_solo_ggirl, Color(0.4, 0.4, 0.5))

	# Botón LONKO
	if is_instance_valid(btn_solo_lonko):
		if tipo == 6:
			btn_solo_lonko.text = "🏹 LONKO ✓"
			_style_button(btn_solo_lonko, Color(0.9, 0.4, 0.1))
		else:
			btn_solo_lonko.text = "🏹 LONKO"
			_style_button(btn_solo_lonko, Color(0.4, 0.4, 0.5))

	# Botón ARQUERA ROSA
	if is_instance_valid(btn_solo_arquera_rosa):
		if tipo == 7:
			btn_solo_arquera_rosa.text = "🌸 A. ROSA ✓"
			_style_button(btn_solo_arquera_rosa, Color(0.9, 0.3, 0.7))
		else:
			btn_solo_arquera_rosa.text = "🌸 A. ROSA"
			_style_button(btn_solo_arquera_rosa, Color(0.4, 0.4, 0.5))

	# Botón GLOBO
	if is_instance_valid(btn_solo_globo):
		if tipo == 8:
			btn_solo_globo.text = "🎈 GLOBO ✓"
			_style_button(btn_solo_globo, Color(0.9, 0.6, 0.2))
		else:
			btn_solo_globo.text = "🎈 GLOBO"
			_style_button(btn_solo_globo, Color(0.4, 0.4, 0.5))


func _toggle_outlines():
	outlines_enabled = not outlines_enabled
	_aplicar_toggle_outline_global()


func _toggle_outlines_proyectiles():
	outline_proy_enabled = not outline_proy_enabled
	_aplicar_toggle_outline_proyectiles()


func _aplicar_toggle_outline_proyectiles():
	if not outline_proy_btn:
		return

	outline_proy_btn.disabled = false
	if outline_proy_enabled:
		outline_proy_btn.text = "✏️ BORDES PROY: ON"
		outline_proy_btn.tooltip_text = "Desactivar contorno en proyectiles enemigos"
		_style_button(outline_proy_btn, Color(0.15, 0.55, 0.6))
	else:
		outline_proy_btn.text = "✏️ BORDES PROY: OFF"
		outline_proy_btn.tooltip_text = "Activar contorno en proyectiles enemigos"
		_style_button(outline_proy_btn, Color(0.35, 0.35, 0.4))

	ShaderGlobals.asegurar_outline_proyectiles(outline_proy_enabled)


func _aplicar_toggle_outline_global():
	if not outline_btn:
		return

	outline_btn.disabled = false
	if outlines_enabled:
		outline_btn.text = "✏️ BORDES: GLOBAL ON"
		outline_btn.tooltip_text = "Desactivar contorno global"
		_style_button(outline_btn, Color(0.1, 0.6, 0.5))
	else:
		outline_btn.text = "✏️ BORDES: GLOBAL OFF"
		outline_btn.tooltip_text = "Activar contorno global"
		_style_button(outline_btn, Color(0.35, 0.35, 0.4))

	_forzar_outline_en_runtime(outlines_enabled)


func _forzar_outline_en_runtime(habilitado: bool) -> void:
	ShaderGlobals.asegurar_outline_global(habilitado)

	if SHADER_OUTLINE == null:
		push_warning("[GameUI] No se pudo cargar SHADER_OUTLINE (TOON_LINEANEGRA.gdshader).")
		return

	var shader_outline := SHADER_OUTLINE

	for item in materials_with_outline:
		if not item is Dictionary:
			continue
		var material_base = item.get("material")
		if material_base is StandardMaterial3D:
			_aplicar_shader_outline_en_material(
				material_base as StandardMaterial3D, shader_outline, habilitado
			)

	# OPT: Cachear el grupo para evitar múltiples accesos al tree
	var meshes = get_tree().get_nodes_in_group("outline_meshes")
	for nodo in meshes:
		var mesh_instance := nodo as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue

		for i in range(mesh_instance.mesh.get_surface_count()):
			var material_activo := mesh_instance.get_active_material(i)
			if material_activo is StandardMaterial3D:
				_aplicar_shader_outline_en_material(
					material_activo as StandardMaterial3D, shader_outline, habilitado
				)


func _aplicar_shader_outline_en_material(
	material_base: StandardMaterial3D, shader_outline: Shader, habilitado: bool
) -> void:
	if material_base == null:
		return

	var outline = material_base.next_pass
	if outline is ShaderMaterial:
		var material_outline := outline as ShaderMaterial
		material_outline.shader = shader_outline
		if habilitado:
			material_outline.set_shader_parameter("outline_width", OUTLINE_WIDTH_RUNTIME)
			material_outline.set_shader_parameter("outline_color", Color(0, 0, 0, 1))
		else:
			material_outline.set_shader_parameter("outline_width", 0.0)
			material_outline.set_shader_parameter("outline_color", Color(0, 0, 0, 0))


func _toggle_effects():
	effects_enabled = not effects_enabled

	if world_environment and world_environment.environment:
		# Controlar FOG
		world_environment.environment.fog_enabled = effects_enabled

		# Controlar DOF (Depth of Field)
		if world_environment.camera_attributes:
			world_environment.camera_attributes.dof_blur_far_enabled = effects_enabled

	# Actualizar botón
	if effects_enabled:
		effects_btn.text = "🌫️ EFECTOS: ON"
		_style_button(effects_btn, Color(0.4, 0.5, 0.6))
	else:
		effects_btn.text = "🌫️ EFECTOS: OFF"
		_style_button(effects_btn, Color(0.3, 0.3, 0.4))


func _on_dof_amount_changed(value: float):
	if world_environment and world_environment.camera_attributes:
		world_environment.camera_attributes.dof_blur_amount = value
	if dof_value_label:
		dof_value_label.text = "%.2f" % value


func _on_fog_density_changed(value: float):
	if fog_material:
		fog_material.set_shader_parameter("fog_density", value)
	if fog_density_value_label:
		fog_density_value_label.text = "%.2f" % value


func _obtener_opacidad_capa001_actual() -> float:
	if capa001_sprite and is_instance_valid(capa001_sprite):
		return capa001_sprite.modulate.a
	return 1.0


func _on_capa001_opacity_changed(value: float):
	if capa001_sprite and is_instance_valid(capa001_sprite):
		var color_capa: Color = capa001_sprite.modulate
		color_capa.a = value
		capa001_sprite.modulate = color_capa
	if capa001_opacity_value_label:
		capa001_opacity_value_label.text = "%.2f" % value


func _toggle_layers():
	layers_enabled = not layers_enabled

	# Mostrar/ocultar FogPlane
	if fog_plane:
		fog_plane.visible = layers_enabled

	# Actualizar botón
	if layers_enabled:
		layers_btn.text = "✨ NIEBLA: ON"
		_style_button(layers_btn, Color(0.5, 0.4, 0.6))
	else:
		layers_btn.text = "✨ NIEBLA: OFF"
		_style_button(layers_btn, Color(0.3, 0.3, 0.4))


func _toggle_shield_sound():
	# Alternar entre sonido de ballesta y flecha para el escudo
	if AudioManager.sfx_streams.has("shield_hit"):
		if (
			AudioManager.sfx_streams["shield_hit"]
			== AudioManager.sfx_streams.get("shield_hit_crossbow")
		):
			AudioManager.sfx_streams["shield_hit"] = AudioManager.sfx_streams.get(
				"shield_hit_arrow", []
			)
			var btn = find_child("ShieldSfxBtn", true, false)
			if btn:
				btn.text = "🛡️ ESCUDO: B"
				_style_button(btn, Color(0.5, 0.6, 0.4))
		else:
			AudioManager.sfx_streams["shield_hit"] = AudioManager.sfx_streams.get(
				"shield_hit_crossbow", []
			)
			var btn = find_child("ShieldSfxBtn", true, false)
			if btn:
				btn.text = "🛡️ ESCUDO: A"
				_style_button(btn, Color(0.4, 0.5, 0.6))


# ═══════════════════════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════════════════════


func _input(event):
	# ESC para pausar
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()


# ═══════════════════════════════════════════════════════════════════════════════
# CONTROL DE ALIADAS
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# CONTROL DE ESCUDOS
# ═══════════════════════════════════════════════════════════════════════════════


func _get_valid_escudos() -> Array[Node]:
	"""Obtiene todos los escudos válidos actualmente en la escena"""
	var escudos_vivas: Array[Node] = []
	for nodo in get_tree().get_nodes_in_group("escudos"):
		if is_instance_valid(nodo) and not nodo.is_queued_for_deletion():
			if nodo.get("es_escudo_enemigo") != true:
				escudos_vivas.append(nodo)
	_escudos_cache = escudos_vivas
	return _escudos_cache


func _guardar_posiciones_escudos():
	"""Guarda las posiciones originales de todos los escudos al inicio"""
	await get_tree().process_frame
	_escudos_cache.clear()
	escudos_originales.clear()

	# OPT: Cachear el grupo primero para evitar N llamadas a get_nodes_in_group si se expandiera en el futuro
	# y asegurar que iteramos sobre una copia estable
	var nodos_escudo = get_tree().get_nodes_in_group("escudos")
	for escudo in nodos_escudo:
		if is_instance_valid(escudo):
			# Guardar TODOS los escudos, incluidos los enemigos: deben
			# reconstruirse también al reiniciar/reiniciar oleada.
			# Se almacena es_escudo_enemigo para filtrar por nivel/oleada.
			_escudos_cache.append(escudo)
			escudos_originales.append(
				{
					"scene_path": escudo.scene_file_path,
					"name": escudo.name,
					"transform": escudo.global_transform,
					"parent_path": escudo.get_parent().get_path(),
					"es_enemigo": escudo.get("es_escudo_enemigo") == true
				}
			)


func _destruir_todos_escudos():
	"""Destruye todos los escudos activos con efecto visual"""
	var escudos = _get_valid_escudos()
	for escudo in escudos:
		if is_instance_valid(escudo) and escudo.has_method("recibir_golpe"):
			# Forzar destrucción inmediata: poner golpes al máximo y dar golpe final
			escudo.golpes_recibidos = escudo.golpes_para_destruir - 1
			escudo.recibir_golpe()


func _reconstruir_todos_escudos(omitir_enemigos: bool = false, numero_oleada: int = -1):
	"""Re-instancia ÚNICAMENTE los escudos que han sido destruidos/rotos.
	omitir_enemigos=true (oleada 5+): los escudos enemigos permanecen eliminados.
	numero_oleada: si >=0, los escudos enemigos solo se reconstruyen si pertenecen a esa oleada."""
	# Resolver oleada actual si no se pasó explícitamente
	if numero_oleada < 0 and wave_spawner and is_instance_valid(wave_spawner) and "oleada_combate" in wave_spawner:
		numero_oleada = wave_spawner.oleada_combate

	# 1. Eliminar restos de escudos rotos que queden en escena
	var escudos_rotos = get_tree().get_nodes_in_group("escudos_rotos")
	for roto in escudos_rotos:
		if is_instance_valid(roto):
			if roto.scene_file_path.contains("Imp"):
				continue
			roto.queue_free()

	# 1b. Si estamos en una oleada definida, eliminar escudos enemigos que no pertenecen a esta oleada y que hayan quedado visibles por reconstrucciones previas
	# Excluir pilares de Lonko (es_pilar_enemigo) que comparten grupo escudos pero son parte del enemigo
	if numero_oleada > 0:
		for esc in get_tree().get_nodes_in_group("escudos"):
			if is_instance_valid(esc) and esc.get("es_escudo_enemigo") == true and esc.get("es_pilar_enemigo") != true:
				if not _es_escudo_enemigo_permitido_en_oleada(esc.name, numero_oleada):
					esc.queue_free()

	# 2. Mapear TODOS los escudos activos actualmente en el mapa
	# (incluidos los enemigos: si siguen intactos NO deben duplicarse)
	var nombres_activos: Dictionary = {}
	for esc in get_tree().get_nodes_in_group("escudos"):
		if is_instance_valid(esc) and not esc.is_queued_for_deletion():
			nombres_activos[esc.name] = esc

	# 3. Recorrer la lista de escudos originales y recrear SOLO los faltantes/rotos
	for data in escudos_originales:
		var nombre_escudo: String = data["name"]
		
		# Si el escudo ya existe e intacto en el mapa, NO tocarlo ni recrearlo
		if nombres_activos.has(nombre_escudo) and is_instance_valid(nombres_activos[nombre_escudo]):
			continue

		var es_enemigo_data: bool = data.get("es_enemigo", false)
		# Si no se guardó el flag, inferir del nombre por compatibilidad con partidas antiguas
		if not es_enemigo_data and "enemigo" in nombre_escudo.to_lower():
			es_enemigo_data = true

		# Escudos enemigos: solo reconstruir si pertenecen a la oleada actual (a menos que se indique explícitamente)
		if es_enemigo_data:
			if omitir_enemigos:
				continue
			if numero_oleada > 0 and not _es_escudo_enemigo_permitido_en_oleada(nombre_escudo, numero_oleada):
				continue

		# Si el escudo falta (fue destruido), recrear SOLO este escudo roto
		var nuevo_escudo: Node = null
		var scene_path: String = data.get("scene_path", "")
		if scene_path != "":
			var res = load(scene_path)
			if res is PackedScene:
				nuevo_escudo = res.instantiate()

		if nuevo_escudo == null:
			nuevo_escudo = escudo_scene.instantiate()

		# Oleada 5+: los escudos enemigos permanecen eliminados (doble chequeo por si el flag no estaba en data)
		# Excluir pilares (no son escudos estáticos)
		if omitir_enemigos and nuevo_escudo.get("es_escudo_enemigo") == true and nuevo_escudo.get("es_pilar_enemigo") != true:
			nuevo_escudo.free()
			continue
		# Filtro por oleada también sobre el nodo instanciado (por si data antigua no tenía es_enemigo)
		if numero_oleada > 0 and nuevo_escudo.get("es_escudo_enemigo") == true and nuevo_escudo.get("es_pilar_enemigo") != true:
			if not _es_escudo_enemigo_permitido_en_oleada(nombre_escudo, numero_oleada):
				nuevo_escudo.free()
				continue

		var parent = get_node_or_null(data["parent_path"])
		if parent and is_instance_valid(parent):
			parent.add_child(nuevo_escudo)
		else:
			get_tree().current_scene.add_child(nuevo_escudo)

		nuevo_escudo.name = nombre_escudo
		nuevo_escudo.global_transform = data["transform"]

		# Animar la reaparición mística con el shader de disolución SOLO para los escudos reconstruidos
		_animar_aparicion_escudo_disolucion(nuevo_escudo)

	# Actualizar caché de escudos
	_escudos_cache = _get_valid_escudos()

	shields_enabled = true
	if btn_toggle_shields:
		btn_toggle_shields.text = "🛡️ ESCUDOS: ON"
		_style_button(btn_toggle_shields, Color(0.3, 0.5, 0.6))


## Reconstruye un escudo enemigo puntual aunque no pertenezca a la oleada actual.
## Usar solo cuando el diseño lo indique explícitamente (ej. evento especial).
func reconstruir_escudo_enemigo_explicito(nombre_escudo: String) -> void:
	for data in escudos_originales:
		if data["name"] != nombre_escudo:
			continue
		var nombres_activos: Dictionary = {}
		for esc in get_tree().get_nodes_in_group("escudos"):
			if is_instance_valid(esc):
				nombres_activos[esc.name] = true
		if nombres_activos.has(nombre_escudo):
			return
		var res = load(data.get("scene_path", "")) if data.get("scene_path", "") != "" else null
		var nuevo: Node = (res as PackedScene).instantiate() if res is PackedScene else escudo_scene.instantiate()
		var parent = get_node_or_null(data["parent_path"])
		if parent and is_instance_valid(parent):
			parent.add_child(nuevo)
		else:
			get_tree().current_scene.add_child(nuevo)
		nuevo.name = nombre_escudo
		nuevo.global_transform = data["transform"]
		_animar_aparicion_escudo_disolucion(nuevo)
		break
	_escudos_cache = _get_valid_escudos()


func _animar_aparicion_escudo_disolucion(escudo: Node) -> void:
	if not is_instance_valid(escudo):
		return
	var dissolve_shader = preload("res://System/Shaders/dissolve.gdshader")
	var meshes: Array[Node] = escudo.find_children("*", "MeshInstance3D", true, false)
	var dissolve_mats: Array = []

	for mesh in meshes:
		if not is_instance_valid(mesh):
			continue
		var mi := mesh as MeshInstance3D
		var mat := ShaderMaterial.new()
		mat.shader = dissolve_shader
		mat.set_shader_parameter("dissolve_amount", 1.0)
		mat.set_shader_parameter("glow_color", Color(0.2, 0.8, 1.0))
		mat.set_shader_parameter("glow_intensity", 8.0)
		mat.set_shader_parameter("edge_thickness", 0.08)
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
		dissolve_mats.append({"mesh": mi, "material": mat, "original": orig})

	# Encontrar el nodo visual 3D (para no deformar la colisión del StaticBody3D en Jolt Physics)
	var nodo_visual: Node3D = null
	for child in escudo.get_children():
		if child is Node3D and not (child is CollisionShape3D) and not (child is SombraPersonaje):
			nodo_visual = child
			break

	var target_vis_scale: Vector3 = Vector3.ONE
	if nodo_visual:
		target_vis_scale = nodo_visual.scale
		if target_vis_scale.is_zero_approx():
			target_vis_scale = Vector3.ONE
		nodo_visual.scale = Vector3(target_vis_scale.x * 0.4, 0.01, target_vis_scale.z * 0.4)

	# Desactivar colisiones mientras se materializa
	var col_shapes: Array[CollisionShape3D] = []
	for child in escudo.get_children():
		if child is CollisionShape3D:
			col_shapes.append(child)
			child.set_deferred("disabled", true)

	var duracion: float = 1.2
	var tween := escudo.create_tween().set_parallel(true)

	# 1. Materialización con shader dissolve
	tween.tween_method(
		func(val: float) -> void:
			for item in dissolve_mats:
				if is_instance_valid(item["mesh"]):
					item["material"].set_shader_parameter("dissolve_amount", val),
		1.0, 0.0, duracion
	)

	# 2. Crecimiento/Escalado vertical desde la base hacia arriba en el nodo visual
	if nodo_visual:
		tween.tween_property(nodo_visual, "scale", target_vis_scale, duracion) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.finished.connect(
		func() -> void:
			for item in dissolve_mats:
				if is_instance_valid(item["mesh"]):
					item["mesh"].material_override = item["original"]
			if is_instance_valid(nodo_visual):
				nodo_visual.scale = target_vis_scale
			for col in col_shapes:
				if is_instance_valid(col):
					col.set_deferred("disabled", false)
	)


func _toggle_escudos():
	"""Toggle ON/OFF de todos los escudos"""
	shields_enabled = not shields_enabled
	var escudos = _get_valid_escudos()
	for escudo in escudos:
		if is_instance_valid(escudo):
			escudo.visible = shields_enabled
			# Activar/desactivar colisión
			for child in escudo.get_children():
				if child is CollisionShape3D:
					child.disabled = not shields_enabled

	if is_instance_valid(btn_toggle_shields):
		if shields_enabled:
			btn_toggle_shields.text = "🛡️ ESCUDOS: ON"
			_style_button(btn_toggle_shields, Color(0.3, 0.5, 0.6))
		else:
			btn_toggle_shields.text = "🛡️ ESCUDOS: OFF"
			_style_button(btn_toggle_shields, Color(0.4, 0.4, 0.4))


# ═══════════════════════════════════════════════════════════════════════════════
# CONTROL DE ALIADAS
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# CONTROL DE CALIDAD GRÁFICA
# ═══════════════════════════════════════════════════════════════════════════════


func _Aplicar_Calidad(indice: int) -> void:
	Indice_Calidad_Actual = indice
	var vp := get_viewport()
	if not vp:
		return

	match indice:
		0:  # Bajo (Mínimo)
			Engine.max_fps = 30
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_scale = 0.5
			vp.positional_shadow_atlas_size = 512
			RenderingServer.directional_shadow_atlas_set_size(512, true)
		1:  # Medio
			Engine.max_fps = 60
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.scaling_3d_scale = 0.75
			vp.positional_shadow_atlas_size = 1024
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
		2:  # Alto
			Engine.max_fps = 0  # Sin límite
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.scaling_3d_scale = 1.0
			vp.positional_shadow_atlas_size = 2048
			RenderingServer.directional_shadow_atlas_set_size(2048, true)


func _Al_Cambiar_Calidad(indice: int) -> void:
	_Aplicar_Calidad(indice)


# ═══════════════════════════════════════════════════════════════════════════════
# RESOLUCIÓN Y PANTALLA COMPLETA
# ═══════════════════════════════════════════════════════════════════════════════


func _on_resolution_changed(index: int):
	var new_res = resolutions[index]
	if (
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	):
		# En pantalla completa, cambiar tamano del viewport
		get_viewport().size = new_res
		DisplayServer.window_set_size(new_res)
	else:
		DisplayServer.window_set_size(new_res)
		# Centrar ventana tras un frame para que el tamano se aplique
		await get_tree().process_frame
		var screen_size = DisplayServer.screen_get_size()
		var actual_size = DisplayServer.window_get_size()
		var win_pos = Vector2i(
			int((screen_size.x - actual_size.x) / 2.0), int((screen_size.y - actual_size.y) / 2.0)
		)
		DisplayServer.window_set_position(win_pos)


func _on_fullscreen_toggled(toggled_on: bool):
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Aplicar resolución seleccionada al salir de pantalla completa
		if resolution_option:
			var idx = resolution_option.selected
			if idx >= 0 and idx < resolutions.size():
				var res = resolutions[idx]
				DisplayServer.window_set_size(res)
				await get_tree().process_frame
				var screen_size = DisplayServer.screen_get_size()
				var actual_size = DisplayServer.window_get_size()
				var win_pos = Vector2i(
					int((screen_size.x - actual_size.x) / 2.0), int((screen_size.y - actual_size.y) / 2.0)
				)
				DisplayServer.window_set_position(win_pos)


func _toggle_imp_blood_color():
	"""Toggle entre sangre roja y morada para los Imps"""
	ImpEnemy.sangre_morada = not ImpEnemy.sangre_morada
	var btn = find_child("BloodToggleBtn", true, false)
	if btn:
		if ImpEnemy.sangre_morada:
			btn.text = "🩸 SANGRE: MORADA"
			_style_button(btn, Color(0.4, 0.1, 0.5))
		else:
			btn.text = "🩸 SANGRE: ROJA"
			_style_button(btn, Color(0.6, 0.15, 0.15))


func _toggle_aliadas():
	"""Toggle ON/OFF de todas las defensoras aliadas"""
	allies_enabled = not allies_enabled
	for ally in AllyArcher.active_allies_cache:
		if is_instance_valid(ally):
			_aplicar_estado_aliada(ally)

	if is_instance_valid(btn_toggle_allies):
		if allies_enabled:
			btn_toggle_allies.text = "🏹 ALIADAS: ON"
			_style_button(btn_toggle_allies, Color(0.3, 0.6, 0.5))
		else:
			btn_toggle_allies.text = "🏹 ALIADAS: OFF"
			_style_button(btn_toggle_allies, Color(0.4, 0.4, 0.4))


## Alterna en tiempo real entre Arqueras y Ballesteras para las defensoras de la muralla
func _alternar_tipo_defensoras() -> void:
	usar_ballesteras = not usar_ballesteras
	var nueva_escena: PackedScene = ESCENA_BALLESTERA_ALIADA if usar_ballesteras else ESCENA_ARQUERA_ALIADA

	var aliadas_a_reemplazar: Array[Node] = []
	for ally in AllyArcher.active_allies_cache.duplicate():
		if is_instance_valid(ally):
			aliadas_a_reemplazar.append(ally)

	if aliadas_a_reemplazar.is_empty():
		for a in get_tree().get_nodes_in_group("allies"):
			if a is Node3D and is_instance_valid(a) and not (a is StaticBody3D) and not (a is CollisionShape3D):
				aliadas_a_reemplazar.append(a)

	for vieja_aliada in aliadas_a_reemplazar:
		if not is_instance_valid(vieja_aliada):
			continue
		var parent = vieja_aliada.get_parent()
		if not parent:
			continue

		var t_global = vieja_aliada.global_transform
		var vida_act = vieja_aliada.health if "health" in vieja_aliada else 2
		var f_exp = vieja_aliada.flechas_explosivas if "flechas_explosivas" in vieja_aliada else 0
		var f_mult = vieja_aliada.flechas_multiples if "flechas_multiples" in vieja_aliada else 0
		var nombre_orig = vieja_aliada.name

		vieja_aliada.queue_free()
		AllyArcher.active_allies_cache.erase(vieja_aliada)

		var nueva_aliada: Node3D = nueva_escena.instantiate() as Node3D
		nueva_aliada.name = nombre_orig
		parent.add_child(nueva_aliada)
		nueva_aliada.global_transform = t_global
		if "health" in nueva_aliada:
			nueva_aliada.health = vida_act
		if "flechas_explosivas" in nueva_aliada:
			nueva_aliada.flechas_explosivas = f_exp
		if "flechas_multiples" in nueva_aliada:
			nueva_aliada.flechas_multiples = f_mult

	_actualizar_boton_tipo_defensoras()


func _actualizar_boton_tipo_defensoras() -> void:
	if is_instance_valid(btn_tipo_defensoras):
		if usar_ballesteras:
			btn_tipo_defensoras.text = "🏹 DEFENSORAS: BALLESTERAS"
			_style_button(btn_tipo_defensoras, Color(0.2, 0.55, 0.75))
		else:
			btn_tipo_defensoras.text = "🏹 DEFENSORAS: ARQUERAS"
			_style_button(btn_tipo_defensoras, Color(0.7, 0.35, 0.15))


func _guardar_plantillas_aliadas():
	"""Guarda una plantilla de cada aliada inicial para poder revivirla por debug."""
	plantillas_aliadas.clear()
	for ally in AllyArcher.active_allies_cache:
		if not is_instance_valid(ally):
			continue
		var plantilla: Node = ally.duplicate()
		if not plantilla:
			continue
		(
			plantillas_aliadas
			. append(
				{
					"name": ally.name,
					"parent_path": ally.get_parent().get_path(),
					"global_transform": ally.global_transform,
					"template": plantilla,
				}
			)
		)


func _buscar_aliada_por_nombre(nombre_aliada: String) -> Node:
	for ally in AllyArcher.active_allies_cache:
		if is_instance_valid(ally) and ally.name == nombre_aliada:
			return ally
	return null


func _aplicar_estado_aliada(ally: Node):
	if not ally or not is_instance_valid(ally):
		return
	if "visible" in ally:
		ally.visible = allies_enabled
	if ally.has_method("set_process"):
		ally.set_process(allies_enabled)
	if ally.has_method("set_physics_process"):
		ally.set_physics_process(allies_enabled)
	var hitbox = ally.get("hitbox_body")
	if hitbox and is_instance_valid(hitbox):
		hitbox.collision_layer = 2 if allies_enabled else 0


func _aliada_esta_revivible(ally: AllyArcher) -> bool:
	if not ally or not is_instance_valid(ally):
		return true
	var estado_actual = ally.get("current_state")
	if (
		estado_actual != null
		and (
			int(estado_actual) == int(AllyArcher.State.DYING)
			or int(estado_actual) == int(AllyArcher.State.DEAD)
		)
	):
		return true
	var vida_actual = ally.get("health")
	if vida_actual != null and int(vida_actual) <= 0:
		return true
	return false


func _revivir_aliadas():
	"""Revive aliadas destruidas reinstanciandolas en su posicion original."""
	if plantillas_aliadas.is_empty():
		_guardar_plantillas_aliadas()

	for data in plantillas_aliadas:
		var nombre_aliada: String = str(data.get("name", ""))
		if nombre_aliada == "":
			continue

		var existente: AllyArcher = _buscar_aliada_por_nombre(nombre_aliada)
		if existente and is_instance_valid(existente):
			if _aliada_esta_revivible(existente):
				if existente.has_method("revivir"):
					existente.revivir()
				_aplicar_estado_aliada(existente)
				continue
			else:
				_aplicar_estado_aliada(existente)
				continue

		var plantilla: Node = data.get("template")
		if not plantilla or not is_instance_valid(plantilla):
			continue

		var nueva_aliada: Node = plantilla.duplicate()
		if not nueva_aliada:
			continue

		var parent_path: NodePath = data.get("parent_path", NodePath("."))
		var parent = get_node_or_null(parent_path)
		if not parent or not is_instance_valid(parent):
			parent = get_tree().current_scene
		if not parent:
			continue

		parent.add_child(nueva_aliada)
		nueva_aliada.name = nombre_aliada

		if nueva_aliada is Node3D:
			var transform_original: Transform3D = data.get("global_transform", Transform3D.IDENTITY)
			(nueva_aliada as Node3D).global_transform = transform_original

		if nueva_aliada is AllyArcher:
			_aplicar_estado_aliada(nueva_aliada)


func _matar_aliadas():
	for ally in AllyArcher.active_allies_cache:
		if is_instance_valid(ally) and (ally is AllyArcher or ally is AllyBallestera):
			if ally.current_state != ally.State.DEAD and ally.current_state != ally.State.DYING:
				if ally.has_method("recibir_dano"):
					ally.recibir_dano(9999)
				else:
					ally.health = 0
					ally._cambiar_estado(ally.State.DYING)


# ═══════════════════════════════════════════════════════════════════════════════
# MODO MÍNIMO (Solo corazones de vida)
# ═══════════════════════════════════════════════════════════════════════════════


## Activa/desactiva el modo mínimo: oculta todo excepto los corazones de vida.
func set_modo_minimo(activo: bool):
	if toggle_ui_btn:
		toggle_ui_btn.visible = debug_ui_enabled and not activo
	if bottom_panel:
		bottom_panel.visible = false


func mostrar_cortinilla_debug(duracion: float = 3.0) -> void:
	var existing = get_node_or_null("PantallaVictoriaCortinilla")
	if existing and is_instance_valid(existing):
		existing.queue_free()

	var overlay = CanvasLayer.new()
	overlay.layer = 210
	overlay.name = "PantallaVictoriaCortinilla"
	overlay.add_to_group("pantalla_victoria_cortinilla")
	add_child(overlay)

	var cortinilla = TextureRect.new()
	cortinilla.texture = load("res://Recursos_Compartidos/fondo trasparencia.png")
	cortinilla.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cortinilla.stretch_mode = TextureRect.STRETCH_SCALE
	
	# Posición inicial: oculta a la derecha
	cortinilla.anchor_left = 1.0
	cortinilla.anchor_right = 1.0
	cortinilla.anchor_top = 0.0
	cortinilla.anchor_bottom = 1.0
	
	cortinilla.offset_left = 0
	cortinilla.offset_right = 0
	cortinilla.offset_top = 0
	cortinilla.offset_bottom = 0
	overlay.add_child(cortinilla)

	# Animación de entrada: desliza de derecha a izquierda
	var tween_in = create_tween()
	tween_in.tween_property(cortinilla, "anchor_left", 0.0, 0.6)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

	# Esperar la duración solicitada (3 segundos)
	await get_tree().create_timer(duracion, false).timeout
	if not is_instance_valid(overlay) or not is_instance_valid(cortinilla):
		return

	# Animación de salida: regresa a la derecha
	var tween_out = create_tween()
	tween_out.tween_property(cortinilla, "anchor_left", 1.0, 0.6)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)

	await tween_out.finished
	if is_instance_valid(overlay):
		overlay.queue_free()


func mostrar_pantalla_victoria(titulo: String, on_continuar: Callable):
	# 1. Crear CanvasLayer
	var overlay = CanvasLayer.new()
	overlay.layer = 210
	overlay.name = "PantallaVictoriaCortinilla"
	overlay.add_to_group("pantalla_victoria_cortinilla")
	add_child(overlay)

	# 1b. Icono puerta pulsante (llama la atención para salir al mapa)
	_mostrar_icono_puerta(overlay)

	# 2. Crear TextureRect con fondo trasparencia.png
	var cortinilla = TextureRect.new()
	cortinilla.texture = load("res://Recursos_Compartidos/fondo trasparencia.png")
	cortinilla.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cortinilla.stretch_mode = TextureRect.STRETCH_SCALE
	
	# Posición inicial: oculta a la derecha (ancho = 0)
	cortinilla.anchor_left = 1.0
	cortinilla.anchor_right = 1.0
	cortinilla.anchor_top = 0.0
	cortinilla.anchor_bottom = 1.0
	
	cortinilla.offset_left = 0
	cortinilla.offset_right = 0
	cortinilla.offset_top = 0
	cortinilla.offset_bottom = 0
	overlay.add_child(cortinilla)

	# 3. Crear Contenedor de UI (en la parte derecha, cubriendo de 0.28 a 1.0 en X)
	var ui_container = Control.new()
	ui_container.anchor_left = 0.28
	ui_container.anchor_right = 1.0
	ui_container.anchor_top = 0.0
	ui_container.anchor_bottom = 1.0
	ui_container.offset_left = 0
	ui_container.offset_right = 0
	ui_container.offset_top = 0
	ui_container.offset_bottom = 0
	ui_container.modulate.a = 0.0  # Empezar invisible para fade-in
	overlay.add_child(ui_container)

	# 4. VBoxContainer centrado para el texto y botón
	var center = VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 30)
	ui_container.add_child(center)

	# Título (e.g. LEVEL COMPLETE!)
	var title_label = Label.new()
	title_label.text = titulo.to_upper()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var settings_title = LabelSettings.new()
	settings_title.font_size = 64
	settings_title.font_color = Color(1, 1, 1, 1)
	settings_title.outline_size = 12
	settings_title.outline_color = Color(0, 0, 0, 1)
	title_label.label_settings = settings_title
	center.add_child(title_label)

	# Botón Continuar
	var boton = Button.new()
	boton.text = tr("BOTON_CONTINUAR") if TranslationServer.get_locale() != "" else "CONTINUAR"
	boton.add_theme_font_size_override("font_size", 24)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.08, 0.05, 0.95)
	btn_style.border_color = Color(0.85, 0.65, 0.2)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(12)
	boton.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.2, 0.14, 0.08, 0.95)
	boton.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.08, 0.05, 0.02, 0.95)
	boton.add_theme_stylebox_override("pressed", btn_pressed)

	boton.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	boton.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.6))
	boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(boton)

	# 5. Animación de entrada de la cortinilla y la UI
	var tween_in = create_tween()
	# Estirar de derecha a izquierda: animar anchor_left de 1.0 a 0.0
	tween_in.tween_property(cortinilla, "anchor_left", 0.0, 0.6)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tween_in.parallel().tween_property(ui_container, "modulate:a", 1.0, 0.4)\
		.set_delay(0.2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	# 6. Lógica de botón de continuar
	boton.pressed.connect(
		func():
			boton.disabled = true
			
			# Llamar al callback de continuar inmediatamente
			on_continuar.call()
			
			# Desvanecer UI
			var tween_out = create_tween()
			tween_out.tween_property(ui_container, "modulate:a", 0.0, 0.2)\
				.set_trans(Tween.TRANS_SINE)
			
			# La cortinilla regresa por donde vino (de 0.0 a 1.0)
			tween_out.parallel().tween_property(cortinilla, "anchor_left", 1.0, 0.6)\
				.set_trans(Tween.TRANS_QUAD)\
				.set_ease(Tween.EASE_IN_OUT)
			
			await tween_out.finished
			overlay.queue_free()
	)


# ═══════════════════════════════════════════════════════════════════════════════
# DEBUG: SPAWN POCIÓN
# ═══════════════════════════════════════════════════════════════════════════════

func _spawn_posion_debug() -> void:
	if not posion_scene_debug:
		push_warning("[GameUI] posion_scene_debug no está asignado.")
		return

	var scene_root := get_tree().current_scene
	if not scene_root:
		push_warning("[GameUI] No hay escena activa para instanciar la poción.")
		return

	var posion := posion_scene_debug.instantiate() as Node3D
	if not posion:
		push_warning("[GameUI] No se pudo instanciar Posion.tscn.")
		return

	var target_x: float = 0.0
	var target_y: float = 1.0
	var target_z: float = 0.0
	if player and is_instance_valid(player) and "global_position" in player:
		target_x = player.global_position.x
		target_y = player.global_position.y
		target_z = player.global_position.z

	posion.position = Vector3(target_x, target_y + 4.0, target_z)
	scene_root.add_child(posion)
	posion.global_position = Vector3(target_x, target_y + 4.0, target_z)


# ═══════════════════════════════════════════════════════════════════════════════
# DEBUG: SPAWN FLECHA EXPLOSIVA
# ═══════════════════════════════════════════════════════════════════════════════


func _spawn_flecha_explosiva_debug() -> void:
	if not flecha_explosiva_scene_debug:
		push_warning("[GameUI] flecha_explosiva_scene_debug no está asignado.")
		return

	var scene_root := get_tree().current_scene
	if not scene_root:
		push_warning("[GameUI] No hay escena activa para instanciar el power-up.")
		return

	var item := flecha_explosiva_scene_debug.instantiate() as Node3D
	if not item:
		push_warning("[GameUI] No se pudo instanciar PowerUpFlechaExplosiva.tscn.")
		return

	var target_x: float = 0.0
	var target_y: float = 1.0
	var target_z: float = 0.0
	if player and is_instance_valid(player) and "global_position" in player:
		target_x = player.global_position.x
		target_y = player.global_position.y
		target_z = player.global_position.z

	item.position = Vector3(target_x, target_y + 4.0, target_z)
	scene_root.add_child(item)
	item.global_position = Vector3(target_x, target_y + 4.0, target_z)


# ═══════════════════════════════════════════════════════════════════════════════
# DEBUG: SPAWN FLECHA MÚLTIPLE
# ═══════════════════════════════════════════════════════════════════════════════


func _spawn_flecha_multiple_debug() -> void:
	if not flecha_multiple_scene_debug:
		push_warning("[GameUI] flecha_multiple_scene_debug no está asignado.")
		return

	var scene_root := get_tree().current_scene
	if not scene_root:
		push_warning("[GameUI] No hay escena activa para instanciar el power-up.")
		return

	var item := flecha_multiple_scene_debug.instantiate() as Node3D
	if not item:
		push_warning("[GameUI] No se pudo instanciar PowerUpFlechaMultiple.tscn.")
		return

	var target_x: float = 0.0
	var target_y: float = 1.0
	var target_z: float = 0.0
	if player and is_instance_valid(player) and "global_position" in player:
		target_x = player.global_position.x
		target_y = player.global_position.y
		target_z = player.global_position.z

	item.position = Vector3(target_x, target_y + 4.0, target_z)
	scene_root.add_child(item)
	item.global_position = Vector3(target_x, target_y + 4.0, target_z)


## Activa el oscurecimiento con viñeteado morado oscuro durante el evento del cuerno con transición gradual
func activar_efecto_viñeta_cuerno(duracion: float = 3.8) -> void:
	if not is_instance_valid(vignette_rect):
		return

	if _vignette_tween and _vignette_tween.is_valid():
		_vignette_tween.kill()

	_vignette_tween = create_tween()
	# Transición de entrada gradual y sedosa desde el valor actual hacia 1.0
	var tiempo_fade_in: float = 1.2 * (1.0 - vignette_rect.modulate.a)
	_vignette_tween.tween_property(vignette_rect, "modulate:a", 1.0, max(0.2, tiempo_fade_in)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Mantiene el efecto visible
	_vignette_tween.tween_interval(max(0.8, duracion - 2.4))
	# Transición de salida suave (fade-out gradual en 1.3 segundos)
	_vignette_tween.tween_property(vignette_rect, "modulate:a", 0.0, 1.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Obtiene la posición en pantalla del punto de nacimiento del diálogo
func _obtener_posicion_nacimiento_dialogo() -> Vector2:
	var punto := get_node_or_null("%PuntoNacimientoDialogo")
	if punto and is_instance_valid(punto):
		if "global_position" in punto:
			return punto.global_position
		elif "position" in punto:
			return punto.position
	return Vector2(960.0, 220.0)


## Crea o asegura la existencia de los nodos del marco y texto de la defensora por código
func _asegurar_marco_texto_defensora() -> void:
	if marco_texto_defensora and is_instance_valid(marco_texto_defensora) and texto_defensora and is_instance_valid(texto_defensora):
		return

	# Globo de diálogo generado 100% por código vectorial (sin imagen externa)
	var panel := PanelContainer.new()
	panel.name = "MarcoTextoDefensora"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false

	# Estilo premium del globo de diálogo (StyleBoxFlat)
	var estilo_globo := StyleBoxFlat.new()
	estilo_globo.bg_color = Color(0.11, 0.08, 0.16, 0.95)  # Fondo oscuro fantástico con transparencia
	estilo_globo.border_color = Color(0.95, 0.76, 0.35, 1.0)  # Borde dorado elegante
	estilo_globo.set_border_width_all(3)
	estilo_globo.set_corner_radius_all(18)
	estilo_globo.corner_detail = 8
	estilo_globo.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	estilo_globo.shadow_size = 10
	estilo_globo.shadow_offset = Vector2(0, 4)
	estilo_globo.content_margin_left = padding_defensora.x
	estilo_globo.content_margin_right = padding_defensora.x
	estilo_globo.content_margin_top = padding_defensora.y
	estilo_globo.content_margin_bottom = padding_defensora.y
	panel.add_theme_stylebox_override("panel", estilo_globo)

	var lbl := Label.new()
	lbl.name = "TextoDefensora"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.add_theme_font_size_override("font_size", 22)
	panel.add_child(lbl)

	add_child(panel)
	marco_texto_defensora = panel
	texto_defensora = lbl


## Muestra un diálogo a partir de un nodo PuntoNacimientoDialogo específico
func mostrar_dialogo_desde_punto(punto: PuntoNacimientoDialogo) -> Vector2:
	if not punto or not is_instance_valid(punto):
		return Vector2.ZERO

	# No reiniciar puntos ya dichos al entrar/salir de la torre
	if not punto.id_dialogo.is_empty() and dialogo_defensora_ya_dicho(punto.id_dialogo):
		return Vector2.ZERO

	_asegurar_marco_texto_defensora()
	if not marco_texto_defensora or not texto_defensora:
		return Vector2.ZERO

	if not punto.id_dialogo.is_empty():
		marcar_dialogo_defensora_dicho(punto.id_dialogo)

	# Aplicar colores y estilos configurados en este nodo específico
	var panel := marco_texto_defensora as PanelContainer
	if panel:
		var sb := panel.get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			sb.border_color = punto.color_borde
			sb.bg_color = punto.color_fondo

	if punto.tamano_fuente > 0:
		texto_defensora.add_theme_font_size_override("font_size", punto.tamano_fuente)

	min_ancho_marco_defensora = punto.ancho_minimo
	max_ancho_marco_defensora = punto.ancho_maximo
	velocidad_escritura_defensora = punto.velocidad_escritura

	return mostrar_texto_defensora(punto.texto, punto.duracion, true, punto.global_position)


## Muestra el texto de la defensora redimensionando automáticamente el marco a su contenido
func mostrar_texto_defensora(texto: String, duracion: float = 0.0, animar: bool = true, pos_override: Vector2 = Vector2.ZERO) -> Vector2:
	_asegurar_marco_texto_defensora()
	if not marco_texto_defensora or not texto_defensora:
		return Vector2.ZERO

	if _tween_marco_defensora and _tween_marco_defensora.is_valid():
		_tween_marco_defensora.kill()
	if _tween_texto_defensora and _tween_texto_defensora.is_valid():
		_tween_texto_defensora.kill()

	var estaba_oculto: bool = not marco_texto_defensora.visible or marco_texto_defensora.modulate.a <= 0.05
	var tamano_final: Vector2 = escalar_marco_a_texto(texto, pos_override)
	marco_texto_defensora.visible = true

	if animar:
		_tween_marco_defensora = marco_texto_defensora.create_tween().set_parallel(true)
		if estaba_oculto:
			# Animación de apertura y expansión orgánica del marco desde el punto de nacimiento
			marco_texto_defensora.modulate.a = 0.0
			marco_texto_defensora.scale = Vector2(0.2, 0.2)
			_tween_marco_defensora.tween_property(marco_texto_defensora, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_tween_marco_defensora.tween_property(marco_texto_defensora, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			# Rebote suave de actualización si ya estaba en pantalla
			_tween_marco_defensora.tween_property(marco_texto_defensora, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween_marco_defensora.chain().tween_property(marco_texto_defensora, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		# Animación de máquina de escribir (Typewriter)
		texto_defensora.visible_ratio = 0.0
		var tiempo_revelado: float = clampf(float(texto.length()) * velocidad_escritura_defensora, 0.25, 1.8)
		_tween_texto_defensora = texto_defensora.create_tween()
		_tween_texto_defensora.tween_property(texto_defensora, "visible_ratio", 1.0, tiempo_revelado).set_trans(Tween.TRANS_LINEAR)
	else:
		marco_texto_defensora.modulate.a = 1.0
		marco_texto_defensora.scale = Vector2.ONE
		texto_defensora.visible_ratio = 1.0

	if duracion > 0.0:
		get_tree().create_timer(duracion, false).timeout.connect(func() -> void:
			if is_instance_valid(self) and is_inside_tree():
				ocultar_texto_defensora(true)
		)

	return tamano_final


## Oculta el marco de texto de la defensora
func ocultar_texto_defensora(animar: bool = true) -> void:
	if not marco_texto_defensora or not marco_texto_defensora.visible:
		return

	if _tween_marco_defensora and _tween_marco_defensora.is_valid():
		_tween_marco_defensora.kill()
	if _tween_texto_defensora and _tween_texto_defensora.is_valid():
		_tween_texto_defensora.kill()

	if animar:
		_tween_marco_defensora = marco_texto_defensora.create_tween().set_parallel(true)
		_tween_marco_defensora.tween_property(marco_texto_defensora, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween_marco_defensora.tween_property(marco_texto_defensora, "scale", Vector2(0.8, 0.8), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween_marco_defensora.chain().tween_callback(func() -> void:
			if is_instance_valid(marco_texto_defensora):
				marco_texto_defensora.visible = false
				marco_texto_defensora.scale = Vector2.ONE
		)
	else:
		marco_texto_defensora.visible = false
		marco_texto_defensora.modulate.a = 1.0
		marco_texto_defensora.scale = Vector2.ONE


## Calcula y ajusta el tamaño del marco proporcionalmente a cualquier texto
func escalar_marco_a_texto(texto: String, pos_override: Vector2 = Vector2.ZERO) -> Vector2:
	_asegurar_marco_texto_defensora()
	if not marco_texto_defensora or not texto_defensora:
		return Vector2.ZERO

	texto_defensora.text = texto

	var font: Font = texto_defensora.get_theme_default_font()
	var font_size: int = texto_defensora.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 22

	# 1. Medir ancho de la línea más ancha
	var lineas: PackedStringArray = texto.split("\n")
	var max_ancho_linea: float = 0.0
	for linea in lineas:
		if font:
			var linea_size := font.get_string_size(linea, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			max_ancho_linea = maxf(max_ancho_linea, linea_size.x)
		else:
			max_ancho_linea = maxf(max_ancho_linea, float(linea.length()) * 13.0)

	# 2. Determinar ancho total deseado con márgenes
	var target_w: float = clampf(max_ancho_linea + padding_defensora.x * 2.0, min_ancho_marco_defensora, max_ancho_marco_defensora)
	var content_w: float = target_w - padding_defensora.x * 2.0

	# 3. Estimar altura con autowrap
	var total_lines_est: float = 0.0
	for linea in lineas:
		if font and content_w > 0.0:
			var w_single := font.get_string_size(linea, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			total_lines_est += maxf(1.0, ceilf(w_single / content_w))
		else:
			total_lines_est += 1.0

	var line_height: float = float(font_size) + 8.0
	var text_h: float = total_lines_est * line_height
	var target_h: float = maxf(min_alto_marco_defensora, text_h + padding_defensora.y * 2.0)

	var nuevo_tamano := Vector2(target_w, target_h)

	# 4. Asignar tamaño al marco y centrarlo en la posición de nacimiento
	var pos_nacimiento: Vector2 = pos_override if pos_override != Vector2.ZERO else _obtener_posicion_nacimiento_dialogo()
	marco_texto_defensora.size = nuevo_tamano
	marco_texto_defensora.custom_minimum_size = nuevo_tamano
	marco_texto_defensora.pivot_offset = nuevo_tamano * 0.5
	marco_texto_defensora.global_position = pos_nacimiento - nuevo_tamano * 0.5

	return nuevo_tamano


## Permite posicionar el marco en coordenadas específicas de pantalla
func posicionar_marco_defensora(pos_pantalla: Vector2) -> void:
	_asegurar_marco_texto_defensora()
	if not marco_texto_defensora:
		return
	marco_texto_defensora.global_position = pos_pantalla - marco_texto_defensora.size * 0.5
