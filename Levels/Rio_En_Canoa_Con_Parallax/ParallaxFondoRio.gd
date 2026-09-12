class_name ParallaxFondoRio
extends Node3D

## Controlador de Parallax 3D para el escenario 'Rio en canoa con paralax'.
## Gestiona dos capas de profundidad:
##   - Fondo lejano: Atardecer (Fondo nivel 6 atardecer) a Z profunda con deriva suave.
##   - Fondo intermedio: Rocas y tierra (Fondo terroso nivel 6) en loop continuo horizontal.

# === CONSTANTES ===
const TEX_ATARDECER: Texture2D = preload("res://TEST_/Fondo nivel 6 atardecer.png")
const TEX_TERROSO: Texture2D = preload("res://TEST_/Fondo terroso nivel 6.png")

const CANTIDAD_SEGMENTOS: int = 3
const PROFUNDIDAD_ATARDECER: float = -38.0
const PROFUNDIDAD_TERROSO: float = -20.0

# === EXPORTS ===
@export_category("Velocidad de Parallax")
@export var activo: bool = true  ## Si true, el fondo se desplaza continuamente
@export var velocidad_terroso: float = 1.0  ## Velocidad de avance de las rocas en m/s hacia la izquierda
@export var factor_atardecer: float = 0.12  ## Multiplicador de velocidad para el cielo lejano (paralaje óptico)

@export_category("Dimensiones y Posicionamiento")
@export var ancho_segmento_terroso: float = 16.0  ## Ancho de cada mosaico de rocas en metros
@export var alto_segmento_terroso: float = 9.85  ## Alto proporcional del mosaico
@export var altura_y_terroso: float = 2.4  ## Cota Y del centro del terreno rocoso

@export var ancho_segmento_atardecer: float = 24.0  ## Ancho del fondo de cielo
@export var alto_segmento_atardecer: float = 15.0  ## Alto del fondo de cielo
@export var altura_y_atardecer: float = 3.6  ## Cota Y del cielo

@export_category("Renderizado")
@export var capa_visual: int = 2  ## Capa de renderizado (Fondo = 2)

# === VARIABLES PRIVADAS ===
var _sprites_terroso: Array[Sprite3D] = []
var _sprites_atardecer: Array[Sprite3D] = []
var _nodo_capa_terroso: Node3D = null
var _nodo_capa_atardecer: Node3D = null


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_construir_capas()
	_aplicar_capa_visual_recursiva(self)


func _process(delta: float) -> void:
	if not activo or delta <= 0.0:
		return

	_actualizar_loop_terroso(delta)
	_actualizar_loop_atardecer(delta)


# === FUNCIONES PÚBLICAS ===
## Retorna la lista de sprites que componen la cinta de rocas intermedias.
func obtener_sprites_terroso() -> Array[Sprite3D]:
	return _sprites_terroso


## Retorna la lista de sprites que componen el cielo lejano.
func obtener_sprites_atardecer() -> Array[Sprite3D]:
	return _sprites_atardecer


## Permite pausar o reanudar el desplazamiento de las capas.
func set_desplazamiento_activo(nuevo_estado: bool) -> void:
	activo = nuevo_estado


# === FUNCIONES PRIVADAS ===
func _construir_capas() -> void:
	_construir_capa_atardecer()
	_construir_capa_terroso()


func _construir_capa_atardecer() -> void:
	if _nodo_capa_atardecer:
		return

	_nodo_capa_atardecer = Node3D.new()
	_nodo_capa_atardecer.name = "CapaAtardecer"
	_nodo_capa_atardecer.position = Vector3(0.0, altura_y_atardecer, PROFUNDIDAD_ATARDECER)
	add_child(_nodo_capa_atardecer)

	# 2 segmentos anchos para el atardecer lejano
	for i in range(2):
		var sprite := Sprite3D.new()
		sprite.name = "Atardecer_" + str(i)
		sprite.texture = TEX_ATARDECER
		sprite.shaded = false
		sprite.double_sided = true
		sprite.render_priority = -10
		sprite.layers = capa_visual

		# Ajustar tamaño al área visible en metros
		var tam_textura := TEX_ATARDECER.get_size() if TEX_ATARDECER else Vector2(5038, 3168)
		var pixel_size: float = ancho_segmento_atardecer / tam_textura.x
		sprite.pixel_size = pixel_size

		# Centrar los 2 sprites lado a lado
		var x_pos: float = (float(i) - 0.5) * ancho_segmento_atardecer
		sprite.position = Vector3(x_pos, 0.0, 0.0)
		_nodo_capa_atardecer.add_child(sprite)
		_sprites_atardecer.append(sprite)


func _construir_capa_terroso() -> void:
	if _nodo_capa_terroso:
		return

	_nodo_capa_terroso = Node3D.new()
	_nodo_capa_terroso.name = "CapaTerroso"
	_nodo_capa_terroso.position = Vector3(0.0, altura_y_terroso, PROFUNDIDAD_TERROSO)
	add_child(_nodo_capa_terroso)

	# 3 segmentos contiguos para garantizar cobertura infinita sin costuras
	for i in range(CANTIDAD_SEGMENTOS):
		var sprite := Sprite3D.new()
		sprite.name = "Terroso_" + str(i)
		sprite.texture = TEX_TERROSO
		sprite.shaded = false
		sprite.double_sided = true
		sprite.render_priority = -5
		sprite.layers = capa_visual

		var tam_textura := TEX_TERROSO.get_size() if TEX_TERROSO else Vector2(6500, 4000)
		var pixel_size: float = ancho_segmento_terroso / tam_textura.x
		sprite.pixel_size = pixel_size

		# Segmentos centrados: i=0 a la izquierda, i=1 al centro, i=2 a la derecha
		var x_pos: float = (float(i) - 1.0) * ancho_segmento_terroso
		sprite.position = Vector3(x_pos, 0.0, 0.0)
		_nodo_capa_terroso.add_child(sprite)
		_sprites_terroso.append(sprite)


func _actualizar_loop_terroso(delta: float) -> void:
	var paso: float = velocidad_terroso * delta

	for s in _sprites_terroso:
		s.position.x -= paso

	# Si el sprite más a la izquierda ya salió completamente del área visible, lo reubicamos a la derecha
	var limite_izquierdo: float = -ancho_segmento_terroso * 1.5
	var x_maxima: float = -INF

	for s in _sprites_terroso:
		if s.position.x > x_maxima:
			x_maxima = s.position.x

	for s in _sprites_terroso:
		if s.position.x <= limite_izquierdo:
			s.position.x = x_maxima + ancho_segmento_terroso
			x_maxima = s.position.x


func _actualizar_loop_atardecer(delta: float) -> void:
	var paso: float = velocidad_terroso * factor_atardecer * delta

	for s in _sprites_atardecer:
		s.position.x -= paso

	var ancho_total: float = ancho_segmento_atardecer * float(_sprites_atardecer.size())
	var limite_izq: float = -ancho_segmento_atardecer

	var x_max: float = -INF
	for s in _sprites_atardecer:
		if s.position.x > x_max:
			x_max = s.position.x

	for s in _sprites_atardecer:
		if s.position.x <= limite_izq:
			s.position.x = x_max + ancho_segmento_atardecer
			x_max = s.position.x


func _aplicar_capa_visual_recursiva(nodo: Node) -> void:
	if nodo is VisualInstance3D:
		nodo.layers = capa_visual
	for hijo in nodo.get_children():
		_aplicar_capa_visual_recursiva(hijo)
