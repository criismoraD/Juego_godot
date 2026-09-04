class_name NivelInterior
extends Node3D

@onready var btn_regresar: Button = %BtnRegresar

func _ready() -> void:
	if btn_regresar:
		btn_regresar.pressed.connect(_on_btn_regresar_pressed)
	# Música del interior de la torre (al salir, NIVEL01 restaura la de batalla)
	AudioManager.play_music(6)

func _on_btn_regresar_pressed() -> void:
	if btn_regresar:
		btn_regresar.disabled = true
	_reproducir_sonido_puerta()
	SceneManager.cambiar_escena_cortinilla_circular("res://Levels/NIVEL01/NIVEL01.tscn")


## SFX de puerta al salir de la torre.
func _reproducir_sonido_puerta() -> void:
	var stream: AudioStream = load("res://TEST_/abrir_puerta.wav")
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.add_to_group("pausable_audio")
	player.stream = stream
	player.volume_db = 2.0
	player.bus = "Master"
	var root := get_tree().current_scene
	if root:
		root.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
	else:
		player.queue_free()
