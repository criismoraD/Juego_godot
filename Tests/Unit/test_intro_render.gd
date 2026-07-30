extends "res://addons/gut/test.gd"

var intro_scene_path = "res://UI/IntroScene.tscn"


func test_inicializacion_intro() -> void:
	# Arrange
	var intro = load(intro_scene_path).instantiate()
	add_child_autofree(intro)

	# Esperar a que se procese _ready y sus process_frames
	await wait_seconds(0.1)

	# Assert
	assert_not_null(intro.title_label, "TitleLabel debe estar inicializado")
	assert_not_null(intro.story_label, "StoryLabel debe estar inicializado")
	assert_eq(intro.story_label.position.y, 0.0, "La posicion Y inicial del texto de la historia debe ser 0.0")
	assert_true(intro.fade_overlay.visible, "El fade overlay debe estar visible")


func test_skip_intro_transiciona() -> void:
	# Arrange
	var intro = load(intro_scene_path).instantiate()
	add_child_autofree(intro)

	# Esperar _ready
	await wait_seconds(0.1)

	# Act
	intro._on_skip_pressed()

	# Assert
	assert_true(intro.transitioning, "Debe iniciar la transicion al saltar la intro")

