extends "res://addons/gut/test.gd"

## Script TEMPORAL de medicion: AABB del globo destruido vs intacto.
## Se eliminara tras usarlo.

const GLOBO_SCENE := preload("res://Entities/Enemigo_GloboAerostatico/GloboAerostatico.tscn")
const WRECK_SCENE = preload("res://Entities/Enemigo_GloboAerostatico/Globo_destruido.glb")


func test_medir_aabb_wreck_vs_intacto():
	# Wreck crudo (escala natural del glb)
	var wreck = WRECK_SCENE.instantiate()
	add_child_autofree(wreck)
	await get_tree().process_frame
	var aabb_w: AABB = AABB()
	var primero: bool = true
	for m in wreck.find_children("*", "MeshInstance3D", true, false):
		var ab: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		if primero:
			aabb_w = ab
			primero = false
		else:
			aabb_w = aabb_w.merge(ab)
	print("=== WRECK CRUDO === size: ", aabb_w.size, " pos: ", aabb_w.position)

	# Intacto: nodo interno y su AABB con transform
	var globo = GLOBO_SCENE.instantiate()
	add_child_autofree(globo)
	await get_tree().process_frame
	var interno := globo.get_node_or_null("PivotBamboleo/ModeloGlobo/Globo aerostatico")
	assert_not_null(interno, "Debe existir el nodo interno del globo intacto")
	var aabb_i: AABB = AABB()
	primero = true
	for m in interno.find_children("*", "MeshInstance3D", true, false) + [interno]:
		if m is MeshInstance3D:
			var ab: AABB = m.global_transform * m.get_aabb()
			if primero:
				aabb_i = ab
				primero = false
			else:
				aabb_i = aabb_i.merge(ab)
	print("=== INTACTO (con transform) === size: ", aabb_i.size, " pos: ", aabb_i.position)
	print("=== TRANSFORM INTERNO === ", interno.transform)
	print("=== WRECK ROOT NAME === ", wreck.name, " hijos: ", wreck.get_children().map(func(c): return str(c.name)))
	assert_true(true)
