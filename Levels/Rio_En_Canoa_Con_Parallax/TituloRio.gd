class_name TituloRio
extends CanvasLayer

## Tarjeta de título del nivel del rio ("Rio Tulemaki").
## Aparece con fundido, se mantiene visible y desaparece con el mismo
## fundido. El texto sale de las traducciones (clave configurable).

signal presentacion_terminada

# === EXPORTS ===
@export var clave_traduccion: String = "TITULO_RIO_TULEMAKI"  ## Clave en translations.csv
@export var tiempo_aparicion: float = 1.0  ## Fundido de entrada en segundos
@export var tiempo_visible: float = 2.0  ## Tiempo a plena opacidad en segundos
@export var tiempo_desaparicion: float = 1.0  ## Fundido de salida en segundos
@export var tamano_fuente: int = 64  ## Tamaño de la letra del título
@export var color_fuente: Color = Color.WHITE  ## Color de la letra del título
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
	_tween_presentacion.tween_property(etiqueta, "modulate:a", 1.0, maxf(tiempo_aparicion, 0.01))
	_tween_presentacion.tween_interval(maxf(tiempo_visible, 0.0))
	_tween_presentacion.tween_property(etiqueta, "modulate:a", 0.0, maxf(tiempo_desaparicion, 0.01))
	_tween_presentacion.tween_callback(_ocultar)


# === FUNCIONES PRIVADAS ===
func _aplicar_texto() -> void:
	if etiqueta == null:
		return
	etiqueta.text = tr(clave_traduccion)
	etiqueta.add_theme_font_size_override("font_size", tamano_fuente)
	etiqueta.add_theme_color_override("font_color", color_fuente)


func _ocultar() -> void:
	if etiqueta:
		etiqueta.visible = false
	presentacion_terminada.emit()
