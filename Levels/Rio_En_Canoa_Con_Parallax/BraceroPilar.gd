@tool
class_name BraceroPilar
extends Node3D

## Wrapper posicionable para el bracero pilar en el nivel del rio.
## Aplica el material con textura a todas las mallas importadas del GLB,
## sin depender del nombre interno del nodo importado.

const INDICE_SUPERFICIE_PRINCIPAL: int = 0

@export var material_bracero: StandardMaterial3D:
	set(nuevo_material):
		material_bracero = nuevo_material
		if is_node_ready():
			_aplicar_material()

@export var fuego_activo: bool = true:
	set(v):
		fuego_activo = v
		_actualizar_estado_fuego()

@onready var modelo: Node3D = $Model
@onready var fuego_nodo: Node3D = get_node_or_null("Fuego2D") as Node3D


func _ready() -> void:
	_aplicar_material()
	_actualizar_estado_fuego()


## Retorna la instancia de Fuego2D asociada al bracero.
func obtener_fuego() -> Fuego2D:
	if not is_instance_valid(fuego_nodo):
		fuego_nodo = find_child("Fuego2D", true, false) as Node3D
	return fuego_nodo as Fuego2D


func _actualizar_estado_fuego() -> void:
	var f := obtener_fuego()
	if is_instance_valid(f):
		if f.has_method("set_fuego_activo"):
			f.call("set_fuego_activo", fuego_activo)
		else:
			f.visible = fuego_activo


## Aplica el material configurado a la instancia del modelo.
func aplicar_material() -> void:
	_aplicar_material()


func _aplicar_material() -> void:
	if material_bracero == null:
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
		malla_instancia.material_override = material_bracero
		if malla_instancia.mesh != null and malla_instancia.mesh.get_surface_count() > INDICE_SUPERFICIE_PRINCIPAL:
			malla_instancia.set_surface_override_material(INDICE_SUPERFICIE_PRINCIPAL, material_bracero)
	for hijo in nodo.get_children():
		_aplicar_a_instancias(hijo)
