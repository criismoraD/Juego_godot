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
	
	assert_eq(_spawner.cola_spawn.size(), 25, "Wave 2 queue should have 25 elements")
	
	var imp_count = 0
	var girl_count = 0
	var goblin_count = 0
	var shield_count = 0
	
	for scene in _spawner.cola_spawn:
		if scene == _spawner.escena_imp:
			imp_count += 1
		elif scene == _spawner.escena_goblin_girl:
			girl_count += 1
		elif scene == _spawner.escena_goblin:
			goblin_count += 1
		elif scene == _spawner.escena_imp_escudo:
			shield_count += 1
			
	assert_eq(shield_count, 2, "Wave 2 should have 2 imps shield")
	assert_eq(imp_count, 7, "Wave 2 should have 7 imps normal")
	assert_eq(girl_count, 8, "Wave 2 should have 8 goblin archers")
	assert_eq(goblin_count, 8, "Wave 2 should have 8 goblin crossbows")

	# Verificar restricciones
	assert_ne(_spawner.cola_spawn.back(), _spawner.escena_imp_escudo, "The imp shield cannot be the last one in Wave 2")
	for i in range(_spawner.cola_spawn.size() - 1):
		var is_consecutive = (_spawner.cola_spawn[i] == _spawner.escena_imp_escudo and _spawner.cola_spawn[i+1] == _spawner.escena_imp_escudo)
		assert_false(is_consecutive, "No two imp shields can be consecutive in Wave 2")


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


