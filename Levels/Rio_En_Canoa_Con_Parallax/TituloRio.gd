class_name TituloRio
extends CanvasLayer

## Tarjeta de título del nivel del rio ("Rio Tulemaki").
## Replica la presentación del nivel 1 ("PASO DE MEDEA"): tipografía
## Ravenna negra con resplandor cálido y la misma duración
## (aparición 2s, visible 16s, brillo 1s, desvanecido 3s).
## El texto sale de las traducciones (clave configurable).

signal presentacion_terminada

# === CONSTANTES (iguales que NIVEL01 "_mostrar_texto_paso_medea") ===
const FUENTE_RAVENNA: Font = preload("res://assets/Fuentes/Ravenna.ttf")
const COLOR_TEXTO_NEGRO: Color = Color.BLACK
const COLOR_BRILLO_SUAVE: Color = Color(1.0, 0.96, 0.88, 0.9)
const GROSOR_RESPLANDOR: int = 36

# === EXPORTS ===
@export var clave_traduccion: String = "TITULO_RIO_TULEMAKI"  ## Clave en translations.csv
@export var tiempo_aparicion: float = 2.0  ## Fundido de entrada en segundos
@export var tiempo_visible: float = 16.0  ## Texto nítido en segundos
@export var tiempo_brillo: float = 1.0  ## Encendido del resplandor en segundos
@export var tiempo_desaparicion: float = 3.0  ## Fundido de salida en segundos
@export var tamano_fuente: int = 120  ## Tamaño de la letra del título
@export var color_fuente: Color = Color.BLACK  ## Color de la letra del título
@export var mostrar_al_iniciar: bool = true  ## Si true, presenta el título al cargar el nivel

# === VARIABLES PRIVADAS ===
var _tween_presentacion: Tween = null

# === ONREADY ===
@onready var etiqueta: Label = $Centro/Titulo


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_aplicar_texto()
	if mostrar_al_iniciar:
		mostrar()


# === FUNCIONES PÚBLICAS ===
## Presenta el título (reaparece aunque ya se haya mostrado).
func mostrar() -> void:
	if etiqueta == null:
		return
	_aplicar_texto()
	if _tween_presentacion and _tween_presentacion.is_valid():
		_tween_presentacion.kill()
	etiqueta.modulate.a = 0.0
	etiqueta.visible = true
	_tween_presentacion = create_tween()
	# 1. Aparición gradual del texto negro limpio
	_tween_presentacion.tween_property(etiqueta, "modulate:a", 1.0, maxf(tiempo_aparicion, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 2. Permanece visible de forma nítida
	_tween_presentacion.tween_interval(maxf(tiempo_visible, 0.0))
	# 3. Brillo suave: se enciende el resplandor cálido alrededor del texto
	_tween_presentacion.tween_property(etiqueta, "theme_override_colors/font_shadow_color", COLOR_BRILLO_SUAVE, maxf(tiempo_brillo, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 4. Desvanecido suave hacia la transparencia total (paralelo con el brillo apagándose)
	_tween_presentacion.set_parallel(true)
	_tween_presentacion.tween_property(etiqueta, "modulate:a", 0.0, maxf(tiempo_desaparicion, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween_presentacion.tween_property(etiqueta, "theme_override_colors/font_shadow_color:a", 0.0, maxf(tiempo_desaparicion, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween_presentacion.chain().tween_callback(_ocultar)


# === FUNCIONES PRIVADAS ===
func _aplicar_texto() -> void:
	if etiqueta == null:
		return
	etiqueta.text = tr(clave_traduccion)
	var fuente_papyrus := FontVariation.new()
	fuente_papyrus.base_font = FUENTE_RAVENNA
	etiqueta.add_theme_font_override("font", fuente_papyrus)
	etiqueta.add_theme_font_size_override("font_size", tamano_fuente)
	etiqueta.add_theme_color_override("font_color", color_fuente)
	etiqueta.add_theme_color_override("font_shadow_color", Color(COLOR_BRILLO_SUAVE.r, COLOR_BRILLO_SUAVE.g, COLOR_BRILLO_SUAVE.b, 0.0))
	etiqueta.add_theme_constant_override("shadow_outline_size", GROSOR_RESPLANDOR)
	etiqueta.add_theme_constant_override("shadow_offset_x", 0)
	etiqueta.add_theme_constant_override("shadow_offset_y", 0)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ocultar() -> void:
	if etiqueta:
		etiqueta.visible = false
	presentacion_terminada.emit()
