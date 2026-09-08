extends "res://addons/gut/test.gd"
## Tests del efecto de sangre NO LETAL en la protagonista y las defensoras
## aliadas (arquera y ballestera): un impacto que no mata debe spawner el
## BloodSplashNoLetal en el punto de impacto.

var PlayerScript = load("res://Entities/Jugador_Arquera/Player.gd")
var AllyArcherScene: PackedScene = load("res://Entities/Aliada_Arquera/AllyArcher.tscn")
var AllyBallesteraScript = load("res://Entities/Aliada_Ballestera/AllyBallestera.gd")
var ESCENA_SANGRE: PackedScene = load("res://VFX/Scenes/BloodSplashNoLetal.tscn")

var _player: Player = null

# Mock para AudioManager
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
	if is_instance_valid(_player):
		_player.free()
		_player = null
	if _mock_audio_created and get_tree().root.has_node("AudioManager"):
		var mock_audio = get_tree().root.get_node("AudioManager")
		get_tree().root.remove_child(mock_audio)
		mock_audio.free()
		_mock_audio_created = false
	# Limpiar los splash spawneados por los tests
	for splash in get_tree().root.find_children("BloodSplashNoLetal", "AnimatedSprite3D", true, false):
		splash.free()


func _agregar_animacion_minima(player: Player) -> void:
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	player.add_child(anim_player)

	var anim_tree := AnimationTree.new()
	anim_tree.name = "AnimationTree"
	anim_tree.anim_player = NodePath("../AnimationPlayer")
	player.add_child(anim_tree)


func _contar_sangres() -> int:
	return get_tree().root.find_children("BloodSplashNoLetal", "AnimatedSprite3D", true, false).size()


func test_player_dano_no_letal_spawnea_sangre() -> void:
	# Arrange: protagonista sana con posición de impacto registrada
	_player = PlayerScript.new()
	_agregar_animacion_minima(_player)
	_player.vida_maxima = 5
	_player.health = 5
	get_tree().root.add_child(_player)
	_player.global_position = Vector3(2.0, 1.0, 0.0)
	_player.last_hit_position = Vector3(2.0, 1.2, 0.0)
	_player.last_hit_direction = Vector3.LEFT
	await get_tree().process_frame
	var sangres_antes := _contar_sangres()

	# Act: golpe no letal
	_player.recibir_dano(1)

	# Assert: la sangre apareció y la protagonista sigue viva
	assert_eq(_player.health, 4, "La protagonista debe seguir viva (4/5)")
	assert_eq(_contar_sangres(), sangres_antes + 1, "El daño no letal debe spawner 1 BloodSplashNoLetal")


func test_player_dano_letal_no_spawnea_sangre_no_letal() -> void:
	# Arrange: protagonista a 1 de vida
	_player = PlayerScript.new()
	_agregar_animacion_minima(_player)
	_player.vida_maxima = 5
	_player.health = 1
	get_tree().root.add_child(_player)
	_player.global_position = Vector3(2.0, 1.0, 0.0)
	await get_tree().process_frame
	var sangres_antes := _contar_sangres()

	# Act: golpe letal
	_player.recibir_dano(1)

	# Assert: sin sangre no letal (el flujo de muerte usa sus propios VFX)
	assert_eq(_player.health, 0, "La protagonista debe quedar a 0 de vida")
	assert_eq(_contar_sangres(), sangres_antes, "El golpe letal NO debe spawner sangre no letal")


func test_arquera_dano_no_letal_spawnea_sangre() -> void:
	# Arrange: arquera con 2 de vida (no muere con 1 golpe)
	var arquera := AllyArcherScene.instantiate() as AllyArcher
	add_child_autofree(arquera)
	arquera.last_hit_position = arquera.global_position + Vector3(0.0, 0.8, 0.0)
	arquera.last_hit_direction = Vector3.LEFT
	var sangres_antes := _contar_sangres()

	# Act: golpe no letal
	arquera.take_damage(1.0)

	# Assert
	assert_gt(arquera.health, 0, "La arquera debe seguir viva")
	assert_eq(_contar_sangres(), sangres_antes + 1, "El daño no letal a la arquera debe spawner sangre")


func test_ballestera_dano_no_letal_spawnea_sangre() -> void:
	# Arrange: ballestera con animaciones mínimas y 4 de vida
	var ballestera: AllyBallestera = AllyBallesteraScript.new()
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	lib.add_animation("Impacto", Animation.new())
	anim_player.add_animation_library("", lib)
	ballestera.add_child(anim_player)
	add_child_autofree(ballestera)
	ballestera.last_hit_position = ballestera.global_position + Vector3(0.0, 0.8, 0.0)
	ballestera.last_hit_direction = Vector3.LEFT
	var sangres_antes := _contar_sangres()

	# Act: golpe no letal
	ballestera.recibir_dano(1)

	# Assert
	assert_eq(ballestera.health, 3, "La ballestera debe seguir viva (3/4)")
	assert_eq(_contar_sangres(), sangres_antes + 1, "El daño no letal a la ballestera debe spawner sangre")


func test_ballestera_dano_letal_sin_sangre_no_letal() -> void:
	# Arrange: ballestera a 1 de vida
	var ballestera: AllyBallestera = AllyBallesteraScript.new()
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	lib.add_animation("Impacto", Animation.new())
	lib.add_animation("MUERTE_01", Animation.new())
	anim_player.add_animation_library("", lib)
	ballestera.add_child(anim_player)
	add_child_autofree(ballestera)
	ballestera.health = 1
	ballestera.last_hit_position = ballestera.global_position + Vector3(0.0, 0.8, 0.0)
	ballestera.last_hit_direction = Vector3.LEFT
	var sangres_antes := _contar_sangres()

	# Act: golpe letal
	ballestera.recibir_dano(1)

	# Assert: sin sangre no letal (la muerte conserva su flujo propio)
	assert_eq(ballestera.health, 0, "La ballestera debe quedar a 0 de vida")
	assert_eq(_contar_sangres(), sangres_antes, "El golpe letal NO debe spawner sangre no letal en la ballestera")


func test_sangre_no_letal_usa_posicion_de_impacto() -> void:
	# Arrange: protagonista con punto de impacto conocido
	_player = PlayerScript.new()
	_agregar_animacion_minima(_player)
	_player.vida_maxima = 5
	_player.health = 5
	get_tree().root.add_child(_player)
	var hit_pos := Vector3(7.0, 1.4, 0.0)
	_player.last_hit_position = hit_pos
	_player.last_hit_direction = Vector3.RIGHT
	await get_tree().process_frame

	# Act
	_player.recibir_dano(1)
	await get_tree().process_frame

	# Assert: el splash quedó en el punto exacto del impacto
	var sangres := get_tree().root.find_children("BloodSplashNoLetal", "AnimatedSprite3D", true, false)
	assert_eq(sangres.size(), 1, "Debe existir exactamente 1 splash de sangre")
	if sangres.size() == 1:
		var splash: Node3D = sangres[0] as Node3D
		assert_almost_eq(splash.global_position.x, hit_pos.x, 0.01, "El splash debe nacer en la X del impacto")
		assert_almost_eq(splash.global_position.y, hit_pos.y, 0.01, "El splash debe nacer en la Y del impacto")
