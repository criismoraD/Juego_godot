extends EnemyBase
class_name GoblinGirl

## Goblin Girl: Camina, se detiene y dispara flechas parabólicas con arco.
## Se diferencia del Goblin en: proyectil parabólico, timing de disparo
## sincronizado con animación, y potencia variable.

# === CONFIGURACIÓN ESPECÍFICA DE GOBLIN GIRL ===
@export_category("Combate - GoblinGirl")
@export var tiempo_disparo_en_animacion: float = 4.0
@export var pausa_entre_disparos: float = 0.1
@export var potencia_disparo_min: float = 1.0
@export var potencia_disparo_max: float = 2.0

# === ESTADO ESPECÍFICO ===
var anim_timer: float = 0.0
var has_fired_this_cycle: bool = false

# === REFERENCIAS ESPECÍFICAS ===
var goblin_girl_arrow_scene = preload("res://Scenes/Projectiles/GoblinGirlArrow.tscn")

# ═══════════════════════════════════════════════════════════════════════════════
# HOOKS DE ENEMYBASE
# ═══════════════════════════════════════════════════════════════════════════════

func _on_enemy_ready():
	# Valores por defecto distintos al Goblin base
	color_borde_disolucion = Color(0.8, 0.2, 0.8) # Púrpura
	_play_animation("GIRL_GOB_CAMINA")

func _on_state_walking():
	_play_animation("GIRL_GOB_CAMINA")

func _on_state_shooting():
	_play_animation("GIRL_GOB_DISPARO")
	anim_timer = 0.0
	has_fired_this_cycle = false
	shoot_timer = pausa_entre_disparos

func _on_state_dying():
	super._on_state_dying()
	if anim_player:
		anim_player.pause()
	AudioManager.play_sfx("goblin_girl_death")

	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_die()
	)

# ═══════════════════════════════════════════════════════════════════════════════
# TRACKING (en _process para no ser sobrescrito por animación)
# ═══════════════════════════════════════════════════════════════════════════════

func _process(_delta):
	if current_state == State.SHOOTING and rastrear_jugador:
		_track_player()

# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO
# ═══════════════════════════════════════════════════════════════════════════════

func _process_shooting(delta):
	velocity.x = 0

	# Incrementar timer de animación
	anim_timer += delta

	# Disparar en el momento exacto de la animación
	if not has_fired_this_cycle and anim_timer >= tiempo_disparo_en_animacion:
		_shoot_arrow()
		has_fired_this_cycle = true

	# Ver si la animación terminó
	var anim_duration = _get_animation_duration("GIRL_GOB_DISPARO")
	if anim_timer >= anim_duration:
		shoot_timer -= delta
		if shoot_timer <= 0:
			anim_timer = 0.0
			has_fired_this_cycle = false
			shoot_timer = pausa_entre_disparos
			_play_animation("GIRL_GOB_DISPARO")

func _shoot_arrow():
	if not goblin_girl_arrow_scene:
		push_error("[GoblinGirl] No arrow scene!")
		return

	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return

	if player_ref.get("is_dead"):
		return

	var arrow = goblin_girl_arrow_scene.instantiate()

	var spawn_pos = global_position + Vector3(-0.3, altura_spawn_flecha, 0)
	var target_pos = player_ref.global_position + Vector3(0, 0.5, 0)
	var diff = target_pos - spawn_pos
	var base_direction = diff.normalized()

	# Añadir arco parabólico según distancia
	var horizontal_dist = abs(diff.x)
	var arc_compensation = clamp(horizontal_dist * 0.15, 0.1, 0.5)
	var direction = Vector3(base_direction.x, base_direction.y + arc_compensation, 0).normalized()

	var potencia = randf_range(potencia_disparo_min, potencia_disparo_max)
	arrow.initialize(direction, potencia)
	arrow.set_meta("shooter", self)

	get_tree().root.add_child(arrow)
	arrow.global_position = spawn_pos

	AudioManager.play_sfx("goblin_girl_shoot")
