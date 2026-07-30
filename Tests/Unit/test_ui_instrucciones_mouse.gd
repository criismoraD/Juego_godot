extends "res://addons/gut/test.gd"

var instrucciones_scene_path: String = "res://UI_INSTRUCCIONES/UI_INSTRUCCIONES_Mouse.tscn"


func test_inicializacion_instrucciones_mouse() -> void:
	# Arrange
	var ui = load(instrucciones_scene_path).instantiate() as UIInstruccionesMouse
	add_child_autofree(ui)

	await wait_seconds(0.1)

	# Assert
	assert_not_null(ui.contenedor, "El contenedor principal debe estar inicializado")
	assert_not_null(ui.imagen_instrucciones, "La imagen de instrucciones debe estar inicializada")
	assert_not_null(ui.texto_moverse, "El texto de moverse debe estar inicializado")
	assert_not_null(ui.texto_raton, "El texto de ratón debe estar inicializado")
	assert_true(ui.is_in_group("ui_instrucciones"), "Debe pertenecer al grupo ui_instrucciones")


func test_ocultar_inmediato_al_golpear_enemigo() -> void:
	# Arrange
	var ui = load(instrucciones_scene_path).instantiate() as UIInstruccionesMouse
	add_child_autofree(ui)
	await wait_seconds(0.1)

	# Act
	ui.ocultar()

	# Assert
	assert_true(ui.ocultando, "Debe marcar ocultando como verdadero al invocar ocultar()")
