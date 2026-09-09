class_name DialogoComic
extends CanvasLayer
signal continuado
@export var velocidad_texto: float = 0.02
@export var chars_por_sonido: int = 4
@export var intervalo_min_sonido: float = 0.18
@export var audio_stream: AudioStream
@export var audio_volume_db: float = -18.0
@export var audio_pitch_scale: float = 1.0
@export var paginas_texto: PackedStringArray = PackedStringArray()
@export var paginas_imagenes: Array[Texture2D] = []
## Hablante por página ("eryn"/"perrena", en minúsculas; vacío = eryn).
## Solo tiene efecto con dos retratos (RetratoEryn + RetratoPerrena).
@export var paginas_hablante: PackedStringArray = PackedStringArray()
@export var nombre_perrena: String = "Perrena"
var retrato_eryn: Node = null
var retrato_perrena: Node = null
var _modo_dual: bool = false
var _escala_eryn_base := Vector2.ONE
var _escala_perrena_base := Vector2.ONE
var _pos_eryn_base := Vector2.ZERO
var _pos_perrena_base := Vector2.ZERO
var _alto_eryn_px: float = 0.0
var _alto_perrena_px: float = 0.0
var _nombre_eryn: String = ""
var _nombre_perrena: String = ""
const COLOR_RETRATO_APAGADO := Color(0.45, 0.45, 0.45)
const ESCALA_RETRATO_APAGADO: float = 0.85
var _revelando: bool = false
var _indice_pagina: int = 0
var _audio_player: AudioStreamPlayer
var _timer_revelado: Timer
var _ultimo_audio_ms: int = 0
var _total_chars_pagina: int = 0
@onready var dialogo_label: RichTextLabel = _obtener_dialogo_label()
@onready var boton_continuar: Button = _obtener_boton_continuar()
@onready var icono_retrato: TextureRect = _obtener_icono_retrato()


func _obtener_dialogo_label() -> RichTextLabel:
	var nodo := find_child("Dialogo", true, false)
	if nodo is RichTextLabel:
		return nodo

	nodo = get_node_or_null("Panel/HBox/Texto/Dialogo")
	if nodo is RichTextLabel:
		return nodo

	return null


func _obtener_boton_continuar() -> Button:
	var nodo := find_child("BotonContinuar", true, false)
	if nodo is Button:
		return nodo

	nodo = get_node_or_null("Panel/HBox/Texto/BotonContinuar")
	if nodo is Button:
		return nodo

	return null


func _obtener_icono_retrato() -> TextureRect:
	var nodo := find_child("Icono", true, false)
	if nodo is TextureRect:
		return nodo

	nodo = get_node_or_null("Panel/HBox/Icono")
	if nodo is TextureRect:
		return nodo

	return null


func _ready():
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "Master"
	add_child(_audio_player)

	_timer_revelado = Timer.new()
	_timer_revelado.one_shot = false
	_timer_revelado.autostart = false
	_timer_revelado.timeout.connect(_on_reveal_timer_timeout)
	add_child(_timer_revelado)

	# Traducir los contenidos del diálogo
	_traducir_dialogos()

	if boton_continuar:
		boton_continuar.visible = false
		boton_continuar.focus_mode = Control.FOCUS_NONE
		boton_continuar.pressed.connect(_on_continue_pressed)

	if paginas_texto.size() > 0:
		_indice_pagina = 0
		_aplicar_pagina_actual()

	_preparar_dialogo_label()
	_actualizar_texto_boton()
	_inicializar_dual()

	var boton_saltar = find_child("BotonSaltar", true, false)
	if boton_saltar and boton_saltar is Button:
		boton_saltar.text = tr("BTN_SKIP")
		boton_saltar.focus_mode = Control.FOCUS_NONE
		
		# Estilos premium (oscuro con borde dorado)
		var estilo_saltar = StyleBoxFlat.new()
		estilo_saltar.bg_color = Color(0.12, 0.08, 0.05, 0.8)
		estilo_saltar.border_color = Color(0.85, 0.65, 0.2)
		estilo_saltar.set_border_width_all(2)
		estilo_saltar.set_corner_radius_all(6)
		estilo_saltar.set_content_margin_all(8)
		boton_saltar.add_theme_stylebox_override("normal", estilo_saltar)
		
		var estilo_hover = estilo_saltar.duplicate()
		estilo_hover.bg_color = Color(0.2, 0.14, 0.08, 0.9)
		boton_saltar.add_theme_stylebox_override("hover", estilo_hover)
		
		var estilo_pressed = estilo_saltar.duplicate()
		estilo_pressed.bg_color = Color(0.08, 0.05, 0.02, 0.9)
		boton_saltar.add_theme_stylebox_override("pressed", estilo_pressed)
		
		boton_saltar.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		boton_saltar.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.6))
		boton_saltar.add_theme_font_size_override("font_size", 16)
		
		boton_saltar.pressed.connect(
			func():
				emit_signal("continuado")
		)

	await get_tree().process_frame
	_revelar_texto()


func _preparar_dialogo_label() -> void:
	if not dialogo_label:
		return

	# Evita relayout por caracter durante el reveal para bajar carga de CPU.
	dialogo_label.fit_content = false
	dialogo_label.scroll_active = false


func _on_reveal_timer_timeout() -> void:
	if not _revelando or not dialogo_label:
		return

	var chars_actuales = dialogo_label.visible_characters
	if chars_actuales >= _total_chars_pagina:
		_terminar_revelado()
		return

	var nuevos_chars = min(chars_actuales + 1, _total_chars_pagina)
	dialogo_label.visible_characters = nuevos_chars

	if nuevos_chars > 0 and nuevos_chars % max(chars_por_sonido, 1) == 0 and audio_stream:
		var ahora_ms: int = Time.get_ticks_msec()
		if ahora_ms - _ultimo_audio_ms >= int(intervalo_min_sonido * 1000.0):
			_reproducir_audio()
			_ultimo_audio_ms = ahora_ms

	if nuevos_chars >= _total_chars_pagina:
		_terminar_revelado()


func _terminar_revelado() -> void:
	_revelando = false
	if _timer_revelado:
		_timer_revelado.stop()
	if dialogo_label:
		if _total_chars_pagina <= 0:
			_total_chars_pagina = dialogo_label.get_total_character_count()
		dialogo_label.visible_characters = _total_chars_pagina
	if boton_continuar:
		boton_continuar.visible = true


func _traducir_dialogos() -> void:
	var nodo_nombre = find_child("Nombre", true, false)
	if nodo_nombre and nodo_nombre is Label:
		nodo_nombre.text = tr(nodo_nombre.text)

	for i in range(paginas_texto.size()):
		paginas_texto[i] = tr(paginas_texto[i])


func _actualizar_texto_boton():
	if not boton_continuar:
		return

	if paginas_texto.size() > 1 and _indice_pagina < paginas_texto.size() - 1:
		boton_continuar.text = tr("BOTON_SIGUIENTE")
	else:
		boton_continuar.text = tr("BOTON_CONTINUAR")


func _aplicar_pagina_actual() -> void:
	if dialogo_label and paginas_texto.size() > 0 and _indice_pagina < paginas_texto.size():
		dialogo_label.text = paginas_texto[_indice_pagina]

	if (
		icono_retrato
		and _indice_pagina < paginas_imagenes.size()
		and paginas_imagenes[_indice_pagina]
	):
		icono_retrato.texture = paginas_imagenes[_indice_pagina]

	if _modo_dual:
		_actualizar_hablante()


## Duelo de retratos: el que no habla se encoge y oscurece. Solo si la
## escena trae RetratoEryn + RetratoPerrena (el intro no los tiene y queda
## exactamente igual que antes).
func _inicializar_dual() -> void:
	retrato_eryn = find_child("RetratoEryn", true, false)
	retrato_perrena = find_child("RetratoPerrena", true, false)
	_modo_dual = retrato_eryn != null and retrato_perrena != null
	if not _modo_dual:
		return
	_escala_eryn_base = _escala_nodo(retrato_eryn)
	_escala_perrena_base = _escala_nodo(retrato_perrena)
	_pos_eryn_base = _pos_nodo(retrato_eryn)
	_pos_perrena_base = _pos_nodo(retrato_perrena)
	_alto_eryn_px = _alto_retrato(retrato_eryn)
	_alto_perrena_px = _alto_retrato(retrato_perrena)
	var nodo_nombre = find_child("Nombre", true, false)
	if nodo_nombre and nodo_nombre is Label:
		_nombre_eryn = (nodo_nombre as Label).text
	_nombre_perrena = tr(nombre_perrena)
	_actualizar_hablante()


func _escala_nodo(nodo: Node) -> Vector2:
	if nodo is Node2D:
		return (nodo as Node2D).scale
	if nodo is Control:
		return (nodo as Control).scale
	return Vector2.ONE


func _pos_nodo(nodo: Node) -> Vector2:
	if nodo is Node2D:
		return (nodo as Node2D).position
	if nodo is Control:
		return (nodo as Control).position
	return Vector2.ZERO


## Alto en píxeles de la textura (para anclar el borde inferior al encoger).
func _alto_retrato(nodo: Node) -> float:
	if nodo is Sprite2D:
		var tex := (nodo as Sprite2D).texture as Texture2D
		if tex:
			return float(tex.get_height())
	if nodo is TextureRect:
		var tex2 := (nodo as TextureRect).texture as Texture2D
		if tex2:
			return float(tex2.get_height())
	return 0.0


func _hablante_actual() -> String:
	if _indice_pagina < paginas_hablante.size():
		var hab := String(paginas_hablante[_indice_pagina]).strip_edges().to_lower()
		if not hab.is_empty():
			return hab
	return "eryn"


func _actualizar_hablante() -> void:
	if not _modo_dual:
		return
	var es_eryn := _hablante_actual() != "perrena"
	_aplicar_foco(retrato_eryn, es_eryn, _escala_eryn_base, _pos_eryn_base, _alto_eryn_px)
	_aplicar_foco(retrato_perrena, not es_eryn, _escala_perrena_base, _pos_perrena_base, _alto_perrena_px)
	var nodo_nombre = find_child("Nombre", true, false)
	if nodo_nombre and nodo_nombre is Label:
		(nodo_nombre as Label).text = _nombre_eryn if es_eryn else _nombre_perrena


## El inactivo se encoge y oscurece, pero su borde inferior queda anclado
## al marco (se baja la mitad de lo que pierde de alto) para que no flote
## ni parezca recortado.
func _aplicar_foco(nodo: Node, activo: bool, base_esc: Vector2, base_pos: Vector2, alto_px: float) -> void:
	if nodo == null:
		return
	if nodo is CanvasItem:
		(nodo as CanvasItem).modulate = Color.WHITE if activo else COLOR_RETRATO_APAGADO
	var nueva_esc: Vector2 = base_esc if activo else base_esc * ESCALA_RETRATO_APAGADO
	if nodo is Node2D:
		(nodo as Node2D).scale = nueva_esc
		(nodo as Node2D).position = Vector2(
			base_pos.x, base_pos.y + alto_px * (base_esc.y - nueva_esc.y) * 0.5
		)
	elif nodo is Control:
		(nodo as Control).scale = nueva_esc


func _revelar_texto():
	if _revelando or not dialogo_label:
		return

	_revelando = true
	_ultimo_audio_ms = 0
	dialogo_label.visible_characters = 0
	_total_chars_pagina = dialogo_label.get_total_character_count()

	if _total_chars_pagina > 0:
		if _timer_revelado:
			_timer_revelado.wait_time = max(velocidad_texto, 0.01)
			_timer_revelado.start()
	else:
		_terminar_revelado()


func _reproducir_audio():
	return


func _on_continue_pressed():
	if _revelando:
		return

	if paginas_texto.size() > 1 and _indice_pagina < paginas_texto.size() - 1:
		_indice_pagina += 1
		_aplicar_pagina_actual()
		_actualizar_texto_boton()
		if boton_continuar:
			boton_continuar.visible = false
		_revelar_texto()
		return

	emit_signal("continuado")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _revelando:
			_terminar_revelado()
		else:
			_on_continue_pressed()
