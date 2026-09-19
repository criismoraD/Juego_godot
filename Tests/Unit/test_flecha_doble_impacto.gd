extends "res://addons/gut/test.gd"

## Un impacto (rayo CCD + área en el mismo vuelo) debe dañar una sola vez.

class MunecoDano:
	extends Node3D
	var impactos: int = 0
	var ultimo_dano: float = 0.0

	func take_damage(amount: float) -> void:
		impactos += 1
		ultimo_dano = amount


var ArrowScene = load("res://Entities/Proyectil_Flecha/Arrow.tscn")

var _arrow: Area3D = null
var _muneco: Node3D = null


func after_each():
	if is_instance_valid(_arrow):
		_arrow.free()
	if is_instance_valid(_muneco):
		_muneco.free()
	_arrow = null
	_muneco = null


func test_doble_evento_un_solo_dano() -> void:
	# Arrange
	_arrow = ArrowScene.instantiate()
	_muneco = MunecoDano.new()
	_muneco.add_to_group("enemies")
	get_tree().root.add_child(_muneco)
	get_tree().root.add_child(_arrow)

	# Act: el rayo y el área reportan el mismo impacto
	_arrow._on_body_entered(_muneco)
	_arrow._on_body_entered(_muneco)

	# Assert: un solo daño (y una sola animación de daño en la víctima)
	assert_eq(_muneco.impactos, 1, "Un impacto = un daño aunque llegue por rayo y área")


func test_flecha_fuego_rapido_dano_doble() -> void:
	# Arrange
	_arrow = ArrowScene.instantiate()
	_muneco = MunecoDano.new()
	_muneco.add_to_group("enemies")
	get_tree().root.add_child(_muneco)
	get_tree().root.add_child(_arrow)
	_arrow.set_meta("fuego_rapido", true)

	# Act
	_arrow._on_body_entered(_muneco)

	# Assert: más fuerte con el power-up
	assert_eq(_muneco.impactos, 1, "Un solo daño")
	assert_almost_eq(_muneco.ultimo_dano, 2.0, 0.001, "Daño x2 con fuego rápido")
