extends "res://addons/gut/test.gd"

## Tests unitarios para el sistema de Squash & Stretch de CanastaCaida
## Evalúa el estiramiento vertical en caída libre y la compresión elástica
## exagerada con rebote y retorno suave al impactar el suelo.

var CanastaCaidaScript: GDScript = preload("res://Entities/Enemigo_GloboAerostatico/CanastaCaida.gd")
var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestCanasta"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()


func _crear_canasta() -> CanastaCaida:
	var canasta := CanastaCaida.new()
	var visual_model := Node3D.new()
	visual_model.name = "ModeloCanasta"
	visual_model.scale = Vector3(0.65, 0.65, 0.65)
	canasta.add_child(visual_model)
	_root_test.add_child(canasta)
	return canasta


func test_canasta_offset_entierro_y_caida_recta() -> void:
	# Arrange
	var canasta: CanastaCaida = _crear_canasta()
	canasta.iniciar_vuelo(Vector3(0.02, -0.8, 0.0), 0.1)

	# Assert 1: Parámetro de entierro configurado bajo tierra para evitar flotar
	assert_lt(canasta.offset_entierro_suelo, 0.0, "offset_entierro_suelo debe ser negativo para enterrar la base")
	assert_almost_eq(canasta.offset_entierro_suelo, -0.05, 0.01, "offset_entierro_suelo debe ser -0.05")

	# Act: Simular frames de física en caída libre
	var rot_inicial: float = canasta.rot_speed_z
	for i in range(10):
		canasta._physics_process(0.016)

	# Assert 2: La velocidad angular z y la rotación z deben amortiguarse hacia 0 para caer recta
	assert_lt(absf(canasta.rot_speed_z), absf(rot_inicial), "rot_speed_z debe amortiguarse hacia 0 en caída")
	assert_almost_eq(canasta.rotation.z, 0.0, 0.1, "rotation.z debe mantenerse casi vertical")


func test_canasta_squash_stretch_inicializacion_escala() -> void:
	# Arrange & Act
	var canasta: CanastaCaida = _crear_canasta()

	# Assert
	assert_true(canasta.habilitar_squash_stretch, "Squash and stretch debe estar habilitado por defecto")
	assert_eq(canasta.stretch_maximo_caida, 0.55, "El estiramiento maximo de caida debe ser 0.55")
	assert_eq(canasta.squash_maximo_impacto, 0.55, "La compresion maxima de impacto debe ser 0.55 (exagerada)")
	var visual: Node3D = canasta._obtener_nodo_visual()
	assert_not_null(visual, "Debe detectar ModeloCanasta como nodo visual")
	assert_almost_eq(visual.scale.x, 0.65, 0.001, "La escala X debe ser la original")
	assert_almost_eq(visual.scale.y, 0.65, 0.001, "La escala Y debe ser la original")
	assert_almost_eq(visual.scale.z, 0.65, 0.001, "La escala Z debe ser la original")


func test_canasta_stretch_vertical_en_caida_libre() -> void:
	# Arrange
	var canasta: CanastaCaida = _crear_canasta()
	var visual: Node3D = canasta._obtener_nodo_visual()
	canasta.iniciar_vuelo(Vector3(0.0, -2.0, 0.0), 0.0)
	canasta.global_position.y = 8.0
	canasta.velocity.y = -10.0

	# Act: Varios pasos de física para que el lerp elástico alcance la deformación
	for i in range(12):
		canasta._actualizar_squash_stretch_caida(0.016)

	# Assert: En caída rápida, la canasta se estira verticalmente (Y) y se comprime en X/Z (conservación de volumen)
	assert_gt(visual.scale.y, 0.65, "La canasta debe estirarse verticalmente en caída libre")
	assert_lt(visual.scale.x, 0.65, "La canasta debe adelgazarse en X para conservar volumen")
	assert_lt(visual.scale.z, 0.65, "La canasta debe adelgazarse en Z para conservar volumen")


func test_canasta_squash_al_impactar_contra_el_suelo_y_retorno_suave() -> void:
	# Arrange
	var canasta: CanastaCaida = _crear_canasta()
	var visual: Node3D = canasta._obtener_nodo_visual()
	canasta.set_physics_process(false)

	# Act 1: Disparar el squash de impacto al chocar contra el suelo
	canasta._disparar_squash_impacto(-11.0, 4.0)

	# Assert 1: Se activó el tween de squash
	assert_true(canasta._is_squash_tween_active, "El tween de squash debe estar activo tras impactar")

	# Assert 2: En el momento del impacto, aplastamiento exagerado (Y comprimido, X/Z ensanchado)
	assert_lt(visual.scale.y, 0.65 * 0.75, "La canasta debe aplastarse notablemente en Y al impactar el suelo")
	assert_gt(visual.scale.x, 0.65 * 1.20, "La canasta debe ensancharse notablemente en X al impactar el suelo")
	assert_gt(visual.scale.z, 0.65 * 1.20, "La canasta debe ensancharse notablemente en Z al impactar el suelo")

	# Act 2: Esperar a que el rebote y asentamiento completen
	await wait_seconds(0.5)

	# Assert 3: Retorno suave y elástico a la escala original
	assert_false(canasta._is_squash_tween_active, "El tween debe finalizar")
	assert_almost_eq(visual.scale.y, 0.65, 0.05, "La canasta debe asentarse a su escala Y original")
	assert_almost_eq(visual.scale.x, 0.65, 0.05, "La canasta debe asentarse a su escala X original")
	assert_almost_eq(visual.scale.z, 0.65, 0.05, "La canasta debe asentarse a su escala Z original")


func test_canasta_sin_squash_stretch_si_esta_deshabilitado() -> void:
	# Arrange
	var canasta: CanastaCaida = _crear_canasta()
	var visual: Node3D = canasta._obtener_nodo_visual()
	canasta.habilitar_squash_stretch = false
	canasta.iniciar_vuelo(Vector3(0.0, -5.0, 0.0), 0.0)
	canasta.velocity.y = -12.0

	# Act
	for i in range(10):
		canasta._actualizar_squash_stretch_caida(0.016)
	canasta._disparar_squash_impacto(-12.0, 5.0)

	# Assert: Ninguna deformación debe ocurrir
	assert_false(canasta._is_squash_tween_active, "No debe activarse el tween si squash & stretch está deshabilitado")
	assert_almost_eq(visual.scale.y, 0.65, 0.001, "La escala Y debe permanecer inalterada")
	assert_almost_eq(visual.scale.x, 0.65, 0.001, "La escala X debe permanecer inalterada")


func test_canasta_reset_squash_stretch() -> void:
	# Arrange
	var canasta: CanastaCaida = _crear_canasta()
	var visual: Node3D = canasta._obtener_nodo_visual()
	canasta._disparar_squash_impacto(-10.0, 3.0)
	assert_true(canasta._is_squash_tween_active, "Debe estar activo el tween")

	# Act
	canasta._reset_squash_stretch()

	# Assert
	assert_false(canasta._is_squash_tween_active, "El tween debe ser cancelado")
	assert_almost_eq(visual.scale.y, 0.65, 0.001, "La escala Y debe restaurarse de inmediato")
	assert_almost_eq(visual.scale.x, 0.65, 0.001, "La escala X debe restaurarse de inmediato")
