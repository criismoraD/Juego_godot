extends "res://addons/gut/test.gd"

## Tests unitarios para el Menú de Defensoras y la Mesa de Configuración.
## Sigue la estructura AAA (Arrange, Act, Assert).

var MenuDefensorasScene = preload("res://UI/MenuDefensoras/MenuDefensoras.tscn")
var MesaConfiguracionScene = preload("res://Levels/Nivel_Interior/MesaConfiguracion.tscn")

var _menu: MenuDefensoras = null
var _mesa: MesaConfiguracion = null


func before_each():
	GameUI.defensoras_config = {
		1: "arquera",
		2: "arquera"
	}
	_menu = MenuDefensorasScene.instantiate() as MenuDefensoras
	add_child_autofree(_menu)


func test_menu_defensoras_carga_configuracion_inicial():
	# Arrange
	GameUI.defensoras_config = { 1: "arquera", 2: "ballestera" }

	# Act
	_menu.abrir()

	# Assert
	assert_eq(_menu.config_local.get(1), "arquera", "Piso 1 debe cargar arquera")
	assert_eq(_menu.config_local.get(2), "ballestera", "Piso 2 debe cargar ballestera")
	assert_true(_menu.visible, "El menú debe ser visible al abrirse")


func test_menu_defensoras_alternar_clase():
	# Arrange
	_menu.abrir()
	assert_eq(_menu.config_local.get(1), "arquera", "Inicialmente debe ser arquera")

	# Act: Alternar en piso 1
	_menu._alternar_defensora(1)

	# Assert
	assert_eq(_menu.config_local.get(1), "ballestera", "Tras alternar debe ser ballestera")

	# Act: Alternar nuevamente
	_menu._alternar_defensora(1)

	# Assert
	assert_eq(_menu.config_local.get(1), "arquera", "Tras alternar de nuevo debe volver a arquera")


func test_menu_defensoras_cambio_de_piso_y_descripcion():
	# Arrange
	_menu.abrir()
	_menu.config_local[1] = "arquera"
	_menu.config_local[2] = "ballestera"

	# Act: Seleccionar Piso 2 (Ballestera)
	_menu._cambiar_piso(2)

	# Assert
	assert_eq(_menu.piso_seleccionado, 2, "El piso seleccionado debe ser 2")
	assert_string_contains(_menu.lbl_descripcion_defensora.text, "Vida 4", "La descripción de la ballestera debe indicar Vida 4")
	assert_string_contains(_menu.lbl_descripcion_defensora.text, "refuerzo de escudo", "La descripción debe mencionar refuerzo de escudo")

	# Act: Seleccionar Piso 1 (Arquera)
	_menu._cambiar_piso(1)

	# Assert
	assert_eq(_menu.piso_seleccionado, 1, "El piso seleccionado debe ser 1")
	assert_string_contains(_menu.lbl_descripcion_defensora.text, "Vida 2", "La descripción de la arquera debe indicar Vida 2")
	assert_string_contains(_menu.lbl_descripcion_defensora.text, "objetivos aéreos", "La descripción debe mencionar objetivos aéreos")


func test_menu_defensoras_guarda_en_game_ui_al_cerrar():
	# Arrange
	_menu.abrir()
	_menu._alternar_defensora(1)  # cambia a ballestera

	# Act
	_menu.cerrar()

	# Assert
	assert_eq(GameUI.defensoras_config.get(1), "ballestera", "GameUI.defensoras_config debe actualizarse con ballestera")
	assert_eq(GameUI.defensoras_config.get(2), "arquera", "GameUI.defensoras_config debe mantenerse con arquera")


func test_mesa_no_abre_menu_directamente_al_acercarse():
	# Arrange
	_mesa = MesaConfiguracionScene.instantiate() as MesaConfiguracion
	add_child_autofree(_mesa)
	var dummy_body = CharacterBody3D.new()
	dummy_body.add_to_group("player_interior")
	add_child_autofree(dummy_body)

	# Act: Jugador entra al área
	_mesa._on_body_entered(dummy_body)

	# Assert
	assert_true(_mesa._jugador_cerca, "El jugador debe ser detectado cerca")
	assert_false(_mesa.menu_canvas.visible, "El menú NO debe abrirse directamente al aproximarse")
	assert_true(_mesa.prompt_e.visible, "El prompt [E] debe hacerse visible")


func test_mesa_abre_menu_con_input_e():
	# Arrange
	_mesa = MesaConfiguracionScene.instantiate() as MesaConfiguracion
	add_child_autofree(_mesa)
	var dummy_body = CharacterBody3D.new()
	dummy_body.add_to_group("player_interior")
	add_child_autofree(dummy_body)
	_mesa._on_body_entered(dummy_body)

	# Act: Simular presionar E
	var key_event = InputEventKey.new()
	key_event.keycode = KEY_E
	key_event.pressed = true
	_mesa._unhandled_input(key_event)

	# Assert
	assert_true(_mesa.menu_canvas.visible, "El menú de la mesa debe abrirse tras presionar E")


func test_menu_bloquea_movimiento_jugador():
	# Arrange
	var dummy_player = CharacterBody3D.new()
	dummy_player.set_script(load("res://Entities/Jugador_Arquera/Player_Interior.gd"))
	dummy_player.add_to_group("player_interior")
	add_child_autofree(dummy_player)
	assert_true(dummy_player.puede_moverse, "Inicialmente el jugador puede moverse")

	# Act: Abrir menú
	_menu.abrir()

	# Assert: Movimiento congelado
	assert_false(dummy_player.puede_moverse, "Al abrir el menú, el jugador NO debe poder moverse")

	# Act: Cerrar menú
	_menu.cerrar()

	# Assert: Movimiento restaurado
	assert_true(dummy_player.puede_moverse, "Al salir del menú, el jugador debe poder moverse nuevamente")


func test_textos_sujetos_a_traduccion():
	assert_eq(tr("MENU_DEFENSORAS"), "DEFENSORAS", "MENU_DEFENSORAS debe existir en el sistema de traducciones")
	assert_eq(tr("PROMPT_INTERACTUAR"), "Interactuar", "PROMPT_INTERACTUAR debe existir en el sistema de traducciones")
	assert_string_contains(tr("DESC_DEFENSORA_ARQUERA"), "Vida 2", "La traducción de arquera debe contener Vida 2")
	assert_string_contains(tr("DESC_DEFENSORA_BALLESTERA"), "Vida 4", "La traducción de ballestera debe contener Vida 4")


