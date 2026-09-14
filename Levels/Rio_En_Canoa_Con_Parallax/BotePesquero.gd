@tool
class_name BotePesquero
extends Node3D

## Bote pesquero con bamboleo suave de flotación para el nivel del rio.
## Aplica el material con textura a todas las mallas importadas del GLB
## y mece solo al hijo "Model": el nodo raíz queda libre para posicionarlo.

const INDICE_SUPERFICIE_PRINCIPAL: int = 0

# === EXPORTS ===
@export_category("Textura")
@export var material_bote: StandardMaterial3D:
	set(nuevo_material):
		material_bote = nuevo_material
		if is_node_ready():
			_aplicar_material()

@export_category("Flotación")
@export var flotacion_activa: bool = true  ## Si false, el bote queda quieto
@export var amplitud_floteo: float = 0.08  ## Sube y baja en metros (espacio local)
@export var velocidad_floteo: float = 0.9  ## Oscilaciones por segundo
@export var amplitud_balanceo: float = 1.5  ## Vaivén lateral en grados
@export var amplitud_cabeceo: float = 1.0  ## Vaivén proa-popa en grados

# === VARIABLES PRIVADAS ===
var _tiempo: float = 0.0
var _pos_modelo_base: Vector3 = Vector3.ZERO

# === ONREADY ===
@onready var modelo: Node3D = $Model


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_aplicar_material()
	if is_instance_valid(modelo):
		_pos_modelo_base = modelo.position


func _process(delta: float) -> void:
	if not flotacion_activa or not is_instance_valid(modelo):
		return
	if delta <= 0.0:
		return
	_tiempo += delta * velocidad_floteo
	_aplicar_flotacion()


# === FUNCIONES PÚBLICAS ===
## Aplica el material configurado a la instancia del modelo.
func aplicar_material() -> void:
	_aplicar_material()


# === FUNCIONES PRIVADAS ===
func _aplicar_material() -> void:
	if material_bote == null:
		return
	var raiz_modelo: Node = modelo
	if not is_instance_valid(raiz_modelo):
		raiz_modelo = find_child("Model", true, false)
		if raiz_modelo == null:
			return
	_aplicar_a_instancias(raiz_modelo)


func _aplicar_a_instancias(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var malla_instancia: MeshInstance3D = nodo as MeshInstance3D
		malla_instancia.material_override = material_bote
		if malla_instancia.mesh != null and malla_instancia.mesh.get_surface_count() > INDICE_SUPERFICIE_PRINCIPAL:
			malla_instancia.set_surface_override_material(INDICE_SUPERFICIE_PRINCIPAL, material_bote)
	for hijo in nodo.get_children():
		_aplicar_a_instancias(hijo)


func _aplicar_flotacion() -> void:
	modelo.position = _pos_modelo_base + Vector3(0.0, sin(_tiempo * TAU) * amplitud_floteo, 0.0)
	modelo.rotation = Vector3(
		sin(_tiempo * TAU * 0.75) * deg_to_rad(amplitud_cabeceo),
		0.0,
		sin(_tiempo * TAU * 0.6) * deg_to_rad(amplitud_balanceo)
	)
