extends CanvasLayer
## UI del Juego - Separada del Player
## Contiene: Vida, God Mode, Reiniciar, BGM, Volumen, Pausa, Toggle Bordes

# === REFERENCIAS ===
var player: Node = null
var health_container: HBoxContainer
var heart_icons: Array = []
var pause_panel: Panel

# === NODOS UI ===
var god_mode_btn: Button
var restart_btn: Button
var pause_btn: Button
var outline_btn: Button
var quit_btn: Button


# === SLIDERS ===
var bgm_slider: HSlider
var sfx_slider: HSlider

# === XD BUTTON ===
var xd_btn: Button
var xd_enabled: bool = false # false = 0.1, true = 1.0

# === ESTADO ===
var outlines_enabled: bool = true
var is_paused: bool = false
var effects_enabled: bool = true # Fog y DOF habilitados por defecto

# === NODOS DE EFECTOS ===
var world_environment: WorldEnvironment = null
var effects_btn: Button
var dof_slider: HSlider
var dof_value_label: Label
var fog_density_slider: HSlider
var fog_density_value_label: Label
var layers_btn: Button
var layers_enabled: bool = true

# === PLANOS DE EFECTOS ===
var fog_plane: Node3D = null
var fog_material: ShaderMaterial = null

# === MATERIALES CON OUTLINE ===
var materials_with_outline: Array = []

func _ready():
	layer = 100
	
	# Buscar al player
	await get_tree().process_frame
	_find_player()
	
	# Buscar WorldEnvironment
	_find_world_environment()
	
	# Escanear materiales con outline
	_scan_outline_materials()
	
	# Crear la UI
	_create_ui()
	
	# Conectar señales del player
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_health_changed)
		if player.has_signal("died"):
			player.died.connect(_on_player_died)


func _find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		# Buscar por nombre
		player = get_tree().root.find_child("Player", true, false)

func _find_world_environment():
	# Buscar el WorldEnvironment en la escena
	world_environment = get_tree().root.find_child("WorldEnvironment", true, false)
	
	# Buscar plano de niebla
	fog_plane = get_tree().root.find_child("FogPlane", true, false)
	
	# Obtener el material del fog plane para modificar fog_density
	if fog_plane and fog_plane is MeshInstance3D:
		fog_material = fog_plane.get_surface_override_material(0)

func _scan_outline_materials():
	# Lista de materiales conocidos con outline
	var material_paths = [
		"res://Assets/Materials/ARQUERA_MATERIAL.tres",
		"res://Assets/Materials/Arrows.tres",
		"res://Assets/Materials/ESCALERAS.tres",
		"res://Assets/Materials/Hand Crossbow.tres",
		"res://Assets/Materials/MAT_GOBLING.tres",
		"res://Assets/Materials/MAT_GOBLIN_GIRL.tres",
		"res://Assets/Materials/MAT_platform.tres",
		"res://Assets/Materials/MAT_shield.tres",
		"res://Assets/Materials/MAT_spike_trap.tres",
		"res://Assets/Materials/Recurve Bow 2.tres"
	]
	
	for path in material_paths:
		if ResourceLoader.exists(path):
			var mat = load(path)
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
	# PANEL INFERIOR - CONTROLES
	# ═══════════════════════════════════════════════════════════════════════════
	var bottom_panel = Control.new()
	bottom_panel.name = "BottomPanel"
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_top = -60
	bottom_panel.offset_bottom = -10
	add_child(bottom_panel)
	
	var hbox = HBoxContainer.new()
	hbox.name = "ButtonsContainer"
	hbox.add_theme_constant_override("separation", 8)
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom_panel.add_child(hbox)
	
	# --- PAUSA ---
	pause_btn = Button.new()
	pause_btn.text = "⏸️ PAUSA"
	pause_btn.custom_minimum_size = Vector2(90, 35)
	pause_btn.pressed.connect(_toggle_pause)
	_style_button(pause_btn, Color(0.5, 0.3, 0.6))
	hbox.add_child(pause_btn)
	
	# --- GOD MODE ---
	god_mode_btn = Button.new()
	god_mode_btn.text = "GOD: OFF"
	god_mode_btn.custom_minimum_size = Vector2(85, 35)
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
	restart_btn.custom_minimum_size = Vector2(100, 35)
	restart_btn.pressed.connect(_restart_game)
	_style_button(restart_btn, Color(0.7, 0.2, 0.2))
	hbox.add_child(restart_btn)

	# --- SALIR ---
	quit_btn = Button.new()
	quit_btn.text = "❌ SALIR"
	quit_btn.custom_minimum_size = Vector2(85, 35)
	quit_btn.pressed.connect(_quit_game)
	_style_button(quit_btn, Color(0.8, 0.2, 0.2))
	hbox.add_child(quit_btn)
	
	# --- SEPARADOR ---
	var sep1 = VSeparator.new()
	sep1.custom_minimum_size.x = 10
	hbox.add_child(sep1)
	
	# --- BGM SELECTOR ---
	var bgm_label = Label.new()
	bgm_label.text = "BGM:"
	hbox.add_child(bgm_label)
	
	var btn_m1 = Button.new()
	btn_m1.text = "1"
	btn_m1.custom_minimum_size = Vector2(30, 35)
	btn_m1.pressed.connect(func(): _play_music(1))
	_style_button(btn_m1, Color(0.3, 0.5, 0.3))
	hbox.add_child(btn_m1)
	
	var btn_m2 = Button.new()
	btn_m2.text = "2"
	btn_m2.custom_minimum_size = Vector2(30, 35)
	btn_m2.pressed.connect(func(): _play_music(2))
	_style_button(btn_m2, Color(0.3, 0.5, 0.3))
	hbox.add_child(btn_m2)
	
	var btn_mute = Button.new()
	btn_mute.text = "🔇"
	btn_mute.custom_minimum_size = Vector2(30, 35)
	btn_mute.pressed.connect(func(): _play_music(0))
	_style_button(btn_mute, Color(0.2, 0.2, 0.2))
	hbox.add_child(btn_mute)
	
	# --- SEPARADOR ---
	var sep2 = VSeparator.new()
	sep2.custom_minimum_size.x = 10
	hbox.add_child(sep2)
	
	# --- VOLUMEN BGM ---
	var vol_bgm_label = Label.new()
	vol_bgm_label.text = "🎵"
	hbox.add_child(vol_bgm_label)
	
	bgm_slider = HSlider.new()
	bgm_slider.min_value = 0
	bgm_slider.max_value = 100
	bgm_slider.value = 50
	bgm_slider.custom_minimum_size = Vector2(60, 20)
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
	sfx_slider.custom_minimum_size = Vector2(60, 20)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	hbox.add_child(sfx_slider)
	
	# --- SEPARADOR ---
	var sep3 = VSeparator.new()
	sep3.custom_minimum_size.x = 10
	hbox.add_child(sep3)
	
	# --- XD BUTTON (Displacement Scale Y para CubeControllers) ---
	xd_btn = Button.new()
	xd_btn.text = "XD: OFF"
	xd_btn.custom_minimum_size = Vector2(70, 35)
	xd_btn.pressed.connect(_toggle_xd)
	_style_button(xd_btn, Color(0.3, 0.3, 0.5))
	hbox.add_child(xd_btn)
	
	# --- SEPARADOR DEBUG ---
	var sep4 = VSeparator.new()
	sep4.custom_minimum_size.x = 10
	hbox.add_child(sep4)
	
	# --- TOGGLE SPAWN ---
	var spawn_btn = Button.new()
	spawn_btn.text = "👾 SPAWN"
	spawn_btn.custom_minimum_size = Vector2(80, 35)
	spawn_btn.pressed.connect(_toggle_spawning)
	_style_button(spawn_btn, Color(0.6, 0.2, 0.6))
	hbox.add_child(spawn_btn)
	
	# --- DESTROY SHIELDS ---
	var destroy_shields_btn = Button.new()
	destroy_shields_btn.text = "💥 ESCUDOS"
	destroy_shields_btn.custom_minimum_size = Vector2(80, 35)
	destroy_shields_btn.pressed.connect(_destroy_all_shields)
	_style_button(destroy_shields_btn, Color(0.8, 0.4, 0.1))
	hbox.add_child(destroy_shields_btn)
	
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

	var quit_pause_btn = Button.new()
	quit_pause_btn.text = "❌ SALIR DEL JUEGO"
	quit_pause_btn.custom_minimum_size = Vector2(200, 50)
	quit_pause_btn.pressed.connect(_quit_game)
	_style_button(quit_pause_btn, Color(0.8, 0.2, 0.2))
	vbox.add_child(quit_pause_btn)
	
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

func _on_player_died():
	# Mostrar todos los corazones vacíos
	for icon in heart_icons:
		if is_instance_valid(icon):
			icon.text = "🖤"
			icon.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))

func _style_button(btn: Button, color: Color):
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

func _quit_game():
	get_tree().quit()

func _play_music(index: int):
	AudioManager.play_music(index)

func _on_bgm_volume_changed(value: float):
	AudioManager.set_music_volume(value)

func _on_sfx_volume_changed(value: float):
	AudioManager.set_sfx_volume(value)

func _toggle_xd():
	xd_enabled = not xd_enabled
	var new_value = 1.0 if xd_enabled else 0.1
	
	# Actualizar botón
	if xd_enabled:
		xd_btn.text = "XD: ON"
		_style_button(xd_btn, Color(0.6, 0.4, 0.8))
	else:
		xd_btn.text = "XD: OFF"
		_style_button(xd_btn, Color(0.3, 0.3, 0.5))
	
	# Aplicar a todos los CubeControllers
	_apply_displacement_to_children(get_tree().root, new_value)

func _apply_displacement_to_children(node: Node, value: float):
	for child in node.get_children():
		if child.get_script():
			var script_path = child.get_script().resource_path
			if "CubeController" in script_path:
				child.displacement_scale_y = value
		_apply_displacement_to_children(child, value)

func _toggle_outlines():
	outlines_enabled = not outlines_enabled
	
	for data in materials_with_outline:
		var mat = data["material"]
		var outline = data["outline"]
		
		if outlines_enabled:
			mat.next_pass = outline
			outline_btn.text = "✏️ BORDES: ON"
			_style_button(outline_btn, Color(0.1, 0.6, 0.5))
		else:
			mat.next_pass = null
			outline_btn.text = "✏️ BORDES: OFF"
			_style_button(outline_btn, Color(0.4, 0.4, 0.4))

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

func _toggle_spawning():
	var spawner = get_tree().root.find_child("WaveSpawner", true, false)
	if spawner and spawner.has_method("toggle_pause_spawning"):
		spawner.toggle_pause_spawning()

func _destroy_all_shields():
	var escudos = get_tree().get_nodes_in_group("escudos")
	for escudo in escudos:
		if is_instance_valid(escudo) and escudo.has_method("recibir_golpe"):
			# Forzar destrucción inmediata
			if escudo.has_method("_destruir"):
				escudo._destruir()
			else:
				# Fallback: golpear hasta romper
				for i in range(10):
					escudo.recibir_golpe()
