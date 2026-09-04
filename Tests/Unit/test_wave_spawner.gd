extends "res://addons/gut/test.gd"

var WaveSpawnerScript = load("res://System/Core/WaveSpawner.gd")
var _spawner = null

# Mock para AudioManager
class MockAudioManager extends Node:
	func on_enemy_killed():
		pass

var _mock_audio_created: bool = false

func before_each():
	_spawner = WaveSpawnerScript.new()

	# Inyectar MockAudioManager si es necesario
	if not get_tree().root.has_node("AudioManager"):
		var mock_audio = MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)
		_mock_audio_created = true

	# Configurar escenas dummy para evitar cargar assets reales
	_spawner.escena_goblin = _create_dummy_scene("GoblinNode")
	_spawner.escena_goblin_girl = _create_dummy_scene("GoblinGirlNode")
	_spawner.escena_imp = _create_dummy_scene("ImpNode")
	_spawner.escena_canonero = _create_dummy_scene("CanoneroNode")
	_spawner.escena_imp_escudo = _create_dummy_scene("ImpShieldNode")
	_spawner.escena_globo_aerostatico = _create_dummy_scene("GloboAerostaticoNode")
	_spawner.escena_goblina_escudo = _create_dummy_scene("GoblinaEscudoNode")

	get_tree().root.add_child(_spawner)

func after_each():
	if is_instance_valid(_spawner):
		for enemy in _spawner.active_goblins:
			if is_instance_valid(enemy):
				if enemy.get_parent():
					enemy.get_parent().remove_child(enemy)
				enemy.free()
		for shield_imp in _spawner.shield_imps_activos:
			if is_instance_valid(shield_imp):
				if shield_imp.get_parent():
					shield_imp.get_parent().remove_child(shield_imp)
				shield_imp.free()
		if _spawner.get_parent():
			_spawner.get_parent().remove_child(_spawner)
		_spawner.free()

	if _mock_audio_created and get_tree().root.has_node("AudioManager"):
		var mock_audio = get_tree().root.get_node("AudioManager")
		get_tree().root.remove_child(mock_audio)
		mock_audio.free()
		_mock_audio_created = false

func _create_dummy_scene(node_name: String) -> PackedScene:
	var scene = PackedScene.new()
	var node = Node3D.new()
	node.name = node_name
	scene.pack(node)
	node.free()
	return scene

func test_get_active_enemies_with_freed_instances():
	var valid_node = Node3D.new()
	var freed_node = Node3D.new()

	_spawner.active_goblins = [valid_node, freed_node]

	# Free one node
	freed_node.free()

	var result = _spawner.get_active_enemies()

	assert_eq(result.size(), 1, "Should only return 1 active enemy")
	assert_eq(result[0], valid_node, "The remaining enemy should be the valid one")

	valid_node.free()

func test_obtener_goblins_activos_counts_correctly():
	var node1 = Node3D.new()
	var node2 = Node3D.new()

	_spawner.active_goblins = [node1, node2]

	node1.free()

	var count = _spawner.obtener_goblins_activos()

	assert_eq(count, 1, "Should count only 1 active goblin")
	assert_eq(_spawner.active_goblins.size(), 1, "Internal array should be cleaned up")

	node2.free()

func test_get_active_shield_imps_filtering():
	var valid_imp = Node3D.new()
	var freed_imp = Node3D.new()

	_spawner.shield_imps_activos = [valid_imp, freed_imp]

	freed_imp.free()

	var result = _spawner.get_active_shield_imps()

	assert_eq(result.size(), 1, "Should only return 1 active shield imp")
	assert_eq(result[0], valid_imp, "The remaining imp should be the valid one")

	valid_imp.free()

func test_filtering_all_freed_instances():
	var node1 = Node3D.new()
	var node2 = Node3D.new()

	_spawner.active_goblins = [node1, node2]

	node1.free()
	node2.free()

	var result = _spawner.get_active_enemies()

	assert_true(result.is_empty(), "Should return an empty array when all instances are freed")

func test_filtering_empty_array():
	_spawner.active_goblins = []
	var result = _spawner.get_active_enemies()
	assert_true(result.is_empty(), "Should handle empty array correctly")

func test_filtering_all_valid_instances():
	var node1 = Node3D.new()
	var node2 = Node3D.new()

	_spawner.active_goblins = [node1, node2]

	var result = _spawner.get_active_enemies()

	assert_eq(result.size(), 2, "Should return all valid instances")

	node1.free()
	node2.free()

func test_filtering_null_values():
	var node = Node3D.new()
	_spawner.active_goblins = [null, node, null]

	var result = _spawner.get_active_enemies()

	assert_eq(result.size(), 1, "Should only return 1 valid node, removing nulls")
	assert_eq(result[0], node, "The remaining node should be the valid one")

	node.free()

func test_forzar_spawn():
	watch_signals(_spawner)
	var initial_count = _spawner.active_goblins.size()
	var initial_spawned = _spawner.goblins_spawned_in_wave

	_spawner.forzar_spawn()

	assert_eq(_spawner.active_goblins.size(), initial_count + 1, "Should increment active_goblins")
	assert_eq(_spawner.goblins_spawned_in_wave, initial_spawned + 1, "Should increment goblins_spawned_in_wave")
	assert_signal_emitted(_spawner, "goblin_spawneado", "Should emit goblin_spawneado signal")

func test_forzar_tipo_enemigo_goblin():
	_spawner.forzar_tipo_enemigo = 0
	_spawner.forzar_spawn()
	var spawned = _spawner.active_goblins.back()
	assert_eq(spawned.name, "GoblinNode", "Should spawn a goblin")

func test_forzar_tipo_enemigo_goblin_girl():
	_spawner.forzar_tipo_enemigo = 1
	_spawner.forzar_spawn()
	var spawned = _spawner.active_goblins.back()
	assert_eq(spawned.name, "GoblinGirlNode", "Should spawn a goblin girl")

func test_forzar_tipo_enemigo_imp():
	_spawner.forzar_tipo_enemigo = 2
	_spawner.forzar_spawn()
	var spawned = _spawner.active_goblins.back()
	assert_eq(spawned.name, "ImpNode", "Should spawn an imp")

func test_forzar_tipo_enemigo_canonero():
	_spawner.forzar_tipo_enemigo = 3
	_spawner.forzar_spawn()
	var spawned = _spawner.active_goblins.back()
	assert_eq(spawned.name, "CanoneroNode", "Should spawn a canonero")

func test_forzar_tipo_enemigo_globo_aerostatico():
	_spawner.forzar_tipo_enemigo = 8
	_spawner.forzar_spawn()
	var spawned = _spawner.active_goblins.back()
	assert_eq(spawned.name, "GloboAerostaticoNode", "Should spawn a globo aerostatico")

func test_forzar_spawn_escudo():
	var initial_spawned_in_wave = _spawner.goblins_spawned_in_wave
	var initial_active = _spawner.active_goblins.size()
	var initial_shields = _spawner.shield_imps_activos.size()

	_spawner.forzar_spawn_escudo()

	assert_eq(_spawner.active_goblins.size(), initial_active + 1, "Should increment active_goblins")
	assert_eq(_spawner.shield_imps_activos.size(), initial_shields + 1, "Should increment shield_imps_activos")
	assert_eq(_spawner.goblins_spawned_in_wave, initial_spawned_in_wave, "Should NOT increment goblins_spawned_in_wave")

	var spawned = _spawner.active_goblins.back()
	assert_eq(spawned.name, "ImpShieldNode", "Should spawn an imp shield girl")


func test_predefined_wave_spawn_queue_wave_1():
	_spawner.oleada_combate = 1
	_spawner._start_wave()
	
	assert_eq(_spawner.cola_spawn.size(), 12, "Wave 1 queue should have 12 elements")
	
	var imp_count = 0
	var girl_count = 0
	var shield_count = 0
	
	for scene in _spawner.cola_spawn:
		if scene == _spawner.escena_imp:
			imp_count += 1
		elif scene == _spawner.escena_goblin_girl:
			girl_count += 1
		elif scene == _spawner.escena_imp_escudo:
			shield_count += 1
			
	assert_eq(imp_count, 6, "Wave 1 should have 6 imps")
	assert_eq(girl_count, 5, "Wave 1 should have 5 goblin girls")
	assert_eq(shield_count, 1, "Wave 1 should have 1 imp shield")
	assert_ne(_spawner.cola_spawn.back(), _spawner.escena_imp_escudo, "The imp shield cannot be the last one in Wave 1")


func test_predefined_wave_spawn_queue_wave_2():
	_spawner.oleada_combate = 2
	_spawner._start_wave()
	
	assert_eq(_spawner.cola_spawn.size(), 26, "Wave 2 queue should have 26 elements")
	assert_eq(_spawner.enemigos_por_oleada, 26, "Wave 2 total enemies should be 26")
	
	var imp_count = 0
	var girl_count = 0
	var goblin_count = 0
	var shield_count = 0
	var goblina_escudo_count = 0
	
	for scene in _spawner.cola_spawn:
		if scene == _spawner.escena_imp:
			imp_count += 1
		elif scene == _spawner.escena_goblin_girl:
			girl_count += 1
		elif scene == _spawner.escena_goblin:
			goblin_count += 1
		elif scene == _spawner.escena_imp_escudo:
			shield_count += 1
		elif scene == _spawner.escena_goblina_escudo:
			goblina_escudo_count += 1
			
	assert_eq(shield_count, 2, "Wave 2 should have 2 imps shield")
	assert_eq(imp_count, 7, "Wave 2 should have 7 imps normal")
	assert_eq(girl_count, 8, "Wave 2 should have 8 goblin archers")
	assert_eq(goblin_count, 8, "Wave 2 should have 8 goblin crossbows")
	assert_eq(goblina_escudo_count, 1, "Wave 2 should have 1 goblina shield")

	# Verificar restricciones
	assert_ne(_spawner.cola_spawn.back(), _spawner.escena_imp_escudo, "The imp shield cannot be the last one in Wave 2")
	assert_ne(_spawner.cola_spawn.back(), _spawner.escena_goblina_escudo, "The goblina shield cannot be the last one in Wave 2")
	for i in range(_spawner.cola_spawn.size() - 1):
		var is_consecutive = (_spawner.cola_spawn[i] == _spawner.escena_imp_escudo and _spawner.cola_spawn[i+1] == _spawner.escena_imp_escudo)
		assert_false(is_consecutive, "No two imp shields can be consecutive in Wave 2")

	# Verificar que la goblina de escudo pesado aparece en la mitad de la oleada
	var idx_goblina = _spawner.cola_spawn.find(_spawner.escena_goblina_escudo)
	assert_true(idx_goblina >= 10 and idx_goblina <= 15, "La goblina de escudo debe aparecer en la mitad de la oleada (indice entre 10 y 15)")
	if idx_goblina > 0:
		assert_ne(_spawner.cola_spawn[idx_goblina - 1], _spawner.escena_imp_escudo, "No debe haber un imp escudo inmediatamente antes de la goblina")
	if idx_goblina < _spawner.cola_spawn.size() - 1:
		assert_ne(_spawner.cola_spawn[idx_goblina + 1], _spawner.escena_imp_escudo, "No debe haber un imp escudo inmediatamente despues de la goblina")


func test_predefined_wave_spawn_queue_wave_3():
	_spawner.oleada_combate = 3
	_spawner._start_wave()
	
	assert_eq(_spawner.cola_spawn.size(), 30, "Wave 3 queue should have 30 elements")
	
	var girl_count = 0
	var goblin_count = 0
	var shield_count = 0
	
	for scene in _spawner.cola_spawn:
		if scene == _spawner.escena_goblin_girl:
			girl_count += 1
		elif scene == _spawner.escena_goblin:
			goblin_count += 1
		elif scene == _spawner.escena_imp_escudo:
			shield_count += 1
			
	assert_eq(shield_count, 4, "Wave 3 should have 4 imps shield")
	assert_eq(girl_count, 13, "Wave 3 should have 13 goblin archers")
	assert_eq(goblin_count, 13, "Wave 3 should have 13 goblin crossbows")

	# Verificar restricciones
	assert_ne(_spawner.cola_spawn.back(), _spawner.escena_imp_escudo, "The imp shield cannot be the last one in Wave 3")
	for i in range(_spawner.cola_spawn.size() - 1):
		var is_consecutive = (_spawner.cola_spawn[i] == _spawner.escena_imp_escudo and _spawner.cola_spawn[i+1] == _spawner.escena_imp_escudo)
		assert_false(is_consecutive, "No two imp shields can be consecutive in Wave 3")


func test_predefined_wave_spawn_queue_wave_6():
	_spawner.oleada_combate = 6
	_spawner._start_wave()

	assert_eq(_spawner.cola_spawn.size(), 40, "Wave 6 queue should have 40 elements")
	assert_eq(_spawner.enemigos_por_oleada, 40, "Wave 6 total enemies should be 40")

	var girl_count = 0
	var goblin_count = 0
	var globo_count = 0
	var shield_goblina_count = 0

	for scene in _spawner.cola_spawn:
		if scene == _spawner.escena_goblin_girl:
			girl_count += 1
		elif scene == _spawner.escena_goblin:
			goblin_count += 1
		elif scene == _spawner.escena_globo_aerostatico:
			globo_count += 1
		elif scene == _spawner.escena_goblina_escudo:
			shield_goblina_count += 1

	assert_eq(girl_count, 12, "Wave 6 should have 12 goblin archers")
	assert_eq(goblin_count, 15, "Wave 6 should have 15 goblin crossbows")
	assert_eq(globo_count, 5, "Wave 6 should have 5 hot air balloons")
	assert_eq(shield_goblina_count, 6, "Wave 6 should have 6 heavy shield goblinas")

	assert_ne(_spawner.cola_spawn.back(), _spawner.escena_goblina_escudo, "The shield goblina cannot be the last one in Wave 6")
	for i in range(_spawner.cola_spawn.size() - 1):
		var is_consecutive = (_spawner.cola_spawn[i] == _spawner.escena_goblina_escudo and _spawner.cola_spawn[i+1] == _spawner.escena_goblina_escudo)
		assert_false(is_consecutive, "No two shield goblinas can be consecutive in Wave 6")


func test_standby_pool_con_instancia_liberada_no_crashea():
	# Arrange: simular que el pool de standby contiene una instancia previamente liberada (freed)
	var dummy_freed = Node3D.new()
	get_tree().root.add_child(dummy_freed)
	dummy_freed.free()  # Ahora es un previously freed instance
	
	_spawner._standby_pool[_spawner.escena_goblin] = [dummy_freed]
	var cola_tipada: Array[PackedScene] = [_spawner.escena_goblin]
	_spawner.cola_spawn = cola_tipada

	
	# Act: Spawner debe vaciar el elemento muerto y crear uno nuevo sin crashear
	_spawner._spawn_goblin()
	
	# Assert
	assert_eq(_spawner.active_goblins.size(), 1, "Debe spawnear un goblin valido a pesar de haber tenido una instancia liberada en el pool")
	assert_true(is_instance_valid(_spawner.active_goblins[0]), "El enemigo spawneado debe ser una instancia valida")


func test_intervalo_aparicion_dinamico_inicio_oleada():
	# Arrange: Oleada iniciada con 100% de enemigos restantes en la barra de progreso
	_spawner.enemigos_por_oleada = 20
	_spawner.intervalo_aparicion = 4.0
	_spawner.intervalo_minimo_aparicion = 1.0
	_spawner.enemigos_muertos_en_oleada = 0

	# Act: Calcular intervalo al inicio
	var intervalo: float = _spawner._calcular_intervalo_actual()

	# Assert: Con 20/20 restantes (factor 1.0), el intervalo debe ser el base (4.0s)
	assert_almost_eq(intervalo, 4.0, 0.01, "Al inicio con todos los enemigos restantes el intervalo debe ser intervalo_aparicion")


func test_intervalo_aparicion_dinamico_mitad_oleada():
	# Arrange: 10 de 20 enemigos muertos (50% en la barra de progreso)
	_spawner.enemigos_por_oleada = 20
	_spawner.intervalo_aparicion = 4.0
	_spawner.intervalo_minimo_aparicion = 1.0
	_spawner.enemigos_muertos_en_oleada = 10

	# Act: Calcular intervalo
	var intervalo: float = _spawner._calcular_intervalo_actual()

	# Assert: Con 10 restantes de 20 (factor 0.5), el intervalo debe ser lerp(1.0, 4.0, 0.5) = 2.5s
	assert_almost_eq(intervalo, 2.5, 0.01, "A mitad de la barra de progreso el intervalo debe ser 2.5s")


func test_intervalo_aparicion_dinamico_final_oleada():
	# Arrange: 20 de 20 enemigos muertos (0 restantes en la barra de progreso)
	_spawner.enemigos_por_oleada = 20
	_spawner.intervalo_aparicion = 4.0
	_spawner.intervalo_minimo_aparicion = 1.0
	_spawner.enemigos_muertos_en_oleada = 20

	# Act: Calcular intervalo
	var intervalo: float = _spawner._calcular_intervalo_actual()

	# Assert: Con 0 restantes (factor 0.0), el intervalo debe ser el mínimo (1.0s)
	assert_almost_eq(intervalo, 1.0, 0.01, "Al agotarse los enemigos de la barra el intervalo debe ser el mínimo")


func test_intervalo_aparicion_con_evento_cuerno():
	# Arrange: Oleada al inicio pero con evento de cuerno activo
	_spawner.enemigos_por_oleada = 20
	_spawner.intervalo_aparicion = 4.0
	_spawner.intervalo_minimo_aparicion = 1.0
	_spawner.enemigos_muertos_en_oleada = 0
	_spawner.evento_cuerno_en_progreso = true

	# Act: Calcular intervalo durante evento de cuerno
	var intervalo: float = _spawner._calcular_intervalo_actual()

	# Assert: Durante el cuerno el intervalo debe reducirse a la mitad (4.0 / 2 = 2.0s)
	assert_almost_eq(intervalo, 2.0, 0.01, "Durante el cuerno el intervalo debe reducirse a la mitad")


func test_ajuste_inmediato_spawn_timer_al_morir_enemigo():
	# Arrange: Oleada activa con timer esperando a 4.0s
	_spawner.is_wave_active = true
	_spawner.enemigos_por_oleada = 20
	_spawner.intervalo_aparicion = 4.0
	_spawner.intervalo_minimo_aparicion = 1.0
	_spawner.goblins_spawned_in_wave = 5
	_spawner.enemigos_muertos_en_oleada = 0
	_spawner.spawn_timer = 4.0

	# Act: Mueren 10 enemigos, activando el setter de enemigos_muertos_en_oleada
	_spawner.enemigos_muertos_en_oleada = 10

	# Assert: spawn_timer debe recortarse inmediatamente al nuevo intervalo calculado (2.5s)
	assert_almost_eq(_spawner.spawn_timer, 2.5, 0.01, "El spawn_timer debe acelerarse inmediatamente al morir enemigos")



