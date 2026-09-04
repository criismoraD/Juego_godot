class_name ExplosionFlechaExplosiva
extends Area3D

## Escena de explosión para la flecha explosiva.
## Permite ajustar el collider de daño de forma manual y visual en el editor de Godot (SphereShape3D o CylinderShape3D en CollisionShape3D).

# === CONSTANTES ===
const RADIO_DANO_POR_DEFECTO: float = 0.75  ## +30% de tamaño de collider (0.58 * 1.3 = 0.75m)
const MASCARA_COLISION_SUELO: int = 65  ## Capa 1 (Mundo) y Capa 7 (Plataformas)
const OFFSET_Y_CENIZA: float = 0.02

# === EXPORT CATEGORY: DAÑO ===
@export_category("Daño de Explosión")
@export var dano_base: float = 3.0  ## Daño base en área (3 HP)
@export var bono_dano_estructuras: float = 6.0  ## Bono contra estructuras y escudos (+6 = 9 HP total)
@export var radio_dano_override: float = -1.0  ## Si es > 0 sobrescribe el radio del CollisionShape3D

# === EXPORT CATEGORY: EFECTOS VISUALES ===
@export_category("Efectos Visuales")
@export var escena_vfx: PackedScene = preload("res://assets/BinbunVFX_Vol2/ExplosionFX/effects/air/vfx_air_explosion_01.tscn")
@export var escala_vfx: Vector3 = Vector3(0.22, 0.22, 0.22)  ## Tamaño visual completo original
@export var velocidad_vfx: float = 1.3  ## +30% de velocidad
@export var rango_luz: float = 3.6  ## Iluminación de impacto completa
@export var energia_luz: float = 2.5
@export var mostrar_debug_collider: bool = false  ## Muestra el collider magenta translúcido en el juego para depuración

# === EXPORT CATEGORY: RASTRO DE CENIZA ===
@export_category("Rastro de Ceniza")
@export var habilitar_rastro_ceniza: bool = true
@export var tamano_ceniza: Vector2 = Vector2(1.4, 1.4)  ## Marca de ceniza completa
@export var tiempo_vida_ceniza: float = 3.5
@export var tiempo_desvanecimiento_ceniza: float = 2.5

# === REFERENCIAS A NODOS ===
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D

# === STATIC CONFIG ===
static var debug_collider_global: bool = false  ## Control global para activar/desactivar el visor en tiempo de ejecución
static var suprimir_sonido_prewarm: bool = false  ## El precalentador de shaders lo activa para instanciar mudo

# === VARIABLES PÚBLICAS ===
var hit_target_directo: Node = null
var tirador_origen: Node = null  ## Quién disparó la flecha explosiva: autoría de muertes en área


func _ready() -> void:
	# 1. Reproducir sonido de explosión (mudo durante el precalentamiento de shaders)
	if not suprimir_sonido_prewarm:
		AudioManager.play_sfx("explosion_flecha_explosiva")

	# 2. Dejar marca de ceniza en el suelo
	if habilitar_rastro_ceniza:
		_crear_rastro_ceniza_suelo(global_position)

	# 3. Spawnear efecto visual
	_spawn_vfx()

	# 4. Obtener radio exacto de la forma de colisión
	var radio: float = _obtener_radio_dano()

	# 5. Dibujar collider visual magenta para depuración en tiempo real
	if mostrar_debug_collider or debug_collider_global:
		_crear_debug_collider_visual(radio)

	# 6. Procesar daño en área limitado estrictamente al radio
	_aplicar_dano_area(radio)

	# 7. Autodestrucción tras terminar el efecto
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)


func _obtener_radio_dano() -> float:
	if radio_dano_override > 0.0:
		return radio_dano_override
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is SphereShape3D:
			return (collision_shape.shape as SphereShape3D).radius * collision_shape.scale.x
		elif collision_shape.shape is CylinderShape3D:
			return (collision_shape.shape as CylinderShape3D).radius * collision_shape.scale.x
	return RADIO_DANO_POR_DEFECTO


func _crear_debug_collider_visual(radio: float) -> void:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "DebugMagentaCollider"
	var sphere := SphereMesh.new()
	sphere.radius = radio
	sphere.height = radio * 2.0
	mesh_inst.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.0, 1.0, 0.45)  # Color magenta translúcido visible
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat

	add_child(mesh_inst)
	mesh_inst.position = Vector3.ZERO

	var tween := mesh_inst.create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if is_instance_valid(mesh_inst):
			mesh_inst.queue_free()
	)


func _aplicar_dano_area(radio: float) -> void:
	var danados: Dictionary = {}

	# A. Dañar enemigos en radio
	var enemigos: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy in enemigos:
		if not is_instance_valid(enemy) or not enemy.is_inside_tree() or not enemy.is_visible_in_tree():
			continue
		if enemy.is_in_group("allies") or enemy.is_in_group("player"):
			continue

		var id_e: int = enemy.get_instance_id()
		if danados.has(id_e):
			continue

		var is_direct_hit: bool = _es_impacto_directo(enemy)
		var dist: float = _calcular_distancia_a_entidad(enemy)

		if is_direct_hit or dist <= radio:
			danados[id_e] = true
			if "last_hit_position" in enemy:
				enemy.last_hit_position = global_position
			if "last_hit_direction" in enemy:
				enemy.last_hit_direction = Vector3.RIGHT
			if "ultimo_atacante" in enemy:
				enemy.ultimo_atacante = tirador_origen

			var es_estructura: bool = (enemy is PilarLonkoBody or "es_pilar_enemigo" in enemy)
			var dmg: float = (dano_base + bono_dano_estructuras) if es_estructura else dano_base
			if "murio_por_explosion" in enemy:
				enemy.murio_por_explosion = true
			if enemy.has_method("take_damage"):
				enemy.take_damage(dmg)
			elif enemy.has_method("recibir_golpe"):
				enemy.recibir_golpe(dmg)

	# B. Dañar escudos y defensas enemigas en radio
	var escudos: Array[Node] = get_tree().get_nodes_in_group("escudos")
	for escudo in escudos:
		if not is_instance_valid(escudo) or not escudo.is_inside_tree() or not escudo.is_visible_in_tree():
			continue

		var es_defensa_enemiga: bool = false
		if "es_escudo_enemigo" in escudo:
			es_defensa_enemiga = escudo.es_escudo_enemigo
		elif "es_pilar_enemigo" in escudo:
			es_defensa_enemiga = escudo.es_pilar_enemigo
		elif escudo.is_in_group("enemies"):
			es_defensa_enemiga = true

		if not es_defensa_enemiga:
			continue

		var id_s: int = escudo.get_instance_id()
		if danados.has(id_s):
			continue

		var is_direct_hit: bool = _es_impacto_directo(escudo)
		var dist: float = _calcular_distancia_a_entidad(escudo)

		if is_direct_hit or dist <= radio:
			danados[id_s] = true
			var dmg_est: float = dano_base + bono_dano_estructuras
			if escudo.has_method("recibir_golpe"):
				escudo.recibir_golpe(int(dmg_est))
			elif escudo.has_method("take_damage"):
				escudo.take_damage(dmg_est)


func _es_impacto_directo(nodo: Node) -> bool:
	if hit_target_directo == null or not is_instance_valid(hit_target_directo):
		return false
	if nodo == hit_target_directo:
		return true
	if hit_target_directo.is_ancestor_of(nodo) or nodo.is_ancestor_of(hit_target_directo):
		return true
	# Caso especial pilar de Lonko: si el impacto directo fue contra el contenedor
	# PilarLonko (Node3D) o contra su malla hermana PILAR_LONKO, mapear al
	# PilarBody hijo correspondiente PERO solo para ese pilar especifico.
	if nodo is PilarLonkoBody or "es_pilar_enemigo" in nodo:
		var pilar_parent: Node = nodo.get_parent()
		if pilar_parent and hit_target_directo == pilar_parent:
			return true
		if is_instance_valid(hit_target_directo.get_parent()) and hit_target_directo.get_parent() == pilar_parent:
			return true
	return false


func _calcular_distancia_a_entidad(nodo: Node) -> float:
	if not (nodo is Node3D):
		return 9999.0

	var node3d := nodo as Node3D
	# Para pilares altos (PilarLonkoBody o estructuras verticales), calcular distancia al segmento vertical
	if nodo is PilarLonkoBody or "es_pilar_enemigo" in nodo:
		var base_pos: Vector3 = node3d.global_position
		var top_y: float = base_pos.y + 4.0
		var clamped_y: float = clamp(global_position.y, base_pos.y, top_y)
		var closest_pt := Vector3(base_pos.x, clamped_y, base_pos.z)
		return global_position.distance_to(closest_pt)

	return global_position.distance_to(node3d.global_position)


func _spawn_vfx() -> void:
	var vfx := get_node_or_null("vfx_air_explosion_01") as Node3D
	if not vfx and escena_vfx:
		vfx = escena_vfx.instantiate() as Node3D
		if vfx:
			add_child(vfx)

	if not vfx:
		return

	vfx.position = Vector3.ZERO
	vfx.scale = escala_vfx

	if "speed_scale" in vfx:
		vfx.speed_scale = velocidad_vfx

	for child in vfx.find_children("*", "GPUParticles3D", true, false):
		if child is GPUParticles3D:
			child.local_coords = true
			child.speed_scale = velocidad_vfx
			child.restart()
			child.emitting = true

	var anim_player := vfx.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player:
		anim_player.speed_scale = velocidad_vfx

	var light_node := vfx.get_node_or_null("VFXOmniLightBB") as OmniLight3D
	if light_node:
		light_node.omni_range = rango_luz
		light_node.light_energy = energia_luz

	if vfx.has_method("play"):
		vfx.play()


func _crear_rastro_ceniza_suelo(pos: Vector3) -> void:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3(0.0, 0.5, 0.0), pos + Vector3(0.0, -6.0, 0.0))
	query.collision_mask = MASCARA_COLISION_SUELO
	var hit := space_state.intersect_ray(query)
	var floor_pos := pos
	var floor_normal := Vector3.UP
	if hit and hit.has("position"):
		floor_pos = hit.position
		if hit.has("normal") and hit.normal.length_squared() > 0.001:
			floor_normal = hit.normal

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "RastroCenizaExplosion"
	var quad := QuadMesh.new()
	quad.size = tamano_ceniza
	mesh_inst.mesh = quad

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.06, 0.05, 0.04, 0.82)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = -2

	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(31.5, 31.5)
	for y in range(64):
		for x in range(64):
			var dist := Vector2(x, y).distance_to(center) / 31.0
			var alpha: float = clamp(1.0 - dist * dist, 0.0, 1.0)
			var noise_factor: float = sin(float(x) * 1.5) * cos(float(y) * 1.5) * 0.12
			alpha = clamp(alpha + noise_factor, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.05, 0.04, 0.03, alpha))
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mesh_inst.material_override = mat

	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	root.add_child(mesh_inst)

	VFXFactory.align_decal_to_surface(mesh_inst, floor_pos, floor_normal, OFFSET_Y_CENIZA)

	var tween := mesh_inst.create_tween()
	tween.tween_interval(tiempo_vida_ceniza)
	tween.tween_property(mat, "albedo_color:a", 0.0, tiempo_desvanecimiento_ceniza) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if is_instance_valid(mesh_inst):
			mesh_inst.queue_free()
	)
