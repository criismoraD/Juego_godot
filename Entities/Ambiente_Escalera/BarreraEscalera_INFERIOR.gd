@tool
class_name BarreraEscalera
extends "res://Entities/Ambiente_Escalera/BarreraEscaleraBase.gd"

## Barrera inferior para escaleras.
## Bloquea bajar por la escalera cuando el jugador ya está escalando.

const IMPULSO_SALIDA_ESCALERA: float = 0.5
const VELOCIDAD_CAIDA_MINIMA: float = -0.5


func _physics_process(_delta: float) -> void:
	if not player_inside or not is_instance_valid(player_ref):
		return

	var pressing_down := Input.is_action_pressed("move_back") or Input.is_action_pressed("ui_down")
	var pressing_up := Input.is_action_pressed("move_forward") or Input.is_action_pressed("ui_up")
	if not pressing_down:
		return

	if not pressing_up and _esta_en_escalera(player_ref):
		_soltar_solo_escalera(player_ref, IMPULSO_SALIDA_ESCALERA)


func _on_player_entered(player: Node3D) -> void:
	if not _esta_en_escalera(player):
		return

	var barrier_top: float = global_position.y + (tamano.y / 2.0)
	var player_velocity_y: float = player.velocity.y if "velocity" in player else 0.0
	if player.global_position.y > barrier_top and player_velocity_y < VELOCIDAD_CAIDA_MINIMA:
		_soltar_solo_escalera(player, IMPULSO_SALIDA_ESCALERA)
