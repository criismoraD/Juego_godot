extends Control

@onready var play_button = $MenuContainer/ButtonsContainer/PlayButton
@onready var load_button = $MenuContainer/ButtonsContainer/LoadButton
@onready var config_button = $MenuContainer/ButtonsContainer/ConfigButton
@onready var exit_button = $MenuContainer/ButtonsContainer/ExitButton
@onready var fade_overlay = $FadeOverlay
@onready var menu_container = $MenuContainer

# Precarga de escena
var nivel01_scene = preload("res://Scenes/Levels/NIVEL01.tscn")

func _ready():
	# Conectar señales
	play_button.pressed.connect(_on_play_pressed)
	load_button.pressed.connect(_on_load_pressed)
	config_button.pressed.connect(_on_config_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	# Animación de entrada
	_animate_menu_entry()

func _animate_menu_entry():
	menu_container.modulate.a = 0
	menu_container.position.x = -100
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(menu_container, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_container, "position:x", 0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_play_pressed():
	_disable_buttons()
	_fade_out_and_change_scene()

func _on_load_pressed():
	print("Cargar partida - Próximamente")

func _on_config_pressed():
	print("Opciones - Próximamente")

func _on_exit_pressed():
	_disable_buttons()
	_fade_out_and_quit()

func _disable_buttons():
	play_button.disabled = true
	load_button.disabled = true
	config_button.disabled = true
	exit_button.disabled = true

func _fade_out_and_change_scene():
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.5).set_ease(Tween.EASE_IN)
	tween.finished.connect(_change_to_game)

func _change_to_game():
	get_tree().change_scene_to_packed(nivel01_scene)

func _fade_out_and_quit():
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.5).set_ease(Tween.EASE_IN)
	tween.finished.connect(func(): get_tree().quit())
