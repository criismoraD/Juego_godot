extends EnemyBase
class_name Goblin

## Goblin estándar: Camina, se detiene y dispara flechas rectas con ballesta.

# === CONFIGURACIÓN ESPECÍFICA DEL GOBLIN ===
@export_category("Combate - Goblin")
@export var intervalo_disparo: float = 3.5
@export var velocidad_flecha: float = 5.0

# === REFERENCIAS ESPECÍFICAS ===
var goblin_arrow_scene = preload("res://Scenes/Projectiles/GoblinArrow.tscn")

# ═══════════════════════════════════════════════════════════════════════════════
# HOOKS DE ENEMYBASE
# ═══════════════════════════════════════════════════════════════════════════════

func _on_enemy_ready():
	_play_animation("ENEMIGO_GOBLING_CORRER")

func _on_state_walking():
	_play_animation("ENEMIGO_GOBLING_CORRER")

func _on_state_shooting():
	_play_animation("ENEMIGO_GOBLING_DISPARO")
	shoot_timer = 0.5 # Pequeño delay antes del primer disparo

func _on_state_dying():
	super._on_state_dying()
	AudioManager.play_sfx("goblin_death")

	var anim_length = 1.5
	if anim_player and anim_player.has_animation("Armature|ENEMIGO_GOBLING_MUERTE"):
		anim_length = anim_player.get_animation("Armature|ENEMIGO_GOBLING_MUERTE").length

	_play_animation("ENEMIGO_GOBLING_MUERTE")

	get_tree().create_timer(anim_length + 0.5).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_die()
	)

# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO
# ═══════════════════════════════════════════════════════════════════════════════

func _process_shooting(delta):
	velocity.x = 0

	if rastrear_jugador:
		_track_player()

	shoot_timer -= delta
	if shoot_timer <= 0:
		_shoot_arrow()
		shoot_timer = intervalo_disparo

func _shoot_arrow():
	if not goblin_arrow_scene:
		return

	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return

	# No disparar si el jugador está muerto
	if player_ref.get("is_dead"):
		return

	var arrow = goblin_arrow_scene.instantiate()
	AudioManager.play_sfx("goblin_shoot")

	var spawn_pos = global_position + Vector3(-0.3, altura_spawn_flecha, 0)
	var target_pos = player_ref.global_position + Vector3(0, 0.5, 0)
	var direction = (target_pos - spawn_pos).normalized()

	arrow.velocidad = velocidad_flecha
	arrow.initialize(direction)

	get_tree().root.add_child(arrow)
	arrow.global_position = spawn_pos
