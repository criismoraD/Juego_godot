@tool
extends TextureRect

const SOLO_EDITOR := true

func _ready() -> void:
	if SOLO_EDITOR:
		visible = Engine.is_editor_hint()
