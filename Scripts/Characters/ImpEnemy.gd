extends EnemyBase
class_name ImpEnemy

## Imp enemigo: Camina hacia la izquierda, se detiene y lanza proyectiles.
## Usa animaciones CAMINAR, LANZAR01/LANZAR2. Partículas de muerte ROJAS.

# === CONFIGURACIÓN ESPECÍFICA DEL IMP ===
@export_category("Combate - Imp")
@export var intervalo_disparo: float = 3.0
@export var velocidad_flecha_min: float = 5.0 ## Velocidad mínima del tridente
@export var velocidad_flecha_max: float = 12.0 ## Velocidad máxima del tridente
@export var arco_altura_min: float = 1.0 ## Altura mínima del arco (parábola)
@export var arco_altura_max: float = 2.0 ## Altura máxima del arco (parábola)
@export var gravedad_tridente: float = 1.0 ## Gravedad del tridente (menor = parábola más ancha)
@export var tiempo_lanzamiento_en_animacion: float = 1.7 ## Segundo exacto donde sale el proyectil en LANZAR01
@export var tiempo_lanzamiento_lanzar2: float = 0.88 ## Segundo exacto donde sale el proyectil en LANZAR2
@export var pausa_idle_min: float = 1.0 ## Pausa mínima en IDLE entre lanzamientos
@export var pausa_idle_max: float = 2.0 ## Pausa máxima en IDLE entre lanzamientos

@export_category("Muerte - Explosión")
@export var tiempo_antes_disolver: float = 1.8 ## Tiempo antes de empezar disolución

@export_category("Retroceso")
@export var tiempo_retroceder: float = 1.5 ## Duración que se reproduce la animación RETROCEDER tras LANZAR01
@export var offset_post_lanzar: float = 0.3 ## Salto instantáneo de posición al terminar LANZAR01 (antes de RETROCEDER)
@export var desplazamiento_retroceder: float = 0.3 ## Movimiento gradual total durante la animación RETROCEDER

# === COLOR DE SANGRE (compartido entre todos los Imps) ===
static var sangre_morada: bool = true ## Toggle rojo/morado para la sangre (morada por defecto)

# === REFERENCIAS ESPECÍFICAS ===
var imp_arrow_scene = preload("res://Scenes/Projectiles/ImpTrident.tscn")
var material_imp: Material = preload("res://Assets/Characters/Imp/MAT_IMP.tres")

var is_throwing: bool = false ## True durante la animación de lanzar
var has_thrown: bool = false ## True después de lanzar en este ciclo
var is_idle_pause: bool = false ## True durante la pausa IDLE entre lanzamientos
var is_retreating: bool = false ## True durante la animación RETROCEDER
var retreat_timer: float = 0.0 ## Timer para la duración de RETROCEDER
var current_throw_anim: String = "" ## Nombre de la animación de lanzamiento actual
var throw_anim_timer: float = 0.0 ## Timer para el momento exacto de lanzamiento
var throw_anim_duration: float = 0.0 ## Duración total de la animación actual
var current_throw_time: float = 0.0 ## Segundo exacto de lanzamiento para la animación actual

# ═══════════════════════════════════════════════════════════════════════════════
# HOOKS DE ENEMYBASE
# ═══════════════════════════════════════════════════════════════════════════════

func _on_enemy_ready():
	# Partículas de muerte rojas
	color_borde_disolucion = Color(1.0, 0.15, 0.1)
	
	# El IMP no necesita tracking de spine (apunta por cálculo)
	rastrear_jugador = false
	
	# Aplicar material del Imp a todos los meshes
	_aplicar_material_imp()
	
	# Reproducir animación de caminar
	_play_animation("CAMINAR")

func _aplicar_material_imp():
	if not material_imp:
		return
	var meshes = find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		# No sobreescribir materiales de accesorios (casco, estandarte, etc.)
		if _es_hijo_de_bone_attachment(mesh):
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
	_play_animation("CAMINAR")

func _on_state_shooting():
	# Empieza con IDLE antes del primer lanzamiento
	is_throwing = false
	has_thrown = false
	is_idle_pause = true
	shoot_timer = randf_range(pausa_idle_min, pausa_idle_max)
	_play_animation("IDLE")

func _on_state_dying():
	super._on_state_dying()
	# Sonido de muerte del Imp + explosión
	AudioManager.play_sfx("imp_death")
	AudioManager.play_sfx("explosion_muerte")
	
	# === ANIMACIÓN DE MUERTE ALEATORIA ===
	var death_anims = ["IMP_MUERTE01", "IMP_MUERTE02"]
	var chosen_death = death_anims[randi() % death_anims.size()]
	var anim_length = _get_animation_duration(chosen_death)
	_play_animation(chosen_death)
	
	# === EXPLOSIÓN DE SANGRE ===
	_crear_explosion_sangre()
	
	# Iniciar disolución después de la animación de muerte + tiempo extra
	var tiempo_total = max(anim_length, tiempo_antes_disolver)
	get_tree().create_timer(tiempo_total).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_die()
	)

func _crear_explosion_sangre():
	var particles = GPUParticles3D.new()
	particles.name = "BloodExplosion"
	particles.amount = 15
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.5
	
	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 0.2
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 2.0
	process_mat.initial_velocity_max = 5.0
	process_mat.gravity = Vector3(0, -6.0, 0)
	process_mat.damping_min = 1.0
	process_mat.damping_max = 3.0
	process_mat.scale_min = 0.02
	process_mat.scale_max = 0.06
	
	# Color de sangre: rojo o morado según toggle
	var color_base: Color
	var color_mid: Color
	var color_end: Color
	var color_albedo: Color
	var color_emission: Color
	if sangre_morada:
		color_base = Color(0.4, 0.0, 0.5, 1.0)
		color_mid = Color(0.3, 0.0, 0.4, 0.9)
		color_end = Color(0.15, 0.0, 0.2, 0.0)
		color_albedo = Color(0.35, 0.0, 0.45)
		color_emission = Color(0.3, 0.0, 0.4)
	else:
		color_base = Color(0.6, 0.0, 0.0, 1.0)
		color_mid = Color(0.4, 0.0, 0.0, 0.9)
		color_end = Color(0.2, 0.0, 0.0, 0.0)
		color_albedo = Color(0.5, 0.0, 0.0)
		color_emission = Color(0.4, 0.0, 0.0)
	
	var gradient = Gradient.new()
	gradient.set_color(0, color_base)
	gradient.add_point(0.3, color_mid)
	gradient.set_color(1, color_end)
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex
	
	particles.process_material = process_mat
	
	# Mesh esfera para cada gota
	var sphere = QuadMesh.new()
	sphere.size = Vector2(1.0, 1.0)
	var blood_mat = StandardMaterial3D.new()
	blood_mat.albedo_color = color_albedo
	blood_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	blood_mat.emission_enabled = true
	blood_mat.emission = color_emission
	blood_mat.emission_energy_multiplier = 1.5
	blood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = blood_mat
	particles.draw_pass_1 = sphere
	
	# Posicionar en el centro del cuerpo
	add_child(particles)
	var bone_pos = _get_hips_global_position()
	if bone_pos != Vector3.ZERO:
		particles.global_position = bone_pos
	else:
		particles.position = Vector3(0, 0.3, 0)
	particles.emitting = true
	
	# Reparentar al mundo para que no desaparezca con el enemigo
	var gpos = particles.global_position
	remove_child(particles)
	get_tree().root.add_child(particles)
	particles.global_position = gpos
	
	# Limpiar después de que terminen
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(particles) and particles.is_inside_tree():
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
	
	var trident = imp_arrow_scene.instantiate()
	
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
	get_tree().root.add_child(trident)
	trident.global_position = spawn_pos
