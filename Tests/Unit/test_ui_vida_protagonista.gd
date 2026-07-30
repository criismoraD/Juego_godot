extends "res://addons/gut/test.gd"

var ui_vida_scene_path: String = "res://UI/UI_Vida_Protagonista.tscn"


func test_inicializacion_ui_vida_protagonista() -> void:
	# Arrange
	var ui_vida = load(ui_vida_scene_path).instantiate() as UIVidaProtagonista
	add_child_autofree(ui_vida)

	# Wait _ready
	await wait_seconds(0.1)

	# Assert
	assert_not_null(ui_vida.barra_vida, "BarraVida debe estar inicializado")
	assert_not_null(ui_vida.corazon_01, "Corazon01 debe estar inicializado")
	assert_not_null(ui_vida.corazon_02, "Corazon02 debe estar inicializado")
	assert_not_null(ui_vida.corazon_03, "Corazon03 debe estar inicializado")
	assert_not_null(ui_vida.corazon_04, "Corazon04 debe estar inicializado")
	assert_false(ui_vida.visible, "Debe iniciar oculta hasta ser llamada por mostrar()")


func test_mostrar_hace_visible_ui_vida() -> void:
	# Arrange
	var ui_vida = load(ui_vida_scene_path).instantiate() as UIVidaProtagonista
	add_child_autofree(ui_vida)
	await wait_seconds(0.1)

	# Act
	ui_vida.mostrar()

	# Assert
	assert_true(ui_vida.visible, "Debe ser visible tras llamar a mostrar()")


func test_actualizar_vida_oculta_corazones_segun_dano() -> void:
	# Arrange
	var ui_vida = load(ui_vida_scene_path).instantiate() as UIVidaProtagonista
	add_child_autofree(ui_vida)
	await wait_seconds(0.1)

	# Vida = 4: Todos visibles
	ui_vida.actualizar_vida(4)
	assert_true(ui_vida.corazon_01.visible, "Corazon01 visible a 4 HP")
	assert_true(ui_vida.corazon_02.visible, "Corazon02 visible a 4 HP")
	assert_true(ui_vida.corazon_03.visible, "Corazon03 visible a 4 HP")
	assert_true(ui_vida.corazon_04.visible, "Corazon04 visible a 4 HP")

	# Vida = 3: Se oculta 1 corazón (Corazon04)
	ui_vida.actualizar_vida(3)
	assert_true(ui_vida.corazon_01.visible)
	assert_true(ui_vida.corazon_02.visible)
	assert_true(ui_vida.corazon_03.visible)
	assert_false(ui_vida.corazon_04.visible, "Corazon04 debe ocultarse al bajar a 3 HP")

	# Vida = 2: Se ocultan 2 corazones
	ui_vida.actualizar_vida(2)
	assert_true(ui_vida.corazon_01.visible)
	assert_true(ui_vida.corazon_02.visible)
	assert_false(ui_vida.corazon_03.visible, "Corazon03 debe ocultarse al bajar a 2 HP")
	assert_false(ui_vida.corazon_04.visible)

	# Vida = 0: Todos ocultos
	ui_vida.actualizar_vida(0)
	assert_false(ui_vida.corazon_01.visible)
	assert_false(ui_vida.corazon_02.visible)
	assert_false(ui_vida.corazon_03.visible)
	assert_false(ui_vida.corazon_04.visible)
