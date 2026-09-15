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

@export_category("Pasajera (Protagonista)")
@export var limitar_pasajera_a_canoa: bool = true  ## Si true, la protagonista no puede salir de la canoa al moverse
@export var limite_pasajera_x: Vector2 = Vector2(-0.5, 0.4)  ## Rango local X donde puede moverse
@export var limite_pasajera_z: Vector2 = Vector2(-0.15, 0.15)  ## Rango local Z donde puede moverse

@export_category("Sonido de Travesía (sonido_canoa_por_el_rio)")
## Control directo del volumen del sonido de la canoa en el Inspector (dB)
@export_range(-30.0, 12.0, 0.5) var volumen_sonido_canoa_db: float = -3.0:
	set(v):
		volumen_sonido_canoa_db = v
		volumen_navegacion_db = v

## Tono / pitch del sonido de navegación
@export_range(0.5, 2.0, 0.05) var pitch_sonido_canoa: float = 1.0:
	set(v):
		pitch_sonido_canoa = v
		pitch_navegacion = v

const Y_PISO_CANOA: float = 0.3  ## Altura del piso de la canoa donde se posa la protagonista

# === ONREADY ===
@onready var pasajera: Node3D = find_child("Protagonista", true, false) as Node3D

# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	super._ready()
	_sincronizar_plano_z_pasajera()
	if is_instance_valid(pasajera):
		pasajera.position.z = 0.0
	if navegacion_continua:
		iniciar_travesia()


func _physics_process(_delta: float) -> void:
	_sincronizar_plano_z_pasajera()
	_sujetar_pasajera()


func _process(delta: float) -> void:
	super._process(delta)

	# Control de recorrido cíclico opcional
	if es_ciclica and _posicion_base.x >= limite_derecho_reinicio:
		_posicion_base.x = limite_izquierdo_reinicio
		position.x = _posicion_base.x

	_sujetar_pasajera()


# === FUNCIONES PÚBLICAS ===
## Inicia la travesía hacia la derecha a velocidad constante y activa el sonido.
func iniciar_travesia(vel: float = -1.0) -> void:
	var v: float = vel if vel > 0.0 else velocidad_avance
	navegar_hacia_x(100000.0, v)
	_actualizar_sonido_navegacion()


## Retorna el reproductor de audio de navegación de la canoa.
func obtener_audio_navegacion() -> AudioStreamPlayer:
	if not is_instance_valid(_audio_navegacion):
		_inicializar_sonido_navegacion()
	return _audio_navegacion


func _sincronizar_plano_z_pasajera() -> void:
	if not is_instance_valid(pasajera):
		pasajera = find_child("Protagonista", true, false) as Node3D
	if not is_instance_valid(pasajera):
		return
	if "plano_profundidad_z" in pasajera:
		pasajera.set("plano_profundidad_z", global_position.z)


func _sujetar_pasajera() -> void:
	if not limitar_pasajera_a_canoa:
		return
	if not is_instance_valid(pasajera):
		pasajera = find_child("Protagonista", true, false) as Node3D
		if not is_instance_valid(pasajera):
			return

	_sincronizar_plano_z_pasajera()

	pasajera.position.x = clampf(pasajera.position.x, limite_pasajera_x.x, limite_pasajera_x.y)
	pasajera.position.z = clampf(pasajera.position.z, limite_pasajera_z.x, limite_pasajera_z.y)

	# Prevenir caídas al vacío si la física de la canoa en movimiento pierde contacto con el piso
	if pasajera.position.y < 0.1:
		pasajera.position.y = Y_PISO_CANOA
		if "velocity" in pasajera:
			pasajera.velocity.y = 0.0
