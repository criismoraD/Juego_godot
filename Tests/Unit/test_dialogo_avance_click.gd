extends "res://addons/gut/test.gd"

## Tests unitarios del avance rápido con click en diálogos (DialogoComic).
## Validan que click/toque fuera de botones completa el texto en revelado,
## y que no altera nada cuando el texto ya terminó o el flag está apagado.

const ESCENA_DIALOGO_PROTA: String = "res://UI/Dialogo_Protagonista.tscn"


func _crear_dialogo() -> DialogoComic:
	var packed := load(ESCENA_DIALOGO_PROTA) as PackedScene
	assert_not_null(packed, "La escena de diálogo debe cargar correctamente")
	var dialogo := packed.instantiate() as DialogoComic
	assert_not_null(dialogo, "La escena debe instanciar un DialogoComic")
	add_child_autofree(dialogo)
	await get_tree().process_frame
	await get_tree().process_frame
	return dialogo


func _poner_en_revelado(dialogo: DialogoComic) -> int:
	dialogo._timer_revelado.stop()
	dialogo.dialogo_label.text = "Texto de prueba para avance rapido"
	var total: int = dialogo.dialogo_label.get_total_character_count()
	assert_gt(total, 0, "El label debe tener caracteres")
	dialogo._total_chars_pagina = total
	dialogo.dialogo_label.visible_characters = 0
	dialogo._revelando = true
	return total


func _crear_click_izquierdo() -> InputEventMouseButton:
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = true
	return evento


# === HAPPY PATH ===
func test_click_izquierdo_completa_texto_en_revelado() -> void:
	# Arrange
	var dialogo := await _crear_dialogo()
	assert_not_null(dialogo.dialogo_label, "Debe existir el label de diálogo")
	var total: int = _poner_en_revelado(dialogo)

	# Act
	dialogo._completar_con_click(_crear_click_izquierdo())

	# Assert
	assert_false(dialogo._revelando, "El revelado debe terminar")
	assert_eq(dialogo.dialogo_label.visible_characters, total, "El texto debe completarse")


func test_toque_pantalla_completa_texto_en_revelado() -> void:
	# Arrange
	var dialogo := await _crear_dialogo()
	var total: int = _poner_en_revelado(dialogo)
	var evento := InputEventScreenTouch.new()
	evento.pressed = true

	# Act
	dialogo._completar_con_click(evento)

	# Assert
	assert_false(dialogo._revelando, "El revelado debe terminar con toque")
	assert_eq(dialogo.dialogo_label.visible_characters, total, "El texto debe completarse con toque")


# === CASOS BORDE ===
func test_click_sin_revelado_no_altera_texto() -> void:
	# Arrange
	var dialogo := await _crear_dialogo()
	dialogo._timer_revelado.stop()
	dialogo.dialogo_label.text = "Texto ya completo"
	var total: int = dialogo.dialogo_label.get_total_character_count()
	dialogo._total_chars_pagina = total
	dialogo.dialogo_label.visible_characters = total
	dialogo._revelando = false

	# Act
	dialogo._completar_con_click(_crear_click_izquierdo())

	# Assert
	assert_eq(dialogo.dialogo_label.visible_characters, total, "Sin revelado el texto no cambia")
	assert_false(dialogo._revelando, "Sin revelado sigue sin revelar")


func test_click_derecho_no_completa_texto() -> void:
	# Arrange
	var dialogo := await _crear_dialogo()
	var total: int = _poner_en_revelado(dialogo)
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_RIGHT
	evento.pressed = true

	# Act
	dialogo._completar_con_click(evento)

	# Assert
	assert_true(dialogo._revelando, "El revelado debe continuar con click derecho")
	assert_eq(dialogo.dialogo_label.visible_characters, 0, "El texto no debe avanzar con click derecho")


func test_click_soltado_no_completa_texto() -> void:
	# Arrange
	var dialogo := await _crear_dialogo()
	var total: int = _poner_en_revelado(dialogo)
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = false

	# Act
	dialogo._completar_con_click(evento)

	# Assert
	assert_true(dialogo._revelando, "Soltar el botón no debe completar")
	assert_eq(dialogo.dialogo_label.visible_characters, 0, "El texto no debe avanzar al soltar")


func test_flag_apagado_ignora_click() -> void:
	# Arrange
	var dialogo := await _crear_dialogo()
	assert_true(dialogo.avance_rapido_con_click, "El avance rápido viene activado por defecto")
	var total: int = _poner_en_revelado(dialogo)
	dialogo.avance_rapido_con_click = false

	# Act
	dialogo._completar_con_click(_crear_click_izquierdo())

	# Assert
	assert_true(dialogo._revelando, "Con el flag apagado el revelado continúa")
	assert_eq(dialogo.dialogo_label.visible_characters, 0, "Con el flag apagado el texto no se completa")


# === MARCO OSCURO ===
func test_marco_conectado_al_gui_input() -> void:
	# Arrange & Act
	var dialogo := await _crear_dialogo()

	# Assert: el Panel consume clicks y los deriva al avance rápido
	var marco := dialogo.find_child("Panel", true, false) as Control
	assert_not_null(marco, "Debe existir el marco Panel")
	assert_true(marco.gui_input.is_connected(Callable(dialogo, "_on_marco_gui_input")), "El marco debe derivar clicks")


func test_click_en_marco_completa_texto() -> void:
	# Arrange
	var dialogo := await _crear_dialogo()
	var total: int = _poner_en_revelado(dialogo)

	# Act: click que llega vía gui_input del marco (el Panel lo consume antes)
	dialogo._on_marco_gui_input(_crear_click_izquierdo())

	# Assert
	assert_false(dialogo._revelando, "El revelado debe terminar")
	assert_eq(dialogo.dialogo_label.visible_characters, total, "El texto debe completarse")
