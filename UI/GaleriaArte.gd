class_name GaleriaArte
extends Control
## Menú Galería de Arte con estética minimalista, limpia y elegante,
## alineada a los menús de la torre interior (Defensoras y Bestiario).
## Fondo oscuro con dos franjas celestes horizontales nítidas, título en amarillo
## y soporte para ilustraciones y videos con reproducción integrada y traducción (tr).

const COLOR_AMARILLO_TITULO: Color = Color(1.0, 0.88, 0.18, 1.0)
const COLOR_CELESTE_ACENTO: Color = Color(0.2, 0.85, 1.0, 1.0)
const COLOR_BORDE_NORMAL: Color = Color(0.28, 0.32, 0.46, 0.75)
const COLOR_BORDE_HOVER: Color = Color(0.2, 0.85, 1.0, 1.0)
const COLOR_FONDO_CARD: Color = Color(0.07, 0.08, 0.13, 0.9)
const COLOR_FONDO_CARD_HOVER: Color = Color(0.09, 0.11, 0.18, 0.95)

## Registro de obras de la galería con claves de traducción y tipo (imagen/video)
const OBRAS_GALERIA: Array[Dictionary] = [
	{
		"id": 1,
		"numero": "01",
		"tipo": "imagen",
		"titulo": "Eryn diseño Dialogos",
		"titulo_key": "OBRA_01_TITULO",
		"desc_key": "OBRA_01_DESC",
		"ruta": "res://TEST_/Eryn diseño Dialogos.png"
	}
]

@onready var fondo_galeria: Control = %FondoGaleria
@onready var title_label: Label = %TitleLabel
@onready var btn_volver: Button = %BtnVolver
@onready var grid_obras: Container = %GridObras
@onready var visor_modal: Control = %VisorModal
@onready var visor_imagen: TextureRect = %VisorImagen
@onready var visor_video: VideoStreamPlayer = %VisorVideo if has_node("%VisorVideo") else null
@onready var visor_titulo: Label = %VisorTitulo
@onready var visor_numero: Label = %VisorNumero
@onready var btn_cerrar_visor: Button = %BtnCerrarVisor
@onready var fade_overlay: ColorRect = %FadeOverlay

var _transitioning: bool = false


func _ready() -> void:
	if is_instance_valid(fade_overlay):
		fade_overlay.color = Color(0, 0, 0, 1)
		fade_overlay.visible = true
		fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := create_tween()
		tw.tween_property(fade_overlay, "color:a", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	_aplicar_textos_traducidos()

	if is_instance_valid(btn_volver):
		btn_volver.pressed.connect(_on_volver_pressed)

	if is_instance_valid(btn_cerrar_visor):
		btn_cerrar_visor.pressed.connect(_cerrar_visor)

	if is_instance_valid(visor_modal):
		visor_modal.visible = false
		visor_modal.gui_input.connect(_on_visor_gui_input)

	_construir_collage()


func _aplicar_textos_traducidos() -> void:
	if is_instance_valid(title_label):
		var texto_galeria: String = tr("MENU_GALLERY")
		if texto_galeria == "MENU_GALLERY" or texto_galeria.is_empty():
			texto_galeria = "Galería de arte"
		title_label.text = texto_galeria
		title_label.add_theme_color_override("font_color", COLOR_AMARILLO_TITULO)

	if is_instance_valid(btn_volver):
		btn_volver.text = "< " + tr("BTN_VOLVER")

	if is_instance_valid(btn_cerrar_visor):
		btn_cerrar_visor.text = "✕ " + tr("BTN_CERRAR")


func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey):
		return
	var tecla := evento as InputEventKey
	if not tecla.pressed or tecla.echo:
		return

	if tecla.keycode == KEY_ESCAPE:
		if is_instance_valid(visor_modal) and visor_modal.visible:
			_cerrar_visor()
			get_viewport().set_input_as_handled()
		else:
			_on_volver_pressed()
			get_viewport().set_input_as_handled()


func _construir_collage() -> void:
	if not is_instance_valid(grid_obras):
		return

	for hijo in grid_obras.get_children():
		hijo.queue_free()

	for obra in OBRAS_GALERIA:
		var tarjeta := _crear_tarjeta_obra(obra)
		grid_obras.add_child(tarjeta)


func _crear_tarjeta_obra(obra: Dictionary) -> Control:
	var btn_tarjeta := Button.new()
	btn_tarjeta.custom_minimum_size = Vector2(440.0, 320.0)
	btn_tarjeta.focus_mode = Control.FOCUS_ALL
	btn_tarjeta.flat = false

	# Estilos minimalistas consistentes con MenuBestiario / MenuDefensoras
	var estilo_normal := _crear_estilo_tarjeta(COLOR_BORDE_NORMAL, COLOR_FONDO_CARD, 4)
	var estilo_hover := _crear_estilo_tarjeta(COLOR_BORDE_HOVER, COLOR_FONDO_CARD_HOVER, 8)
	var estilo_pressed := _crear_estilo_tarjeta(COLOR_BORDE_HOVER, Color(0.12, 0.16, 0.25, 0.98), 8)

	btn_tarjeta.add_theme_stylebox_override("normal", estilo_normal)
	btn_tarjeta.add_theme_stylebox_override("hover", estilo_hover)
	btn_tarjeta.add_theme_stylebox_override("pressed", estilo_pressed)
	btn_tarjeta.add_theme_stylebox_override("focus", estilo_hover)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16.0
	vbox.offset_top = 14.0
	vbox.offset_right = -16.0
	vbox.offset_bottom = -14.0
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_tarjeta.add_child(vbox)

	# Fila superior: Número e indicador de tipo (si es video)
	var hbox_num := HBoxContainer.new()
	hbox_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hbox_num)

	var lbl_num := Label.new()
	lbl_num.text = str(obra.get("numero", "01"))
	lbl_num.add_theme_color_override("font_color", COLOR_CELESTE_ACENTO)
	lbl_num.add_theme_font_size_override("font_size", 20)
	hbox_num.add_child(lbl_num)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox_num.add_child(spacer)

	if str(obra.get("tipo", "imagen")) == "video":
		var badge_video := Label.new()
		badge_video.text = tr("GALERIA_VIDEO")
		badge_video.add_theme_color_override("font_color", COLOR_CELESTE_ACENTO)
		badge_video.add_theme_font_size_override("font_size", 13)
		hbox_num.add_child(badge_video)

	# Miniatura enmarcada con proporción elegante
	var panel_img := PanelContainer.new()
	panel_img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo_img := StyleBoxFlat.new()
	estilo_img.bg_color = Color(0.02, 0.02, 0.04, 0.95)
	estilo_img.border_color = Color(0.18, 0.22, 0.32, 0.6)
	estilo_img.set_border_width_all(1)
	estilo_img.set_corner_radius_all(6)
	panel_img.add_theme_stylebox_override("panel", estilo_img)
	vbox.add_child(panel_img)

	var tex_rect := TextureRect.new()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ruta: String = obra.get("ruta", "")
	if ResourceLoader.exists(ruta):
		tex_rect.texture = load(ruta) as Texture2D

	panel_img.add_child(tex_rect)

	# Título al pie sujeto a traducción
	var lbl_titulo := Label.new()
	var clave_titulo: String = obra.get("titulo_key", "")
	var texto_titulo: String = tr(clave_titulo) if not clave_titulo.is_empty() else str(obra.get("titulo", ""))
	lbl_titulo.text = texto_titulo
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_titulo.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0, 1.0))
	lbl_titulo.add_theme_font_size_override("font_size", 16)
	lbl_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl_titulo)

	# Animación de hover sutil
	btn_tarjeta.pivot_offset = Vector2(220.0, 160.0)
	btn_tarjeta.mouse_entered.connect(func():
		var tw := create_tween()
		tw.tween_property(btn_tarjeta, "scale", Vector2(1.025, 1.025), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	btn_tarjeta.mouse_exited.connect(func():
		var tw := create_tween()
		tw.tween_property(btn_tarjeta, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)

	btn_tarjeta.pressed.connect(_on_tarjeta_pulsada.bind(obra))

	return btn_tarjeta


func _crear_estilo_tarjeta(color_borde: Color, color_fondo: Color, sombra: int) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = color_fondo
	st.border_color = color_borde
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = sombra
	return st


func _on_tarjeta_pulsada(obra: Dictionary) -> void:
	if Engine.has_singleton("AudioManager"):
		var am = Engine.get_singleton("AudioManager")
		if am and am.has_method("play_sfx"):
			am.play_sfx("seleccion_menu")
	_abrir_visor(obra)


func _abrir_visor(obra: Dictionary) -> void:
	if not is_instance_valid(visor_modal):
		return

	if is_instance_valid(visor_numero):
		visor_numero.text = str(obra.get("numero", "01"))

	if is_instance_valid(visor_titulo):
		var clave: String = obra.get("titulo_key", "")
		visor_titulo.text = tr(clave) if not clave.is_empty() else str(obra.get("titulo", ""))

	var tipo: String = str(obra.get("tipo", "imagen"))
	if tipo == "video":
		if is_instance_valid(visor_imagen):
			visor_imagen.visible = false
		if is_instance_valid(visor_video):
			var ruta_vid: String = obra.get("ruta_video", "")
			if ResourceLoader.exists(ruta_vid):
				visor_video.stream = load(ruta_vid) as VideoStream
				visor_video.visible = true
				visor_video.play()
	else:
		if is_instance_valid(visor_video):
			visor_video.stop()
			visor_video.stream = null
			visor_video.visible = false
		if is_instance_valid(visor_imagen):
			visor_imagen.visible = true
			var ruta_img: String = obra.get("ruta", "")
			if ResourceLoader.exists(ruta_img):
				visor_imagen.texture = load(ruta_img) as Texture2D

	visor_modal.modulate.a = 0.0
	visor_modal.visible = true
	var tw := create_tween()
	tw.tween_property(visor_modal, "modulate:a", 1.0, 0.18).set_ease(Tween.EASE_OUT)


func _cerrar_visor() -> void:
	if not is_instance_valid(visor_modal) or not visor_modal.visible:
		return

	if is_instance_valid(visor_video):
		visor_video.stop()
		visor_video.stream = null
		visor_video.visible = false

	var tw := create_tween()
	tw.tween_property(visor_modal, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tw.finished.connect(func():
		if is_instance_valid(visor_modal):
			visor_modal.visible = false
	)


func _on_visor_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_cerrar_visor()


func _on_volver_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true

	if is_instance_valid(visor_video):
		visor_video.stop()
		visor_video.stream = null

	if Engine.has_singleton("AudioManager"):
		var am = Engine.get_singleton("AudioManager")
		if am and am.has_method("play_sfx"):
			am.play_sfx("seleccion_menu")

	if is_instance_valid(fade_overlay):
		var tw := create_tween()
		tw.tween_property(fade_overlay, "color:a", 1.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		tw.finished.connect(func():
			get_tree().change_scene_to_file("res://UI/MainMenu.tscn")
		)
	else:
		get_tree().change_scene_to_file("res://UI/MainMenu.tscn")
