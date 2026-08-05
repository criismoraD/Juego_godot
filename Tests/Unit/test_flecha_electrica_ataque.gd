extends GutTest

const FLECHA_ELECTRICA_ATAQUE_SCENE: PackedScene = preload("res://Entities/Enemigo_Lonko/Flecha_Electrica_Ataque.tscn")

var scene_root: Node3D


func before_each() -> void:
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func test_flecha_electrica_estructura_y_fase_inicial() -> void:
	# Arrange & Act
	var flecha := FLECHA_ELECTRICA_ATAQUE_SCENE.instantiate() as FlechaElectricaAtaque
	scene_root.add_child(flecha)
	await get_tree().process_frame

	# Assert: La flecha normal (modelo del arco) + VFX eléctrico añadido
	assert_not_null(flecha, "La flecha eléctrica debe instanciarse correctamente")
	assert_not_null(flecha.find_child("FLECHA_ARQUERA_ENEMIGA", true, false), "Debe portar la flecha normal")
	assert_not_null(flecha.find_child("FlechaElectricaVFX", true, false), "Debe portar el VFX Flecha_Electrica.tscn")
	assert_eq(flecha.fase, FlechaElectricaAtaque.Fase.SUBIDA, "Debe iniciar en fase de subida")

	flecha.queue_free()
	await get_tree().process_frame


func test_flecha_electrica_zona_caida_por_defecto() -> void:
	# Arrange
	var flecha := FLECHA_ELECTRICA_ATAQUE_SCENE.instantiate() as FlechaElectricaAtaque
	scene_root.add_child(flecha)
	await get_tree().process_frame

	# Assert: Valores exportables por defecto de la zona aliada (X -10.0 a -6.5, Z 0)
	assert_eq(flecha.zona_caida_x_min, -10.0, "Límite izquierdo de la zona de caída")
	assert_eq(flecha.zona_caida_x_max, -6.5, "Límite derecho de la zona de caída")
	assert_eq(flecha.zona_caida_z, 0.0, "Plano Z de la zona de caída")
	assert_eq(flecha.segundos_marca, 1.5, "La marca debe durar 1.5 segundos")
	assert_eq(flecha.radio_marca, 1.25, "El radio de la marca debe ser 1.25 unidades")

	flecha.queue_free()
	await get_tree().process_frame


func test_flecha_electrica_apunta_arriba_y_mitad_tamano() -> void:
	# Arrange: instanciar y lanzar en vertical (como la recarga eléctrica de Lonko)
	var flecha := FLECHA_ELECTRICA_ATAQUE_SCENE.instantiate() as FlechaElectricaAtaque
	scene_root.add_child(flecha)
	await get_tree().process_frame

	# Act: dirección de subida vertical
	flecha.initialize(Vector3.UP, 1.0)
	await get_tree().physics_frame

	# Assert: la punta (eje +X de ArrowModel tras el volteo del script) apunta al cielo
	var modelo := flecha.get_node_or_null("ArrowModel") as Node3D
	assert_not_null(modelo, "ArrowModel debe existir")
	var punta: Vector3 = modelo.global_basis.x.normalized()
	assert_almost_eq(punta.x, 0.0, 0.01, "La punta debe quedar en el plano X=0")
	assert_almost_eq(punta.y, 1.0, 0.01, "La punta debe apuntar hacia arriba")
	assert_almost_eq(punta.z, 0.0, 0.01, "La punta no debe apuntar hacia el fondo")

	# Assert: escala a la mitad del tamaño original
	assert_almost_eq(flecha.scale.x, 0.5, 0.01, "La flecha debe medir la mitad en vuelo")

	flecha.queue_free()
	await get_tree().process_frame


func test_flecha_electrica_sube_marca_y_cae() -> void:
	# Arrange: parámetros pequeños para acelerar el ciclo en el test
	var flecha := FLECHA_ELECTRICA_ATAQUE_SCENE.instantiate() as FlechaElectricaAtaque
	flecha.altura_cielo = 5.0
	flecha.velocidad_subida = 50.0
	flecha.segundos_marca = 0.1
	flecha.zona_caida_x_min = -10.0
	flecha.zona_caida_x_max = -6.5
	flecha.zona_caida_z = 0.0
	scene_root.add_child(flecha)
	await get_tree().process_frame

	flecha.initialize(Vector3.UP, 1.0)

	# Act: esperar a que llegue al cielo (subida vertical)
	var esperas: int = 0
	while flecha.global_position.y < flecha.altura_cielo and esperas < 300:
		await get_tree().physics_frame
		esperas += 1

	# Assert: alcanzó el cielo y pasó a esperar con la marca
	assert_true(flecha.global_position.y >= flecha.altura_cielo, "La flecha debe salir de pantalla en vertical")
	assert_eq(flecha.fase, FlechaElectricaAtaque.Fase.ESPERA_MARCA, "Debe entrar en fase de espera con la marca")
	assert_false(flecha.visible, "La flecha debe estar oculta mientras cae la cuenta atrás")
	assert_not_null(flecha._marca, "Debe haberse creado la marca de caída")
	assert_true(flecha._punto_caida.x >= -10.0 and flecha._punto_caida.x <= -6.5, "El punto de caída debe estar dentro de la zona aliada X[-10,-6.5]")
	assert_eq(flecha._punto_caida.z, 0.0, "El punto de caída debe estar en el plano Z=0")

	# Act: esperar a que termine la cuenta atrás y empiece a caer
	await get_tree().create_timer(flecha.segundos_marca + 0.05).timeout
	await get_tree().physics_frame

	# Assert: cae del cielo en picada hacia el punto marcado
	assert_eq(flecha.fase, FlechaElectricaAtaque.Fase.CAIDA, "Debe entrar en fase de caída tras la marca")
	assert_true(flecha.visible, "La flecha debe reaparecer visible al caer del cielo")
	assert_almost_eq(flecha.global_position.x, flecha._punto_caida.x, 0.01, "Debe caer alineada con la marca (X)")
	assert_almost_eq(flecha.global_position.z, flecha._punto_caida.z, 0.01, "Debe caer alineada con la marca (Z)")
	assert_gt(flecha.global_position.y, 0.2, "Debe estar cayendo desde el cielo")

	# Act: esperar la caída hasta el impacto con el suelo (y = 0.2, atraviesa todo)
	var esperas_impacto: int = 0
	while flecha.global_position.y > 0.2 and esperas_impacto < 300:
		await get_tree().physics_frame
		esperas_impacto += 1

	# Assert: atraviesa todo hasta y=0.2 y se destruye en el impacto
	assert_true(flecha.global_position.y <= 0.2, "Debe traspasar todo hasta llegar a y=0.2")
	await get_tree().physics_frame
	assert_false(flecha.visible, "Debe destruirse al impactar el suelo")

	flecha.queue_free()
	await get_tree().process_frame
