extends "res://addons/gut/test.gd"

var SceneManagerScript = load("res://System/Core/SceneManager.gd")
var LoadingScreenScript = load("res://UI/LoadingScreen.gd")
var LoadingScreenScene = load("res://UI/LoadingScreen.tscn")

var _scene_mgr: Node = null


func before_each():
	_scene_mgr = SceneManagerScript.new()
	add_child_autofree(_scene_mgr)


func test_scene_manager_initialization():
	# Assert
	assert_not_null(_scene_mgr, "SceneManager debe instanciarse correctamente")
	assert_not_null(_scene_mgr.loading_screen_scene, "Debe tener asignada la escena de pantalla de carga")


func test_loading_screen_instantiation_and_progress():
	# Arrange
	var loading_screen = LoadingScreenScene.instantiate()
	if not loading_screen.get_script():
		loading_screen.set_script(LoadingScreenScript)
	add_child_autofree(loading_screen)

	# Assert inicial
	assert_not_null(loading_screen, "LoadingScreen debe instanciarse")
	assert_eq(loading_screen.layer, 250, "El layer debe ser 250 (prioridad alta)")

	# Act: Set progress
	loading_screen.set_progress(0.5)
	loading_screen._process(0.5)

	# Assert
	assert_gt(loading_screen.progress_bar.value, 0.0, "La barra de progreso debe avanzar")
	assert_not_null(loading_screen.tip_label.text, "Debe mostrar un consejo o texto de estado")


func test_loading_screen_fade_out_libera_recursos():
	# Arrange
	var loading_screen = LoadingScreenScene.instantiate()
	if not loading_screen.get_script():
		loading_screen.set_script(LoadingScreenScript)
	add_child_autofree(loading_screen)

	# Act: Ejecutar fade out
	loading_screen.fade_out(0.05)
	await get_tree().create_timer(0.15, false, false, true).timeout

	# Assert: Debe haberse liberado tras el fade out
	assert_false(is_instance_valid(loading_screen), "LoadingScreen debe liberarse tras completar el fade out")