extends Node3D

@onready var texture_rect = $SubViewport/TextureRect

func _ready():
	# Asegurarse de que el TextureRect esté oculto al inicio
	if texture_rect:
		texture_rect.visible = false
