extends Control
## Menú principal simple: fondo negro, letra blanca, traducible.
## Aparece después de LanguageSelector. Botones: JUGAR, CARGAR PARTIDA, OPCIONES, GALERIA DE ARTE, CREDITOS.

@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var btn_jugar: Button = $CenterContainer/VBoxContainer/BtnJugar
@onready var btn_cargar: Button = $CenterContainer/VBoxContainer/BtnCargar
@onready var btn_opciones: Button = $CenterContainer/VBoxContainer/BtnOpciones
@onready var btn_galeria: Button = $CenterContainer/VBoxContainer/BtnGaleria
@onready var btn_creditos: Button = $CenterContainer/VBoxContainer/BtnCreditos
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var msg_label: Label = $MsgLabel

var transitioning: bool = false


func _ready() -> void:
	fade_overlay.color = Color(0, 0, 0, 1)
	fade_overlay.visible = true
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_actualizar_textos()
	_conectar_botones()

	# Fade in
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func _actualizar_textos() -> void:
	title_label.text = tr("INTRO_TITLE") if tr("INTRO_TITLE") != "INTRO_TITLE" else "Arrow of Anathema"
	btn_jugar.text = tr("MENU_PLAY")
	btn_cargar.text = tr("MENU_LOAD")
	btn_opciones.text = tr("MENU_OPTIONS")
	btn_galeria.text = tr("MENU_GALLERY")
	btn_creditos.text = tr("MENU_CREDITS")


func _conectar_botones() -> void:
	btn_jugar.pressed.connect(_on_jugar_pressed)
	btn_cargar.pressed.connect(_on_cargar_pressed)
	btn_opciones.pressed.connect(_on_opciones_pressed)
	btn_galeria.pressed.connect(_on_galeria_pressed)
	btn_creditos.pressed.connect(_on_creditos_pressed)


func _on_jugar_pressed() -> void:
	if transitioning:
		return
	transitioning = true
	_mostrar_mensaje("")
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.finished.connect(func(): get_tree().change_scene_to_file("res://UI/IntroScene.tscn"))


func _on_cargar_pressed() -> void:
	# Intentar cargar partida si existe save file
	var save_path := "user://savegame.save"
	if FileAccess.file_exists(save_path):
		_mostrar_mensaje(tr("MENU_LOAD") + " - " + tr("Cargando..."))
		# Por ahora ir a NIVEL01 con continuación si existe oleada guardada
		await get_tree().create_timer(0.6).timeout
		get_tree().change_scene_to_file("res://Levels/NIVEL01/NIVEL01.tscn")
	else:
		_mostrar_mensaje("No hay partida guardada / No save found", 2.0)


func _on_opciones_pressed() -> void:
	_mostrar_mensaje("Opciones - En desarrollo / Options - Coming soon", 2.0)


func _on_galeria_pressed() -> void:
	_mostrar_mensaje("Galería - En desarrollo / Gallery - Coming soon", 2.0)


func _on_creditos_pressed() -> void:
	_mostrar_mensaje("Créditos - En desarrollo / Credits - Coming soon", 2.0)


func _mostrar_mensaje(texto: String, duracion: float = 0.0) -> void:
	msg_label.text = texto
	msg_label.visible = not texto.is_empty()
	if duracion > 0.0 and not texto.is_empty():
		await get_tree().create_timer(duracion).timeout
		if is_instance_valid(msg_label) and msg_label.text == texto:
			msg_label.visible = false
			msg_label.text = ""
