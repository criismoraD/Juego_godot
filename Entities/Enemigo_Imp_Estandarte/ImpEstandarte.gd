class_name ImpEstandarte
extends EnemyBase

const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")

## Imp con estandarte para el Nivel 0 (modo pacifista).
## Usa su propio set de animaciones IMP_* y dispara flechas (arco),
## en lugar del tridente del Imp normal.
@export_category("Combate - Imp Estandarte")
@export var intervalo_disparo_arco: float = 0.0
@export var tiempo_disparo_en_animacion_arco: float = 3.1
@export var tiempo_tensa_arco: float = 1.9
@export_range(15.0, 40.0, 0.1) var velocidad_flecha_arco_min: float = 15.0
@export_range(15.0, 40.0, 0.1) var velocidad_flecha_arco_max: float = 20.0
@export var distancia_escala_velocidad_min: float = 5.0
@export var distancia_escala_velocidad_max: float = 15.0
@export_range(0.0, 0.5, 0.05) var variacion_velocidad_arco: float = 0.20
@export_range(0.25, 5.0, 0.05) var multiplicador_cadencia_arco: float = 1.0
@export var elevacion_disparo_arco: float = 0.18
@export var espera_idle_arco_min: float = 0.08
@export var espera_idle_arco_max: float = 0.18
@export_category("Proyectil - Imp Estandarte")
@export var escala_proyectil_estandarte: float = 1.8
@export var color_proyectil_estandarte: Color = Color(1.0, 0.06, 0.03, 1.0)
@export_category("Visual - Estandarte")
@export var soltar_estandarte_al_atacar: bool = false
@export var impulso_caida_estandarte: float = 0.08
@export var torque_caida_estandarte: float = 0.01
@export var tiempo_autodestruir_estandarte: float = 8.0
@export var escala_gravedad_caida: float = 0.25
@export var amortiguacion_lineal_caida: float = 2.5
@export_category("Visual - Flecha en Mano")
@export var mostrar_flecha_en_mano: bool = true
@export var offset_flecha_mano: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var rotacion_flecha_mano_grados: Vector3 = Vector3(90.0, 0.0, 0.0)
@export var escala_flecha_mano: Vector3 = Vector3(1.0, 1.0, 1.0)
@export_category("Daño - Imp Estandarte")
@export var usar_animacion_hit: bool = true
@export var volumen_hit_imp_db: float = -7.0
@export_category("Muerte - Imp Estandarte")
@export var tiempo_antes_disolver: float = 1.8
@export var escala_sangre_min: float = 0.015  ## Escala mínima de las partículas de sangre al morir
@export var escala_sangre_max: float = 0.03   ## Escala máxima de las partículas de sangre al morir
var escena_flecha_estandarte = preload("res://Entities/Proyectil_Flecha_Imp_Estandarte/ImpEstandarteArrow.tscn")
var escena_flecha_visual_mano = preload("res://Entities/Proyectil_Flecha_Imp_Estandarte/ImpEstandarteArrow.tscn")
var escena_estandarte_caido = preload("res://Entities/Ambiente_Estandarte/Estandarte.tscn")
var sonido_muerte_estandarte: AudioStreamMP3 = preload(
	"res://Entities/Enemigo_Imp_Estandarte/IMP_ESTANDARTE_MUERTE.mp3"
)
var en_animacion_disparo: bool = false
var disparo_realizado_en_ciclo: bool = false
var timer_animacion_disparo: float = 0.0
var duracion_animacion_disparo: float = 1.0
var hit_en_proceso: bool = false
var espera_entrada_disparo: float = 0.0
var estandarte_visual: Node3D = null
var arco_visual: Node3D = null
var estandarte_ya_soltado: bool = false
var attachment_flecha_mano: BoneAttachment3D = null
var flecha_visual_mano: Node3D = null
var escala_original_flecha_mano: Vector3 = Vector3.ONE
var escala_original_global_flecha_mano: Vector3 = Vector3.ONE


func _on_enemy_ready():
	# Configuración base del Imp (sin usar lógica de tridente)
	color_borde_disolucion = Color(0.7, 0.0, 0.0)
	rastrear_jugador = true

	# Restaurar materiales originales del casco y estandarte
	_restaurar_materiales_accesorios()
	_cachear_visuales_arma()
	_configurar_flecha_visual_mano()
	estandarte_ya_soltado = false
	_actualizar_visual_arma(false)
	_actualizar_visibilidad_flecha_mano(false)

	_play_animation("IMP_IDLE")


func _process(delta):
	super._process(delta)
	if current_state == State.SHOOTING and rastrear_jugador:
		_track_player()


func _on_state_walking():
	_actualizar_visual_arma(false)
	_actualizar_visibilidad_flecha_mano(false)
	_play_animation("IMP_IDLE")


func _on_pacifico_detenido():
	_actualizar_visual_arma(false)
	_actualizar_visibilidad_flecha_mano(false)
	_play_animation("IMP_IDLE_001")


func _process_walking(delta):
	if hit_en_proceso:
		velocity.x = 0
		return
	super._process_walking(delta)


func _on_state_shooting():
	if soltar_estandarte_al_atacar and not estandarte_ya_soltado:
		_soltar_estandarte_fisico()
		estandarte_ya_soltado = true

	_actualizar_visual_arma(true)
	en_animacion_disparo = false
	disparo_realizado_en_ciclo = false
	timer_animacion_disparo = 0.0
	duracion_animacion_disparo = max(
		0.05, _get_animation_duration("IMP_DISPARO") / _obtener_multiplicador_cadencia()
	)
	shoot_timer = 0.0
	espera_entrada_disparo = 0.0
	_actualizar_visibilidad_flecha_mano(false)
	_iniciar_ciclo_disparo()


func _process_shooting(delta):
	velocity.x = 0

	if rastrear_jugador:
		_track_player()

	if hit_en_proceso:
		return

	if not en_animacion_disparo:
		if espera_entrada_disparo > 0.0:
			espera_entrada_disparo -= delta
			if espera_entrada_disparo <= 0.0:
				_iniciar_ciclo_disparo()
			return

		if shoot_timer > 0.0:
			shoot_timer -= delta
			if shoot_timer <= 0.0:
				_iniciar_ciclo_disparo()
			return

		_iniciar_ciclo_disparo()
		return

	timer_animacion_disparo += delta
	_actualizar_flecha_mano_durante_animacion()
	var tiempo_disparo_efectivo = clamp(
		tiempo_disparo_en_animacion_arco / _obtener_multiplicador_cadencia(),
		0.0,
		duracion_animacion_disparo
	)

	if not disparo_realizado_en_ciclo and timer_animacion_disparo >= tiempo_disparo_efectivo:
		_throw_projectile()
		disparo_realizado_en_ciclo = true

	if timer_animacion_disparo >= duracion_animacion_disparo:
		if not disparo_realizado_en_ciclo:
			_throw_projectile()
			disparo_realizado_en_ciclo = true

		en_animacion_disparo = false
		_actualizar_visibilidad_flecha_mano(false)
		if intervalo_disparo_arco > 0.0:
			shoot_timer = intervalo_disparo_arco / _obtener_multiplicador_cadencia()
		else:
			_iniciar_ciclo_disparo()


func _iniciar_ciclo_disparo():
	var cadencia_actual: float = _obtener_multiplicador_cadencia()
	en_animacion_disparo = true
	disparo_realizado_en_ciclo = false
	timer_animacion_disparo = 0.0
	duracion_animacion_disparo = max(0.05, _get_animation_duration("IMP_DISPARO") / cadencia_actual)
	_actualizar_visibilidad_flecha_mano(false)
	_play_animation("IMP_DISPARO", -1.0, cadencia_actual)


func _obtener_multiplicador_cadencia() -> float:
	return max(0.25, multiplicador_cadencia_arco)


func _throw_projectile():
	if not escena_flecha_estandarte:
		return

	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return

	if player_ref.get("is_dead"):
		return

	AudioManager.play_sfx("goblin_girl_shoot")

	var flecha := PROJECTILE_POOL_REF.acquire(escena_flecha_estandarte) as ImpEstandarteArrowProjectile
	if not flecha:
		return

	var spawn_pos: Vector3
	if flecha_visual_mano and is_instance_valid(flecha_visual_mano):
		spawn_pos = flecha_visual_mano.global_position
	else:
		spawn_pos = global_position + Vector3(-0.3, altura_spawn_flecha, 0)
	var target_pos = player_ref.global_position + Vector3(0, 0.5, 0)
	var direction = (target_pos - spawn_pos).normalized()
	direction.y += elevacion_disparo_arco
	direction = direction.normalized()

	flecha.color_proyectil = color_proyectil_estandarte

	flecha.scale = escala_original_global_flecha_mano
	var dist_x: float = abs(player_ref.global_position.x - global_position.x)
	var t: float = 0.0
	var rango_dist: float = distancia_escala_velocidad_max - distancia_escala_velocidad_min
	if rango_dist > 0.0:
		t = clampf((dist_x - distancia_escala_velocidad_min) / rango_dist, 0.0, 1.0)
	
	var velocidad_minima: float = min(velocidad_flecha_arco_min, velocidad_flecha_arco_max)
	var velocidad_maxima: float = max(velocidad_flecha_arco_min, velocidad_flecha_arco_max)
	var velocidad_base: float = lerp(velocidad_minima, velocidad_maxima, t)
	var velocidad_final: float = velocidad_base * randf_range(1.0 - variacion_velocidad_arco, 1.0 + variacion_velocidad_arco)

	flecha.initialize(direction, 1.0)
	flecha.velocidad = velocidad_final

	# Cuando la flecha sale despedida, ocultamos la flecha visual de la mano.
	_actualizar_visibilidad_flecha_mano(false)

	PROJECTILE_POOL_REF.activate(flecha, get_tree().root, spawn_pos)


func _on_state_dying():
	# Base de EnemyBase: desactivar física/colisiones
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

	_reproducir_sonido_muerte_estandarte()
	AudioManager.play_sfx("explosion_muerte")
	_actualizar_visual_arma(true)
	_actualizar_visibilidad_flecha_mano(false)

	var anim_length = _get_animation_duration("IMP_MUERTE")
	_play_animation("IMP_MUERTE")
	_crear_explosion_sangre()

	var tiempo_total = max(anim_length, tiempo_antes_disolver)
	get_tree().create_timer(tiempo_total).timeout.connect(_on_death_timer_timeout)


func _on_death_timer_timeout() -> void:
	if is_inside_tree():
		_die()


func _reproducir_sonido_muerte_estandarte():
	if not sonido_muerte_estandarte:
		AudioManager.play_sfx("imp_death")
		return

	var temp_player := AudioStreamPlayer.new()
	temp_player.stream = sonido_muerte_estandarte
	temp_player.volume_db = -2.0
	temp_player.bus = "Master"
	add_child(temp_player)
	temp_player.play()
	temp_player.finished.connect(
		func():
			if is_instance_valid(temp_player):
				temp_player.queue_free()
	)


func take_damage(amount: float):
	if current_state == State.DYING or current_state == State.DEAD:
		return

	# Ocultar la flecha de la mano inmediatamente si es dañado o muere
	en_animacion_disparo = false
	_actualizar_visibilidad_flecha_mano(false)

	if not estandarte_ya_soltado:
		_soltar_estandarte_fisico()
		estandarte_ya_soltado = true
		_actualizar_visual_arma(current_state == State.SHOOTING)

	super.take_damage(amount)

	if current_state != State.DYING and current_state != State.DEAD:
		_flash_red()
		if usar_animacion_hit:
			_reproducir_hit_aleatorio()
		# Reusar sonido del imp normal en daño (atenuado para no saturar)
		AudioManager.play_sfx("imp_death", volumen_hit_imp_db)


func _desaparecer_estandarte_con_particulas() -> void:
	if not estandarte_ya_soltado:
		_soltar_estandarte_fisico()
		estandarte_ya_soltado = true
		_actualizar_visual_arma(current_state == State.SHOOTING)


func _reproducir_hit_aleatorio():
	if hit_en_proceso:
		return
	hit_en_proceso = true

	var hits = ["IMP_HIT_01", "IMP_HIT_02", "IMP_HIT_03"]
	var anim_hit: String = hits[randi() % hits.size()]
	_play_animation(anim_hit)

	var dur_hit = _get_animation_duration(anim_hit)
	get_tree().create_timer(max(0.15, dur_hit)).timeout.connect(_on_hit_timer_timeout)


func _on_hit_timer_timeout() -> void:
	hit_en_proceso = false
	if current_state == State.DYING or current_state == State.DEAD:
		return
	if current_state == State.WALKING:
		_on_state_walking()
	elif current_state == State.SHOOTING:
		espera_entrada_disparo = 0.0
		shoot_timer = 0.0
		_iniciar_ciclo_disparo()


func _crear_explosion_sangre():
	var particles := GPUParticles3D.new()
	particles.name = "BloodExplosion"
	particles.amount = 15
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.5
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 0.2
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 2.0
	process_mat.initial_velocity_max = 5.0
	process_mat.gravity = Vector3(0, -6.0, 0)
	process_mat.damping_min = 1.0
	process_mat.damping_max = 3.0
	process_mat.scale_min = escala_sangre_min
	process_mat.scale_max = escala_sangre_max

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.7, 0.0, 0.0, 1.0))
	gradient.add_point(0.3, Color(0.5, 0.0, 0.0, 0.9))
	gradient.set_color(1, Color(0.2, 0.0, 0.0, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	particles.process_material = process_mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.025
	sphere.height = 0.05
	var blood_mat := StandardMaterial3D.new()
	blood_mat.albedo_color = Color(0.6, 0.0, 0.0)
	blood_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	blood_mat.emission_enabled = true
	blood_mat.emission = Color(0.5, 0.0, 0.0)
	blood_mat.emission_energy_multiplier = 1.5
	blood_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = blood_mat
	particles.draw_pass_1 = sphere

	add_child(particles)
	var bone_pos = _get_hips_global_position()
	if bone_pos != Vector3.ZERO:
		particles.global_position = bone_pos
	else:
		particles.position = Vector3(0, 0.3, 0)
	particles.emitting = true

	var gpos = particles.global_position
	remove_child(particles)
	get_tree().root.add_child(particles)
	particles.global_position = gpos

	get_tree().create_timer(2.0).timeout.connect(
		func():
			if is_instance_valid(particles) and particles.is_inside_tree():
				particles.queue_free()
	)


func _cachear_visuales_arma():
	estandarte_visual = find_child("Estandarte", true, false) as Node3D
	arco_visual = find_child("ArcoCombate", true, false) as Node3D
	if not arco_visual:
		arco_visual = find_child("ARCO_GOBLING_GIRL", true, false) as Node3D


func _configurar_flecha_visual_mano():
	# ── 1. Buscar una "FlechaMano" ya colocada manualmente en la escena ──
	flecha_visual_mano = find_child("FlechaMano", true, false) as Node3D
	if flecha_visual_mano:
		flecha_visual_mano.visible = false
		escala_original_flecha_mano = flecha_visual_mano.scale
		# Incrementado en un 25% según solicitud del usuario
		escala_original_global_flecha_mano = (flecha_visual_mano.global_transform.basis.get_scale() * 1.25).abs()
		return

	# ── 2. Si no existe, crearla programáticamente como fallback ──
	if not mostrar_flecha_en_mano:
		return

	var esqueleto_nodo: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D
	if not esqueleto_nodo:
		push_warning("[ImpEstandarte] No se encontró Skeleton3D para crear FlechaMano")
		return

	var nombre_hueso: String = _obtener_hueso_mano(esqueleto_nodo)
	if nombre_hueso.is_empty():
		push_warning("[ImpEstandarte] No se encontró hueso de mano en el esqueleto")
		return

	attachment_flecha_mano = BoneAttachment3D.new()
	attachment_flecha_mano.name = "AttachmentFlechaMano"
	esqueleto_nodo.add_child(attachment_flecha_mano)
	attachment_flecha_mano.bone_name = nombre_hueso

	flecha_visual_mano = _crear_visual_flecha_mano()
	attachment_flecha_mano.add_child(flecha_visual_mano)

	flecha_visual_mano.position = offset_flecha_mano
	flecha_visual_mano.rotation_degrees = rotacion_flecha_mano_grados
	flecha_visual_mano.scale = escala_flecha_mano
	# Forzar actualización de transform para que calcule la escala global
	flecha_visual_mano.force_update_transform()
	escala_original_flecha_mano = escala_flecha_mano
	# Incrementado en un 25% según solicitud del usuario
	escala_original_global_flecha_mano = (flecha_visual_mano.global_transform.basis.get_scale() * 1.25).abs()
	flecha_visual_mano.visible = false


func _crear_visual_flecha_mano() -> Node3D:
	if escena_flecha_visual_mano:
		var instancia_visual := escena_flecha_visual_mano.instantiate() as Node3D
		if instancia_visual:
			instancia_visual.name = "FlechaMano"
			return instancia_visual
	return null





func _obtener_hueso_mano(esqueleto_nodo: Skeleton3D) -> String:
	var candidatos := ["mixamorig_LeftHand", "mixamorig_RightHand", "LeftHand", "RightHand", "Hand_L", "Hand_R"]

	for nombre in candidatos:
		if esqueleto_nodo.find_bone(nombre) != -1:
			return nombre

	return ""


func _actualizar_flecha_mano_durante_animacion():
	if not en_animacion_disparo or not flecha_visual_mano or not is_instance_valid(flecha_visual_mano):
		return

	var multiplicador: float = _obtener_multiplicador_cadencia()
	var anim_time_scaled: float = timer_animacion_disparo * multiplicador
	var tiempo_tensa: float = tiempo_tensa_arco
	var tiempo_disparo: float = tiempo_disparo_en_animacion_arco

	# Mostrar la flecha durante la fase de tensión del arco
	if anim_time_scaled >= tiempo_tensa and anim_time_scaled < tiempo_disparo and not disparo_realizado_en_ciclo:
		flecha_visual_mano.visible = true
		
		# Animación de escala: de 0.01 a 1.0 (de la escala del proyectil disparado)
		var duracion_tensa: float = tiempo_disparo - tiempo_tensa
		var t: float = 0.0
		if duracion_tensa > 0.0:
			t = clampf((anim_time_scaled - tiempo_tensa) / duracion_tensa, 0.0, 1.0)
		
		# Efecto juice: curva easeOutBack
		var t_eased: float = _ease_out_back(t)
		
		var target_scale: Vector3 = escala_original_global_flecha_mano * lerp(0.01, 1.0, t_eased)
		var trans: Transform3D = flecha_visual_mano.global_transform
		trans.basis = trans.basis.orthonormalized().scaled(target_scale)
		flecha_visual_mano.global_transform = trans
		
		# Efecto juice: vibración/temblor por tensión al final del tensado (t > 0.8)
		if t > 0.8:
			var shake_intensity: float = (t - 0.8) * 0.012
			flecha_visual_mano.position = offset_flecha_mano + Vector3(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)
		else:
			flecha_visual_mano.position = offset_flecha_mano
	else:
		flecha_visual_mano.visible = false
		flecha_visual_mano.position = offset_flecha_mano


func _ease_out_back(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func _actualizar_visibilidad_flecha_mano(visible_flecha: bool):
	if not flecha_visual_mano or not is_instance_valid(flecha_visual_mano):
		return

	flecha_visual_mano.visible = visible_flecha and mostrar_flecha_en_mano


func _actualizar_visual_arma(usando_arco: bool):
	if estandarte_visual and is_instance_valid(estandarte_visual):
		estandarte_visual.visible = (not usando_arco) and (not estandarte_ya_soltado)
	if arco_visual and is_instance_valid(arco_visual):
		arco_visual.visible = usando_arco


func _soltar_estandarte_fisico():
	if not estandarte_visual or not is_instance_valid(estandarte_visual):
		return

	# Buscar el esqueleto y el BoneAttachment3D subiendo por el árbol de padres
	var skel_ref = estandarte_visual.get_parent()
	var attachment: BoneAttachment3D = null
	while skel_ref and not skel_ref is Skeleton3D:
		if skel_ref is BoneAttachment3D:
			attachment = skel_ref
		skel_ref = skel_ref.get_parent()

	var escena_actual = get_tree().current_scene
	if not escena_actual:
		return

	var transform_global_estandarte: Transform3D = estandarte_visual.global_transform
	if skel_ref and attachment:
		var bone_name_str: String = attachment.bone_name
		var bone_idx: int = (skel_ref as Skeleton3D).find_bone(bone_name_str)
		if bone_idx != -1:
			(skel_ref as Skeleton3D).force_update_all_bone_transforms()
			var bone_global_pose: Transform3D = (skel_ref as Skeleton3D).global_transform * (skel_ref as Skeleton3D).get_bone_global_pose(bone_idx)
			transform_global_estandarte = bone_global_pose * estandarte_visual.transform
	else:
		estandarte_visual.force_update_transform()

	# Usar valores absolutos de la escala para evitar dimensiones negativas en BoxShape3D
	var escala_global := transform_global_estandarte.basis.get_scale().abs()

	# Crear el RigidBody3D con escala (1, 1, 1) para evitar errores del motor de física
	var cuerpo_caida := RigidBody3D.new()
	cuerpo_caida.name = "EstandarteCaido"
	cuerpo_caida.mass = 0.5
	cuerpo_caida.gravity_scale = escala_gravedad_caida
	cuerpo_caida.linear_damp = amortiguacion_lineal_caida
	cuerpo_caida.angular_damp = 4.0
	cuerpo_caida.collision_layer = 0
	cuerpo_caida.collision_mask = 1
	# Habilitar Continuous Collision Detection (CCD) para evitar que atraviese el suelo
	cuerpo_caida.continuous_cd = true
	# Configurar reporte de colisiones para detectar el impacto contra el suelo
	cuerpo_caida.contact_monitor = true
	cuerpo_caida.max_contacts_reported = 3

	# Configurar el transform sin escala (normalizado) antes de añadir al árbol
	var transform_body := transform_global_estandarte
	transform_body.basis = transform_body.basis.orthonormalized()
	cuerpo_caida.global_transform = transform_body

	var visual_caida: Node3D = null
	if escena_estandarte_caido:
		visual_caida = escena_estandarte_caido.instantiate() as Node3D

	if visual_caida:
		_desactivar_colisiones_visual_caida(visual_caida)
		cuerpo_caida.add_child(visual_caida)
		# Aplicamos la escala real únicamente al nodo visual
		visual_caida.scale = escala_global

	# Buscar y reparentar la colisión del visual al cuerpo rígido (antes de añadir al árbol)
	var colision: CollisionShape3D = null
	if visual_caida:
		colision = visual_caida.find_child("CollisionShape3D", true, false) as CollisionShape3D

	if colision:
		# Calcular transform local relativo a cuerpo_caida
		var local_trans := visual_caida.transform * colision.transform
		# Limpiar el owner antes de reparentar para evitar inconsistencias
		colision.owner = null
		colision.get_parent().remove_child(colision)
		cuerpo_caida.add_child(colision)
		
		# Asignar posición y rotación (sin escala para evitar bugs de física en Godot)
		colision.position = local_trans.origin
		colision.transform.basis = Basis(local_trans.basis.get_rotation_quaternion())
		
		# Aplicar la escala directamente al recurso Shape de la colisión para evitar bugs de física
		_aplicar_escala_a_forma_de_colision(colision, escala_global)
	else:
		# Fallback programático si por alguna razón no tiene colisión en la escena
		colision = CollisionShape3D.new()
		var forma := CapsuleShape3D.new()
		forma.radius = 0.12 * escala_global.y
		forma.height = 2.0 * escala_global.y
		colision.shape = forma
		colision.position.y = 1.0 * escala_global.y
		cuerpo_caida.add_child(colision)

	# Conectar señal para detectar la caída y el desvanecimiento 1 segundo después de tocar el suelo
	cuerpo_caida.body_entered.connect(_on_estandarte_caido_contacto.bind(cuerpo_caida, visual_caida))

	# Agregar excepciones para evitar colisiones indeseadas con personajes
	cuerpo_caida.add_collision_exception_with(self)
	
	# Añadimos al árbol de la escena activa
	escena_actual.add_child(cuerpo_caida)
	_agregar_excepciones_personajes_estandarte(cuerpo_caida)

	# Asignar la velocidad actual (inercia) del enemigo
	cuerpo_caida.linear_velocity = velocity

	# Aplicamos el impulso inicial (caída natural, hacia adelante y levemente hacia arriba)
	var direccion_impulso := Vector3(-1.0, 0.1, 0.0).normalized()
	cuerpo_caida.apply_central_impulse(direccion_impulso * impulso_caida_estandarte)

	if torque_caida_estandarte > 0.0:
		var torque := Vector3(0.0, 0.0, torque_caida_estandarte)
		cuerpo_caida.apply_torque_impulse(torque)


	# Temporizador de seguridad por si cae fuera de límites o no colisiona
	if tiempo_autodestruir_estandarte > 0.0:
		var tiempo_espera = max(0.05, tiempo_autodestruir_estandarte - 0.4)
		var timer = get_tree().create_timer(tiempo_espera)
		timer.timeout.connect(_on_safety_timer_timeout.bind(cuerpo_caida, visual_caida))


func _on_safety_timer_timeout(cuerpo_caida, visual_caida) -> void:
	if is_instance_valid(cuerpo_caida) and not cuerpo_caida.has_meta("landed"):
		_desvanecer_y_destruir_cuerpo(cuerpo_caida, visual_caida)


func _desvanecer_y_destruir_cuerpo(cuerpo, visual):
	if not is_instance_valid(cuerpo) or not is_instance_valid(visual):
		return

	# Buscar las mallas del estandarte para aplicarles el shader de disolución
	var palo = visual.find_child("PALO", true, false) as MeshInstance3D
	var tela = visual.find_child("TELA", true, false) as MeshInstance3D

	var shaders_creados: Array[ShaderMaterial] = []

	for mesh in [palo, tela]:
		if not mesh or not is_instance_valid(mesh):
			continue
		
		var mat_dissolve := ShaderMaterial.new()
		mat_dissolve.shader = dissolve_shader
		mat_dissolve.set_shader_parameter("dissolve_amount", 0.0)
		mat_dissolve.set_shader_parameter("glow_color", color_borde_disolucion)
		mat_dissolve.set_shader_parameter("glow_intensity", intensidad_emision)
		mat_dissolve.set_shader_parameter("edge_thickness", 0.05)
		mat_dissolve.set_shader_parameter("noise_scale", 20.0)

		var original_mat = mesh.get_surface_override_material(0)
		if original_mat == null and mesh.mesh:
			original_mat = mesh.mesh.surface_get_material(0)

		if original_mat:
			var tex = null
			var col = Color(1.0, 1.0, 1.0, 1.0)
			if original_mat is StandardMaterial3D:
				tex = original_mat.albedo_texture
				col = original_mat.albedo_color
			elif original_mat is ShaderMaterial:
				tex = original_mat.get_shader_parameter("albedo_texture")
				var c = original_mat.get_shader_parameter("albedo_color")
				if c is Color:
					col = c
			
			if tex:
				mat_dissolve.set_shader_parameter("albedo_texture", tex)
			mat_dissolve.set_shader_parameter("albedo_tint", Vector3(col.r, col.g, col.b))

		mesh.material_override = mat_dissolve
		shaders_creados.append(mat_dissolve)

	# Función de interpolación del shader de disolución
	var actualizar_disolucion_fn := func(value: float):
		for mat in shaders_creados:
			if is_instance_valid(mat):
				mat.set_shader_parameter("dissolve_amount", value)

	# Crear Tween en el cuerpo físico (no en el visual) para evitar null cuando self sea liberado
	var tween = cuerpo.create_tween()
	tween.tween_method(actualizar_disolucion_fn, 0.0, 1.0, duracion_disolucion)

	# Callback de finalización: guardar referencia local para evitar lambda captures liberados
	var cuerpo_ref: RigidBody3D = cuerpo
	var al_terminar_fn := func():
		if is_instance_valid(cuerpo_ref):
			cuerpo_ref.queue_free()

	tween.tween_callback(al_terminar_fn)



func _aplicar_escala_a_forma_de_colision(colision_node: CollisionShape3D, escala: Vector3):
	if not colision_node or not colision_node.shape:
		return

	# Duplicar el recurso de la forma para no modificar el original de la escena
	var shape_original = colision_node.shape
	var shape_duplicada = shape_original.duplicate()
	# Usar valores absolutos para evitar dimensiones negativas
	var escala_abs := escala.abs()

	if shape_duplicada is BoxShape3D:
		var box = shape_duplicada as BoxShape3D
		box.size = box.size * escala_abs
	elif shape_duplicada is CapsuleShape3D:
		var capsule = shape_duplicada as CapsuleShape3D
		capsule.radius = capsule.radius * escala_abs.x
		capsule.height = capsule.height * escala_abs.y
	elif shape_duplicada is CylinderShape3D:
		var cylinder = shape_duplicada as CylinderShape3D
		cylinder.radius = cylinder.radius * escala_abs.x
		cylinder.height = cylinder.height * escala_abs.y
	elif shape_duplicada is SphereShape3D:
		var sphere = shape_duplicada as SphereShape3D
		sphere.radius = sphere.radius * escala_abs.y

	colision_node.shape = shape_duplicada



func _agregar_excepciones_personajes_estandarte(cuerpo_caida: RigidBody3D):
	if not is_instance_valid(cuerpo_caida):
		return

	var grupos = ["enemies", "player", "allies", "shield_imps"]
	for grupo in grupos:
		for nodo in get_tree().get_nodes_in_group(grupo):
			if not is_instance_valid(nodo) or nodo == self:
				continue
			if nodo is PhysicsBody3D:
				var cuerpo = nodo as PhysicsBody3D
				cuerpo_caida.add_collision_exception_with(cuerpo)
				if cuerpo.has_method("add_collision_exception_with"):
					cuerpo.add_collision_exception_with(cuerpo_caida)


func _desactivar_colisiones_visual_caida(nodo_visual: Node):
	if not nodo_visual:
		return

	var colisiones = nodo_visual.find_children("*", "CollisionObject3D", true, false)
	for colision in colisiones:
		if colision is CollisionObject3D:
			colision.collision_layer = 0
			colision.collision_mask = 0


func _restaurar_materiales_accesorios():
	# Buscar los nodos del estandarte y casco (definidos en la escena .tscn)
	var estandarte_node = find_child("Estandarte", true, false)
	var casco_node = find_child("CASCO_ESTANDARTE", true, false)

	for accesorio in [estandarte_node, casco_node]:
		if not accesorio or not is_instance_valid(accesorio):
			continue
		var meshes = accesorio.find_children("*", "MeshInstance3D", true, false)
		# Si el accesorio es un MeshInstance3D, incluirlo también
		if accesorio is MeshInstance3D:
			meshes.append(accesorio)
		for mesh in meshes:
			mesh.material_override = null  # Quitar override, usa material del GLB


func _on_estandarte_caido_contacto(_body: Node, cuerpo, visual):
	if not is_instance_valid(cuerpo) or cuerpo.has_meta("landed"):
		return
	cuerpo.set_meta("landed", true)
	
	# Desvanecer y destruir a partir de 1.0 segundo después de tocar el suelo
	get_tree().create_timer(1.0).timeout.connect(_desvanecer_y_destruir_cuerpo.bind(cuerpo, visual))
