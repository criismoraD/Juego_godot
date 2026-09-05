@tool
class_name BarreraEscaleraSuperior
extends "res://Entities/Ambiente_Escalera/BarreraEscaleraBase.gd"

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

	if not _esta_en_escalera(player_ref):
		return

	# Solo desmontar si los PIES del jugador han alcanzado la altura de la barrera.
	# player_ref.global_position.y representa la posición de los pies.
	var col_shape: CollisionShape3D = collision_shape if collision_shape else get_node_or_null("CollisionShape3D")
	var barrier_y: float = col_shape.global_position.y if col_shape else global_position.y
	var player_feet_y: float = player_ref.global_position.y

	# Si los pies aún no han subido hasta el nivel de la barrera, continuar escalando
	if player_feet_y < barrier_y - 0.35:
		return

	var impulso_x: float = 0.0
	var input_h: float = Input.get_axis("move_left", "move_right")
	if not is_zero_approx(input_h):
		var walk_speed: float = player_ref.get("velocidad_caminar") if "velocidad_caminar" in player_ref else 3.0
		impulso_x = signf(input_h) * walk_speed * 0.5

	if player_ref.has_method("dismount_ladder_top"):
		player_ref.dismount_ladder_top(impulso_x)
	else:
		_soltar_solo_escalera(player_ref, impulso_x)

