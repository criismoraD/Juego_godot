@tool
class_name Pino2D
extends Node3D

## Pino 2D posicionable para el nivel del rio.
## Wrapper sobre un Sprite3D: el nodo raiz queda libre para
## mover/rotar/escalar en el editor, el hijo "Visual" solo
## aplica escala base + balanceo opcional.
## En juego, la raiz avanza sola a la velocidad exacta de la
## cordillera (velocidad_base * factor_cordillera del ParallaxFondo)
## y se recicla por delante de la camara conservando su Y/Z manual.
## No modifica ningun otro nodo de la escena.

const ALTURA_PIVOTE_DEFAULT: float = 0.0
const NOMBRE_FONDO_PARALLAX: String = "ParallaxFondo"

@export_category("Pino 2D")
@export var pixel_size: float = 0.005:
	set(nuevo_valor):
		pixel_size = nuevo_valor
		if is_node_ready():
			_aplicar_pixel_size()
@export var escala_base: Vector3 = Vector3.ONE:
	set(nuevo_valor):
		escala_base = nuevo_valor
		if is_node_ready():
			_aplicar_escala_base()
@export var altura_pivote: float = ALTURA_PIVOTE_DEFAULT:
	set(nuevo_valor):
		altura_pivote = nuevo_valor
		if is_node_ready():
			_aplicar_altura_pivote()

@export_category("Balanceo viento")
@export var balanceo_activo: bool = false ## Si false, el pino queda totalmente estatico
@export var velocidad_balanceo: float = 1.2 ## Oscilaciones por segundo
@export var amplitud_balanceo: float = 0.03 ## Rotacion en radianes sobre Z

@export_category("Parallax")
@export var sincronizar_parallax: bool = true ## Si false, este pino queda fijo y no hace scroll
@export var margen_atras: float = 30.0 ## Distancia tras la camara donde se recicla
@export var margen_adelante: float = 55.0 ## Distancia minima delante de la camara donde reaparece
@export var separacion_reciclaje: float = 3.0 ## Hueco en X respecto al pino mas adelantado al reciclar

static var _registro: Array[Pino2D] = []
static var _aviso_suelo_mostrado: bool = false

var _tiempo: float = 0.0
var _rotacion_visual_base: float = 0.0
var _fondo_cache: Node = null

@onready var visual: Node3D = $Visual
@onready var sprite: Sprite3D = $Visual/Pino


func _ready() -> void:
	if not _registro.has(self):
		_registro.append(self)
	if is_instance_valid(visual):
		_rotacion_visual_base = visual.rotation.z
	_aplicar_pixel_size()
	_aplicar_escala_base()
	_aplicar_altura_pivote()
	if not Engine.is_editor_hint():
		_asentar()


func _exit_tree() -> void:
	_registro.erase(self)


func _process(delta: float) -> void:
	if balanceo_activo and is_instance_valid(visual) and delta > 0.0:
		_tiempo += delta * velocidad_balanceo
		visual.rotation.z = _rotacion_visual_base + sin(_tiempo * TAU) * amplitud_balanceo
	_proceso_parallax(delta)


## Reinicia el ciclo de balanceo (util al duplicar la instancia).
func reiniciar_balanceo() -> void:
	_tiempo = 0.0
	if is_instance_valid(visual):
		visual.rotation.z = _rotacion_visual_base


func _aplicar_pixel_size() -> void:
	if not is_instance_valid(sprite):
		return
	sprite.pixel_size = pixel_size


func _aplicar_escala_base() -> void:
	if not is_instance_valid(visual):
		return
	visual.scale = escala_base


func _aplicar_altura_pivote() -> void:
	if not is_instance_valid(sprite):
		return
	sprite.position.y = altura_pivote


## Avanza a la par de la cordillera y recicla por delante de la camara.
## En el editor no se mueve: respeta tu colocacion manual.
func _proceso_parallax(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not sincronizar_parallax:
		return
	if delta <= 0.0:
		return
	var paso: float = _paso_parallax(delta)
	if paso == 0.0:
		return
	position.x -= paso
	_reciclar_si_detras()


## Lee la velocidad exacta de la cordillera desde el ParallaxFondo.
## Retorna 0.0 si el fondo no existe, esta pausado o no expone esas propiedades.
func _paso_parallax(delta: float) -> float:
	var fondo: Node = _buscar_fondo()
	if not is_instance_valid(fondo):
		return 0.0
	var activo: Variant = fondo.get("activo")
	if activo == null or not bool(activo):
		return 0.0
	var base: Variant = fondo.get("velocidad_base")
	var factor: Variant = fondo.get("factor_cordillera")
	if base == null or factor == null:
		return 0.0
	return float(base) * float(factor) * delta


## Busca el nodo "ParallaxFondo" subiendo por los padres (los pinos cuelgan del nivel).
func _buscar_fondo() -> Node:
	if is_instance_valid(_fondo_cache):
		return _fondo_cache
	var nodo: Node = get_parent()
	while is_instance_valid(nodo):
		if nodo.has_node(NOMBRE_FONDO_PARALLAX):
			_fondo_cache = nodo.get_node(NOMBRE_FONDO_PARALLAX)
			return _fondo_cache
		nodo = nodo.get_parent()
	return null


## Si quedo detras de la camara, reaparece delante asentado en el suelo (conserva su Z).
func _reciclar_si_detras() -> void:
	var cam_x: float = _obtener_x_camara()
	if is_nan(cam_x):
		return
	if global_position.x > cam_x - margen_atras:
		return
	var destino: float = cam_x + margen_adelante
	var max_x: float = -INF
	for otro in _registro:
		if otro != self and is_instance_valid(otro):
			var ox: float = (otro as Node3D).global_position.x
			if ox > max_x:
				max_x = ox
	if max_x != -INF:
		destino = maxf(destino, max_x + separacion_reciclaje)
	var destino_pos := Vector3(destino, global_position.y, global_position.z)
	var suelo_y: float = _suelo_superior_en(destino_pos)
	if not is_nan(suelo_y):
		destino_pos.y = suelo_y + _mitad_visible()
	global_position = destino_pos


## Apoya la base visible del pino sobre el suelo (solo en juego).
## No toca X/Z: respeta tu colocacion manual del editor.
func _asentar() -> void:
	var suelo_y: float = _suelo_superior_en(global_position)
	if is_nan(suelo_y):
		if not _aviso_suelo_mostrado:
			_aviso_suelo_mostrado = true
			push_warning("[Pino2D] sin referencia de suelo (ParallaxFondo/piso). Se conserva Y manual.")
		return
	global_position.y = suelo_y + _mitad_visible()


## Tope del piso mas cercano a un punto (NAN si no hay referencia de suelo).
func _suelo_superior_en(punto: Vector3) -> float:
	var fondo: Node = _buscar_fondo()
	if not is_instance_valid(fondo) or not fondo.has_method("obtener_segmentos_piso_aliado"):
		return NAN
	var pisos: Array = fondo.call("obtener_segmentos_piso_aliado") as Array
	if pisos == null or pisos.is_empty():
		return NAN
	var mejor: Node3D = null
	var mejor_dist: float = INF
	for piso in pisos:
		if is_instance_valid(piso) and piso is Node3D:
			var p := piso as Node3D
			var dist: float = Vector2(punto.x, punto.z).distance_to(Vector2(p.global_position.x, p.global_position.z))
			if dist < mejor_dist:
				mejor_dist = dist
				mejor = p
	if mejor == null:
		return NAN
	return mejor.global_position.y + ParallaxFondoRio.SEMIALTURA_PISO_MODELO * absf(mejor.global_transform.basis.get_scale().y)


## Mitad de la altura visible del sprite en metros globales.
func _mitad_visible() -> float:
	var alto_px: float = 653.0
	if is_instance_valid(sprite) and sprite.texture != null:
		alto_px = float(sprite.texture.get_height())
	var escala_y: float = absf(global_transform.basis.get_scale().y) * escala_base.y
	return (alto_px * 0.5 * pixel_size - altura_pivote) * escala_y


func _obtener_x_camara() -> float:
	var vp: Viewport = get_viewport()
	if vp == null:
		return NAN
	var cam: Camera3D = vp.get_camera_3d()
	if not is_instance_valid(cam):
		return NAN
	return cam.global_position.x
