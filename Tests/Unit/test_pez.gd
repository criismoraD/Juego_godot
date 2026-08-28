extends GutTest
## Test unitario para el componente Pez de ambiente acuático.
## Valida instanciación, traslación horizontal, alternancia de dirección y ciclo de 30 segundos.

var pez: Pez


func before_each():
	pez = Pez.new()


func after_each():
	if is_instance_valid(pez):
		pez.queue_free()
	await get_tree().process_frame


func test_instanciacion_correcta():
	# Arrange & Act
	# Assert
	assert_not_null(pez, "Pez debe instanciarse correctamente")
	assert_true(pez is Node3D, "Debe ser un Node3D")


func test_valores_por_defecto():
	# Assert
	assert_almost_eq(pez.velocidad_nado, 0.8, 0.01, "Velocidad default = 0.8")
	assert_almost_eq(pez.tiempo_entre_apariciones, 30.0, 0.01, "Cooldown entre apariciones = 30.0s")
	assert_almost_eq(pez.profundidad_base_y, -0.42, 0.01, "Profundidad default = -0.42")
	assert_almost_eq(pez.limite_x_min, -16.0, 0.1)
	assert_almost_eq(pez.limite_x_max, 14.0, 0.1)


func test_alternancia_de_direccion_en_cruces():
	# Arrange
	add_child(pez)
	pez.direccion_inicial_derecha = false
	pez._ready()

	# Assert primer cruce (debe ir de derecha a izquierda, _direccion_x = -1)
	assert_true(pez._activo, "Debe iniciar activo")
	assert_eq(pez._direccion_x, -1.0, "Primer cruce debe ir hacia la izquierda (-X)")

	# Act: Finalizar cruce y forzar nuevo cruce
	pez._finalizar_cruce()
	assert_false(pez._activo, "Pez debe quedar inactivo durante cooldown")
	assert_false(pez.visible, "Pez debe ocultarse durante cooldown")
	assert_almost_eq(pez._cooldown_temporizador, 30.0, 0.1, "Cooldown seteado a 30s")

	# Simular fin de temporizador de 30s
	pez._cooldown_temporizador = 0.0
	pez._process(0.1)

	# Assert segundo cruce (debe ir de izquierda a derecha, _direccion_x = +1)
	assert_true(pez._activo, "Debe reactivarse tras el cooldown")
	assert_true(pez.visible, "Debe hacerse visible al iniciar cruce")
	assert_eq(pez._direccion_x, 1.0, "Segundo cruce debe alternar hacia la derecha (+X)")


func test_instanciacion_escena_tscn():
	# Arrange
	var escena: PackedScene = preload("res://Entities/Ambiente_Pez/Pez.tscn")
	assert_not_null(escena, "Escena Pez.tscn debe existir")

	# Act
	var pez_nodo = escena.instantiate()
	add_child(pez_nodo)
	await get_tree().process_frame

	# Assert
	var mesh = pez_nodo.get_node_or_null("PezMesh")
	assert_not_null(mesh, "Debe contener el nodo PezMesh")
	assert_true(mesh is MeshInstance3D, "PezMesh debe ser MeshInstance3D")

	pez_nodo.queue_free()
	await get_tree().process_frame