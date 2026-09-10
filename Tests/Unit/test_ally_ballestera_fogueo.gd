extends "res://addons/gut/test.gd"

## Tiro de fogueo tras el despliegue (refuerzo oleada 5): el primer disparo
## no marca enemigos y cae al terreno por delante con depresión leve, sin
## consumir ciclo. Sigue la estructura AAA.

var AllyBallesteraScript = load("res://Entities/Aliada_Ballestera/AllyBallestera.gd")
var _ballestera: AllyBallestera = null


class MockAudioManager extends Node:
	func play_sfx(_name, _boost = 0.0):
		pass
	func stop_bow_tension():
		pass
	func reset_bow_hold():
		pass


func before_each():
	_ballestera = AllyBallesteraScript.new()
	if not get_tree().root.has_node("AudioManager"):
		var mock_audio = MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)
	get_tree().root.add_child(_ballestera)


func after_each():
	if is_instance_valid(_ballestera):
		if _ballestera.get_parent():
			_ballestera.get_parent().remove_child(_ballestera)
		_ballestera.free()
	if get_tree().root.has_node("AudioManager"):
		var mock_audio = get_tree().root.get_node("AudioManager")
		if mock_audio is MockAudioManager:
			get_tree().root.remove_child(mock_audio)
			mock_audio.free()


func test_programar_tiro_fogueo_arma_un_fogueo():
	# Arrange
	assert_eq(_ballestera.tiros_fogueo_pendientes, 0, "Sin fogueo al instanciar")

	# Act
	_ballestera.programar_tiro_fogueo()

	# Assert
	assert_eq(_ballestera.tiros_fogueo_pendientes, _ballestera.TIROS_FOGUEO_DESPLIEGUE, "Arma el fogueo del despliegue")


func test_direccion_fogueo_terreno_delante_nunca_a_los_pies():
	# Arrange & Act: muestrear la dirección (no necesita escena ni enemigos).
	for i in range(20):
		var dir: Vector3 = _ballestera._direccion_fogueo()

		# Assert: al frente (+X), depresión leve y normalizada.
		assert_almost_eq(dir.length(), 1.0, 0.001, "Dirección normalizada")
		assert_gt(dir.x, 0.9, "Siempre hacia el frente")
		assert_lt(dir.y, sin(deg_to_rad(-3.0)), "Siempre pica terreno")
		assert_gt(dir.y, sin(deg_to_rad(-13.0)), "Nunca picado a los pies")


func test_fogueo_no_consume_ciclo_ni_marca():
	# Arrange
	_ballestera.fase_agachada = false
	_ballestera.disparos_en_fase = 2
	_ballestera.programar_tiro_fogueo()

	# Act: disparar con fogueo armado (aunque hubiera enemigo a los pies,
	# el fogueo no lo marca: no necesita objetivo válido).
	_ballestera._disparar()

	# Assert: se consumió el fogueo sin tocar el ciclo de 5.
	assert_eq(_ballestera.tiros_fogueo_pendientes, 0, "El fogueo se consume de un tiro")
	assert_eq(_ballestera.disparos_en_fase, 2, "El fogueo no avanza el ciclo")


func test_fogueo_agachada_tampoco_aplica_refuerzo():
	# Arrange: valores que en un tiro normal aplicarían refuerzo de escudo.
	_ballestera.fase_agachada = true
	_ballestera.disparos_en_fase = 0
	_ballestera.programar_tiro_fogueo()

	# Act
	_ballestera._disparar()

	# Assert: el fogueo sale antes del ciclo (sin contar ni reforzar).
	assert_eq(_ballestera.tiros_fogueo_pendientes, 0, "El fogueo se consume")
	assert_eq(_ballestera.disparos_en_fase, 0, "El fogueo no cuenta como tiro de fase")
