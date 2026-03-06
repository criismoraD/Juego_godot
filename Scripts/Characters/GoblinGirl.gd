extends EnemyBase
class_name GoblinGirl

## Goblin Girl: Camina, se detiene y dispara flechas parabólicas con arco.
## Se diferencia del Goblin en: proyectil parabólico, timing de disparo
## sincronizado con animación, potencia variable, y animaciones de arco.
## Algunas se agachan al disparar (animación AGACHADA).

# === CONFIGURACIÓN ESPECÍFICA DE GOBLIN GIRL ===
@export_category("Combate - GoblinGirl")
@export var tiempo_disparo_en_animacion: float = 4.0
@export var pausa_entre_disparos: float = 0.1
@export var potencia_disparo_min: float = 1.0
@export var potencia_disparo_max: float = 2.0

@export_category("Agacharse")
@export var probabilidad_agacharse: float = 0.3
@export var tiempo_disparo_agachada: float = 4.0

# === ESTADO ESPECÍFICO ===
var anim_timer: float = 0.0
var has_fired_this_cycle: bool = false
var esta_agachada: bool = false

# === REFERENCIAS ESPECÍFICAS ===
var goblin_girl_arrow_scene = preload("res://Scenes/Projectiles/GoblinGirlArrow.tscn")
var bow_anim_player: AnimationPlayer = null
var girl_anim_tree: AnimationTree = null

# ═══════════════════════════════════════════════════════════════════════════════
# HOOKS DE ENEMYBASE
# ═══════════════════════════════════════════════════════════════════════════════

func _on_enemy_ready():
	# Valores por defecto distintos al Goblin base
	color_borde_disolucion = Color(0.8, 0.2, 0.8) # Púrpura

	# Decidir aleatoriamente si esta GoblinGirl se agacha al disparar
	esta_agachada = randf() < probabilidad_agacharse

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

func _on_state_walking():
	if girl_anim_tree:
		girl_anim_tree.active = false
	_play_animation("GIRL_GOB_CAMINA")
	_play_bow_animation("ARCO_IDLE")

func _on_state_shooting():
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

func _on_state_dying():
	if girl_anim_tree:
		girl_anim_tree.active = false
	super._on_state_dying()
	AudioManager.play_sfx("goblin_girl_death")

	# Elegir aleatoriamente entre las 3 animaciones de muerte
	var death_anims = ["MUERTE1", "MUERTE2", "MUERTE3"]
	var chosen_death = death_anims[randi() % death_anims.size()]
	var anim_length = _get_animation_duration(chosen_death)
	_play_animation(chosen_death)

	get_tree().create_timer(anim_length + 0.5).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_die()
	)

func _on_pacifico_detenido():
	# Congelar en la pose de disparo (frame 1) al detenerse en modo pacífico
	if girl_anim_tree:
		girl_anim_tree.active = false
	_play_animation("GIRL_GOB_DISPARO", -1.0, 0.0) # speed 0 = congelada
	if anim_player:
		anim_player.seek(0.033, true) # Frame 1 (~1/30s)
	_play_bow_animation("ARCO_TENSAR")

# ═══════════════════════════════════════════════════════════════════════════════
# TRACKING (en _process para no ser sobrescrito por animación)
# ═══════════════════════════════════════════════════════════════════════════════

func _process(_delta):
	if current_state == State.SHOOTING and rastrear_jugador:
		_track_player()

# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO
# ═══════════════════════════════════════════════════════════════════════════════

func _process_shooting(delta):
	velocity.x = 0

	# Incrementar timer de animación
	anim_timer += delta

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
		shoot_timer -= delta
		if shoot_timer <= 0:
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

	var arrow = goblin_girl_arrow_scene.instantiate()
	
	# Usar el mismo color que las partículas de muerte (púrpura)
	arrow.color_proyectil = color_borde_disolucion

	var spawn_pos = global_position + Vector3(-0.3, altura_spawn_flecha, 0)
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

	get_tree().root.add_child(arrow)
	arrow.global_position = spawn_pos

	AudioManager.play_sfx("goblin_girl_shoot")

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
		"mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2",
		"mixamorig_Neck", "mixamorig_Head", "mixamorig_HeadTop_End",
		"mixamorig_LeftShoulder", "mixamorig_RightShoulder",
		"mixamorig_LeftArm", "mixamorig_RightArm",
		"mixamorig_LeftForeArm", "mixamorig_RightForeArm",
		"mixamorig_LeftHand", "mixamorig_RightHand",
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
	girl_anim_tree.active = false # Inactivo hasta que sea necesario

func _find_anim_name(base_name: String) -> StringName:
	"""Busca el nombre real de la animación con posibles prefijos del FBX"""
	if not anim_player:
		return base_name
	for anim_name in anim_player.get_animation_list():
		if base_name in anim_name:
			return anim_name
	return base_name
