extends "res://addons/gut/test.gd"

var debug_level_script = preload("res://Levels/NIVEL_DEBUG/NIVEL_DEBUG.gd")
var debug_scene = preload("res://Levels/NIVEL_DEBUG/NIVEL_DEBUG.tscn")
var AllyArcherScript = preload("res://Entities/Aliada_Arquera/AllyArcher.gd")

class MockAudioManager extends Node:
	func play_sfx(_name, _boost = 0.0): pass
	func stop_bow_tension(): pass
	func reset_bow_hold(): pass

var _mock_audio_created: bool = false


func before_each():
	if not get_tree().root.has_node("AudioManager"):
		var mock_audio = MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)
		_mock_audio_created = true


func after_each():
	if _mock_audio_created and get_tree().root.has_node("AudioManager"):
		var mock_audio = get_tree().root.get_node("AudioManager")
		get_tree().root.remove_child(mock_audio)
		mock_audio.free()
		_mock_audio_created = false


func _agregar_animacion_minima(ally: AllyArcher) -> void:
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	var lib = AnimationLibrary.new()
	lib.add_animation("IDLE", Animation.new())
	lib.add_animation("DISPARO", Animation.new())
	lib.add_animation("MUERTE_01", Animation.new())
	lib.add_animation("MUERTE_02", Animation.new())
	lib.add_animation("LEVANTARSE", Animation.new())
	anim_player.add_animation_library("", lib)
	ally.add_child(anim_player)


func test_calcular_tamano_render_debug() -> void:
	# Arrange
	var nivel = debug_level_script.new()

	# Act
	var tamano_render: Vector2i = nivel._calcular_tamano_render(Vector2(1920, 1080), 0.95)

	# Assert
	assert_eq(tamano_render, Vector2i(1824, 1026), "Debe calcular el tamano de render de forma identica")

	nivel.free()


func test_escena_nivel_debug_contiene_arqueras_aliadas() -> void:
	# Arrange & Act
	var instancia_nivel = debug_scene.instantiate()

	# Assert
	assert_not_null(instancia_nivel, "La escena de NIVEL_DEBUG debe instanciarse correctamente")
	var ally1 = instancia_nivel.get_node_or_null("AllyArcher")
	var ally2 = instancia_nivel.get_node_or_null("AllyArcher2")

	assert_not_null(ally1, "Debe existir el nodo AllyArcher en NIVEL_DEBUG.tscn")
	assert_not_null(ally2, "Debe existir el nodo AllyArcher2 en NIVEL_DEBUG.tscn")

	if ally1:
		assert_almost_eq(ally1.position.x, -7.8802323, 0.01, "AllyArcher X debe coincidir con Nivel 1")
		assert_almost_eq(ally1.position.y, 3.1431754, 0.01, "AllyArcher Y debe coincidir con Nivel 1")
		assert_almost_eq(ally1.scale.x, 0.3, 0.01, "AllyArcher escala debe ser 0.3")

	if ally2:
		assert_almost_eq(ally2.position.x, -7.1104116, 0.01, "AllyArcher2 X debe coincidir con Nivel 1")
		assert_almost_eq(ally2.position.y, 1.585446, 0.01, "AllyArcher2 Y debe coincidir con Nivel 1")
		assert_almost_eq(ally2.scale.x, 0.3, 0.01, "AllyArcher2 escala debe ser 0.3")

	instancia_nivel.free()


func test_toggle_aliadas_visibles_debug() -> void:
	# Arrange
	var nivel = debug_level_script.new()
	var ally = AllyArcherScript.new()
	_agregar_animacion_minima(ally)
	get_tree().root.add_child(ally)

	# Act 1: Toggle a desactivado
	assert_true(nivel._aliadas_activas, "Inicialmente las aliadas deben estar activas")
	nivel._toggle_aliadas_visibles()

	# Assert 1
	assert_false(nivel._aliadas_activas, "El estado _aliadas_activas debe ser false")
	assert_false(ally.visible, "La arquera debe estar invisible")
	assert_false(ally.is_processing(), "El procesamiento debe estar desactivado")

	# Act 2: Toggle de vuelta a activado
	nivel._toggle_aliadas_visibles()

	# Assert 2
	assert_true(nivel._aliadas_activas, "El estado _aliadas_activas debe ser true")
	assert_true(ally.visible, "La arquera debe estar visible")
	assert_true(ally.is_processing(), "El procesamiento debe estar activado")

	get_tree().root.remove_child(ally)
	ally.free()
	nivel.free()


func test_revivir_aliadas_debug() -> void:
	# Arrange
	var nivel = debug_level_script.new()
	var ally = AllyArcherScript.new()
	_agregar_animacion_minima(ally)
	get_tree().root.add_child(ally)

	# Simular arquera muerta
	ally.health = 0
	ally.current_state = AllyArcher.State.DEAD
	ally.set_process(false)

	# Act
	nivel._revivir_aliadas_debug()

	# Assert
	assert_eq(ally.health, ally.vida_maxima, "La vida debe restablecerse al máximo")
	assert_eq(ally.current_state, AllyArcher.State.GETTING_UP, "El estado debe cambiar a GETTING_UP")
	assert_true(ally.is_processing(), "El procesamiento debe reactivarse")
	assert_true(ally.visible, "La arquera debe estar visible")

	get_tree().root.remove_child(ally)
	ally.free()
	nivel.free()


func test_spawn_respeta_selector_tras_evento_cuerno() -> void:
	# Arrange
	var WaveSpawnerScript = load("res://System/Core/WaveSpawner.gd")
	var spawner = WaveSpawnerScript.new()
	var dummy_goblin = PackedScene.new()
	var dummy_girl = PackedScene.new()
	var dummy_lonko = PackedScene.new()
	
	var n_goblin = Node3D.new()
	n_goblin.name = "DummyGoblin"
	dummy_goblin.pack(n_goblin)
	n_goblin.free()

	var n_girl = Node3D.new()
	n_girl.name = "DummyGirl"
	dummy_girl.pack(n_girl)
	n_girl.free()

	var n_lonko = Node3D.new()
	n_lonko.name = "DummyLonko"
	dummy_lonko.pack(n_lonko)
	n_lonko.free()

	spawner.escena_goblin = dummy_goblin
	spawner.escena_goblin_girl = dummy_girl
	spawner.escena_lonko = dummy_lonko
	get_tree().root.add_child(spawner)

	# Simular activación del cuerno (llena cola con goblins)
	spawner._iniciar_evento_cuerno()
	assert_false(spawner.cola_spawn.is_empty(), "La cola debe tener la ráfaga del cuerno")

	# Act: El usuario selecciona Lonko en el selector de debug y pulsa spawn
	spawner.forzar_tipo_enemigo = 6  # 6 = Lonko
	spawner.forzar_spawn()

	# Assert: El enemigo instanciado debe ser Lonko
	assert_gt(spawner.active_goblins.size(), 0, "Debe haberse spawneado al menos un enemigo")
	var ultimo_enemigo = spawner.active_goblins.back()
	assert_eq(ultimo_enemigo.name, "DummyLonko", "El enemigo spawneado debe ser Lonko respetando la selección")

	for enemy in spawner.active_goblins:
		if is_instance_valid(enemy):
			if enemy.get_parent():
				enemy.get_parent().remove_child(enemy)
			enemy.free()
	get_tree().root.remove_child(spawner)
	spawner.free()


func test_nivel_debug_player_inicia_con_5_flechas_explosivas() -> void:
	# Arrange & Act
	var instancia_nivel = debug_scene.instantiate()

	# Assert
	var player = instancia_nivel.get_node_or_null("Player")
	assert_not_null(player, "Debe existir el nodo Player en NIVEL_DEBUG")
	if player:
		assert_eq(player.flechas_explosivas, 5, "El jugador debe iniciar con 5 flechas explosivas en el nivel debug")

	instancia_nivel.free()


func test_nivel_debug_iniciar_oleadas_libres_imp_default_active() -> void:
	# Arrange
	var WaveSpawnerScript = load("res://System/Core/WaveSpawner.gd")
	var nivel = debug_level_script.new()
	var spawner = WaveSpawnerScript.new()
	nivel.wave_spawner = spawner

	# Act
	nivel._iniciar_oleadas_libres()

	# Assert
	assert_eq(spawner.forzar_tipo_enemigo, 2, "El tipo de enemigo forzado por defecto debe ser 2 (Imp Normal)")
	assert_true(spawner.is_wave_active, "Las oleadas deben estar activas por defecto")
	assert_true(spawner.spawn_infinito, "El spawn debe ser infinito en oleadas libres")

	spawner.free()
	nivel.free()


