class_name ImpEstandarte
extends EnemyBase
## Imp con estandarte para el Nivel 0 (modo pacifista).
## Usa su propio set de animaciones IMP_* y dispara flechas (arco),
## en lugar del tridente del Imp normal.
@export_category("Combate - Imp Estandarte")
@export var intervalo_disparo_arco: float = 0.0
@export var tiempo_disparo_en_animacion_arco: float = 0.55
@export_range(15.0, 40.0, 0.1) var velocidad_flecha_arco_min: float = 15.0
@export_range(15.0, 40.0, 0.1) var velocidad_flecha_arco_max: float = 20.0
@export_range(0.25, 5.0, 0.05) var multiplicador_cadencia_arco: float = 1.0
@export var elevacion_disparo_arco: float = 0.18
@export var espera_idle_arco_min: float = 0.08
@export var espera_idle_arco_max: float = 0.18
@export_category("Proyectil - Imp Estandarte")
@export var escala_proyectil_estandarte: float = 1.8
@export var color_proyectil_estandarte: Color = Color(1.0, 0.06, 0.03, 1.0)
@export_category("Visual - Estandarte")
@export var soltar_estandarte_al_atacar: bool = true
@export var impulso_caida_estandarte: float = 0.32
@export var torque_caida_estandarte: float = 0.04
@export var tiempo_autodestruir_estandarte: float = 8.0
@export_category("Visual - Flecha en Mano")
@export var mostrar_flecha_en_mano: bool = true
@export var tiempo_aparece_flecha_mano: float = 1.0
@export var tiempo_desaparece_flecha_mano: float = 3.0
@export var offset_flecha_mano: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var rotacion_flecha_mano_grados: Vector3 = Vector3(90.0, 0.0, 0.0)
@export var escala_flecha_mano: Vector3 = Vector3(1.0, 1.0, 1.0)
@export_category("Daño - Imp Estandarte")
@export var usar_animacion_hit: bool = true
@export var volumen_hit_imp_db: float = -7.0
@export_category("Muerte - Imp Estandarte")
@export var tiempo_antes_disolver: float = 1.8
var escena_flecha_estandarte = preload("res://Scenes/Projectiles/GoblinGirlArrow.tscn")
var escena_flecha_visual_mano = preload("res://Scenes/Projectiles/FlechaManoVisual.tscn")
var escena_estandarte_caido = preload("res://Assets/Environment/Estandarte/Estandarte.glb")
var sonido_muerte_estandarte: AudioStreamMP3 = preload(
	"res://Assets/Characters/IMP_ESTANDARTE/IMP_ESTANDARTE_MUERTE.mp3"
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


func _on_enemy_ready():
	# Configuración base del Imp (sin usar lógica de tridente)
	color_borde_disolucion = Color(1.0, 0.15, 0.1)
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

	var flecha = escena_flecha_estandarte.instantiate()
	var spawn_pos = global_position + Vector3(-0.3, altura_spawn_flecha, 0)
	var target_pos = player_ref.global_position + Vector3(0, 0.5, 0)
	var direction = (target_pos - spawn_pos).normalized()
	direction.y += elevacion_disparo_arco
	direction = direction.normalized()

	if "color_proyectil" in flecha:
		flecha.color_proyectil = color_proyectil_estandarte

	var escala_final: float = max(0.1, escala_proyectil_estandarte)
	flecha.scale = Vector3(escala_final, escala_final, escala_final)
	var velocidad_minima: float = min(velocidad_flecha_arco_min, velocidad_flecha_arco_max)
	var velocidad_maxima: float = max(velocidad_flecha_arco_min, velocidad_flecha_arco_max)
	var velocidad_final: float = randf_range(velocidad_minima, velocidad_maxima)

	flecha.initialize(direction, 1.0)
	if "velocidad" in flecha:
		flecha.velocidad = velocidad_final

	# Cuando la flecha sale despedida, ocultamos la flecha visual de la mano.
	_actualizar_visibilidad_flecha_mano(false)

	get_tree().root.add_child(flecha)
	flecha.global_position = spawn_pos


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
	get_tree().create_timer(tiempo_total).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_die()
	)


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


func _cargar_sonido_muerte_estandarte():
	pass


func take_damage(amount: float):
	if current_state == State.DYING or current_state == State.DEAD:
		return

	if not estandarte_ya_soltado:
		_desaparecer_estandarte_con_particulas()
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
	if not estandarte_visual or not is_instance_valid(estandarte_visual):
		return

	_crear_particulas_desaparicion_estandarte(estandarte_visual.global_position)
	estandarte_visual.queue_free()
	estandarte_visual = null


func _reproducir_hit_aleatorio():
	if hit_en_proceso:
		return
	hit_en_proceso = true

	var hits = ["IMP_HIT_01", "IMP_HIT_02", "IMP_HIT_03"]
	var anim_hit: String = hits[randi() % hits.size()]
	_play_animation(anim_hit)

	var dur_hit = _get_animation_duration(anim_hit)
	get_tree().create_timer(max(0.15, dur_hit)).timeout.connect(
		func():
			hit_en_proceso = false
			if (
				not is_instance_valid(self)
				or current_state == State.DYING
				or current_state == State.DEAD
			):
				return
			if current_state == State.WALKING:
				_on_state_walking()
			elif current_state == State.SHOOTING:
				espera_entrada_disparo = 0.0
				shoot_timer = 0.0
				_iniciar_ciclo_disparo()
	)


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
	process_mat.scale_min = 0.015
	process_mat.scale_max = 0.03

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
	if not mostrar_flecha_en_mano:
		return

	var esqueleto_nodo: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D
	if not esqueleto_nodo:
		return

	var nombre_hueso: String = _obtener_hueso_mano_derecha(esqueleto_nodo)
	if nombre_hueso.is_empty():
		return

	attachment_flecha_mano = (
		esqueleto_nodo.get_node_or_null("AttachmentFlechaMano") as BoneAttachment3D
	)
	if not attachment_flecha_mano:
		attachment_flecha_mano = BoneAttachment3D.new()
		attachment_flecha_mano.name = "AttachmentFlechaMano"
		esqueleto_nodo.add_child(attachment_flecha_mano)

	attachment_flecha_mano.bone_name = nombre_hueso
	attachment_flecha_mano.position = Vector3.ZERO
	attachment_flecha_mano.rotation = Vector3.ZERO
	attachment_flecha_mano.scale = Vector3.ONE

	flecha_visual_mano = attachment_flecha_mano.get_node_or_null("FlechaMano") as Node3D
	if not flecha_visual_mano:
		flecha_visual_mano = _crear_visual_flecha_mano()
		attachment_flecha_mano.add_child(flecha_visual_mano)

	flecha_visual_mano.position = offset_flecha_mano
	flecha_visual_mano.rotation_degrees = rotacion_flecha_mano_grados
	flecha_visual_mano.scale = escala_flecha_mano
	flecha_visual_mano.visible = false


func _crear_visual_flecha_mano() -> Node3D:
	if escena_flecha_visual_mano:
		var instancia_visual := escena_flecha_visual_mano.instantiate() as Node3D
		if instancia_visual:
			instancia_visual.name = "FlechaMano"
			return instancia_visual

	var raiz := Node3D.new()
	raiz.name = "FlechaMano"

	var material_flecha := StandardMaterial3D.new()
	material_flecha.albedo_color = color_proyectil_estandarte
	material_flecha.emission_enabled = true
	material_flecha.emission = color_proyectil_estandarte
	material_flecha.emission_energy_multiplier = 2.0
	material_flecha.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var cuerpo := MeshInstance3D.new()
	cuerpo.name = "Body"
	var mesh_cuerpo := CylinderMesh.new()
	mesh_cuerpo.top_radius = 0.015
	mesh_cuerpo.bottom_radius = 0.015
	mesh_cuerpo.height = 0.25
	mesh_cuerpo.radial_segments = 6
	mesh_cuerpo.rings = 1
	mesh_cuerpo.material = material_flecha
	cuerpo.mesh = mesh_cuerpo
	raiz.add_child(cuerpo)

	var punta := MeshInstance3D.new()
	punta.name = "Tip"
	var mesh_punta := CylinderMesh.new()
	mesh_punta.top_radius = 0.0
	mesh_punta.bottom_radius = 0.03
	mesh_punta.height = 0.08
	mesh_punta.radial_segments = 6
	mesh_punta.rings = 1
	mesh_punta.material = material_flecha
	punta.mesh = mesh_punta
	punta.position = Vector3(0.165, 0.0, 0.0)
	raiz.add_child(punta)

	return raiz


func _obtener_hueso_mano_derecha(esqueleto_nodo: Skeleton3D) -> String:
	var candidatos := ["mixamorig_RightHandIndex1", "mixamorig_RightHand", "RightHand", "Hand_R"]

	for nombre in candidatos:
		if esqueleto_nodo.find_bone(nombre) != -1:
			return nombre

	return ""


func _actualizar_flecha_mano_durante_animacion():
	if not en_animacion_disparo:
		_actualizar_visibilidad_flecha_mano(false)
		return

	var multiplicador := _obtener_multiplicador_cadencia()
	var tiempo_aparece: float = max(0.0, tiempo_aparece_flecha_mano / multiplicador)
	var tiempo_desaparece: float = max(
		tiempo_aparece, tiempo_desaparece_flecha_mano / multiplicador
	)
	var visible_en_ventana: bool = (
		timer_animacion_disparo >= tiempo_aparece and timer_animacion_disparo < tiempo_desaparece
	)

	_actualizar_visibilidad_flecha_mano(visible_en_ventana and not disparo_realizado_en_ciclo)


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

	var escena_actual = get_tree().current_scene
	if not escena_actual:
		return

	var cuerpo_caida := RigidBody3D.new()
	cuerpo_caida.name = "EstandarteCaido"
	cuerpo_caida.mass = 1.2
	cuerpo_caida.gravity_scale = 3.4
	cuerpo_caida.linear_damp = 0.02
	cuerpo_caida.angular_damp = 3.0
	cuerpo_caida.collision_layer = 0
	cuerpo_caida.collision_mask = 1
	cuerpo_caida.add_collision_exception_with(self)

	var colision := CollisionShape3D.new()
	var forma := CapsuleShape3D.new()
	forma.radius = 0.6
	forma.height = 1.2
	colision.shape = forma
	cuerpo_caida.add_child(colision)

	var visual_caida: Node3D = null
	if escena_estandarte_caido:
		visual_caida = escena_estandarte_caido.instantiate() as Node3D

	if visual_caida:
		_desactivar_colisiones_visual_caida(visual_caida)
		cuerpo_caida.add_child(visual_caida)

	var transform_global_estandarte := estandarte_visual.global_transform
	escena_actual.add_child(cuerpo_caida)
	_agregar_excepciones_personajes_estandarte(cuerpo_caida)
	cuerpo_caida.global_transform = transform_global_estandarte

	var direccion_impulso := Vector3(-0.22, -0.98, 0.0).normalized()
	cuerpo_caida.apply_central_impulse(direccion_impulso * impulso_caida_estandarte)

	if torque_caida_estandarte > 0.0:
		var torque := Vector3(0.0, 0.0, torque_caida_estandarte)
		cuerpo_caida.apply_torque_impulse(torque)

	if tiempo_autodestruir_estandarte > 0.0:
		get_tree().create_timer(tiempo_autodestruir_estandarte).timeout.connect(
			func():
				if is_instance_valid(cuerpo_caida):
					_crear_particulas_desaparicion_estandarte(cuerpo_caida.global_position)
					cuerpo_caida.queue_free()
		)


func _crear_particulas_desaparicion_estandarte(posicion_global: Vector3):
	var particulas := GPUParticles3D.new()
	particulas.name = "EstandarteDesaparece"
	particulas.amount = 15
	particulas.lifetime = 1.05
	particulas.one_shot = true
	particulas.explosiveness = 1.0
	particulas.randomness = 0.4
	particulas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var proceso := ParticleProcessMaterial.new()
	proceso.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proceso.emission_sphere_radius = 0.18
	proceso.direction = Vector3(0, 1, 0)
	proceso.spread = 180.0
	proceso.initial_velocity_min = 0.55
	proceso.initial_velocity_max = 1.6
	proceso.gravity = Vector3(0, -0.7, 0)
	proceso.scale_min = 0.01125
	proceso.scale_max = 0.0225

	var gradiente := Gradient.new()
	gradiente.set_color(0, color_borde_disolucion)
	gradiente.set_color(
		1, Color(color_borde_disolucion.r, color_borde_disolucion.g, color_borde_disolucion.b, 0.0)
	)
	var textura_gradiente := GradientTexture1D.new()
	textura_gradiente.gradient = gradiente
	proceso.color_ramp = textura_gradiente

	particulas.process_material = proceso

	var esfera := SphereMesh.new()
	esfera.radius = 0.025
	esfera.height = 0.05
	var material_particula := StandardMaterial3D.new()
	material_particula.albedo_color = color_borde_disolucion
	material_particula.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material_particula.emission_enabled = true
	material_particula.emission = color_borde_disolucion
	material_particula.emission_energy_multiplier = intensidad_emision * 0.5
	material_particula.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_particula.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	esfera.material = material_particula
	particulas.draw_pass_1 = esfera

	get_tree().root.add_child(particulas)
	particulas.global_position = posicion_global
	particulas.emitting = true

	get_tree().create_timer(2.0).timeout.connect(
		func():
			if is_instance_valid(particulas):
				particulas.queue_free()
	)


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
