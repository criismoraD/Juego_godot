class_name UIGameOver
extends CanvasLayer

## Pantalla de Game Over con degradado a negro suave y lento, silencio total de fondo,
## pausado de escena, letras animadas en fuente Morpheus/SystemFont y centrado perfecto.

signal restart_requested

var background: ColorRect = null
var title_label: Label = null
var btn_continue: Button = null
var font_morpheus: Font = null
var _anim_time: float = 0.0


func _ready() -> void:
	layer = 200
	process_mode = PROCESS_MODE_ALWAYS

	# Pausar el árbol del juego para que los enemigos y aliados dejen de disparar y moverse
	get_tree().paused = true

	# Silenciar completamente todo el audio (Master bus + stop_all) para evitar sonidos de fondo
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		if am.has_method("stop_all"):
			am.call("stop_all")

	# Ocultar la UI del juego (vida, instrucciones, etc.)
	_ocultar_todas_las_ui()

	# Configurar fuente Morpheus / Fallback Serif
	var sys_font := SystemFont.new()
	sys_font.font_names = PackedStringArray(["Morpheus", "Georgia", "Cinzel", "Times New Roman", "Serif"])
	font_morpheus = sys_font

	_construir_ui()
	_iniciar_degradado_suave()


func _ocultar_todas_las_ui() -> void:
	get_tree().call_group("ui_vida_protagonista", "set_visible", false)
	get_tree().call_group("ui_instrucciones_mouse", "set_visible", false)


func _construir_ui() -> void:
	# Fondo negro inicial transparente para el degradado a negro suave y lento
	background = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(background)

	# CenterContainer a pantalla completa para un centrado perfecto sin desfases
	var center_container := CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(center_container)

	var v_box := VBoxContainer.new()
	v_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v_box.add_theme_constant_override("separation", 40)
	center_container.add_child(v_box)

	# Texto Principal Único: "HAS MUERTO" / GAME OVER
	title_label = Label.new()
	title_label.text = tr("GAME_OVER_TITLE")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", font_morpheus)
	title_label.add_theme_font_size_override("font_size", 76)
	title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	title_label.modulate.a = 0.0
	
	# Ajustar pivote dinámico al centro exacto de la etiqueta para evitar desfases al animar
	title_label.resized.connect(func():
		if is_instance_valid(title_label):
			title_label.pivot_offset = title_label.size * 0.5
	)
	v_box.add_child(title_label)

	# Botón de Continuar / Reiniciar Centrado
	var btn_center := CenterContainer.new()
	
	btn_continue = Button.new()
	btn_continue.text = "   " + tr("BTN_REINICIAR") + "   "
	btn_continue.custom_minimum_size = Vector2(220, 54)
	btn_continue.add_theme_font_override("font", font_morpheus)
	btn_continue.add_theme_font_size_override("font_size", 24)
	btn_continue.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	btn_continue.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.5))
	btn_continue.focus_mode = Control.FOCUS_ALL
	btn_continue.modulate.a = 0.0

	# Estilo minimalista elegante
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(1.0, 1.0, 1.0, 0.85)
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_right = 6
	style_normal.corner_radius_bottom_left = 6
	btn_continue.add_theme_stylebox_override("normal", style_normal)

	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.25, 0.25, 0.3, 1.0)
	style_hover.border_color = Color(1.0, 0.9, 0.4, 1.0)
	btn_continue.add_theme_stylebox_override("hover", style_hover)
	btn_continue.add_theme_stylebox_override("pressed", style_hover)

	btn_continue.pressed.connect(_on_continue_pressed)
	btn_center.add_child(btn_continue)
	v_box.add_child(btn_center)


func _iniciar_degradado_suave() -> void:
	# Transición degradada a negro lenta y pausada (2.8 segundos)
	var duracion: float = 2.8
	var tween := create_tween().set_parallel(true)
	
	tween.tween_property(background, "color", Color(0.0, 0.0, 0.0, 1.0), duracion) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if is_instance_valid(title_label):
		tween.tween_property(title_label, "modulate:a", 1.0, duracion * 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if is_instance_valid(btn_continue):
		tween.tween_property(btn_continue, "modulate:a", 1.0, duracion) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_anim_time += delta
	# Animación sutil de respiración en blanco sobre el texto principal
	if is_instance_valid(title_label) and title_label.modulate.a > 0.5:
		var pulso: float = (sin(_anim_time * 2.5) + 1.0) * 0.5
		var escala: float = lerp(1.0, 1.06, pulso)
		title_label.scale = Vector2(escala, escala)


func _on_continue_pressed() -> void:
	restart_requested.emit()

	# Eliminar enemigos y proyectiles sobrantes en pantalla
	for grp in ["enemies", "enemy_projectiles", "projectiles"]:
		for node in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(node):
				node.queue_free()

	# Despausar juego y desmutear audio antes de reiniciar
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
	get_tree().paused = false

	get_tree().reload_current_scene()
