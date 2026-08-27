extends "res://addons/gut/test.gd"

var WaveSpawnerScript = load("res://System/Core/WaveSpawner.gd")
var _spawner: WaveSpawner = null

func before_each():
	_spawner = WaveSpawnerScript.new()
	_spawner.escena_goblin = _create_dummy_scene("GoblinNode")
	_spawner.escena_goblin_girl = _create_dummy_scene("GoblinGirlNode")
	_spawner.escena_imp = _create_dummy_scene("ImpNode")
	_spawner.escena_canonero = _create_dummy_scene("CanoneroNode")
	_spawner.escena_gargola = _create_dummy_scene("GargolaNode")
	_spawner.escena_lonko = _create_dummy_scene("LonkoNode")
	_spawner.escena_imp_escudo = _create_dummy_scene("ImpShieldNode")
	add_child_autofree(_spawner)

func _create_dummy_scene(node_name: String) -> PackedScene:
	var scene = PackedScene.new()
	var node = Node3D.new()
	node.name = node_name
	scene.pack(node)
	node.free()
	return scene

func test_oleada_5_generacion_cola_40_enemigos():
	# Arrange
	_spawner.oleada_combate = 5

	# Act
	_spawner._generar_cola_spawn()

	# Assert: 40 enemigos totales en la cola
	assert_eq(_spawner.cola_spawn.size(), 40, "La Oleada 5 debe contener un total de 40 enemigos")

	# Contar cantidad de cada tipo
	var count_lonko := 0
	var count_escudo := 0
	var count_gargola := 0
	var count_goblin_girl := 0
	var count_goblin := 0

	for scene in _spawner.cola_spawn:
		if scene == _spawner.escena_lonko:
			count_lonko += 1
		elif scene == _spawner.escena_imp_escudo:
			count_escudo += 1
		elif scene == _spawner.escena_gargola:
			count_gargola += 1
		elif scene == _spawner.escena_goblin_girl:
			count_goblin_girl += 1
		elif scene == _spawner.escena_goblin:
			count_goblin += 1

	assert_gte(count_lonko, 10, "La Oleada 5 debe tener mínimo 10 Arqueras Lonko")
	assert_eq(count_escudo, 4, "La Oleada 5 debe tener 4 Imps de escudo")
	assert_eq(count_gargola, 7, "La Oleada 5 debe tener 7 Gárgolas")
	assert_eq(count_goblin_girl, 9, "La Oleada 5 debe tener 9 Arqueras Goblin")
	assert_eq(count_goblin, 9, "La Oleada 5 debe tener 9 Goblins Ballesta")

func test_generacion_sonido_cuerno_procedural():
	# Act
	var stream: AudioStreamWAV = _spawner.generar_sonido_cuerno_procedural()

	# Assert
	assert_not_null(stream, "El sonido de cuerno procedural debe generarse correctamente")
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "El formato debe ser PCM de 16 bits")
	assert_gt(stream.data.size(), 0, "El stream debe contener datos de audio sintetizados")

func test_evento_cuerno_disparo_y_rafaga_refuerzos():
	# Arrange
	_spawner.oleada_combate = 5
	_spawner._generar_cola_spawn()
	assert_false(_spawner.evento_cuerno_activado, "El evento de cuerno no debe estar activo inicialmente")

	# Act: Iniciar evento de cuerno
	_spawner._iniciar_evento_cuerno()

	# Assert
	assert_true(_spawner.evento_cuerno_activado, "El evento de cuerno debe marcarse como activado")
	assert_true(_spawner.evento_cuerno_en_progreso, "El evento de cuerno debe estar en progreso")
	
	# Verificar que los primeros 10 elementos son la ráfaga de 5 goblin + 5 goblin girl
	var burst_goblins := 0
	var burst_girls := 0
	for i in range(10):
		var scene = _spawner.cola_spawn[i]
		if scene == _spawner.escena_goblin:
			burst_goblins += 1
		elif scene == _spawner.escena_goblin_girl:
			burst_girls += 1

	assert_eq(burst_goblins, 5, "La ráfaga del cuerno debe tener 5 Goblins Ballesta al frente")
	assert_eq(burst_girls, 5, "La ráfaga del cuerno debe tener 5 Arqueras Goblin al frente")


func test_evento_cuerno_oleada_4_rafaga_5_mas_5_mas_imp_escudo_fijo():
	# Arrange
	_spawner.oleada_combate = 4
	_spawner._generar_cola_spawn()
	var cola_previa: int = _spawner.cola_spawn.size()
	var escudos_previos: int = _spawner.shield_imps_activos.size()

	# Act: evento de cuerno de la oleada 4 (ráfaga 5+5 + 1 imp de escudo fijo)
	_spawner._iniciar_evento_cuerno(10, true)

	# Assert: banderas activas
	assert_true(_spawner.evento_cuerno_activado, "El evento de cuerno debe activarse en oleada 4")
	assert_true(_spawner.evento_cuerno_en_progreso, "El evento debe estar en progreso")
	assert_eq(_spawner.refuerzos_cuerno_total, 10, "La ráfaga debe ser de 10 refuerzos")

	# Ráfaga 5+5 al frente de la cola
	var burst_goblins := 0
	var burst_girls := 0
	for i in range(10):
		var scene = _spawner.cola_spawn[i]
		if scene == _spawner.escena_goblin:
			burst_goblins += 1
		elif scene == _spawner.escena_goblin_girl:
			burst_girls += 1
	assert_eq(burst_goblins, 5, "La ráfaga debe tener 5 Goblins Ballesta al frente")
	assert_eq(burst_girls, 5, "La ráfaga debe tener 5 Arqueras Goblin al frente")

	# La cola crece exactamente 10 (el imp de escudo va FUERA de la cola)
	assert_eq(_spawner.cola_spawn.size(), cola_previa + 10, "La cola debe crecer exactamente 10")

	# Imp de escudo fijo spawneado directamente
	assert_eq(
		_spawner.shield_imps_activos.size(), escudos_previos + 1,
		"El evento debe incluir fijo 1 Imp de Escudo"
	)


func test_evento_cuerno_actualiza_enemigos_por_oleada_para_barra_progreso():
	# Arrange
	_spawner.oleada_combate = 5
	_spawner.enemigos_por_oleada = 40
	_spawner._generar_cola_spawn()
	_spawner.goblins_spawned_in_wave = 12

	# Act: se dispara el evento de cuerno con 10 refuerzos
	_spawner._iniciar_evento_cuerno(10, false)

	# Assert: la barra de progreso / wave_spawner debe contabilizar los 50 enemigos totales (40 base + 10 refuerzos)
	assert_eq(
		_spawner.enemigos_por_oleada, 50,
		"enemigos_por_oleada debe actualizarse a 50 al sumar los 10 refuerzos del evento cuerno"
	)

