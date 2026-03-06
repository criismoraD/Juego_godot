extends EnemyBase
class_name Goblin

## Goblin estándar: Camina, se detiene y dispara flechas rectas con ballesta.

# === CONFIGURACIÓN ESPECÍFICA DEL GOBLIN ===
@export_category("Combate - Goblin")
@export var intervalo_disparo: float = 3.5
@export var velocidad_flecha: float = 8.0
@export var velocidad_recarga: float = 2.0 ## Multiplicador de velocidad de la animación de recarga (2.0 = doble de rápido)

# === REFERENCIAS ESPECÍFICAS ===
var goblin_arrow_scene = preload("res://Scenes/Projectiles/GoblinArrow.tscn")
var is_reloading: bool = false

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

	# Elegir aleatoriamente entre las 3 animaciones de muerte
	var death_anims = ["ENEMIGO_GOBLING_MUERTE_1", "ENEMIGO_GOBLING_MUERTE_2", "ENEMIGO_GOBLING_MUERTE_3"]
	var chosen_death = death_anims[randi() % death_anims.size()]

	var anim_length = _get_animation_duration(chosen_death)
	_play_animation(chosen_death)

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

	# No contar timer mientras recarga
	if is_reloading:
		return

	shoot_timer -= delta
	if shoot_timer <= 0:
		_shoot_arrow()
		_start_reload()

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

# ═══════════════════════════════════════════════════════════════════════════════
# RECARGA
# ═══════════════════════════════════════════════════════════════════════════════

func _start_reload():
	is_reloading = true
	# Reproducir recarga con blend suave desde disparo
	_play_animation("ENEMIGO_GOBLING_RECARGA", 0.2, velocidad_recarga)

	var reload_duration = _get_animation_duration("ENEMIGO_GOBLING_RECARGA") / velocidad_recarga
	get_tree().create_timer(reload_duration - 0.2).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree() and current_state == State.SHOOTING:
			# Volver a disparo con blend largo para suavizar la transición
			_play_animation("ENEMIGO_GOBLING_DISPARO", 0.3)
			is_reloading = false
			shoot_timer = intervalo_disparo
	)
