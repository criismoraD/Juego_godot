class_name Canonero
extends EnemyBase

const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")
const PROJECTILE_SCALE: Vector3 = Vector3.ONE

const SANGRE_CANONERO_TEX: Texture2D = preload("res://Entities/Enemigo_Canonero/Canonero_Muerte_Explosiva.png")
const SANGRE_CANONERO_FRAMES: int = 12
const SANGRE_CANONERO_SEGUNDOS_POR_FRAME: float = 0.055
const SANGRE_CANONERO_PIXEL_SIZE: float = 0.016

@export_category("Combate - Canonero")
@export var intervalo_disparo: float = 4.0
@export var velocidad_proyectil: float = 10.0
var is_reloading: bool = false
var murio_por_explosion: bool = false
var canon_bola_scene = preload("res://Entities/Proyectil_Flecha_Goblin/GoblinArrow.tscn")  # Usando flecha de placeholder por si acaso, aunque deberia ser cañon


func _on_enemy_ready():
	_play_animation("CANON_IDLE")


func _on_state_walking():
	_play_animation("CANON_CAMINAR")


func _on_state_shooting():
	_play_animation("CANON_DISPARO")
	shoot_timer = 0.5


func _on_state_dying():
	if murio_por_explosion:
		_ejecutar_explosion_desmembramiento()
		return

	super._on_state_dying()
	AudioManager.play_sfx("goblin_death")
	var death_anims = ["CANON_DEAD_01", "CANON_DEAD_02", "CANON_ATERRRIZAJE_MUERTE"]
	var chosen_death = death_anims[randi() % death_anims.size()]

	var anim_length = 1.0
	if has_method("_get_animation_duration"):
		anim_length = _get_animation_duration(chosen_death)

	_play_animation(chosen_death)
	get_tree().create_timer(anim_length + 0.5).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_die()
	)


func _ejecutar_explosion_desmembramiento() -> void:
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

	# 1. Ocultar modelo intacto del cañonero
	var model := get_node_or_null("Model") as Node3D
	if model:
		model.visible = false

	# 2. Audio de impacto, explosión y carne
	AudioManager.play_sfx("explosion_muerte")
	AudioManager.play_sfx("sangre_splash")

	# 3. Mancha de sangre en el suelo (fade en 3.5s + 2.5s)
	VFXFactory.spawn_ground_blood_splatter(self, global_position)

	# 4. Secuencia animada de explosión cárnica (12 frames)
	_spawn_secuencia_explosion_animada(global_position)

	# 5. Liberación tras concluir la animación
	var duracion_total: float = SANGRE_CANONERO_FRAMES * SANGRE_CANONERO_SEGUNDOS_POR_FRAME + 0.1
	get_tree().create_timer(duracion_total).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_die()
	)


func _spawn_secuencia_explosion_animada(pos: Vector3) -> void:
	if not SANGRE_CANONERO_TEX:
		return

	var sprite := Sprite3D.new()
	sprite.texture = SANGRE_CANONERO_TEX
	sprite.vframes = SANGRE_CANONERO_FRAMES
	sprite.hframes = 1
	sprite.frame = 0
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.render_priority = 3
	sprite.no_depth_test = false
	sprite.pixel_size = SANGRE_CANONERO_PIXEL_SIZE

	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	root.add_child(sprite)
	sprite.global_position = pos + Vector3(0.0, 0.45, 0.0)

	var anim_task := func():
		for f in range(SANGRE_CANONERO_FRAMES):
			if not is_instance_valid(sprite) or not sprite.is_inside_tree():
				return
			sprite.frame = f
			await sprite.get_tree().create_timer(SANGRE_CANONERO_SEGUNDOS_POR_FRAME, false).timeout
		if is_instance_valid(sprite):
			sprite.queue_free()

	anim_task.call()


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

	var proyectil := PROJECTILE_POOL_REF.acquire(canon_bola_scene) as GoblinArrowProjectile
	if not proyectil:
		return

	proyectil.scale = PROJECTILE_SCALE
	AudioManager.play_sfx("goblin_shoot")

	var spawn_pos = global_position + Vector3(-0.5, altura_spawn_flecha, 0)
	var target_pos = player_ref.global_position + Vector3(0, 0.5, 0)
	var direction = (target_pos - spawn_pos).normalized()

	var power: float = (velocidad_proyectil - 10.0) / 20.0
	proyectil.initialize(direction, power)
	proyectil.speed = velocidad_proyectil

	PROJECTILE_POOL_REF.activate(proyectil, get_tree().root, spawn_pos)


func _start_reload():
	is_reloading = true
	_play_animation("CANON_IDLE")  # Usamos idle como recarga temporal ya que no hay CANON_RELOAD en el modelo
	get_tree().create_timer(1.5).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree() and current_state == State.SHOOTING:
				is_reloading = false
				shoot_timer = intervalo_disparo
	)
