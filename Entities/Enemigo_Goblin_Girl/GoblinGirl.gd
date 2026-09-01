class_name GoblinGirl
extends "res://System/Core/EnemyBase.gd"

const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")
const PROJECTILE_SCALE: Vector3 = Vector3.ONE
const TEXTURA_HUMO_PISADAS: Texture2D = preload("res://VFX/Textures/Smoke/Humo_Pisadas_1A-1.png")
const HUMO_PISADAS_FRAMES_H: int = 9
const HUMO_PISADAS_FRAMES_V: int = 1
var _particulas_pisada: GPUParticles3D = null

## Goblin Girl: Camina, se detiene y dispara flechas parabólicas con arco.
## Se diferencia del Goblin en: proyectil parabólico, timing de disparo
## sincronizado con animación, potencia variable, y animaciones de arco.
## Algunas se agachan al disparar (animación AGACHADA).
# === CONFIGURACIÓN ESPECÍFICA DE GOBLIN GIRL ===
@export_category("Combate - GoblinGirl")
@export var tiempo_disparo_en_animacion: float = 3.1
@export var tiempo_tensa_arco: float = 1.9
@export var pausa_entre_disparos: float = 0.1
@export var potencia_disparo_min: float = 1.0
@export var potencia_disparo_max: float = 2.0
@export_category("Agacharse")
@export var probabilidad_agacharse: float = 0.3
@export var tiempo_disparo_agachada: float = 3.1
@export_category("Visual - Flecha en Mano")
@export var mostrar_flecha_en_mano: bool = true
@export var offset_flecha_mano: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var rotacion_flecha_mano_grados: Vector3 = Vector3(90.0, 0.0, 0.0)
@export var escala_flecha_mano: Vector3 = Vector3(1.0, 1.0, 1.0)
# === ESTADO ESPECÍFICO ===
var anim_timer: float = 0.0
var has_fired_this_cycle: bool = false
var esta_agachada: bool = false
var en_animacion_disparo: bool = false
var murio_por_explosion: bool = false  ## Marcado por FlechaExplosiva: impulso en parábola al morir
var _impulso_explosivo_activo: bool = false  ## True durante el vuelo parabólico del cadáver
# === REFERENCIAS ESPECÍFICAS ===
var goblin_girl_arrow_scene = preload("res://Entities/Proyectil_Flecha_Goblin_Girl/GoblinGirlArrow.tscn")
var escena_flecha_visual_mano = preload("res://Entities/Proyectil_Flecha_Goblin_Girl/GoblinGirlArrow.tscn")
var bow_anim_player: AnimationPlayer = null
var girl_anim_tree: AnimationTree = null
var attachment_flecha_mano: BoneAttachment3D = null
var flecha_visual_mano: Node3D = null
var escala_original_flecha_mano: Vector3 = Vector3.ONE
var escala_original_global_flecha_mano: Vector3 = Vector3.ONE
## Pose local base de la flecha en mano (la afinada en el editor o la creada
## por código). Fuente de verdad para restaurar durante la animación de disparo,
## en lugar de pisar la posición con offset_flecha_mano (= 0,0,0 por defecto).
var _pose_base_flecha_mano: Transform3D = Transform3D.IDENTITY
# ═══════════════════════════════════════════════════════════════════════════════
# HOOKS DE ENEMYBASE
# ═══════════════════════════════════════════════════════════════════════════════


func _on_enemy_ready():
	# Valores por defecto distintos al Goblin base
	color_borde_disolucion = Color(0.8, 0.2, 0.8)  # Púrpura

	# Decidir aleatoriamente si esta GoblinGirl se agacha al disparar
	esta_agachada = randf() < probabilidad_agacharse

	# Configurar la flecha en la mano al iniciar
	_configurar_flecha_visual_mano()
	en_animacion_disparo = false
	_actualizar_visibilidad_flecha_mano(false)

	# Buscar AnimationPlayer del arco
	var bow_node = find_child("ARCO_GOBLING_GIRL", true, false)
	if bow_node:
		var bow_players = bow_node.find_children("*", "AnimationPlayer", true, false)
		if bow_players.size() > 0:
			bow_anim_player = bow_players[0]

	# Verificar que anim_player es el principal (no el del arco)
	# EnemyBase usa find_child que puede encontrar el del arco primero
	if anim_player and not _has_main_animation(anim_player):
		var all_players = find_children("*", "AnimationPlayer", true, false)
		for player in all_players:
			if player != bow_anim_player and _has_main_animation(player):
				anim_player = player
				break

	# Configurar loop en animación de caminar (no se hizo si EnemyBase encontró el AP incorrecto)
	if anim_player:
		for anim_name_full in anim_player.get_animation_list():
			if "CAMINA" in anim_name_full or "CAMINAR" in anim_name_full:
				var anim = anim_player.get_animation(anim_name_full)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR

	_play_animation("GIRL_GOB_CAMINA")
	_play_bow_animation("ARCO_IDLE")

	# Crear AnimationTree para mezcla crouch + shoot (split-body)
	_setup_animation_tree()
	_configurar_particulas_pisada()
	set_process(true)


func _configurar_particulas_pisada() -> void:
	if _particulas_pisada and is_instance_valid(_particulas_pisada):
		return
	_particulas_pisada = GPUParticles3D.new()
	_particulas_pisada.name = "Particulas_Pisada"
	_particulas_pisada.emitting = false
	_particulas_pisada.amount = 10
	_particulas_pisada.lifetime = 0.9
	_particulas_pisada.visibility_aabb = AABB(Vector3(-1, -0.2, -1), Vector3(2, 1.5, 2))
	add_child(_particulas_pisada)
	_particulas_pisada.position = Vector3(0, 0.05, 0)
	var mat := StandardMaterial3D.new()
	if TEXTURA_HUMO_PISADAS:
		mat.albedo_texture = TEXTURA_HUMO_PISADAS
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
	mesh.size = Vector2(0.393, 0.393)
	_particulas_pisada.draw_pass_1 = mesh
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 50.0
	pm.initial_velocity_min = 0.12
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0.0, 0.12, 0.0)
	pm.scale_min = 0.486
	pm.scale_max = 0.788
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.096, 0.012, 0.096)
	pm.anim_speed_min = 1.0
	pm.anim_speed_max = 1.0
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0
	var grad := Gradient.new()
	grad.set_color(0, Color(0.5, 0.5, 0.5, 0.6))
	grad.set_color(1, Color(0.5, 0.5, 0.5, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pm.color_ramp = grad_tex
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.25), 0.0, 1.2)
	curve.add_point(Vector2(0.3, 1.0), 0.2, -0.4)
	curve.add_point(Vector2(0.65, 0.6), -0.6, -0.8)
	curve.add_point(Vector2(1.0, 0.0), -1.2, 0.0)
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	pm.scale_curve = curve_tex
	_particulas_pisada.process_material = pm


func _particulas_pisada_emitir() -> void:
	if not _particulas_pisada or not is_instance_valid(_particulas_pisada):
		return
	var corriendo := current_state == State.WALKING or velocity.length_squared() > 0.04
	_particulas_pisada.emitting = corriendo and current_state != State.DYING and current_state != State.DEAD


func _on_state_walking():
	if girl_anim_tree:
		girl_anim_tree.active = false
	en_animacion_disparo = false
	_actualizar_visibilidad_flecha_mano(false)
	_play_animation("GIRL_GOB_CAMINA")
	_play_bow_animation("ARCO_IDLE")


func _on_state_shooting():
	en_animacion_disparo = true
	if esta_agachada and girl_anim_tree:
		# Activar AnimationTree: piernas agachadas + torso disparando
		girl_anim_tree.active = true
	else:
		if girl_anim_tree:
			girl_anim_tree.active = false
		_play_animation("GIRL_GOB_DISPARO")
	_play_bow_animation("ARCO_TENSAR")
	anim_timer = 0.0
	has_fired_this_cycle = false
	shoot_timer = pausa_entre_disparos
	_actualizar_visibilidad_flecha_mano(false)


func _on_state_dying():
	if girl_anim_tree:
		girl_anim_tree.active = false
	super._on_state_dying()
	en_animacion_disparo = false
	_actualizar_visibilidad_flecha_mano(false)
	AudioManager.play_sfx("goblin_girl_death")

	# Muerte por explosión: mantener la animación normal pero el cuerpo
	# recibe el impulso (se eleva un poco y cae en parábola hacia la derecha)
	if murio_por_explosion:
		_aplicar_impulso_explosivo()
		_lanzar_arco_explosivo()
		murio_por_explosion = false

	# Elegir aleatoriamente entre las 3 animaciones de muerte
	var death_anims = ["MUERTE1", "MUERTE2", "MUERTE3"]
	var chosen_death = death_anims[randi() % death_anims.size()]
	var anim_length = _get_animation_duration(chosen_death)
	_play_animation(chosen_death)

	get_tree().create_timer(anim_length + 0.5).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_die()
	)


## Impulso de la explosión: reactiva la física del cuerpo y le da un pequeño
## salto hacia arriba con empuje lateral. La gravedad del EnemyBase dibuja la
## parábola mientras suena la animación de muerte normal.
func _aplicar_impulso_explosivo() -> void:
	_impulso_explosivo_activo = true
	set_physics_process(true)
	collision_layer = 0  # Nadie colisiona contra el cadáver
	collision_mask = 1   # Pero él sí colisiona contra el suelo para aterrizar

	# Dirección de expulsión según el punto de impacto de la explosión
	var push_dir: float = 1.0
	if last_hit_position != Vector3.ZERO:
		var dx: float = global_position.x - last_hit_position.x
		if absf(dx) > 0.05:
			push_dir = signf(dx)

	velocity.x = push_dir * randf_range(1.6, 2.4)  # Caer hacia la derecha
	velocity.y = randf_range(2.0, 2.8)             # Elevarse un poco
	velocity.z = 0.0


## Durante la muerte con impulso: conserva el empuje lateral en el aire y
## frena al aterrizar para que no patine; la gravedad la aplica el EnemyBase.
func _process_dying(delta: float) -> void:
	if not _impulso_explosivo_activo:
		velocity.x = 0
		return

	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 0.8)


## Muerte por explosión: el arco se desprende de la mano y sale volando
## en parábola girando sobre sí mismo (mismo patrón que la ballesta del Goblin).
func _lanzar_arco_explosivo() -> void:
	var arco := find_child("ARCO_GOBLING_GIRL", true, false) as Node3D
	if not arco:
		return

	var root_scene := get_tree().current_scene
	if not root_scene:
		root_scene = get_tree().root

	# Dirección de expulsión según el punto de impacto de la explosión
	var push_dir: float = 1.0
	if last_hit_position != Vector3.ZERO:
		var dx: float = global_position.x - last_hit_position.x
		if absf(dx) > 0.05:
			push_dir = signf(dx)

	var tr_arco: Transform3D = arco.global_transform
	arco.get_parent().remove_child(arco)

	var contenedor := GoblinPiezaFisica.new()
	root_scene.add_child(contenedor)
	contenedor.global_transform = tr_arco

	arco.transform = Transform3D.IDENTITY
	arco.visible = true
	# Limpiar overrides (disolución/daño) para que el arco conserve su material
	for m in arco.find_children("*", "MeshInstance3D", true, false):
		m.visible = true
		m.material_override = null
	contenedor.add_child(arco)

	contenedor.iniciar_vuelo(
		Vector3(push_dir * randf_range(2.0, 3.6), randf_range(3.8, 5.6), 0.0),
		randf_range(-14.0, 14.0)
	)


func take_damage(amount: float) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	# Ocultar la flecha de la mano inmediatamente si es dañada o muere
	en_animacion_disparo = false
	_actualizar_visibilidad_flecha_mano(false)

	super.take_damage(amount)


func _on_pacifico_detenido():
	# Congelar en la pose de disparo (frame 1) al detenerse en modo pacífico
	if girl_anim_tree:
		girl_anim_tree.active = false
	_play_animation("GIRL_GOB_DISPARO", -1.0, 0.0)  # speed 0 = congelada
	if anim_player:
		anim_player.seek(0.033, true)  # Frame 1 (~1/30s)
	_play_bow_animation("ARCO_TENSAR")


# ═══════════════════════════════════════════════════════════════════════════════
# TRACKING (en _process para no ser sobrescrito por animación)
# ═══════════════════════════════════════════════════════════════════════════════


func _process(delta):
	super._process(delta)
	if _particulas_pisada:
		_particulas_pisada_emitir()
	if current_state == State.SHOOTING and rastrear_jugador:
		_track_player()


# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO
# ═══════════════════════════════════════════════════════════════════════════════


func _process_shooting(delta):
	velocity.x = 0

	# Incrementar timer de animación
	anim_timer += delta
	_actualizar_flecha_mano_durante_animacion()

	# Timing del disparo: siempre basado en GIRL_GOB_DISPARO (torso superior)
	var disparo_time = tiempo_disparo_en_animacion

	# Disparar en el momento exacto de la animación
	if not has_fired_this_cycle and anim_timer >= disparo_time:
		_shoot_arrow()
		_play_bow_animation("ARCO_DISPARO")
		has_fired_this_cycle = true

	# El ciclo se basa en la animación GIRL_GOB_DISPARO (el torso manda)
	var anim_duration = _get_animation_duration("GIRL_GOB_DISPARO")
	if anim_timer >= anim_duration:
		en_animacion_disparo = false
		_actualizar_visibilidad_flecha_mano(false)
		shoot_timer -= delta
		if shoot_timer <= 0:
			en_animacion_disparo = true
			anim_timer = 0.0
			has_fired_this_cycle = false
			shoot_timer = pausa_entre_disparos
			if esta_agachada and girl_anim_tree:
				# Reiniciar animaciones del tree al inicio del ciclo
				girl_anim_tree.set("parameters/Seek/seek_request", 0.0)
			else:
				_play_animation("GIRL_GOB_DISPARO")
			_play_bow_animation("ARCO_TENSAR")


func _shoot_arrow():
	if not goblin_girl_arrow_scene:
		push_error("[GoblinGirl] No arrow scene!")
		return

	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return

	if player_ref.get("is_dead"):
		return

	var arrow := PROJECTILE_POOL_REF.acquire(goblin_girl_arrow_scene) as GoblinGirlArrowProjectile
	if not arrow:
		return

	arrow.scale = escala_original_global_flecha_mano
	arrow.color_proyectil = GoblinGirlArrowProjectile.GOBLIN_GIRL_ARROW_MAGENTA

	var spawn_pos: Vector3
	if flecha_visual_mano and is_instance_valid(flecha_visual_mano) and flecha_visual_mano.visible:
		spawn_pos = flecha_visual_mano.global_position
	else:
		spawn_pos = global_position + Vector3(-0.3, altura_spawn_flecha, 0)
	var target_pos = player_ref.global_position + Vector3(0, 0.5, 0)
	var diff = target_pos - spawn_pos
	var base_direction = diff.normalized()

	# Añadir arco parabólico según distancia
	var horizontal_dist = abs(diff.x)
	var arc_compensation = clamp(horizontal_dist * 0.15, 0.1, 0.5)
	var direction = Vector3(base_direction.x, base_direction.y + arc_compensation, 0).normalized()

	# Potencia aleatoria dentro del rango configurado
	var potencia = randf_range(potencia_disparo_min, potencia_disparo_max)
	arrow.initialize(direction, potencia)
	arrow.set_meta("shooter", self)

	PROJECTILE_POOL_REF.activate(arrow, get_tree().root, spawn_pos)

	AudioManager.play_sfx("goblin_girl_shoot")
	_actualizar_visibilidad_flecha_mano(false)


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMACIÓN DEL ARCO
# ═══════════════════════════════════════════════════════════════════════════════


func _play_bow_animation(anim_name: String, custom_blend: float = -1.0):
	if not bow_anim_player:
		return

	# Intentar con distintos prefijos (depende de cómo Godot importó el GLB)
	var prefixes = ["", "ENEMY|", "ENEMY| ", "Recurve Bow 2 Armature|"]
	for prefix in prefixes:
		var full_name = prefix + anim_name
		if bow_anim_player.has_animation(full_name):
			bow_anim_player.play(full_name, custom_blend)
			return

	# Fallback: buscar por contenido del nombre
	for a in bow_anim_player.get_animation_list():
		if anim_name in a:
			bow_anim_player.play(a, custom_blend)
			return


# ═══════════════════════════════════════════════════════════════════════════════
# UTILIDADES
# ═══════════════════════════════════════════════════════════════════════════════


## Verifica si un AnimationPlayer tiene las animaciones principales de la GoblinGirl
func _has_main_animation(player: AnimationPlayer) -> bool:
	for anim_name in player.get_animation_list():
		if "GIRL_GOB_CAMINA" in anim_name:
			return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATION TREE (Split-Body: Piernas agachadas + Torso disparando)
# ═══════════════════════════════════════════════════════════════════════════════


func _setup_animation_tree():
	if not anim_player or not skeleton:
		return

	girl_anim_tree = AnimationTree.new()
	girl_anim_tree.name = "GoblinGirlAnimTree"
	add_child(girl_anim_tree)

	# Conectar al AnimationPlayer principal
	girl_anim_tree.anim_player = girl_anim_tree.get_path_to(anim_player)

	# Root node = el nodo raíz del AnimationPlayer para resolver paths de tracks
	var ap_root = anim_player.get_node(anim_player.root_node)
	girl_anim_tree.root_node = girl_anim_tree.get_path_to(ap_root)

	# === Construir BlendTree ===
	var root = AnimationNodeBlendTree.new()

	# Animación de agacharse (cuerpo completo, base)
	var node_crouch = AnimationNodeAnimation.new()
	node_crouch.animation = _find_anim_name("AGACHADA")
	root.add_node("CrouchAnim", node_crouch)

	# Animación de disparo (se aplicará SOLO al torso superior)
	var node_shoot = AnimationNodeAnimation.new()
	node_shoot.animation = _find_anim_name("GIRL_GOB_DISPARO")
	root.add_node("ShootAnim", node_shoot)

	# Blend2: mezcla crouch (lower) + shoot (upper) con filtro de huesos
	var blend = AnimationNodeBlend2.new()
	blend.filter_enabled = true

	# Path al Skeleton3D relativo al root_node del tree
	var skel_path = str(ap_root.get_path_to(skeleton))

	# Huesos del torso superior (Mixamo rig)
	var upper_bones: Array[String] = [
		"mixamorig_Spine",
		"mixamorig_Spine1",
		"mixamorig_Spine2",
		"mixamorig_Neck",
		"mixamorig_Head",
		"mixamorig_HeadTop_End",
		"mixamorig_LeftShoulder",
		"mixamorig_RightShoulder",
		"mixamorig_LeftArm",
		"mixamorig_RightArm",
		"mixamorig_LeftForeArm",
		"mixamorig_RightForeArm",
		"mixamorig_LeftHand",
		"mixamorig_RightHand",
	]

	# Añadir huesos de dedos si existen en el rig
	for side in ["Left", "Right"]:
		for finger in ["Index", "Middle", "Ring", "Pinky", "Thumb"]:
			for idx in ["1", "2", "3"]:
				upper_bones.append("mixamorig_%sHand%s%s" % [side, finger, idx])

	# Aplicar filtro solo para huesos que existen en el skeleton
	for bone in upper_bones:
		if skeleton.find_bone(bone) != -1:
			blend.set_filter_path(NodePath("%s:%s" % [skel_path, bone]), true)

	root.add_node("UpperBlend", blend)
	root.connect_node("UpperBlend", 0, "CrouchAnim")
	root.connect_node("UpperBlend", 1, "ShootAnim")

	# TimeSeek para poder reiniciar animaciones al inicio de cada ciclo
	var seek = AnimationNodeTimeSeek.new()
	root.add_node("Seek", seek)
	root.connect_node("Seek", 0, "UpperBlend")

	# Salida
	root.connect_node("output", 0, "Seek")

	girl_anim_tree.tree_root = root
	girl_anim_tree.set("parameters/UpperBlend/blend_amount", 1.0)
	girl_anim_tree.active = false  # Inactivo hasta que sea necesario


func _find_anim_name(base_name: String) -> StringName:
	"""Busca el nombre real de la animación con posibles prefijos del FBX"""
	if not anim_player:
		return base_name
	for anim_name in anim_player.get_animation_list():
		if base_name in anim_name:
			return anim_name
	return base_name


func _configurar_flecha_visual_mano():
	# ── 1. Buscar una "FlechaMano" ya colocada manualmente en la escena ──
	flecha_visual_mano = find_child("FlechaMano", true, false) as Node3D
	if flecha_visual_mano:
		flecha_visual_mano.visible = false
		escala_original_flecha_mano = flecha_visual_mano.scale
		# Capturar la pose afinada en el editor: la animación de disparo debe
		# restaurar ESTA pose, no offset_flecha_mano (que vale 0,0,0 por defecto).
		_pose_base_flecha_mano = flecha_visual_mano.transform
		# Incrementado en un 10% según solicitud del usuario
		escala_original_global_flecha_mano = (flecha_visual_mano.global_transform.basis.get_scale() * 1.10).abs()
		return

	# ── 2. Si no existe, crearla programáticamente como fallback ──
	if not mostrar_flecha_en_mano:
		return

	var esqueleto_nodo: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D
	if not esqueleto_nodo:
		push_warning("[GoblinGirl] No se encontró Skeleton3D para crear FlechaMano")
		return

	var nombre_hueso: String = _obtener_hueso_mano(esqueleto_nodo)
	if nombre_hueso.is_empty():
		push_warning("[GoblinGirl] No se encontró hueso de mano en el esqueleto")
		return

	attachment_flecha_mano = BoneAttachment3D.new()
	attachment_flecha_mano.name = "AttachmentFlechaMano"
	esqueleto_nodo.add_child(attachment_flecha_mano)
	attachment_flecha_mano.bone_name = nombre_hueso

	flecha_visual_mano = _crear_visual_flecha_mano()
	if not flecha_visual_mano:
		push_warning("[GoblinGirl] No se pudo crear la flecha visual de mano")
		return
	attachment_flecha_mano.add_child(flecha_visual_mano)

	flecha_visual_mano.position = offset_flecha_mano
	flecha_visual_mano.rotation_degrees = rotacion_flecha_mano_grados
	flecha_visual_mano.scale = escala_flecha_mano
	_pose_base_flecha_mano = flecha_visual_mano.transform
	# Forzar actualización de transform para que calcule la escala global
	flecha_visual_mano.force_update_transform()
	escala_original_flecha_mano = escala_flecha_mano
	# Incrementado en un 10% según solicitud del usuario
	escala_original_global_flecha_mano = (flecha_visual_mano.global_transform.basis.get_scale() * 1.10).abs()
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


func _actualizar_visibilidad_flecha_mano(visible_flecha: bool):
	if not flecha_visual_mano or not is_instance_valid(flecha_visual_mano):
		return
	flecha_visual_mano.visible = visible_flecha and mostrar_flecha_en_mano


func _actualizar_flecha_mano_durante_animacion():
	if not en_animacion_disparo or not flecha_visual_mano or not is_instance_valid(flecha_visual_mano):
		return

	var anim_time_scaled: float = anim_timer
	var tiempo_tensa: float = tiempo_tensa_arco
	var tiempo_disparo: float = tiempo_disparo_en_animacion

	# Mostrar la flecha durante la fase de tensión del arco
	if anim_time_scaled >= tiempo_tensa and anim_time_scaled < tiempo_disparo and not has_fired_this_cycle:
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
			flecha_visual_mano.position = _pose_base_flecha_mano.origin + Vector3(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)
		else:
			flecha_visual_mano.position = _pose_base_flecha_mano.origin
	else:
		flecha_visual_mano.visible = false
		flecha_visual_mano.position = _pose_base_flecha_mano.origin


func _ease_out_back(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
