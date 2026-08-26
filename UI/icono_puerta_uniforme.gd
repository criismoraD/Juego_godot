@tool
extends TextureRect

## Fuerza escalado uniforme en editor.
## Evita deformaciones tipo (1.0, -0.36) al arrastrar handles.
## En runtime no hace nada (el tween de GameUI.gd ya es uniforme).

@export var escala_uniforme_activa: bool = true

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if not escala_uniforme_activa:
		return
	if not is_equal_approx(scale.x, scale.y):
		scale.y = scale.x
