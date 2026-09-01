extends "res://addons/gut/test.gd"

var AllyArcherScript = load("res://Entities/Aliada_Arquera/AllyArcher.gd")
var AllyBallesteraScript = load("res://Entities/Aliada_Ballestera/AllyBallestera.gd")
var PlayerScript = load("res://Entities/Jugador_Arquera/Player.gd")
var LonkoScript = load("res://Entities/Enemigo_Lonko/Lonko.gd")
var PilarBodyScript = load("res://Entities/Enemigo_Lonko/PilarLonkoBody.gd")
var FlechaElectricaScript = load("res://Entities/Enemigo_Lonko/Flecha_Electrica_Ataque.gd")
var GargolaScript = load("res://Entities/Enemigo_Gargola/Gargola.gd")

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
var _gargola: Node3D = null

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

	if is_instance_valid(_gargola):
		if _gargola.get_parent():
			_gargola.get_parent().remove_child(_gargola)
		_gargola.free()
		_gargola = null

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

func _agregar_animaciones_lonko(lonko: Lonko) -> void:
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	var lib = AnimationLibrary.new()
	lib.add_animation("IDLE", Animation.new())
	lib.add_animation("IMPACTO_01", Animation.new())
	lib.add_animation("IMPACTO_02", Animation.new())
	lib.add_animation("MUERTE_01", Animation.new())
	lib.add_animation("MUERTE_02", Animation.new())
	anim_player.add_animation_library("", lib)
	lonko.add_child(anim_player)
	lonko.anim_player = anim_player

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


func test_priorizar_disparo_explosivo_contra_lonko():
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

	# Aliada tiene flechas explosivas y múltiples
	_ally.flechas_explosivas = 5
	_ally.flechas_multiples = 3

	# Act: Decidir disparo
	var decision = _ally._decidir_disparo_y_objetivo()

	# Assert: Contra Lonko/Pilar debe priorizar disparo explosivo
	assert_eq(decision.get("type"), AllyArcher.TipoDisparoAliada.EXPLOSIVO, "Debe priorizar disparo explosivo contra Lonko")
	assert_true(decision.get("target") == _lonko or decision.get("target") == _pilar, "El objetivo debe ser Lonko o su pilar")


func test_priorizar_disparo_normal_contra_gargola():
	# Arrange: Gárgola presente en pantalla
	_gargola = GargolaScript.new()
	_gargola.name = "GargolaEnemy"
	get_tree().root.add_child(_gargola)
	_gargola.global_position = Vector3(6.0, 2.5, 0.0)
	_gargola.current_state = EnemyBase.State.WALKING
	_gargola.health = 2

	# Aliada tiene flechas explosivas y múltiples almacenadas
	_ally.flechas_explosivas = 5
	_ally.flechas_multiples = 3

	# Act: Decidir disparo
	var decision = _ally._decidir_disparo_y_objetivo()

	# Assert: Contra Gárgola prioriza disparo normal y no gasta munición especial
	assert_eq(decision.get("type"), AllyArcher.TipoDisparoAliada.NORMAL, "Contra Gárgola debe usar disparo NORMAL")
	assert_eq(decision.get("target"), _gargola, "El objetivo debe ser la Gárgola")

	# Act: Disparar
	_ally._disparar()

	# Assert: La munición especial debe mantenerse intacta en reserva
	assert_eq(_ally.flechas_explosivas, 5, "Las flechas explosivas deben permanecer intactas")
	assert_eq(_ally.flechas_multiples, 3, "Las flechas múltiples deben permanecer intactas")


func test_disparo_explosivo_al_azar_si_no_hay_lonko():
	# Arrange: Enemigo normal presente (sin Lonko)
	_lonko = null
	var enemy = Node3D.new()
	enemy.name = "GoblinEnemy"
	enemy.add_to_group("enemies")
	get_tree().root.add_child(enemy)
	enemy.global_position = Vector3(5.0, 0.0, 0.0)

	_ally.flechas_explosivas = 4
	_ally.flechas_multiples = 0

	# Act: Decidir disparo
	var decision = _ally._decidir_disparo_y_objetivo()

	# Assert: Al no haber Lonko, usa flechas explosivas al azar
	assert_eq(decision.get("type"), AllyArcher.TipoDisparoAliada.EXPLOSIVO, "Sin Lonko, usa flechas explosivas al azar")
	assert_eq(decision.get("target"), enemy, "Debe apuntar al enemigo disponible")

	# Cleanup
	get_tree().root.remove_child(enemy)
	enemy.free()


func test_disparo_multiple_al_azar():
	# Arrange: Enemigo normal presente
	var enemy = Node3D.new()
	enemy.name = "GoblinEnemy2"
	enemy.add_to_group("enemies")
	get_tree().root.add_child(enemy)
	enemy.global_position = Vector3(5.0, 0.0, 0.0)

	_ally.flechas_explosivas = 0
	_ally.flechas_multiples = 3

	# Act: Decidir disparo
	var decision = _ally._decidir_disparo_y_objetivo()

	# Assert: Disparo múltiple se efectúa al azar
	assert_eq(decision.get("type"), AllyArcher.TipoDisparoAliada.MULTIPLE, "Disparo múltiple se efectúa al azar")
	assert_eq(decision.get("target"), enemy, "Debe apuntar al enemigo disponible")

	# Cleanup
	get_tree().root.remove_child(enemy)
	enemy.free()

# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DE ESTADO PARÁLISIS
# ═══════════════════════════════════════════════════════════════════════════════

func test_paralisis_en_arquera_aliada():
	# Arrange
	_ally._cambiar_estado(_ally.State.AIMING)
	assert_eq(_ally.current_state, _ally.State.AIMING)

	# Act: Aplicar parálisis
	_ally.aplicar_paralisis(4.0)

	# Assert: Se resetea a IDLE y se activa el temporizador e icono de aturdimiento
	assert_eq(_ally.paralisis_timer, 4.0, "El temporizador de parálisis debe ser 4 segundos")
	assert_true(_ally.esta_paralizada(), "Debe reportar estar paralizada")
	assert_eq(_ally.current_state, _ally.State.IDLE, "Debe interrumpir apuntado y pasar a IDLE")
	assert_not_null(_ally._icono_aturdimiento, "Debe crearse el icono de aturdimiento")
	assert_true(_ally._icono_aturdimiento.visible, "El icono de aturdimiento debe estar visible")

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
	assert_not_null(ballestera._icono_aturdimiento, "Debe crearse el icono de aturdimiento flotante")
	assert_true(ballestera._icono_aturdimiento.visible, "El icono de aturdimiento debe estar visible")

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

	# Assert: Cancela el disparo y activa bloqueo e icono verde
	assert_eq(player.paralisis_timer, 4.0, "El jugador debe tener 4s de parálisis")
	assert_true(player.esta_paralizada, "El flag esta_paralizada debe ser true")
	assert_true(player.is_shot_locked, "El disparo debe estar bloqueado")
	assert_eq(player.current_aim_state, player.AimState.NONE, "El disparo en curso debe cancelarse")
	assert_not_null(player._icono_aturdimiento, "Debe crearse el icono de aturdimiento en el jugador")
	assert_true(player._icono_aturdimiento.visible, "El icono de aturdimiento debe estar visible")
	assert_gt(player._icono_aturdimiento.modulate.g, player._icono_aturdimiento.modulate.r, "El icono debe ser de color verde")

	# Simular 4.1 segundos en gameplay
	player._process_gameplay(4.1)
	assert_false(player.esta_paralizada, "La parálisis debe desactivarse tras 4s")
	assert_false(player.is_shot_locked, "El bloqueo de disparo debe levantarse")

	player.get_parent().remove_child(player)
	player.free()

func test_flecha_electrica_no_paraliza_a_defensora():
	# Arrange
	var flecha: FlechaElectricaAtaque = FlechaElectricaScript.new()
	get_tree().root.add_child(flecha)
	flecha.fase = FlechaElectricaAtaque.Fase.CAIDA
	_ally.global_position = Vector3(5.0, 0.0, 0.0)

	# Act: Simular impacto en la defensora aliada
	flecha._on_body_entered(_ally)

	# Assert: La defensora recibe daño pero NO queda aturdida (el aturdimiento solo afecta a la protagonista)
	assert_false(_ally.esta_paralizada(), "La flecha eléctrica no debe aturdir a la defensora aliada")
	assert_eq(_ally.paralisis_timer, 0.0, "La defensora no debe tener parálisis")

	flecha.get_parent().remove_child(flecha)
	flecha.free()


func test_paralisis_no_es_acumulable():
	# Arrange
	var player: Player = PlayerScript.new()
	_agregar_animaciones_player(player)
	get_tree().root.add_child(player)

	# Act: Aplicar parálisis inicial
	player.aplicar_paralisis(4.0)
	assert_eq(player.paralisis_timer, 4.0)

	# Avanzar 2 segundos (restan 2s)
	player._process_gameplay(2.0)
	assert_almost_eq(player.paralisis_timer, 2.0, 0.05, "Deben restar ~2s de parálisis")

	# Act: Intentar re-aplicar parálisis mientras el efecto sigue activo
	player.aplicar_paralisis(4.0)

	# Assert: El efecto NO se acumula ni reinicia (debe seguir en los ~2s restantes)
	assert_almost_eq(player.paralisis_timer, 2.0, 0.05, "La parálisis no debe ser acumulable mientras esté activa")

	# Avanzar 2.1s para que expire completamente
	player._process_gameplay(2.1)
	assert_false(player.esta_paralizada, "La parálisis debe expirar")

	# Ahora que expiró, se puede volver a aplicar
	player.aplicar_paralisis(4.0)
	assert_eq(player.paralisis_timer, 4.0, "Una vez expirado el efecto, se puede volver a aplicar")

	player.get_parent().remove_child(player)
	player.free()


func test_lonko_caida_dinamica_al_destruir_pilar():
	# Arrange
	_lonko = LonkoScript.new()
	_agregar_animaciones_lonko(_lonko)
	var modelo := Node3D.new()
	modelo.name = "LONKO"
	_lonko.add_child(modelo)
	_lonko._lonko_modelo = modelo
	get_tree().root.add_child(_lonko)
	_lonko.global_position = Vector3(8.0, 3.2, 0.0)
	_lonko._base_pos_pilar = Vector3(8.0, 0.185, 0.0)
	_lonko._reached_position = true

	# Act: Destruir el pilar
	_lonko._on_pilar_destruido()

	# Assert inicial: Estado DYING, activa física de caída con impulso
	assert_eq(_lonko.current_state, EnemyBase.State.DYING, "Debe pasar a estado DYING")
	assert_true(_lonko._cayendo_por_destruccion_pilar, "Debe activar bandera _cayendo_por_destruccion_pilar")
	assert_gt(_lonko.velocity.y, 0.0, "Debe tener un impulso vertical inicial positivo")
	assert_gt(_lonko.velocity.x, 0.0, "Debe tener un impulso horizontal hacia atrás")

	# Simular caída en el aire (10 frames)
	for i in range(10):
		_lonko._process_dying(0.016)

	assert_lt(_lonko.velocity.y, 2.0, "La gravedad debe reducir la velocidad vertical rápidamente")

	# Simular impacto en el suelo
	_lonko.global_position.y = 0.185
	_lonko._process_dying(0.016)

	assert_true(_lonko._ha_tocado_suelo_muerte, "Debe marcar _ha_tocado_suelo_muerte al alcanzar el piso")
	assert_almost_eq(_lonko.velocity.x, 0.0, 0.01, "La velocidad debe detenerse al tocar el piso")



# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DE PRIORIDAD 0: BALLESTERA DISPARA AL AZAR CONTRA LONKOS
# ═══════════════════════════════════════════════════════════════════════════════

var _ballestera: AllyBallestera = null


func _crear_ballestera() -> AllyBallestera:
	_ballestera = AllyBallesteraScript.new()
	_ballestera.name = "BallesteraTestAzar"
	get_tree().root.add_child(_ballestera)
	_ballestera.global_position = Vector3(0.0, 0.0, 0.0)
	return _ballestera


func _limpiar_ballestera() -> void:
	if is_instance_valid(_ballestera):
		if _ballestera.get_parent():
			_ballestera.get_parent().remove_child(_ballestera)
		_ballestera.free()
		_ballestera = null


func test_ballestera_reconoce_objetivo_azar_cuando_solo_hay_lonko():
	# Arrange: ballestera con una Lonko activa a su derecha y ningún básico apuntable
	_crear_ballestera()
	_lonko = LonkoScript.new()
	_lonko.name = "LonkoEnemy"
	get_tree().root.add_child(_lonko)
	_lonko.global_position = Vector3(8.0, 0.0, 0.0)

	# Act
	var hay_azar: bool = _ballestera._hay_objetivo_azar()
	var objetivo_apuntable: Node3D = _ballestera._obtener_objetivo_prioritario()

	# Assert
	assert_true(hay_azar, "Con solo Lonkos debe existir objetivo de azar (prioridad 0)")
	assert_null(objetivo_apuntable, "La Lonko no debe ser objetivo apuntable de prioridad 2")

	_limpiar_ballestera()


func test_ballestera_sin_objetivo_azar_sin_hostiles():
	# Arrange: ballestera sin ningún enemigo activo
	_crear_ballestera()

	# Act
	var hay_azar: bool = _ballestera._hay_objetivo_azar()

	# Assert
	assert_false(hay_azar, "Sin hostiles no debe haber objetivo de azar (caso borde)")

	_limpiar_ballestera()


func test_ballestera_ignora_lonko_detras_de_ella():
	# Arrange: Lonko a la izquierda (x negativa), fuera del arco frontal de disparo
	_crear_ballestera()
	_lonko = LonkoScript.new()
	_lonko.name = "LonkoEnemy"
	get_tree().root.add_child(_lonko)
	_lonko.global_position = Vector3(-8.0, 0.0, 0.0)

	# Act
	var hay_azar: bool = _ballestera._hay_objetivo_azar()

	# Assert
	assert_false(hay_azar, "Una Lonko detrás de la ballestera no habilita el tiro al azar")

	_limpiar_ballestera()
