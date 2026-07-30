extends "res://addons/gut/test.gd"

var splash_scene_path: String = "res://UI/SplashScreen.tscn"


func test_inicializacion_splash() -> void:
	# Arrange
	var splash = load(splash_scene_path).instantiate()
	add_child_autofree(splash)

	# Esperar _ready
	await wait_seconds(0.1)

	# Assert
	assert_not_null(splash.splash_image, "SplashImage debe estar inicializado")
	assert_not_null(splash.fade_overlay, "FadeOverlay debe estar inicializado")
	assert_eq(splash.next_scene_path, "res://UI/LanguageSelector.tscn", "La ruta al selector de idioma debe estar configurada")


func test_skip_splash_inicia_transicion() -> void:
	# Arrange
	var splash = load(splash_scene_path).instantiate()
	add_child_autofree(splash)

	await wait_seconds(0.2)

	# Act
	splash._skip_splash()

	# Assert
	assert_true(splash.transitioning, "Debe marcar transitioning como verdadero al saltar el splash")
