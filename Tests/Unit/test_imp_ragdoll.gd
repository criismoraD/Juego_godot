extends "res://addons/gut/test.gd"

var ImpCuerpoRagdollScript = load("res://TEST_/IMP_EXPLOTADO/ImpCuerpoRagdoll.gd")
var TestImpRagdollScene = load("res://TEST_/IMP_EXPLOTADO/Test_Imp_Ragdoll.tscn")
var ImpCuerpoRagdollScene = load("res://TEST_/IMP_EXPLOTADO/ImpCuerpoRagdoll.tscn")


func test_escenas_existen_y_cargan():
	# Arrange & Act
	var test_inst = TestImpRagdollScene.instantiate()
	var ragdoll_inst = ImpCuerpoRagdollScene.instantiate()

	# Assert
	assert_not_null(test_inst, "La escena Test_Imp_Ragdoll.tscn debe instanciarse correctamente")
	assert_not_null(ragdoll_inst, "La escena ImpCuerpoRagdoll.tscn debe instanciarse correctamente")

	test_inst.free()
	ragdoll_inst.free()


func test_ragdoll_inicializacion_y_activacion():
	# Arrange
	var ragdoll_node = ImpCuerpoRagdollScene.instantiate()
	add_child_autofree(ragdoll_node)

	# Assert 1: Skeleton encontrado
	assert_not_null(ragdoll_node.skeleton, "Debe encontrar el Skeleton3D en IMP_CUERPO")
	assert_gt(ragdoll_node._physical_bones.size(), 0, "Debe generar los PhysicalBone3D para los huesos")

	# Act: Activar Ragdoll
	assert_false(ragdoll_node.is_ragdoll_active, "Inicialmente el ragdoll debe estar inactivo")
	ragdoll_node.activar_ragdoll(Vector3(0.0, 5.0, 0.0))

	# Assert 2: Ragdoll activo
	assert_true(ragdoll_node.is_ragdoll_active, "is_ragdoll_active debe ser true tras activar_ragdoll")

	# Act 3: Detener Ragdoll
	ragdoll_node.detener_ragdoll()
	assert_false(ragdoll_node.is_ragdoll_active, "is_ragdoll_active debe ser false tras detener_ragdoll")
