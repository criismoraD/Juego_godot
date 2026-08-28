extends "res://addons/gut/test.gd"

var AllyArcherScript = load("res://Entities/Aliada_Arquera/AllyArcher.gd")
var AllyBallesteraScript = load("res://Entities/Aliada_Ballestera/AllyBallestera.gd")
var PlayerScript = load("res://Entities/Jugador_Arquera/Player.gd")
var LonkoScript = load("res://Entities/Enemigo_Lonko/Lonko.gd")
var PilarBodyScript = load("res://Entities/Enemigo_Lonko/PilarLonkoBody.gd")
var FlechaElectricaScript = load("res://Entities/Enemigo_Lonko/Flecha_Electrica_Ataque.gd")

class MockAudioManager extends Node:
	func play_sfx(_name, _boost = 0.0): pass
	func stop_bow_tension(): pass
	func reset_bow_hold(): pass
	func play_bow_tension(): pass
	func play_shield_hit(): pass

var _mock_audio_created: bool = false
var _ally: AllyArcher = null
var _lonko: Lonko = null
var _pilar: PilarLonkoBody = null

func before_each():
	if not get_tree().root.has_node("AudioManager"):
		var mock_audio = MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)
		_mock_audio_created = true

	_ally = AllyArcherScript.new()
	_agregar_animaciones_ally(_ally)
	get_tree().root.add_child(_ally)
	_ally.global_position = Vector3(0, 0, 0)

func after_each():
	if is_instance_valid(_ally):
		if _ally.get_parent():
			_ally.get_parent().remove_child(_ally)
		_ally.free()
		_ally = null

	if is_instance_valid(_lonko):
		if _lonko.get_parent():
			_lonko.get_parent().remove_child(_lonko)
		_lonko.free()
		_lonko = null

	if is_instance_valid(_pilar):
		if _pilar.get_parent():
			_pilar.get_parent().remove_child(_pilar)
		_pilar.free()
		_pilar = null

	if _mock_audio_created and get_tree().root.has_node("AudioManager"):
		var mock_audio = get_tree().root.get_node("AudioManager")
		get_tree().root.remove_child(mock_audio)
		mock_audio.free()
		_mock_audio_created = false

func _agregar_animaciones_ally(ally: AllyArcher) -> void:
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	var lib = AnimationLibrary.new()
	lib.add_animation("IDLE", Animation.new())
	lib.add_animation("TOMAR_FLECHA", Animation.new())
	lib.add_animation("APUNTAR_IDLE", Animation.new())
	lib.add_animation("DISPARO", Animation.new())
	lib.add_animation("MUERTE_01", Animation.new())
	lib.add_animation("MUERTE_02", Animation.new())
	lib.add_animation("LEVANTARSE", Animation.new())
	anim_player.add_animation_library("", lib)
	ally.add_child(anim_player)
	ally.anim_player = anim_player

func _agregar_animaciones_player(player: Player) -> void:
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	player.add_child(anim_player)
	var anim_tree := AnimationTree.new()
	anim_tree.name = "AnimationTree"
	anim_tree.anim_player = NodePath("../AnimationPlayer")
	player.add_child(anim_tree)

# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DE TARGETING: LONKO VS PILAR
# ═══════════════════════════════════════════════════════════════════════════════

func test_no_reconocer_lonko_mientras_emerge_o_camina():
	# Arrange: Lonko caminando o en plena animación de emergencia (no lista aún)
	_lonko = LonkoScript.new()
	_lonko.name = "LonkoEnemy"
	get_tree().root.add_child(_lonko)
	_lonko.global_position = Vector3(8.0, 0.0, 0.0)
	_lonko.current_state = EnemyBase.State.WALKING
	_lonko.health = 6
	_lonko._pilar_desplegado = false
	_lonko._is_invulnerable = true
	_lonko._girando_hacia_fondo = true

	_ally.flechas_multiples = 0

	# Act & Assert 1: Durante emergencia / antes de estar en el pilar desplegado, NO la reconoce
	var objetivo = _ally._obtener_objetivo_actual()
	assert_null(objetivo, "No debe reconocer a Lonko mientras emerge o no esté el pilar completo")
	assert_eq(_ally._contar_enemigos_vivos(), 0, "No debe contar a Lonko como enemigo vivo atacable antes de emerger")


func test_reconocer_lonko_solo_con_pilar_emergido_completo():
	# Arrange: Lonko completó su animación de emergencia en la cima del pilar
	_lonko = LonkoScript.new()
	_lonko.name = "LonkoEnemy"
	get_tree().root.add_child(_lonko)
	_lonko.global_position = Vector3(8.0, 3.2, 0.0)
	_lonko.current_state = EnemyBase.State.SHOOTING
	_lonko.health = 6
	_lonko._pilar_desplegado = true
	_lonko._is_invulnerable = false
	_lonko._girando_hacia_fondo = false

	_ally.flechas_multiples = 0

	# Act: Buscar objetivo actual
	var objetivo = _ally._obtener_objetivo_actual()

	# Assert: Debe reconocer a Lonko como objetivo directo
	assert_not_null(objetivo, "Debería encontrar a Lonko como objetivo válido")
	assert_eq(objetivo, _lonko, "La arquera defensora debe reconocer a Lonko con su pilar ya emergido")
	assert_eq(_ally._contar_enemigos_vivos(), 1, "Debe contar a Lonko como enemiga viva")


func test_reconocer_solo_pilar_con_disparo_multiple():
	# Arrange: Lonko y su pilar presentes
	_lonko = LonkoScript.new()
	_lonko.name = "LonkoEnemy"
	get_tree().root.add_child(_lonko)
	_lonko.global_position = Vector3(8.0, 3.2, 0.0)
	_lonko.current_state = EnemyBase.State.SHOOTING
	_lonko.health = 6
	_lonko._pilar_desplegado = true
	_lonko._is_invulnerable = false
	_lonko._girando_hacia_fondo = false

	_pilar = PilarLonkoBody.new()
	_pilar.name = "PilarBody"
	_pilar.es_pilar_enemigo = true
	_pilar.vida_pilar = 15.0
	get_tree().root.add_child(_pilar)
	_pilar.global_position = Vector3(8.0, 0.0, 0.0)

	# Activar power up de disparo múltiple
	_ally.flechas_multiples = 3

	# Act: Buscar objetivo actual
	var objetivo = _ally._obtener_objetivo_actual()

	# Assert: Con disparo múltiple, solo debe reconocer el pilar
	assert_not_null(objetivo, "Debería encontrar un objetivo válido")
	assert_eq(objetivo, _pilar, "Con power-up múltiple SOLO debe reconocer el pilar de Lonko")


func test_cambio_de_objetivo_al_agotar_disparo_multiple():
	# Arrange: Lonko y su pilar
	_lonko = LonkoScript.new()
	_lonko.name = "LonkoEnemy"
	get_tree().root.add_child(_lonko)
	_lonko.global_position = Vector3(8.0, 3.2, 0.0)
	_lonko.current_state = EnemyBase.State.SHOOTING
	_lonko.health = 6
	_lonko._pilar_desplegado = true
	_lonko._is_invulnerable = false
	_lonko._girando_hacia_fondo = false

	_pilar = PilarLonkoBody.new()
	_pilar.name = "PilarBody"
	_pilar.es_pilar_enemigo = true
	_pilar.vida_pilar = 15.0
	get_tree().root.add_child(_pilar)
	_pilar.global_position = Vector3(8.0, 0.0, 0.0)

	# Iniciar con 1 flecha múltiple
	_ally.flechas_multiples = 1
	assert_eq(_ally._obtener_objetivo_actual(), _pilar, "Con 1 flecha múltiple apunta al pilar")

	# Consumir el disparo múltiple
	_ally.flechas_multiples = 0
	assert_eq(_ally._obtener_objetivo_actual(), _lonko, "Sin flechas múltiples vuelve a apuntar a Lonko")

# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DE ESTADO PARÁLISIS
# ═══════════════════════════════════════════════════════════════════════════════

func test_paralisis_en_arquera_aliada():
	# Arrange
	_ally._cambiar_estado(_ally.State.AIMING)
	assert_eq(_ally.current_state, _ally.State.AIMING)

	# Act: Aplicar parálisis
	_ally.aplicar_paralisis(4.0)

	# Assert: Se resetea a IDLE y se activa el temporizador
	assert_eq(_ally.paralisis_timer, 4.0, "El temporizador de parálisis debe ser 4 segundos")
	assert_true(_ally.esta_paralizada(), "Debe reportar estar paralizada")
	assert_eq(_ally.current_state, _ally.State.IDLE, "Debe interrumpir apuntado y pasar a IDLE")

	# Simular avance de tiempo (2 segundos)
	_ally._process(2.0)
	assert_almost_eq(_ally.paralisis_timer, 2.0, 0.01, "El temporizador debe decrementar correctamente")
	assert_true(_ally.esta_paralizada(), "Sigue paralizada a los 2 segundos")

	# Simular término de parálisis (2.1 segundos más)
	_ally._process(2.1)
	assert_eq(_ally.paralisis_timer, 0.0, "El temporizador debe llegar a 0")
	assert_false(_ally.esta_paralizada(), "Ya no debe estar paralizada tras 4 segundos")

func test_paralisis_en_ballestera_aliada():
	# Arrange
	var ballestera: AllyBallestera = AllyBallesteraScript.new()
	get_tree().root.add_child(ballestera)
	ballestera.current_state = ballestera.State.AIMING

	# Act
	ballestera.aplicar_paralisis(4.0)

	# Assert
	assert_eq(ballestera.paralisis_timer, 4.0, "Ballestera debe tener 4s de parálisis")
	assert_true(ballestera.esta_paralizada(), "Ballestera debe estar paralizada")
	assert_eq(ballestera.current_state, ballestera.State.IDLE, "Debe pasar a IDLE")

	ballestera._process(4.1)
	assert_false(ballestera.esta_paralizada(), "Debe terminar la parálisis tras 4 segundos")

	ballestera.get_parent().remove_child(ballestera)
	ballestera.free()

func test_paralisis_en_jugador():
	# Arrange
	var player: Player = PlayerScript.new()
	_agregar_animaciones_player(player)
	get_tree().root.add_child(player)
	player.current_aim_state = player.AimState.DRAWING

	# Act: Aplicar parálisis
	player.aplicar_paralisis(4.0)

	# Assert: Cancela el disparo y activa bloqueo
	assert_eq(player.paralisis_timer, 4.0, "El jugador debe tener 4s de parálisis")
	assert_true(player.esta_paralizada, "El flag esta_paralizada debe ser true")
	assert_true(player.is_shot_locked, "El disparo debe estar bloqueado")
	assert_eq(player.current_aim_state, player.AimState.NONE, "El disparo en curso debe cancelarse")

	# Simular 4.1 segundos en gameplay
	player._process_gameplay(4.1)
	assert_false(player.esta_paralizada, "La parálisis debe desactivarse tras 4s")
	assert_false(player.is_shot_locked, "El bloqueo de disparo debe levantarse")

	player.get_parent().remove_child(player)
	player.free()

func test_flecha_electrica_aplica_paralisis_en_impacto():
	# Arrange
	var flecha: FlechaElectricaAtaque = FlechaElectricaScript.new()
	get_tree().root.add_child(flecha)
	flecha.fase = FlechaElectricaAtaque.Fase.CAIDA
	_ally.global_position = Vector3(5.0, 0.0, 0.0)

	# Act: Simular impacto en cuerpo
	flecha._on_body_entered(_ally)

	# Assert
	assert_true(_ally.esta_paralizada(), "Flecha eléctrica debe paralizar a la defensora al impactar")
	assert_eq(_ally.paralisis_timer, 4.0, "La duración de la parálisis debe ser de 4 segundos")

	flecha.get_parent().remove_child(flecha)
	flecha.free()
