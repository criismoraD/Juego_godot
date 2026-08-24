class_name ImpEnemy
extends EnemyBase

const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")
const PROJECTILE_SCALE: Vector3 = Vector3.ONE

## Sangre de muerte explosiva: idéntica al desmembramiento del Goblin ballestero
## (Sangre_explosion.png, 14 cuadros verticales animados en Sprite3D billboard).
const SANGRE_EXPLOSION_TEX: Texture2D = preload("res://Entities/Enemigo_Goblin/Muerte_Explotado/Sangre_explosion.png")
const SANGRE_FRAMES: int = 14
const SANGRE_SEGUNDOS_POR_FRAME: float = 0.04
const SANGRE_PIXEL_SIZE: float = 0.0070
const SANGRE_OFFSET_Y: float = 0.40
## Duración de la disolución normal (igual a EnemyBase.duracion_disolucion por defecto)
const DURACION_EMISION_DISOLUCION: float = 1.0
## Factor de cese de emisión (igual a particulas_detener_emision del Imp)
const FACTOR_DETENER_EMISION: float = 0.5

## Imp enemigo: Camina hacia la izquierda, se detiene y lanza proyectiles.
## Usa animaciones CAMINAR, LANZAR01/LANZAR2. Partículas de muerte ROJAS.
# === CONFIGURACIÓN ESPECÍFICA DEL IMP ===
@export_category("Combate - Imp")
@export var intervalo_disparo: float = 3.0
@export var velocidad_flecha_min: float = 5.0  ## Velocidad mínima del tridente
@export var velocidad_flecha_max: float = 12.0  ## Velocidad máxima del tridente
@export var arco_altura_min: float = 1.0  ## Altura mínima del arco (parábola)
@export var arco_altura_max: float = 2.0  ## Altura máxima del arco (parábola)
@export var gravedad_tridente: float = 1.0  ## Gravedad del tridente (menor = parábola más ancha)
@export var tiempo_lanzamiento_en_animacion: float = 1.7  ## Segundo exacto donde sale el proyectil en LANZAR01
@export var tiempo_lanzamiento_lanzar2: float = 0.88  ## Segundo exacto donde sale el proyectil en LANZAR2
@export var pausa_idle_min: float = 1.0  ## Pausa mínima en IDLE entre lanzamientos
@export var pausa_idle_max: float = 2.0  ## Pausa máxima en IDLE entre lanzamientos
@export_category("Muerte - Explosión")
@export var tiempo_antes_disolver: float = 1.8  ## Tiempo antes de empezar disolución
@export var escala_sangre_min: float = 0.015  ## Escala mínima de las partículas de sangre al morir
@export var escala_sangre_max: float = 0.03   ## Escala máxima de las partículas de sangre al morir
@export_category("Retroceso")
@export var tiempo_retroceder: float = 1.5  ## Duración que se reproduce la animación RETROCEDER tras LANZAR01
@export var offset_post_lanzar: float = 0.3  ## Salto instantáneo de posición al terminar LANZAR01 (antes de RETROCEDER)
@export var desplazamiento_retroceder: float = 0.3  ## Movimiento gradual total durante la animación RETROCEDER
@export var velocidad_correr: float = 1.2  ## Velocidad de movimiento cuando corre (1.2 por defecto)
# === COLOR DE SANGRE (compartido entre todos los Imps) ===
static var sangre_morada: bool = true  ## Toggle rojo/morado para la sangre (morada por defecto)
# === REFERENCIAS ESPECÍFICAS ===
var imp_arrow_scene = preload("res://Entities/Proyectil_Tridente_Imp/ImpTrident.tscn")
var material_imp: Material = preload("res://Entities/Enemigo_Imp/MAT_IMP.tres")
var is_throwing: bool = false  ## True durante la animación de lanzar
var has_thrown: bool = false  ## True después de lanzar en este ciclo
var is_idle_pause: bool = false  ## True durante la pausa IDLE entre lanzamientos
var is_retreating: bool = false  ## True durante la animación RETROCEDER
var retreat_timer: float = 0.0  ## Timer para la duración de RETROCEDER
var current_throw_anim: String = ""  ## Nombre de la animación de lanzamiento actual
var throw_anim_timer: float = 0.0  ## Timer para el momento exacto de lanzamiento
var throw_anim_duration: float = 0.0  ## Duración total de la animación actual
var current_throw_time: float = 0.0  ## Segundo exacto de lanzamiento para la animación actual
var va_a_correr: bool = false  ## Determina si el Imp corre o camina en esta aparición
var murio_por_explosion: bool = false  ## Marcado por FlechaExplosiva: activa desmembramiento con ragdoll
# ═══════════════════════════════════════════════════════════════════════════════
# HOOKS DE ENEMYBASE
# ═══════════════════════════════════════════════════════════════════════════════


func _on_enemy_ready():
	# Partículas de muerte del mismo color que la sangre
	if sangre_morada:
		color_borde_disolucion = Color(0.4, 0.0, 0.5)
	else:
		color_borde_disolucion = Color(0.6, 0.0, 0.0)

	# El IMP no necesita tracking de spine (apunta por cálculo)
	rastrear_jugador = false

	# Aplicar material del Imp a todos los meshes
	_aplicar_material_imp()

	# Decidir aleatoriamente si corre o camina (50% de probabilidad)
	va_a_correr = randf() < 0.5
	if va_a_correr:
		velocidad_caminar = velocidad_correr
		_play_animation("CORRER")
	else:
		_play_animation("CAMINAR")


func _aplicar_material_imp():
	if not material_imp:
		return
	var meshes = find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		# No sobreescribir materiales de accesorios ni piezas desmembradas (cuerpo ragdoll o cabeza)
		if _es_hijo_de_bone_attachment(mesh) or mesh.find_parent("RagdollImp") != null or mesh.find_parent("CabezaImp") != null or mesh.find_parent("PartesExplotadas") != null:
			continue
		mesh.material_override = material_imp


## Verifica si un nodo es descendiente de un BoneAttachment3D
func _es_hijo_de_bone_attachment(node: Node) -> bool:
	var parent = node.get_parent()
	while parent and parent != self:
		if parent is BoneAttachment3D:
			return true
		parent = parent.get_parent()
	return false


func _on_state_walking():
	if va_a_correr:
		_play_animation("CORRER")
	else:
		_play_animation("CAMINAR")


func _on_state_shooting():
	# Empieza con IDLE antes del primer lanzamiento
	is_throwing = false
	has_thrown = false
	is_idle_pause = true
	shoot_timer = randf_range(pausa_idle_min, pausa_idle_max)
	_play_animation("IDLE")


func _on_state_dying():
	if murio_por_explosion:
		# Diferido: al morir por explosión se llega aquí desde el callback de
		# colisión de la flecha. Reparentar nodos e iniciar la simulación del
		# ragdoll DURANTE el flush de la física corrompe los PhysicalBone3D y
		# estira el modelo por toda la pantalla. Ejecutar fuera del paso de
		# física lo evita.
		_ejecutar_desmembramiento_explosivo.call_deferred()
		return

	super._on_state_dying()
	# Sonido de muerte del Imp + explosión
	AudioManager.play_sfx("imp_death")
	AudioManager.play_sfx("explosion_muerte")

	# === ANIMACIÓN DE MUERTE ALEATORIA ===
	var death_anims = ["IMP_MUERTE01", "IMP_MUERTE02"]
	var chosen_death = death_anims[randi() % death_anims.size()]
	var anim_length = _get_animation_duration(chosen_death)
	_play_animation(chosen_death)

	# Iniciar disolución después de la animación de muerte + tiempo extra
	var tiempo_total = max(anim_length, tiempo_antes_disolver)
	get_tree().create_timer(tiempo_total).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_die()
	)


func _spawn_blood_splash(custom_modulate: Color = Color.WHITE) -> void:
	var color_final: Color = Color(0.8, 0.3, 1.0) if sangre_morada else Color.WHITE
	super._spawn_blood_splash(color_final)


## Muerte por flecha explosiva: la cabeza sale disparada y el cuerpo
## se reemplaza por el ragdoll ImpCuerpoRagdoll activado en la posición actual.
func _ejecutar_desmembramiento_explosivo() -> void:
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

	var root_scene := get_tree().current_scene
	if not root_scene:
		root_scene = get_tree().root

	# 1. Ocultar el modelo intacto
	var model := get_node_or_null("ImpModel") as Node3D
	if model:
		model.visible = false

	# 2. Audio + sangre (mismo efecto de sangre que el Goblin ballestero al explotar)
	AudioManager.play_sfx("explosion_muerte")
	AudioManager.play_sfx("sangre_splash")
	_spawn_sangre_animada(global_position)

	# 3. Dirección de expulsión según el punto de impacto de la explosión
	var push_dir: float = 1.0
	if last_hit_position != Vector3.ZERO:
		var dx: float = global_position.x - last_hit_position.x
		if absf(dx) > 0.05:
			push_dir = signf(dx)

	# 4. Ragdoll: reparentar a la escena, mostrar y activar con rotación en Z e impulso moderado
	var ragdoll := get_node_or_null("RagdollImp") as ImpCuerpoRagdoll
	if ragdoll:
		var tr_ragdoll: Transform3D = ragdoll.global_transform
		ragdoll.get_parent().remove_child(ragdoll)
		root_scene.add_child(ragdoll)
		# Conservar orientación base (-90°) y aplicar variación aleatoria de rotación en Z entre -10° y +30°
		var rot_z_rad: float = deg_to_rad(randf_range(-10.0, 30.0))
		var base_basis: Basis = tr_ragdoll.basis.orthonormalized().rotated(Vector3(0, 0, 1), rot_z_rad)
		ragdoll.global_transform = Transform3D(base_basis, tr_ragdoll.origin)
		ragdoll.visible = true
		for m in ragdoll.find_children("*", "MeshInstance3D", true, false):
			m.material_override = null
		# Impulso moderado para caída y rebote natural sin saltar excesivamente alto
		var impulse_cuerpo := Vector3(
			push_dir * randf_range(1.2, 2.2),
			randf_range(1.0, 1.8),
			0.0
		)
		ragdoll.activar_ragdoll(impulse_cuerpo)
		ragdoll.iniciar_disolucion_automatica(color_borde_disolucion)

	# 5. Cabeza: contenedor físico con vuelo parabólico
	var cabeza := get_node_or_null("CabezaImp") as Node3D
	if cabeza:
		var tr_cabeza: Transform3D = cabeza.global_transform
		var local_tr_cabeza: Transform3D = cabeza.transform
		cabeza.get_parent().remove_child(cabeza)
		var contenedor := ImpPiezaFisica.new()
		root_scene.add_child(contenedor)
		contenedor.global_position = tr_cabeza.origin
		cabeza.transform = Transform3D(local_tr_cabeza.basis, Vector3.ZERO)
		cabeza.visible = true
		for m in cabeza.find_children("*", "MeshInstance3D", true, false):
			m.material_override = null
		contenedor.add_child(cabeza)
		var vel_cabeza := Vector3(
			push_dir * randf_range(2.2, 5.5),
			randf_range(3.8, 7.2),
			0.0
		)
		var rot_cabeza := randf_range(8.0, 20.0) * (-1.0 if randf() < 0.5 else 1.0)
		contenedor.iniciar_vuelo(vel_cabeza, rot_cabeza)

	# 6. Configurar el ragdoll para que, al comenzar a desaparecer (disolución),
	# emita las partículas moradas en la ÚLTIMA posición del cadáver.
	# Si no hay ragdoll (fallback), emitirlas aquí mismo y liberar la entidad.
	if ragdoll:
		ragdoll.configurar_particulas_desaparicion(
			color_borde_disolucion,
			particulas_cantidad * 3,
			particulas_vida,
			particulas_caja,
			particulas_dispersion,
			particulas_velocidad_min,
			particulas_velocidad_max,
			particulas_gravedad,
			intensidad_emision,
			particulas_offset_y,
			particulas_escala_min,
			particulas_escala_max
		)
	else:
		var centro_fallback := _get_hips_global_position()
		if centro_fallback == Vector3.ZERO:
			centro_fallback = global_position
		_spawn_particulas_disolucion_explosiva(centro_fallback)

	queue_free()


## Mismo efecto de sangre que el Goblin ballestero al explotar:
## sprite 3D con los 14 cuadros verticales de Sangre_explosion.png animados en bucle único.
func _spawn_sangre_animada(pos: Vector3) -> void:
	if not SANGRE_EXPLOSION_TEX:
		return

	var sprite := Sprite3D.new()
	sprite.texture = SANGRE_EXPLOSION_TEX
	sprite.vframes = SANGRE_FRAMES
	sprite.hframes = 1
	sprite.frame = 0
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.render_priority = 3
	sprite.no_depth_test = false
	sprite.pixel_size = SANGRE_PIXEL_SIZE

	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	root.add_child(sprite)
	sprite.global_position = pos + Vector3(0.0, SANGRE_OFFSET_Y, 0.0)

	var anim_task := func():
		for f in range(SANGRE_FRAMES):
			if not is_instance_valid(sprite) or not sprite.is_inside_tree():
				return
			sprite.frame = f
			await sprite.get_tree().create_timer(SANGRE_SEGUNDOS_POR_FRAME, false).timeout
		if is_instance_valid(sprite):
			sprite.queue_free()

	anim_task.call()


## Mismo efecto de partículas de disolución que la muerte normal del Imp
## (morado por defecto vía color_borde_disolucion). Wrapper de instancia que
## delega en el builder estático crear_particulas_disolucion().
func _spawn_particulas_disolucion_explosiva(pos_hips: Vector3) -> void:
	crear_particulas_disolucion(
		self,
		pos_hips,
		color_borde_disolucion,
		particulas_cantidad * 3,
		particulas_vida,
		particulas_caja,
		particulas_dispersion,
		particulas_velocidad_min,
		particulas_velocidad_max,
		particulas_gravedad,
		particulas_escala_min,
		particulas_escala_max,
		intensidad_emision,
		particulas_offset_y
	)


## Builder estático: partículas de disolución idénticas a la muerte normal
## (EnemyBase._create_dissolve_particles). Nodo independiente en la escena para
## sobrevivir al queue_free() del cuerpo; lo usa también el ragdoll al desaparecer.
static func crear_particulas_disolucion(
	dueno: Node,
	pos_base: Vector3,
	color_particulas: Color,
	cantidad: int,
	vida: float,
	caja: Vector3,
	dispersion: float,
	vel_min: float,
	vel_max: float,
	gravedad: Vector3,
	escala_min: float,
	escala_max: float,
	intensidad: float,
	offset_y: float
) -> void:
	if dueno == null or not is_instance_valid(dueno):
		return

	var particles := GPUParticles3D.new()
	particles.name = "ParticulasDisolucionExplosiva"
	particles.amount = cantidad
	particles.lifetime = vida
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.3

	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = caja
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = dispersion
	process_mat.initial_velocity_min = vel_min
	process_mat.initial_velocity_max = vel_max
	process_mat.gravity = gravedad
	# Variación aleatoria de tamaño entre partículas (rango normalizado)
	process_mat.scale_min = 0.5
	process_mat.scale_max = 1.5

	var gradient := Gradient.new()
	gradient.set_color(0, color_particulas)
	gradient.set_color(
		1, Color(color_particulas.r, color_particulas.g, color_particulas.b, 0.0)
	)
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 0.2))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	process_mat.scale_curve = scale_tex

	particles.process_material = process_mat

	# El tamaño del mesh controla directamente el tamaño visual de las partículas
	var avg_radius: float = (escala_min + escala_max) / 2.0
	var sphere := SphereMesh.new()
	sphere.radius = avg_radius
	sphere.height = avg_radius * 2.0

	var part_mat := StandardMaterial3D.new()
	part_mat.albedo_color = color_particulas
	part_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	part_mat.emission_enabled = true
	part_mat.emission = color_particulas
	part_mat.emission_energy_multiplier = intensidad
	part_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	part_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = part_mat

	particles.draw_pass_1 = sphere

	var root := dueno.get_tree().current_scene
	if not root:
		root = dueno.get_tree().root
	root.add_child(particles)
	particles.global_position = pos_base + Vector3(0, offset_y, 0)
	particles.emitting = true

	# Mismos tiempos que la muerte normal: dejar de emitir y luego autodestruirse
	dueno.get_tree().create_timer(DURACION_EMISION_DISOLUCION * FACTOR_DETENER_EMISION).timeout.connect(
		func():
			if is_instance_valid(particles):
				particles.emitting = false
	)
	dueno.get_tree().create_timer(DURACION_EMISION_DISOLUCION + vida + 0.5).timeout.connect(
		func():
			if is_instance_valid(particles):
				particles.queue_free()
	)



# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO / LANZAMIENTO
# ═══════════════════════════════════════════════════════════════════════════════


func _process_shooting(delta):
	velocity.x = 0

	if rastrear_jugador:
		_track_player()

	if is_throwing:
		# === FASE LANZAMIENTO: esperando el momento exacto del proyectil ===
		throw_anim_timer += delta
		if not has_thrown and throw_anim_timer >= current_throw_time:
			_throw_projectile()
			has_thrown = true
		# Esperar a que termine la animación completa
		if throw_anim_timer >= throw_anim_duration:
			is_throwing = false
			# Si fue LANZAR01, ejecutar RETROCEDER antes del IDLE
			if current_throw_anim == "LANZAR01":
				is_retreating = true
				retreat_timer = tiempo_retroceder
				# Salto instantáneo de posición (offset post-lanzar)
				global_position.x += offset_post_lanzar
				_play_animation("RETROCEDER")
			else:
				# LANZAR2 → directo a pausa IDLE
				is_idle_pause = true
				shoot_timer = randf_range(pausa_idle_min, pausa_idle_max)
				_play_animation("IDLE")
	elif is_retreating:
		# === FASE RETROCEDER: animación de retroceso tras LANZAR01 ===
		# Desplazamiento gradual durante la animación RETROCEDER
		var velocidad_retroceso = desplazamiento_retroceder / tiempo_retroceder
		global_position.x += velocidad_retroceso * delta
		retreat_timer -= delta
		if retreat_timer <= 0:
			is_retreating = false
			is_idle_pause = true
			shoot_timer = randf_range(pausa_idle_min, pausa_idle_max)
			_play_animation("IDLE")
	elif is_idle_pause:
		# === FASE IDLE: esperando entre lanzamientos ===
		shoot_timer -= delta
		if shoot_timer <= 0:
			is_idle_pause = false
			_start_throw_animation()


func _start_throw_animation():
	is_throwing = true
	has_thrown = false
	throw_anim_timer = 0.0
	var lanzar_anims = ["LANZAR01", "LANZAR2"]
	var chosen = lanzar_anims[randi() % lanzar_anims.size()]
	current_throw_anim = chosen
	_play_animation(chosen)
	throw_anim_duration = _get_animation_duration(chosen)
	# Cada animación tiene su propio timing de lanzamiento
	if chosen == "LANZAR2":
		current_throw_time = tiempo_lanzamiento_lanzar2
	else:
		current_throw_time = tiempo_lanzamiento_en_animacion


func _throw_projectile():
	if not imp_arrow_scene:
		return

	# Sonido de lanzamiento del tridente
	AudioManager.play_sfx("trident_shot")

	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return

	# No disparar si el jugador está muerto
	if player_ref.get("is_dead"):
		return

	var trident := PROJECTILE_POOL_REF.acquire(imp_arrow_scene) as ImpTridentProjectile
	if not trident:
		return

	trident.scale = PROJECTILE_SCALE
	var spawn_pos = global_position + Vector3(-0.3, altura_spawn_flecha, 0)
	var target_pos = player_ref.global_position + Vector3(0, 0.5, 0)
	var direction = (target_pos - spawn_pos).normalized()

	# Ajustar dirección para trayectoria parabólica (arco variable)
	var arco = randf_range(arco_altura_min, arco_altura_max)
	direction.y += arco
	direction = direction.normalized()

	var potencia = randf_range(velocidad_flecha_min, velocidad_flecha_max)
	trident.initialize(direction, potencia / 8.0)
	# Aplicar gravedad personalizada al tridente
	trident.gravedad = gravedad_tridente
	PROJECTILE_POOL_REF.activate(trident, get_tree().root, spawn_pos)
