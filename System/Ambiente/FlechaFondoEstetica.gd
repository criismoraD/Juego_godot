class_name FlechaFondoEstetica
extends Node3D
## Proyectil estético de ambientación para el combate de fondo entre embarcaciones.
##
## Características:
## - Renderizado exclusivo en la Capa Visual 2 (layers = 2).
## - Trayectoria parabólica suave sobre el agua sin colisiones de daño.
## - Desaparece al tocar el nivel del agua o al agotar su tiempo de vida.

# === CONSTANTES ===
const NIVEL_AGUA_DEFECTO: float = -0.55
const TIEMPO_VIDA_DEFECTO: float = 3.5

# === CONFIGURACIÓN ===
@export_category("Visual")
@export var capa_visual: int = 2
@export var es_enemiga: bool = false

@export_category("Física")
@export var gravedad: float = 3.8  ## Aceleración de gravedad estética
@export var tiempo_vida_max: float = TIEMPO_VIDA_DEFECTO
@export var nivel_agua: float = NIVEL_AGUA_DEFECTO

# === ESTADO PRIVADO ===
var _velocidad: Vector3 = Vector3.ZERO
var _tiempo_vivo: float = 0.0
var _activa: bool = false

# === REFERENCIAS DE NODOS ===
@onready var _modelo_aliado: Node3D = find_child("FlechaAliada", true, false)
@onready var _modelo_enemigo: Node3D = find_child("FlechaEnemiga", true, false)


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	add_to_group("flechas_fondo_esteticas")
	_aplicar_capa_visual_recursiva(self)
	_actualizar_variante_visual()


func _process(delta: float) -> void:
	if delta <= 0.0 or not _activa:
		return

	_tiempo_vivo += delta
	if _tiempo_vivo >= tiempo_vida_max or global_position.y <= nivel_agua:
		queue_free()
		return

	# Movimiento parabólico
	_velocidad.y -= gravedad * delta
	global_position += _velocidad * delta

	# Rotación hacia la dirección de avance
	if _velocidad.length_squared() > 0.01:
		var dir_normalizada: Vector3 = _velocidad.normalized()
		var target: Vector3 = global_position + dir_normalizada
		if not is_equal_approx(absf(dir_normalizada.dot(Vector3.UP)), 1.0):
			look_at(target, Vector3.UP)


# === FUNCIONES PÚBLICAS ===
## Inicializa la flecha en una posición global dada con vector de velocidad y variante.
func iniciar(posicion_inicial: Vector3, velocidad_inicial: Vector3, variante_enemiga: bool = false, gravedad_custom: float = -1.0) -> void:
	global_position = posicion_inicial
	_velocidad = velocidad_inicial
	es_enemiga = variante_enemiga
	if gravedad_custom > 0.0:
		gravedad = gravedad_custom
	_activa = true
	_tiempo_vivo = 0.0
	_actualizar_variante_visual()
	if _velocidad.length_squared() > 0.01:
		var dir: Vector3 = _velocidad.normalized()
		if not is_equal_approx(absf(dir.dot(Vector3.UP)), 1.0):
			look_at(global_position + dir, Vector3.UP)


# === FUNCIONES PRIVADAS ===
func _actualizar_variante_visual() -> void:
	if is_instance_valid(_modelo_aliado):
		_modelo_aliado.visible = not es_enemiga
	if is_instance_valid(_modelo_enemigo):
		_modelo_enemigo.visible = es_enemiga


func _aplicar_capa_visual_recursiva(nodo: Node) -> void:
	if nodo is VisualInstance3D:
		nodo.layers = capa_visual
	for hijo in nodo.get_children():
		_aplicar_capa_visual_recursiva(hijo)
