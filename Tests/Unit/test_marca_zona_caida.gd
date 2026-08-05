extends GutTest

const MARCA_REF = preload("res://Entities/Enemigo_Lonko/Marca_Zona_Caida.gd")

var scene_root: Node3D


func before_each() -> void:
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func test_marca_crea_aros_y_se_posiciona() -> void:
	# Arrange
	var marca := MARCA_REF.new() as MarcaZonaCaida
	marca.radio_marca = 2.0
	marca.duracion_marca = 1.0
	scene_root.add_child(marca)

	# Act
	marca.iniciar(Vector3(-8.0, 0.0, 0.0))
	await get_tree().process_frame

	# Assert: se creó al menos el primer aro y el cráneo, en la posición Y=0.1
	assert_not_null(marca, "La marca debe instanciarse")
	assert_almost_eq(marca.global_position.y, 0.1, 0.01, "La marca debe quedar a 0.1 en el eje Y")
	assert_true(marca.get_child_count() >= 1, "Debe crear elementos al iniciar")
	
	var craneo := marca.get_node_or_null("CraneoTarget") as Sprite3D
	assert_not_null(craneo, "Debe existir el nodo CraneoTarget")
	if craneo:
		assert_eq(craneo.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "El cráneo debe estar en modo billboard mirando a la pantalla")

	var primer_aro := marca.get_node_or_null("Anillo")
	assert_not_null(primer_aro, "El primer aro debe llamarse Anillo")
	if primer_aro:
		assert_almost_eq(primer_aro.global_position.x, -8.0, 0.01, "La marca debe quedar en la X pedida")
		assert_almost_eq(primer_aro.global_position.z, 0.0, 0.01, "La marca debe quedar en la Z pedida")

	marca.queue_free()
	await get_tree().process_frame


func test_marca_se_autodestruye_al_terminar() -> void:
	# Arrange
	var marca := MARCA_REF.new() as MarcaZonaCaida
	marca.radio_marca = 1.0
	marca.duracion_marca = 0.15
	marca.intervalo_anillo = 0.05
	scene_root.add_child(marca)

	# Act
	marca.iniciar(Vector3.ZERO)
	await get_tree().create_timer(marca.duracion_marca + 0.3).timeout

	# Assert: se liberó sola al terminar la secuencia
	assert_false(is_instance_valid(marca), "La marca debe autodestruirse al terminar el aviso")
	await get_tree().process_frame


func test_marca_radio_exportable() -> void:
	# Arrange & Act
	var marca := MARCA_REF.new() as MarcaZonaCaida
	scene_root.add_child(marca)

	# Assert: radio por defecto = 1.25 unidades según diseño
	assert_eq(marca.radio_marca, 1.25, "El radio de la marca debe ser 1.25 por defecto")

	marca.queue_free()
	await get_tree().process_frame
