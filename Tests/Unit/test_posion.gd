extends "res://addons/gut/test.gd"

var PosionScript = load("res://Pocion/Posion.gd")
var PlayerScript = load("res://Entities/Player/Player.gd")
var ImpShieldGirlScript = load("res://Entities/Enemies/ImpShieldGirl/ImpShieldGirl.gd")

var _posion: Posion = null
var _player: Player = null

func before_each():
	_posion = PosionScript.new()
	_player = PlayerScript.new()
	_player.vida_maxima = 4
	_player.health = 3
	add_child_autofree(_posion)
	add_child_autofree(_player)

func test_posion_initialization():
	# Arrange & Act
	var ruby_light = OmniLight3D.new()
	ruby_light.name = "RubyLight"
	_posion.add_child(ruby_light)
	_posion.ruby_light = ruby_light

	# Assert
	assert_not_null(_posion, "La poción debe instanciarse correctamente")
	assert_eq(_posion.vida_a_restaurar, 1, "Por defecto restored health debe ser 1")
	assert_eq(_posion.tiempo_vida_completa, 5.0, "Tiempo con vida completa debe ser 5.0 segundos")

func test_player_curar_method():
	# Arrange
	_player.health = 2
	_player.vida_maxima = 4

	# Act
	_player.curar(1)

	# Assert
	assert_eq(_player.health, 3, "El método curar(1) debe aumentar la vida en 1")

	# Act: Curar más allá del máximo
	_player.curar(5)
	assert_eq(_player.health, 4, "La vida curada no debe superar vida_maxima")

func test_posion_full_health_duration_config():
	# Arrange & Act & Assert
	assert_eq(_posion.tiempo_vida_completa, 5.0, "La configuración de duración para vida completa debe ser exactamente 5.0s")

func test_impshieldgirl_drop_scene_assigned():
	# Arrange
	var imp = ImpShieldGirlScript.new()
	add_child_autofree(imp)

	# Assert
	assert_not_null(imp.posion_scene, "ImpShieldGirl debe tener asignada la escena posion_scene por defecto")
