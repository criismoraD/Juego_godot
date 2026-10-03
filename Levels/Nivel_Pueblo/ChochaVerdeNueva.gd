@tool
class_name ChochaVerdeNueva
extends Node3D

## Wrapper posicionable para Chocha verde nueva en el nivel pueblo.
## Aplica el material con textura a la malla importada directamente desde Levels/Nivel_Pueblo/Chocha verde nueva.glb.

const INDICE_SUPERFICIE_PRINCIPAL: int = 0
const CAPA_FONDO_DEFAULT: int = 2

@export var material_choza: StandardMaterial3D:
	set(nuevo_material):
		material_choza = nuevo_material
		if is_node_ready():
			_aplicar_material()

@export_flags_3d_render var capa_visual: int = 1:
	set(nueva_capa):
		capa_visual = nueva_capa
		if is_node_ready():
			_aplicar_capa_visual(self)

@onready var modelo: Node3D = %Model if has_node("%Model") else ($Model if has_node("Model") else null)


func _ready() -> void:
	if "fondo" in name.to_lower():
		capa_visual = CAPA_FONDO_DEFAULT
	_aplicar_material()
	_aplicar_capa_visual(self)


func _aplicar_material() -> void:
	if not material_choza:
		return
	var raiz_modelo: Node = modelo
	if not is_instance_valid(raiz_modelo):
		raiz_modelo = find_child("Model", true, false)
		if not raiz_modelo:
			raiz_modelo = self
	_aplicar_a_instancias(raiz_modelo)


func _aplicar_a_instancias(nodo: Node) -> void:
	if not nodo:
		return
	if nodo is MeshInstance3D:
		var malla_instancia: MeshInstance3D = nodo as MeshInstance3D
		malla_instancia.material_override = material_choza
		if malla_instancia.mesh != null and malla_instancia.mesh.get_surface_count() > INDICE_SUPERFICIE_PRINCIPAL:
			malla_instancia.set_surface_override_material(INDICE_SUPERFICIE_PRINCIPAL, material_choza)
	for hijo: Node in nodo.get_children():
		_aplicar_a_instancias(hijo)


func _aplicar_capa_visual(nodo: Node) -> void:
	if not is_instance_valid(nodo):
		return
	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = capa_visual
	for hijo: Node in nodo.get_children():
		_aplicar_capa_visual(hijo)
