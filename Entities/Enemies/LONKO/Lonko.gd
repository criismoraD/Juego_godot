class_name Lonko
extends EnemyBase

## Lonko: Enemigo arquero avanzado con 6 puntos de vida.
## Utiliza el arco y la flecha de GoblinGirl (con animación de escala al recargar).
## Animaciones:
## - Caminar/Correr: CORRER_01, CORRE_02 (variantes aleatorias)
## - Daño/Impacto: IMPACTO_01, IMPACTO_02 (variantes aleatorias) + Daño.mp3
## - Muerte normal: MUERTE_01, MUERTE_02 (variantes aleatorias) + Muerte.mp3
## - Disparo: RECARGA (toma la flecha y la escala) -> DISPARO (la suelta y lanza proyectil)

const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")

@export_category("Combate - Lonko")
@export var intervalo_disparo: float = 3.0
@export var tiempo_recarga: float = 1.0        ## Duración de la animación RECARGA (toma la flecha)
@export var tiempo_disparo: float = 0.8        ## Duración de la animación DISPARO
@export var tiempo_lanzar_flecha: float = 0.35  ## Momento justo de la suelta de la flecha en DISPARO
@export var velocidad_proyectil: float = 12.0

# Referencias
var lonko_arrow_scene: PackedScene = preload("res://Entities/Projectiles/GoblinGirlArrow.tscn")
var sfx_dano_stream: AudioStream = preload("res://LONKO/Daño.mp3")
var sfx_muerte_stream: AudioStream = preload("res://LONKO/Muerte.mp3")
var flecha_visual_mano: Node3D = null

# Estado interno
var _is_shooting: bool = false
var _has_released_arrow: bool = false


func _on_enemy_ready() -> void:
	vida_maxima = 6
	health = 6
	color_borde_disolucion = Color(1.0, 0.4, 0.1)  # Naranja fuego
	
	# Orientar el modelo hacia la izquierda (hacia el jugador)
	var lonko_model = get_node_or_null("LONKO") as Node3D
	if lonko_model:
		lonko_model.rotation_degrees.y = -90.0

	_configurar_flecha_mano()
	_play_random_run_animation()


func _configurar_flecha_mano() -> void:
	flecha_visual_mano = find_child("FlechaMano", true, false)
	if flecha_visual_mano:
		flecha_visual_mano.visible = false
		flecha_visual_mano.scale = Vector3(0.01, 0.01, 0.01)


func _on_state_walking() -> void:
	_is_shooting = false
	_ocultar_flecha_mano()
	_play_random_run_animation()


func _on_state_shooting() -> void:
	if _is_shooting:
		return
	_iniciar_secuencia_disparo()


func _play_random_run_animation() -> void:
	var rand_run: String = "CORRER_01" if randf() < 0.5 else "CORRE_02"
	_play_animation(rand_run)


func _iniciar_secuencia_disparo() -> void:
	_is_shooting = true
	_has_released_arrow = false
	velocity = Vector3.ZERO
	
	# 1. Animación RECARGA (toma la flecha)
	_play_animation("RECARGA")
	_mostrar_y_escalar_flecha_mano()
	
	# Esperar a que termine la animación RECARGA
	await get_tree().create_timer(tiempo_recarga).timeout
	if current_state != State.SHOOTING or not is_instance_valid(self):
		return
		
	# 2. Animación DISPARO (suelta la flecha)
	_play_animation("DISPARO")
	
	# Esperar el instante justo de la suelta de flecha
	await get_tree().create_timer(tiempo_lanzar_flecha).timeout
	if current_state != State.SHOOTING or not is_instance_valid(self):
		return
		
	_disparar_proyectil()
	
	# Esperar a que termine la animación de DISPARO completa
	var tiempo_restante: float = max(0.05, tiempo_disparo - tiempo_lanzar_flecha)
	await get_tree().create_timer(tiempo_restante).timeout
	
	_is_shooting = false
	if current_state == State.SHOOTING:
		_change_state(State.WALKING)


func _mostrar_y_escalar_flecha_mano() -> void:
	if not flecha_visual_mano:
		flecha_visual_mano = find_child("FlechaMano", true, false)
	if flecha_visual_mano:
		flecha_visual_mano.visible = true
		flecha_visual_mano.scale = Vector3(0.01, 0.01, 0.01)
		
		var tween := create_tween()
		tween.tween_property(flecha_visual_mano, "scale", Vector3(1.0, 1.0, 1.0), tiempo_recarga * 0.8) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _ocultar_flecha_mano() -> void:
	if not flecha_visual_mano:
		flecha_visual_mano = find_child("FlechaMano", true, false)
	if flecha_visual_mano:
		flecha_visual_mano.visible = false
		flecha_visual_mano.scale = Vector3(0.01, 0.01, 0.01)


func _disparar_proyectil() -> void:
	if _has_released_arrow:
		return
	_has_released_arrow = true
	_ocultar_flecha_mano()
	
	if not lonko_arrow_scene:
		return
		
	var arrow := lonko_arrow_scene.instantiate() as Node3D
	if not arrow:
		return
		
	var spawn_pos: Vector3 = global_position + Vector3(0, 1.2, 0)
	if flecha_visual_mano and is_instance_valid(flecha_visual_mano):
		spawn_pos = flecha_visual_mano.global_position
		
	var target_pos: Vector3 = global_position + transform.basis.z * 5.0
	if player_ref and is_instance_valid(player_ref):
		target_pos = player_ref.global_position + Vector3(0, 1.0, 0)
		
	var root_scene := get_tree().current_scene
	if root_scene:
		root_scene.add_child(arrow)
		arrow.global_position = spawn_pos
		
		var dir := (target_pos - spawn_pos).normalized()
		if not dir.is_zero_approx():
			arrow.look_at(spawn_pos + dir, Vector3.UP)
			
		if arrow.has_method("lanzar"):
			arrow.lanzar(dir * velocidad_proyectil)
		elif "velocity" in arrow:
			arrow.velocity = dir * velocidad_proyectil

	AudioManager.play_sfx("disparo_flecha")


func take_damage(amount: float) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	health -= int(amount)
	_flash_red()

	if health <= 0:
		_change_state(State.DYING)
	else:
		_reproducir_sonido_dano()
		# Variantes de impacto (IMPACTO_01 / IMPACTO_02)
		var rand_impact: String = "IMPACTO_01" if randf() < 0.5 else "IMPACTO_02"
		_play_animation(rand_impact)


func _on_state_dying() -> void:
	_ocultar_flecha_mano()
	_reproducir_sonido_muerte()
	super._on_state_dying()
	
	# Variantes de muerte normal (MUERTE_01 / MUERTE_02)
	var rand_death: String = "MUERTE_01" if randf() < 0.5 else "MUERTE_02"
	_play_animation(rand_death)


func _reproducir_sonido_dano() -> void:
	if not sfx_dano_stream:
		return
	var player := AudioStreamPlayer.new()
	player.stream = sfx_dano_stream
	player.volume_db = 2.0
	player.bus = "Master"
	var root := get_tree().current_scene
	if root:
		root.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
	else:
		player.queue_free()


func _reproducir_sonido_muerte() -> void:
	if not sfx_muerte_stream:
		return
	var player := AudioStreamPlayer.new()
	player.stream = sfx_muerte_stream
	player.volume_db = 2.0
	player.bus = "Master"
	var root := get_tree().current_scene
	if root:
		root.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
	else:
		player.queue_free()
