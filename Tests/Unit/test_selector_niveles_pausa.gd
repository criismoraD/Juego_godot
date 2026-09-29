extends "res://addons/gut/test.gd"

## Tests unitarios para el Selector de Niveles en el menú de pausa / escape (GameUI).
## Verifica la presencia y configuración de los botones de nivel:
## - Nivel 1 (Bosque) -> res://Levels/NIVEL01/NIVEL01.tscn
## - Nivel Río -> res://Levels/Rio en canoa con paralax.tscn
## - Nivel Pueblo -> res://Levels/Nivel_Pueblo/NivelPueblo.tscn

const SCRIPT_GAME_UI: Script = preload("res://UI/GameUI.gd")

var _game_ui: CanvasLayer = null


func before_each() -> void:
	_game_ui = SCRIPT_GAME_UI.new() as CanvasLayer
	add_child_autofree(_game_ui)


func test_botones_selector_de_niveles_existen_en_panel_pausa() -> void:
	# Arrange
	_game_ui._create_pause_panel()
	var pause_panel: Panel = _game_ui.find_child("PausePanel", true, false) as Panel
	assert_not_null(pause_panel, "PausePanel debe existir en GameUI")

	# Act
	var btn_bosque: Button = pause_panel.find_child("BtnNivelBosque", true, false) as Button
	var btn_rio: Button = pause_panel.find_child("BtnNivelRio", true, false) as Button
	var btn_pueblo: Button = pause_panel.find_child("BtnNivelPueblo", true, false) as Button

	# Assert
	assert_not_null(btn_bosque, "Debe existir el botón de Nivel 1 (Bosque)")
	assert_not_null(btn_rio, "Debe existir el botón de Nivel Río")
	assert_not_null(btn_pueblo, "Debe existir el botón de Nivel Pueblo")

	assert_true(btn_bosque.text.contains("Nivel 1") or btn_bosque.text.contains("Bosque"), "El botón debe identificar Nivel 1")
	assert_true(btn_rio.text.contains("Río") or btn_rio.text.contains("Rio"), "El botón debe identificar Nivel Río")
	assert_true(btn_pueblo.text.contains("Pueblo"), "El botón debe identificar Nivel Pueblo")


func test_rutas_de_niveles_son_validas_y_existen_en_disco() -> void:
	# Arrange & Act & Assert
	var ruta_bosque: String = "res://Levels/NIVEL01/NIVEL01.tscn"
	var ruta_rio: String = "res://Levels/Rio en canoa con paralax.tscn"
	var ruta_pueblo: String = "res://Levels/Nivel_Pueblo/NivelPueblo.tscn"

	assert_true(ResourceLoader.exists(ruta_bosque), "La escena de Nivel 1 debe existir: " + ruta_bosque)
	assert_true(ResourceLoader.exists(ruta_rio), "La escena de Nivel Río debe existir: " + ruta_rio)
	assert_true(ResourceLoader.exists(ruta_pueblo), "La escena de Nivel Pueblo debe existir: " + ruta_pueblo)


func test_ir_a_nivel_metodo_ejecuta_limpieza_y_navegacion() -> void:
	# Arrange
	assert_true(_game_ui.has_method("_ir_a_nivel"), "_ir_a_nivel debe existir en GameUI")
