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

# === SEÑALES ===
signal destino_alcanzado

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
@export var capa_visual: int = 2  ## Capa de renderizado (Fondo = 2)
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

var _navegando: bool = false
var _x_destino: float = 0.0
var _velocidad_navegacion: float = 0.0
var _direccion_navegacion: float = 1.0


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	add_to_group("canoas_aliadas")
	_posicion_base = position
	_rotacion_base = rotation_degrees
	_inicializar_fases()
	_aplicar_capa_visual_recursiva(self)
	_flotando = flotar_al_iniciar
	set_process(_flotando or _navegando)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return

	if _navegando:
		_actualizar_navegacion(delta)

	if not _flotando:
		return

	_tiempo += delta * escala_tiempo
	_aplicar_flotacion()


# === FUNCIONES PÚBLICAS ===
## Ordena a todos los tripulantes a bordo que comiencen el combate estético.
func iniciar_combate_tripulacion() -> void:
	for hijo in find_children("*", "TripulanteBarcoFondoAllyArcher", true, false):
		if hijo.has_method("iniciar_combate"):
			hijo.iniciar_combate()


## Inicia el desplazamiento horizontal hacia una coordenada X objetivo.
func navegar_hacia_x(x_destino: float, velocidad: float) -> void:
	_x_destino = x_destino
	_velocidad_navegacion = absf(velocidad)
	_direccion_navegacion = 1.0 if _x_destino > _posicion_base.x else -1.0
	_navegando = true
	_flotando = true
	set_process(true)


## Detiene la navegación horizontal sin frenar la flotación.
func detener_navegacion() -> void:
	_navegando = false


## Indica si la canoa está en movimiento horizontal hacia su destino.
func esta_navegando() -> bool:
	return _navegando


## Fija la posición base (sin desfase sinusoidal).
func fijar_posicion_base(nueva_pos: Vector3) -> void:
	_posicion_base = nueva_pos
	position = _posicion_base


## Retorna la posición base actual.
func obtener_posicion_base() -> Vector3:
	return _posicion_base


## Inicia (o reanuda) el vaivén de la canoa.
func flotar() -> void:
	_flotando = true
	set_process(true)


## Detiene el vaivén y devuelve la canoa a su transformada base.
func detener() -> void:
	_flotando = false
	set_process(false)
	_restaurar_transformada_base()


## Oculta inmediatamente la canoa y a sus tripulantes y desactiva su procesamiento.
func ocultar_y_desactivar() -> void:
	visible = false
	_flotando = false
	_navegando = false
	set_process(false)
	for hijo in find_children("*", "TripulanteBarcoFondoAllyArcher", true, false):
		var tripulante := hijo as Node3D
		if is_instance_valid(tripulante):
			tripulante.visible = false
			tripulante.set_process(false)


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
func _actualizar_navegacion(delta: float) -> void:
	var paso: float = _velocidad_navegacion * delta * _direccion_navegacion
	var nueva_x: float = _posicion_base.x + paso

	var llego: bool = false
	if _direccion_navegacion > 0.0 and nueva_x >= _x_destino:
		llego = true
	elif _direccion_navegacion < 0.0 and nueva_x <= _x_destino:
		llego = true

	if llego:
		_posicion_base.x = _x_destino
		_navegando = false
		destino_alcanzado.emit()
	else:
		_posicion_base.x = nueva_x


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


func _aplicar_capa_visual_recursiva(nodo: Node) -> void:
	if nodo is VisualInstance3D:
		nodo.layers = capa_visual
	for hijo in nodo.get_children():
		_aplicar_capa_visual_recursiva(hijo)

