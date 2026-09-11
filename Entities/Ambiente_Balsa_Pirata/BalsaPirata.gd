class_name BalsaPirata
extends Node3D
## Balsa pirata de ambientación: flota sobre el agua con vaivén continuo
## y puede navegar a lo largo del eje X hacia un punto de parada.
##
## Al igual que la Canoa Aliada, el modelo GLB no trae animaciones horneadas,
## por lo que la flotación se genera por código mediante ondas sinusoidales:
##   - Flotación (Y): oscilación vertical respecto a la línea de flotación.
##   - Balanceo (Roll Z): mecida lateral.
##   - Cabeceo (Pitch X): proa y popa suben alternadamente.
##   - Deriva (X/Z): leve oscilación por corrientes de agua.
##   - Guinada (Yaw Y): giro suave sobre la superficie.
##
## Permite desplazamiento guiado en X hacia un punto de parada mediante `navegar_hacia_x()`,
## emitiendo la señal `destino_alcanzado` al llegar y manteniendo la flotación.

# === SEÑALES ===
signal destino_alcanzado

# === CONSTANTES ===
const FASE_ALEATORIA: float = -1.0  ## Centinela: al iniciar, genera una fase aleatoria
const UMBRAL_LLEGADA_X: float = 0.05  ## Tolerancia en metros para considerar destino alcanzado

# === FLOTACIÓN VERTICAL (Y) ===
@export_category("Flotación Vertical (Y)")
@export var amplitud_flotacion: float = 0.06  ## Amplitud del sube y baja sobre el agua (metros)
@export var frecuencia_flotacion: float = 0.32  ## Velocidad de oscilación vertical (Hz)

# === BALANCEO DE COSTADO (ROLL Z) ===
@export_category("Balanceo Lateral (Roll Z)")
@export var amplitud_balanceo: float = 2.2  ## Amplitud del balanceo lateral (grados)
@export var frecuencia_balanceo: float = 0.25  ## Velocidad del balanceo (Hz)

# === CABECEO PROA-POPA (PITCH X) ===
@export_category("Cabeceo Frontal (Pitch X)")
@export var amplitud_cabeceo: float = 1.8  ## Amplitud del cabeceo frontal (grados)
@export var frecuencia_cabeceo: float = 0.38  ## Velocidad del cabeceo (Hz)

# === DERIVA HORIZONTAL (X / Z) ===
@export_category("Deriva Horizontal")
@export var amplitud_deriva_x: float = 0.04  ## Amplitud de la deriva por corriente (metros)
@export var frecuencia_deriva_x: float = 0.10  ## Velocidad de la deriva en X (Hz)
@export var amplitud_deriva_z: float = 0.05  ## Amplitud de la deriva transversal (metros)
@export var frecuencia_deriva_z: float = 0.08  ## Velocidad de la deriva en Z (Hz)

# === GUINADA (YAW Y) ===
@export_category("Guinada (Yaw Y)")
@export var amplitud_guinada: float = 1.6  ## Amplitud del giro lento sobre el agua (grados)
@export var frecuencia_guinada: float = 0.12  ## Velocidad de la guinada (Hz)

# === COMPORTAMIENTO Y NAVEGACIÓN ===
@export_category("Comportamiento")
@export var capa_visual: int = 2  ## Capa de renderizado (Fondo = 2)
@export var flotar_al_iniciar: bool = true  ## Si true, comienza a flotar desde el primer frame
@export var escala_tiempo: float = 1.0  ## Multiplicador global de la velocidad de animación
@export var fase_flotacion: float = FASE_ALEATORIA
@export var fase_balanceo: float = FASE_ALEATORIA
@export var fase_cabeceo: float = FASE_ALEATORIA
@export var fase_deriva_x: float = FASE_ALEATORIA
@export var fase_deriva_z: float = FASE_ALEATORIA
@export var fase_guinada: float = FASE_ALEATORIA

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


const MAT_BALSA: Material = preload("res://TEST_/Balsa piarata/Balsa piarata_MAT.tres")

# === ROTACIÓN Y ORIENTACIÓN ===
@export_category("Orientación")
@export var rotacion_y_proa: float = 180.0  ## Grados Y para que la balsa apunte hacia la izquierda

# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	if not is_zero_approx(rotacion_y_proa) and is_zero_approx(rotation_degrees.y):
		rotation_degrees.y = rotacion_y_proa
	_posicion_base = position
	_rotacion_base = rotation_degrees
	_asegurar_materiales()
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
	for hijo in find_children("*", "TripulanteBarcoFondoGoblinGirl", true, false):
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


## Indica si la balsa está en movimiento horizontal hacia su destino.
func esta_navegando() -> bool:
	return _navegando


## Inicia (o reanuda) el vaivén de la balsa.
func flotar() -> void:
	_flotando = true
	set_process(true)


## Detiene el vaivén y devuelve la balsa a su transformada base.
func detener() -> void:
	_flotando = false
	_navegando = false
	set_process(false)
	_restaurar_transformada_base()


## Indica si la balsa se está meciendo actualmente sobre el agua.
func esta_flotando() -> bool:
	return _flotando


## Reinicia el ciclo de flotación desde cero, regenerando las fases aleatorias.
func reiniciar() -> void:
	_tiempo = 0.0
	_inicializar_fases()
	_restaurar_transformada_base()


## Fija la posición base (sin desfase sinusoidal).
func fijar_posicion_base(nueva_pos: Vector3) -> void:
	_posicion_base = nueva_pos
	position = _posicion_base


## Retorna la posición base actual.
func obtener_posicion_base() -> Vector3:
	return _posicion_base


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


## Rotación absoluta (en grados) de la balsa para un instante dado.
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


func _asegurar_materiales() -> void:
	if not MAT_BALSA:
		return
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if is_instance_valid(mi) and mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				mi.set_surface_override_material(s, MAT_BALSA)


func _aplicar_capa_visual_recursiva(nodo: Node) -> void:
	if nodo is VisualInstance3D:
		nodo.layers = capa_visual
	for hijo in nodo.get_children():
		_aplicar_capa_visual_recursiva(hijo)


