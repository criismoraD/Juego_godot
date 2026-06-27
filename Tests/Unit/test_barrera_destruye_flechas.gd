extends "res://addons/gut/test.gd"

var BarreraScript = load("res://Entities/Environment/BarreraLimite/BarreraDestruyeFlechas.gd")
var ArrowScene = load("res://Entities/Projectiles/Arrow.tscn")
var AllyArrowScene = load("res://Entities/Projectiles/AllyArrow.tscn")

var _barrera: StaticBody3D = null
var _arrow: Area3D = null
var _ally_arrow: Area3D = null


func before_each():
	_barrera = BarreraScript.new()
	get_tree().root.add_child(_barrera)


func after_each():
	if is_instance_valid(_barrera):
		_barrera.free()
	if is_instance_valid(_arrow):
		_arrow.free()
	if is_instance_valid(_ally_arrow):
		_ally_arrow.free()


func test_barrera_properties():
	assert_true(_barrera.is_in_group("barrera_destruye_flechas"), "Debería estar en el grupo barrera_destruye_flechas")
	assert_eq(_barrera.collision_layer, 4, "La capa de colisión debería ser la 3 (bit 2 = valor 4)")
	assert_eq(_barrera.collision_mask, 0, "No debería colisionar con nada activamente (collision_mask = 0)")


func test_arrow_destroyed_by_barrier():
	# Arrange
	_arrow = ArrowScene.instantiate()
	get_tree().root.add_child(_arrow)

	# Act
	_arrow._on_body_entered(_barrera)

	# Assert
	assert_true(_arrow.get("_destroying"), "La flecha del jugador debería destruirse al chocar con la barrera")


func test_ally_arrow_destroyed_by_barrier():
	# Arrange
	_ally_arrow = AllyArrowScene.instantiate()
	get_tree().root.add_child(_ally_arrow)

	# Act
	_ally_arrow._on_body_entered(_barrera)

	# Assert
	assert_true(_ally_arrow.get("_destroying"), "La flecha aliada debería destruirse al chocar con la barrera")
