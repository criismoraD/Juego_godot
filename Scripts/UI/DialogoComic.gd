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

	if boton_continuar:
		boton_continuar.visible = false
		boton_continuar.focus_mode = Control.FOCUS_NONE
		boton_continuar.pressed.connect(_on_continue_pressed)

	if paginas_texto.size() > 0:
		_indice_pagina = 0
		_aplicar_pagina_actual()

	_preparar_dialogo_label()
	_actualizar_texto_boton()

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


func _actualizar_texto_boton():
	if not boton_continuar:
		return

	if paginas_texto.size() > 1 and _indice_pagina < paginas_texto.size() - 1:
		boton_continuar.text = "Siguiente"
	else:
		boton_continuar.text = "Continuar"


func _aplicar_pagina_actual() -> void:
	if dialogo_label and paginas_texto.size() > 0 and _indice_pagina < paginas_texto.size():
		dialogo_label.text = paginas_texto[_indice_pagina]

	if (
		icono_retrato
		and _indice_pagina < paginas_imagenes.size()
		and paginas_imagenes[_indice_pagina]
	):
		icono_retrato.texture = paginas_imagenes[_indice_pagina]


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
	if not _audio_player or not audio_stream:
		return

	if _audio_player.stream != audio_stream:
		_audio_player.stream = audio_stream
	if _audio_player.volume_db != audio_volume_db:
		_audio_player.volume_db = audio_volume_db
	if _audio_player.pitch_scale != audio_pitch_scale:
		_audio_player.pitch_scale = audio_pitch_scale
	_audio_player.play()


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
