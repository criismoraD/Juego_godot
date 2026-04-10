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

@onready var dialogo_label: RichTextLabel = _obtener_dialogo_label()
@onready var boton_continuar: Button = _obtener_boton_continuar()

var _revelando: bool = false
var _indice_pagina: int = 0
var _audio_player: AudioStreamPlayer

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

func _ready():
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "Master"
	add_child(_audio_player)

	if boton_continuar:
		boton_continuar.visible = false
		boton_continuar.focus_mode = Control.FOCUS_NONE
		boton_continuar.pressed.connect(_on_continue_pressed)

	if dialogo_label and paginas_texto.size() > 0:
		_indice_pagina = 0
		dialogo_label.text = paginas_texto[_indice_pagina]

	_actualizar_texto_boton()

	await get_tree().process_frame
	await _revelar_texto()

func _actualizar_texto_boton():
	if not boton_continuar:
		return

	if paginas_texto.size() > 1 and _indice_pagina < paginas_texto.size() - 1:
		boton_continuar.text = "Siguiente"
	else:
		boton_continuar.text = "Continuar"

func _revelar_texto():
	if _revelando or not dialogo_label:
		return

	_revelando = true
	dialogo_label.visible_characters = 0

	var total_chars: int = dialogo_label.get_total_character_count()
	if total_chars > 0:
		var ultimo_audio_ms: int = 0
		for i in range(total_chars + 1):
			if not is_instance_valid(self) or not is_inside_tree():
				return

			dialogo_label.visible_characters = i

			if i > 0 and i % max(chars_por_sonido, 1) == 0 and audio_stream:
				var ahora_ms: int = Time.get_ticks_msec()
				if ahora_ms - ultimo_audio_ms >= int(intervalo_min_sonido * 1000.0):
					_reproducir_audio()
					ultimo_audio_ms = ahora_ms

			await get_tree().create_timer(max(velocidad_texto, 0.005)).timeout

	if boton_continuar:
		boton_continuar.visible = true

	_revelando = false

func _reproducir_audio():
	if not _audio_player:
		return
	_audio_player.stream = audio_stream
	_audio_player.volume_db = audio_volume_db
	_audio_player.pitch_scale = audio_pitch_scale
	_audio_player.play()

func _on_continue_pressed():
	if _revelando:
		return

	if paginas_texto.size() > 1 and _indice_pagina < paginas_texto.size() - 1:
		_indice_pagina += 1
		dialogo_label.text = paginas_texto[_indice_pagina]
		_actualizar_texto_boton()
		boton_continuar.visible = false
		await _revelar_texto()
		return

	emit_signal("continuado")
