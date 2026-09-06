extends Area3D
class_name ArrowProjectile
const CameraUtilsRef = preload("res://System/Utils/CameraUtils.gd")
const DURACION_DESVANECIMIENTO: float = 0.6

# === CONFIGURACIÓN (Español) ===
@export_category("Física")
@export var escala_gravedad: float = 1.0  # Multiplicador de gravedad
@export var tiempo_vida: float = 10.0  # Tiempo antes de destruirse
@export var tiempo_pegada: float = 5.0  # Tiempo antes de desaparecer cuando está pegada

# === TIPO DE FLECHA ===
enum TipoFlecha { JUGADOR, ENEMIGO }
@export var tipo_dueño: TipoFlecha = TipoFlecha.JUGADOR
@export var multiplicador_dano_sobrecarga: float = 2.0  ## Daño x2 solo con flecha de sobrecarga morada al 100% (meta "sobrecarga_max")

## SISTEMA GOLPE CRÍTICO: daño letal instantáneo cuando la sobrecarga al 100%
## impacta a un enemigo en su momento vulnerable (es_momento_golpe_critico).
const GOLPE_CRITICO_DANO: float = 99999.0

# === FLECHA EXPLOSIVA ===
@export_category("Flecha Explosiva")
@export var es_explosiva: bool = false:
	set(value):
		es_explosiva = value
		if es_explosiva and is_inside_tree():
			_crear_destello_punta()
@export var dano_base_explosiva: float = 3.0  ## Daño base en área (3)
@export var bono_dano_estructuras: float = 6.0  ## Bono contra estructuras y escudos (+6 = 9 total)
@export var radio_explosion: float = 4.84  ## Radio del área de efecto ampliado (4.84m)

# === ESTADO INTERNO ===
var velocity: Vector3 = Vector3.ZERO
var power: float = 0.0
var tirador: Node = null  ## Quién disparó (Player o AllyArcher): autoría de la muerte para diálogos
var world_gravity: float = 0.0
var is_stuck: bool = false
var _destroying: bool = false
var _ray_ccd: RayCast3D
var _last_ccd_pos: Vector3 = Vector3.ZERO  # OPT: Posición del último CCD check
const CCD_MIN_MOVE: float = 0.05  # OPT: Distancia mínima antes de re-chequear CCD
var gameplay_z_plane: float = 0.0
var _destello_punta_creado: bool = false

var _cached_mesh_instances: Array[Node] = []
var _cached_particles: Array[Node] = []
var _desvaneciendose: bool = false  ## True durante la transición de transparencia clavada
static var _cached_tip_material: StandardMaterial3D = null
static var _cached_tip_mesh: SphereMesh = null


func _ready():
	if get_parent() is BoneAttachment3D or is_in_group("visual_only"):
		set_physics_process(false)
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		return

	world_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

	var player = get_tree().get_first_node_in_group("player")
	if player:
		gameplay_z_plane = player.global_position.z
	else:
		gameplay_z_plane = 0.0

	_cached_mesh_instances = find_children("*", "MeshInstance3D", true, false)
	_cached_particles = find_children("*", "GPUParticles3D", true, false)

	for mesh in _cached_mesh_instances:
		mesh.add_to_group("outline_meshes")

	if es_explosiva:
		_crear_destello_punta()

	# Inicializar RayCast para detección continua (anti-tunneling)
	var ray = RayCast3D.new()
	_ray_ccd = ray
	ray.name = "RayCastCCD"
	ray.enabled = true
	ray.target_position = Vector3.ZERO  # Se actualiza cada frame
	ray.collision_mask = collision_mask  # Usar la misma máscara
	ray.exclude_parent = true
	ray.collide_with_areas = true  # También detectar áreas (como ArrowDetector)
	ray.collide_with_bodies = true
	add_child(ray)

	# Timer de destrucción (si no se pega antes)
	get_tree().create_timer(tiempo_vida).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_check_destroy()
	)

	# Conectar colisiones
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta):
	if is_stuck:
		return  # No mover si está pegada

	# 1. Aplicar gravedad
	velocity.y -= world_gravity * escala_gravedad * delta

	# 2. Forzar Z (2.5D dinámico)
	velocity.z = 0
	global_position.z = gameplay_z_plane

	# --- CCD Detection (RayCast) — OPT: solo si nos movimos lo suficiente ---
	var ray = _ray_ccd
	if ray:
		var dist_moved = global_position.distance_to(_last_ccd_pos)
		if dist_moved >= CCD_MIN_MOVE:
			# Convertir vector de velocidad (World) a local para el raycast
			# Predecimos dónde estará en el siguiente frame
			var next_pos = global_position + velocity * delta
			ray.target_position = to_local(next_pos)
			ray.force_raycast_update()
			_last_ccd_pos = global_position

			if ray.is_colliding():
				var collider = ray.get_collider()
				var ignorar_colision: bool = false
				if collider:
					if collider.is_in_group("allies") or (tipo_dueño == TipoFlecha.JUGADOR and collider.is_in_group("player")):
						ignorar_colision = true
					elif tipo_dueño == TipoFlecha.JUGADOR and (collider.is_in_group("escudos") or collider.has_method("recibir_golpe")):
						var es_enemigo: bool = false
						if "es_escudo_enemigo" in collider:
							es_enemigo = collider.es_escudo_enemigo
						elif "es_pilar_enemigo" in collider:
							es_enemigo = collider.es_pilar_enemigo
						elif collider.is_in_group("enemies"):
							es_enemigo = true
						if not es_enemigo:
							ignorar_colision = true

				if ignorar_colision:
					ray.add_exception(collider)
				else:
					# Si detectamos colisión válida, nos movemos al punto de impacto
					global_position = ray.get_collision_point()

					if collider is Area3D:
						_on_area_entered(collider)
					else:
						_on_body_entered(collider)

					if is_stuck:
						return
	# -------------------------------

	# 3. Mover
	global_position += velocity * delta

	# 4. Rotar para apuntar hacia la dirección de movimiento
	if velocity.length_squared() > 0.01:
		var angle = atan2(velocity.y, velocity.x)
		rotation = Vector3(0, 0, angle)

	# 5. Verificar si está fuera de pantalla
	_check_off_screen()


func _check_off_screen():
	# Verificación ultra-rápida en coordenadas 3D para evitar cálculos de proyección por matriz
	if global_position.y < -20.0 or global_position.x < -25.0 or global_position.x > 55.0 or global_position.y > 50.0:
		_safe_destroy()
		return

	var camera = CameraUtilsRef.obtener_camara_juego(self)
	if not camera:
		return

	# Obtener posición en pantalla
	var screen_pos = camera.unproject_position(global_position)
	var viewport_size = get_viewport().get_visible_rect().size

	# Margen horizontal moderado
	var margin_x = 400.0
	# Margen vertical amplio arriba para permitir trayectorias parabólicas
	var margin_top = 2000.0
	var margin_bottom = 300.0

	if screen_pos.x < -margin_x or screen_pos.x > viewport_size.x + margin_x:
		_safe_destroy()
	elif screen_pos.y < -margin_top:
		_safe_destroy()
	elif screen_pos.y > viewport_size.y + margin_bottom:
		_safe_destroy()


func _on_body_entered(body):
	if is_stuck:
		return

	# Ignorar cuerpos ocultos o desactivados
	if not body.is_visible_in_tree():
		if _ray_ccd: _ray_ccd.add_exception(body)
		return

	if body.is_in_group("barrera_destruye_flechas"):
		# La barrera solo elimina la flecha: sin sonido ni VFX de impacto.
		_safe_destroy(true)
		return

	# Ignorar al jugador si es flecha del jugador (para que no se pegue al salir)
	if tipo_dueño == TipoFlecha.JUGADOR and body.is_in_group("player"):
		return

	# Ignorar aliados (NPC) — las flechas los atraviesan
	if body.is_in_group("allies"):
		if _ray_ccd: _ray_ccd.add_exception(body)
		return

	# Ignorar defensas y escudos aliados si la flecha es del jugador/aliadas
	if tipo_dueño == TipoFlecha.JUGADOR:
		if body.has_method("recibir_golpe") or body.is_in_group("escudos"):
			var es_enemigo: bool = false
			if "es_escudo_enemigo" in body:
				es_enemigo = body.es_escudo_enemigo
			elif "es_pilar_enemigo" in body:
				es_enemigo = body.es_pilar_enemigo
			elif body.is_in_group("enemies"):
				es_enemigo = true

			if not es_enemigo:
				if _ray_ccd: _ray_ccd.add_exception(body)
				return # Ignora el escudo / defensa aliada y pasa de largo sin interactuar

	# Si es flecha explosiva, impacta y explota en área contra cualquier cuerpo o superficie enemiga/suelo
	if es_explosiva:
		_explotar(body)
		return

	# Interacción con escudos
	if body.has_method("recibir_golpe"):
		var es_enemigo = false
		if "es_escudo_enemigo" in body:
			es_enemigo = body.es_escudo_enemigo

		if tipo_dueño == TipoFlecha.ENEMIGO:
			if es_enemigo:
				if _ray_ccd: _ray_ccd.add_exception(body)
				return # Ignora el escudo enemigo y pasa de largo
			else:
				if body.has_method("es_reflejante") and body.es_reflejante():
					body.recibir_golpe_reflejo(self)
					_rebotar_de_aura(body)
					return
				body.recibir_golpe()
				_safe_destroy()
				return
		elif tipo_dueño == TipoFlecha.JUGADOR:
			if es_enemigo:
				var es_sobrecarga: bool = has_meta("sobrecarga_max") and bool(get_meta("sobrecarga_max"))
				# SISTEMA GOLPE CRÍTICO: enemigos con momento vulnerable definido
				# (ej.: GuardianaMoradita) se dañan por take_damage, no como escudo.
				# Con sobrecarga al 100% solo mueren de un golpe si están en ese momento.
				if es_sobrecarga and body.has_method("es_momento_golpe_critico"):
					var dano_critico: float = GOLPE_CRITICO_DANO if body.es_momento_golpe_critico() else multiplicador_dano_sobrecarga
					body.take_damage(dano_critico)
					_safe_destroy()
					return
				var dano_escudo: float = 1.0
				# La sobrecarga al máximo solo destruye de un golpe defensas
				# destruibles por contador de golpes (escudos). Las estructuras
				# con vida propia (pilar de Lonko) NO entran en esta regla.
				if es_sobrecarga and not _es_estructura_con_vida(body):
					dano_escudo = 999.0
				body.recibir_golpe(dano_escudo)
				if es_sobrecarga:
					_safe_destroy()
				else:
					_stick_to_shield(body)
				return
			else:
				if _ray_ccd: _ray_ccd.add_exception(body)
				return # Ignora el escudo aliado y pasa de largo
	
	# Por si acaso, si es un escudo sin el método (no debería pasar)
	if body.is_in_group("escudos"):
		if _ray_ccd: _ray_ccd.add_exception(body)
		return

	# Verificar si es un suelo o plataforma (StaticBody3D o AnimatableBody3D)
	# Las flechas del jugador se pegan a plataformas desde cualquier dirección
	if body is StaticBody3D or body is AnimatableBody3D:
		_stick_to_surface()
		return

	# Verificar si es un objetivo válido
	if tipo_dueño == TipoFlecha.JUGADOR:
		# Las flechas del jugador dañan enemigos (x2 con sobrecarga morada al 100%)
		if body.has_method("take_damage") and body.is_in_group("enemies"):
			# Verificar interacción con aura repelente (ej: Arquera Rosa)
			if body.has_method("manejar_impacto_aura") and body.manejar_impacto_aura(self):
				_rebotar_de_aura(body)
				return

			if ("_is_invulnerable" in body and body._is_invulnerable) or ("is_invulnerable" in body and body.is_invulnerable):
				if _ray_ccd: _ray_ccd.add_exception(body)
				return  # Pasa de largo a través del enemigo invulnerable

			# Guardar posición del impacto para las partículas de sangre
			if body.has_method("set") and "last_hit_position" in body:
				body.last_hit_position = global_position
			if body.has_method("set") and "last_hit_direction" in body:
				body.last_hit_direction = velocity.normalized()
			# Autoría del golpe para el conteo de muertes por defensora
			if body.has_method("set") and "ultimo_atacante" in body:
				body.ultimo_atacante = tirador
			var dano_final: float = 1.0
			var es_sobrecarga: bool = has_meta("sobrecarga_max") and bool(get_meta("sobrecarga_max"))
			if es_sobrecarga:
				dano_final *= multiplicador_dano_sobrecarga
				# SISTEMA GOLPE CRÍTICO: la sobrecarga morada al 100% solo mata de
				# un golpe si el enemigo está en SU momento vulnerable (definido por
				# cada enemigo en es_momento_golpe_critico, ej.: Moradita en plena
				# animación de ataque). Fuera de ese momento recibe el daño x2 normal.
				if body.has_method("es_momento_golpe_critico") and body.es_momento_golpe_critico():
					dano_final = GOLPE_CRITICO_DANO
			body.take_damage(dano_final)
			_safe_destroy()
	elif tipo_dueño == TipoFlecha.ENEMIGO:
		# Las flechas del enemigo dañan al jugador
		if body.has_method("take_damage") and body.is_in_group("player"):
			body.take_damage(1.0)
			_safe_destroy()


func _on_area_entered(area: Area3D):
	if is_stuck:
		return

	if es_explosiva:
		var parent_node := area.get_parent()
		var target: Node = parent_node if parent_node else area
		
		# Ignorar aliados y defensas aliadas
		if target.is_in_group("allies") or target.is_in_group("player"):
			return
		if ("es_escudo_enemigo" in target and not target.es_escudo_enemigo):
			return

		if target.is_in_group("enemies") or target.is_in_group("escudos") or target is StaticBody3D or target is AnimatableBody3D:
			_explotar(target)
			return

	# Detectar ArrowDetector de PlataformaOneway para pegar la flecha
	if area.name == "ArrowDetector":
		# Buscar el AnimatableBody3D padre (la plataforma)
		var platform = area.get_parent()
		if platform and (platform is AnimatableBody3D or platform is StaticBody3D):
			_stick_to_surface()
			return

	# Interacción con escudos o áreas enemigas (ej: EscudoPesadoArea de GuardianaMoradita)
	if tipo_dueño == TipoFlecha.JUGADOR and (area.is_in_group("escudos") or area.has_method("recibir_golpe")):
		var es_enemigo: bool = false
		if "es_escudo_enemigo" in area:
			es_enemigo = area.es_escudo_enemigo
		elif "es_pilar_enemigo" in area:
			es_enemigo = area.es_pilar_enemigo
		elif area.is_in_group("enemies"):
			es_enemigo = true

		if not es_enemigo:
			if _ray_ccd: _ray_ccd.add_exception(area)
			return  # Ignorar escudos aliados

		var es_sobrecarga: bool = has_meta("sobrecarga_max") and bool(get_meta("sobrecarga_max"))
		var dano_escudo: float = 1.0
		if es_sobrecarga:
			dano_escudo = 999.0

		if area.has_method("recibir_golpe"):
			area.recibir_golpe(dano_escudo)
		elif area.has_method("take_damage"):
			area.take_damage(dano_escudo)

		if es_sobrecarga:
			_safe_destroy()
		else:
			_stick_to_shield(area)
		return


## Estructuras defensivas con vida propia (pilar de Lonko): no mueren de un
## golpe con la sobrecarga; reciben el daño normal de flecha por recibir_golpe.
func _es_estructura_con_vida(body: Object) -> bool:
	if body is PilarLonkoBody:
		return true
	return "es_pilar_enemigo" in body and bool(body.get("es_pilar_enemigo"))


func _stick_to_surface():
	is_stuck = true
	velocity = Vector3.ZERO
	AudioManager.play_sfx("arrow_impact")

	# Desactivar colisiones para no seguir detectando (usar set_deferred para evitar errores)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	# Detener partículas de estela si existen
	var trail = get_node_or_null("TrailParticles")
	if trail:
		trail.emitting = false

	# Programar desvanecimiento después de un tiempo clavada (sin borrado brusco)
	get_tree().create_timer(tiempo_pegada).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_desvanecer_y_liberar()
	)


## Transición de transparencia al dejar de estar clavada (terreno/escudo):
## desvanece el alfa de sus materiales gradualmente antes de liberarse.
func _desvanecer_y_liberar() -> void:
	if _desvaneciendose:
		return
	_desvaneciendose = true

	var trail = get_node_or_null("TrailParticles")
	if trail:
		trail.emitting = false

	var materiales: Array[StandardMaterial3D] = []
	for mesh in _cached_mesh_instances:
		if not is_instance_valid(mesh):
			continue
		var orig: Material = mesh.material_override
		if orig == null and mesh.mesh:
			orig = mesh.mesh.surface_get_material(0)
		var mat := StandardMaterial3D.new()
		if orig is StandardMaterial3D:
			mat = (orig as StandardMaterial3D).duplicate()
		# Sin contorno durante el desvanecimiento y con alfa animable
		mat.next_pass = null
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = mat
		materiales.append(mat)

	var tween := create_tween()
	tween.tween_method(
		func(alfa: float):
			for m in materiales:
				if is_instance_valid(m):
					var c := m.albedo_color
					c.a = alfa
					m.albedo_color = c
					if m.emission_enabled:
						m.emission_energy_multiplier = 3.0 * alfa
	, 1.0, 0.0, DURACION_DESVANECIMIENTO
	)
	tween.tween_callback(queue_free)


func _stick_to_shield(shield: Node3D):
	is_stuck = true
	velocity = Vector3.ZERO

	# Desactivar colisiones para no seguir detectando
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	# Detener partículas de estela si existen
	var trail = get_node_or_null("TrailParticles")
	if trail:
		trail.emitting = false

	var glob_trans = global_transform
	call_deferred("_reparent_to_shield", shield, glob_trans)


func _reparent_to_shield(shield: Node3D, glob_trans: Transform3D):
	if not is_instance_valid(shield):
		_cleanup_materials()
		queue_free()
		return

	var current_parent = get_parent()
	if current_parent:
		current_parent.remove_child(self)
	shield.add_child(self)
	global_transform = glob_trans

	# Conectar señal de destrucción del escudo para desvanecerse
	if shield.has_signal("destruido"):
		shield.destruido.connect(
			func():
				if is_instance_valid(self):
					_desvanecer_y_liberar()
		)

	# Programar desvanecimiento después de un tiempo clavada en el escudo
	get_tree().create_timer(tiempo_pegada).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_desvanecer_y_liberar()
	)


func _stick_to_enemy(enemy: Node3D):
	is_stuck = true
	velocity = Vector3.ZERO

	# Desactivar colisiones
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	# Detener partículas de estela
	var trail = get_node_or_null("TrailParticles")
	if trail:
		trail.emitting = false

	# Buscar el skeleton del enemigo para pegar la flecha a un hueso
	var skeleton = enemy.find_child("Skeleton3D", true, false)
	if skeleton and skeleton is Skeleton3D:
		# Encontrar el hueso más cercano a la posición de impacto
		var closest_bone_idx = _find_closest_bone(skeleton)
		if closest_bone_idx >= 0:
			call_deferred("_attach_to_bone", enemy, skeleton, closest_bone_idx)
			return

	# Fallback: pegar al goblin directamente (comportamiento anterior)
	var relative_pos = global_position - enemy.global_position
	call_deferred("_reparent_to_enemy", enemy, relative_pos)


func _find_closest_bone(skeleton: Skeleton3D) -> int:
	var closest_idx = -1
	var min_dist = INF

	for i in range(skeleton.get_bone_count()):
		var bone_pos = skeleton.global_position + skeleton.get_bone_global_pose(i).origin
		var dist = global_position.distance_to(bone_pos)
		if dist < min_dist:
			min_dist = dist
			closest_idx = i

	return closest_idx


func _attach_to_bone(enemy: Node3D, skeleton: Skeleton3D, bone_idx: int):
	if not is_instance_valid(enemy) or not is_instance_valid(skeleton):
		_cleanup_materials()
		queue_free()
		return

	# Calcular posición relativa al hueso
	var bone_transform = skeleton.get_bone_global_pose(bone_idx)
	var bone_global_pos = skeleton.global_position + bone_transform.origin
	var relative_pos = global_position - bone_global_pos

	# Crear un BoneAttachment3D para seguir el hueso
	var attachment = BoneAttachment3D.new()
	attachment.bone_name = skeleton.get_bone_name(bone_idx)
	skeleton.add_child(attachment)

	# Remover del padre actual
	var current_parent = get_parent()
	if current_parent:
		current_parent.remove_child(self)

	# Añadir la flecha al attachment
	attachment.add_child(self)
	position = relative_pos * 2.0  # Ajustar escala por skeleton

	# Conectar señal de muerte del enemigo para auto-destruirse
	if enemy.has_signal("died"):
		enemy.died.connect(
			func():
				if is_instance_valid(self):
					_cleanup_materials()
					queue_free()
		)

	# Timer de destrucción
	get_tree().create_timer(tiempo_pegada).timeout.connect(
		func():
			if is_instance_valid(attachment) and attachment.is_inside_tree():
				attachment.queue_free()
			if is_instance_valid(self) and is_inside_tree():
				_cleanup_materials()
				queue_free()
	)


func _reparent_to_enemy(enemy: Node3D, relative_pos: Vector3):
	if not is_instance_valid(enemy):
		_cleanup_materials()
		queue_free()
		return

	# Remover del padre actual
	var current_parent = get_parent()
	if current_parent:
		current_parent.remove_child(self)

	# Añadir al enemigo
	enemy.add_child(self)
	position = relative_pos

	# Conectar señal de muerte del enemigo
	if enemy.has_signal("died"):
		enemy.died.connect(
			func():
				if is_instance_valid(self):
					_cleanup_materials()
					queue_free()
		)

	# Destruir después de un tiempo
	get_tree().create_timer(tiempo_pegada).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_cleanup_materials()
				queue_free()
	)


func _safe_destroy(silent: bool = false):
	if _destroying:
		return
	_destroying = true

	# Si es de máxima potencia, crear una explosión de impacto juiciosa.
	# Se omite cuando la destrucción es silenciosa (ej. BarreraDestruyeFlechas).
	if not silent and has_meta("is_max_power") and bool(get_meta("is_max_power")):
		_spawn_max_power_impact_vfx()
		
	# Detener trail antes de liberar para evitar "Parameter material is null"
	var trail = get_node_or_null("TrailParticles")
	if trail:
		trail.emitting = false
		if trail.draw_pass_1 and trail.draw_pass_1 is Mesh:
			trail.draw_pass_1.material = null
		trail.draw_pass_1 = null
	# Limpiar materiales de meshes
	_cleanup_materials()
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_physics_process(false)
	get_tree().create_timer(0.3).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				queue_free()
	)


func _spawn_max_power_impact_vfx():
	# Helper local para crear textura suave de círculo radial
	var grad = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var base_mat = StandardMaterial3D.new()
	base_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	base_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	base_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	base_mat.vertex_color_use_as_albedo = true
	base_mat.albedo_texture = tex

	# 1. Chispas sutiles de impacto
	var sparks = CPUParticles3D.new()
	sparks.amount = 10
	sparks.lifetime = 0.25
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.emitting = true
	sparks.local_coords = false
	sparks.direction = -velocity.normalized()
	sparks.spread = 45.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 5.0
	sparks.gravity = Vector3(0, -8.0, 0)
	var color_grad = Gradient.new()
	color_grad.set_color(0, Color(0.5, 0.85, 1.0, 0.8))
	color_grad.set_color(1, Color(0.2, 0.5, 1.0, 0.0))
	sparks.color_ramp = color_grad
	sparks.scale_amount_min = 0.01
	sparks.scale_amount_max = 0.04
	var sc = Curve.new()
	sc.add_point(Vector2(0, 1.0))
	sc.add_point(Vector2(1, 0.0))
	sparks.scale_amount_curve = sc
	var qm = QuadMesh.new()
	qm.size = Vector2(0.04, 0.04)
	qm.material = base_mat
	sparks.mesh = qm
	get_tree().root.add_child(sparks)
	sparks.global_position = global_position

	# 2. Destello pequeño de impacto
	var flash = CPUParticles3D.new()
	flash.amount = 1
	flash.lifetime = 0.1
	flash.one_shot = true
	flash.emitting = true
	flash.local_coords = false
	flash.gravity = Vector3.ZERO
	var fg = Gradient.new()
	fg.set_color(0, Color(0.6, 0.9, 1.0, 0.7))
	fg.set_color(1, Color(0.4, 0.7, 1.0, 0.0))
	flash.color_ramp = fg
	flash.scale_amount_min = 0.05
	flash.scale_amount_max = 0.1
	var qf = QuadMesh.new()
	qf.size = Vector2(0.12, 0.12)
	qf.material = base_mat.duplicate()
	flash.mesh = qf
	get_tree().root.add_child(flash)
	flash.global_position = global_position

	# Auto-destroy
	get_tree().create_timer(0.4).timeout.connect(func():
		if is_instance_valid(sparks): sparks.queue_free()
		if is_instance_valid(flash): flash.queue_free()
	)

	# 3. Sonido sutil de impacto
	AudioManager.play_sfx("shield_hit_arrow")
	
	# 4. Screen shake en el impacto
	var game_feel = get_tree().root.get_node_or_null("GameFeel")
	if game_feel and game_feel.has_method("on_player_shoot"):
		game_feel.on_player_shoot()


func _cleanup_materials():
	for mesh in _cached_mesh_instances:
		if is_instance_valid(mesh):
			mesh.material_override = null
			if mesh.mesh:
				for si in range(mesh.mesh.get_surface_count()):
					mesh.set_surface_override_material(si, null)
			mesh.visible = false
	for p in _cached_particles:
		if is_instance_valid(p):
			p.emitting = false
			if p.draw_pass_1 and p.draw_pass_1 is Mesh:
				p.draw_pass_1.material = null
			p.draw_pass_1 = null


func _check_destroy():
	# Solo destruir si no está pegada (las pegadas tienen su propio timer)
	if not is_stuck:
		_safe_destroy()


# Llamar ANTES de añadir al árbol
# IMPORTANTE: La velocidad se calcula y pasa desde Player.gd, no se usa internamente
func initialize(target_direction: Vector3, arrow_speed: float):
	var dir = Vector3(target_direction.x, target_direction.y, 0).normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.RIGHT

	# Usar la velocidad que viene de Player.gd directamente
	velocity = dir * arrow_speed

	var angle = atan2(dir.y, dir.x)
	rotation = Vector3(0, 0, angle)


func _crear_destello_punta() -> void:
	if _destello_punta_creado or has_node("RedTipLight"):
		_destello_punta_creado = true
		return
	_destello_punta_creado = true

	# Luz roja en la punta
	var red_light := OmniLight3D.new()
	red_light.name = "RedTipLight"
	red_light.position = Vector3(0.4, 0.0, 0.0)
	red_light.light_color = Color(1.0, 0.12, 0.08)
	red_light.light_energy = 1.0
	red_light.omni_range = 1.0
	add_child(red_light)

	# Esfera incandescente roja en la punta (material y malla cacheados)
	var tip_mesh := MeshInstance3D.new()
	tip_mesh.name = "RedTipMesh"
	tip_mesh.position = Vector3(0.42, 0.0, 0.0)

	if not _cached_tip_mesh:
		_cached_tip_mesh = SphereMesh.new()
		_cached_tip_mesh.radius = 0.06
		_cached_tip_mesh.height = 0.12

	if not _cached_tip_material:
		_cached_tip_material = StandardMaterial3D.new()
		_cached_tip_material.albedo_color = Color(1.0, 0.2, 0.1)
		_cached_tip_material.emission_enabled = true
		_cached_tip_material.emission = Color(1.0, 0.1, 0.05)
		_cached_tip_material.emission_energy_multiplier = 6.0
		_cached_tip_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	tip_mesh.mesh = _cached_tip_mesh
	tip_mesh.material_override = _cached_tip_material
	add_child(tip_mesh)


func _explotar(hit_target: Node = null) -> void:
	if _destroying:
		return

	# Screen shake doble por explosión
	var game_feel = get_tree().root.get_node_or_null("GameFeel")
	if game_feel and game_feel.has_method("on_player_shoot"):
		game_feel.on_player_shoot()
		game_feel.on_player_shoot()

	# Instanciar la escena dedicada de explosión (permite ajustar el collider visualmente)
	var explosion_scene: PackedScene = preload("res://Entities/Flecha_Explosiva/ExplosionFlechaExplosiva.tscn")
	if explosion_scene:
		var expl := explosion_scene.instantiate() as ExplosionFlechaExplosiva
		if expl:
			expl.dano_base = dano_base_explosiva
			expl.bono_dano_estructuras = bono_dano_estructuras
			expl.hit_target_directo = hit_target
			expl.tirador_origen = tirador
			expl.position = global_position
			var root := get_tree().current_scene
			if not root:
				root = get_tree().root
			root.add_child(expl)
			expl.global_position = global_position

	_safe_destroy()


func _rebotar_de_aura(body: Node) -> void:
	if _ray_ccd and is_instance_valid(body):
		_ray_ccd.add_exception(body)

	AudioManager.play_sfx("parry")

	# Impulso de rebote deflectado
	velocity.x = abs(velocity.x) * randf_range(0.4, 0.7) + 1.2
	velocity.y = randf_range(2.0, 4.5)
	velocity.z = randf_range(-0.3, 0.3)
	collision_mask = 1

	var t := get_tree().create_timer(1.2)
	t.timeout.connect(_safe_destroy)
