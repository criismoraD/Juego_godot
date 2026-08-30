class_name SpeechBubbleUI
extends Control

## Controlador visual del globo de diálogo 2D con cinta modular de 3 piezas.
## Las puntas rasgadas cuentan con difuminado alfa suave sobre el cuerpo central en mosaico (Tile),
## garantizando 0% de estiramiento en los bordes y una fusión invisible entre todas las piezas.

signal mostrado
signal texto_completado
signal ocultado

const ANCHO_PUNTA: float = 44.0
const ALTO_BANNER: float = 40.0
const ANCHO_COLA: float = 21.0
const ALTO_COLA: float = 16.0
const SOLAPAMIENTO_COLA_Y: float = 7.0

@export_group("Personalización")
@export var color_borde: Color = Color(0.95, 0.76, 0.35, 1.0)
@export var color_fondo: Color = Color(0.11, 0.08, 0.16, 0.95)
@export var color_texto: Color = Color(0.14, 0.09, 0.04, 1.0):
	set(val):
		color_texto = val
		_actualizar_estilos()

@export var tamano_fuente: int = 16:
	set(val):
		tamano_fuente = val
		_actualizar_estilos()

@export var ancho_maximo: float = 380.0
@export var ancho_minimo: float = 60.0

var _tween_globo: Tween = null
var _tween_texto: Tween = null
var _timer_autocierre: SceneTreeTimer = null
var _audio_player: AudioStreamPlayer = null
var _audio_stream: AudioStream = null
var _audio_pitch: float = 1.0
var _audio_volume_db: float = -18.0
var _posicion_ancla_pantalla: Vector2 = Vector2.ZERO
var _esta_abierto: bool = false
var _chars_sonados: int = 0
var _chars_por_sonido: int = 3
var _tamano_actual: Vector2 = Vector2(100.0, ALTO_BANNER)

@onready var banner_container: Control = $BannerContainer
@onready var cuerpo_centro: TextureRect = $BannerContainer/CuerpoCentro
@onready var punta_izq: TextureRect = $BannerContainer/PuntaIzq
@onready var punta_der: TextureRect = $BannerContainer/PuntaDer
@onready var texture_cola: TextureRect = $BannerContainer/TextureCola
@onready var label_texto: RichTextLabel = $BannerContainer/RichTextLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	scale = Vector2.ZERO
	
	_crear_audio_player()
	_actualizar_estilos()


func _crear_audio_player() -> void:
	if _audio_player and is_instance_valid(_audio_player):
		return
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "Master"
	add_child(_audio_player)


func _actualizar_estilos() -> void:
	if label_texto:
		label_texto.add_theme_font_size_override("normal_font_size", tamano_fuente)
		label_texto.add_theme_color_override("default_color", color_texto)


## Muestra el diálogo con texto traducido, animación de pop-in elástico y máquina de escribir
func mostrar_dialogo(
	texto: String,
	duracion: float = 3.5,
	velocidad_escritura: float = 0.025,
	audio_pitch: float = 1.0,
	audio_stream: AudioStream = null,
	volumen_db: float = -18.0
) -> void:
	_limpiar_tweens()
	_actualizar_estilos()

	_audio_pitch = audio_pitch
	_audio_stream = audio_stream
	_audio_volume_db = volumen_db
	_chars_sonados = 0

	var texto_final := tr(texto)
	_configurar_dimensiones(texto_final)

	label_texto.text = "[center]%s[/center]" % texto_final
	label_texto.visible_ratio = 0.0
	visible = true
	_esta_abierto = true

	# 1. Animación de apertura pop-in elástica
	scale = Vector2(0.2, 0.2)
	modulate.a = 0.0
	_tween_globo = create_tween().set_parallel(true)
	_tween_globo.tween_property(self, "scale", Vector2.ONE, 0.28)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	_tween_globo.tween_property(self, "modulate:a", 1.0, 0.18)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	emit_signal("mostrado")

	# 2. Animación Typewriter (Máquina de escribir)
	var total_chars: int = texto_final.length()
	var tiempo_escritura: float = clampf(float(total_chars) * velocidad_escritura, 0.2, 2.5)

	_tween_texto = create_tween()
	_tween_texto.tween_method(
		func(val: float) -> void:
			if not is_instance_valid(label_texto):
				return
			label_texto.visible_ratio = val
			var chars_act := int(val * float(total_chars))
			if chars_act - _chars_sonados >= _chars_por_sonido:
				_chars_sonados = chars_act
				_reproducir_sonido_habla(),
		0.0,
		1.0,
		tiempo_escritura
	).set_trans(Tween.TRANS_LINEAR)

	_tween_texto.finished.connect(func() -> void:
		emit_signal("texto_completado")
	)

	# 3. Auto-cierre tras duración
	if duracion > 0.0:
		var tiempo_total: float = tiempo_escritura + duracion
		_timer_autocierre = get_tree().create_timer(tiempo_total, false)
		_timer_autocierre.timeout.connect(func() -> void:
			if is_instance_valid(self) and _esta_abierto:
				ocultar_dialogo(true)
		)


## Oculta el globo con desvanecimiento y encogimiento suave
func ocultar_dialogo(animado: bool = true) -> void:
	if not _esta_abierto:
		return
	_esta_abierto = false
	_limpiar_tweens()

	if animado:
		_tween_globo = create_tween().set_parallel(true)
		_tween_globo.tween_property(self, "scale", Vector2(0.8, 0.8), 0.18)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_IN)
		_tween_globo.tween_property(self, "modulate:a", 0.0, 0.18)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_IN)
		_tween_globo.chain().tween_callback(func() -> void:
			if is_instance_valid(self):
				visible = false
				scale = Vector2.ONE
				emit_signal("ocultado")
		)
	else:
		visible = false
		modulate.a = 0.0
		scale = Vector2.ONE
		emit_signal("ocultado")


## Actualiza la posición del globo en pantalla para alinearse con el punto 3D proyectado
func actualizar_posicion_pantalla(pos_pantalla: Vector2, es_visible: bool) -> void:
	_posicion_ancla_pantalla = pos_pantalla
	if not es_visible:
		if visible and modulate.a > 0.0:
			visible = false
		return

	if not visible and _esta_abierto:
		visible = true

	if not banner_container:
		return

	var ancho_total := _tamano_actual.x
	var alto_total := _tamano_actual.y

	var pos_final := Vector2(
		pos_pantalla.x - ancho_total * 0.5,
		pos_pantalla.y - alto_total - ALTO_COLA + SOLAPAMIENTO_COLA_Y
	)

	var viewport_size := get_viewport_rect().size
	pos_final.x = clampf(pos_final.x, 10.0, maxf(10.0, viewport_size.x - ancho_total - 10.0))
	pos_final.y = clampf(pos_final.y, 10.0, maxf(10.0, viewport_size.y - alto_total - 10.0))

	banner_container.position = pos_final
	pivot_offset = pos_final + Vector2(ancho_total * 0.5, alto_total + ALTO_COLA - SOLAPAMIENTO_COLA_Y)


func esta_abierto() -> bool:
	return _esta_abierto


func _configurar_dimensiones(texto: String) -> void:
	if not label_texto or not banner_container or not punta_izq or not cuerpo_centro or not punta_der:
		return

	var font: Font = label_texto.get_theme_default_font()
	var f_size: int = tamano_fuente

	var lineas: PackedStringArray = texto.split("\n")
	var max_w_linea: float = 0.0
	for linea in lineas:
		if font:
			var sz := font.get_string_size(linea, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size)
			max_w_linea = maxf(max_w_linea, sz.x)
		else:
			max_w_linea = maxf(max_w_linea, float(linea.length()) * 10.0)

	# Espacio para el texto + respiro reducido a la mitad en los laterales
	var margen_lateral := 21.0
	var total_w := clampf(max_w_linea + margen_lateral * 2.0, ancho_minimo, ancho_maximo)

	_tamano_actual = Vector2(total_w, ALTO_BANNER)

	# 1. Cuerpo Central en Mosaico (Solo en la zona interna segura, evitando asomarse por las rasgaduras exteriores)
	var cuerpo_x := 28.0
	var cuerpo_w := maxf(total_w - 56.0, 10.0)
	cuerpo_centro.position = Vector2(cuerpo_x, 0.0)
	cuerpo_centro.size = Vector2(cuerpo_w, ALTO_BANNER)

	# 2. Punta Izquierda (con difuminado alfa suave sobre el cuerpo central)
	punta_izq.position = Vector2.ZERO
	punta_izq.size = Vector2(ANCHO_PUNTA, ALTO_BANNER)

	# 3. Punta Derecha (con difuminado alfa suave sobre el cuerpo central)
	punta_der.position = Vector2(total_w - ANCHO_PUNTA, 0.0)
	punta_der.size = Vector2(ANCHO_PUNTA, ALTO_BANNER)

	# 4. Texto centrado sobre el pergamino con respiro ceñido
	label_texto.position = Vector2(margen_lateral, 8.0)
	label_texto.size = Vector2(total_w - margen_lateral * 2.0, ALTO_BANNER - 16.0)

	# 5. Cola centrada bajo el banner
	if texture_cola:
		texture_cola.size = Vector2(ANCHO_COLA, ALTO_COLA)
		texture_cola.position = Vector2(total_w * 0.5 - ANCHO_COLA * 0.5, ALTO_BANNER - SOLAPAMIENTO_COLA_Y)

	banner_container.size = _tamano_actual


func _reproducir_sonido_habla() -> void:
	if not _audio_stream or not _audio_player:
		return

	_audio_player.stream = _audio_stream
	_audio_player.pitch_scale = _audio_pitch * randf_range(0.96, 1.04)
	_audio_volume_db = _audio_volume_db
	_audio_player.play()


func _limpiar_tweens() -> void:
	if _tween_globo and _tween_globo.is_valid():
		_tween_globo.kill()
		_tween_globo = null
	if _tween_texto and _tween_texto.is_valid():
		_tween_texto.kill()
		_tween_texto = null
