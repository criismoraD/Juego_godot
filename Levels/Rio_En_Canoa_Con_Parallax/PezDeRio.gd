class_name PezDeRio
extends Node3D

## Pez de río 3D decorativo con animación de nado natural en el agua.
## Se activa únicamente cuando la cámara lo enfoca en escena, desplazándose lentamente
## de derecha a izquierda y desapareciendo al cruzar la pantalla para optimizar recursos.

# === CONSTANTES ===
const ROTACION_Y_HACIA_IZQUIERDA: float = -PI * 0.5  ## Cabeza (+Z) orientada hacia -X (izquierda)
const VELOCIDAD_NADO_DEFECTO: float = 1.15
const TIEMPO_ESPERA_DEFECTO: float = 1.0
const MARGEN_DESAPARICION_DEFECTO: float = 6.5
const TIEMPO_ADICIONAL_DESAPARICION_DEFECTO: float = 4.0
const MARGEN_ENFOQUE_X_DEFECTO: float = 7.5
const AABB_NOTIFICADOR_DEFECTO: AABB = AABB(Vector3(-1.5, -0.6, -0.6), Vector3(3.0, 1.2, 1.2))

# === EXPORTS ===
@export_category("Visual y Material")
@export var material_pez: Material:
	set(nuevo_material):
		material_pez = nuevo_material
		if is_node_ready():
			_aplicar_material()

@export_category("Activación y Enfoque de Cámara")
@export var activar_solo_al_enfocar: bool = true  ## Si true, solo se activa y nada cuando la cámara enfoca al pez en escena
@export var margen_enfoque_x: float = MARGEN_ENFOQUE_X_DEFECTO  ## Distancia horizontal máxima respecto a la cámara para considerarlo enfocado
@export var tiempo_espera_activacion: float = TIEMPO_ESPERA_DEFECTO  ## Tiempo de espera para compatibilidad / fallback
@export var autoactivar: bool = true  ## Si true, permite la activación automática (por enfoque de cámara o fallback)

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
var _ciclo_finalizado: bool = false
var _tiempo: float = 0.0
var _pos_base_y: float = 0.0
var _pos_base_z: float = 0.0
var _camara_cache: Camera3D = null
var _tiempo_fuera_pantalla: float = 0.0

# === ONREADY ===
@onready var mesh_inst: MeshInstance3D = find_child("Pez de rio", true, false) as MeshInstance3D
@onready var notifier: VisibleOnScreenNotifier3D = find_child("VisibleOnScreenNotifier3D", true, false) as VisibleOnScreenNotifier3D


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_pos_base_y = position.y
	_pos_base_z = position.z
	rotation.y = ROTACION_Y_HACIA_IZQUIERDA
	_aplicar_material()

	if Engine.is_editor_hint():
		return

	_activo = false
	visible = false

	if is_instance_valid(notifier):
		notifier.screen_entered.connect(_on_screen_entered)

	if not autoactivar:
		return

	if not activar_solo_al_enfocar:
		var timer := get_tree().create_timer(tiempo_espera_activacion)
		timer.timeout.connect(activar)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or delta <= 0.0:
		return

	if not _activo:
		if autoactivar and not _ciclo_finalizado and activar_solo_al_enfocar:
			if _camara_enfoca_pez():
				activar()
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
	if _ciclo_finalizado:
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
func _on_screen_entered() -> void:
	if autoactivar and not _activo and not _ciclo_finalizado and activar_solo_al_enfocar:
		activar()


func _camara_enfoca_pez() -> bool:
	if is_instance_valid(notifier) and notifier.is_on_screen():
		return true

	var cam := _obtener_camara()
	if not is_instance_valid(cam):
		return false

	var dx: float = global_position.x - cam.global_position.x
	if dx <= margen_enfoque_x and dx >= -margen_desaparicion:
		return true

	return false


func _desaparecer() -> void:
	_activo = false
	visible = false
	_ciclo_finalizado = true
	if destruir_al_salir:
		queue_free()


func _obtener_camara() -> Camera3D:
	if is_instance_valid(_camara_cache):
		return _camara_cache
	var vp := get_viewport()
	if vp:
		_camara_cache = vp.get_camera_3d()
	if not is_instance_valid(_camara_cache) and is_inside_tree():
		var raiz := get_tree().root if get_tree() else null
		if raiz:
			_camara_cache = raiz.find_child("CamaraPrincipal", true, false) as Camera3D
	return _camara_cache


func _obtener_x_camara() -> float:
	var cam := _obtener_camara()
	if is_instance_valid(cam):
		return cam.global_position.x
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
