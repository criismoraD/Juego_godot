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
const FLECHA_ELECTRICA_SCENE = preload("res://Entities/Enemigo_Lonko/Flecha_Electrica_Ataque.tscn")
const TIEMPO_DISPARO: float = 0.8
const TIEMPO_LANZAR_FLECHA: float = 0.35

## Humo de pisadas: spritesheet SmokeFX Lite 1A-1 (tira horizontal 9x1 de 64px)
const TEXTURA_HUMO_PISADAS: String = "res://TEST_/HUMO_PISADAS/SmokeFX Lite SpriteSheet 1A-1.png"
const HUMO_PISADAS_FRAMES_H: int = 9
const HUMO_PISADAS_FRAMES_V: int = 1

@export_category("Combate - Lonko")
@export var tiempo_recarga_min: float = 1.5
@export var tiempo_recarga_max: float = 3.0
@export var pausa_entre_disparos: float = 2.0
@export var potencia_disparo_min: float = 2.0  ## Potencia mínima de disparo (x2)
@export var potencia_disparo_max: float = 3.0  ## Potencia máxima de disparo (x3)
@export var velocidad_proyectil: float = 12.0
@export var color_proyectil_lonko: Color = Color(0.2, 1.0, 0.2, 1.0)  ## Verde lima

@export_category("Ataque Eléctrico - Lonko")
@export var cada_cuantos_tiros_electrico: int = 3  ## Cada N disparos, dispara la flecha eléctrica vertical
@export var altura_cielo_electrica: float = 45.0  ## Altura a la que la flecha sale de pantalla
@export var velocidad_subida_electrica: float = 40.0  ## Velocidad de ascenso vertical (doble de rápida)
@export var zona_caida_x_min: float = -10.0  ## Límite izquierdo de la zona aliada de caída
@export var zona_caida_x_max: float = -6.5  ## Límite derecho de la zona aliada de caída
@export var zona_caida_z: float = 0.0  ## Plano Z fijo de la zona de caída
@export var segundos_marca_caida: float = 1.5  ## Tiempo de aviso con aros rojos antes de caer
@export var radio_marca_caida: float = 1.25  ## Radio de los aros de la marca
@export var tiempo_recarga_electrica: float = 2.0  ## Duración de la recarga eléctrica (= duración de "Cargando SP.mp3", 2 s)

@export_category("Pilar - Lonko")
@export var pilar_lonko_scene: PackedScene = preload("res://Entities/Enemigo_Lonko/PilarLonko.tscn")  ## Escena configurable del pilar
@export var altura_pilar_offset: float = 3.2  ## Altura final de Lonko sobre el pilar (ajustable manualmente en Inspector)
@export var escala_pilar: float = 3.0         ## Escala del pilar (3.0x por defecto)
@export var vida_pilar_max: float = 15.0      ## Vida del pilar (15 HP de resistencia)
@export var textura_rocas_pilar: Texture2D = null  ## Textura opcional para partículas de rocas en el suelo

@export_category("Drops - Lonko")
@export var power_up_explosivo_scene: PackedScene = preload("res://Entities/Item_Flecha_Explosiva/PowerUpFlechaExplosiva.tscn")
@export_range(0.0, 1.0, 0.01) var drop_chance_flecha_explosiva: float = 0.30  ## 30% de probabilidad de dropear power-up

@export_category("Debug Tracking - Lonko")
@export var debug_tracking_override: bool = false  ## Activar para usar el slider de ángulo manualmente
@export_range(-90.0, 90.0, 0.5) var debug_pitch_deg: float = 0.0  ## Slider para probar la rotación en vivo

# Referencias
var lonko_arrow_scene: PackedScene = preload("res://Entities/Proyectil_Flecha_Goblin_Girl/GoblinGirlArrow.tscn")
var sfx_dano_stream: AudioStream = preload("res://Entities/Enemigo_Lonko/Daño.mp3")
var sfx_muerte_stream: AudioStream = preload("res://Entities/Enemigo_Lonko/Muerte.mp3")
var sfx_pilar_stream: AudioStream = preload("res://Entities/Enemigo_Lonko/Sonido pilar emergiendo.mp3")
var sfx_cargando_sp_stream: AudioStream = preload("res://Entities/Enemigo_Lonko/Cargando SP.mp3")
var flecha_visual_mano: Node3D = null
var escala_original_flecha_mano: Vector3 = Vector3.ONE

# Estado interno
var _is_shooting: bool = false
var _has_released_arrow: bool = false
var _is_taking_damage: bool = false
var _is_invulnerable: bool = false
var _pilar_invocado: bool = false
var _pilar_desplegado: bool = false
var _pilar_fue_destruido_primero: bool = false
var _tween_flecha: Tween = null
var _tween_subida: Tween = null
var _reached_position: bool = false
var _cached_spawn_pos: Vector3 = Vector3.ZERO
var _particulas_pilar: GPUParticles3D = null
var _particulas_pisada: GPUParticles3D = null  ## Polvo de las pisadas al correr
var _instancia_pilar: Node3D = null
var _base_pos_pilar: Vector3 = Vector3.ZERO
var _tiros_realizados: int = 0  ## Contador de tiros lanzados (para el ataque eléctrico periódico)
var _apuntar_arriba: bool = false  ## True mientras el próximo disparo es el eléctrico (apunta a -90°)

# Recursos de pilares
var pilar_destruido_scene: PackedScene = preload("res://Entities/Enemigo_Lonko/PILAR_DESTRUIDO.glb")
var explocion_pilar_scene: PackedScene = preload("res://Entities/Enemigo_Lonko/Explocion_Pilar.tscn")
var tex_pilar_destruido: Texture2D = preload("res://Entities/Enemigo_Lonko/PILAR_DESTRUIDO_D.jpg")
var tex_pilar_normal: Texture2D = preload("res://Entities/Enemigo_Lonko/PILAR_LONKO_D.jpg")
var sfx_explosion_01: AudioStream = preload("res://Entities/Enemigo_Lonko/EXPLOSION01.mp3")
var sfx_explosion_02: AudioStream = preload("res://Entities/Enemigo_Lonko/EXPLOSION02.mp3")
var _flecha_electrica_en_mano: FlechaElectricaAtaque = null  ## Proyectil eléctrico cargado en la mano durante la RECARGA
var omni_light_sp: OmniLight3D = null  ## Luz lila que ilumina durante el ataque especial (similar a la Gárgola)


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
	_configurar_particulas_pisada()
	_play_random_run_animation()


func _configurar_particulas_pisada() -> void:
	if not _particulas_pisada:
		_particulas_pisada = find_child("Particulas_Pisada", true, false) as GPUParticles3D
	if not _particulas_pisada:
		return

	var mat := StandardMaterial3D.new()
	var tex := load(TEXTURA_HUMO_PISADAS) as Texture2D
	if tex:
		mat.albedo_texture = tex
		# Spritesheet animado: tira horizontal 9x1 (SmokeFX Lite 1A-1)
		mat.particles_anim_h_frames = HUMO_PISADAS_FRAMES_H
		mat.particles_anim_v_frames = HUMO_PISADAS_FRAMES_V
		mat.particles_anim_loop = false
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.render_priority = 2

	var mesh := QuadMesh.new()
	mesh.material = mat
	mesh.size = Vector2(0.6552, 0.6552)  # +80% sobre 0.364
	_particulas_pisada.draw_pass_1 = mesh

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 50.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0.0, 0.2, 0.0)
	pm.scale_min = 0.81  # +80% sobre 0.45
	pm.scale_max = 1.314  # +80% sobre 0.73
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.16, 0.02, 0.16)
	# Animación del spritesheet: un ciclo completo por partícula, con desfase aleatorio
	pm.anim_speed_min = 1.0
	pm.anim_speed_max = 1.0
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0

	var grad := Gradient.new()
	grad.set_color(0, Color(0.5, 0.5, 0.5, 0.85))  # Gris
	grad.set_color(1, Color(0.5, 0.5, 0.5, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pm.color_ramp = grad_tex

	# Curva de escala suave en 4 puntos
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.25), 0.0, 1.2)
	curve.add_point(Vector2(0.3, 1.0), 0.2, -0.4)
	curve.add_point(Vector2(0.65, 0.6), -0.6, -0.8)
	curve.add_point(Vector2(1.0, 0.0), -1.2, 0.0)
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	pm.scale_curve = curve_tex

	_particulas_pisada.process_material = pm
	_particulas_pisada.amount = 16  # Reducido a la mitad
	_particulas_pisada.lifetime = 1.15  # Estela suave duradera


func _configurar_flecha_mano() -> void:
	_particulas_pisada = find_child("Particulas_Pisada", true, false) as GPUParticles3D

	flecha_visual_mano = find_child("FlechaMano", true, false)
	if not flecha_visual_mano:
		return

	escala_original_flecha_mano = flecha_visual_mano.scale
	flecha_visual_mano.visible = false
	flecha_visual_mano.scale = escala_original_flecha_mano * 0.01

	# El VFX manual (FlechaElectricaVFX_Manual) solo se muestra sincronizado con
	# la flecha eléctrica en mano durante la RECARGA eléctrica.
	var vfx_manual := find_child("FlechaElectricaVFX_Manual", true, false) as Node3D
	if vfx_manual:
		vfx_manual.visible = false

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
	if _particulas_pisada:
		_particulas_pisada_emitir()
	if _reached_position and _base_pos_pilar != Vector3.ZERO:
		global_position.x = _base_pos_pilar.x
		global_position.z = _base_pos_pilar.z

	if debug_tracking_override:
		_lonko_track_player()
	elif current_state == State.SHOOTING and rastrear_jugador and not _is_taking_damage and not _is_invulnerable:
		_lonko_track_player()
	else:
		_reset_spine_rotation()


## Polvo de pisadas: se activa mientras Lonko se desplaza por el escenario.
func _particulas_pisada_emitir() -> void:
	var moviendose := velocity.length_squared() > 0.04 or not _reached_position
	_particulas_pisada.emitting = (
		moviendose and not _is_taking_damage and current_state != State.DYING and current_state != State.DEAD
	)


func _lonko_track_player() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
	if not skeleton or spine_bone_idx == -1:
		_buscar_skeleton()

	if not skeleton or spine_bone_idx == -1:
		return

	var pitch_angle_rad: float = 0.0

	if _apuntar_arriba:
		# Disparo eléctrico: apuntar completamente hacia arriba, sin tracking
		pitch_angle_rad = deg_to_rad(-90.0)
	elif debug_tracking_override:
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
	_is_invulnerable = true  ## Invulnerable a ataques y flechas atraviesan durante la subida
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
			_tween_subida = create_tween()
			_tween_subida.set_parallel(true)
			_tween_subida.tween_property(_instancia_pilar, "global_position:y", base_y, duracion_real) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween_subida.tween_property(self, "global_position:y", base_y + altura_pilar, duracion_real) \
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
		rocas_tex = load("res://Entities/Enemigo_Lonko/ROCAS.png") as Texture2D

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

	# El próximo tiro es eléctrico cada `cada_cuantos_tiros_electrico` disparos:
	# apuntar el torso completamente hacia arriba (sin tracking) durante la secuencia
	_apuntar_arriba = _es_tiro_electrico(_tiros_realizados + 1)

	var tiempo_recarga_actual: float = randf_range(tiempo_recarga_min, tiempo_recarga_max)
	if _apuntar_arriba:
		# El tiro eléctrico carga exactamente lo que dura "Cargando SP.mp3" (2 s)
		_is_invulnerable = true  # Invulnerable durante la preparación y ejecución de la ulti
		tiempo_recarga_actual = tiempo_recarga_electrica
		_reproducir_sonido_cargando_sp()

	# 1. RECARGA: toma la flecha y la escala
	if _apuntar_arriba:
		# Estirar la animación para que la pose dure toda la recarga lenta
		var duracion_clip_recarga: float = max(0.1, _get_animation_duration("RECARGA"))
		_play_animation("RECARGA", 0.2, duracion_clip_recarga / tiempo_recarga_actual)
		_mostrar_flecha_electrica_en_mano(tiempo_recarga_actual)
	else:
		_play_animation("RECARGA")
		_mostrar_y_escalar_flecha_mano(tiempo_recarga_actual)

	await get_tree().create_timer(tiempo_recarga_actual, false).timeout
	if current_state != State.SHOOTING or _is_taking_damage or not is_instance_valid(self):
		if _apuntar_arriba:
			_is_invulnerable = false
		return

	# Capturar posición de spawn al final de RECARGA
	if flecha_visual_mano and is_instance_valid(flecha_visual_mano) and flecha_visual_mano.is_inside_tree():
		_cached_spawn_pos = flecha_visual_mano.global_position
	else:
		_cached_spawn_pos = global_position + Vector3(0, altura_spawn_flecha, 0)

	# 2. DISPARO: suelta la flecha
	_play_animation("DISPARO")

	await get_tree().create_timer(TIEMPO_LANZAR_FLECHA, false).timeout
	if current_state != State.SHOOTING or _is_taking_damage or not is_instance_valid(self):
		if _apuntar_arriba:
			_is_invulnerable = false
		return

	_disparar_proyectil()

	var tiempo_restante: float = max(0.05, TIEMPO_DISPARO - TIEMPO_LANZAR_FLECHA)
	await get_tree().create_timer(tiempo_restante, false).timeout

	if not is_instance_valid(self) or current_state != State.SHOOTING:
		if _apuntar_arriba:
			_is_invulnerable = false
		return

	_is_shooting = false
	if _apuntar_arriba:
		_is_invulnerable = false
	_apuntar_arriba = false
	_reset_spine_rotation()

	# Pausa entre disparos, luego volver a disparar
	if not _is_taking_damage:
		_play_animation("IDLE")
		await get_tree().create_timer(pausa_entre_disparos, false).timeout
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
	_set_flecha_mano_meshes_visible(true)

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
	_liberar_flecha_electrica_en_mano()
	_apagar_luz_especial()
	if not flecha_visual_mano:
		flecha_visual_mano = find_child("FlechaMano", true, false)
	if flecha_visual_mano:
		flecha_visual_mano.visible = false
		flecha_visual_mano.scale = escala_original_flecha_mano * 0.01


var _escala_original_vfx_manual: Vector3 = Vector3.ZERO


## Para el tiro eléctrico: muestra el proyectil Flecha_Electrica_Ataque en la mano
## durante toda la RECARGA (modelo + VFX eléctrico) en lugar de la flecha normal.
func _mostrar_flecha_electrica_en_mano(duracion_total: float) -> void:
	_ocultar_flecha_mano()

	if not flecha_visual_mano:
		flecha_visual_mano = find_child("FlechaMano", true, false)
	if not flecha_visual_mano:
		return

	_encender_luz_especial(duracion_total)

	# Ocultar la flecha normal en la mano
	flecha_visual_mano.visible = true
	_set_flecha_mano_meshes_visible(false)

	# Mostrar y escalar de 0 a 1 el nodo FlechaElectricaVFX_Manual en BoneAttachment3D_Arrow
	var vfx_manual := find_child("FlechaElectricaVFX_Manual", true, false) as Node3D
	if vfx_manual:
		if _escala_original_vfx_manual.is_zero_approx():
			_escala_original_vfx_manual = vfx_manual.scale
		vfx_manual.visible = true
		vfx_manual.scale = _escala_original_vfx_manual * 0.01

		if _tween_flecha and _tween_flecha.is_valid():
			_tween_flecha.kill()
		_tween_flecha = create_tween()
		_tween_flecha.tween_interval(1.0)
		var duracion_escalado: float = max(0.2, duracion_total - 1.0)
		_tween_flecha.tween_property(vfx_manual, "scale", _escala_original_vfx_manual, duracion_escalado) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Muestra u oculta solo la flecha normal dentro del nodo FlechaMano
## (sin tocar el nodo padre, que ocultaría también al proyectil eléctrico).
func _set_flecha_mano_meshes_visible(visible: bool) -> void:
	if not flecha_visual_mano:
		return
	for mesh_node in flecha_visual_mano.find_children("*", "MeshInstance3D", true, false):
		if mesh_node is MeshInstance3D:
			mesh_node.visible = visible
	if "trail_particles" in flecha_visual_mano and flecha_visual_mano.trail_particles:
		flecha_visual_mano.trail_particles.emitting = visible


## Libera (destruye) la flecha eléctrica si quedó en la mano sin lanzarse
## (interrupción por daño, cambio de estado, etc.).
func _liberar_flecha_electrica_en_mano() -> void:
	_apagar_luz_especial()
	if _flecha_electrica_en_mano and is_instance_valid(_flecha_electrica_en_mano):
		_flecha_electrica_en_mano.queue_free()
	_flecha_electrica_en_mano = null
	# El VFX manual solo acompaña a la flecha mientras carga: se oculta al soltar
	# (el proyectil en vuelo lleva su propio VFX).
	var vfx_manual := find_child("FlechaElectricaVFX_Manual", true, false) as Node3D
	if vfx_manual:
		vfx_manual.visible = false


# ═══════════════════════════════════════════════════════════════════════════════
# CONTROL DE LUZ ESPECIAL (OMNILIGHT LIMA)
# ═══════════════════════════════════════════════════════════════════════════════

func _buscar_luz_especial() -> OmniLight3D:
	if omni_light_sp and is_instance_valid(omni_light_sp):
		return omni_light_sp
	var luz := find_child("LUZ_AtaqueEspecial", true, false) as OmniLight3D
	if luz:
		omni_light_sp = luz
		return omni_light_sp
	omni_light_sp = OmniLight3D.new()
	omni_light_sp.name = "LUZ_AtaqueEspecial"
	omni_light_sp.light_color = color_proyectil_lonko  ## Lima verde brillante (igual que el proyectil)
	omni_light_sp.omni_range = 5.5
	omni_light_sp.light_energy = 0.0
	omni_light_sp.visible = false
	if flecha_visual_mano and is_instance_valid(flecha_visual_mano):
		flecha_visual_mano.add_child(omni_light_sp)
	else:
		add_child(omni_light_sp)
	return omni_light_sp


func _encender_luz_especial(duracion: float = 2.0) -> void:
	var luz := _buscar_luz_especial()
	if luz:
		luz.light_color = color_proyectil_lonko  ## Lima verde
		luz.visible = true
		luz.light_energy = 0.5
		var tween := create_tween()
		tween.tween_property(luz, "light_energy", 4.5, duracion) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _apagar_luz_especial() -> void:
	if omni_light_sp and is_instance_valid(omni_light_sp):
		var tween := create_tween()
		tween.tween_property(omni_light_sp, "light_energy", 0.0, 0.25)
		tween.chain().tween_callback(func():
			if omni_light_sp and is_instance_valid(omni_light_sp):
				omni_light_sp.visible = false
		)


# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO DEL PROYECTIL
# ═══════════════════════════════════════════════════════════════════════════════

func _disparar_proyectil() -> void:
	if _has_released_arrow:
		return
	_has_released_arrow = true

	_tiros_realizados += 1

	if _es_tiro_electrico(_tiros_realizados):
		_disparar_proyectil_electrico()
		return

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


## True si el tiro `numero_tiro` (1-based) debe ser el eléctrico vertical.
func _es_tiro_electrico(numero_tiro: int) -> bool:
	if numero_tiro <= 0 or cada_cuantos_tiros_electrico <= 0:
		return false
	return numero_tiro % cada_cuantos_tiros_electrico == 0


## Disparo eléctrico periódico: la flecha eléctrica sale en vertical (apuntando al cielo),
## sale de pantalla, deja la marca de aros rojos en la zona aliada y cae del cielo.
func _disparar_proyectil_electrico() -> void:
	var vfx_manual := find_child("FlechaElectricaVFX_Manual", true, false) as Node3D
	var spawn_pos: Vector3 = _cached_spawn_pos
	if vfx_manual:
		spawn_pos = vfx_manual.global_position
		vfx_manual.visible = false

	if spawn_pos.is_zero_approx():
		spawn_pos = global_position + Vector3(0, altura_spawn_flecha, 0)

	var arrow := FLECHA_ELECTRICA_SCENE.instantiate() as FlechaElectricaAtaque
	if not arrow:
		_ocultar_flecha_mano()
		return

	_propagar_config_electrica(arrow)
	arrow.color_proyectil = color_proyectil_lonko
	var root_scene := get_tree().current_scene
	if root_scene:
		root_scene.add_child(arrow)
	else:
		get_tree().root.add_child(arrow)

	arrow.global_position = spawn_pos
	arrow._activar_desde_pool()
	arrow.initialize(Vector3.UP, 1.0)
	arrow.scale = Vector3.ONE * 0.5

	_ocultar_flecha_mano()


## Propaga la configuración exportable de Lonko al proyectil eléctrico.
func _propagar_config_electrica(arrow: FlechaElectricaAtaque) -> void:
	arrow.altura_cielo = altura_cielo_electrica
	arrow.velocidad_subida = velocidad_subida_electrica
	arrow.zona_caida_x_min = zona_caida_x_min
	arrow.zona_caida_x_max = zona_caida_x_max
	arrow.zona_caida_z = zona_caida_z
	arrow.segundos_marca = segundos_marca_caida
	arrow.radio_marca = radio_marca_caida


# ═══════════════════════════════════════════════════════════════════════════════
# DAÑO Y MUERTE (Con hundimiento y disolución del pilar)
# ═══════════════════════════════════════════════════════════════════════════════

func take_damage(amount: float) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	if _is_invulnerable and amount < 900.0:
		return

	health -= int(amount)
	_flash_red()

	if health <= 0:
		if _tween_subida and _tween_subida.is_valid():
			_tween_subida.kill()
			_tween_subida = null
		_change_state(State.DYING)
	else:
		_is_taking_damage = true
		_is_shooting = false
		_apuntar_arriba = false
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
	_apuntar_arriba = false
	_ocultar_flecha_mano()
	_reset_spine_rotation()
	_reproducir_sonido_muerte()
	_hundir_y_disolver_pilar()
	_drop_power_up()

	super._on_state_dying()

	var rand_death: String = "MUERTE_01" if randf() < 0.5 else "MUERTE_02"
	_play_animation(rand_death)

	var anim_length: float = _get_animation_duration(rand_death)
	get_tree().create_timer(anim_length + 0.3).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_die()
	)


func _drop_power_up() -> void:
	if not power_up_explosivo_scene:
		return
	if randf() > drop_chance_flecha_explosiva:
		return
	var item := power_up_explosivo_scene.instantiate() as Node3D
	if not item:
		return
	var target_parent := get_tree().current_scene
	if target_parent:
		target_parent.add_child(item)
	elif get_parent():
		get_parent().add_child(item)
	item.global_position = global_position + Vector3(0.0, 0.5, 0.0)


func _on_pilar_destruido() -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	_pilar_fue_destruido_primero = true
	_is_invulnerable = false

	# Detener inmediatamente la subida si fue destruido en pleno ascenso
	if _tween_subida and _tween_subida.is_valid():
		_tween_subida.kill()
		_tween_subida = null

	_detener_particulas_pilar()

	# Cambiar el modelo 3D visual por PILAR_DESTRUIDO.glb
	if _instancia_pilar and is_instance_valid(_instancia_pilar) and pilar_destruido_scene:
		# Eliminar u ocultar la malla visual intacta (PILAR_LONKO)
		var mesh_old := _instancia_pilar.find_child("PILAR_LONKO", true, false)
		if mesh_old:
			mesh_old.queue_free()

		var dest_mesh := pilar_destruido_scene.instantiate() as Node3D
		if dest_mesh:
			dest_mesh.name = "PILAR_DESTRUIDO"
			_instancia_pilar.add_child(dest_mesh)

	# Al ser destruido el pilar, matar a Lonko inmediatamente
	health = 0
	_change_state(State.DYING)


func _crear_particulas_rocas_destruccion(spawn_pos: Vector3) -> void:
	var parts := GPUParticles3D.new()
	parts.name = "ParticulasRocasDestruccion"
	parts.amount = 12  ## Cantidad reducida a la mitad
	parts.lifetime = 2.5
	parts.one_shot = true
	parts.explosiveness = 0.85

	var tex := load("res://Entities/Enemigo_Lonko/PIEDRAS_NEGRAS_ DESTRUCION.png") as Texture2D

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.3, 0.1, 0.3)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 45.0
	pmat.initial_velocity_min = 2.5
	pmat.initial_velocity_max = 5.5
	pmat.gravity = Vector3(0, -11.0, 0)
	pmat.scale_min = 0.25  ## Escala reducida a la mitad
	pmat.scale_max = 0.65
	pmat.anim_offset_min = 0.0
	pmat.anim_offset_max = 1.0
	pmat.angle_min = 0.0
	pmat.angle_max = 360.0
	pmat.angular_velocity_min = -180.0
	pmat.angular_velocity_max = 180.0

	parts.process_material = pmat

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.particles_anim_h_frames = 4
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = false
	mat.render_priority = -1

	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)  ## Malla reducida a la mitad (0.35m x 0.35m)
	quad.material = mat
	parts.draw_pass_1 = quad

	var root := get_tree().current_scene
	if root:
		root.add_child(parts)
		parts.global_position = spawn_pos
		parts.emitting = true

	get_tree().create_timer(3.5).timeout.connect(func():
		if is_instance_valid(parts):
			parts.queue_free()
	)


func _reproducir_sonido_explosion(spawn_pos: Vector3) -> void:
	var stream: AudioStream = sfx_explosion_01 if randf() < 0.5 else sfx_explosion_02
	if not stream:
		return

	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = 0.0
	player.unit_size = 10.0
	player.max_distance = 50.0
	player.bus = "Master"

	var root := get_tree().current_scene
	if root:
		root.add_child(player)
		player.global_position = spawn_pos
		player.play()
		player.finished.connect(player.queue_free)
	else:
		player.queue_free()


func _hundir_y_disolver_pilar() -> void:
	if not _instancia_pilar or not is_instance_valid(_instancia_pilar):
		return

	var pilar_to_destroy := _instancia_pilar
	_instancia_pilar = null

	var target_sink_y: float = pilar_to_destroy.global_position.y - altura_pilar_offset
	# Si el pilar fue destruido por la jugadora, baja el doble de lento (3.42s en lugar de 1.71s)
	var duracion_hundir: float = 3.42 if _pilar_fue_destruido_primero else 1.2
	var ground_y: float = _base_pos_pilar.y if _base_pos_pilar != Vector3.ZERO else (global_position.y - altura_pilar_offset)

	# Si el pilar fue destruido, aplicar el efecto de bamboleo y 4 explosiones con rocas negras a lo largo del cuerpo
	if _pilar_fue_destruido_primero:
		var wobble_task := func():
			var elapsed_wobble: float = 0.0
			while elapsed_wobble < duracion_hundir:
				if not is_instance_valid(pilar_to_destroy):
					return
				var angle: float = sin(elapsed_wobble * 15.0) * 0.63  # Mismo bamboleo sutil (±0.63°, frec 15.0)
				pilar_to_destroy.rotation_degrees.z = angle
				await get_tree().create_timer(0.02).timeout
				elapsed_wobble += 0.02
			if is_instance_valid(pilar_to_destroy):
				pilar_to_destroy.rotation_degrees.z = 0.0
		wobble_task.call()

		# Instanciar 4 explosiones (25% más pequeñas) + rocas negras (PIEDRAS_NEGRAS_ DESTRUCION.png) + SFX a lo largo del cuerpo
		var exp_task := func():
			var root_scene := get_tree().current_scene
			if not root_scene or not explocion_pilar_scene:
				return

			var alturas_relativas: Array[float] = [0.80, 0.58, 0.36, 0.14]
			for i in range(4):
				if not is_instance_valid(pilar_to_destroy):
					return
				var exp_node := explocion_pilar_scene.instantiate() as Node3D
				if exp_node:
					root_scene.add_child(exp_node)
					exp_node.scale = Vector3(0.75, 0.75, 0.75)  ## Explosiones 25% más pequeñas
					var exp_y: float = pilar_to_destroy.global_position.y + (altura_pilar_offset * alturas_relativas[i])
					var rand_offset := Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
					var spawn_p: Vector3 = Vector3(pilar_to_destroy.global_position.x, exp_y, pilar_to_destroy.global_position.z) + rand_offset
					exp_node.global_position = spawn_p

					# Ráfaga de rocas negras y sonido de explosión
					_crear_particulas_rocas_destruccion(spawn_p)
					_reproducir_sonido_explosion(spawn_p)

					get_tree().create_timer(1.2).timeout.connect(func():
						if is_instance_valid(exp_node):
							exp_node.queue_free()
					)
				await get_tree().create_timer(0.70).timeout
		exp_task.call()

	# 1. Aplicar shader de disolución SOLO cuando Lonko muere primero (el pilar destruido NO se disuelve)
	var materials: Array[ShaderMaterial] = []
	if not _pilar_fue_destruido_primero:
		var dissolve_shader := load("res://System/Shaders/dissolve.gdshader") as Shader
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
					tex = tex_pilar_normal

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

	# 2. Hundir el pilar: tween ligado AL PROPIO PILAR (sobrevive a la Lonko).
	# Si estuviera ligado a la Lonko y ella se liberara antes (su animación de
	# muerte + disolución pueden terminar antes del hundimiento), el tween
	# moriría y el pilar quedaría flotando e indestructible.
	var tween_pilar := pilar_to_destroy.create_tween()
	tween_pilar.set_parallel(true)
	tween_pilar.tween_property(pilar_to_destroy, "global_position:y", target_sink_y, duracion_hundir) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if not materials.is_empty():
		var update_dissolve := func(val: float):
			for mat in materials:
				if is_instance_valid(mat):
					mat.set_shader_parameter("dissolve_amount", val)
		tween_pilar.tween_method(update_dissolve, 0.0, 1.0, duracion_hundir)

	tween_pilar.chain().tween_callback(pilar_to_destroy.queue_free)

	# Caída de la Lonko al suelo: tween cosmético ligado a ella (muere con ella)
	var tween_lonko := create_tween()
	tween_lonko.tween_property(self, "global_position:y", ground_y, duracion_hundir) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# ═══════════════════════════════════════════════════════════════════════════════
# SONIDO
# ═══════════════════════════════════════════════════════════════════════════════

func _reproducir_sonido_pilar() -> void:
	if not sfx_pilar_stream:
		return
	var player := AudioStreamPlayer.new()
	player.add_to_group("pausable_audio")
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


func _reproducir_sonido_cargando_sp() -> void:
	if not sfx_cargando_sp_stream:
		return
	var player := AudioStreamPlayer.new()
	player.add_to_group("pausable_audio")
	player.stream = sfx_cargando_sp_stream
	player.volume_db = -12.0  # Volumen reducido un 50% adicional (-12 dB)
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
	player.add_to_group("pausable_audio")
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
	player.add_to_group("pausable_audio")
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
