extends "res://addons/gut/test.gd"

const GUARDIANA_SCENE: PackedScene = preload("res://Entities/Enemigo_Goblina_Escudo_Pesado/GuardianaMoradita.tscn")
const ARROW_SCENE: PackedScene = preload("res://Entities/Proyectil_Flecha/Arrow.tscn")
const ESCUDO_SCENE: PackedScene = preload("res://Entities/Ambiente_Escudo/Escudo.tscn")
const BALLESTERA_SCENE: PackedScene = preload("res://Entities/Aliada_Ballestera/AllyBallestera.tscn")


func test_flecha_sobrecarga_max_mata_guardiana_un_golpe_cuerpo() -> void:
	# Arrange
	var guardiana = GUARDIANA_SCENE.instantiate() as GuardianaMoradita
	add_child_autofree(guardiana)
	await get_tree().process_frame
	var hp_inicial: int = guardiana.health
	assert_gt(hp_inicial, 1, "La guardiana debe iniciar con más de 1 HP")

	var arrow = ARROW_SCENE.instantiate()
	add_child_autofree(arrow)
	arrow.tipo_dueño = arrow.TipoFlecha.JUGADOR
	arrow.set_meta("sobrecarga_max", true)

	# Act: Impacto directo en el cuerpo
	arrow._on_body_entered(guardiana)

	# Assert
	assert_eq(guardiana.health, 0, "La flecha morada al 100% debe reducir la vida a 0 de un solo golpe")
	assert_eq(guardiana.current_state, GuardianaMoradita.State.DYING, "La guardiana debe pasar a estado DYING")


func test_flecha_sobrecarga_max_mata_guardiana_un_golpe_escudo() -> void:
	# Arrange
	var guardiana = GUARDIANA_SCENE.instantiate() as GuardianaMoradita
	add_child_autofree(guardiana)
	await get_tree().process_frame

	var escudo_area: Area3D = guardiana.find_child("EscudoArea", true, false) as Area3D
	assert_not_null(escudo_area, "El nodo EscudoArea debe existir en la GuardianaMoradita")

	var arrow = ARROW_SCENE.instantiate()
	add_child_autofree(arrow)
	arrow.tipo_dueño = arrow.TipoFlecha.JUGADOR
	arrow.set_meta("sobrecarga_max", true)

	# Act: Impacto en el área del escudo pesado
	arrow._on_area_entered(escudo_area)

	# Assert
	assert_eq(guardiana.health, 0, "Impactar el escudo con flecha morada al 100% debe matar a la guardiana de un solo golpe")
	assert_eq(guardiana.current_state, GuardianaMoradita.State.DYING, "La guardiana debe pasar a estado DYING")


func test_flecha_normal_no_mata_guardiana_un_golpe() -> void:
	# Arrange
	var guardiana = GUARDIANA_SCENE.instantiate() as GuardianaMoradita
	add_child_autofree(guardiana)
	await get_tree().process_frame
	var hp_inicial: int = guardiana.health

	var arrow = ARROW_SCENE.instantiate()
	add_child_autofree(arrow)
	arrow.tipo_dueño = arrow.TipoFlecha.JUGADOR
	# Sin sobrecarga_max

	# Act
	arrow._on_body_entered(guardiana)

	# Assert
	assert_gt(guardiana.health, 0, "Una flecha normal NO debe matar a la guardiana de un golpe")
	assert_eq(guardiana.health, hp_inicial - 1, "Debe reducir únicamente 1 punto de vida")
	assert_ne(guardiana.current_state, GuardianaMoradita.State.DYING, "No debe estar en estado DYING")


func test_escudo_modo_metalico_color_gris_y_sin_textura_madera() -> void:
	# Arrange
	var escudo = ESCUDO_SCENE.instantiate() as EscudoDestruible
	add_child_autofree(escudo)
	await get_tree().process_frame

	# Act
	escudo.activar_modo_metalico(2)

	# Assert
	assert_true(escudo.es_metalico, "El escudo debe tener es_metalico = true")
	assert_eq(escudo.aguante_metalico, 2, "El escudo debe tener aguante_metalico = 2")
	assert_not_null(escudo.material_metalico, "Debe haber generado material_metalico")

	var mat: StandardMaterial3D = escudo.material_metalico
	assert_null(mat.albedo_texture, "El material metálico no debe tener textura de madera marrón")
	assert_gt(mat.metallic, 0.7, "El material debe tener propiedad metálica alta")
	assert_gt(mat.albedo_color.r, 0.6, "El canal R debe ser gris brillante")
	assert_gt(mat.albedo_color.g, 0.6, "El canal G debe ser gris brillante")
	assert_gt(mat.albedo_color.b, 0.6, "El canal B debe ser gris brillante")

	var mallas: Array[MeshInstance3D] = escudo._recolectar_mallas()
	for mi in mallas:
		var override_mat = mi.get_surface_override_material(0)
		assert_eq(override_mat, escudo.material_metalico, "La malla '%s' debe tener el material gris metálico aplicado" % mi.name)


func test_escudo_desactivar_modo_metalico_restaura_material() -> void:
	# Arrange
	var escudo = ESCUDO_SCENE.instantiate() as EscudoDestruible
	add_child_autofree(escudo)
	await get_tree().process_frame

	# Act
	escudo.activar_modo_metalico(2)
	assert_true(escudo.es_metalico)
	escudo.desactivar_modo_metalico()

	# Assert
	assert_false(escudo.es_metalico, "El modo metálico debe quedar desactivado")
	assert_eq(escudo.aguante_metalico, 0, "El aguante debe ser 0")

	var mallas: Array[MeshInstance3D] = escudo._recolectar_mallas()
	for mi in mallas:
		var override_mat = mi.get_surface_override_material(0)
		assert_ne(override_mat, escudo.material_metalico, "La malla '%s' no debe conservar el material metálico" % mi.name)


func test_ballestera_refuerzo_aplica_modo_metalico_a_escudo() -> void:
	# Arrange
	var ballestera = BALLESTERA_SCENE.instantiate()
	add_child_autofree(ballestera)
	var escudo = ESCUDO_SCENE.instantiate() as EscudoDestruible
	add_child_autofree(escudo)
	await get_tree().process_frame

	ballestera._escudo_piso_ref = escudo

	# Act
	ballestera._aplicar_efecto_escudo_piso()

	# Assert
	assert_true(escudo.es_metalico, "La habilidad de refuerzo debe activar el modo metálico en el escudo")
	assert_eq(escudo.aguante_metalico, 2, "El escudo debe quedar con 2 de aguante metálico")
	var mallas: Array[MeshInstance3D] = escudo._recolectar_mallas()
	for mi in mallas:
		assert_eq(mi.get_surface_override_material(0), escudo.material_metalico, "Debe tener material gris metálico")
