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

	# Assert: Proyectil Javelin VFX instanciado y fase inicial
	assert_not_null(flecha, "La flecha eléctrica debe instanciarse correctamente")
	assert_not_null(flecha.find_child("MProjectileJavelinVFX_02", true, false), "Debe portar el VFX MProjectileJavelinVFX_02")
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
	assert_eq(flecha.segundos_marca, 1.4, "La marca debe durar 1.4 segundos")
	assert_eq(flecha.radio_marca, 0.55, "El radio de la marca debe ser 0.55 unidades")

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

	# Assert: rotación hacia arriba
	assert_almost_eq(flecha.rotation_degrees.z, 90.0, 0.01, "La flecha debe rotar 90 grados apuntando arriba")

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


func test_ult_lonko_sacude_canoa_al_impactar() -> void:
	# Arrange: Canoa aliada en escena
	var canoa := Node3D.new()
	canoa.set_script(load("res://Entities/Ambiente_Canoa_Aliada/CanoaAliada.gd"))
	canoa.add_to_group("canoa_protagonista")
	scene_root.add_child(canoa)
	canoa.global_position = Vector3(0.0, 0.0, 0.0)
	var amp_base: float = canoa.amplitud_flotacion

	var flecha := FLECHA_ELECTRICA_ATAQUE_SCENE.instantiate() as FlechaElectricaAtaque
	scene_root.add_child(flecha)
	flecha.global_position = Vector3(0.0, 1.0, 0.0)
	flecha.fase = FlechaElectricaAtaque.Fase.CAIDA

	# Act: Simular impacto en la canoa
	flecha._sacudir_canoa_si_impacta()

	# Assert: amplitudes de oleaje multiplicadas por 3.0 (como la mina)
	assert_almost_eq(canoa.amplitud_flotacion, amp_base * 3.0, 0.001, "La canoa debe triplicar su amplitud de flotacion al impactar el ult")
	assert_true(flecha._canoa_sacudida, "Debe registrarse que la canoa fue sacudida")

	canoa.queue_free()
	flecha.queue_free()
	await get_tree().process_frame


func test_sacudida_oleaje_retorno_suave_y_fluido() -> void:
	# Arrange: Canoa aliada con amplitudes base conocidas
	var canoa := Node3D.new()
	canoa.set_script(load("res://Entities/Ambiente_Canoa_Aliada/CanoaAliada.gd"))
	scene_root.add_child(canoa)
	var amp_base_flot: float = canoa.amplitud_flotacion
	var amp_base_bal: float = canoa.amplitud_balanceo

	# Act 1: Activar sacudida con duración corta para evaluar interpolación
	canoa.sacudida_oleaje(0.4, 2.5)

	# Assert 1: Inmediatamente tras el impacto se elevan las amplitudes
	assert_almost_eq(canoa.amplitud_flotacion, amp_base_flot * 2.5, 0.001, "Pico de impacto inmediato")
	assert_not_null(canoa._tween_oleaje, "Debe existir un Tween para amortiguar el oleaje")
	assert_true(canoa._tween_oleaje.is_valid(), "El Tween de amortiguación debe estar activo")

	# Act 2: Esperar a que la amortiguación concluya de forma fluida
	await get_tree().create_timer(0.9).timeout

	# Assert 2: Al concluir la amortiguación gradual, las amplitudes retornan fluidamente a sus valores base
	assert_almost_eq(canoa.amplitud_flotacion, amp_base_flot, 0.01, "Amplitud de flotación restaurada suavemente")
	assert_almost_eq(canoa.amplitud_balanceo, amp_base_bal, 0.01, "Amplitud de balanceo restaurada suavemente")

	canoa.queue_free()
	await get_tree().process_frame

