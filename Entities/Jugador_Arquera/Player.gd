class_name Player
extends CharacterBody3D
signal health_changed(new_health: int)
signal flechas_explosivas_changed(cantidad: int)
signal flechas_multiples_changed(cantidad: int)
signal died
enum AimState { NONE, DRAWING, AIMING, SHOOTING }
enum MoveState { GROUND, AIR, LANDING, CLIMBING, DEAD, CROUCHING }
const CameraUtilsRef = preload("res://System/Utils/CameraUtils.gd")
# === CONFIGURACIÓN - MOVIMIENTO ===
const COYOTE_TIME: float = 0.15
const JUMP_BUFFER_TIME: float = 0.12
# === SEÑALES ===
@export_category("Munición Especial")
@export var flechas_explosivas: int = 0:
	set(v):
		flechas_explosivas = v
		_actualizar_throttle_explosivo()  ## Histéresis 30/25
@export var flechas_multiples: int = 0
## Throttle de drops explosivos: 30 entra en mitigación, 25 libera (histéresis para evitar flapping)
var _explosive_drop_throttled: bool = false
const UMBRAL_EXPLOSIVO_MAX: int = 30
const UMBRAL_EXPLOSIVO_RELEASE: int = 25
const DROP_CHANCE_MITIGADO: float = 0.05

@export_category("Movimiento")
@export var velocidad_caminar: float = 0.5  # Velocidad al caminar
@export var velocidad_correr: float = 1.0  # Velocidad al correr
@export var fuerza_salto: float = 2.35  # Fuerza del salto
@export var umbral_aterrizaje: float = -3.0  # Umbral para aterrizaje fuerte
@export var velocidad_giro_suave: float = 12.0  ## Velocidad de interpolación de giro al cambiar de dirección
@export var aceleracion_movimiento: float = 12.0  ## Suavizado de aceleración y desaceleración horizontal
# === CONFIGURACIÓN - DISPARO ===
@export_category("Disparo")
@export var multiplicador_velocidad_disparo: float = 1.0  # Velocidad de animaciones de disparo
@export var cadencia_disparo: float = 0.2  # Tiempo mínimo de cooldown entre disparos (0.2s)
@export var tiempo_tensar: float = 0.2  # Tiempo para tensar el arco (0.2s)
@export var duracion_carga: float = 0.7  # Tiempo para cargar al 100% de potencia y largo alcance (0.7s)
@export var velocidad_recarga: float = 2.0  # Multiplicador de velocidad de recarga (draw→aim→shoot)
@export var velocidad_flecha_minima: float = 2.5  # Velocidad mínima de la flecha (clic rápido)
@export var velocidad_flecha_maxima: float = 15.0  # Velocidad máxima de la flecha (carga completa)
@export var Reduccion_Velocidad_Por_Angulo: float = 0.35  # Reducción de velocidad por ángulo vertical de disparo
# === CONFIGURACIÓN - APUNTADO ===
@export_category("Apuntado")
@export_range(-90, 90, 0.1) var angulo_minimo: float = -45.0  # Ángulo mínimo de apuntado
@export_range(-90, 90, 0.1) var angulo_maximo: float = 70.0  # Ángulo máximo de apuntado
@export var invertir_angulo: bool = true
@export var altura_barra: float = 0.7  # Altura de la barra de carga
@export_range(-180, 180, 1.0) var rotacion_torso_escalera: float = 0.0  # Giro del torso al disparar en escalera
@export var invertir_pitch_escalera: bool = true  # Invertir dirección de apuntado en escalera
@export_range(-10.0, 10.0, 0.1) var multiplicador_inversion_pitch: float = -2.0  # Multiplicador de inversión en escalera
@export_enum("X (Izq/Der)", "Y (Arriba/Abajo)", "Z (Adelante/Atras)") var eje_rotacion: int = 2
@export_category("Puntos de Spawn")
@export var spawn_flecha_explosiva: Marker3D = null  ## Nodo Marker3D para definir el punto exacto de nacimiento de la flecha explosiva y su trayectoria

@export_category("Hitbox")
@export var mostrar_hitbox: bool = false  ## Muestra la hitbox del jugador en tiempo real
# === SISTEMA DE VIDA ===
@export_category("Vida")
@export var vida_maxima: int = 5
@export var modo_dios: bool = false  # Inmune a todo daño (god mode)
@export var caer_escalera_al_recibir_dano: bool = true
# Duración de la invulnerabilidad tras recibir daño
@export var invulnerability_duration: float = 1.5
# Tiempo que no puedes disparar tras recibir daño
@export var shot_lock_duration: float = 0.2
# === CONFIGURACIÓN - EFECTOS VISUALES ===
@export_category("Efectos Visuales")
@export var mostrar_particulas_aterrizaje: bool = false  # Desactivado: partículas muy grandes
@export_subgroup("Partículas de Salto")
@export var color_particulas_salto: Color = Color(0.7, 0.65, 0.5, 0.5)  # Color de las partículas
@export_range(0.01, 0.5, 0.01) var escala_min_salto: float = 0.05  # Tamaño mínimo
@export_range(0.01, 0.5, 0.01) var escala_max_salto: float = 0.15  # Tamaño máximo
# === CONFIGURACIÓN - SOMBRA ===
@export_category("Sombra")
@export var sombra_opacidad: float = 1.0
@export var sombra_tamano: Vector2 = Vector2(0.6, 0.6)
@export var sombra_suavizado: float = 0.8
@export var sombra_altura_max: float = 0.2 ## Altura donde la sombra desaparece al saltar
# Escena del proyectil flecha
var eje_disparo: int = 0
# === HITBOX / COLISIÓN ===
var arrow_scene = preload("res://Entities/Proyectil_Flecha/Arrow.tscn")
var explosive_arrow_scene = preload("res://Entities/Flecha_Explosiva/FlechaExplosiva.tscn")
# --- REFERENCIAS ---
var anim_tree: AnimationTree
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var bow_anim_player: AnimationPlayer  # AnimationPlayer del arco
var arrow_node: Node3D  # Nodo de la flecha para visibilidad
var explosive_arrow_node: Node3D  # Nodo de la flecha explosiva visual
var _arrow_base_scale: Vector3 = Vector3(40.0, 40.0, 40.0)
var _explosive_arrow_base_scale: Vector3 = Vector3(40.0, 40.0, 40.0)
# --- ESTADO ---
var current_aim_state = AimState.NONE
var state_timer = 0.0
# Estados de Movimiento
var current_move_state = MoveState.GROUND
var landing_timer = 0.0
var landing_anim_duration = 0.5  # Se auto-calcula
var crouch_timer: float = 0.0
const TIEMPO_POSTURA_AGACHADO_APEX: float = 0.26  ## Punto más bajo y flexionado de la animación de agachado
var is_dead: bool = false
var ladder_cooldown: float = 0.0  # Tiempo de espera para volver a agarrar la escalera
var is_inside_platform: bool = false  # Bloquea movimiento lateral
var charge_time = 0.0
var last_charge_power = 0.0  # Potencia al momento de disparar (0.0 a 1.0)
var _cooldown_disparo_timer: float = 0.0  # Temporizador de cooldown entre disparos
var charge_bar: ProgressBar
var _bow_hold_timer: float = 0.0  # Timer para delay de sonido mantener arco
# === TRAYECTORIA VISUAL (FLECHA EXPLOSIVA) ===
var _trajectory_mesh_instance: MeshInstance3D = null
var _trajectory_immediate_mesh: ImmediateMesh = null
var _trajectory_material: Material = null
var _trajectory_impact_marker: Node3D = null
var _trajectory_fade_timer: float = 0.0
# === HITBOX ===
var collision_shape_node: CollisionShape3D
var hitbox_altura_original: float = 1.8
var hitbox_pos_y_original: float = 0.9
var hitbox_debug_mesh: MeshInstance3D
var _cached_mesh_instances: Array[Node] = []
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
# === OPTIMIZACIÓN: Material de flash cacheado ===
var _flash_material: StandardMaterial3D = null
# === VIDA ===
var health: int = 5
var is_invulnerable: bool = false
var invulnerability_timer: float = 0.0
var shot_cancelled: bool = false  # Flag para cancelar disparo cuando nos dañan
var is_shot_locked: bool = false  # Flag de bloqueo de disparo temporal
## Cuando true (mapa de debug), no se inicia el disparo si el cursor está sobre
## un Control interactivo (panel/botones), para que clicar opciones no dispare.
var disparo_bloqueado_por_ui: bool = false

## Cursor de mira personalizado durante la partida
const TEXTURA_CURSOR_MIRA: String = "res://TEST_/Mira mouse.png"
## Los cursores de hardware no soportan imágenes grandes (512px): se reduce
const TAMANO_CURSOR_PX: int = 75

var _textura_cursor_mira: Texture2D = null
var _cursor_sistema_activo: bool = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED:
			# Menú de pausa / Game Over: cursor por defecto del sistema
			_set_cursor_sistema(true)
		NOTIFICATION_UNPAUSED:
			_set_cursor_sistema(false)
# === AUDIO ===
# Gestionado por AudioManager (singleton)
# === GAME FEEL ===
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0


func _ready():
	add_to_group("player")
	health = vida_maxima
	anim_tree = find_child("AnimationTree", true, false)
	skeleton = find_child("Skeleton3D", true, false)
	_cached_mesh_instances = find_children("*", "MeshInstance3D", true, false)

	# Cursor de mira personalizado durante la partida
	_aplicar_cursor_mira()

	# Añadir layer 10 al collision_mask para colisionar con BarreraLimite (bit 9)
	# y remover layer 4 (Enemy Projectiles, bit 3) para no colisionar físicamente con proyectiles enemigos
	collision_mask = (collision_mask | (1 << 9)) & ~(1 << 3)

	if anim_tree:
		# CONSTRUIR ÁRBOL DINÁMICAMENTE (Para evitar corrupciones del editor)
		setup_animation_tree_dynamic()

		anim_tree.active = true

		anim_player = anim_tree.get_node(anim_tree.anim_player)
		if anim_player:
			var anims_to_loop = [
				"Armature|Armature|IDLE",
				"Armature|Armature|CAMINAR_ADELANTE",
				"Armature|Armature|CAMINAR_ATRAS",
				"Armature|Armature|APUNTAR_IDLE",
				"Armature|Armature|CORRER_ADELANTE",
				"Armature|Armature|SUBIR_ESCALERA"
			]
			for anim_name in anims_to_loop:
				if anim_player.has_animation(anim_name):
					anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		else:
			push_error("[Player] AnimationPlayer not found in AnimationTree")
	else:
		push_error("[Player] AnimationTree not found")

	if skeleton:
		var bone_name = "mixamorig_Spine1"
		var idx = skeleton.find_bone(bone_name)
		self.set_meta("bone_idx", idx)

	# Buscar AnimationPlayer del arco
	var bow_node = find_child("ARCO_ANIMADO", true, false)
	if bow_node:
		bow_anim_player = bow_node.find_child("AnimationPlayer", true, false)

	# Buscar nodo de la flecha
	arrow_node = find_child("FLECHA", true, false)
	if arrow_node:
		_arrow_base_scale = arrow_node.scale
		arrow_node.visible = false
	if not spawn_flecha_explosiva:
		spawn_flecha_explosiva = find_child("SpawnPosition_FlechaExplosiva", true, false) as Marker3D
	_setup_explosive_arrow_visual()
	_setup_trayectoria_visual()

	# Buscar Armature para rotación de escalera
	armature_node = find_child("Armature", true, false)
	if not armature_node:
		armature_node = find_child("ArqueraModel", true, false)
	if armature_node:
		armature_original_rotation = armature_node.rotation

	create_charge_bar()

	# === HITBOX: guardar referencia y valores originales ===
	collision_shape_node = find_child("CollisionShape3D", true, false)
	if collision_shape_node and collision_shape_node.shape is CapsuleShape3D:
		hitbox_altura_original = collision_shape_node.shape.height
		hitbox_pos_y_original = collision_shape_node.position.y
	_setup_hitbox_debug()

	# Sombra procedural debajo del personaje
	var _sombra := SombraPersonaje.new()
	_sombra.opacidad = sombra_opacidad
	_sombra.tamano = sombra_tamano
	_sombra.suavizado = sombra_suavizado
	_sombra.altura_max_desvanecimiento = sombra_altura_max
	add_child(_sombra)


# ═══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DINÁMICA DEL ÁRBOL DE ANIMACIÓN
# ═══════════════════════════════════════════════════════════════════════════════
func setup_animation_tree_dynamic():
	var root = AnimationNodeBlendTree.new()

	# ───────────────────────────────────────────────────────────────────────────
	# SECCIÓN 1: NODOS DE ANIMACIÓN BASE
	# ───────────────────────────────────────────────────────────────────────────
	var node_idle = AnimationNodeAnimation.new()
	node_idle.animation = "Armature|Armature|IDLE"

	var node_walk_fwd = AnimationNodeAnimation.new()
	node_walk_fwd.animation = "Armature|Armature|CAMINAR_ADELANTE"

	var node_walk_back = AnimationNodeAnimation.new()
	node_walk_back.animation = "Armature|Armature|CAMINAR_ATRAS"

	var node_run_fwd = AnimationNodeAnimation.new()
	node_run_fwd.animation = "Armature|Armature|CORRER_ADELANTE"

	var node_aim = AnimationNodeAnimation.new()
	node_aim.animation = "Armature|Armature|APUNTAR_IDLE"

	var node_shoot = AnimationNodeAnimation.new()
	node_shoot.animation = "Armature|Armature|DISPARAR"

	var node_draw = AnimationNodeAnimation.new()
	node_draw.animation = "Armature|Armature|TOMAR_FLECHA"

	var node_none = AnimationNodeAnimation.new()
	node_none.animation = "Armature|Armature|IDLE"

	var node_jump_fall = AnimationNodeAnimation.new()
	node_jump_fall.animation = "Armature|Armature|CAER_SALTAR"

	var node_land = AnimationNodeAnimation.new()
	node_land.animation = "Armature|Armature|ATERRIZAJE"

	var node_climb = AnimationNodeAnimation.new()
	node_climb.animation = "Armature|Armature|SUBIR_ESCALERA"

	var node_death = AnimationNodeAnimation.new()
	node_death.animation = "Armature|Armature|MUERTE"

	# Agregar nodos al árbol
	root.add_node("Idle", node_idle)
	root.add_node("WalkFwd", node_walk_fwd)
	root.add_node("WalkBack", node_walk_back)
	root.add_node("RunFwd", node_run_fwd)
	root.add_node("Aim", node_aim)
	root.add_node("Shoot", node_shoot)
	root.add_node("Draw", node_draw)
	root.add_node("None", node_none)
	root.add_node("JumpFall", node_jump_fall)
	root.add_node("Land", node_land)
	root.add_node("ClimbAnim", node_climb)
	root.add_node("Death", node_death)

	# ───────────────────────────────────────────────────────────────────────────
	# SECCIÓN 2: NODOS DE TRANSICIÓN
	# ───────────────────────────────────────────────────────────────────────────

	# A. Locomotion (Movimiento en suelo)
	var trans_loco = AnimationNodeTransition.new()
	trans_loco.input_count = 4
	trans_loco.set_input_name(0, "idle")
	trans_loco.set_input_name(1, "walk_fwd")
	trans_loco.set_input_name(2, "walk_back")
	trans_loco.set_input_name(3, "run_fwd")
	trans_loco.xfade_time = 0.2
	root.add_node("Locomotion", trans_loco)

	# B. TimeScale para escalada (invertir al bajar)
	var time_climb = AnimationNodeTimeScale.new()
	root.add_node("Climb", time_climb)
	root.connect_node("Climb", 0, "ClimbAnim")

	# TimeScale para agachado / aterrizaje (permite congelar y sostener la pose agachada)
	var time_crouch = AnimationNodeTimeScale.new()
	root.add_node("CrouchTimeScale", time_crouch)
	root.connect_node("CrouchTimeScale", 0, "Land")

	# C. MotionState (Estados de movimiento principales)
	var trans_motion = AnimationNodeTransition.new()
	trans_motion.input_count = 5
	trans_motion.set_input_name(0, "ground")
	trans_motion.set_input_name(1, "air")
	trans_motion.set_input_name(2, "land")
	trans_motion.set_input_name(3, "climb")
	trans_motion.set_input_name(4, "death")
	trans_motion.xfade_time = 0.25
	root.add_node("MotionState", trans_motion)

	# D. UpperBody (Acciones de torso superior)
	var trans_upper = AnimationNodeTransition.new()
	trans_upper.input_count = 4
	trans_upper.set_input_name(0, "none")
	trans_upper.set_input_name(1, "aim")
	trans_upper.set_input_name(2, "shoot")
	trans_upper.set_input_name(3, "draw")
	trans_upper.xfade_time = 0.35
	root.add_node("UpperBody", trans_upper)

	# ───────────────────────────────────────────────────────────────────────────
	# SECCIÓN 3: MEZCLA DE ANIMACIONES (Blend)
	# ───────────────────────────────────────────────────────────────────────────

	# Filtros para torso/brazos (no afectan piernas)
	var upper_body_filters = [
		"Armature/Skeleton3D:mixamorig_Spine",
		"Armature/Skeleton3D:mixamorig_Spine1",
		"Armature/Skeleton3D:mixamorig_Spine2",
		"Armature/Skeleton3D:mixamorig_Neck",
		"Armature/Skeleton3D:mixamorig_Head",
		"Armature/Skeleton3D:mixamorig_LeftShoulder",
		"Armature/Skeleton3D:mixamorig_RightShoulder",
		"Armature/Skeleton3D:mixamorig_LeftArm",
		"Armature/Skeleton3D:mixamorig_RightArm",
		"Armature/Skeleton3D:mixamorig_LeftForeArm",
		"Armature/Skeleton3D:mixamorig_RightForeArm",
		"Armature/Skeleton3D:mixamorig_LeftHand",
		"Armature/Skeleton3D:mixamorig_RightHand",
		"Armature/Skeleton3D:mixamorig_LeftHandIndex1",
		"Armature/Skeleton3D:mixamorig_LeftHandIndex2",
		"Armature/Skeleton3D:mixamorig_LeftHandIndex3",
		"Armature/Skeleton3D:mixamorig_RightHandIndex1",
		"Armature/Skeleton3D:mixamorig_RightHandIndex2",
		"Armature/Skeleton3D:mixamorig_RightHandIndex3"
	]

	# AimBlend: Mezcla UpperBody sobre MotionState
	var blend_aim = AnimationNodeBlend2.new()
	blend_aim.filter_enabled = true
	for f in upper_body_filters:
		blend_aim.set_filter_path(NodePath(f), true)
	root.add_node("AimBlend", blend_aim)

	# HitOneShot: Animación de daño sobre todo lo anterior
	var oneshot_hit = AnimationNodeOneShot.new()
	oneshot_hit.filter_enabled = true
	for f in upper_body_filters:
		oneshot_hit.set_filter_path(NodePath(f), true)

	var node_hit = AnimationNodeAnimation.new()
	node_hit.animation = "Armature|Armature|HIT"

	root.add_node("HitOneShot", oneshot_hit)
	root.add_node("HitAnim", node_hit)

	# ───────────────────────────────────────────────────────────────────────────
	# SECCIÓN 4: CONEXIONES DEL ÁRBOL
	# ───────────────────────────────────────────────────────────────────────────

	# Locomotion: idle, walk_fwd, walk_back, run_fwd
	root.connect_node("Locomotion", 0, "Idle")
	root.connect_node("Locomotion", 1, "WalkFwd")
	root.connect_node("Locomotion", 2, "WalkBack")
	root.connect_node("Locomotion", 3, "RunFwd")

	# MotionState: ground, air, land, climb, death
	root.connect_node("MotionState", 0, "Locomotion")
	root.connect_node("MotionState", 1, "JumpFall")
	root.connect_node("MotionState", 2, "CrouchTimeScale")
	root.connect_node("MotionState", 3, "Climb")
	root.connect_node("MotionState", 4, "Death")

	# UpperBody: none, aim, shoot, draw
	root.connect_node("UpperBody", 0, "None")
	root.connect_node("UpperBody", 1, "Aim")
	root.connect_node("UpperBody", 2, "Shoot")
	root.connect_node("UpperBody", 3, "Draw")

	# AimBlend: Base (MotionState) + Overlay (UpperBody)
	root.connect_node("AimBlend", 0, "MotionState")
	root.connect_node("AimBlend", 1, "UpperBody")

	# HitOneShot: AimBlend + HitAnim
	root.connect_node("HitOneShot", 0, "AimBlend")
	root.connect_node("HitOneShot", 1, "HitAnim")

	# Salida final
	root.connect_node("output", 0, "HitOneShot")

	# ───────────────────────────────────────────────────────────────────────────
	# SECCIÓN 5: ASIGNAR Y CONFIGURAR PARÁMETROS INICIALES
	# ───────────────────────────────────────────────────────────────────────────
	anim_tree.tree_root = root

	anim_tree.set("parameters/Locomotion/transition_request", "idle")
	anim_tree.set("parameters/MotionState/transition_request", "ground")
	anim_tree.set("parameters/UpperBody/transition_request", "none")
	anim_tree.set("parameters/AimBlend/blend_amount", 0.0)
	anim_tree.set("parameters/HitOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


# === Variables Escalera ===
var current_ladder = null
var is_near_ladder = false
@export var velocidad_escalar_subir: float = 0.65  ## Velocidad al subir escaleras (+30% sobre 0.5)
@export var velocidad_escalar_bajar: float = 0.65  ## Velocidad al bajar escaleras
@export_range(-360, 360, 1.0) var rotacion_personaje_escalera: float = 180.0  # Giro del modelo al escalar

# Referencia al Armature para rotarlo
var armature_node: Node3D = null
var armature_original_rotation: Vector3 = Vector3.ZERO
var _mirando_derecha: bool = true  ## Dirección actual a la que mira el personaje (true=derecha, false=izquierda)


func set_near_ladder(val, ladder_area):
	is_near_ladder = val
	if val:
		current_ladder = ladder_area
	else:
		current_ladder = null
		if current_move_state == MoveState.CLIMBING:
			stop_climbing()


func stop_climbing():
	if is_on_floor():
		current_move_state = MoveState.GROUND
		set_motion_anim("ground")
		velocity.y = 0.0
	else:
		current_move_state = MoveState.AIR
		velocity.y = 0.5
		set_motion_anim("air")

	# Restaurar rotación suavemente
	_reset_armature_rotation(false)


## Salida suave por la parte superior de la escalera hacia la plataforma
func dismount_ladder_top(direction_x: float = 0.0) -> void:
	ladder_cooldown = 0.5
	current_move_state = MoveState.GROUND
	set_motion_anim("ground")
	velocity.y = 0.0
	_mirando_derecha = true
	if not is_zero_approx(direction_x):
		velocity.x = direction_x
	else:
		velocity.x = velocidad_caminar * 0.4


func _apply_climbing_rotation(delta: float, snap: bool = false):
	_apply_character_rotation(delta, snap)


func _apply_character_rotation(delta: float, snap: bool = false) -> void:
	if not armature_node:
		return

	var target_y: float = armature_original_rotation.y

	if current_move_state == MoveState.CLIMBING and current_aim_state == AimState.NONE:
		# Si solo está escalando sin apuntar, se orienta hacia la escalera
		# Restamos 0.5 grados para que el camino más corto al apuntar sea en sentido horario (decreciente)
		target_y = armature_original_rotation.y + deg_to_rad(rotacion_personaje_escalera - 0.5)
	else:
		# En el suelo, aire o apuntando (incluso en escalera): orienta hacia _mirando_derecha (izquierda o derecha)
		if _mirando_derecha:
			target_y = armature_original_rotation.y
		else:
			target_y = armature_original_rotation.y + PI

	if snap:
		armature_node.rotation.y = target_y
	else:
		armature_node.rotation.y = lerp_angle(armature_node.rotation.y, target_y, velocidad_giro_suave * delta)


func _reset_armature_rotation(snap: bool = false):
	# Restaurar rotación original de forma suave (o forzada si snap=true)
	_mirando_derecha = true
	if snap and armature_node:
		armature_node.rotation = armature_original_rotation


# ═══════════════════════════════════════════════════════════════════════════════
# HITBOX - DEBUG Y AJUSTE AL AGACHARSE
# ═══════════════════════════════════════════════════════════════════════════════


func _setup_hitbox_debug():
	if not collision_shape_node:
		return
	# Crear mesh debug para visualizar la hitbox
	hitbox_debug_mesh = MeshInstance3D.new()
	hitbox_debug_mesh.name = "HitboxDebug"
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0, 1, 0, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	hitbox_debug_mesh.material_override = mat
	collision_shape_node.add_child(hitbox_debug_mesh)
	_update_hitbox_debug_mesh()


func _update_hitbox_debug_mesh():
	if not hitbox_debug_mesh or not collision_shape_node:
		return
	if not collision_shape_node.shape is CapsuleShape3D:
		return
	var capsule: CapsuleShape3D = collision_shape_node.shape
	var mesh = CapsuleMesh.new()
	mesh.radius = capsule.radius
	mesh.height = capsule.height
	hitbox_debug_mesh.mesh = mesh
	hitbox_debug_mesh.visible = mostrar_hitbox


## Reduce la hitbox a la mitad al agacharse para esquivar proyectiles altos
func _ajustar_hitbox_agachado(agachado: bool) -> void:
	if not collision_shape_node or not collision_shape_node.shape is CapsuleShape3D:
		return
	var capsule: CapsuleShape3D = collision_shape_node.shape
	if agachado:
		capsule.height = hitbox_altura_original * 0.55
		collision_shape_node.position.y = hitbox_pos_y_original - (hitbox_altura_original * 0.225)
	else:
		capsule.height = hitbox_altura_original
		collision_shape_node.position.y = hitbox_pos_y_original
	_update_hitbox_debug_mesh()


func create_charge_bar():
	var canvas = CanvasLayer.new()
	canvas.name = "UI_Player"
	canvas.layer = 100
	add_child(canvas)

	charge_bar = ProgressBar.new()
	charge_bar.max_value = 100
	charge_bar.value = 0
	charge_bar.show_percentage = false
	charge_bar.size = Vector2(50, 5)
	charge_bar.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.8, 0.3)
	charge_bar.add_theme_stylebox_override("fill", style)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	charge_bar.add_theme_stylebox_override("background", bg_style)

	canvas.add_child(charge_bar)


func _process(delta):
	# Actualizar visibilidad del debug de hitbox en tiempo real
	if hitbox_debug_mesh:
		hitbox_debug_mesh.visible = mostrar_hitbox
	# En el mapa debug, cursor del sistema mientras se usa el panel de spawn/debug
	if disparo_bloqueado_por_ui:
		_set_cursor_sistema(_mouse_sobre_control_ui())
	# Actualizar estados visuales y UI
	_process_gameplay(delta)


func _physics_process(delta):
	# BLOQUEAR TODO SI ESTAMOS MUERTOS
	if is_dead:
		return

	# Obtener Input
	var input_dir = Input.get_axis("move_left", "move_right")
	# Usar move_forward/back (W/S) que añadimos o ui_up/down
	var input_vert_ws = Input.get_axis("move_forward", "move_back")
	var input_vert_ui = Input.get_axis("ui_up", "ui_down")

	# Priorizar W/S, fallback a flechas
	var input_vert = input_vert_ws if input_vert_ws != 0 else input_vert_ui

	# Actualizar orientación:
	# - Si está apuntando / cargando arco: orienta hacia el lado de la pantalla donde está el cursor del mouse
	# - Si se mueve normalmente sin apuntar: orienta según las teclas de movimiento (A/D)
	if current_aim_state != AimState.NONE:
		var camera = CameraUtilsRef.obtener_camara_juego(self)
		if camera:
			var player_screen_pos = camera.unproject_position(global_position + Vector3(0, 1.0, 0))
			var mouse_pos = get_viewport().get_mouse_position()
			if mouse_pos.x < player_screen_pos.x - 12.0:
				_mirando_derecha = false
			elif mouse_pos.x > player_screen_pos.x + 12.0:
				_mirando_derecha = true
	elif current_move_state != MoveState.CLIMBING:
		if input_dir > 0.1:
			_mirando_derecha = true
		elif input_dir < -0.1:
			_mirando_derecha = false

	# Aplicar rotación suave del personaje
	_apply_character_rotation(delta, false)

	# Guardar velocidad vertical PREVIA al movimiento (para detectar impacto)
	var prev_vel_y = velocity.y

	# Rastrear inicio de caída libre desde altura para humo al tocar superficie
	if not is_on_floor():
		if not _was_in_air_from_height:
			_was_in_air_from_height = true
			_fall_start_y = global_position.y

	# --- MÁQUINA DE ESTADOS DE MOVIMIENTO SIMPLE ---

	# 1. GRAVEDAD (Solo si no escalamos)
	if current_move_state != MoveState.CLIMBING:
		if not is_on_floor():
			velocity.y -= gravity * delta
			if current_move_state == MoveState.CROUCHING:
				_ajustar_hitbox_agachado(false)
				if anim_tree:
					anim_tree.set("parameters/CrouchTimeScale/scale", 1.0)
			if current_move_state != MoveState.LANDING:  # Si no estamos aterrizando, estamos en aire
				current_move_state = MoveState.AIR

		# Mantener rotación estándar lateral (ej 90 grados) si no estamos escalando
		# IMPORTANTE: Si es 2.5D lateral, el personaje en sí (Root) suele estar rotado 90 grados.
		# No forzamos rotación aquí para dejar libertad, salvo resetear Armature si fuera necesario.

	# Update cooldown
	if ladder_cooldown > 0:
		ladder_cooldown -= delta

	# Detectar inicio de escalada
	if is_near_ladder and ladder_cooldown <= 0 and current_move_state != MoveState.CLIMBING:
		if abs(input_vert) > 0.5:
			current_move_state = MoveState.CLIMBING
			velocity.x = 0

			# Centrar en la escalera (Solo eje X)
			if current_ladder:
				var tween = create_tween()
				tween.tween_property(
					self, "global_position:x", current_ladder.global_position.x, 0.2
				)

			_cancel_current_shot()
			_apply_climbing_rotation(delta, false)  # Rotación suave al montar la escalera

	# 2. MOVIMIENTO FÍSICO
	move_and_slide()

	# 3. DETECCIÓN DE ATERRIZAJE (Post-movimiento)
	if is_on_floor():
		if current_move_state == MoveState.CLIMBING:
			if input_vert > 0:  # Bajando
				current_move_state = MoveState.GROUND
				set_motion_anim("ground")
				_reset_armature_rotation()

		# Acabamos de tocar suelo viniendo del aire?
		elif current_move_state == MoveState.AIR:
			# Humo sincronizado exactamente al tocar la superficie tras caída
			if _was_in_air_from_height:
				var dist: float = _fall_start_y - global_position.y
				if dist > 0.9:
					_spawn_fall_smoke()
				_was_in_air_from_height = false

			# ATERRIZAJE CONDICIONAL
			if prev_vel_y < umbral_aterrizaje:
				start_landing()  # Caída fuerte -> Bloqueo
				# GAME FEEL: Partículas de aterrizaje
				_spawn_landing_vfx()
			else:
				# Aterrizaje suave (salto normal) -> Pasar directo a Ground sin bloquear
				current_move_state = MoveState.GROUND
				if anim_tree:
					set_motion_anim("ground")

			# GAME FEEL: Consumir jump buffer al aterrizar
			if jump_buffer_timer > 0:
				velocity.y = fuerza_salto
				current_move_state = MoveState.AIR
				_spawn_jump_vfx()
				jump_buffer_timer = 0

	# GAME FEEL: Actualizar timers
	_update_jump_assist(delta)

	# 4. LOGICA SEGUN ESTADO ACTUAL
	match current_move_state:
		MoveState.GROUND:
			# Movimiento normal - CON COYOTE TIME
			coyote_timer = COYOTE_TIME  # Resetear coyote time en suelo

			if Input.is_action_just_pressed("ui_accept"):
				_perform_jump()
			elif input_vert > 0.5 and not is_near_ladder:
				# Agacharse al presionar S / Abajo en el suelo
				current_move_state = MoveState.CROUCHING
				crouch_timer = 0.0
				_ajustar_hitbox_agachado(true)
				if anim_tree:
					anim_tree.set("parameters/CrouchTimeScale/scale", 1.0)
					set_motion_anim("land")
			else:
				apply_movement(input_dir, delta)
				if anim_tree:
					set_motion_anim("ground")
					update_locomotion_anim(input_dir)

		MoveState.CROUCHING:
			if Input.is_action_just_pressed("ui_accept"):
				_ajustar_hitbox_agachado(false)
				if anim_tree:
					anim_tree.set("parameters/CrouchTimeScale/scale", 1.0)
				_perform_jump()
			elif input_vert <= 0.3:
				# Soltar la tecla abajo: levantarse
				current_move_state = MoveState.GROUND
				_ajustar_hitbox_agachado(false)
				if anim_tree:
					anim_tree.set("parameters/CrouchTimeScale/scale", 1.0)
					set_motion_anim("ground")
			else:
				# Mantenerse agachada indefinidamente mientras se mantenga presionada la tecla
				crouch_timer += delta
				if anim_tree:
					set_motion_anim("land")
					if crouch_timer >= TIEMPO_POSTURA_AGACHADO_APEX:
						anim_tree.set("parameters/CrouchTimeScale/scale", 0.0)
					else:
						anim_tree.set("parameters/CrouchTimeScale/scale", 1.0)

				velocity.x = move_toward(velocity.x, 0, aceleracion_movimiento * delta)

		MoveState.CLIMBING:
			_apply_climbing_rotation(delta, false)
			# Si estamos apuntando, bloquear movimiento completamente
			if current_aim_state != AimState.NONE:
				velocity.y = 0
				velocity.x = 0
				# Detener animación de escalada completamente
				if anim_tree:
					anim_tree.set("parameters/Climb/scale", 0.0)
			else:
				# Movimiento libre vertical, sin gravedad
				var climb_speed = velocidad_escalar_subir
				if input_vert > 0:  # Si input es positivo (S/Abajo), estamos bajando
					climb_speed = velocidad_escalar_bajar

				velocity.y = -input_vert * climb_speed

				# Bloquear movimiento lateral si estamos atravesando una plataforma
				if is_inside_platform:
					velocity.x = 0
				else:
					velocity.x = input_dir * velocidad_caminar  # Permitir movimiento lateral (A/D)

				# Ajustar velocidad de animación (invertir si bajamos y escalar según velocidad)
				if anim_tree:
					var anim_mult: float = max(0.5, climb_speed / 0.6)
					var scale_val: float = 1.0
					if input_vert > 0.1:  # Bajando
						scale_val = -anim_mult
					elif input_vert < -0.1:  # Subiendo
						scale_val = anim_mult
					else:
						scale_val = 0.0  # Quieto

					# El nombre del parámetro es "Climb" porque así nombramos al nodo TimeScale
					anim_tree.set("parameters/Climb/scale", scale_val)

			set_motion_anim("climb")

			# Saltar para soltarse
			if Input.is_action_just_pressed("ui_accept"):
				stop_climbing()
				velocity.y = fuerza_salto * 0.5

		MoveState.AIR:
			apply_movement(input_dir, delta)
			if anim_tree:
				set_motion_anim("air")

			# GAME FEEL: Coyote Time - permitir saltar brevemente después de caer
			if Input.is_action_just_pressed("ui_accept") and coyote_timer > 0:
				_perform_jump()

		MoveState.LANDING:
			# Bloqueado!
			velocity.x = move_toward(velocity.x, 0, velocidad_caminar)

			landing_timer += delta
			if landing_timer >= landing_anim_duration:
				current_move_state = MoveState.GROUND

			if anim_tree:
				set_motion_anim("land")


func apply_movement(input_dir: float, delta: float = 0.016) -> void:
	var current_speed: float = velocidad_correr
	if current_aim_state == AimState.DRAWING or current_aim_state == AimState.AIMING:
		current_speed = velocidad_caminar

	var target_vel_x: float = input_dir * current_speed
	velocity.x = move_toward(velocity.x, target_vel_x, aceleracion_movimiento * delta)


func start_landing():
	current_move_state = MoveState.LANDING
	landing_timer = 0.0

	# GAME FEEL: Screen shake en aterrizaje fuerte
	if has_node("/root/GameFeel"):
		get_node("/root/GameFeel").on_hard_landing()

	# Calcular duracion real land
	landing_anim_duration = 0.5
	if anim_player and anim_player.has_animation("Armature|Armature|ATERRIZAJE"):
		landing_anim_duration = anim_player.get_animation("Armature|Armature|ATERRIZAJE").length

	# CANCELAR AIM / SHOOT
	current_aim_state = AimState.NONE
	charge_time = 0.0
	charge_bar.visible = false
	AudioManager.reset_bow_hold()
	if anim_tree:
		anim_tree.set("parameters/CrouchTimeScale/scale", 1.0)
		anim_tree.set("parameters/UpperBody/transition_request", "none")
		anim_tree.set("parameters/AimBlend/blend_amount", 0.0)

	reset_torso_bone()


# ═══════════════════════════════════════════════════════════════════════════════
# GAME FEEL - COYOTE TIME, JUMP BUFFER & VFX
# ═══════════════════════════════════════════════════════════════════════════════


func _update_jump_assist(delta: float) -> void:
	# Decrementar timers
	if coyote_timer > 0:
		coyote_timer -= delta
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

	# Si presionamos saltar, guardar en buffer
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME


func _perform_jump() -> void:
	velocity.y = fuerza_salto
	current_move_state = MoveState.AIR
	coyote_timer = 0  # Consumir coyote time
	jump_buffer_timer = 0  # Consumir buffer
	_spawn_jump_vfx()


func _can_jump() -> bool:
	# Puede saltar si está en suelo O tiene coyote time
	return is_on_floor() or coyote_timer > 0


func _spawn_jump_vfx() -> void:
	# Llamar a VFXFactory con los parámetros configurables desde el inspector
	VFXFactory.spawn_jump(
		get_tree().root, global_position, color_particulas_salto, escala_min_salto, escala_max_salto
	)


func _spawn_landing_vfx() -> void:
	# Verificar si las partículas de aterrizaje están habilitadas
	if not mostrar_particulas_aterrizaje:
		return
	# Llamar a VFXFactory directamente (clase estática)
	VFXFactory.spawn_landing(get_tree().root, global_position, 1.5)

# Humo sutil al caer desde altura (plataforma/escalera) - SmokeFX 2A-2, dos penachos a los pies
var _fall_start_y: float = 0.0
var _was_in_air_from_height: bool = false

func _spawn_fall_smoke() -> void:
	var tex: Texture2D = load("res://TEST_/SmokeFX Lite SpriteSheet 2A-2.png") as Texture2D
	if not tex:
		return
	for side in [-1, 1]:
		var puf: GPUParticles3D = GPUParticles3D.new()
		puf.amount = 3
		puf.lifetime = 0.65
		puf.one_shot = true
		puf.explosiveness = 0.2
		puf.randomness = 0.3
		puf.visibility_aabb = AABB(Vector3(-1.5, -1.2, -1.5), Vector3(3, 3, 3))
		var pmat: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		pmat.direction = Vector3(side * 0.7, 0.4, 0)
		pmat.spread = 18.0
		pmat.initial_velocity_min = 0.6
		pmat.initial_velocity_max = 1.1
		pmat.gravity = Vector3(0, -0.4, 0)
		pmat.scale_min = 0.45
		pmat.scale_max = 0.68
		pmat.anim_speed_min = 0.9
		pmat.anim_speed_max = 1.1
		pmat.anim_offset_min = 0.0
		pmat.anim_offset_max = 0.2
		var grad: Gradient = Gradient.new()
		grad.set_color(0, Color(0.96, 0.94, 0.88, 0.85))
		grad.set_color(1, Color(0.96, 0.94, 0.88, 0.0))
		var grad_tex: GradientTexture1D = GradientTexture1D.new()
		grad_tex.gradient = grad
		pmat.color_ramp = grad_tex
		pmat.turbulence_enabled = true
		pmat.turbulence_noise_strength = 0.008
		puf.process_material = pmat
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = tex
		mat.particles_anim_h_frames = 6
		mat.particles_anim_v_frames = 1
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.billboard_keep_scale = true
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.72, 0.72)
		quad.material = mat
		puf.draw_pass_1 = quad
		get_tree().root.add_child(puf)
		puf.global_position = global_position + Vector3(side * 0.25, 0.04, 0)
		puf.emitting = true
		# Asegurar visibilidad en viewport del juego (capa Frente)
		puf.layers = 1048575
		get_tree().create_timer(1.2).timeout.connect(func(): if is_instance_valid(puf): puf.queue_free())


func set_motion_anim(state_name):
	if anim_tree.get("parameters/MotionState/current_state") != state_name:
		anim_tree.set("parameters/MotionState/transition_request", state_name)


func update_locomotion_anim(input_dir):
	var loc_path = "parameters/Locomotion/transition_request"
	if current_aim_state == AimState.AIMING or current_aim_state == AimState.DRAWING:
		# Al tensar el arco / apuntar con click:
		if _mirando_derecha:
			# Apuntando a la derecha:
			if input_dir > 0.1:
				anim_tree.set(loc_path, "walk_fwd")
			elif input_dir < -0.1:
				anim_tree.set(loc_path, "walk_back")
			else:
				anim_tree.set(loc_path, "idle")
		else:
			# Apuntando a la izquierda:
			if input_dir < -0.1:
				anim_tree.set(loc_path, "walk_fwd")
			elif input_dir > 0.1:
				anim_tree.set(loc_path, "walk_back")
			else:
				anim_tree.set(loc_path, "idle")
	else:
		# Movimiento normal sin click: el personaje se voltea hacia donde camina y avanza de frente
		if abs(input_dir) > 0.1:
			anim_tree.set(loc_path, "run_fwd")
		else:
			anim_tree.set(loc_path, "idle")


func _process_gameplay(delta):
	control_visual_state(delta)
	update_charge_bar_position()


func update_charge_bar_position():
	if not charge_bar.visible:
		return

	var camera = CameraUtilsRef.obtener_camara_juego(self)
	if not camera:
		return

	var head_pos = global_position + Vector3(0, altura_barra, 0)

	if not camera.is_position_behind(head_pos):
		var screen_pos = camera.unproject_position(head_pos)
		charge_bar.position = screen_pos - (charge_bar.size / 2)
	else:
		charge_bar.visible = false


## True si el cursor está sobre un Control interactivo (botón/panel con
## MOUSE_FILTER_STOP). Se usa para no disparar al clicar opciones de la UI.
func _mouse_sobre_control_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return (
		hovered != null
		and hovered.is_visible_in_tree()
		and hovered.mouse_filter == Control.MOUSE_FILTER_STOP
	)


# ═══════════════════════════════════════════════════════════════════════════════
# CURSOR DE MIRA (partida)
# ═══════════════════════════════════════════════════════════════════════════════

## Cambia el cursor del sistema por la mira personalizada mientras el jugador
## está en partida. La imagen se reduce a TAMANO_CURSOR_PX (los cursores de
## hardware no soportan 512px) y el hotspot queda en el centro de la mira.
func _aplicar_cursor_mira() -> void:
	if _textura_cursor_mira == null:
		var tex := load(TEXTURA_CURSOR_MIRA) as Texture2D
		if tex == null:
			return

		var imagen := tex.get_image()
		if imagen == null:
			return
		if imagen.is_compressed():
			imagen.decompress()
		imagen.resize(TAMANO_CURSOR_PX, TAMANO_CURSOR_PX, Image.INTERPOLATE_LANCZOS)
		_textura_cursor_mira = ImageTexture.create_from_image(imagen)

	var mitad := TAMANO_CURSOR_PX / 2.0
	Input.set_custom_mouse_cursor(_textura_cursor_mira, Input.CURSOR_ARROW, Vector2(mitad, mitad))


## Alterna entre el cursor del sistema (null) y la mira personalizada,
## sin tocar el cursor si ya está en el estado pedido.
func _set_cursor_sistema(activo: bool) -> void:
	if _cursor_sistema_activo == activo:
		return
	_cursor_sistema_activo = activo
	if activo:
		Input.set_custom_mouse_cursor(null)
	else:
		_aplicar_cursor_mira()


## Al salir de la partida se restaura el cursor por defecto del sistema.
func _exit_tree():
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.set_custom_mouse_cursor(null)


func control_visual_state(delta):
	# BLOQUEAR TODO SI ESTAMOS MUERTOS
	if is_dead:
		return

	# Si estamos aterrizando, NO permitimos aiming
	if current_move_state == MoveState.LANDING:
		return

	# Si la cortinilla está activa, cancelar disparo y bloquear aiming
	if get_tree().has_group("pantalla_victoria_cortinilla") and not get_tree().get_nodes_in_group("pantalla_victoria_cortinilla").is_empty():
		_cancel_current_shot()
		return

	if not anim_tree:
		return

	var upper_path = "parameters/UpperBody/transition_request"
	var blend_path = "parameters/AimBlend/blend_amount"

	if anim_player:
		anim_player.speed_scale = 1.0

	match current_aim_state:
		AimState.NONE:
			var current_state = anim_tree.get("parameters/UpperBody/current_state")
			# Verificar si existe la propiedad (al ser dinámico a veces da error si no se inicializa bien, pero setup() lo hace)
			if current_state != null and current_state != "none":
				anim_tree.set(upper_path, "none")

			_ocultar_flecha_visual()

			var current = float(anim_tree.get(blend_path))
			if current > 0.0:
				anim_tree.set(
					blend_path,
					move_toward(current, 0.0, 5.0 * delta * multiplicador_velocidad_disparo)
				)

			reset_torso_bone()

			# Mantener animación idle del arco
			if bow_anim_player and not bow_anim_player.is_playing():
				play_bow_animation("ARCO_IDLE")

			# Resetear shot_cancelled cuando el usuario suelta el clic
			if shot_cancelled and not Input.is_action_pressed("click_izquierdo"):
				shot_cancelled = false

			# Cooldown entre disparos consecutivos
			if _cooldown_disparo_timer > 0.0:
				_cooldown_disparo_timer -= delta

			if Input.is_action_just_pressed("click_izquierdo"):
				# Bloquear si aún estamos en cooldown de cadencia
				if _cooldown_disparo_timer > 0.0:
					return

				# Mapa de debug: ignorar el clic si cae sobre un control de UI
				# (panel de spawn/debug), para que seleccionar opciones no dispare.
				if disparo_bloqueado_por_ui and _mouse_sobre_control_ui():
					return

				# Bloquear disparo si el disparo fue cancelado (debe soltar y volver a presionar)
				if shot_cancelled:
					return

				# Bloquear disparo si estamos bloqueados temporalment por daño (0.2s)
				if is_shot_locked:
					return

				# Bloquear disparo si estamos dentro de una plataforma
				if is_inside_platform:
					return

				# Cancelar animación de HIT si está activa
				if anim_tree:
					anim_tree.set(
						"parameters/HitOneShot/request",
						AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT
					)

				current_aim_state = AimState.DRAWING
				state_timer = 0.0
				_trajectory_fade_timer = 0.0
				anim_tree.set(upper_path, "draw")
				# Iniciar animación de tensar el arco
				play_bow_animation("ARCO_TENSAR")
				# Reproducir sonido de tensar cuerda (se puede detener)
				AudioManager.play_bow_tension()
				# Mostrar la flecha correspondiente y resetear escala
				_mostrar_flecha_visual(0.0)

		AimState.DRAWING:
			var current = float(anim_tree.get(blend_path))
			if current < 1.0:
				anim_tree.set(
					blend_path,
					move_toward(current, 1.0, 5.0 * delta * multiplicador_velocidad_disparo)
				)

			state_timer += delta
			_trajectory_fade_timer += delta
			actualizar_rotacion_torso_pitch()

			if Input.is_action_just_released("click_izquierdo"):
				# Si el disparo fue cancelado por daño, solo resetear el flag
				if shot_cancelled:
					shot_cancelled = false
					return
				start_shooting()
				return

			var adjusted_draw_time = (
				tiempo_tensar / (multiplicador_velocidad_disparo * velocidad_recarga)
			)
			if state_timer >= adjusted_draw_time:
				current_aim_state = AimState.AIMING
				anim_tree.set(upper_path, "aim")
				charge_time = 0.0
				charge_bar.visible = true

				# Asegurar escala final
				_mostrar_flecha_visual(1.0)

			# Mostrar trayectoria y actualizar escala de flecha
			var progress = clamp(state_timer / adjusted_draw_time, 0.0, 1.0)
			_mostrar_flecha_visual(progress)
			if flechas_explosivas > 0:
				_actualizar_trayectoria_explosiva()

		AimState.AIMING:
			if float(anim_tree.get(blend_path)) != 1.0:
				anim_tree.set(blend_path, 1.0)

			var adjusted_charge_dur = duracion_carga / multiplicador_velocidad_disparo
			charge_time += delta
			_trajectory_fade_timer += delta

			charge_time = min(charge_time, adjusted_charge_dur)
			var charge_percent = (charge_time / adjusted_charge_dur) * 100
			charge_bar.value = charge_percent

			# Sonido de mantener arco al máximo (con delay configurable)
			if charge_percent >= 100:
				_update_charge_vfx(true)
				_bow_hold_timer += delta
				if _bow_hold_timer >= AudioManager.delay_mantener_arco:
					AudioManager.play_bow_hold()
			else:
				_update_charge_vfx(false)
				_bow_hold_timer = 0.0

			charge_bar.modulate = Color.WHITE
			if charge_bar.has_meta("original_position"):
				charge_bar.position = charge_bar.get_meta("original_position")
			if charge_bar.has_method("set_tint_progress"):
				charge_bar.tint_progress = Color.WHITE

			actualizar_rotacion_torso_pitch()
			if flechas_explosivas > 0:
				_actualizar_trayectoria_explosiva()

			if Input.is_action_just_released("click_izquierdo"):
				# Si el disparo fue cancelado por daño, solo resetear el flag
				if shot_cancelled:
					shot_cancelled = false
					return
				charge_bar.modulate = Color.WHITE  # Restaurar color
				start_shooting()

		AimState.SHOOTING:
			var current_blend = float(anim_tree.get(blend_path))
			if current_blend < 1.0:
				anim_tree.set(blend_path, move_toward(current_blend, 1.0, 4.0 * delta))

			actualizar_rotacion_torso_pitch()

			state_timer += delta

			# Usar la duración que guardamos al iniciar el disparo
			# Ajustada por la velocidad de disparo y velocidad de recarga
			var current_shoot_dur = (
				shoot_anim_duration / (multiplicador_velocidad_disparo * velocidad_recarga)
			)

			if state_timer >= current_shoot_dur:
				current_aim_state = AimState.NONE
				anim_tree.set(upper_path, "none")  # Volver explícitamente a none
				# Detener animación del arco
				stop_bow_animation()
				# Ocultar la flecha y trayectoria
				_ocultar_flecha_visual()


var shoot_anim_duration = 1.0  # Valor por defecto


func start_shooting():
	_update_charge_vfx(false)
	_ocultar_trayectoria_explosiva()
	# Detener el sonido de tensar cuerda
	AudioManager.stop_bow_tension()

	current_aim_state = AimState.SHOOTING
	state_timer = 0.0  # Reset timer para contar duración del disparo
	_cooldown_disparo_timer = cadencia_disparo  # Cooldown antes de poder iniciar otro tensado

	anim_tree.set("parameters/UpperBody/transition_request", "shoot")
	charge_bar.visible = false

	# Reproducir animación de disparo del arco
	play_bow_animation("ARCO_DISPARO")

	# Ocultar la flecha visual (se "disparó")
	_ocultar_flecha_visual()

	# Obtener duración real de la animación
	if anim_player and anim_player.has_animation("Armature|Armature|DISPARAR"):
		shoot_anim_duration = anim_player.get_animation("Armature|Armature|DISPARAR").length

	# Calcular potencia del disparo de forma consistente (0.0 a 1.0)
	var adjusted_charge_dur = duracion_carga / multiplicador_velocidad_disparo
	var adjusted_draw_time = tiempo_tensar / (multiplicador_velocidad_disparo * velocidad_recarga)

	# Si charge_time > 0, estamos en AIMING y usamos ese valor proporcional al tiempo cargado
	# Si charge_time = 0 (soltamos rápido durante DRAWING), potencia baja proporcional al tensado
	if charge_time > 0.0:
		last_charge_power = clamp(charge_time / adjusted_charge_dur, 0.0, 1.0)
	else:
		var draw_progress = clamp(state_timer / adjusted_draw_time, 0.0, 1.0)
		last_charge_power = draw_progress * 0.15  # Máximo 15% de potencia si sueltas rápido durante DRAWING

	# Asegurar límites de potencia
	last_charge_power = clamp(last_charge_power, 0.05, 1.0)

	# Disparar la flecha física
	spawn_arrow_projectile()

	# Reproducir sonido de disparo de la arquera
	AudioManager.play_sfx("player_shoot")

	charge_time = 0.0


func agregar_flechas_multiples(cantidad: int = 6) -> void:
	if flechas_explosivas > 0:
		flechas_explosivas = 0
		flechas_explosivas_changed.emit(0)
	flechas_multiples += cantidad
	flechas_multiples_changed.emit(flechas_multiples)


func agregar_flechas_explosivas(cantidad: int = 10) -> void:
	if flechas_multiples > 0:
		flechas_multiples = 0
		flechas_multiples_changed.emit(0)
	flechas_explosivas += cantidad  # setter actualiza throttle
	flechas_explosivas_changed.emit(flechas_explosivas)


## Actualiza el flag de histéresis para mitigar drops explosivos
func _actualizar_throttle_explosivo() -> void:
	if not _explosive_drop_throttled and flechas_explosivas >= UMBRAL_EXPLOSIVO_MAX:
		_explosive_drop_throttled = true
	elif _explosive_drop_throttled and flechas_explosivas < UMBRAL_EXPLOSIVO_RELEASE:
		_explosive_drop_throttled = false

## True si el stock está en zona mitigada (30 hasta bajar a <25)
func is_explosive_drop_throttled() -> bool:
	return _explosive_drop_throttled

## Devuelve la chance efectiva mitigada a 5% si está throttled
func get_effective_explosive_drop_chance(base_chance: float) -> float:
	if _explosive_drop_throttled:
		return min(base_chance, DROP_CHANCE_MITIGADO)
	return base_chance


func spawn_arrow_projectile():
	if not arrow_scene:
		return

	# Calcular datos de disparo
	var data = calculate_shoot_data()
	if not data["valid"]:
		return

	# Obtener dirección hacia el mouse
	var shoot_dir = data["velocity"].normalized()

	# Calcular velocidad basada en la carga (usando variables exportadas)
	var arrow_speed = lerp(velocidad_flecha_minima, velocidad_flecha_maxima, last_charge_power)

	# Reducir velocidad según el ángulo de inclinación vertical (solo al disparar hacia arriba)
	var Factor_Angulo: float = 1.0
	if shoot_dir.y > 0.0:
		Factor_Angulo = 1.0 - (Reduccion_Velocidad_Por_Angulo * shoot_dir.y)
	arrow_speed *= Factor_Angulo

	var es_potencia_maxima: bool = (last_charge_power >= 0.98)

	# CASO 1: Flechas Múltiples activas (5 flechas normales en rápida sucesión)
	if flechas_multiples > 0:
		flechas_multiples -= 1
		flechas_multiples_changed.emit(flechas_multiples)
		_disparar_rafaga_flechas_multiples(data, shoot_dir, arrow_speed, es_potencia_maxima)
		return

	# CASO 2: Flechas Explosivas activas
	var es_flecha_explosiva: bool = false
	if flechas_explosivas > 0:
		flechas_explosivas -= 1
		flechas_explosivas_changed.emit(flechas_explosivas)
		es_flecha_explosiva = true

	# Instanciar la flecha (explosiva o estándar)
	var arrow_instance: Node = null
	if es_flecha_explosiva and explosive_arrow_scene:
		arrow_instance = explosive_arrow_scene.instantiate()
	else:
		arrow_instance = arrow_scene.instantiate()

	if "es_explosiva" in arrow_instance:
		arrow_instance.es_explosiva = es_flecha_explosiva

	# Inicializar la flecha con dirección y velocidad calculada
	arrow_instance.initialize(shoot_dir, arrow_speed)

	if es_potencia_maxima:
		arrow_instance.set_meta("is_max_power", true)

	# Agregar al árbol PRIMERO (para que _ready se ejecute y sea válido en el tree)
	get_tree().root.add_child(arrow_instance)

	# Posicionar DESPUÉS de agregar (ahora global_position funciona correctamente)
	arrow_instance.global_position = data["origin"]

	# GAME FEEL: Screen shake al disparar
	if has_node("/root/GameFeel"):
		get_node("/root/GameFeel").on_player_shoot()
		if es_potencia_maxima or es_flecha_explosiva:
			# Sacudida doble para potencia máxima o flecha explosiva
			get_node("/root/GameFeel").on_player_shoot()


func _disparar_rafaga_flechas_multiples(data: Dictionary, shoot_dir: Vector3, arrow_speed: float, es_potencia_maxima: bool) -> void:
	# Flecha 1: disparo inmediato
	var arrow_1 := arrow_scene.instantiate()
	arrow_1.initialize(shoot_dir, arrow_speed)
	if es_potencia_maxima:
		arrow_1.set_meta("is_max_power", true)
	get_tree().root.add_child(arrow_1)
	arrow_1.global_position = data["origin"]

	if has_node("/root/GameFeel"):
		get_node("/root/GameFeel").on_player_shoot()

	# 4 flechas restantes en rápida sucesión (total 5 flechas)
	for i in range(4):
		await get_tree().create_timer(0.055, false).timeout
		if not is_instance_valid(self) or not is_inside_tree():
			return

		var burst_data = calculate_shoot_data()
		var dir: Vector3 = burst_data["velocity"].normalized() if (burst_data and burst_data.get("valid", false)) else shoot_dir
		var origin: Vector3 = burst_data["origin"] if (burst_data and burst_data.get("valid", false)) else data["origin"]

		var arr: Node = arrow_scene.instantiate()
		arr.initialize(dir, arrow_speed)
		if es_potencia_maxima:
			arr.set_meta("is_max_power", true)
		get_tree().root.add_child(arr)
		arr.global_position = origin

		AudioManager.play_sfx("player_shoot")
		if has_node("/root/GameFeel"):
			get_node("/root/GameFeel").on_player_shoot()

	# GAME FEEL: Partículas de disparo (DESACTIVADO)
	# VFXFactory.spawn_muzzle_flash(get_tree().root, data["origin"], shoot_dir)


func actualizar_rotacion_torso_pitch():
	if not skeleton or not self.has_meta("bone_idx"):
		return
	var idx = self.get_meta("bone_idx")
	if idx == -1:
		return

	var camera = CameraUtilsRef.obtener_camara_juego(self)
	if not camera:
		return

	skeleton.set_bone_global_pose_override(idx, Transform3D.IDENTITY, 0.0, false)
	var current_pose = skeleton.get_bone_global_pose(idx)
	var current_position = current_pose.origin

	var mouse_pos = get_viewport().get_mouse_position()
	var player_screen_pos = camera.unproject_position(global_position)
	var direction_to_mouse = (mouse_pos - player_screen_pos).normalized()

	var pitch_angle = -asin(direction_to_mouse.y)
	pitch_angle = clamp(pitch_angle, deg_to_rad(angulo_minimo), deg_to_rad(angulo_maximo))

	if invertir_angulo:
		pitch_angle = -pitch_angle

	var axis_vec = Vector3.FORWARD
	if eje_rotacion == 0:
		axis_vec = Vector3.LEFT
	elif eje_rotacion == 1:
		axis_vec = Vector3.UP
	elif eje_rotacion == 2:
		axis_vec = Vector3.FORWARD

	var pitch_rotation = Quaternion(axis_vec, pitch_angle)
	var new_basis = current_pose.basis * Basis(pitch_rotation)

	# Si estamos escalando, añadir rotación en Y para apuntar hacia la izquierda
	# e invertir el pitch para que el apuntado sea correcto
	if current_move_state == MoveState.CLIMBING and not (armature_node and current_aim_state != AimState.NONE):
		var yaw_rotation = Quaternion(Vector3.UP, deg_to_rad(rotacion_torso_escalera))
		# Invertir pitch si está habilitado
		if invertir_pitch_escalera:
			var inverted_pitch = Quaternion(axis_vec, -pitch_angle * multiplicador_inversion_pitch)
			new_basis = new_basis * Basis(yaw_rotation) * Basis(inverted_pitch)
		else:
			new_basis = new_basis * Basis(yaw_rotation)

	skeleton.set_bone_global_pose_override(
		idx, Transform3D(new_basis, current_position), 1.0, false
	)


func reset_torso_bone():
	if not skeleton or not self.has_meta("bone_idx"):
		return
	var idx = self.get_meta("bone_idx")
	if idx != -1:
		skeleton.set_bone_global_pose_override(idx, Transform3D.IDENTITY, 0.0, false)


# --- FUNCIONES DE ANIMACIÓN DEL ARCO ---
func play_bow_animation(anim_name: String):
	if not bow_anim_player:
		return

	# Buscar la animación con diferentes prefijos posibles
	var full_anim_name = ""
	var possible_names = [
		anim_name,
		"Recurve Bow 2 Armature|" + anim_name,
		"Armature|" + anim_name,
		"Armature|Armature|" + anim_name
	]

	for anim in possible_names:
		if bow_anim_player.has_animation(anim):
			full_anim_name = anim
			break

	if full_anim_name != "":
		# Evitar spam: Si ya está sonando la misma, no hacer nada (excepto si queremos reiniciar, pero para idle/tensar vale)
		if bow_anim_player.current_animation == full_anim_name and bow_anim_player.is_playing():
			return

		bow_anim_player.speed_scale = 1.0
		bow_anim_player.play(full_anim_name)
		# print("→ Arco: Reproduciendo ", full_anim_name) # Comentado para evitar spam excesivo


func stop_bow_animation():
	if bow_anim_player:
		bow_anim_player.stop()


# --- FUNCIONES DE TRAYECTORIA Y UTILIDADES ---


func calculate_shoot_data() -> Dictionary:
	var result = {"origin": Vector3.ZERO, "velocity": Vector3.ZERO, "valid": false}

	var camera = CameraUtilsRef.obtener_camara_juego(self)
	if not camera:
		return result

	# Origen exacto de nacimiento de la flecha y trayectoria
	var marker: Marker3D = spawn_flecha_explosiva
	if not marker:
		marker = find_child("SpawnPosition_FlechaExplosiva", true, false) as Marker3D

	var spawn_pos: Vector3
	if marker and is_instance_valid(marker) and marker.is_inside_tree():
		if marker.get_parent() == self:
			# Si es hijo directo de Player, respetar su posición y voltear en X al mirar a la izquierda
			var x_dir: float = 1.0 if _mirando_derecha else -1.0
			spawn_pos = global_position + Vector3(marker.position.x * x_dir, marker.position.y, marker.position.z)
		else:
			# Si está emparentado a un hueso o modelo, usar su global_position exacta
			spawn_pos = marker.global_position
	elif explosive_arrow_node and is_instance_valid(explosive_arrow_node) and explosive_arrow_node.is_inside_tree():
		spawn_pos = explosive_arrow_node.global_position
	elif arrow_node and is_instance_valid(arrow_node) and arrow_node.is_inside_tree():
		spawn_pos = arrow_node.global_position
	else:
		spawn_pos = global_position + Vector3(0.45 if _mirando_derecha else -0.45, 1.25, 0.0)

	result["origin"] = spawn_pos

	# === MÉTODO SIMPLE: Usar posición en pantalla ===
	# Convertir posición del personaje a coordenadas de pantalla
	var player_screen = camera.unproject_position(spawn_pos)
	var mouse_pos = get_viewport().get_mouse_position()

	# Calcular dirección en pantalla (2D)
	var screen_dir = mouse_pos - player_screen

	# Convertir a dirección 3D:
	# - X de pantalla -> X del mundo (derecha/izquierda)
	# - Y de pantalla -> -Y del mundo (pantalla Y baja = mundo Y sube)
	# - Z = 0 siempre (2.5D)
	var shoot_direction = Vector3(screen_dir.x, -screen_dir.y, 0)

	if shoot_direction.length_squared() > 0.01:
		shoot_direction = shoot_direction.normalized()
	else:
		# Dirección por defecto según hacia dónde mira
		shoot_direction = Vector3.RIGHT if _mirando_derecha else Vector3.LEFT

	# Velocidad (usa los valores exportados)
	var adjusted_charge_dur = duracion_carga / multiplicador_velocidad_disparo
	var current_power = clamp(charge_time / adjusted_charge_dur, 0.0, 1.0)

	var speed = lerp(velocidad_flecha_minima, velocidad_flecha_maxima, current_power)
	var Factor_Angulo: float = 1.0
	if shoot_direction.y > 0.0:
		Factor_Angulo = 1.0 - (Reduccion_Velocidad_Por_Angulo * shoot_direction.y)
	speed *= Factor_Angulo
	result["velocity"] = shoot_direction * speed
	result["valid"] = true

	return result


# === SISTEMA DE DAÑO ===
## Alias de compatibilidad — las flechas enemigas llaman take_damage()
func take_damage(amount: float):
	recibir_dano(int(amount))


func _cancel_current_shot():
	_update_charge_vfx(false)
	# Cancelar cualquier estado de disparo actual
	if current_aim_state != AimState.NONE:
		# Marcar que el disparo fue cancelado (evita disparar al soltar clic)
		shot_cancelled = true

		# Detener el sonido de tensar cuerda si estaba sonando
		AudioManager.stop_bow_tension()
		AudioManager.reset_bow_hold()
		_bow_hold_timer = 0.0

		current_aim_state = AimState.NONE
		charge_time = 0.0
		state_timer = 0.0

		if charge_bar:
			charge_bar.visible = false

		_ocultar_flecha_visual()

		if anim_tree:
			anim_tree.set("parameters/UpperBody/transition_request", "none")
			anim_tree.set("parameters/AimBlend/blend_amount", 0.0)

		reset_torso_bone()
		stop_bow_animation()


func _setup_explosive_arrow_visual() -> void:
	# 1. Buscar si ya existe en la escena del jugador (nodo FlechaExplosiva o Flecha_Explosiva2)
	explosive_arrow_node = find_child("FlechaExplosiva", true, false) as Node3D
	if not explosive_arrow_node:
		explosive_arrow_node = find_child("Flecha_Explosiva*", true, false) as Node3D
	if not explosive_arrow_node:
		explosive_arrow_node = find_child("FLECHA_EXPLOSIVA*", true, false) as Node3D
	if not explosive_arrow_node:
		explosive_arrow_node = find_child("Flecha_Electrica*", true, false) as Node3D

	# 2. Si no existía en la escena, instanciarla dinámicamente como respaldo
	if not explosive_arrow_node and arrow_node and arrow_node.get_parent():
		var parent_attach = arrow_node.get_parent()
		var glb_scene = load("res://TEST_/Flecha_Explosiva.glb") as PackedScene
		if glb_scene:
			explosive_arrow_node = glb_scene.instantiate() as Node3D
			explosive_arrow_node.name = "Flecha_Explosiva2"
			parent_attach.add_child(explosive_arrow_node)
			var rot_adj = Basis(Vector3.UP, deg_to_rad(-90.0))
			explosive_arrow_node.transform = Transform3D(
				arrow_node.transform.basis * rot_adj * (0.305 / 0.4),
				arrow_node.transform.origin
			)
			var tip_light := OmniLight3D.new()
			tip_light.name = "RedTipLight"
			tip_light.light_color = Color(1.0, 0.15, 0.08)
			tip_light.light_energy = 0.8
			tip_light.omni_range = 0.9
			tip_light.position = Vector3(0.0, 0.0, 0.45)
			explosive_arrow_node.add_child(tip_light)

	if explosive_arrow_node:
		if explosive_arrow_node.scale.length_squared() > 0.001:
			_explosive_arrow_base_scale = explosive_arrow_node.scale
		elif arrow_node and arrow_node.scale.length_squared() > 0.001:
			_explosive_arrow_base_scale = arrow_node.scale
		else:
			_explosive_arrow_base_scale = Vector3(40.0, 40.0, 40.0)
		explosive_arrow_node.visible = false


func _mostrar_flecha_visual(factor_progreso: float = 1.0) -> void:
	if not explosive_arrow_node:
		_setup_explosive_arrow_visual()
	var es_explosiva: bool = (flechas_explosivas > 0)
	if es_explosiva and explosive_arrow_node and is_instance_valid(explosive_arrow_node):
		if arrow_node and is_instance_valid(arrow_node):
			arrow_node.visible = false
		explosive_arrow_node.visible = true
		explosive_arrow_node.scale = _explosive_arrow_base_scale * factor_progreso

		# Luz tenue y suave al cargarse
		var red_light = explosive_arrow_node.find_child("RedTipLight", true, false) as OmniLight3D
		if red_light and is_instance_valid(red_light):
			red_light.light_energy = lerp(0.2, 0.75, clamp(factor_progreso, 0.0, 1.0))
			red_light.omni_range = 0.9
	else:
		if explosive_arrow_node and is_instance_valid(explosive_arrow_node):
			explosive_arrow_node.visible = false
		if arrow_node and is_instance_valid(arrow_node):
			arrow_node.visible = true
			arrow_node.scale = _arrow_base_scale * factor_progreso


func _ocultar_flecha_visual() -> void:
	if arrow_node and is_instance_valid(arrow_node):
		arrow_node.visible = false
	if explosive_arrow_node and is_instance_valid(explosive_arrow_node):
		explosive_arrow_node.visible = false
	_ocultar_trayectoria_explosiva()


func _es_objeto_ignorable_por_flecha(obj: Object) -> bool:
	if not obj:
		return true
	if obj == self or (obj is Node and obj.is_in_group("player")):
		return true
	if obj is Node and obj.is_in_group("allies"):
		return true
	# Proyectiles en vuelo (las flechas no colisionan con proyectiles en el aire)
	if obj is ArrowProjectile or obj is EnemyProjectileBase or (obj is Node and (obj.is_in_group("projectiles") or obj.is_in_group("enemy_projectiles") or obj.is_in_group("flechas"))):
		return true
	# Si es un escudo o estructura aliada
	if obj.has_method("recibir_golpe") or (obj is Node and obj.is_in_group("escudos")):
		var es_enemigo: bool = false
		if "es_escudo_enemigo" in obj:
			es_enemigo = obj.es_escudo_enemigo
		elif "es_pilar_enemigo" in obj:
			es_enemigo = obj.es_pilar_enemigo
		elif obj is Node and obj.is_in_group("enemies"):
			es_enemigo = true
		if not es_enemigo:
			return true  # Escudo o estructura aliada -> la flecha la atraviesa

	# Ignorar cualquier Area3D que no sea enemigo o destructible (escaleras, triggers, agua, etc.)
	if obj is Area3D:
		if not (obj.is_in_group("enemies") or obj.is_in_group("destructibles") or obj.has_method("recibir_dano")):
			return true

	return false


func _setup_trayectoria_visual() -> void:
	if _trajectory_mesh_instance:
		return

	_trajectory_immediate_mesh = ImmediateMesh.new()

	var shader := load("res://System/Shaders/TRAYECTORIA_FLECHA_PUNTEADA.gdshader") as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.render_priority = 100
		_trajectory_material = mat
	else:
		_trajectory_material = StandardMaterial3D.new()
		_trajectory_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_trajectory_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_trajectory_material.vertex_color_use_as_albedo = true
		_trajectory_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_trajectory_material.no_depth_test = true
		_trajectory_material.render_priority = 100

	_trajectory_mesh_instance = MeshInstance3D.new()
	_trajectory_mesh_instance.name = "TrajectoryLineExplosive"
	_trajectory_mesh_instance.mesh = _trajectory_immediate_mesh
	_trajectory_mesh_instance.material_override = _trajectory_material
	_trajectory_mesh_instance.top_level = true
	_trajectory_mesh_instance.visible = false
	add_child(_trajectory_mesh_instance)

	# Nodo contenedor del marcador y mira en el punto de impacto
	_trajectory_impact_marker = Node3D.new()
	_trajectory_impact_marker.name = "TrajectoryImpactMarker"
	_trajectory_impact_marker.top_level = true
	_trajectory_impact_marker.visible = false

	# 1. Círculo / punto rojo central
	var dot_mesh_inst := MeshInstance3D.new()
	dot_mesh_inst.name = "CenterDot"
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.05
	dot_mesh.height = 0.10
	dot_mesh_inst.mesh = dot_mesh
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.albedo_color = Color(1.0, 0.1, 0.05, 0.95)
	dot_mat.no_depth_test = true
	dot_mat.render_priority = 101
	dot_mesh_inst.material_override = dot_mat
	_trajectory_impact_marker.add_child(dot_mesh_inst)

	# 2. Puntero / Mira de la flecha regular (Sprite3D con Mira mouse.png)
	var reticle_sprite := Sprite3D.new()
	reticle_sprite.name = "ReticleSprite"
	var tex := load(TEXTURA_CURSOR_MIRA) as Texture2D
	if tex:
		reticle_sprite.texture = tex
	reticle_sprite.pixel_size = 0.00075  # Tamaño proporcionado a la escala del mundo (~0.38m)
	reticle_sprite.modulate = Color(1.0, 0.25, 0.08, 0.95)
	reticle_sprite.render_priority = 102
	reticle_sprite.no_depth_test = true
	reticle_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_trajectory_impact_marker.add_child(reticle_sprite)

	add_child(_trajectory_impact_marker)


func _actualizar_trayectoria_explosiva() -> void:
	if flechas_explosivas <= 0 or current_aim_state == AimState.NONE or current_aim_state == AimState.SHOOTING:
		_ocultar_trayectoria_explosiva()
		return

	# Ocultar el cursor del ratón mientras se apunta con flecha explosiva
	if Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	if not _trajectory_mesh_instance:
		_setup_trayectoria_visual()

	var data := calculate_shoot_data()
	if not data or not data.get("valid", false):
		_ocultar_trayectoria_explosiva()
		return

	var spawn_pos: Vector3 = data["origin"]
	var vel: Vector3 = data["velocity"]
	if vel.length_squared() < 0.01:
		_ocultar_trayectoria_explosiva()
		return

	var plano_z: float = global_position.z
	var pos: Vector3 = spawn_pos
	pos.z = plano_z

	var world_grav: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var dt: float = 0.025  # ~40 muestras / seg
	var max_pasos: int = 220  # hasta ~5.5s de trayectoria completa para garantizar impacto en suelo o enemigo

	var space_state := get_world_3d().direct_space_state
	var puntos: Array[Vector3] = [pos]
	var punto_impacto: Vector3 = Vector3.ZERO
	var hubo_impacto: bool = false

	# Raycast para detectar dónde colisionará la flecha (máscara 255 = todas las capas relevantes)
	var excluded_rids: Array[RID] = [get_rid()]
	var query_params := PhysicsRayQueryParameters3D.new()
	query_params.collision_mask = 255
	query_params.collide_with_areas = true
	query_params.collide_with_bodies = true
	query_params.exclude = excluded_rids

	for _i in range(max_pasos):
		var sig_vel := vel
		sig_vel.y -= world_grav * dt
		var sig_pos := pos + (vel + sig_vel) * 0.5 * dt
		sig_pos.z = plano_z

		# Comprobar colisión ignorando escudos aliados, proyectiles y triggers
		var ray_origen := pos
		var colision_valida := false
		var iteraciones_paso := 0

		while iteraciones_paso < 5:
			iteraciones_paso += 1
			query_params.from = ray_origen
			query_params.to = sig_pos
			query_params.exclude = excluded_rids
			var col := space_state.intersect_ray(query_params)
			if col.is_empty():
				break

			var col_obj: Object = col.get("collider", null)
			var col_pos: Vector3 = col.get("position", sig_pos)
			var col_rid = col.get("rid", null)

			# Ignorar si está a menos de 30cm del origen de disparo o si es objeto ignorable
			if col_pos.distance_squared_to(spawn_pos) < 0.09 or _es_objeto_ignorable_por_flecha(col_obj):
				if col_rid and not excluded_rids.has(col_rid):
					excluded_rids.append(col_rid)
					query_params.exclude = excluded_rids
				var dir_paso: Vector3 = sig_pos - col_pos
				if dir_paso.length_squared() < 0.0001:
					break
				ray_origen = col_pos + dir_paso.normalized() * 0.05
			else:
				punto_impacto = col_pos
				punto_impacto.z = plano_z
				puntos.append(punto_impacto)
				hubo_impacto = true
				colision_valida = true
				break

		if colision_valida:
			break

		pos = sig_pos
		vel = sig_vel
		puntos.append(pos)

	# Si no hubo impacto en el rango, proyectar hacia el plano del suelo para no cortarse en el aire
	if not hubo_impacto and puntos.size() > 1:
		var last_p := puntos[puntos.size() - 1]
		query_params.from = last_p
		query_params.to = last_p + Vector3(0.0, -15.0, 0.0)
		var ground_col := space_state.intersect_ray(query_params)
		if not ground_col.is_empty():
			punto_impacto = ground_col.get("position", last_p)
			punto_impacto.z = plano_z
			puntos.append(punto_impacto)
			hubo_impacto = true
		else:
			punto_impacto = last_p
			punto_impacto.y = 0.0
			punto_impacto.z = plano_z
			puntos.append(punto_impacto)
			hubo_impacto = true

	if puntos.size() < 2:
		_ocultar_trayectoria_explosiva()
		return

	# Dibujar Ribbon 2.5D punteado y estático con ImmediateMesh
	_trajectory_immediate_mesh.clear_surfaces()
	_trajectory_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _trajectory_material)

	var num_puntos: int = puntos.size()
	var dist_acumulada: float = 0.0

	# Transición de aparición suave durante 1.0 segundo al apuntar
	var fade_in_alpha: float = clampf(_trajectory_fade_timer / 1.0, 0.0, 1.0)
	fade_in_alpha = smoothstep(0.0, 1.0, fade_in_alpha)

	for i in range(num_puntos):
		var p: Vector3 = puntos[i]
		if i > 0:
			dist_acumulada += p.distance_to(puntos[i - 1])

		var t: float = float(i) / float(num_puntos - 1)

		# Tangente
		var tangente: Vector3 = Vector3.RIGHT
		if i < num_puntos - 1:
			tangente = (puntos[i + 1] - p).normalized()
		elif i > 0:
			tangente = (p - puntos[i - 1]).normalized()

		# Normal perpendicular en plano XY
		var normal_cinta := Vector3(-tangente.y, tangente.x, 0.0).normalized()

		# Ancho cónico: base más gruesa (~6.5 cm) y punta fina (~1.5 cm)
		var ancho_cinta: float = lerp(0.065, 0.015, t)

		# Fading de transparencia al final combinado con el fade-in de 1 segundo
		var alfa: float = lerp(1.0, 0.18, t) * fade_in_alpha
		# COLOR.r = t (progreso a lo largo del arco), COLOR.a = alfa
		var col := Color(t, 1.0, 1.0, alfa)

		_trajectory_immediate_mesh.surface_set_color(col)
		_trajectory_immediate_mesh.surface_set_uv(Vector2(dist_acumulada, 0.0))
		_trajectory_immediate_mesh.surface_add_vertex(p + normal_cinta * (ancho_cinta * 0.5))

		_trajectory_immediate_mesh.surface_set_color(col)
		_trajectory_immediate_mesh.surface_set_uv(Vector2(dist_acumulada, 1.0))
		_trajectory_immediate_mesh.surface_add_vertex(p - normal_cinta * (ancho_cinta * 0.5))

	_trajectory_immediate_mesh.surface_end()
	_trajectory_mesh_instance.visible = true

	# Ubicar el puntero / reticle y el círculo rojo en el punto de impacto
	if not hubo_impacto:
		punto_impacto = puntos[puntos.size() - 1]

	if _trajectory_impact_marker:
		_trajectory_impact_marker.global_position = punto_impacto
		_trajectory_impact_marker.visible = true
		var reticle := _trajectory_impact_marker.find_child("ReticleSprite", true, false) as Sprite3D
		if reticle:
			reticle.modulate.a = 0.95 * fade_in_alpha
		var center_dot := _trajectory_impact_marker.find_child("CenterDot", true, false) as MeshInstance3D
		if center_dot and center_dot.material_override is StandardMaterial3D:
			center_dot.material_override.albedo_color.a = 0.95 * fade_in_alpha


func _ocultar_trayectoria_explosiva() -> void:
	_trajectory_fade_timer = 0.0
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if not _cursor_sistema_activo:
			_aplicar_cursor_mira()

	if _trajectory_mesh_instance and is_instance_valid(_trajectory_mesh_instance):
		_trajectory_mesh_instance.visible = false
		if _trajectory_immediate_mesh:
			_trajectory_immediate_mesh.clear_surfaces()
	if _trajectory_impact_marker and is_instance_valid(_trajectory_impact_marker):
		_trajectory_impact_marker.visible = false


func _play_hit_animation():
	# Usar HitOneShot para permitir caminar mientras se recibe daño
	if not anim_tree:
		return

	# Disparar la animación HIT (OneShot)
	# Al tener filtros en el torso, las piernas seguirán caminando
	anim_tree.set("parameters/HitOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _flash_damage():
	# OPT: Usar material cacheado en vez de crear uno nuevo cada daño
	if not _flash_material:
		_flash_material = StandardMaterial3D.new()
		_flash_material.albedo_color = Color(1, 0.3, 0.3)

	# Cambiar a rojo
	for mesh in _cached_mesh_instances:
		if mesh.material_override == null:
			mesh.material_override = _flash_material

	# Restaurar después de un tiempo
	await get_tree().create_timer(0.1).timeout
	for mesh in _cached_mesh_instances:
		if is_instance_valid(mesh):
			mesh.material_override = null


# ═══════════════════════════════════════════════════════════════════════════════
# SISTEMA DE RECIBIR DAÑO
# ═══════════════════════════════════════════════════════════════════════════════
func recibir_dano(cantidad: int = 1):
	# Verificar invulnerabilidad o modo dios
	if is_invulnerable or modo_dios or is_dead:
		return

	# Reducir vida
	health -= cantidad
	health_changed.emit(health)

	# IMPORTANTE: Cancelar disparo actual cuando recibimos daño
	_cancel_current_shot()

	# Flash visual
	_flash_damage()

	# Animación de hit
	_play_hit_animation()

	# Reproducir sonido de daño
	AudioManager.play_sfx("player_hurt")

	# Si estamos en escalera y la opción está activada, caer
	if current_move_state == MoveState.CLIMBING and caer_escalera_al_recibir_dano:
		_caer_de_escalera()

	# Verificar muerte
	if health <= 0:
		_die()
	else:
		# Activar invulnerabilidad temporal
		is_invulnerable = true
		invulnerability_timer = invulnerability_duration

		# Bloqueo de disparo
		is_shot_locked = true

		# Timers independientes
		get_tree().create_timer(invulnerability_duration).timeout.connect(
			func():
				if is_instance_valid(self) and is_inside_tree():
					is_invulnerable = false
		)
		get_tree().create_timer(shot_lock_duration).timeout.connect(
			func():
				if is_instance_valid(self) and is_inside_tree():
					is_shot_locked = false
		)


func _caer_de_escalera():
	# NO desconectamos is_near_ladder porque físicamente seguimos ahí
	# Solo impedimos reconectar inmediatamente con cooldown
	ladder_cooldown = 0.5

	current_ladder = null
	current_move_state = MoveState.AIR

	# Cancelar cualquier disparo en curso
	_cancel_current_shot()

	# Restaurar rotación del armature
	_reset_armature_rotation()

	# Dar un pequeño impulso hacia atrás
	velocity.y = 0.5
	velocity.x = 0.5  # Empujar ligeramente hacia la derecha (alejándose del muro)


func _die():
	if is_dead:
		return

	is_dead = true
	died.emit()

	# GAME FEEL: Slow motion dramático al morir
	if has_node("/root/GameFeel"):
		get_node("/root/GameFeel").on_player_death()

	# Cancelar cualquier disparo
	_cancel_current_shot()
	_ajustar_hitbox_agachado(false)

	# Restaurar rotación del armature si estamos en escalera
	if current_move_state == MoveState.CLIMBING:
		_reset_armature_rotation()

	# Si estamos en el aire o en escalera, caer al suelo primero
	if (
		current_move_state == MoveState.CLIMBING
		or current_move_state == MoveState.AIR
		or not is_on_floor()
	):
		# Desconectar de la escalera si aplica
		if current_move_state == MoveState.CLIMBING:
			is_near_ladder = false
			current_ladder = null

		current_move_state = MoveState.AIR
		# Esperar a tocar el suelo antes de reproducir muerte
		await _wait_for_ground_death()

	# Cambiar a estado de muerte
	current_move_state = MoveState.DEAD
	velocity = Vector3.ZERO

	# Reproducir animación de muerte
	if anim_tree:
		anim_tree.set("parameters/MotionState/transition_request", "death")

	# Reproducir sonido de muerte
	AudioManager.play_sfx("player_death")
	_crear_splash_sangre_muerte()


func _crear_splash_sangre_muerte() -> void:
	var blood_scene: PackedScene = preload("res://VFX/Scenes/BloodSplashNormal.tscn")
	if not blood_scene:
		return
	var splash = blood_scene.instantiate() as BloodSplash2D
	if not splash:
		return

	var root := get_tree().current_scene
	if root:
		root.add_child(splash)
	else:
		get_parent().add_child(splash)

	# Dirección invertida (hacia la izquierda -X) acorde a proyectiles enemigos que impactan desde la derecha
	splash.setup(global_position + Vector3(0.0, 0.8, 0.0), Vector3.LEFT, Color.WHITE)


func _wait_for_ground_death():
	# Esperar hasta tocar el suelo mientras cae con gravedad
	var timeout = 3.0
	while not is_on_floor() and timeout > 0:
		# Aplicar gravedad manualmente durante la caída
		velocity.y -= gravity * get_physics_process_delta_time()
		move_and_slide()
		await get_tree().process_frame
		timeout -= get_process_delta_time()


func curar(cantidad: int = 1) -> void:
	if is_dead:
		return
	health = min(health + cantidad, vida_maxima)
	health_changed.emit(health)


# ═══════════════════════════════════════════════════════════════════════════════
# SISTEMA DE REVIVIR
# ═══════════════════════════════════════════════════════════════════════════════
func revive():
	if not is_dead:
		return

	is_dead = false
	health = vida_maxima
	health_changed.emit(health)
	current_move_state = MoveState.GROUND

	if anim_tree:
		anim_tree.set("parameters/MotionState/transition_request", "ground")


# ═══════════════════════════════════════════════════════════════════════════════
# JUICE & VFX COMPLEMENTS
# ═══════════════════════════════════════════════════════════════════════════════
var _charge_vfx: CPUParticles3D = null
var _soft_particle_material: StandardMaterial3D = null


## Crea un material de partícula suave con textura de círculo difuso generada
## programáticamente mediante GradientTexture2D radial.
func _get_soft_particle_material() -> StandardMaterial3D:
	if _soft_particle_material:
		return _soft_particle_material.duplicate()
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
	_soft_particle_material = StandardMaterial3D.new()
	_soft_particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_soft_particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_soft_particle_material.use_particle_colors = true
	_soft_particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_soft_particle_material.vertex_color_use_as_albedo = true
	_soft_particle_material.albedo_texture = tex
	return _soft_particle_material.duplicate()


func _create_particle_mesh(particle_size: float) -> QuadMesh:
	var qmesh = QuadMesh.new()
	qmesh.size = Vector2(particle_size, particle_size)
	qmesh.material = _get_soft_particle_material()
	return qmesh


func _update_charge_vfx(active: bool):
	if active:
		if is_instance_valid(_charge_vfx):
			return
		_charge_vfx = CPUParticles3D.new()
		_charge_vfx.name = "ChargeVFX"
		_charge_vfx.amount = 12
		_charge_vfx.lifetime = 0.4
		_charge_vfx.local_coords = true
		_charge_vfx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_charge_vfx.emission_sphere_radius = 0.4
		_charge_vfx.gravity = Vector3.ZERO
		_charge_vfx.radial_accel_min = -6.0
		_charge_vfx.radial_accel_max = -3.0
		_charge_vfx.tangential_accel_min = 1.0
		_charge_vfx.tangential_accel_max = 2.0
		var gradient = Gradient.new()
		gradient.set_color(0, Color(0.4, 0.7, 1.0, 0.6))
		gradient.set_color(1, Color(0.6, 0.9, 1.0, 0.0))
		_charge_vfx.color_ramp = gradient
		_charge_vfx.scale_amount_min = 0.02
		_charge_vfx.scale_amount_max = 0.06
		var scale_curve = Curve.new()
		scale_curve.add_point(Vector2(0, 0.2))
		scale_curve.add_point(Vector2(0.6, 1.0))
		scale_curve.add_point(Vector2(1.0, 0.0))
		_charge_vfx.scale_amount_curve = scale_curve
		_charge_vfx.mesh = _create_particle_mesh(0.06)
		if arrow_node:
			arrow_node.add_child(_charge_vfx)
			_charge_vfx.position = Vector3(0, 0, 0.2)
	else:
		if is_instance_valid(_charge_vfx):
			_charge_vfx.queue_free()
			_charge_vfx = null
