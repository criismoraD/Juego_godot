extends "res://addons/gut/test.gd"

## Tests unitarios para el efecto de temblor/tiritar del arco al tensar (Player.gd).
## Verifica que el arco y la flecha comiencen con vibracion sutil mientras se tensa,
## alcancen su nivel base al 100% de la barra verde, y se acentuen perceptiblemente
## de forma dramatica con la sobrecarga morada activa, restaurandose al disparar o cancelar.

var PlayerScript: GDScript = preload("res://Entities/Jugador_Arquera/Player.gd")
var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestPlayerBowTremor"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()


func _crear_player() -> Player:
	var player: Player = PlayerScript.new()

	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	player.add_child(anim_player)

	var anim_tree := AnimationTree.new()
	anim_tree.name = "AnimationTree"
	anim_tree.anim_player = NodePath("../AnimationPlayer")
	player.add_child(anim_tree)

	var charge_bar := ProgressBar.new()
	charge_bar.name = "ChargeBar"
	player.add_child(charge_bar)
	player.charge_bar = charge_bar

	var overcharge_bar := ProgressBar.new()
	overcharge_bar.name = "OverchargeBar"
	player.add_child(overcharge_bar)
	player.overcharge_bar = overcharge_bar

	var model := Node3D.new()
	model.name = "ArqueraModel"
	player.add_child(model)

	var bow := Node3D.new()
	bow.name = "ARCO_ANIMADO"
	bow.position = Vector3(0.2, 1.1, -0.4)
	bow.rotation = Vector3(0.1, 0.2, 0.3)
	player.add_child(bow)

	var arrow := Node3D.new()
	arrow.name = "FLECHA"
	arrow.position = Vector3(0.2, 1.1, -0.4)
	arrow.visible = false
	player.add_child(arrow)

	_root_test.add_child(player)
	player._ready()

	return player


func test_temblor_arco_en_idle_sin_tensar_mantiene_reposo() -> void:
	# Arrange
	var player: Player = _crear_player()
	player.current_aim_state = Player.AimState.NONE

	# Act
	player._actualizar_temblor_arco(0.016)

	# Assert
	assert_eq(player.bow_node.position, player._bow_base_position, "En reposo (NONE) el arco debe estar exactamente en su posicion base")
	assert_eq(player.bow_node.rotation, player._bow_base_rotation, "En reposo (NONE) la rotacion del arco debe coincidir con la base")


func test_temblor_arco_al_tensar_verde_vibra_con_amplitud_base() -> void:
	# Arrange
	var player: Player = _crear_player()
	player.current_aim_state = Player.AimState.AIMING
	player.charge_time = player.duracion_carga
	player.sobrecarga_time = 0.0

	# Act: Avanzar varios frames de temblor
	var max_dist: float = 0.0
	for i in range(10):
		player._actualizar_temblor_arco(0.02)
		var dist: float = player.bow_node.position.distance_to(player._bow_base_position)
		if dist > max_dist:
			max_dist = dist

	# Assert: El arco vibra respecto a su posicion base dentro del orden de amplitud base
	assert_gt(max_dist, 0.004, "El arco debe temblar con la barra verde llena")
	assert_lt(max_dist, player.amplitud_temblor_base * 2.5, "La vibracion verde no debe sobrepasar el rango esperado")


func test_temblor_arco_sobrecarga_morada_se_acentua_fuertemente() -> void:
	# Arrange
	var player: Player = _crear_player()
	player.current_aim_state = Player.AimState.AIMING
	player.charge_time = player.duracion_carga

	# Medir vibracion maxima en verde
	player.sobrecarga_time = 0.0
	var max_verde: float = 0.0
	for i in range(15):
		player._actualizar_temblor_arco(0.02)
		var d: float = player.bow_node.position.distance_to(player._bow_base_position)
		if d > max_verde:
			max_verde = d

	# Medir vibracion con barra morada activa al 100%
	player.sobrecarga_time = player.duracion_sobrecarga
	var max_morada: float = 0.0
	for i in range(15):
		player._actualizar_temblor_arco(0.02)
		var d: float = player.bow_node.position.distance_to(player._bow_base_position)
		if d > max_morada:
			max_morada = d

	# Assert: Con la barra morada cargada, el temblor es perceptiblemente mucho mas intenso (>2.0x)
	assert_gt(max_morada, max_verde * 2.0, "El temblor con la barra morada cargada debe acentuarse drasticamente frente a la verde")


func test_detener_temblor_arco_restaura_posicion_y_rotacion_exactas() -> void:
	# Arrange
	var player: Player = _crear_player()
	player.current_aim_state = Player.AimState.AIMING
	player.charge_time = player.duracion_carga
	player.sobrecarga_time = player.duracion_sobrecarga
	player._actualizar_temblor_arco(0.05)

	# Verificar que efectivamente se desplazo
	assert_ne(player.bow_node.position, player._bow_base_position, "El arco debe haberse desplazado por el temblor")

	# Act: Detener temblor (al soltar el disparo o cancelar)
	player._detener_temblor_arco()

	# Assert: Restitucion inmediata
	assert_eq(player.bow_node.position, player._bow_base_position, "Al detener el temblor la posicion debe volver a la base")
	assert_eq(player.bow_node.rotation, player._bow_base_rotation, "Al detener el temblor la rotacion debe volver a la base")


func test_temblor_arco_deshabilitado_no_produce_movimiento() -> void:
	# Arrange
	var player: Player = _crear_player()
	player.habilitar_temblor_arco = false
	player.current_aim_state = Player.AimState.AIMING
	player.charge_time = player.duracion_carga
	player.sobrecarga_time = player.duracion_sobrecarga

	# Act
	player._actualizar_temblor_arco(0.05)

	# Assert
	assert_eq(player.bow_node.position, player._bow_base_position, "Si habilitar_temblor_arco es false, el arco no se desplaza")
	assert_eq(player.bow_node.rotation, player._bow_base_rotation, "Si habilitar_temblor_arco es false, la rotacion no cambia")


func test_flecha_sostenida_vibra_en_sincronia_con_el_arco() -> void:
	# Arrange
	var player: Player = _crear_player()
	player.arrow_node.visible = true
	player.current_aim_state = Player.AimState.AIMING
	player.charge_time = player.duracion_carga
	player.sobrecarga_time = player.duracion_sobrecarga

	# Act
	player._actualizar_temblor_arco(0.03)

	# Assert
	var bow_offset: Vector3 = player.bow_node.position - player._bow_base_position
	var arrow_offset: Vector3 = player.arrow_node.position - player._arrow_base_position
	assert_almost_eq(bow_offset.x, arrow_offset.x, 0.0001, "La flecha debe vibrar sincronicamente con el arco en X")
	assert_almost_eq(bow_offset.y, arrow_offset.y, 0.0001, "La flecha debe vibrar sincronicamente con el arco en Y")
	assert_almost_eq(bow_offset.z, arrow_offset.z, 0.0001, "La flecha debe vibrar sincronicamente con el arco en Z")
