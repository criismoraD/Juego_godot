extends "res://addons/gut/test.gd"

## El botón debug de alternar defensoras debe crear la unidad nueva con la vida
## completa DE SU TIPO (arquera 2, ballestera 4). Antes copiaba la vida cruda y la
## ballestera de piso quedaba con 2 (moría de 2 disparos).

var GameUIScript = load("res://UI/GameUI.gd")
var ArqueraScene: PackedScene = load("res://Entities/Aliada_Arquera/AllyArcher.tscn")

var _game_ui = null
var _cont: Node3D = null
var _mock_audio_created: bool = false


class MockAudioManager extends Node:
	func play_sfx(_nombre: String, _boost: float = 0.0) -> void:
		pass

	func play_music(_index: int) -> void:
		pass

	func stop_all() -> void:
		pass


func before_each() -> void:
	if not get_tree().root.has_node("AudioManager"):
		var mock_audio := MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)
		_mock_audio_created = true
	AllyArcher.active_allies_cache.clear()
	GameUI.usar_ballesteras = false
	_game_ui = GameUIScript.new()
	add_child_autofree(_game_ui)
	_cont = Node3D.new()
	_cont.name = "ContenedorAliadasTest"
	add_child_autofree(_cont)


func after_each() -> void:
	for ally in AllyArcher.active_allies_cache.duplicate():
		AllyArcher.active_allies_cache.erase(ally)
	GameUI.usar_ballesteras = false
	if _mock_audio_created and get_tree().root.has_node("AudioManager"):
		var mock_audio: Node = get_tree().root.get_node("AudioManager")
		get_tree().root.remove_child(mock_audio)
		mock_audio.free()
		_mock_audio_created = false


func _crear_arquera_sana():
	var arquera = ArqueraScene.instantiate()
	_cont.add_child(arquera)
	arquera.global_position = Vector3(-7.1, 1.58, 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(AllyArcher.active_allies_cache.has(arquera), "La arquera debe registrarse en active_allies_cache")
	return arquera


func _buscar_ballestera() -> AllyBallestera:
	for ally in AllyArcher.active_allies_cache:
		if is_instance_valid(ally) and ally is AllyBallestera:
			return ally as AllyBallestera
	return null


func _buscar_arquera() -> AllyArcher:
	for ally in AllyArcher.active_allies_cache:
		if is_instance_valid(ally) and ally is AllyArcher:
			return ally as AllyArcher
	return null


func test_alternar_a_ballestera_entra_con_vida_4_y_aguanta_2_disparos() -> void:
	# Arrange: arquera de piso sana (2/2)
	var arquera := await _crear_arquera_sana()
	assert_eq(arquera.health, 2, "Precondición: la arquera sana tiene 2 de vida")
	assert_eq(arquera.vida_maxima, 2, "Precondición: la arquera tiene máximo 2")

	# Act: alternar a ballesteras (misma vía que el botón debug)
	_game_ui._alternar_tipo_defensoras()
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: la ballestera nueva tiene vida completa de SU tipo
	var ballestera := _buscar_ballestera()
	assert_not_null(ballestera, "Debe existir la ballestera reemplazada")
	assert_eq(ballestera.vida_maxima, 4, "La ballestera fija tiene máximo 4")
	assert_eq(ballestera.health, 4, "La ballestera nueva entra con 4 de vida, no con 2 copiados")

	# Assert: aguanta 2 disparos sin morir (el bug la mataba con 2)
	ballestera.recibir_dano(1)
	ballestera.recibir_dano(1)
	assert_eq(ballestera.health, 2, "Tras 2 disparos debe quedar con 2 de vida")
	assert_ne(ballestera.current_state, ballestera.State.DYING, "No debe entrar en DYING con 2 disparos")
	assert_ne(ballestera.current_state, ballestera.State.DEAD, "No debe estar muerta con 2 disparos")


func test_alternar_de_vuelta_a_arquera_sin_sobrevida() -> void:
	# Arrange: arquera -> ballestera -> arquera
	await _crear_arquera_sana()
	_game_ui._alternar_tipo_defensoras()
	await get_tree().process_frame
	var ballestera := _buscar_ballestera()
	assert_not_null(ballestera, "Debe existir la ballestera intermedia")

	# Act: volver a arqueras
	_game_ui._alternar_tipo_defensoras()
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: la arquera no hereda los 4 de vida de la ballestera
	var arquera := _buscar_arquera()
	assert_not_null(arquera, "Debe existir la arquera reemplazada")
	assert_eq(arquera.vida_maxima, 2, "La arquera tiene máximo 2")
	assert_eq(arquera.health, 2, "La arquera nueva entra con 2 de vida, sin sobrevida")
