extends ImpEnemy
class_name ImpEstandarte

## Imp con estandarte para el Nivel 0 (modo pacifista).
## Hereda todo el comportamiento de ImpEnemy.
## El estandarte y casco ya están configurados en ImpEnemyEstandarte.tscn.

func _on_enemy_ready():
	super._on_enemy_ready()
	# Restaurar materiales originales del casco y estandarte
	# que fueron sobreescritos por _aplicar_material_imp()
	_restaurar_materiales_accesorios()

func _restaurar_materiales_accesorios():
	# Buscar los nodos del estandarte y casco (definidos en la escena .tscn)
	var estandarte_node = find_child("Estandarte", true, false)
	var casco_node = find_child("CASCO_ESTANDARTE", true, false)

	for accesorio in [estandarte_node, casco_node]:
		if not accesorio or not is_instance_valid(accesorio):
			continue
		var meshes = accesorio.find_children("*", "MeshInstance3D", true, false)
		# Si el accesorio es un MeshInstance3D, incluirlo también
		if accesorio is MeshInstance3D:
			meshes.append(accesorio)
		for mesh in meshes:
			mesh.material_override = null # Quitar override, usa material del GLB
