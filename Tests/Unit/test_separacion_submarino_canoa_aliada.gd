extends "res://addons/gut/test.gd"

## Tests unitarios de la separación anti-submarino de la canoa aliada base
## (CanoaAliada, ej. las generadas por el controlador de trayectorias).
## Ninguna canoa aliada debe atravesar un casco: al solaparse hace tamboleo
## y sale hacia el lado más cercano hasta dejar el casco despejado.

const ESCENA_CANOA_ALIADA: PackedScene = preload("res://Entities/Ambiente_Canoa_Aliada/CanoaAliada.tscn")
const MARGEN_FLOAT: float = 0.05
const AMPLITUD_BALANCEO_BASE: float = 2.5
const MEDIO_CASCO_ESPERADO: float = 6.5  ## 5.0 defecto + 1.5 margen


class DummySubmarino extends Node3D:
	pass


class DummySubmarinoSumergido extends Node3D:
	func esta_en_superficie() -> bool:
		return false


func _crear_canoa() -> CanoaAliada:
	var canoa: CanoaAliada = ESCENA_CANOA_ALIADA.instantiate() as CanoaAliada
	add_child_autofree(canoa)
	canoa.global_position = Vector3(0.0, 0.0, 0.0)
	canoa.expulsar_maderos_en_impacto = false
	return canoa


func _crear_submarino(x: float, z: float = 0.0) -> Node3D:
	var sub := DummySubmarino.new()
	sub.add_to_group("submarino")
	add_child_autofree(sub)
	sub.global_position = Vector3(x, 0.0, z)
	return sub


func _avanzar(canoa: CanoaAliada, frames: int, delta: float = 0.05) -> void:
	for i in range(frames):
		canoa._process(delta)


func test_solape_dispara_tamboleo_y_separa_a_la_izquierda() -> void:
	# Arrange: submarino a +2m (solapado, canoa a su izquierda)
	var canoa: CanoaAliada = _crear_canoa()
	var sub: Node3D = _crear_submarino(2.0)

	# Act
	_avanzar(canoa, 10)

	# Assert
	assert_true(canoa.esta_separando_submarino(), "Debe detectar el solape con el submarino")
	assert_gt(canoa.amplitud_balanceo, AMPLITUD_BALANCEO_BASE, "El tamboleo debe elevar el balanceo")

	# Act: dejar que complete la separación (6.5m a 8 m/s ≈ 0.9s)
	_avanzar(canoa, 30)

	# Assert: proa despejada a la izquierda del casco
	var x_segura: float = sub.global_position.x - MEDIO_CASCO_ESPERADO
	assert_le(canoa.obtener_posicion_base().x, x_segura + 0.6, "Debe salir del casco hacia la izquierda")
	assert_lt(canoa.global_position.x, sub.global_position.x, "Nunca debe atravesar al submarino")


func test_solape_por_la_derecha_separa_a_la_derecha() -> void:
	# Arrange: submarino a -2m (canoa a su derecha, lado más cercano)
	var canoa: CanoaAliada = _crear_canoa()
	var sub: Node3D = _crear_submarino(-2.0)

	# Act
	_avanzar(canoa, 40)

	# Assert: sale hacia la derecha sin cruzar el casco
	var x_segura: float = sub.global_position.x + MEDIO_CASCO_ESPERADO
	assert_ge(canoa.obtener_posicion_base().x, x_segura - 0.6, "Debe salir del casco hacia la derecha")
	assert_gt(canoa.global_position.x, sub.global_position.x, "Nunca debe cruzar hacia el otro lado")


func test_submarino_en_otro_cauce_no_reacciona() -> void:
	# Arrange: submarino encima en X pero 10m al fondo en Z
	var canoa: CanoaAliada = _crear_canoa()
	_crear_submarino(0.5, 10.0)

	# Act
	_avanzar(canoa, 10)

	# Assert
	assert_false(canoa.esta_separando_submarino(), "Otro cauce no debe separarse")
	assert_almost_eq(canoa.amplitud_balanceo, AMPLITUD_BALANCEO_BASE, MARGEN_FLOAT, "Sin tamboleo")


func test_submarino_sumergido_no_reacciona() -> void:
	# Arrange
	var canoa: CanoaAliada = _crear_canoa()
	var sub := DummySubmarinoSumergido.new()
	sub.add_to_group("submarino")
	add_child_autofree(sub)
	sub.global_position = Vector3(0.5, 0.0, 0.0)

	# Act
	_avanzar(canoa, 10)

	# Assert
	assert_false(canoa.esta_separando_submarino(), "Sumergido no debe separarse")
	assert_almost_eq(canoa.amplitud_balanceo, AMPLITUD_BALANCEO_BASE, MARGEN_FLOAT, "Sin tamboleo")


func test_separacion_desactivada_no_reacciona() -> void:
	# Arrange
	var canoa: CanoaAliada = _crear_canoa()
	canoa.separacion_submarinos_activa = false
	_crear_submarino(0.5)

	# Act
	_avanzar(canoa, 10)

	# Assert
	assert_false(canoa.esta_separando_submarino(), "Desactivado no debe separar")
	assert_almost_eq(canoa.amplitud_balanceo, AMPLITUD_BALANCEO_BASE, MARGEN_FLOAT, "Sin tamboleo")


func test_sin_submarinos_navega_libre() -> void:
	# Arrange
	var canoa: CanoaAliada = _crear_canoa()

	# Act
	_avanzar(canoa, 10)

	# Assert
	assert_false(canoa.esta_separando_submarino(), "Sin submarinos no debe separar")
	assert_almost_eq(canoa.amplitud_balanceo, AMPLITUD_BALANCEO_BASE, MARGEN_FLOAT, "Sin tamboleo")
