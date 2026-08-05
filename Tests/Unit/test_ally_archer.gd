extends "res://addons/gut/test.gd"

var AllyArcherScript = load("res://Entities/Aliada_Arquera/AllyArcher.gd")
var _ally: AllyArcher = null

# Mock para AudioManager
class MockAudioManager extends Node:
	func play_sfx(_name, _boost = 0.0): pass
	func stop_bow_tension(): pass
	func reset_bow_hold(): pass

var _mock_audio_created: bool = false

func before_each():
	_ally = AllyArcherScript.new()
	_agregar_animacion_minima(_ally)

	if not get_tree().root.has_node("AudioManager"):
		var mock_audio = MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)
		_mock_audio_created = true

	get_tree().root.add_child(_ally)

func after_each():
	if is_instance_valid(_ally):
		if _ally.get_parent():
			_ally.get_parent().remove_child(_ally)
		_ally.free()

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

func test_inicializacion_vida():
	assert_eq(_ally.vida_maxima, 2, "La vida máxima por defecto debería ser 2")
	assert_eq(_ally.health, 2, "La salud inicial debería coincidir con vida_maxima")

func test_recibir_dano_no_muere():
	_ally.recibir_dano(1)
	assert_eq(_ally.health, 1, "La salud debería reducirse a 1")
	assert_ne(_ally.current_state, _ally.State.DYING, "No debería estar muriendo con salud > 0")

func test_recibir_dano_muere_y_permanece():
	_ally.recibir_dano(2)
	assert_eq(_ally.health, 0, "La salud debería reducirse a 0")
	assert_eq(_ally.current_state, _ally.State.DYING, "El estado debería ser DYING al quedarse sin salud")
	
	# Simular el timer que pasa de DYING a DEAD
	# Llamamos directamente a la transición para evitar esperar en el test
	_ally._cambiar_estado(_ally.State.DEAD)
	assert_eq(_ally.current_state, _ally.State.DEAD, "El estado debería cambiar a DEAD")
	assert_true(is_instance_valid(_ally), "La arquera debería permanecer en la escena (no autodestruirse)")

func test_revivir_desde_muerta():
	# Forzar estado muerto
	_ally.health = 0
	_ally.current_state = _ally.State.DEAD
	_ally.set_process(false)
	if _ally.hitbox_body:
		_ally.hitbox_body.collision_layer = 0

	_ally.revivir()

	assert_eq(_ally.health, _ally.vida_maxima, "La salud debería restablecerse a vida_maxima")
	assert_eq(_ally.current_state, _ally.State.GETTING_UP, "El estado debería cambiar a GETTING_UP")
	assert_true(_ally.is_processing(), "El procesamiento del nodo debería estar activo")
	if _ally.hitbox_body:
		assert_eq(_ally.hitbox_body.collision_layer, 2, "El hitbox debería volver a la capa de colisión 2")

func test_revivir_rotacion_muerte_01():
	# Crear un model_root dummy para testear rotación
	var dummy_model = Node3D.new()
	dummy_model.name = "ArqueraModel"
	_ally.add_child(dummy_model)
	_ally.model_root = dummy_model
	_ally._original_model_y_rot = 0.0
	
	# Forzar muerte con MUERTE_01
	_ally.ultima_muerte_anim = "MUERTE_01"
	_ally.current_state = _ally.State.DEAD
	
	_ally.revivir()
	
	assert_almost_eq(dummy_model.rotation.y, deg_to_rad(90), 0.0001, "El modelo debería estar rotado 90 grados en Y durante GETTING_UP si la muerte fue MUERTE_01")
	
	# Transicionar fuera de GETTING_UP debería restaurar la rotación original
	_ally._cambiar_estado(_ally.State.IDLE)
	await wait_seconds(0.4)
	assert_eq(dummy_model.rotation.y, 0.0, "La rotación debería restaurarse al salir de GETTING_UP")

func test_invulnerable_durante_getting_up():
	_ally.health = 2
	_ally.current_state = _ally.State.GETTING_UP
	_ally.take_damage(1.0)
	assert_eq(_ally.health, 2, "No debería recibir daño durante el estado GETTING_UP")

func test_enemigos_minimos_es_uno():
	assert_eq(_ally.enemigos_minimos, 1, "Las arqueras aliadas deben empezar a disparar con al menos 1 enemigo")

