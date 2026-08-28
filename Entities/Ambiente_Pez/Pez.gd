class_name Pez
extends Node3D
## Pez decorativo que nada bajo el agua cada 30 segundos, alternando dirección de aparición.

# === CONFIGURACIÓN - TEMPORIZADOR Y RUTA ===
@export_category("Ciclo de Aparición")
@export var tiempo_entre_apariciones: float = 30.0  ## Tiempo de espera (en segundos) entre cada cruce de pez
@export var aparecer_al_iniciar: bool = true  ## Si true, realiza el primer cruce inmediatamente al iniciar
@export var direccion_inicial_derecha: bool = false  ## Si false, el primer pez va de derecha a izquierda

# === CONFIGURACIÓN - MOVIMIENTO ===
@export_category("Movimiento en Río")
@export var velocidad_nado: float = 0.8  ## Velocidad base de traslación horizontal
@export var limite_x_min: float = -16.0  ## Límite izquierdo del recorrido
@export var limite_x_max: float = 14.0  ## Límite derecho del recorrido

# === CONFIGURACIÓN - PROFUNDIDAD Y DERIVA ===
@export_category("Profundidad y Oscilación")
@export var profundidad_base_y: float = -0.42  ## Altura base bajo la superficie del agua
@export var amplitud_vertical: float = 0.04  ## Amplitud del suave sube y baja vertical
@export var frecuencia_vertical: float = 0.45  ## Frecuencia de la oscilación vertical (Hz)
@export var amplitud_z: float = 0.08  ## Deriva sutil lateral en el cauce
@export var frecuencia_z: float = 0.3  ## Frecuencia de la deriva lateral

# === CONFIGURACIÓN - IMPULSO DE NADO ===
@export_category("Dinámica de Nado")
@export var simular_impulso_nado: bool = true  ## Aceleraciones rítmicas por golpe de cola
@export var amplitud_impulso: float = 0.35  ## Intensidad de la propulsión
@export var frecuencia_impulso: float = 0.9  ## Ritmo de propulsión de cola

# === VARIABLES PRIVADAS ===
var _mesh: MeshInstance3D = null
var _pos_inicial: Vector3 = Vector3.ZERO
var _rot_inicial: Vector3 = Vector3.ZERO
var _tiempo: float = 0.0
var _fase_y: float = 0.0
var _fase_z: float = 0.0
var _fase_impulso: float = 0.0
var _cooldown_temporizador: float = 0.0
var _activo: bool = false
var _nadando_hacia_derecha: bool = false
var _direccion_x: float = -1.0


func _ready() -> void:
	_buscar_mesh()
	_pos_inicial = position
	_rot_inicial = rotation_degrees
	_nadando_hacia_derecha = !direccion_inicial_derecha
	
	if position.y == 0.0:
		position.y = profundidad_base_y
		_pos_inicial.y = profundidad_base_y

	if aparecer_al_iniciar:
		_iniciar_cruce()
	else:
		_activo = false
		visible = false
		_cooldown_temporizador = tiempo_entre_apariciones


func _process(delta: float) -> void:
	# 1. Gestión del temporizador de 30 segundos entre apariciones
	if not _activo:
		_cooldown_temporizador -= delta
		if _cooldown_temporizador <= 0.0:
			_iniciar_cruce()
		return

	_tiempo += delta

	# 2. Impulso dinámico de nado (ráfagas de aceleración por brazada de cola)
	var factor_impulso: float = 1.0
	if simular_impulso_nado:
		var onda_impulso: float = sin(_tiempo * frecuencia_impulso * TAU + _fase_impulso)
		factor_impulso = 1.0 + amplitud_impulso * max(0.0, onda_impulso)

	# 3. Desplazamiento horizontal según la dirección actual (1.0 = Derecha, -1.0 = Izquierda)
	position.x += _direccion_x * velocidad_nado * factor_impulso * delta

	# 4. Oscilación vertical bajo el agua (eje Y)
	var onda_y: float = sin(_tiempo * frecuencia_vertical * TAU + _fase_y)
	position.y = _pos_inicial.y + amplitud_vertical * onda_y

	# 5. Deriva suave en el río (eje Z)
	var onda_z: float = sin(_tiempo * frecuencia_z * TAU + _fase_z)
	position.z = _pos_inicial.z + amplitud_z * onda_z

	# 6. Inclinación física de nado (Pitch al subir/bajar orientado al sentido de nado)
	var velocidad_vertical_aprox: float = cos(_tiempo * frecuencia_vertical * TAU + _fase_y)
	rotation_degrees.z = _rot_inicial.z + (velocidad_vertical_aprox * 6.0 * _direccion_x)
	rotation_degrees.y = _rot_inicial.y + (onda_z * 4.0 * _direccion_x)

	# 7. Verificar si completó el recorrido para ocultarse y reiniciar temporizador
	if _direccion_x < 0.0 and position.x < limite_x_min:
		_finalizar_cruce()
	elif _direccion_x > 0.0 and position.x > limite_x_max:
		_finalizar_cruce()


func _iniciar_cruce() -> void:
	_buscar_mesh()
	# Alternar dirección en cada aparición
	_nadando_hacia_derecha = !_nadando_hacia_derecha
	_direccion_x = 1.0 if _nadando_hacia_derecha else -1.0

	# Orientar el modelo hacia la dirección de avance
	if _mesh:
		_mesh.scale.x = 1.0 if _nadando_hacia_derecha else -1.0

	# Colocar en el punto de inicio correspondiente
	if _nadando_hacia_derecha:
		position.x = limite_x_min - randf_range(0.0, 1.5)
	else:
		position.x = limite_x_max + randf_range(0.0, 1.5)

	_pos_inicial.y = randf_range(profundidad_base_y - 0.06, profundidad_base_y + 0.04)
	_pos_inicial.z = randf_range(2.3, 3.8)
	position.y = _pos_inicial.y
	position.z = _pos_inicial.z

	_fase_y = randf() * TAU
	_fase_z = randf() * TAU
	_fase_impulso = randf() * TAU
	_tiempo = 0.0

	visible = true
	_activo = true


func _finalizar_cruce() -> void:
	_activo = false
	visible = false
	_cooldown_temporizador = tiempo_entre_apariciones


func _buscar_mesh() -> void:
	if not _mesh:
		_mesh = get_node_or_null("PezMesh") as MeshInstance3D
