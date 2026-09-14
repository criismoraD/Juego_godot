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
## Material opcional para mallas 3D hijas (el PNG del tulemaki no lo usa).
@export var material_general: StandardMaterial3D:
	set(nuevo_material):
		material_general = nuevo_material
		if is_node_ready():
			_aplicar_material_general()

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
	_aplicar_material_general()


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


## Aplica el material opcional a las mallas 3D bajo Visual.
func _aplicar_material_general() -> void:
	if material_general == null or not is_instance_valid(visual):
		return
	_aplicar_material_a(visual)


func _aplicar_material_a(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var malla := nodo as MeshInstance3D
		malla.material_override = material_general
		if malla.mesh != null and malla.mesh.get_surface_count() > 0:
			malla.set_surface_override_material(0, material_general)
	for hijo in nodo.get_children():
		_aplicar_material_a(hijo)


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
