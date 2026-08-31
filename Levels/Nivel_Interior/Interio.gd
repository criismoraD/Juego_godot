class_name NivelInterior
extends Node3D

@onready var btn_regresar: Button = %BtnRegresar

func _ready() -> void:
	if btn_regresar:
		btn_regresar.pressed.connect(_on_btn_regresar_pressed)

func _on_btn_regresar_pressed() -> void:
	if btn_regresar:
		btn_regresar.disabled = true
	SceneManager.cambiar_escena_cortinilla_circular("res://Levels/NIVEL01/NIVEL01.tscn")
