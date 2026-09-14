@tool
class_name TulemakiRebote
extends Node3D

## Animación idle de rebote tipo pulpo para el tulemaki del nivel del rio.
## Pulso gelatinoso (squash & stretch con conservación de volumen),
## flotación vertical y leve balanceo. Solo anima al hijo "Visual":
## el nodo raíz queda libre para posicionarlo en el editor.

# === CONSTANTES ===
const FASE_BALANCEO: float = 0.5
const FACTOR_CONSERVACION_VOLUMEN: float = 0.6
const AMPLITUD_BALANCEO: float = 0.05

# === EXPORTS ===
@export_category("Rebote pulpo")
@export var animacion_activa: bool = true  ## Si false, congela al tulemaki en su pose base
@export var velocidad: float = 2.2  ## Pulsos por segundo del manto
@export var amplitud_rebote: float = 0.08  ## Intensidad del squash & stretch (0.0 = rígido)
@export var altura_flote: float = 0.35  ## Desplazamiento vertical de la flotación en metros
@export var escala_base: Vector3 = Vector3.ONE  ## Escala de referencia sobre la que pulsa

# === VARIABLES PRIVADAS ===
var _tiempo: float = 0.0
var _pos_visual_base: Vector3 = Vector3.ZERO

# === ONREADY ===
@onready var visual: Node3D = $Visual


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	if is_instance_valid(visual):
		_pos_visual_base = visual.position
		visual.scale = escala_base


func _process(delta: float) -> void:
	if not animacion_activa or not is_instance_valid(visual):
		return
	if delta <= 0.0:
		return
	_tiempo += delta * velocidad
	_aplicar_rebote()


# === FUNCIONES PÚBLICAS ===
## Reinicia el ciclo de rebote (útil al reutilizar la instancia).
func reiniciar_rebote() -> void:
	_tiempo = 0.0


# === FUNCIONES PRIVADAS ===
func _aplicar_rebote() -> void:
	var pulso: float = sin(_tiempo * TAU)
	var estiron_y: float = 1.0 + pulso * amplitud_rebote
	var encogido_xz: float = 1.0 - pulso * amplitud_rebote * FACTOR_CONSERVACION_VOLUMEN
	visual.scale = Vector3(
		escala_base.x * encogido_xz,
		escala_base.y * estiron_y,
		escala_base.z * encogido_xz
	)
	visual.position = _pos_visual_base + Vector3(0.0, sin(_tiempo * TAU * FASE_BALANCEO) * altura_flote, 0.0)
	visual.rotation.z = sin(_tiempo * TAU * FASE_BALANCEO) * AMPLITUD_BALANCEO
