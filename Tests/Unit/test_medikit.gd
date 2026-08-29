extends "res://addons/gut/test.gd"

var MedikitScript = load("res://Entities/Item_Medikit/Medikit.gd")
var PlayerScript = load("res://Entities/Jugador_Arquera/Player.gd")
var AllyArcherScript = load("res://Entities/Aliada_Arquera/AllyArcher.gd")
var AllyBallesteraScript = load("res://Entities/Aliada_Ballestera/AllyBallestera.gd")

var _medikit: Medikit = null
var _player: Player = null

func before_each():
	_medikit = MedikitScript.new()
	add_child_autofree(_medikit)

	_player = PlayerScript.new()
	add_child_autofree(_player)
	_player.vida_maxima = 4
	_player.health = 4
	_player.add_to_group("player")

func _agregar_animacion_minima(ally: Node) -> void:
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	var lib = AnimationLibrary.new()
	lib.add_animation("IDLE", Animation.new())
	lib.add_animation("SHOOT", Animation.new())
	lib.add_animation("DISPARO", Animation.new())
	lib.add_animation("MUERTE_01", Animation.new())
	lib.add_animation("Armature|DIE_01", Animation.new())
	lib.add_animation("Armature|GETTING_UP_01", Animation.new())
	anim_player.add_animation_library("", lib)
	ally.add_child(anim_player)

func test_medikit_no_se_consume_con_vida_maxima():
	# Arrange: Jugador con vida completa
	_player.health = 4
	_player.vida_maxima = 4

	# Act: Jugador entra en contacto con el medikit
	_medikit._manejar_contacto(_player)

	# Assert: Medikit NO se consume y recuerda que el jugador está en contacto
	assert_eq(_medikit.current_state, MedikitScript.State.IDLE, "Medikit no debe consumirse si el jugador tiene vida completa y no hay aliadas dañadas")
	assert_eq(_medikit._player_en_contacto, _player, "Medikit debe registrar al jugador en contacto")
	assert_eq(_player.health, 4, "La vida del jugador debe permanecer en 4")

func test_medikit_se_consume_al_tener_dano():
	# Arrange: Jugador con 2 corazones de 4
	_player.health = 2
	_player.vida_maxima = 4

	# Act: Jugador entra en contacto
	_medikit._manejar_contacto(_player)

	# Assert: Medikit se consume y cura 1 corazón
	assert_eq(_medikit.current_state, MedikitScript.State.DISSOLVING, "Medikit debe entrar en estado de disolución al consumirse")
	assert_eq(_player.health, 3, "El jugador debe haber recuperado 1 corazón (2 -> 3)")

func test_medikit_cura_no_supera_vida_maxima():
	# Arrange: Jugador con 3 corazones de 4
	_player.health = 3
	_player.vida_maxima = 4

	# Act: Jugador consume medikit
	_medikit._intentar_consumir(_player)

	# Assert: La vida no supera vida_maxima
	assert_eq(_player.health, 4, "La vida debe llegar a 4 (máxima)")

func test_medikit_se_consume_cuando_jugador_recibe_dano_estando_en_contacto():
	# Arrange: Jugador entra con vida completa
	_player.health = 4
	_player.vida_maxima = 4
	_medikit._manejar_contacto(_player)
	assert_eq(_medikit.current_state, MedikitScript.State.IDLE)

	# Act: Jugador recibe daño mientras sigue en contacto con el medikit
	_player.health = 3
	_medikit._process(0.016)

	# Assert: Medikit detecta el daño en el _process y se consume inmediatamente
	assert_eq(_medikit.current_state, MedikitScript.State.DISSOLVING, "Medikit debe consumirse cuando el jugador en contacto recibe daño")
	assert_eq(_player.health, 4, "El jugador debe ser curado automáticamente a 4")

func test_medikit_cura_defensoras_aliadas_vivas_sin_superar_maximo():
	# Arrange: Crear defensora arquera y defensora ballestera dañadas
	var archer: AllyArcher = AllyArcherScript.new()
	_agregar_animacion_minima(archer)
	add_child_autofree(archer)
	archer.vida_maxima = 2
	archer.health = 1
	archer.add_to_group("allies")

	var ballestera: AllyBallestera = AllyBallesteraScript.new()
	_agregar_animacion_minima(ballestera)
	add_child_autofree(ballestera)
	ballestera.vida_maxima = 4
	ballestera.health = 2
	ballestera.add_to_group("allies")

	_player.health = 2
	_player.vida_maxima = 4

	# Act: Consumir medikit
	_medikit._intentar_consumir(_player)

	# Assert: Jugador y ambas defensoras reciben +1 de salud
	assert_eq(_player.health, 3, "Jugador debe curarse 1 punto (2 -> 3)")
	assert_eq(archer.health, 2, "Arquera defensora debe curarse 1 punto (1 -> 2 máxima)")
	assert_eq(ballestera.health, 3, "Ballestera defensora debe curarse 1 punto (2 -> 3)")

func test_medikit_revive_defensoras_fijas_caidas():
	# Arrange: Defensora arquera fija y defensora ballestera fija caídas (muertas)
	var archer: AllyArcher = AllyArcherScript.new()
	_agregar_animacion_minima(archer)
	add_child_autofree(archer)
	archer.vida_maxima = 2
	archer.health = 0
	archer.current_state = AllyArcherScript.State.DEAD
	archer.add_to_group("allies")

	var ballestera: AllyBallestera = AllyBallesteraScript.new()
	_agregar_animacion_minima(ballestera)
	add_child_autofree(ballestera)
	ballestera.es_movil = false
	ballestera.vida_maxima = 4
	ballestera.health = 0
	ballestera.current_state = AllyBallesteraScript.State.DEAD
	ballestera.add_to_group("allies")

	_player.health = 4
	_player.vida_maxima = 4

	# Act: Jugador camina sobre el medikit (estando a full pero con aliadas caídas)
	_medikit._manejar_contacto(_player)

	# Assert: Medikit se consume para revivir a las defensoras caídas
	assert_eq(_medikit.current_state, MedikitScript.State.DISSOLVING, "Medikit debe consumirse si hay aliadas defensoras caídas")
	assert_true(archer.health > 0, "La arquera defensora caída debe ser revivida")
	assert_true(ballestera.health > 0, "La ballestera defensora caída debe ser revivida")

func test_medikit_se_desvanece_al_terminar_oleada():
	# Arrange: Medikit intacto
	assert_eq(_medikit.current_state, MedikitScript.State.IDLE)

	# Act: Finaliza la oleada
	_medikit._on_oleada_completada(1)

	# Assert: Medikit inicia desintegración para salir de escena
	assert_eq(_medikit.current_state, MedikitScript.State.DISSOLVING, "Medikit debe desvanecerse si la oleada concluye sin ser usado")
