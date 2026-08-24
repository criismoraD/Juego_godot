extends GutTest

var game_over_screen: UIGameOver


func before_each() -> void:
	game_over_screen = UIGameOver.new()
	add_child(game_over_screen)
	await get_tree().process_frame


func after_each() -> void:
	if is_instance_valid(game_over_screen):
		game_over_screen.queue_free()
	await get_tree().process_frame


func test_game_over_ui_elements_created() -> void:
	# Assert
	assert_not_null(game_over_screen.background, "Debe tener un fondo negro ColorRect")
	assert_not_null(game_over_screen.title_label, "Debe tener el label de título")
	assert_not_null(game_over_screen.subtitle_label, "Debe tener el label de subtítulo")
	assert_not_null(game_over_screen.btn_continue, "Debe tener el botón de continuar/reiniciar")
	assert_eq(game_over_screen.title_label.text, tr("GAME_OVER_TITLE"), "El título debe estar traducido")


func test_registra_ultima_escena_jugada() -> void:
	# Al mostrarse Game Over debe registrarse la escena actual como último nivel
	# jugado, para que Continuar reinicie ese nivel.
	assert_ne(
		UIGameOver.ultima_escena_jugada, "",
		"Debe registrarse la ruta del último nivel jugado al mostrarse Game Over"
	)
