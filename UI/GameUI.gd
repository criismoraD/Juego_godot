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
var btn_spawn_escudo: Button
var btn_spawn_posion: Button
var btn_spawn_flecha_explosiva: Button
var flecha_explosiva_scene_debug: PackedScene = preload("res://Entities/Item_Flecha_Explosiva/PowerUpFlechaExplosiva.tscn")
var vignette_rect: ColorRect = null
var _vignette_tween: Tween = null
const TEXTURA_ICONO_PUERTA: Texture2D = preload("res://TEST_/Icono puerta.png")
var _icono_puerta: TextureRect = null
var _tween_icono_puerta: Tween = null
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
var Indice_Calidad_Actual: int = 0
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
	_Aplicar_Calidad(0)
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

	# Fila de Navegación de Nivees (Debug)
	var hbox_nav_debug = HBoxContainer.new()
	hbox_nav_debug.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_nav_debug.add_theme_constant_override("separation", 10)
	hbox_nav_debug.visible = debug_ui_enabled
	vbox.add_child(hbox_nav_debug)

	var lvl6_btn = Button.new()
	lvl6_btn.text = "🏆 Ir al Nivel 6"
	lvl6_btn.custom_minimum_size = Vector2(170, 40)
	lvl6_btn.pressed.connect(
		func():
			if is_paused:
				is_paused = false
				get_tree().paused = false
			AudioManager.stop_all()
			get_tree().change_scene_to_file("res://Levels/NIVEL06_ASALTO/NIVEL06_ASALTO.tscn")
	)
	_style_button(lvl6_btn, Color(0.6, 0.4, 0.1))
	hbox_nav_debug.add_child(lvl6_btn)

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
			get_tree().change_scene_to_file("res://Levels/NIVEL01/NIVEL01.tscn")
	)
	_style_button(debug_btn, Color(0.4, 0.4, 0.4))
	hbox_nav_debug.add_child(debug_btn)

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

	if numero_oleada == 5:
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


func _on_oleada_iniciada_reconstruir_escudos(num_oleada: int) -> void:
	# Desde la oleada 5 los elementos del nivel 3 (incluido el escudo enemigo)
	# permanecen ocultos por diseño: NO reconstruir escudos enemigos ahí.
	_reconstruir_todos_escudos(num_oleada >= 5)
	# El icono puerta desaparece al empezar cualquier oleada
	_ocultar_icono_puerta()


## Icono puerta pulsante (latido lento) sobre la puerta de la torre, visible
## mientras la cortinilla de fin de oleada está activa.
func _mostrar_icono_puerta(overlay: CanvasLayer = null) -> void:
	_ocultar_icono_puerta()

	# 1. Buscar si ya existe el nodo en la escena UI (colocado manualmente en el editor de escenas)
	_icono_puerta = get_node_or_null("%IconoPuerta") as TextureRect
	if not _icono_puerta:
		_icono_puerta = find_child("IconoPuerta", true, false) as TextureRect

	if _icono_puerta:
		_icono_puerta.visible = true
		if overlay and _icono_puerta.get_parent() != overlay:
			_icono_puerta.top_level = true
	else:
		# Fallback dinámico si no existiera en la escena
		_icono_puerta = TextureRect.new()
		_icono_puerta.texture = TEXTURA_ICONO_PUERTA
		_icono_puerta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icono_puerta.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icono_puerta.anchor_left = 0.0
		_icono_puerta.anchor_right = 0.0
		_icono_puerta.anchor_top = 0.0
		_icono_puerta.anchor_bottom = 0.0
		var icon_size := Vector2(110.0, 110.0)
		var center_pos := Vector2(300.0, 815.0)
		var root_scene := get_tree().current_scene
		if root_scene:
			var torre := root_scene.find_child("TORRE", true, false) as Node3D
			var cam: Camera3D = get_viewport().get_camera_3d()
			if not cam:
				cam = root_scene.find_child("PRESPECTIVA", true, false) as Camera3D
			if not cam:
				cam = root_scene.find_child("CamaraFondoDOF", true, false) as Camera3D
			if torre and cam and cam.is_inside_tree():
				var door_local := Vector3(0.0, 0.15, 0.35)
				var door_world: Vector3 = torre.to_global(door_local)
				if not cam.is_position_behind(door_world):
					var sp: Vector2 = cam.unproject_position(door_world)
					var vp_size: Vector2 = get_viewport().get_visible_rect().size
					if vp_size.x > 0 and vp_size.y > 0:
						sp.x = clamp(sp.x, icon_size.x * 0.5, vp_size.x - icon_size.x * 0.5)
						sp.y = clamp(sp.y, icon_size.y * 0.5, vp_size.y - icon_size.y * 0.5)
						center_pos = sp
		_icono_puerta.offset_left = center_pos.x - icon_size.x * 0.5
		_icono_puerta.offset_top = center_pos.y - icon_size.y * 0.5
		_icono_puerta.offset_right = center_pos.x + icon_size.x * 0.5
		_icono_puerta.offset_bottom = center_pos.y + icon_size.y * 0.5
		_icono_puerta.pivot_offset = icon_size * 0.5
		if overlay:
			overlay.add_child(_icono_puerta)
		else:
			add_child(_icono_puerta)

	# Palpitar lento: latido de 1.2 s (crece y vuelve)
	if _icono_puerta:
		_icono_puerta.scale = Vector2.ONE
		_tween_icono_puerta = _icono_puerta.create_tween().set_loops()
		_tween_icono_puerta.tween_property(_icono_puerta, "scale", Vector2(1.12, 1.12), 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween_icono_puerta.tween_property(_icono_puerta, "scale", Vector2.ONE, 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Oculta el icono puerta y detiene su palpito (al empezar una oleada).
func _ocultar_icono_puerta() -> void:
	if _tween_icono_puerta and _tween_icono_puerta.is_valid():
		_tween_icono_puerta.kill()
	_tween_icono_puerta = null
	if _icono_puerta and is_instance_valid(_icono_puerta):
		_icono_puerta.scale = Vector2.ONE
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
			_escudos_cache.append(escudo)
			escudos_originales.append(
				{
					"scene_path": escudo.scene_file_path,
					"name": escudo.name,
					"transform": escudo.global_transform,
					"parent_path": escudo.get_parent().get_path()
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


func _reconstruir_todos_escudos(omitir_enemigos: bool = false):
	"""Re-instancia ÚNICAMENTE los escudos que han sido destruidos/rotos.
	omitir_enemigos=true (oleada 5+): los escudos enemigos permanecen eliminados."""
	# 1. Eliminar restos de escudos rotos que queden en escena
	var escudos_rotos = get_tree().get_nodes_in_group("escudos_rotos")
	for roto in escudos_rotos:
		if is_instance_valid(roto):
			if roto.scene_file_path.contains("Imp"):
				continue
			roto.queue_free()

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

		# Si el escudo falta (fue destruido), recrear SOLO este escudo roto
		var nuevo_escudo: Node = null
		var scene_path: String = data.get("scene_path", "")
		if scene_path != "":
			var res = load(scene_path)
			if res is PackedScene:
				nuevo_escudo = res.instantiate()

		if nuevo_escudo == null:
			nuevo_escudo = escudo_scene.instantiate()

		# Oleada 5+: los escudos enemigos permanecen eliminados
		if omitir_enemigos and nuevo_escudo.get("es_escudo_enemigo") == true:
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

	# Guardar la escala objetivo original
	var target_scale: Vector3 = Vector3.ONE
	if escudo is Node3D:
		target_scale = (escudo as Node3D).scale
		if target_scale.is_zero_approx():
			target_scale = Vector3.ONE

	# Iniciar el escudo aplanado en la base (escala Y casi cero)
	if escudo is Node3D:
		(escudo as Node3D).scale = Vector3(target_scale.x * 0.4, 0.01, target_scale.z * 0.4)

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

	# 2. Crecimiento/Escalado vertical desde la base hacia arriba
	if escudo is Node3D:
		tween.tween_property(escudo, "scale", target_scale, duracion) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.finished.connect(
		func() -> void:
			for item in dissolve_mats:
				if is_instance_valid(item["mesh"]):
					item["mesh"].material_override = item["original"]
			if is_instance_valid(escudo) and escudo is Node3D:
				(escudo as Node3D).scale = target_scale
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
			(screen_size.x - actual_size.x) / 2, (screen_size.y - actual_size.y) / 2
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
					(screen_size.x - actual_size.x) / 2, (screen_size.y - actual_size.y) / 2
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
	"""Toggle ON/OFF de todas las arqueras aliadas"""
	allies_enabled = not allies_enabled
	for ally in AllyArcher.active_allies_cache:
		if ally is AllyArcher:
			_aplicar_estado_aliada(ally)

	if is_instance_valid(btn_toggle_allies):
		if allies_enabled:
			btn_toggle_allies.text = "🏹 ALIADAS: ON"
			_style_button(btn_toggle_allies, Color(0.3, 0.6, 0.5))
		else:
			btn_toggle_allies.text = "🏹 ALIADAS: OFF"
			_style_button(btn_toggle_allies, Color(0.4, 0.4, 0.4))


func _guardar_plantillas_aliadas():
	"""Guarda una plantilla de cada aliada inicial para poder revivirla por debug."""
	plantillas_aliadas.clear()
	for ally in AllyArcher.active_allies_cache:
		if not (ally is AllyArcher):
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


func _buscar_aliada_por_nombre(nombre_aliada: String) -> AllyArcher:
	for ally in AllyArcher.active_allies_cache:
		if ally is AllyArcher and ally.name == nombre_aliada:
			return ally
	return null


func _aplicar_estado_aliada(ally: AllyArcher):
	if not ally or not is_instance_valid(ally):
		return
	ally.visible = allies_enabled
	ally.set_process(allies_enabled)
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
		if ally is AllyArcher and ally.current_state != AllyArcher.State.DEAD and ally.current_state != AllyArcher.State.DYING:
			ally.recibir_dano(9999)


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

	# Colocar en el centro del mapa en X, a altura del jugador si está disponible
	var spawn_y: float = 1.0
	if player and "global_position" in player:
		spawn_y = player.global_position.y

	scene_root.add_child(posion)
	posion.global_position = Vector3(0.0, spawn_y, 0.0)


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

	var spawn_y: float = 1.0
	if player and "global_position" in player:
		spawn_y = player.global_position.y

	scene_root.add_child(item)
	item.global_position = Vector3(0.0, spawn_y, 0.0)


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
