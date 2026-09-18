class_name LanzaAzulinaProjectile
extends ImpTridentProjectile

## Lanza de Azulina: mismo patrón que el tridente del imp pero más potente
## (3.0 de daño) y con mayor precisión (el tirador apenas dispersa).
## A diferencia del tridente, muestra el arma texturizada (LanzaAzulina_MAT)
## en vez del material emisivo plano: la estela sí usa el color azul
## de _init, pero la malla muestra la lanza real con su textura.

const DANO_LANZA_AZULINA: float = 1.0
const MATERIAL_LANZA: Material = preload("res://Entities/Enemigo_Azulina/LanzaAzulina_MAT.tres")


func _init() -> void:
	super._init()
	color_proyectil = Color(0.35, 0.75, 1.0)


## No crear el material emisivo del tridente: la lanza usa su textura propia.
func _preparar_visuales() -> void:
	pass


func _aplicar_visuales_cacheados() -> void:
	for mesh in _cached_mesh_instances:
		if not is_instance_valid(mesh):
			continue
		if mesh is MeshInstance3D:
			(mesh as MeshInstance3D).visible = true
			(mesh as MeshInstance3D).add_to_group("outline_meshes")
			if MATERIAL_LANZA:
				(mesh as MeshInstance3D).material_override = MATERIAL_LANZA


func _restaurar_visuales_desde_pool() -> void:
	_aplicar_visuales_cacheados()


func _aplicar_dano_a_objetivo(body: Node) -> void:
	var target := _obtener_objetivo_dano(body)
	if "last_hit_position" in target:
		target.last_hit_position = global_position
	if "last_hit_direction" in target:
		target.last_hit_direction = direction
	if target.has_method("take_damage"):
		target.take_damage(DANO_LANZA_AZULINA)
		return
	if target.has_method("recibir_dano"):
		target.recibir_dano(DANO_LANZA_AZULINA)
