extends "res://addons/gut/test.gd"

const ESCUDO_SCENE := preload("res://Entities/Ambiente_Escudo/Escudo.tscn")


func test_material_dano_hereda_sombreado_y_outline() -> void:
	# Arrange
	var escudo = ESCUDO_SCENE.instantiate()
	add_child_autofree(escudo)
	await get_tree().process_frame

	# Assert: el material de daño debe verse IGUAL al original (sin volverse negro)
	assert_not_null(escudo.material_original, "El material original debe guardarse en _ready")
	assert_not_null(escudo.material_dano, "El material de daño debe crearse en _ready")
	if escudo.material_original is StandardMaterial3D and escudo.material_dano is StandardMaterial3D:
		var original := escudo.material_original as StandardMaterial3D
		var dano := escudo.material_dano as StandardMaterial3D
		assert_eq(
			dano.shading_mode, original.shading_mode,
			"El material de daño debe heredar el shading_mode (UNSHADED) para no verse negro"
		)
		assert_eq(
			dano.next_pass, original.next_pass,
			"El material de daño debe heredar el next_pass del outline"
		)
		assert_eq(
			dano.albedo_texture, original.albedo_texture,
			"El material de daño debe conservar la textura original"
		)


func test_sombra_solo_en_escudos_enemigos() -> void:
	# Arrange: escudo del jugador (neutral)
	var escudo_jugador = ESCUDO_SCENE.instantiate()
	add_child_autofree(escudo_jugador)
	await get_tree().process_frame

	# Assert: el escudo del jugador NO debe tener sombra
	assert_eq(
		escudo_jugador.find_children("*", "SombraPersonaje", true, false).size(), 0,
		"Los escudos del jugador NO deben tener sombra"
	)

	# Arrange: escudo enemigo
	var escudo_enemigo = ESCUDO_SCENE.instantiate()
	escudo_enemigo.es_escudo_enemigo = true
	add_child_autofree(escudo_enemigo)
	await get_tree().process_frame

	# Assert: el escudo enemigo SÍ debe tener sombra
	var sombras := escudo_enemigo.find_children("*", "SombraPersonaje", true, false)
	assert_gt(sombras.size(), 0, "Los escudos enemigos deben tener sombra falsa circular")
	if sombras.size() > 0:
		var sombra := sombras[0] as SombraPersonaje
		assert_gt(sombra.tamano.x, 0.0, "La sombra debe tener tamaño positivo")
		assert_eq(
			sombra.prioridad_render, -128,
			"La sombra debe renderizarse con prioridad mínima para quedar DEBAJO del modelo"
		)
		assert_lt(sombra.offset_y, 0.0, "El offset Y debe ser negativo (pegada al suelo)")


func test_flash_y_dano_no_dejan_material_negro_permanente() -> void:
	# Arrange
	var escudo = ESCUDO_SCENE.instantiate()
	add_child_autofree(escudo)
	await get_tree().process_frame

	# Act: recibir un golpe no letal
	escudo.golpes_para_destruir = 3
	escudo.recibir_golpe(1)
	await wait_seconds(0.25)

	# Assert: tras el flash, la malla queda con el material de daño (no negro)
	var mesh = escudo.mesh_instance
	assert_not_null(mesh, "El escudo debe encontrar su MeshInstance3D")
	if mesh:
		var actual = mesh.get_surface_override_material(0)
		assert_eq(actual, escudo.material_dano, "Tras el flash debe volver el material de daño")
		if actual is StandardMaterial3D:
			assert_eq(
				(actual as StandardMaterial3D).shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED,
				"El material aplicado debe seguir siendo UNSHADED"
			)
