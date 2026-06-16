@tool
class_name BarreraEscaleraSuperior
extends "res://Entities/Environment/ESCALERA/BarreraEscaleraBase.gd"

## Barrera superior para escaleras.
## Bloquea seguir subiendo y permite bajar sin restricción.


func _init() -> void:
	cooldown_escalera = 0.5


func _physics_process(_delta: float) -> void:
	if not player_inside or not is_instance_valid(player_ref):
		return

	var pressing_up := Input.is_action_pressed("move_forward") or Input.is_action_pressed("ui_up")
	if not pressing_up:
		return

	_aplicar_cooldown(player_ref)
	if _esta_en_escalera(player_ref):
		_soltar_solo_escalera(player_ref)
