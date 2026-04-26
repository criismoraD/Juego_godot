extends CanvasLayer
## UI del Juego - Separada del Player
## Contiene: Vida, God Mode, Reiniciar, BGM, Volumen, Pausa, Toggle Bordes

# === REFERENCIAS ===
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
var btn_spawn_escudo: Button

# === TOGGLE UI ===
var bottom_panel: Control
var toggle_ui_btn: Button

# === ESTADO ===
var outlines_enabled: bool = true
var is_paused: bool = false
var effects_enabled: bool = true # Fog y DOF habilitados por defecto
var shields_enabled: bool = true
var allies_enabled: bool = true

# === OPTIMIZACIÓN ===
var _wave_update_timer: float = 0.0
const WAVE_UPDATE_INTERVAL: float = 0.25 # Actualizar progreso de oleada 4 veces por segundo en vez de cada frame

# === ESCUDOS ===
var escudo_scene: PackedScene = preload("res://Scenes/Environment/Escudo.tscn")
var escudos_originales: Array = [] # [{transform, parent_path}]
var _escudos_cache: Array[Node] = []
var btn_toggle_shields: Button
var btn_toggle_allies: Button
var btn_revive_allies: Button
var plantillas_aliadas: Array = [] # [{name, parent_path, global_transform, template}]

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
const RUTA_SHADER_OUTLINE := "res://Assets/Shaders/TOON_LINEANEGRA.gdshader"
const SHADER_OUTLINE := preload(RUTA_SHADER_OUTLINE)
const PARAMETRO_OUTLINE_GLOBAL := "Toon_LineaNegra_Activo"
const OUTLINE_WIDTH_RUNTIME := 20.0

func _ready():
	layer = 100
	outlines_enabled = true

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
		preload("res://Assets/Characters/Player/ARQUERA_MATERIAL.tres"),
		preload("res://Assets/Projectiles/Arrow/Arrows.tres"),
		preload("res://Assets/Environment/Ladder/ESCALERAS.tres"),
		preload("res://Assets/Projectiles/GoblinCrossbow/Hand Crossbow.tres"),
		preload("res://Assets/Characters/Goblin/GOBLING_MATERIAL.tres"),
		preload("res://Assets/Characters/GoblinGirl/MAT_GOBLIN_GIRL.tres"),
		preload("res://Assets/Environment/Platform/MAT_platform.tres"),
		preload("res://Assets/Environment/Shield/MAT_shield.tres"),
		preload("res://Assets/Environment/SpikeTrap/MAT_spike_trap.tres"),
		preload("res://Assets/Weapons/PlayerBow/Recurve Bow 2.tres")
	]

	for mat in materials:
		if mat and mat.next_pass:
			materials_with_outline.append({
				"material": mat,
				"outline": mat.next_pass
			})

func _create_ui():
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
	# BOTÓN TOGGLE UI (ESQUINA SUPERIOR DERECHA)
	# ═══════════════════════════════════════════════════════════════════════════
	toggle_ui_btn = Button.new()
	toggle_ui_btn.name = "ToggleUIBtn"
	toggle_ui_btn.text = "🔽 UI"
	toggle_ui_btn.custom_minimum_size = Vector2(60, 28)
	toggle_ui_btn.anchor_left = 1.0
	toggle_ui_btn.anchor_right = 1.0
	toggle_ui_btn.offset_left = -70
	toggle_ui_btn.offset_right = -10
	toggle_ui_btn.offset_top = 10
	toggle_ui_btn.offset_bottom = 38
	toggle_ui_btn.pressed.connect(_toggle_bottom_panel)
	_style_button(toggle_ui_btn, Color(0.3, 0.3, 0.4))
	add_child(toggle_ui_btn)

	# ═══════════════════════════════════════════════════════════════════════════
	# PANEL INFERIOR - CONTROLES (2 FILAS)
	# ═══════════════════════════════════════════════════════════════════════════
	bottom_panel = Control.new()
	bottom_panel.name = "BottomPanel"
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_top = -100
	bottom_panel.offset_bottom = -5
	add_child(bottom_panel)

	var vbox_rows = VBoxContainer.new()
	vbox_rows.name = "RowsContainer"
	vbox_rows.add_theme_constant_override("separation", 4)
	vbox_rows.set_anchors_preset(Control.PRESET_CENTER)
	vbox_rows.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox_rows.grow_vertical = Control.GROW_DIRECTION_BOTH
	bottom_panel.add_child(vbox_rows)

	# ═══════════════ FILA 1: Controles principales ═══════════════
	var hbox = HBoxContainer.new()
	hbox.name = "Row1"
	hbox.add_theme_constant_override("separation", 6)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_rows.add_child(hbox)

	# --- PAUSA ---
	pause_btn = Button.new()
	pause_btn.text = "⏸️ PAUSA"
	pause_btn.custom_minimum_size = Vector2(85, 32)
	pause_btn.pressed.connect(_toggle_pause)
	_style_button(pause_btn, Color(0.5, 0.3, 0.6))
	hbox.add_child(pause_btn)

	# --- GOD MODE ---
	god_mode_btn = Button.new()
	god_mode_btn.text = "GOD: OFF"
	god_mode_btn.custom_minimum_size = Vector2(80, 32)
	god_mode_btn.pressed.connect(_toggle_god_mode)
	_style_button(god_mode_btn, Color(0.2, 0.4, 0.8))
	hbox.add_child(god_mode_btn)

	# Actualizar estado inicial
	if player and player.get("modo_dios"):
		god_mode_btn.text = "GOD: ON"
		_style_button(god_mode_btn, Color(0.8, 0.6, 0.1))

	# --- REINICIAR ---
	restart_btn = Button.new()
	restart_btn.text = "🔄 REINICIAR"
	restart_btn.custom_minimum_size = Vector2(95, 32)
	restart_btn.pressed.connect(_restart_game)
	_style_button(restart_btn, Color(0.7, 0.2, 0.2))
	hbox.add_child(restart_btn)

	# --- SALIR ---
	quit_btn = Button.new()
	quit_btn.text = "❌ SALIR"
	quit_btn.custom_minimum_size = Vector2(75, 32)
	quit_btn.pressed.connect(_quit_game)
	_style_button(quit_btn, Color(0.8, 0.2, 0.2))
	hbox.add_child(quit_btn)

	# --- SEPARADOR ---
	var sep1 = VSeparator.new()
	sep1.custom_minimum_size.x = 8
	hbox.add_child(sep1)

	# --- BGM SELECTOR ---
	var bgm_label = Label.new()
	bgm_label.text = "BGM:"
	hbox.add_child(bgm_label)

	var btn_m1 = Button.new()
	btn_m1.text = "1"
	btn_m1.custom_minimum_size = Vector2(28, 32)
	btn_m1.pressed.connect(func(): _play_music(1))
	_style_button(btn_m1, Color(0.3, 0.5, 0.3))
	hbox.add_child(btn_m1)

	var btn_m2 = Button.new()
	btn_m2.text = "2"
	btn_m2.custom_minimum_size = Vector2(28, 32)
	btn_m2.pressed.connect(func(): _play_music(2))
	_style_button(btn_m2, Color(0.3, 0.5, 0.3))
	hbox.add_child(btn_m2)

	var btn_mute = Button.new()
	btn_mute.text = "🔇"
	btn_mute.custom_minimum_size = Vector2(28, 32)
	btn_mute.pressed.connect(func(): _play_music(0))
	_style_button(btn_mute, Color(0.2, 0.2, 0.2))
	hbox.add_child(btn_mute)

	# --- SEPARADOR ---
	var sep2 = VSeparator.new()
	sep2.custom_minimum_size.x = 8
	hbox.add_child(sep2)

	# --- VOLUMEN BGM ---
	var vol_bgm_label = Label.new()
	vol_bgm_label.text = "🎵"
	hbox.add_child(vol_bgm_label)

	bgm_slider = HSlider.new()
	bgm_slider.min_value = 0
	bgm_slider.max_value = 100
	bgm_slider.value = 50
	bgm_slider.custom_minimum_size = Vector2(55, 20)
	bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	hbox.add_child(bgm_slider)

	# --- VOLUMEN SFX ---
	var vol_sfx_label = Label.new()
	vol_sfx_label.text = "🔊"
	hbox.add_child(vol_sfx_label)

	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0
	sfx_slider.max_value = 100
	sfx_slider.value = 70
	sfx_slider.custom_minimum_size = Vector2(55, 20)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	hbox.add_child(sfx_slider)

	# --- SEPARADOR ---
	var sep3 = VSeparator.new()
	sep3.custom_minimum_size.x = 8
	hbox.add_child(sep3)

	# --- BOTONES DE CONTROL DE SPAWN ---
	btn_iguales = Button.new()
	btn_iguales.text = "⚖️ IGUALES"
	btn_iguales.custom_minimum_size = Vector2(80, 32)
	btn_iguales.pressed.connect(_toggle_equal_spawn)
	_style_button(btn_iguales, Color(0.4, 0.4, 0.5))
	hbox.add_child(btn_iguales)

	btn_solo_imp = Button.new()
	btn_solo_imp.text = "👹 IMP"
	btn_solo_imp.custom_minimum_size = Vector2(60, 32)
	btn_solo_imp.pressed.connect(func(): _set_spawn_type(2))
	_style_button(btn_solo_imp, Color(0.4, 0.4, 0.5))
	hbox.add_child(btn_solo_imp)

	btn_solo_goblin = Button.new()
	btn_solo_goblin.text = "🧟 GOBLIN"
	btn_solo_goblin.custom_minimum_size = Vector2(75, 32)
	btn_solo_goblin.pressed.connect(func(): _set_spawn_type(0))
	_style_button(btn_solo_goblin, Color(0.4, 0.4, 0.5))
	hbox.add_child(btn_solo_goblin)

	btn_solo_ggirl = Button.new()
	btn_solo_ggirl.text = "🧝 G.GIRL"
	btn_solo_ggirl.custom_minimum_size = Vector2(75, 32)
	btn_solo_ggirl.pressed.connect(func(): _set_spawn_type(1))
	_style_button(btn_solo_ggirl, Color(0.4, 0.4, 0.5))
	hbox.add_child(btn_solo_ggirl)

	# --- FORZAR SPAWN ESCUDO ---
	btn_spawn_escudo = Button.new()
	btn_spawn_escudo.text = "\U0001F6E1\uFE0F ESCUDO"
	btn_spawn_escudo.custom_minimum_size = Vector2(85, 32)
	btn_spawn_escudo.pressed.connect(func():
		if wave_spawner and wave_spawner.has_method("forzar_spawn_escudo"):
			wave_spawner.forzar_spawn_escudo()
	)
	_style_button(btn_spawn_escudo, Color(0.5, 0.3, 0.6))
	hbox.add_child(btn_spawn_escudo)

	# Sincronizar estado inicial
	_update_spawn_buttons()

	# ═══════════════ FILA 2: Escudos, Aliadas, Toggles ═══════════════
	var hbox2 = HBoxContainer.new()
	hbox2.name = "Row2"
	hbox2.add_theme_constant_override("separation", 6)
	hbox2.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_rows.add_child(hbox2)

	# --- DESTRUIR ESCUDOS ---
	var btn_destroy_shields = Button.new()
	btn_destroy_shields.text = "💥 DESTRUIR ESCUDOS"
	btn_destroy_shields.custom_minimum_size = Vector2(135, 32)
	btn_destroy_shields.pressed.connect(_destruir_todos_escudos)
	_style_button(btn_destroy_shields, Color(0.7, 0.2, 0.2))
	hbox2.add_child(btn_destroy_shields)

	# --- RECONSTRUIR ESCUDOS ---
	var btn_rebuild_shields = Button.new()
	btn_rebuild_shields.text = "🛡️ RECONSTRUIR ESCUDOS"
	btn_rebuild_shields.custom_minimum_size = Vector2(155, 32)
	btn_rebuild_shields.pressed.connect(_reconstruir_todos_escudos)
	_style_button(btn_rebuild_shields, Color(0.3, 0.6, 0.3))
	hbox2.add_child(btn_rebuild_shields)

	# --- SEPARADOR ---
	var sep_toggles = VSeparator.new()
	sep_toggles.custom_minimum_size.x = 8
	hbox2.add_child(sep_toggles)

	# --- TOGGLE OUTLINE GLOBAL ---
	outline_btn = Button.new()
	outline_btn.text = "✏️ BORDES: GLOBAL ON"
	outline_btn.custom_minimum_size = Vector2(170, 32)
	outline_btn.disabled = false
	outline_btn.tooltip_text = "Activar/Desactivar contorno global"
	outline_btn.pressed.connect(_toggle_outlines)
	_style_button(outline_btn, Color(0.1, 0.6, 0.5))
	hbox2.add_child(outline_btn)

	# --- TOGGLE ESCUDOS ---
	btn_toggle_shields = Button.new()
	btn_toggle_shields.text = "🛡️ ESCUDOS: ON"
	btn_toggle_shields.custom_minimum_size = Vector2(115, 32)
	btn_toggle_shields.pressed.connect(_toggle_escudos)
	_style_button(btn_toggle_shields, Color(0.3, 0.5, 0.6))
	hbox2.add_child(btn_toggle_shields)

	# --- TOGGLE ALIADAS ---
	btn_toggle_allies = Button.new()
	btn_toggle_allies.text = "🏹 ALIADAS: ON"
	btn_toggle_allies.custom_minimum_size = Vector2(115, 32)
	btn_toggle_allies.pressed.connect(_toggle_aliadas)
	_style_button(btn_toggle_allies, Color(0.3, 0.6, 0.5))
	hbox2.add_child(btn_toggle_allies)

	# --- REVIVIR ALIADAS ---
	btn_revive_allies = Button.new()
	btn_revive_allies.text = "💚 REVIVIR ALIADAS"
	btn_revive_allies.custom_minimum_size = Vector2(145, 32)
	btn_revive_allies.pressed.connect(_revivir_aliadas)
	_style_button(btn_revive_allies, Color(0.2, 0.55, 0.35))
	hbox2.add_child(btn_revive_allies)

	# --- SEPARADOR ---
	var sep_blood = VSeparator.new()
	sep_blood.custom_minimum_size.x = 8
	hbox2.add_child(sep_blood)

	# --- TOGGLE SANGRE IMP ---
	var btn_blood_toggle = Button.new()
	btn_blood_toggle.name = "BloodToggleBtn"
	btn_blood_toggle.text = "🩸 SANGRE: MORADA"
	btn_blood_toggle.custom_minimum_size = Vector2(130, 32)
	btn_blood_toggle.pressed.connect(_toggle_imp_blood_color)
	_style_button(btn_blood_toggle, Color(0.4, 0.1, 0.5))
	hbox2.add_child(btn_blood_toggle)

	# --- OPACIDAD CAPA001 (FogPlane) ---
	var sep_capa = VSeparator.new()
	sep_capa.custom_minimum_size.x = 8
	hbox2.add_child(sep_capa)

	var lbl_capa = Label.new()
	lbl_capa.text = "CAPA001 α:"
	hbox2.add_child(lbl_capa)

	capa001_opacity_slider = HSlider.new()
	capa001_opacity_slider.min_value = 0.0
	capa001_opacity_slider.max_value = 1.0
	capa001_opacity_slider.step = 0.01
	capa001_opacity_slider.custom_minimum_size = Vector2(90, 20)
	capa001_opacity_slider.value = _obtener_opacidad_capa001_actual()
	capa001_opacity_slider.value_changed.connect(_on_capa001_opacity_changed)
	hbox2.add_child(capa001_opacity_slider)

	capa001_opacity_value_label = Label.new()
	capa001_opacity_value_label.text = "%.2f" % capa001_opacity_slider.value
	hbox2.add_child(capa001_opacity_value_label)

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
	restart_pause_btn.pressed.connect(func():
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
	vbox.add_child(sep_lvl)

	# ═══════════════ SELECTOR DE OLEADAS (DEBUG) ═══════════════
	var lvl_label = Label.new()
	lvl_label.text = "⚔️ CAMBIAR OLEADA (DEBUG)"
	lvl_label.add_theme_font_size_override("font_size", 22)
	lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lvl_label)

	var hbox_levels = HBoxContainer.new()
	hbox_levels.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_levels.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox_levels)

	var btn_oleada_1 = Button.new()
	btn_oleada_1.text = "Oleada 1"
	btn_oleada_1.custom_minimum_size = Vector2(110, 40)
	btn_oleada_1.pressed.connect(func():
		_toggle_pause()
		_ejecutar_cambio_oleada_debug(1)
	)
	_style_button(btn_oleada_1, Color(0.1, 0.4, 0.6))
	hbox_levels.add_child(btn_oleada_1)

	var btn_oleada_2 = Button.new()
	btn_oleada_2.text = "Oleada 2"
	btn_oleada_2.custom_minimum_size = Vector2(110, 40)
	btn_oleada_2.pressed.connect(func():
		_toggle_pause()
		_ejecutar_cambio_oleada_debug(2)
	)
	_style_button(btn_oleada_2, Color(0.6, 0.2, 0.4))
	hbox_levels.add_child(btn_oleada_2)

	var btn_carteles = Button.new()
	btn_carteles.text = "Carteles"
	btn_carteles.custom_minimum_size = Vector2(110, 40)
	btn_carteles.pressed.connect(func():
		_toggle_pause()
		_ejecutar_carteles_debug()
	)
	_style_button(btn_carteles, Color(0.45, 0.35, 0.1))
	hbox_levels.add_child(btn_carteles)

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
	fullscreen_check.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	fullscreen_check.custom_minimum_size = Vector2(200, 40)
	fullscreen_check.focus_mode = Control.FOCUS_NONE
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(fullscreen_check)

	add_child(pause_panel)

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIONES DE UI
# ═══════════════════════════════════════════════════════════════════════════════

func _update_health_ui():
	# Limpiar corazones existentes
	for icon in heart_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	heart_icons.clear()

	if not player:
		return

	var max_hp = player.get("vida_maxima") if player.get("vida_maxima") else 5
	var current_hp = player.get("health") if player.get("health") else max_hp

	# Crear nuevos corazones
	for i in range(max_hp):
		var heart = Label.new()
		heart.add_theme_font_size_override("font_size", 24)
		if i < current_hp:
			heart.text = "❤️"
			heart.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
		else:
			heart.text = "🖤"
			heart.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		health_container.add_child(heart)
		heart_icons.append(heart)

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
		var active_goblins: Array = wave_spawner.active_goblins
		var vivos := 0
		# OPT: Iteración inversa in-place — limpiar refs inválidas y contar vivos en un solo pass
		for i in range(active_goblins.size() - 1, -1, -1):
			var e = active_goblins[i]
			if is_instance_valid(e) and not (e.get("current_state") in [5, 6]): # 5=DYING, 6=DEAD
				vivos += 1
			else:
				active_goblins.remove_at(i)

		var total = wave_spawner.get("enemigos_por_oleada")
		var spawneados = wave_spawner.get("goblins_spawned_in_wave")
		if total != null and spawneados != null:
			var faltan_por_spawnear = max(0, total - spawneados)
			var restantes = faltan_por_spawnear + vivos

			wave_progress.max_value = total
			wave_progress.value = max(0, total - restantes)
			wave_progress_label.text = "ENEMIGOS RESTANTES: %d / %d" % [restantes, total]
			wave_container.visible = true
	else:
		if wave_container:
			wave_container.visible = false

func _on_player_died():
	# Mostrar todos los corazones vacíos
	for icon in heart_icons:
		if is_instance_valid(icon):
			icon.text = "🖤"
			icon.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))

func _ejecutar_cambio_oleada_debug(numero_oleada: int) -> void:
	var root_node = _get_scene_root()
	if not is_instance_valid(root_node):
		return

	if numero_oleada == 2:
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
	bottom_panel.visible = not bottom_panel.visible
	if bottom_panel.visible:
		toggle_ui_btn.text = "🔽 UI"
	else:
		toggle_ui_btn.text = "🔼 UI"

func _toggle_pause():
	is_paused = not is_paused
	get_tree().paused = is_paused
	pause_panel.visible = is_paused

	if is_paused:
		pause_btn.text = "▶️ PLAY"
		_style_button(pause_btn, Color(0.2, 0.6, 0.3))
	else:
		pause_btn.text = "⏸️ PAUSA"
		_style_button(pause_btn, Color(0.5, 0.3, 0.6))

func _toggle_god_mode():
	if not player:
		return

	player.modo_dios = not player.modo_dios

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
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()

	# Eliminar proyectiles enemigos
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
	if wave_spawner:
		return wave_spawner

	# Fallback: Buscar por nombre en la raíz de la escena
	var root = get_tree().current_scene
	if root:
		wave_spawner = root.find_child("WaveSpawner", true, false)

	return wave_spawner

func _toggle_equal_spawn():
	var spawner = _find_wave_spawner()
	if not spawner:
		push_warning("[GameUI] No se encontró WaveSpawner")
		return
	spawner.probabilidad_igual = not spawner.probabilidad_igual
	spawner.forzar_tipo_enemigo = -1 # Desactivar forzado
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
	var spawner = _find_wave_spawner()
	var igual_on = spawner and spawner.probabilidad_igual
	var tipo = spawner.forzar_tipo_enemigo if spawner else -1

	# Botón IGUALES
	if igual_on:
		btn_iguales.text = "⚖️ IGUALES: ON"
		_style_button(btn_iguales, Color(0.2, 0.7, 0.3))
	else:
		btn_iguales.text = "⚖️ IGUALES"
		_style_button(btn_iguales, Color(0.4, 0.4, 0.5))

	# Botón IMP
	if tipo == 2:
		btn_solo_imp.text = "👹 IMP ✓"
		_style_button(btn_solo_imp, Color(0.7, 0.2, 0.2))
	else:
		btn_solo_imp.text = "👹 IMP"
		_style_button(btn_solo_imp, Color(0.4, 0.4, 0.5))

	# Botón GOBLIN
	if tipo == 0:
		btn_solo_goblin.text = "🧟 GOBLIN ✓"
		_style_button(btn_solo_goblin, Color(0.3, 0.6, 0.2))
	else:
		btn_solo_goblin.text = "🧟 GOBLIN"
		_style_button(btn_solo_goblin, Color(0.4, 0.4, 0.5))

	# Botón G.GIRL
	if tipo == 1:
		btn_solo_ggirl.text = "🧝 G.GIRL ✓"
		_style_button(btn_solo_ggirl, Color(0.6, 0.2, 0.6))
	else:
		btn_solo_ggirl.text = "🧝 G.GIRL"
		_style_button(btn_solo_ggirl, Color(0.4, 0.4, 0.5))

func _toggle_outlines():
	outlines_enabled = not outlines_enabled
	_aplicar_toggle_outline_global()

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
	RenderingServer.global_shader_parameter_set(PARAMETRO_OUTLINE_GLOBAL, habilitado)

	if SHADER_OUTLINE == null:
		push_warning("[GameUI] No se pudo cargar SHADER_OUTLINE (TOON_LINEANEGRA.gdshader).")
		return

	var shader_outline := SHADER_OUTLINE

	for item in materials_with_outline:
		if not item is Dictionary:
			continue
		var material_base = item.get("material")
		if material_base is StandardMaterial3D:
			_aplicar_shader_outline_en_material(material_base as StandardMaterial3D, shader_outline, habilitado)

	var meshes = get_tree().get_nodes_in_group("outline_meshes")
	for nodo in meshes:
		var mesh_instance := nodo as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue

		for i in range(mesh_instance.mesh.get_surface_count()):
			var material_activo := mesh_instance.get_active_material(i)
			if material_activo is StandardMaterial3D:
				_aplicar_shader_outline_en_material(material_activo as StandardMaterial3D, shader_outline, habilitado)

func _aplicar_shader_outline_en_material(material_base: StandardMaterial3D, shader_outline: Shader, habilitado: bool) -> void:
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
		if AudioManager.sfx_streams["shield_hit"] == AudioManager.sfx_streams.get("shield_hit_crossbow"):
			AudioManager.sfx_streams["shield_hit"] = AudioManager.sfx_streams.get("shield_hit_arrow", [])
			var btn = find_child("ShieldSfxBtn", true, false)
			if btn:
				btn.text = "🛡️ ESCUDO: B"
				_style_button(btn, Color(0.5, 0.6, 0.4))
		else:
			AudioManager.sfx_streams["shield_hit"] = AudioManager.sfx_streams.get("shield_hit_crossbow", [])
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
	"""Limpia el cache de nodos inválidos y retorna la lista actualizada"""
	for i in range(_escudos_cache.size() - 1, -1, -1):
		if not is_instance_valid(_escudos_cache[i]):
			_escudos_cache.remove_at(i)
	return _escudos_cache

func _guardar_posiciones_escudos():
	"""Guarda las posiciones originales de todos los escudos al inicio"""
	await get_tree().process_frame
	_escudos_cache.clear()
	for escudo in get_tree().get_nodes_in_group("escudos"):
		if is_instance_valid(escudo):
			_escudos_cache.append(escudo)
			escudos_originales.append({
				"transform": escudo.global_transform,
				"parent_path": escudo.get_parent().get_path()
			})

func _destruir_todos_escudos():
	"""Destruye todos los escudos activos con efecto visual"""
	var escudos = _get_valid_escudos()
	for escudo in escudos:
		if is_instance_valid(escudo) and escudo.has_method("recibir_golpe"):
			# Forzar destrucción inmediata: poner golpes al máximo y dar golpe final
			escudo.golpes_recibidos = escudo.golpes_para_destruir - 1
			escudo.recibir_golpe()

func _reconstruir_todos_escudos():
	"""Re-instancia los escudos en sus posiciones originales"""
	# Primero eliminar cualquier escudo roto que quede
	for roto in get_tree().get_nodes_in_group("escudos_rotos"):
		if is_instance_valid(roto):
			roto.queue_free()

	# Eliminar escudos existentes (por si quedan)
	var escudos = _get_valid_escudos()
	for escudo in escudos:
		if is_instance_valid(escudo):
			escudo.queue_free()
	_escudos_cache.clear()

	# Recrear en las posiciones originales
	for data in escudos_originales:
		var nuevo_escudo = escudo_scene.instantiate()
		var parent = get_node_or_null(data["parent_path"])
		if parent and is_instance_valid(parent):
			parent.add_child(nuevo_escudo)
		else:
			get_tree().current_scene.add_child(nuevo_escudo)
		nuevo_escudo.global_transform = data["transform"]
		_escudos_cache.append(nuevo_escudo)

	# Actualizar estado del toggle
	shields_enabled = true
	if btn_toggle_shields:
		btn_toggle_shields.text = "🛡️ ESCUDOS: ON"
		_style_button(btn_toggle_shields, Color(0.3, 0.5, 0.6))

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
# RESOLUCIÓN Y PANTALLA COMPLETA
# ═══════════════════════════════════════════════════════════════════════════════

func _on_resolution_changed(index: int):
	var new_res = resolutions[index]
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		# En pantalla completa, cambiar tamaño del viewport
		get_viewport().size = new_res
		DisplayServer.window_set_size(new_res)
	else:
		DisplayServer.window_set_size(new_res)
		# Centrar ventana tras un frame para que el tamaño se aplique
		await get_tree().process_frame
		var screen_size = DisplayServer.screen_get_size()
		var actual_size = DisplayServer.window_get_size()
		var win_pos = Vector2i((screen_size.x - actual_size.x) / 2, (screen_size.y - actual_size.y) / 2)
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
				var win_pos = Vector2i((screen_size.x - actual_size.x) / 2, (screen_size.y - actual_size.y) / 2)
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
		plantillas_aliadas.append({
			"name": ally.name,
			"parent_path": ally.get_parent().get_path(),
			"global_transform": ally.global_transform,
			"template": plantilla,
		})

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
	if estado_actual != null and (int(estado_actual) == int(AllyArcher.State.DYING) or int(estado_actual) == int(AllyArcher.State.DEAD)):
		return true
	var vida_actual = ally.get("health")
	if vida_actual != null and int(vida_actual) <= 0:
		return true
	return false

func _revivir_aliadas():
	"""Revive aliadas destruidas reinstanciandolas en su posicion original."""
	if plantillas_aliadas.is_empty():
		_guardar_plantillas_aliadas()

	var revividas: int = 0
	for data in plantillas_aliadas:
		var nombre_aliada: String = str(data.get("name", ""))
		if nombre_aliada == "":
			continue

		var existente: AllyArcher = _buscar_aliada_por_nombre(nombre_aliada)
		if existente and is_instance_valid(existente):
			if _aliada_esta_revivible(existente):
				existente.name = "%s_DESCARTADA" % nombre_aliada
				existente.queue_free()
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
			revividas += 1

	if revividas > 0:
		print("[GameUI] Aliadas revividas: ", revividas)

# ═══════════════════════════════════════════════════════════════════════════════
# MODO MÍNIMO (Solo corazones de vida)
# ═══════════════════════════════════════════════════════════════════════════════

## Activa/desactiva el modo mínimo: oculta todo excepto los corazones de vida.
func set_modo_minimo(activo: bool):
	if bottom_panel:
		bottom_panel.visible = not activo
	if toggle_ui_btn:
		toggle_ui_btn.visible = not activo