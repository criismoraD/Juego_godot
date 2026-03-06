extends Node3D
class_name Tronco

## Tronco flotante con movimiento de río y oscilaciones naturales.

# === MOVIMIENTO EN X ===
@export_category("Movimiento")
@export var velocidad_x: float = 1.0 ## Velocidad de desplazamiento en eje X (dirección del río)

# === OSCILACIONES ===
@export_category("Oscilación - Flotación (Y)")
@export var amplitud_y: float = 0.15 ## Amplitud del sube y baja (metros)
@export var frecuencia_y: float = 1.2 ## Velocidad de oscilación vertical

@export_category("Oscilación - Balanceo (Roll Z)")
@export var amplitud_roll: float = 3.0 ## Amplitud del balanceo lateral (grados)
@export var frecuencia_roll: float = 0.8 ## Velocidad del balanceo

@export_category("Oscilación - Cabeceo (Pitch X)")
@export var amplitud_pitch: float = 2.0 ## Amplitud del cabeceo frontal (grados)
@export var frecuencia_pitch: float = 0.6 ## Velocidad del cabeceo

# === INTERNOS ===
var _tiempo: float = 0.0
var _pos_inicial: Vector3
var _rot_inicial: Vector3
var _fase_y: float
var _fase_roll: float
var _fase_pitch: float

func _ready():
	_pos_inicial = position
	_rot_inicial = rotation_degrees
	# Fases aleatorias para que cada instancia tenga movimiento diferente
	_fase_y = randf() * TAU
	_fase_roll = randf() * TAU
	_fase_pitch = randf() * TAU

func _process(delta: float):
	_tiempo += delta

	# Movimiento lineal en X (río arrastra el tronco)
	position.x = _pos_inicial.x + velocidad_x * _tiempo

	# Oscilación vertical (flotación)
	position.y = _pos_inicial.y + amplitud_y * sin(_tiempo * frecuencia_y * TAU + _fase_y)

	# Balanceo lateral (roll en Z)
	rotation_degrees.z = _rot_inicial.z + amplitud_roll * sin(_tiempo * frecuencia_roll * TAU + _fase_roll)

	# Cabeceo frontal (pitch en X)
	rotation_degrees.x = _rot_inicial.x + amplitud_pitch * sin(_tiempo * frecuencia_pitch * TAU + _fase_pitch)
