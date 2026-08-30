class_name CanoaAliada
extends Node3D
## Canoa aliada de ambientación: flota sobre el agua con un vaivén suave y continuo.
##
## El modelo GLB no trae animaciones horneadas, por lo que el movimiento se genera
## por código combinando oscilaciones sinusoidales desfasadas:
##   - Flotación (Y): sube y baja respecto a la línea de flotación.
##   - Balanceo (Roll Z): se mece de costado.
##   - Cabeceo (Pitch X): proa y popa suben alternadamente.
##   - Deriva (X/Z): se desplaza lentamente dentro del cauce.
##   - Guinada (Yaw Y): gira muy despacio sobre la superficie.
##
## La lógica matemática vive en funciones puras (calcular_desplazamiento /
## calcular_rotacion_grados) para poder testearse unitariamente sin árbol de nodos.

# === CONSTANTES ===
const FASE_ALEATORIA: float = -1.0  ## Centinela: al iniciar, genera una fase aleatoria

# === FLOTACIÓN VERTICAL (Y) ===
@export_category("Flotación Vertical (Y)")
@export var amplitud_flotacion: float = 0.05  ## Amplitud del sube y baja sobre el agua (metros)
@export var frecuencia_flotacion: float = 0.35  ## Velocidad de la oscilación vertical (Hz)

# === BALANCEO DE COSTADO (ROLL Z) ===
@export_category("Balanceo Lateral (Roll Z)")
@export var amplitud_balanceo: float = 2.5  ## Amplitud del balanceo lateral (grados)
@export var frecuencia_balanceo: float = 0.28  ## Velocidad del balanceo (Hz)

# === CABECEO PROA-POPA (PITCH X) ===
@export_category("Cabeceo Frontal (Pitch X)")
@export var amplitud_cabeceo: float = 1.5  ## Amplitud del cabeceo proa-popa (grados)
@export var frecuencia_cabeceo: float = 0.42  ## Velocidad del cabeceo (Hz)

# === DERIVA HORIZONTAL (X / Z) ===
@export_category("Deriva Horizontal")
@export var amplitud_deriva_x: float = 0.05  ## Amplitud de la deriva a lo largo del cauce (metros)
@export var frecuencia_deriva_x: float = 0.12  ## Velocidad de la deriva en X (Hz)
@export var amplitud_deriva_z: float = 0.04  ## Amplitud de la deriva transversal (metros)
@export var frecuencia_deriva_z: float = 0.09  ## Velocidad de la deriva en Z (Hz)

# === GUINADA (YAW Y) ===
@export_category("Guinada (Yaw Y)")
@export var amplitud_guinada: float = 2.0  ## Amplitud del giro lento sobre el agua (grados)
@export var frecuencia_guinada: float = 0.15  ## Velocidad de la guinada (Hz)

# === COMPORTAMIENTO ===
@export_category("Comportamiento")
@export var flotar_al_iniciar: bool = true  ## Si true, comienza a flotar desde el primer frame
@export var escala_tiempo: float = 1.0  ## Multiplicador global de la velocidad de animación
@export var fase_flotacion: float = FASE_ALEATORIA  ## Fase inicial (radianes). -1 = aleatoria
@export var fase_balanceo: float = FASE_ALEATORIA  ## Fase inicial (radianes). -1 = aleatoria
@export var fase_cabeceo: float = FASE_ALEATORIA  ## Fase inicial (radianes). -1 = aleatoria
@export var fase_deriva_x: float = FASE_ALEATORIA  ## Fase inicial (radianes). -1 = aleatoria
@export var fase_deriva_z: float = FASE_ALEATORIA  ## Fase inicial (radianes). -1 = aleatoria
@export var fase_guinada: float = FASE_ALEATORIA  ## Fase inicial (radianes). -1 = aleatoria

# === ESTADO PRIVADO ===
var _tiempo: float = 0.0
var _posicion_base: Vector3 = Vector3.ZERO
var _rotacion_base: Vector3 = Vector3.ZERO
var _flotando: bool = false
var _fase_flotacion: float = 0.0
var _fase_balanceo: float = 0.0
var _fase_cabeceo: float = 0.0
var _fase_deriva_x: float = 0.0
var _fase_deriva_z: float = 0.0
var _fase_guinada: float = 0.0


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_posicion_base = position
	_rotacion_base = rotation_degrees
	_inicializar_fases()
	_flotando = flotar_al_iniciar
	set_process(_flotando)


func _process(delta: float) -> void:
	if not _flotando:
		return
	if delta <= 0.0:
		return

	_tiempo += delta * escala_tiempo
	_aplicar_flotacion()


# === FUNCIONES PÚBLICAS ===
## Inicia (o reanuda) el vaivén de la canoa.
func flotar() -> void:
	_flotando = true
	set_process(true)


## Detiene el vaivén y devuelve la canoa a su transformada base.
func detener() -> void:
	_flotando = false
	set_process(false)
	_restaurar_transformada_base()


## Indica si la canoa se está moviendo actualmente.
func esta_flotando() -> bool:
	return _flotando


## Reinicia el ciclo de flotación desde cero, regenerando las fases aleatorias.
func reiniciar() -> void:
	_tiempo = 0.0
	_inicializar_fases()
	_restaurar_transformada_base()


## Desplazamiento (en metros) respecto a la posición base para un instante dado.
func calcular_desplazamiento(tiempo: float) -> Vector3:
	var onda_x: float = sin(tiempo * frecuencia_deriva_x * TAU + _fase_deriva_x)
	var onda_y: float = sin(tiempo * frecuencia_flotacion * TAU + _fase_flotacion)
	var onda_z: float = sin(tiempo * frecuencia_deriva_z * TAU + _fase_deriva_z)

	return Vector3(
		amplitud_deriva_x * onda_x,
		amplitud_flotacion * onda_y,
		amplitud_deriva_z * onda_z
	)


## Rotación absoluta (en grados) de la canoa para un instante dado.
func calcular_rotacion_grados(tiempo: float) -> Vector3:
	var onda_cabeceo: float = sin(tiempo * frecuencia_cabeceo * TAU + _fase_cabeceo)
	var onda_guinada: float = sin(tiempo * frecuencia_guinada * TAU + _fase_guinada)
	var onda_balanceo: float = sin(tiempo * frecuencia_balanceo * TAU + _fase_balanceo)

	return Vector3(
		_rotacion_base.x + amplitud_cabeceo * onda_cabeceo,
		_rotacion_base.y + amplitud_guinada * onda_guinada,
		_rotacion_base.z + amplitud_balanceo * onda_balanceo
	)


# === FUNCIONES PRIVADAS ===
func _inicializar_fases() -> void:
	_fase_flotacion = _resolver_fase(fase_flotacion)
	_fase_balanceo = _resolver_fase(fase_balanceo)
	_fase_cabeceo = _resolver_fase(fase_cabeceo)
	_fase_deriva_x = _resolver_fase(fase_deriva_x)
	_fase_deriva_z = _resolver_fase(fase_deriva_z)
	_fase_guinada = _resolver_fase(fase_guinada)


func _resolver_fase(fase_configurada: float) -> float:
	if fase_configurada >= 0.0:
		return fase_configurada
	return randf() * TAU


func _aplicar_flotacion() -> void:
	position = _posicion_base + calcular_desplazamiento(_tiempo)
	rotation_degrees = calcular_rotacion_grados(_tiempo)


func _restaurar_transformada_base() -> void:
	position = _posicion_base
	rotation_degrees = _rotacion_base
