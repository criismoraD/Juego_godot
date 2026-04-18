extends EnemyBase
class_name Canonero

@export_category("Combate - Canonero")
@export var intervalo_disparo: float = 4.0
@export var velocidad_proyectil: float = 10.0

var is_reloading: bool = false
var canon_bola_scene = preload("res://Scenes/Projectiles/GoblinArrow.tscn") # Usando flecha de placeholder por si acaso, aunque deberia ser cañon

func _on_enemy_ready():
	_play_animation("CANON_IDLE")

func _on_state_walking():
	_play_animation("CANON_CAMINAR")

func _on_state_shooting():
	_play_animation("CANON_DISPARO")
	shoot_timer = 0.5

func _on_state_dying():
	super._on_state_dying()
	AudioManager.play_sfx("goblin_death")
	var death_anims = ["CANON_DEAD_01", "CANON_DEAD_02", "CANON_ATERRRIZAJE_MUERTE"]
	var chosen_death = death_anims[randi() % death_anims.size()]
	
	var anim_length = 1.0
	if has_method("_get_animation_duration"):
		anim_length = _get_animation_duration(chosen_death)
		
	_play_animation(chosen_death)
	get_tree().create_timer(anim_length + 0.5).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_die()
	)

func _process_shooting(delta):
	velocity.x = 0
	if rastrear_jugador:
		_track_player()
	if is_reloading:
		return

	shoot_timer -= delta
	if shoot_timer <= 0:
		_shoot_cannon()
		_start_reload()

func _shoot_cannon():
	if not canon_bola_scene or not player_ref or player_ref.get("is_dead"):
		return

	var proyectil = canon_bola_scene.instantiate()
	AudioManager.play_sfx("goblin_shoot")

	var spawn_pos = global_position + Vector3(-0.5, altura_spawn_flecha, 0)
	var target_pos = player_ref.global_position + Vector3(0, 0.5, 0)
	var direction = (target_pos - spawn_pos).normalized()

	if proyectil.has_method("initialize"):
		proyectil.velocidad = velocidad_proyectil
		proyectil.initialize(direction)

	get_tree().root.add_child(proyectil)
	proyectil.global_position = spawn_pos

func _start_reload():
	is_reloading = true
	_play_animation("CANON_IDLE") # Usamos idle como recarga temporal ya que no hay CANON_RELOAD en el modelo
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree() and current_state == State.SHOOTING:
			is_reloading = false
			shoot_timer = intervalo_disparo
	)
