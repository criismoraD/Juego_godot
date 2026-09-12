class_name CanoaProtagonistaRio
extends CanoaAliada

## Canoa aliada que transporta a la protagonista en travesía fluvial continua hacia la derecha.
## Hereda toda la cinemática de flotación sinusoidal y balanceo sobre el agua de CanoaAliada.

# === EXPORTS ===
@export_category("Travesía Fluvial")
@export var velocidad_avance: float = 0.65  ## Velocidad de avance horizontal hacia la derecha (m/s)
@export var navegacion_continua: bool = true  ## Si true, navega permanentemente hacia la derecha
@export var limite_derecho_reinicio: float = 14.0  ## Si supera esta X, reaparece suavemente por la izquierda si es cíclico
@export var limite_izquierdo_reinicio: float = -14.0
@export var es_ciclica: bool = false  ## Si true, reinicia su posición en X al salir de pantalla

# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	super._ready()
	if navegacion_continua:
		iniciar_travesia()


func _process(delta: float) -> void:
	super._process(delta)

	# Control de recorrido cíclico opcional
	if es_ciclica and _posicion_base.x >= limite_derecho_reinicio:
		_posicion_base.x = limite_izquierdo_reinicio
		position.x = _posicion_base.x


# === FUNCIONES PÚBLICAS ===
## Inicia la travesía hacia la derecha a velocidad constante.
func iniciar_travesia(vel: float = -1.0) -> void:
	var v: float = vel if vel > 0.0 else velocidad_avance
	navegar_hacia_x(100000.0, v)
