extends GutTest

## La protagonista debe poder agacharse con S al pie de la escalera
## (tocando el piso inferior) en vez de trepar. Arriba, S sigue bajando por ella.

var PlayerScene = load("res://Entities/Jugador_Arquera/Player.tscn")
var LadderScene = load("res://Entities/Ambiente_Escalera/ESCALERA.tscn")

class MockAudioManager extends Node:
	func play_sfx(_name, _boost = 0.0): pass
	func stop_bow_tension(): pass
	func reset_bow_hold(): pass

var _mock_audio_created: bool = false
var _nodes_to_clean: Array[Node] = []


func before_each() -> void:
	if not get_tree().root.has_node("AudioManager"):
		var mock_audio = MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)
		_mock_audio_created = true


func after_each() -> void:
	Input.action_release("move_back")
	Input.action_release("move_forward")
	for n in _nodes_to_clean:
		if is_instance_valid(n):
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()
	_nodes_to_clean.clear()

	if _mock_audio_created and get_tree().root.has_node("AudioManager"):
		var mock_audio = get_tree().root.get_node("AudioManager")
		get_tree().root.remove_child(mock_audio)
		mock_audio.free()
		_mock_audio_created = false


func _crear_suelo(y_top: float = 0.0) -> StaticBody3D:
	var suelo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 1.0, 4.0)
	col.shape = box
	# Tope del suelo en y_top
	suelo.position = Vector3(-7.0, y_top - 0.5, 0.0)
	suelo.add_child(col)
	get_tree().root.add_child(suelo)
	_nodes_to_clean.append(suelo)
	return suelo


func _crear_jugadora_en_piso() -> Node:
	_crear_suelo(0.0)
	var player = PlayerScene.instantiate()
	get_tree().root.add_child(player)
	_nodes_to_clean.append(player)
	player.global_position = Vector3(-7.58, 0.5, 0.05)
	# Dejarla reposar hasta tocar suelo
	for i in range(40):
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	return player



func test_esta_al_pie_de_escalera() -> void:
	var player = await _crear_jugadora_en_piso()
	var ladder = LadderScene.instantiate()
	get_tree().root.add_child(ladder)
	_nodes_to_clean.append(ladder)
	ladder.global_position = Vector3(-7.58, 0.22, -0.3)
	await get_tree().physics_frame

	# Abajo, al pie: true
	player.global_position = Vector3(-7.58, 0.1, 0.05)
	player.set_near_ladder(true, ladder)
	assert_true(player._esta_al_pie_de_escalera(), "Al pie de la escalera debe reportar pie")

	# Arriba (plataforma 1): false
	player.global_position = Vector3(-7.58, 1.7, 0.05)
	assert_false(player._esta_al_pie_de_escalera(), "Arriba de la escalera no debe reportar pie")


func test_s_agacha_al_pie_en_vez_de_trepar() -> void:
	var player = await _crear_jugadora_en_piso()
	assert_true(player.is_on_floor(), "Precondición: la jugadora toca el piso inferior")
	var ladder = LadderScene.instantiate()
	get_tree().root.add_child(ladder)
	_nodes_to_clean.append(ladder)
	ladder.global_position = Vector3(-7.58, 0.22, -0.3)
	player.global_position = Vector3(-7.58, 0.0, 0.05)
	for i in range(5):
		await get_tree().physics_frame
	ladder._on_body_entered(player)
	assert_true(player.is_near_ladder, "Precondición: cerca de la escalera")
	player.current_move_state = player.MoveState.GROUND
	player.ladder_cooldown = 0.0

	# Act: presionar S (abajo) al pie de la escalera
	Input.action_press("move_back")
	for i in range(10):
		await get_tree().physics_frame


	# Assert: se agacha, no trepa
	assert_eq(player.current_move_state, player.MoveState.CROUCHING, "S al pie de la escalera debe agachar, no trepar")
