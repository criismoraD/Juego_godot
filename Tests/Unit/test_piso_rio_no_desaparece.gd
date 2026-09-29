extends GutTest

## Test unitario para verificar que las baldosas de 'Piso nueva version'
## no se desplacen con el parallax ni desaparezcan a medida que la canoa avanza.

const ESCENA_RIO: PackedScene = preload("res://Levels/Rio en canoa con paralax.tscn")


func test_piso_nueva_version_permanece_estatico_durante_avance() -> void:
	# Arrange
	var scene = ESCENA_RIO.instantiate()
	add_child_autofree(scene)

	var parallax: ParallaxFondoRio = scene.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	assert_not_null(parallax, "ParallaxFondo debe existir en la escena")
	assert_false(parallax.sincronizar_piso_con_cordillera, "sincronizar_piso_con_cordillera debe ser false")

	var pisos: Array[Node3D] = []
	var posiciones_iniciales: Array[Vector3] = []
	for c in scene.get_children():
		if c.name.begins_with("Piso nueva"):
			var nodo_piso := c as Node3D
			pisos.append(nodo_piso)
			posiciones_iniciales.append(nodo_piso.global_position)

	assert_gt(pisos.size(), 0, "Deben existir baldosas de Piso nueva version en la escena")

	# Act: Simular avance de canoa y procesamiento de parallax durante 300 frames
	for i in range(300):
		scene._process(0.016)
		if is_instance_valid(parallax):
			parallax._process(0.016)

	# Assert: Verificar que ninguna baldosa haya cambiado de posición ni desaparecido
	for i in range(pisos.size()):
		var p: Node3D = pisos[i]
		var pos_esperada: Vector3 = posiciones_iniciales[i]
		assert_almost_eq(p.global_position.x, pos_esperada.x, 0.01,
			"La baldosa %s no debe desplazarse en X durante el avance" % p.name)
		assert_almost_eq(p.global_position.y, pos_esperada.y, 0.01,
			"La baldosa %s no debe cambiar en Y" % p.name)
		assert_almost_eq(p.global_position.z, pos_esperada.z, 0.01,
			"La baldosa %s no debe cambiar en Z" % p.name)
		assert_true(p.visible, "La baldosa %s debe permanecer visible" % p.name)
