extends "res://addons/gut/test.gd"

## Tests unitarios para el sistema de Squash & Stretch de Eryn (Player.gd)
## Evalúa el estiramiento sutil vertical durante caída libre desde altura
## y la compresión elástica con retorno suave al aterrizar.

var PlayerScript: GDScript = preload("res://Entities/Jugador_Arquera/Player.gd")
var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestPlayer"
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

	var model := Node3D.new()
	model.name = "ArqueraModel"
	model.scale = Vector3(3.1, 3.1, 3.1)
	player.add_child(model)
	_root_test.add_child(player)
	return player


func test_player_squash_stretch_inicializacion_escala() -> void:
	# Arrange & Act
	var player: Player = _crear_player()

	# Assert
	assert_not_null(player.visual_model, "Debe detectar ArqueraModel como visual_model")
	assert_eq(player._squash_stretch_current, Vector3.ONE, "El factor inicial debe ser Vector3.ONE")
	assert_almost_eq(player.visual_model.scale.x, player._original_model_scale.x, 0.001, "La escala X debe coincidir con la original")
	assert_almost_eq(player.visual_model.scale.y, player._original_model_scale.y, 0.001, "La escala Y debe coincidir con la original")


func test_player_stretch_vertical_en_caida_libre_desde_altura() -> void:
	# Arrange
	var player: Player = _crear_player()

	# Act: Simular caída desde altura en el aire
	player.current_move_state = Player.MoveState.AIR
	player._was_in_air_from_height = true
	player._fall_start_y = 10.0
	player.global_position.y = 5.0
	player.velocity.y = -8.0

	# Varios pasos de física para que el lerp alcance la deformación de caída
	for i in range(10):
		player._actualizar_squash_stretch_aire(0.016)

	# Assert: En caída libre rápida, el modelo se estira verticalmente (Y) y se adelgaza en X/Z
	assert_gt(player.visual_model.scale.y, player._original_model_scale.y, "El modelo debe estirarse verticalmente al caer de altura")
	assert_lt(player.visual_model.scale.x, player._original_model_scale.x, "El modelo debe comprimirse sutilmente en X para conservar volumen")
	assert_lt(player.visual_model.scale.z, player._original_model_scale.z, "El modelo debe comprimirse sutilmente en Z para conservar volumen")


func test_player_squash_al_aterrizar_tras_caida_y_retorno_suave() -> void:
	# Arrange
	var player: Player = _crear_player()
	player.set_physics_process(false)

	# Act 1: Disparar el squash de impacto al aterrizar
	player._disparar_squash_aterrizaje(-7.0, 3.0)

	# Assert 1: Se activó el tween de squash
	assert_true(player._is_squash_tween_active, "El tween de squash debe estar activo tras aterrizar")

	# Assert 2: En el impacto inmediato, el modelo se comprime en Y y se ensancha en X/Z
	assert_lt(player.visual_model.scale.y, player._original_model_scale.y, "El modelo debe comprimirse en Y al aterrizar")
	assert_gt(player.visual_model.scale.x, player._original_model_scale.x, "El modelo debe ensancharse en X al absorber el impacto")

	# Act 2: Esperar que complete el rebote y asentamiento elástico
	await wait_seconds(0.5)

	# Assert 3: Retorno suave a la escala normal
	assert_false(player._is_squash_tween_active, "El tween debe finalizar")
	assert_almost_eq(player.visual_model.scale.y, player._original_model_scale.y, 0.05, "Debe asentarse suavemente a su escala original")
	assert_almost_eq(player.visual_model.scale.x, player._original_model_scale.x, 0.05, "Debe asentarse suavemente a su escala horizontal original")


func test_player_sin_squash_stretch_si_esta_deshabilitado() -> void:
	# Arrange
	var player: Player = _crear_player()
	player.habilitar_squash_stretch = false

	# Act: Simular caída fuerte
	player.current_move_state = Player.MoveState.AIR
	player._was_in_air_from_height = true
	player._fall_start_y = 10.0
	player.velocity.y = -10.0
	player._actualizar_squash_stretch_aire(0.05)
	player._disparar_squash_aterrizaje(-10.0, 5.0)

	# Assert: No se altera la escala
	assert_eq(player.visual_model.scale, player._original_model_scale, "No debe deformarse si habilitar_squash_stretch es false")
