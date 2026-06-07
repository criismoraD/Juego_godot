@tool
extends BarreraEscalera
class_name BarreraEscaleraSuperior

## Barrera SUPERIOR para escaleras
## - Bloquea subir (suelta la escalera) si intentas seguir subiendo
## - Permite bajar sin problemas

func _ready():
	pass
	if solo_jugador:
		collision_layer = 0
		collision_mask = 1

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_buscar_componentes()
	_actualizar_tamano()




func _physics_process(_delta):
	if not player_inside or not is_instance_valid(player_ref):
		return

	# Detectar inputs
	var pressing_up = Input.is_action_pressed("move_forward") or Input.is_action_pressed("ui_up")

	# Si intenta SUBIR ("move_forward") mientras está en la barrera:
	# 1. Aplicamos cooldown SIEMPRE para evitar que la escalera "chupe" al jugador
	# 2. Si ya estaba escalando, lo soltamos
	if pressing_up:
		# Aplicar cooldown preventivo (clave para no quedarse pegado al salir)
		if "ladder_cooldown" in player_ref:
			player_ref.ladder_cooldown = cooldown_escalera

		if _esta_en_escalera(player_ref):
			_soltar_solo_escalera(player_ref)




func _soltar_solo_escalera(player):
	if not _esta_en_escalera(player):
		return

	# Estado AIR
	player.current_move_state = player.MoveState.AIR

	# Reset rotación
	if player.has_method("_reset_armature_rotation"):
		player._reset_armature_rotation()

	# Pequeño empujón opcional para despegarse
	if "velocity" in player:
		pass  # No empujamos horizontalmente necesariamente, solo soltamos


