class_name PezDeRio
extends Node3D

## Pez de río 3D decorativo con animación de nado natural en el agua.
## Se activa 1 segundo tras la entrada de la canoa, se desplaza lentamente de derecha
## a izquierda y desaparece al cruzar la pantalla para optimizar recursos.

# === CONSTANTES ===
const ROTACION_Y_HACIA_IZQUIERDA: float = -PI * 0.5  ## Cabeza (+Z) orientada hacia -X (izquierda)
const VELOCIDAD_NADO_DEFECTO: float = 1.15
const TIEMPO_ESPERA_DEFECTO: float = 1.0
const MARGEN_DESAPARICION_DEFECTO: float = 6.5
const TIEMPO_ADICIONAL_DESAPARICION_DEFECTO: float = 4.0

# === EXPORTS ===
@export_category("Visual y Material")
@export var material_pez: Material:
	set(nuevo_material):
		material_pez = nuevo_material
		if is_node_ready():
			_aplicar_material()

@export_category("Activación y Tiempo")
@export var tiempo_espera_activacion: float = TIEMPO_ESPERA_DEFECTO  ## Segundos tras inicio antes de activarse y nadar
@export var autoactivar: bool = true  ## Si true, se activa automáticamente tras el tiempo de espera

@export_category("Cinemática de Nado")
@export var velocidad: float = VELOCIDAD_NADO_DEFECTO  ## Velocidad lenta de avance hacia la izquierda (m/s)
@export var amplitud_ondulacion_y: float = 0.025  ## Sutil sube y baja vertical
@export var frecuencia_ondulacion_y: float = 1.6  ## Ritmo del sube y baja
@export var amplitud_deriva_z: float = 0.04  ## Sutil deriva lateral en Z
@export var frecuencia_deriva_z: float = 1.2  ## Ritmo de la deriva lateral

@export_category("Optimización de Recursos")
@export var margen_desaparicion: float = MARGEN_DESAPARICION_DEFECTO  ## Distancia tras la cámara donde inicia la salida de pantalla
@export var tiempo_adicional_desaparicion: float = TIEMPO_ADICIONAL_DESAPARICION_DEFECTO  ## Segundos adicionales nadando tras cruzar el margen antes de desaparecer (4.0s)
@export var destruir_al_salir: bool = true  ## Si true, llama a queue_free() al salir de escena

# === VARIABLES PRIVADAS ===
var _activo: bool = false
var _tiempo: float = 0.0
var _pos_base_y: float = 0.0
var _pos_base_z: float = 0.0
var _camara_cache: Camera3D = null
var _tiempo_fuera_pantalla: float = 0.0

# === ONREADY ===
@onready var mesh_inst: MeshInstance3D = find_child("Pez de rio", true, false) as MeshInstance3D


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_pos_base_y = position.y
	_pos_base_z = position.z
	rotation.y = ROTACION_Y_HACIA_IZQUIERDA
	_aplicar_material()

	if Engine.is_editor_hint():
		return

	if autoactivar:
		visible = false
		_activo = false
		var timer := get_tree().create_timer(tiempo_espera_activacion)
		timer.timeout.connect(activar)
	else:
		_activo = false
		visible = false


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _activo or delta <= 0.0:
		return

	_tiempo += delta

	# 1. Movimiento continuo y lento de derecha a izquierda (-X)
	global_position.x -= velocidad * delta

	# 2. Suave ondulación física vertical y lateral en el agua
	position.y = _pos_base_y + sin(_tiempo * frecuencia_ondulacion_y) * amplitud_ondulacion_y
	position.z = _pos_base_z + cos(_tiempo * frecuencia_deriva_z) * amplitud_deriva_z

	# 3. Comprobar si salió de pantalla por la izquierda para ahorrar recursos
	var x_cam: float = _obtener_x_camara()
	if global_position.x < x_cam - margen_desaparicion:
		_tiempo_fuera_pantalla += delta
		if _tiempo_fuera_pantalla >= tiempo_adicional_desaparicion:
			_desaparecer()
	else:
		_tiempo_fuera_pantalla = 0.0


# === FUNCIONES PÚBLICAS ===
## Activa el pez haciéndolo visible y comenzando su nado.
func activar() -> void:
	if not is_inside_tree():
		return
	_activo = true
	visible = true
	_tiempo_fuera_pantalla = 0.0


## Indica si el pez está actualmente activo y nadando.
func esta_activo() -> bool:
	return _activo


## Retorna el tiempo acumulado que lleva el pez nadando tras cruzar el margen de desaparición.
func obtener_tiempo_fuera_pantalla() -> float:
	return _tiempo_fuera_pantalla


## Configura la velocidad de nado horizontal del pez.
func fijar_velocidad(nueva_vel: float) -> void:
	velocidad = nueva_vel


## Permite fijar manualmente la referencia a la cámara.
func fijar_camara(cam: Camera3D) -> void:
	_camara_cache = cam


# === FUNCIONES PRIVADAS ===
func _desaparecer() -> void:
	_activo = false
	visible = false
	if destruir_al_salir:
		queue_free()


func _obtener_x_camara() -> float:
	if is_instance_valid(_camara_cache):
		return _camara_cache.global_position.x
	var vp := get_viewport()
	if vp:
		_camara_cache = vp.get_camera_3d()
	if not is_instance_valid(_camara_cache):
		var raiz := get_tree().root if get_tree() else null
		if raiz:
			_camara_cache = raiz.find_child("CamaraPrincipal", true, false) as Camera3D
	if is_instance_valid(_camara_cache):
		return _camara_cache.global_position.x
	return 0.0


func _aplicar_material() -> void:
	if material_pez == null:
		return
	_aplicar_a_instancias(self)


func _aplicar_a_instancias(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		(nodo as MeshInstance3D).material_override = material_pez
	for hijo in nodo.get_children():
		_aplicar_a_instancias(hijo)

