class_name Lonko
extends EnemyBase

## Lonko: Enemigo arquero avanzado con 6 puntos de vida.
## Nace, camina hasta su posición de tiro, invoca un pilar vinculado emergiendo del suelo con invulnerabilidad,
## bamboleo estilo terremoto, asciende en sincronía perfecta con el pilar, se orienta hacia la jugadora y entra en modo ataque.
## Al morir, el pilar se hunde en la tierra y se disuelve.
## Animaciones:
## - Caminar/Correr: CORRER_01, CORRE_02 (variantes aleatorias)
## - Daño/Impacto: IMPACTO_01, IMPACTO_02 (variantes aleatorias) + Daño.mp3
## - Muerte normal: MUERTE_01, MUERTE_02 (variantes aleatorias) + Muerte.mp3
## - Invocación: PILAR_SUBIDA (hasta seg 9.5 a 1.15x velocidad, emergiendo PILAR_LONKO.glb)
## - Disparo: RECARGA (toma la flecha y la escala) -> DISPARO (la suelta y lanza proyectil)

const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")
const CameraUtilsRef = preload("res://System/Utils/CameraUtils.gd")
const TIEMPO_DISPARO: float = 0.8
const TIEMPO_LANZAR_FLECHA: float = 0.35

@export_category("Combate - Lonko")
@export var tiempo_recarga_min: float = 1.5
@export var tiempo_recarga_max: float = 3.0
@export var pausa_entre_disparos: float = 2.0
@export var potencia_disparo_min: float = 2.0  ## Potencia mínima de disparo (x2)
@export var potencia_disparo_max: float = 3.0  ## Potencia máxima de disparo (x3)
@export var velocidad_proyectil: float = 12.0
@export var color_proyectil_lonko: Color = Color(0.2, 1.0, 0.2, 1.0)  ## Verde lima

@export_category("Pilar - Lonko")
@export var pilar_lonko_scene: PackedScene = preload("res://LONKO/PilarLonko.tscn")  ## Escena configurable del pilar
@export var altura_pilar_offset: float = 3.2  ## Altura final de Lonko sobre el pilar (ajustable manualmente en Inspector)
@export var escala_pilar: float = 3.0         ## Escala del pilar (3.0x por defecto)
@export var vida_pilar_max: float = 13.0      ## Vida del pilar (13 HP de resistencia)
@export var textura_rocas_pilar: Texture2D = null  ## Textura opcional para partículas de rocas en el suelo

@export_category("Debug Tracking - Lonko")
@export var debug_tracking_override: bool = false  ## Activar para usar el slider de ángulo manualmente
@export_range(-90.0, 90.0, 0.5) var debug_pitch_deg: float = 0.0  ## Slider para probar la rotación en vivo

# Referencias
var lonko_arrow_scene: PackedScene = preload("res://Entities/Projectiles/GoblinGirlArrow.tscn")
var sfx_dano_stream: AudioStream = preload("res://LONKO/Daño.mp3")
var sfx_muerte_stream: AudioStream = preload("res://LONKO/Muerte.mp3")
var sfx_pilar_stream: AudioStream = preload("res://LONKO/Sonido pilar emergiendo.mp3")
var flecha_visual_mano: Node3D = null
var escala_original_flecha_mano: Vector3 = Vector3.ONE

# Estado interno
var _is_shooting: bool = false
var _has_released_arrow: bool = false
var _is_taking_damage: bool = false
var _is_invulnerable: bool = false
var _pilar_invocado: bool = false
var _pilar_desplegado: bool = false
var _tween_flecha: Tween = null
var _reached_position: bool = false
var _cached_spawn_pos: Vector3 = Vector3.ZERO
var _particulas_pilar: GPUParticles3D = null
var _instancia_pilar: Node3D = null
var _base_pos_pilar: Vector3 = Vector3.ZERO


func _on_enemy_ready() -> void:
	vida_maxima = 6
	health = 6
	color_borde_disolucion = Color(0.2, 1.0, 0.2)  # Verde lima
	rastrear_jugador = true

	var lonko_model := get_node_or_null("LONKO") as Node3D
	if lonko_model:
		lonko_model.rotation_degrees.y = -90.0
		lonko_model.scale = Vector3(0.85, 0.85, 0.85)  # Reducir tamaño un 15%

	_configurar_flecha_mano()
	_play_random_run_animation()


func _configurar_flecha_mano() -> void:
	flecha_visual_mano = find_child("FlechaMano", true, false)
	if not flecha_visual_mano:
		return

	escala_original_flecha_mano = flecha_visual_mano.scale
	flecha_visual_mano.visible = false
	flecha_visual_mano.scale = escala_original_flecha_mano * 0.01

	_recolorear_flecha_mano.call_deferred()


func _recolorear_flecha_mano() -> void:
	if not flecha_visual_mano or not is_instance_valid(flecha_visual_mano):
		return

	if "color_proyectil" in flecha_visual_mano:
		flecha_visual_mano.color_proyectil = color_proyectil_lonko

	var meshes: Array[Node] = flecha_visual_mano.find_children("*", "MeshInstance3D", true, false)
	for mesh_node in meshes:
		var mi := mesh_node as MeshInstance3D
		if not mi:
			continue
		var mat: Material = mi.material_override
		if mat is StandardMaterial3D:
			var new_mat := mat.duplicate() as StandardMaterial3D
			new_mat.albedo_color = color_proyectil_lonko
			if new_mat.emission_enabled:
				new_mat.emission = color_proyectil_lonko
			mi.material_override = new_mat

	if "trail_particles" in flecha_visual_mano and flecha_visual_mano.trail_particles:
		var tp: GPUParticles3D = flecha_visual_mano.trail_particles
		if tp.process_material is ParticleProcessMaterial:
			var pm := tp.process_material.duplicate() as ParticleProcessMaterial
			pm.color = color_proyectil_lonko
			tp.process_material = pm


# ═══════════════════════════════════════════════════════════════════════════════
# TRACKING - Rotación del torso hacia la jugadora
# ═══════════════════════════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	super._process(_delta)
	if _reached_position and _base_pos_pilar != Vector3.ZERO:
		global_position.x = _base_pos_pilar.x
		global_position.z = _base_pos_pilar.z

	if debug_tracking_override:
		_lonko_track_player()
	elif current_state == State.SHOOTING and rastrear_jugador and not _is_taking_damage and not _is_invulnerable:
		_lonko_track_player()
	else:
		_reset_spine_rotation()


func _lonko_track_player() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
	if not skeleton or spine_bone_idx == -1:
		_buscar_skeleton()

	if not skeleton or spine_bone_idx == -1:
		return

	var pitch_angle_rad: float = 0.0

	if debug_tracking_override:
		pitch_angle_rad = deg_to_rad(debug_pitch_deg)
	else:
		if not player_ref or not is_instance_valid(player_ref) or not player_ref.is_inside_tree():
			_reset_spine_rotation()
			return

		var my_pos: Vector3 = global_position + Vector3(0, 0.5, 0)
		var target_pos: Vector3 = player_ref.global_position + Vector3(0, 0.8, 0)
		var delta_y: float = target_pos.y - my_pos.y
		var delta_x: float = abs(target_pos.x - my_pos.x)

		# 0° en el suelo, hasta -60° en plataformas altas
		var angle_rad: float = atan2(max(0.0, delta_y), max(0.1, delta_x))
		var pitch_deg: float = -rad_to_deg(angle_rad)
		pitch_deg = clamp(pitch_deg, -60.0, 0.0)

		pitch_angle_rad = deg_to_rad(pitch_deg)

	skeleton.set_bone_global_pose_override(spine_bone_idx, Transform3D.IDENTITY, 0.0, false)
	var bone_pose: Transform3D = skeleton.get_bone_global_pose(spine_bone_idx)

	var pitch_rotation := Quaternion(Vector3.RIGHT, pitch_angle_rad)
	var new_basis: Basis = Basis(pitch_rotation) * bone_pose.basis

	skeleton.set_bone_global_pose_override(
		spine_bone_idx, Transform3D(new_basis, bone_pose.origin), 1.0, false
	)


# ═══════════════════════════════════════════════════════════════════════════════
# ESTADOS Y NAVEGACIÓN
# ═══════════════════════════════════════════════════════════════════════════════

func _on_state_walking() -> void:
	if _pilar_desplegado or _reached_position:
		_change_state(State.SHOOTING)
		return
	_is_shooting = false
	_ocultar_flecha_mano()
	_reset_spine_rotation()
	if not _is_taking_damage:
		_play_random_run_animation()


func _process_walking(delta: float) -> void:
	if _pilar_desplegado or _reached_position:
		velocity.x = 0
		_change_state(State.SHOOTING)
		return

	if _is_taking_damage or _is_invulnerable:
		velocity.x = 0
		return

	velocity.x = -velocidad_caminar
	walked_distance += velocidad_caminar * delta

	if modo_pacifico:
		if global_position.x <= limite_pacifico_x:
			velocity.x = 0
			if not pacifico_detenido:
				pacifico_detenido = true
				_on_pacifico_detenido()
		return

	if walked_distance >= target_walk_distance:
		if _check_spacing():
			_reached_position = true
			_base_pos_pilar = global_position
			_change_state(State.SHOOTING)
		else:
			target_walk_distance += 0.3


func _on_state_shooting() -> void:
	if _is_shooting or _is_taking_damage:
		return
	if not _pilar_invocado and not _pilar_desplegado:
		_iniciar_secuencia_pilar()
	elif _pilar_desplegado:
		_iniciar_secuencia_disparo()


func _process_shooting(_delta: float) -> void:
	velocity.x = 0
	if _pilar_desplegado or _is_invulnerable or _pilar_invocado:
		velocity.y = 0


func _play_random_run_animation() -> void:
	var rand_run: String = "CORRER_01" if randf() < 0.5 else "CORRE_02"
	_play_animation(rand_run)


# ═══════════════════════════════════════════════════════════════════════════════
# SECUENCIA DEL PILAR VINCULADO (PILAR_SUBIDA + BAMBOLEO + VFX)
# ═══════════════════════════════════════════════════════════════════════════════

func _iniciar_secuencia_pilar() -> void:
	if _pilar_invocado or (_instancia_pilar and is_instance_valid(_instancia_pilar)):
		return
	_pilar_invocado = true
	_is_invulnerable = false  ## Vulnerable a ataques durante la subida
	velocity = Vector3.ZERO
	_base_pos_pilar = global_position

	var base_x: float = _base_pos_pilar.x
	var base_y: float = _base_pos_pilar.y
	var base_z: float = _base_pos_pilar.z
	var altura_pilar: float = altura_pilar_offset

	# 1. Crear partículas de rocas en la intersección exacta del suelo con el pilar
	_crear_particulas_rocas_pilar(base_x, base_y, base_z)
	_reproducir_sonido_pilar()

	# Girar el modelo hacia el fondo durante la animación de subida
	var lonko_model := get_node_or_null("LONKO") as Node3D
	if lonko_model:
		lonko_model.rotation_degrees.y = 180.0  # Mirar hacia el fondo
		lonko_model.position = Vector3.ZERO

	var duracion_base: float = 9.5
	var velocidad_anim: float = 1.15
	var duracion_real: float = duracion_base / velocidad_anim

	# 2. Animación PILAR_SUBIDA 15% más rápida
	_play_animation("PILAR_SUBIDA", 0.2, velocidad_anim)

	# 3. Instanciar PILAR_LONKO.glb vinculado a este Lonko (sin colisión con enemigos)
	if pilar_lonko_scene:
		_instancia_pilar = pilar_lonko_scene.instantiate() as Node3D
		var root := get_tree().current_scene
		if root and _instancia_pilar:
			root.add_child(_instancia_pilar)
			_instancia_pilar.scale = Vector3(escala_pilar, escala_pilar, escala_pilar)

			var pilar_start_y: float = base_y - altura_pilar
			_instancia_pilar.global_position = Vector3(base_x, pilar_start_y, base_z)

			# Inicializar colisionador físico destructible para el pilar (13 HP)
			var pilar_body := _instancia_pilar.find_child("PilarBody", true, false) as PilarLonkoBody
			if not pilar_body:
				pilar_body = PilarLonkoBody.new()
				pilar_body.name = "PilarBody"
				pilar_body.collision_layer = 2  # Capa de escudos
				pilar_body.collision_mask = 0

				var col_shape := CollisionShape3D.new()
				var cylinder := CylinderShape3D.new()
				cylinder.height = altura_pilar
				cylinder.radius = 0.65
				col_shape.shape = cylinder
				col_shape.position = Vector3(0, altura_pilar * 0.5, 0)
				pilar_body.add_child(col_shape)
				_instancia_pilar.add_child(pilar_body)

			pilar_body.inicializar(self, vida_pilar_max)

			# Animar la emergencia del pilar Y la elevación de Lonko a la par
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(_instancia_pilar, "global_position:y", base_y, duracion_real) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "global_position:y", base_y + altura_pilar, duracion_real) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 4. Bamboleo sutil estilo terremoto (duración reducida 2 segundos menos)
	var _wobble_active: bool = true
	var duracion_bamboleo: float = max(1.0, (duracion_real * 0.70) - 2.0)
	var wobble_task := func():
		var elapsed_wobble: float = 0.0
		while elapsed_wobble < duracion_bamboleo and _wobble_active:
			if not is_instance_valid(self) or not is_instance_valid(_instancia_pilar):
				return
			var angle: float = sin(elapsed_wobble * 15.0) * 0.63  # Bamboleo sutil ±0.63°
			_instancia_pilar.rotation_degrees.z = angle
			await get_tree().create_timer(0.02).timeout
			elapsed_wobble += 0.02
		if is_instance_valid(_instancia_pilar):
			_instancia_pilar.rotation_degrees.z = 0.0

	wobble_task.call()

	# 5. Agitación de cámara durante la subida
	_shake_camera_during(duracion_real)

	# 5. Esperar a que se complete hasta el segundo 9.5 de la animación
	await get_tree().create_timer(duracion_real).timeout

	if not is_instance_valid(self):
		return

	# Detener animación de subida y bamboleo inmediatamente para quedar 100% estático
	_wobble_active = false
	if anim_player:
		anim_player.stop()

	if is_instance_valid(_instancia_pilar):
		_instancia_pilar.rotation_degrees.z = 0.0

	# Detener la emisión de partículas inmediatamente
	_detener_particulas_pilar()

	# Fijar posición final exacta en la cima del pilar
	global_position = Vector3(base_x, base_y + altura_pilar, base_z)

	# Reorientar hacia la izquierda (jugadora) para entrar en modo ataque
	if lonko_model:
		lonko_model.rotation_degrees.y = -90.0
		lonko_model.position = Vector3.ZERO

	_reset_camera_offset()
	_is_invulnerable = false
	_pilar_desplegado = true

	# Entrar en modo ataque (disparo continuo)
	if current_state == State.SHOOTING and not _is_taking_damage:
		_iniciar_secuencia_disparo()


func _crear_particulas_rocas_pilar(bx: float, by: float, bz: float) -> void:
	_particulas_pilar = GPUParticles3D.new()
	_particulas_pilar.name = "ParticulasRocasPilar"
	_particulas_pilar.amount = 45
	_particulas_pilar.lifetime = 4.6  ## +2 segundos más de duración (4.6s)
	_particulas_pilar.one_shot = true  ## Emisión tipo ráfaga únicamente al inicio
	_particulas_pilar.explosiveness = 0.85

	var rocas_tex: Texture2D = textura_rocas_pilar
	if not rocas_tex:
		rocas_tex = load("res://LONKO/ROCAS.png") as Texture2D

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.20, 0.05, 0.20)  ## Dispersión reducida un 70%
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 15.0  ## Ángulo de dispersión reducido un 70% (15°)
	pmat.initial_velocity_min = 2.5
	pmat.initial_velocity_max = 5.5
	pmat.gravity = Vector3(0, -12.0, 0)
	pmat.scale_min = 0.20  ## Tamaño reducido un 20%
	pmat.scale_max = 0.52
	pmat.color = Color(1.0, 1.0, 1.0, 1.0)

	# Seleccionar aleatoriamente una de las 4 rocas del atlas ROCAS.png
	pmat.anim_offset_min = 0.0
	pmat.anim_offset_max = 1.0
	pmat.angle_min = 0.0
	pmat.angle_max = 360.0
	pmat.angular_velocity_min = -180.0
	pmat.angular_velocity_max = 180.0
	_particulas_pilar.process_material = pmat

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = rocas_tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.particles_anim_h_frames = 4
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = false
	mat.render_priority = -1  ## Renderizar por detrás del pilar

	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)  ## Malla reducida un 20% (0.28m x 0.28m)
	quad.material = mat
	_particulas_pilar.draw_pass_1 = quad

	var root := get_tree().current_scene
	if root:
		root.add_child(_particulas_pilar)
		# Nacer en la base del suelo donde emerge el pilar
		_particulas_pilar.global_position = Vector3(bx, by + 0.02, bz + 0.15)
		_particulas_pilar.emitting = true

	# Autodestruir el nodo de partículas tras concluir la ráfaga (~6.5 seg)
	get_tree().create_timer(6.5).timeout.connect(func():
		if _particulas_pilar and is_instance_valid(_particulas_pilar):
			_particulas_pilar.queue_free()
			_particulas_pilar = null
	)


func _detener_particulas_pilar() -> void:
	if _particulas_pilar and is_instance_valid(_particulas_pilar):
		_particulas_pilar.emitting = false
		get_tree().create_timer(2.0).timeout.connect(func():
			if _particulas_pilar and is_instance_valid(_particulas_pilar):
				_particulas_pilar.queue_free()
				_particulas_pilar = null
		)


func _shake_camera_during(duration: float) -> void:
	var elapsed: float = 0.0
	while elapsed < duration:
		if not is_instance_valid(self) or not is_inside_tree():
			return
		var cam: Camera3D = CameraUtilsRef.obtener_camara_juego(self)
		if cam:
			var intensity: float = 0.025
			cam.h_offset = randf_range(-intensity, intensity)
			cam.v_offset = randf_range(-intensity, intensity)
		await get_tree().create_timer(0.03).timeout
		elapsed += 0.03

	_reset_camera_offset()


func _reset_camera_offset() -> void:
	var cam: Camera3D = CameraUtilsRef.obtener_camara_juego(self)
	if cam:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


# ═══════════════════════════════════════════════════════════════════════════════
# SECUENCIA DE DISPARO
# ═══════════════════════════════════════════════════════════════════════════════

func _iniciar_secuencia_disparo() -> void:
	_is_shooting = true
	_has_released_arrow = false
	velocity = Vector3.ZERO

	var tiempo_recarga_actual: float = randf_range(tiempo_recarga_min, tiempo_recarga_max)

	# 1. RECARGA: toma la flecha y la escala
	_play_animation("RECARGA")
	_mostrar_y_escalar_flecha_mano(tiempo_recarga_actual)

	await get_tree().create_timer(tiempo_recarga_actual).timeout
	if current_state != State.SHOOTING or _is_taking_damage or not is_instance_valid(self):
		return

	# Capturar posición de spawn al final de RECARGA
	if flecha_visual_mano and is_instance_valid(flecha_visual_mano) and flecha_visual_mano.is_inside_tree():
		_cached_spawn_pos = flecha_visual_mano.global_position
	else:
		_cached_spawn_pos = global_position + Vector3(0, altura_spawn_flecha, 0)

	# 2. DISPARO: suelta la flecha
	_play_animation("DISPARO")

	await get_tree().create_timer(TIEMPO_LANZAR_FLECHA).timeout
	if current_state != State.SHOOTING or _is_taking_damage or not is_instance_valid(self):
		return

	_disparar_proyectil()

	var tiempo_restante: float = max(0.05, TIEMPO_DISPARO - TIEMPO_LANZAR_FLECHA)
	await get_tree().create_timer(tiempo_restante).timeout

	if not is_instance_valid(self) or current_state != State.SHOOTING:
		return

	_is_shooting = false
	_reset_spine_rotation()

	# Pausa entre disparos, luego volver a disparar
	if not _is_taking_damage:
		_play_animation("IDLE")
		await get_tree().create_timer(pausa_entre_disparos).timeout
		if not is_instance_valid(self) or current_state != State.SHOOTING:
			return
		if not _is_taking_damage:
			_iniciar_secuencia_disparo()


# ═══════════════════════════════════════════════════════════════════════════════
# FLECHA VISUAL EN LA MANO
# ═══════════════════════════════════════════════════════════════════════════════

func _mostrar_y_escalar_flecha_mano(duracion_total: float) -> void:
	if not flecha_visual_mano:
		flecha_visual_mano = find_child("FlechaMano", true, false)
	if not flecha_visual_mano:
		return

	flecha_visual_mano.visible = true
	flecha_visual_mano.scale = escala_original_flecha_mano * 0.01

	if _tween_flecha and _tween_flecha.is_valid():
		_tween_flecha.kill()
	_tween_flecha = create_tween()
	_tween_flecha.tween_interval(1.0)
	var duracion_escalado: float = max(0.2, duracion_total - 1.0)
	_tween_flecha.tween_property(flecha_visual_mano, "scale", escala_original_flecha_mano, duracion_escalado) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ocultar_flecha_mano() -> void:
	if _tween_flecha and _tween_flecha.is_valid():
		_tween_flecha.kill()
	if not flecha_visual_mano:
		flecha_visual_mano = find_child("FlechaMano", true, false)
	if flecha_visual_mano:
		flecha_visual_mano.visible = false
		flecha_visual_mano.scale = escala_original_flecha_mano * 0.01


# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO DEL PROYECTIL
# ═══════════════════════════════════════════════════════════════════════════════

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

	var spawn_pos: Vector3 = _cached_spawn_pos
	if spawn_pos.is_zero_approx():
		spawn_pos = global_position + Vector3(0, altura_spawn_flecha, 0)

	var target_pos: Vector3 = global_position + Vector3(-5, 0, 0)
	if player_ref and is_instance_valid(player_ref):
		target_pos = player_ref.global_position + Vector3(0, 1.0, 0)

	if "color_proyectil" in arrow:
		arrow.color_proyectil = color_proyectil_lonko

	var root_scene := get_tree().current_scene
	if root_scene:
		root_scene.add_child(arrow)
		arrow.global_position = spawn_pos

		var dir := (target_pos - spawn_pos).normalized()
		var potencia_actual: float = randf_range(potencia_disparo_min, potencia_disparo_max)

		if arrow.has_method("initialize"):
			arrow.initialize(dir, potencia_actual)
		elif arrow.has_method("lanzar"):
			arrow.lanzar(dir * (velocidad_proyectil * potencia_actual))
		elif "velocity" in arrow:
			arrow.velocity = dir * (velocidad_proyectil * potencia_actual)

	AudioManager.play_sfx("disparo_flecha")


# ═══════════════════════════════════════════════════════════════════════════════
# DAÑO Y MUERTE (Con hundimiento y disolución del pilar)
# ═══════════════════════════════════════════════════════════════════════════════

func take_damage(amount: float) -> void:
	if current_state == State.DYING or current_state == State.DEAD or _is_invulnerable:
		return

	health -= int(amount)
	_flash_red()

	if health <= 0:
		_change_state(State.DYING)
	else:
		_is_taking_damage = true
		_is_shooting = false
		velocity = Vector3.ZERO
		_ocultar_flecha_mano()
		_reset_spine_rotation()
		_reproducir_sonido_dano()

		var rand_impact: String = "IMPACTO_01" if randf() < 0.5 else "IMPACTO_02"
		_play_animation(rand_impact)

		var dur: float = max(0.3, _get_animation_duration(rand_impact))
		get_tree().create_timer(dur).timeout.connect(func():
			if not is_instance_valid(self):
				return
			_is_taking_damage = false
			if current_state == State.DYING or current_state == State.DEAD:
				return
			if _pilar_desplegado:
				_change_state(State.SHOOTING)
			elif _pilar_invocado:
				_change_state(State.SHOOTING)
			elif _reached_position:
				_change_state(State.SHOOTING)
			else:
				_on_state_walking()
		)


func _on_state_dying() -> void:
	_is_taking_damage = true
	_ocultar_flecha_mano()
	_reset_spine_rotation()
	_reproducir_sonido_muerte()
	_hundir_y_disolver_pilar()

	super._on_state_dying()

	var rand_death: String = "MUERTE_01" if randf() < 0.5 else "MUERTE_02"
	_play_animation(rand_death)

	var anim_length: float = _get_animation_duration(rand_death)
	get_tree().create_timer(anim_length + 0.3).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_die()
	)


func _on_pilar_destruido() -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	# Al destruir el pilar, matar a Lonko. Su función _on_state_dying() ejecutará la animación y desintegración unificada
	take_damage(999.0)


func _hundir_y_disolver_pilar() -> void:
	if not _instancia_pilar or not is_instance_valid(_instancia_pilar):
		return

	var pilar_to_destroy := _instancia_pilar
	_instancia_pilar = null

	var target_sink_y: float = pilar_to_destroy.global_position.y - altura_pilar_offset
	var duracion_hundir: float = 1.2
	var ground_y: float = _base_pos_pilar.y if _base_pos_pilar != Vector3.ZERO else (global_position.y - altura_pilar_offset)

	# 1. Aplicar shader de disolución conservando la textura original del pilar
	var dissolve_shader := load("res://System/Shaders/dissolve.gdshader") as Shader
	var materials: Array[ShaderMaterial] = []
	if dissolve_shader:
		var meshes := pilar_to_destroy.find_children("*", "MeshInstance3D", true, false)
		for mesh_node in meshes:
			var mi := mesh_node as MeshInstance3D
			if not mi:
				continue

			var tex: Texture2D = null
			if mi.material_override is StandardMaterial3D and mi.material_override.albedo_texture:
				tex = mi.material_override.albedo_texture
			elif mi.mesh and mi.mesh.surface_get_material(0) is StandardMaterial3D:
				tex = mi.mesh.surface_get_material(0).albedo_texture
			if not tex:
				tex = load("res://LONKO/PILAR_LONKO_D.jpg") as Texture2D

			var mat := ShaderMaterial.new()
			mat.shader = dissolve_shader
			if tex:
				mat.set_shader_parameter("albedo_texture", tex)
			mat.set_shader_parameter("glow_color", color_borde_disolucion)  # Verde lima
			mat.set_shader_parameter("glow_intensity", 6.0)
			mat.set_shader_parameter("edge_thickness", 0.05)
			mat.set_shader_parameter("dissolve_amount", 0.0)
			mi.material_override = mat
			materials.append(mat)

	# 2. Tween paralelo: hundir el pilar, hacer caer a Lonko al suelo y disolver el material
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(pilar_to_destroy, "global_position:y", target_sink_y, duracion_hundir) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "global_position:y", ground_y, duracion_hundir) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if not materials.is_empty():
		var update_dissolve := func(val: float):
			for mat in materials:
				if is_instance_valid(mat):
					mat.set_shader_parameter("dissolve_amount", val)
		tween.tween_method(update_dissolve, 0.0, 1.0, duracion_hundir)

	tween.chain().tween_callback(pilar_to_destroy.queue_free)


# ═══════════════════════════════════════════════════════════════════════════════
# SONIDO
# ═══════════════════════════════════════════════════════════════════════════════

func _reproducir_sonido_pilar() -> void:
	if not sfx_pilar_stream:
		return
	var player := AudioStreamPlayer.new()
	player.stream = sfx_pilar_stream
	player.volume_db = 0.0
	player.bus = "Master"
	var root := get_tree().current_scene
	if root:
		root.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
	else:
		player.queue_free()


func _reproducir_sonido_dano() -> void:
	if not sfx_dano_stream:
		return
	var player := AudioStreamPlayer.new()
	player.stream = sfx_dano_stream
	player.volume_db = -2.5  ## Reducido un 40%
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
	player.volume_db = -2.5  ## Reducido un 40%
	player.bus = "Master"
	var root := get_tree().current_scene
	if root:
		root.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
	else:
		player.queue_free()
