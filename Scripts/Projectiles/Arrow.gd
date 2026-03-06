extends Area3D
class_name ArrowProjectile

# === CONFIGURACIÓN (Español) ===
@export_category("Física")
@export var escala_gravedad: float = 1.0 # Multiplicador de gravedad
@export var tiempo_vida: float = 10.0 # Tiempo antes de destruirse
@export var tiempo_pegada: float = 5.0 # Tiempo antes de desaparecer cuando está pegada

# === TIPO DE FLECHA ===
enum TipoFlecha {JUGADOR, ENEMIGO}
@export var tipo_dueño: TipoFlecha = TipoFlecha.JUGADOR

# === ESTADO INTERNO ===
var velocity: Vector3 = Vector3.ZERO
var power: float = 0.0
var world_gravity: float = 0.0
var is_stuck: bool = false
var _destroying: bool = false

func _ready():
	world_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	
	# Inicializar RayCast para detección continua (anti-tunneling)
	var ray = RayCast3D.new()
	ray.name = "RayCastCCD"
	ray.enabled = true
	ray.target_position = Vector3.ZERO # Se actualiza cada frame
	ray.collision_mask = collision_mask # Usar la misma máscara
	ray.exclude_parent = true
	ray.collide_with_areas = true # También detectar áreas (como ArrowDetector)
	ray.collide_with_bodies = true
	add_child(ray)
	
	# Timer de destrucción (si no se pega antes)
	get_tree().create_timer(tiempo_vida).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_check_destroy()
	)
	
	# Conectar colisiones
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta):
	if is_stuck:
		return # No mover si está pegada
	
	# 1. Aplicar gravedad
	velocity.y -= world_gravity * escala_gravedad * delta
	
	# 2. Forzar Z = 0 (2.5D)
	velocity.z = 0
	
	# --- CCD Detection (RayCast) ---
	var ray = get_node_or_null("RayCastCCD")
	if ray:
		# Convertir vector de velocidad (World) a local para el raycast
		# Predecimos dónde estará en el siguiente frame
		var next_pos = global_position + velocity * delta
		ray.target_position = to_local(next_pos)
		ray.force_raycast_update()
		
		if ray.is_colliding():
			var collider = ray.get_collider()
			# Si detectamos colisión, nos movemos al punto de impacto
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
	var camera = get_viewport().get_camera_3d()
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
	elif global_position.y < -20:
		_safe_destroy()

func _on_body_entered(body):
	if is_stuck:
		return
	
	# Ignorar al jugador si es flecha del jugador (para que no se pegue al salir)
	if tipo_dueño == TipoFlecha.JUGADOR and body.is_in_group("player"):
		return
	
	# Las flechas del JUGADOR ignoran escudos (los atraviesan)
	# Solo las flechas enemigas interactúan con escudos
	if tipo_dueño == TipoFlecha.ENEMIGO and body.has_method("recibir_golpe"):
		body.recibir_golpe()
		_safe_destroy()
		return
	
	# Si es flecha del jugador y encuentra un escudo, ignorarlo
	if tipo_dueño == TipoFlecha.JUGADOR and body.is_in_group("escudos"):
		return
	
	# Ignorar aliados (NPC) — las flechas los atraviesan
	if body.is_in_group("allies"):
		return
	
	# Verificar si es un suelo o plataforma (StaticBody3D o AnimatableBody3D)
	# Las flechas del jugador se pegan a plataformas desde cualquier dirección
	if body is StaticBody3D or body is AnimatableBody3D:
		_stick_to_surface()
		return
	
	# Verificar si es un objetivo válido
	if tipo_dueño == TipoFlecha.JUGADOR:
		# Las flechas del jugador dañan enemigos - daño fijo de 1
		if body.has_method("take_damage") and body.is_in_group("enemies"):
			# Guardar posición del impacto para las partículas de sangre
			if body.has_method("set") and "last_hit_position" in body:
				body.last_hit_position = global_position
			body.take_damage(1.0)
			_safe_destroy()
	elif tipo_dueño == TipoFlecha.ENEMIGO:
		# Las flechas del enemigo dañan al jugador
		if body.has_method("take_damage") and body.is_in_group("player"):
			body.take_damage(1.0)
			_safe_destroy()

func _on_area_entered(area: Area3D):
	if is_stuck:
		return
	
	# Detectar ArrowDetector de PlataformaOneway para pegar la flecha
	if area.name == "ArrowDetector":
		# Buscar el AnimatableBody3D padre (la plataforma)
		var platform = area.get_parent()
		if platform and (platform is AnimatableBody3D or platform is StaticBody3D):
			_stick_to_surface()
			return

func _stick_to_surface():
	is_stuck = true
	velocity = Vector3.ZERO
	
	# Desactivar colisiones para no seguir detectando (usar set_deferred para evitar errores)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Detener partículas de estela si existen
	var trail = get_node_or_null("TrailParticles")
	if trail:
		trail.emitting = false
	
	# Programar destrucción después de un tiempo
	get_tree().create_timer(tiempo_pegada).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_cleanup_materials()
			queue_free()
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
	position = relative_pos * 2.0 # Ajustar escala por skeleton
	
	# Conectar señal de muerte del enemigo para auto-destruirse
	if enemy.has_signal("died"):
		enemy.died.connect(func():
			if is_instance_valid(self):
				_cleanup_materials()
				queue_free()
		)
	
	# Timer de destrucción
	get_tree().create_timer(tiempo_pegada).timeout.connect(func():
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
		enemy.died.connect(func():
			if is_instance_valid(self):
				_cleanup_materials()
				queue_free()
		)
	
	# Destruir después de un tiempo
	get_tree().create_timer(tiempo_pegada).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_cleanup_materials()
			queue_free()
	)

func _safe_destroy():
	if _destroying:
		return
	_destroying = true
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
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			queue_free()
	)

func _cleanup_materials():
	var meshes = find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		if is_instance_valid(mesh):
			mesh.material_override = null
			if mesh.mesh:
				for si in range(mesh.mesh.get_surface_count()):
					mesh.set_surface_override_material(si, null)
			mesh.visible = false
	var particles = find_children("*", "GPUParticles3D", true, false)
	for p in particles:
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
