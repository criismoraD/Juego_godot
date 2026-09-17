extends "res://addons/gut/test.gd"

var ArrowScene = load("res://Entities/Proyectil_Flecha/Arrow.tscn")

var _arrow: Area3D = null


func after_each():
	if is_instance_valid(_arrow):
		_arrow.free()
	_arrow = null


func test_clavada_preserva_brillo_calido() -> void:
	# Arrange
	_arrow = ArrowScene.instantiate()
	get_tree().root.add_child(_arrow)

	# Act
	_arrow._stick_to_surface()

	# Assert: queda clavada con emisión propia en vez de apagarse
	assert_true(_arrow.is_stuck, "Queda clavada")
	var revisadas: int = 0
	for mesh in _arrow._cached_mesh_instances:
		if not is_instance_valid(mesh):
			continue
		var mat: Material = mesh.material_override
		if mat == null and mesh.mesh:
			mat = mesh.mesh.surface_get_material(0)
		if mat is StandardMaterial3D:
			revisadas += 1
			assert_true((mat as StandardMaterial3D).emission_enabled, "Brillo preservado en " + str(mesh.name))
	assert_gt(revisadas, 0, "Revisó al menos una malla con material estándar")
