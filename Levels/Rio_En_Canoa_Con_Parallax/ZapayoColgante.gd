@tool
class_name ZapayoColgante
extends Node3D

## Fruta colgante con bamboleo muy sutil para el nivel del rio.
## El pivote "Colgante" queda arriba de la fruta y oscila como péndulo;
## el nodo raíz queda libre para posicionarlo en el editor.
## Aplica el material con textura a las mallas sin depender de sus nombres.

const INDICE_SUPERFICIE_PRINCIPAL: int = 0

# === EXPORTS ===
@export_category("Fruta colgante")
@export var animacion_activa: bool = true  ## Si false, la fruta queda quieta
@export var velocidad: float = 0.5  ## Oscilaciones por segundo del péndulo
@export var amplitud_balanceo: float = 3.0  ## Vaivén lateral en grados (muy sutil)
@export var amplitud_cabeceo: float = 2.0  ## Vaivén frontal en grados (muy sutil)

@export_category("Textura")
@export var material_zapayo: StandardMaterial3D:
	set(nuevo_material):
		material_zapayo = nuevo_material
		if is_node_ready():
			_aplicar_material()

# === VARIABLES PRIVADAS ===
var _tiempo: float = 0.0

# === ONREADY ===
@onready var colgante: Node3D = $Colgante


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_aplicar_material()


func _process(delta: float) -> void:
	if not animacion_activa or not is_instance_valid(colgante):
		return
	if delta <= 0.0:
		return
	_tiempo += delta * velocidad
	_aplicar_bamboleo()


# === FUNCIONES PÚBLICAS ===
## Aplica el material configurado a la instancia del modelo.
func aplicar_material() -> void:
	_aplicar_material()


# === FUNCIONES PRIVADAS ===
func _aplicar_bamboleo() -> void:
	colgante.rotation = Vector3(
		sin(_tiempo * TAU * 0.7) * deg_to_rad(amplitud_cabeceo),
		0.0,
		sin(_tiempo * TAU) * deg_to_rad(amplitud_balanceo)
	)


func _aplicar_material() -> void:
	if material_zapayo == null or not is_instance_valid(colgante):
		return
	_aplicar_a_instancias(colgante)


func _aplicar_a_instancias(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var malla := nodo as MeshInstance3D
		malla.material_override = material_zapayo
		if malla.mesh != null and malla.mesh.get_surface_count() > INDICE_SUPERFICIE_PRINCIPAL:
			malla.set_surface_override_material(INDICE_SUPERFICIE_PRINCIPAL, material_zapayo)
	for hijo in nodo.get_children():
		_aplicar_a_instancias(hijo)
