extends "res://addons/gut/test.gd"

## Tests unitarios para el efecto Smear y Gelatina (estilo años 30 / rubber hose)
## en el frenado de Perrena y las transiciones suaves entre correr, frenar y caminar
## en la cinemática de la oleada 5 (CinematicaOleada5.gd).

const CINE: GDScript = preload("res://Levels/NIVEL01/CinematicaOleada5.gd")
const PERRENA_SCENE: PackedScene = preload("res://Entities/Jugador_Perrena/Perrena.tscn")
const PLAYER_SCENE: PackedScene = preload("res://Entities/Jugador_Arquera/Player.tscn")

var _root_test: Node3D = null
var _cine: CinematicaOleada5 = null
var _perrena: Perrena = null
var _eryn: Player = null


class NivelTest extends Node:
	var _aliadas_activas := true
	func _set_movimiento_jugador_bloqueado(_b: bool) -> void:
		pass
	func _set_aliadas_modo_pacifico() -> void:
		pass
	func _set_aliadas_activas(_a: bool) -> void:
		pass
	func _mostrar_dialogo_escena(_a, _b, _c, _d, _e, _f, _g) -> void:
		pass


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestCinePerrena"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test

	_eryn = PLAYER_SCENE.instantiate() as Player
	_root_test.add_child(_eryn)

	_perrena = PERRENA_SCENE.instantiate() as Perrena
	_root_test.add_child(_perrena)

	var nivel := NivelTest.new()
	_root_test.add_child(nivel)

	_cine = CINE.new()
	_cine.entrada_torre_habilitada = false
	nivel.add_child(_cine)
	_cine.iniciar(nivel, func(): pass)
	await get_tree().process_frame


func after_each() -> void:
	if is_instance_valid(_cine) and not _cine.is_queued_for_deletion():
		_cine._reset_smear()
		_cine.free()
	if is_instance_valid(_root_test):
		_root_test.free()
	_cine = null
	_perrena = null
	_eryn = null
	_root_test = null


func test_smear_suave_correr_se_activa_con_velocidad() -> void:
	# Arrange
	assert_not_null(_cine._perrena_model, "Debe detectar el modelo de Perrena")
	var scale_base: Vector3 = _cine._perrena_model_scale_base
	_cine._fase = CINE.Fase.CORRER
	_cine._v_actual = CINE.V_CORRER

	# Act: Varios frames de corrida a toda velocidad
	for i in range(12):
		_cine._actualizar_smear_correr(0.016)

	# Assert: Deformación suave de smear estira en X y comprime sutilmente en Y para exagerar velocidad
	assert_gt(_cine._perrena_model.scale.x, scale_base.x, "El modelo debe estirarse suavemente en X mientras corre")
	assert_lt(_cine._perrena_model.scale.y, scale_base.y, "El modelo debe comprimirse sutilmente en Y para conservar volumen")
	# Assert: Nunca altera la posición ni rotación (cero teletransporte)
	assert_almost_eq(_cine._perrena_model.position.x, _cine._perrena_model_pos_base.x, 0.001, "La posición del modelo no debe alterarse")
	assert_almost_eq(_cine._perrena_model.rotation.z, _cine._perrena_model_rot_base.z, 0.001, "La rotación del modelo no debe alterarse")


func test_smear_suave_retorna_al_detenerse() -> void:
	# Arrange: Modelo en smear de carrera
	var scale_base: Vector3 = _cine._perrena_model_scale_base
	_cine._fase = CINE.Fase.CORRER
	_cine._v_actual = CINE.V_CORRER
	for i in range(12):
		_cine._actualizar_smear_correr(0.016)
	assert_gt(_cine._perrena_model.scale.x, scale_base.x)

	# Act: Detener la velocidad y entrar en fase PAUSA
	_cine._v_actual = 0.0
	_cine._fase = CINE.Fase.PAUSA
	for i in range(35):
		_cine._actualizar_smear_correr(0.016)

	# Assert: Retorna suavemente a la escala original sin rebotes de gelatina ni oscilaciones
	assert_almost_eq(_cine._perrena_model.scale.x, scale_base.x, 0.05, "La escala X debe retornar a la base")
	assert_almost_eq(_cine._perrena_model.scale.y, scale_base.y, 0.05, "La escala Y debe retornar a la base")


func test_transicion_deceleracion_suave_frenado_sin_teletransporte() -> void:
	# Arrange: Colocar a Perrena justo al iniciar el frenado suave
	_cine._perrena.global_position.x = CINE.PAUSA_X + CINE.DISTANCIA_FRENADO_SUAVE - 0.02
	_cine._v_actual = CINE.V_CORRER
	_cine._frenando = false
	var pos_x_prev: float = _cine._perrena.global_position.x

	# Act: Ejecutar un paso de proceso
	_cine._process(0.016)

	# Assert: Inició el frenado suave, desaceleró progresivamente y solicitó idle en Locomotion
	assert_true(_cine._frenando, "Debe iniciar el frenado suave")
	assert_lt(_cine._v_actual, CINE.V_CORRER, "La velocidad debe desacelerar progresivamente")
	assert_gt(_cine._v_actual, 0.0, "No debe pararse de golpe")
	# Movimiento continuo sin saltos hacia adelante (teletransporte)
	var delta_movido: float = pos_x_prev - _cine._perrena.global_position.x
	assert_gt(delta_movido, 0.0, "Debe continuar avanzando hacia la izquierda")
	assert_lt(delta_movido, 0.05, "El movimiento por frame debe ser suave y continuo, sin teletransporte")
	if _cine._perrena.anim_tree:
		assert_eq(_cine._perrena.anim_tree.get("parameters/Locomotion/transition_request"), "idle", "Debe solicitar idle con crossfade en Locomotion")


func test_transicion_aceleracion_suave_caminar() -> void:
	# Arrange: Situar cinemática en fase CAMINAR arrancando desde 0
	_cine._fase = CINE.Fase.CAMINAR
	_cine._v_caminar_actual = 0.0
	_cine._perrena.global_position.x = CINE.PAUSA_X

	# Act: Avanzar un frame corto
	_cine._process(0.016)

	# Assert: Velocidad se incrementa progresivamente (no salta bruscamente a V_CAMINAR)
	assert_gt(_cine._v_caminar_actual, 0.0, "La velocidad de caminata debe comenzar a acelerar")
	assert_lt(_cine._v_caminar_actual, CINE.V_CAMINAR, "La aceleración debe ser suave (no salto instantáneo)")


func test_reset_smear_restaura_escala_base() -> void:
	# Arrange
	var scale_base: Vector3 = _cine._perrena_model_scale_base
	_cine._fase = CINE.Fase.CORRER
	_cine._v_actual = CINE.V_CORRER
	for i in range(10):
		_cine._actualizar_smear_correr(0.016)
	assert_gt(_cine._perrena_model.scale.x, scale_base.x)

	# Act: Reset inmediato
	_cine._reset_smear()

	# Assert
	assert_almost_eq(_cine._perrena_model.scale.x, scale_base.x, 0.001, "Escala X restaurada")
	assert_almost_eq(_cine._perrena_model.scale.y, scale_base.y, 0.001, "Escala Y restaurada")
