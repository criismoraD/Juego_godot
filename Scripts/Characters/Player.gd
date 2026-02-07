extends CharacterBody3D

# === CONFIGURACIÓN - MOVIMIENTO ===
@export_category("Movimiento")
@export var velocidad_caminar: float = 0.5 # Velocidad al caminar
@export var velocidad_correr: float = 1.0 # Velocidad al correr
@export var fuerza_salto: float = 2.0 # Fuerza del salto
@export var umbral_aterrizaje: float = -3.0 # Umbral para aterrizaje fuerte

# === CONFIGURACIÓN - DISPARO ===
@export_category("Disparo")
@export var multiplicador_velocidad_disparo: float = 1.0 # Velocidad de animaciones de disparo
@export var cadencia_disparo: float = 0.01 # Tiempo mínimo entre disparos (cooldown)
@export var tiempo_tensar: float = 0.1 # Tiempo para tensar el arco
@export var duracion_carga: float = 0.5 # Tiempo para cargar al máximo

@export var velocidad_flecha_minima: float = 2.5 # Velocidad mínima de la flecha (clic rápido)
@export var velocidad_flecha_maxima: float = 15.0 # Velocidad máxima de la flecha (carga completa)

# === CONFIGURACIÓN - APUNTADO ===
@export_category("Apuntado")
@export_range(-90, 90, 0.1) var angulo_minimo: float = -45.0 # Ángulo mínimo de apuntado
@export_range(-90, 90, 0.1) var angulo_maximo: float = 70.0 # Ángulo máximo de apuntado
@export var invertir_angulo: bool = true
@export var altura_barra: float = 0.7 # Altura de la barra de carga
@export_range(-180, 180, 1.0) var rotacion_torso_escalera: float = -180.0 # Giro del torso al disparar en escalera
@export var invertir_pitch_escalera: bool = true # Invertir dirección de apuntado en escalera
@export_range(-10.0, 10.0, 0.1) var multiplicador_inversion_pitch: float = -2.0 # Multiplicador de inversión en escalera

@export_enum("X (Izq/Der)", "Y (Arriba/Abajo)", "Z (Adelante/Atras)") var eje_rotacion: int = 2

# Eje de disparo interno (no expuesto)
var eje_disparo: int = 0

# === SISTEMA DE VIDA ===
@export_category("Vida")
@export var vida_maxima: int = 5
@export var modo_dios: bool = false # Inmune a todo daño (god mode)
@export var caer_escalera_al_recibir_dano: bool = true

# Duración de la invulnerabilidad tras recibir daño
@export var invulnerability_duration: float = 1.5

# Tiempo que no puedes disparar tras recibir daño
@export var shot_lock_duration: float = 0.2

# === CONFIGURACIÓN - EFECTOS VISUALES ===
@export_category("Efectos Visuales")
@export var mostrar_particulas_aterrizaje: bool = false # Desactivado: partículas muy grandes

@export_subgroup("Partículas de Salto")
@export var color_particulas_salto: Color = Color(0.7, 0.65, 0.5, 0.5) # Color de las partículas
@export_range(0.01, 0.5, 0.01) var escala_min_salto: float = 0.05 # Tamaño mínimo
@export_range(0.01, 0.5, 0.01) var escala_max_salto: float = 0.15 # Tamaño máximo

# Escena del proyectil flecha
var arrow_scene = preload("res://Scenes/Projectiles/Arrow.tscn")

# --- REFERENCIAS ---
var anim_tree: AnimationTree
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var bow_anim_player: AnimationPlayer # AnimationPlayer del arco
var arrow_node: Node3D # Nodo de la flecha para visibilidad

# --- ESTADO ---
enum AimState {NONE, DRAWING, AIMING, SHOOTING}
var current_aim_state = AimState.NONE
var state_timer = 0.0

# Estados de Movimiento
enum MoveState {GROUND, AIR, LANDING, CLIMBING, DEAD}
var current_move_state = MoveState.GROUND
var landing_timer = 0.0
var landing_anim_duration = 0.5 # Se auto-calcula
var is_dead: bool = false
var ladder_cooldown: float = 0.0 # Tiempo de espera para volver a agarrar la escalera
var is_inside_platform: bool = false # Bloquea movimiento lateral

var charge_time = 0.0
var last_charge_power = 0.0 # Potencia al momento de disparar (0.0 a 1.0)
var charge_bar: ProgressBar

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# === VIDA ===
var health: int = 5
var is_invulnerable: bool = false
var invulnerability_timer: float = 0.0
var shot_cancelled: bool = false # Flag para cancelar disparo cuando nos dañan
var is_shot_locked: bool = false # Flag de bloqueo de disparo temporal

# === AUDIO ===
# Gestionado por AudioManager (singleton)

# === GAME FEEL ===
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
const COYOTE_TIME: float = 0.15
const JUMP_BUFFER_TIME: float = 0.12

# === SEÑALES ===
signal health_changed(new_health: int)
signal died

func _ready():
	add_to_group("player")
	health = vida_maxima
	anim_tree = find_child("AnimationTree", true, false)
	skeleton = find_child("Skeleton3D", true, false)
	
	# Añadir layer 10 al collision_mask para colisionar con BarreraLimite
	# Layer 10 = bit 9 (los layers son 1-indexed pero los bits son 0-indexed)
	collision_mask = collision_mask | (1 << 9) # Añadir layer 10
	
	if anim_tree:
		# CONSTRUIR ÁRBOL DINÁMICAMENTE (Para evitar corrupciones del editor)
		setup_animation_tree_dynamic()
		
		anim_tree.active = true
		
		anim_player = anim_tree.get_node(anim_tree.anim_player)
		if anim_player:
			var anims_to_loop = [
				"Armature|IDLE", "Armature|CAMINAR_ADELANTE", "Armature|CAMINAR_ATRAS", "Armature|APUNTAR_IDLE",
				"Armature|CORRER_ADELANTE", "Armature|SUBIR_ESCALERA"
			]
			for anim_name in anims_to_loop:
				if anim_player.has_animation(anim_name):
					anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	else:
		pass # Error: No AnimationTree
	
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
		arrow_node.visible = false
	
	# Buscar Armature para rotación de escalera
	armature_node = find_child("Armature", true, false)
	if not armature_node:
		armature_node = find_child("ArqueraModel", true, false)
	if armature_node:
		armature_original_rotation = armature_node.rotation

	create_charge_bar()

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DINÁMICA DEL ÁRBOL DE ANIMACIÓN
# ═══════════════════════════════════════════════════════════════════════════════
func setup_animation_tree_dynamic():
	var root = AnimationNodeBlendTree.new()
	
	# ───────────────────────────────────────────────────────────────────────────
	# SECCIÓN 1: NODOS DE ANIMACIÓN BASE
	# ───────────────────────────────────────────────────────────────────────────
	var node_idle = AnimationNodeAnimation.new()
	node_idle.animation = "Armature|IDLE"
	
	var node_walk_fwd = AnimationNodeAnimation.new()
	node_walk_fwd.animation = "Armature|CAMINAR_ADELANTE"
	
	var node_walk_back = AnimationNodeAnimation.new()
	node_walk_back.animation = "Armature|CAMINAR_ATRAS"
	
	var node_run_fwd = AnimationNodeAnimation.new()
	node_run_fwd.animation = "Armature|CORRER_ADELANTE"
	
	var node_aim = AnimationNodeAnimation.new()
	node_aim.animation = "Armature|APUNTAR_IDLE"
	
	var node_shoot = AnimationNodeAnimation.new()
	node_shoot.animation = "Armature|DISPARAR"
	
	var node_draw = AnimationNodeAnimation.new()
	node_draw.animation = "Armature|TOMAR_FLECHA"
	
	var node_none = AnimationNodeAnimation.new()
	node_none.animation = "Armature|IDLE"
	
	var node_jump_fall = AnimationNodeAnimation.new()
	node_jump_fall.animation = "Armature|CAER_SALTAR"
	
	var node_land = AnimationNodeAnimation.new()
	node_land.animation = "Armature|ATERRIZAJE"
	
	var node_climb = AnimationNodeAnimation.new()
	node_climb.animation = "Armature|SUBIR_ESCALERA"
	
	var node_death = AnimationNodeAnimation.new()
	node_death.animation = "Armature|MUERTE"
	
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
	
	# C. MotionState (Estados de movimiento principales)
	var trans_motion = AnimationNodeTransition.new()
	trans_motion.input_count = 5
	trans_motion.set_input_name(0, "ground")
	trans_motion.set_input_name(1, "air")
	trans_motion.set_input_name(2, "land")
	trans_motion.set_input_name(3, "climb")
	trans_motion.set_input_name(4, "death")
	trans_motion.xfade_time = 0.2
	root.add_node("MotionState", trans_motion)
	
	# D. UpperBody (Acciones de torso superior)
	var trans_upper = AnimationNodeTransition.new()
	trans_upper.input_count = 4
	trans_upper.set_input_name(0, "none")
	trans_upper.set_input_name(1, "aim")
	trans_upper.set_input_name(2, "shoot")
	trans_upper.set_input_name(3, "draw")
	trans_upper.xfade_time = 0.2
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
	node_hit.animation = "Armature|HIT"
	
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
	root.connect_node("MotionState", 2, "Land")
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
@export var velocidad_escalar_subir: float = 2.0
@export var velocidad_escalar_bajar: float = 2.0
@export_range(-360, 360, 1.0) var rotacion_personaje_escalera: float = 180.0 # Giro del modelo al escalar

# Referencia al Armature para rotarlo
var armature_node: Node3D = null
var armature_original_rotation: Vector3 = Vector3.ZERO

func set_near_ladder(val, ladder_area):
	is_near_ladder = val
	if val:
		current_ladder = ladder_area
	else:
		current_ladder = null
		if current_move_state == MoveState.CLIMBING:
			stop_climbing()

func stop_climbing():
	current_move_state = MoveState.AIR
	velocity.y = 0.5
	set_motion_anim("air")
	
	# Restaurar rotación original del armature
	_reset_armature_rotation()

func _apply_climbing_rotation():
	# Rotar el modelo para la animación de escalera
	if armature_node:
		armature_node.rotation.y = armature_original_rotation.y + deg_to_rad(rotacion_personaje_escalera)

func _reset_armature_rotation():
	# Restaurar rotación original del modelo
	if armature_node:
		armature_node.rotation = armature_original_rotation

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
	
	# Guardar velocidad vertical PREVIA al movimiento (para detectar impacto)
	var prev_vel_y = velocity.y
	
	# --- MÁQUINA DE ESTADOS DE MOVIMIENTO SIMPLE ---
	
	# 1. GRAVEDAD (Solo si no escalamos)
	if current_move_state != MoveState.CLIMBING:
		if not is_on_floor():
			velocity.y -= gravity * delta
			if current_move_state != MoveState.LANDING: # Si no estamos aterrizando, estamos en aire
				current_move_state = MoveState.AIR
		
		# Mantener rotación estándar lateral (ej 90 grados) si no estamos escalando
		# IMPORTANTE: Si es 2.5D lateral, el personaje en sí (Root) suele estar rotado 90 grados.
		# No forzamos rotación aquí para dejar libertad, salvo resetear Armature si fuera necesario.
		pass
	
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
				tween.tween_property(self, "global_position:x", current_ladder.global_position.x, 0.2)
			
			_cancel_current_shot()
			_apply_climbing_rotation() # Aplicar rotación de escalera
	
	# 2. MOVIMIENTO FÍSICO
	move_and_slide()
	
	# 3. DETECCIÓN DE ATERRIZAJE (Post-movimiento)
	if is_on_floor():
		if current_move_state == MoveState.CLIMBING:
			if input_vert > 0: # Bajando
				current_move_state = MoveState.GROUND
				set_motion_anim("ground")
				_reset_armature_rotation()
		
		# Acabamos de tocar suelo viniendo del aire?
		elif current_move_state == MoveState.AIR:
			# ATERRIZAJE CONDICIONAL
			if prev_vel_y < umbral_aterrizaje:
				start_landing() # Caída fuerte -> Bloqueo
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
			coyote_timer = COYOTE_TIME # Resetear coyote time en suelo
			
			if Input.is_action_just_pressed("ui_accept"):
				_perform_jump()
			
			apply_movement(input_dir)
			
			if anim_tree:
				set_motion_anim("ground")
				update_locomotion_anim(input_dir)
				
		MoveState.CLIMBING:
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
				if input_vert > 0: # Si input es positivo (S/Abajo), estamos bajando
					climb_speed = velocidad_escalar_bajar
				
				velocity.y = - input_vert * climb_speed
				
				# Bloquear movimiento lateral si estamos atravesando una plataforma
				if is_inside_platform:
					velocity.x = 0
				else:
					velocity.x = input_dir * velocidad_caminar # Permitir movimiento lateral (A/D)
				
				# Ajustar velocidad de animación (invertir si bajamos)
				if anim_tree:
					var scale_val = 1.0
					if input_vert > 0.1: # Bajando
						scale_val = -1.0
					elif input_vert < -0.1: # Subiendo
						scale_val = 1.0
					else:
						scale_val = 0.0 # Quieto
					
					# El nombre del parámetro es "Climb" porque así nombramos al nodo TimeScale
					anim_tree.set("parameters/Climb/scale", scale_val)
			
			set_motion_anim("climb")
			
			# Saltar para soltarse
			if Input.is_action_just_pressed("ui_accept"):
				stop_climbing()
				velocity.y = fuerza_salto * 0.5

		MoveState.AIR:
			apply_movement(input_dir)
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

func apply_movement(input_dir):
	var current_speed = velocidad_correr
	if current_aim_state == AimState.DRAWING or current_aim_state == AimState.AIMING:
		current_speed = velocidad_caminar
	
	if input_dir:
		velocity.x = input_dir * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)

func start_landing():
	current_move_state = MoveState.LANDING
	landing_timer = 0.0
	
	# GAME FEEL: Screen shake en aterrizaje fuerte
	if has_node("/root/GameFeel"):
		get_node("/root/GameFeel").on_hard_landing()
	
	# Calcular duracion real land
	landing_anim_duration = 0.5
	if anim_player and anim_player.has_animation("Armature|ATERRIZAJE"):
		landing_anim_duration = anim_player.get_animation("Armature|ATERRIZAJE").length
	
	# CANCELAR AIM / SHOOT
	current_aim_state = AimState.NONE
	charge_time = 0.0
	charge_bar.visible = false
	if anim_tree:
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
	coyote_timer = 0 # Consumir coyote time
	jump_buffer_timer = 0 # Consumir buffer
	_spawn_jump_vfx()
	
	# GAME FEEL: Screen shake ligero opcional
	# if has_node("/root/GameFeel"):
	#     get_node("/root/GameFeel").shake(GameFeelManager.ShakePreset.LIGHT)

func _can_jump() -> bool:
	# Puede saltar si está en suelo O tiene coyote time
	return is_on_floor() or coyote_timer > 0

func _spawn_jump_vfx() -> void:
	# Llamar a VFXFactory con los parámetros configurables desde el inspector
	VFXFactory.spawn_jump(get_tree().root, global_position,
		color_particulas_salto, escala_min_salto, escala_max_salto)

func _spawn_landing_vfx() -> void:
	# Verificar si las partículas de aterrizaje están habilitadas
	if not mostrar_particulas_aterrizaje:
		return
	# Llamar a VFXFactory directamente (clase estática)
	VFXFactory.spawn_landing(get_tree().root, global_position, 1.5)

func set_motion_anim(state_name):
	if anim_tree.get("parameters/MotionState/current_state") != state_name:
		anim_tree.set("parameters/MotionState/transition_request", state_name)

func update_locomotion_anim(input_dir):
	var loc_path = "parameters/Locomotion/transition_request"
	if input_dir > 0.1:
		if current_aim_state == AimState.AIMING or current_aim_state == AimState.DRAWING:
			anim_tree.set(loc_path, "walk_fwd")
		else:
			anim_tree.set(loc_path, "run_fwd")
	elif input_dir < -0.1:
		anim_tree.set(loc_path, "walk_back")
	else:
		anim_tree.set(loc_path, "idle")

func _process_gameplay(delta):
	control_visual_state(delta)
	update_charge_bar_position()

func update_charge_bar_position():
	if not charge_bar.visible: return
	
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	var head_pos = global_position + Vector3(0, altura_barra, 0)
	
	if not camera.is_position_behind(head_pos):
		var screen_pos = camera.unproject_position(head_pos)
		charge_bar.position = screen_pos - (charge_bar.size / 2)
	else:
		charge_bar.visible = false

func control_visual_state(delta):
	# BLOQUEAR TODO SI ESTAMOS MUERTOS
	if is_dead:
		return
	
	# Si estamos aterrizando, NO permitimos aiming
	if current_move_state == MoveState.LANDING:
		return

	if not anim_tree: return
	
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
			

			if arrow_node: arrow_node.visible = false # Asegurar oculta
			
			var current = float(anim_tree.get(blend_path))
			if current > 0.0:
				anim_tree.set(blend_path, move_toward(current, 0.0, 5.0 * delta * multiplicador_velocidad_disparo))
			
			reset_torso_bone()
			
			# Mantener animación idle del arco
			if bow_anim_player and not bow_anim_player.is_playing():
				play_bow_animation("ARCO_IDLE")
			
			# Resetear shot_cancelled cuando el usuario suelta el clic
			if shot_cancelled and not Input.is_action_pressed("click_izquierdo"):
				shot_cancelled = false
			
			if Input.is_action_just_pressed("click_izquierdo"):
				# Bloquear disparo si el disparo fue cancelado (debe soltar y volver a presionar)
				if shot_cancelled:
					return
				
				# Bloquear disparo si estamos bloqueados temporalment por daño (0.2s)
				if is_shot_locked:
					return
				
				# Bloquear disparo si estamos dentro de una plataforma
				if is_inside_platform:
					return
					
				# EXPERIMENTAL: Permitir disparo mientras escalamos
				# (Comentar las siguientes 2 líneas para bloquear)
				# if current_move_state == MoveState.CLIMBING:
				# 	return
				# Cancelar animación de HIT si está activa
				if anim_tree:
					anim_tree.set("parameters/HitOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
				
				current_aim_state = AimState.DRAWING
				state_timer = 0.0
				anim_tree.set(upper_path, "draw")
				# Iniciar animación de tensar el arco
				play_bow_animation("ARCO_TENSAR")
				# Reproducir sonido de tensar cuerda (se puede detener)
				AudioManager.play_bow_tension()
				# Mostrar la flecha y resetear escala
				if arrow_node:
					arrow_node.visible = true
					arrow_node.scale = Vector3.ZERO # Empezar pequeña
				
				
		AimState.DRAWING:
			var current = float(anim_tree.get(blend_path))
			if current < 1.0:
				anim_tree.set(blend_path, move_toward(current, 1.0, 5.0 * delta * multiplicador_velocidad_disparo))
			
			state_timer += delta
			actualizar_rotacion_torso_pitch()
			
			if Input.is_action_just_released("click_izquierdo"):
				# Si el disparo fue cancelado por daño, solo resetear el flag
				if shot_cancelled:
					shot_cancelled = false
					return
				start_shooting()
				return
			
			var adjusted_draw_time = tiempo_tensar / multiplicador_velocidad_disparo
			if state_timer >= adjusted_draw_time:
				current_aim_state = AimState.AIMING
				anim_tree.set(upper_path, "aim")
				charge_time = 0.0
				charge_bar.visible = true
				
				# Asegurar escala final
				if arrow_node: arrow_node.scale = Vector3(0.4, 0.4, 0.4)
			
			# Mostrar trayectoria y actualizar escala de flecha

			if arrow_node:
				var progress = clamp(state_timer / adjusted_draw_time, 0.0, 1.0)
				var scale_val = progress * 0.4
				arrow_node.scale = Vector3(scale_val, scale_val, scale_val)
				
		AimState.AIMING:
			if float(anim_tree.get(blend_path)) != 1.0:
				anim_tree.set(blend_path, 1.0)
			
			var adjusted_charge_dur = duracion_carga / multiplicador_velocidad_disparo
			charge_time += delta
			
			# Sistema de fatiga eliminado por solicitud
			
			charge_time = min(charge_time, adjusted_charge_dur)
			var charge_percent = (charge_time / adjusted_charge_dur) * 100
			charge_bar.value = charge_percent
			
			charge_bar.modulate = Color.WHITE
			if charge_bar.has_meta("original_position"):
				charge_bar.position = charge_bar.get_meta("original_position")
			if charge_bar.has_method("set_tint_progress"):
				charge_bar.tint_progress = Color.WHITE
			
			actualizar_rotacion_torso_pitch()

			
			if Input.is_action_just_released("click_izquierdo"):
				# Si el disparo fue cancelado por daño, solo resetear el flag
				if shot_cancelled:
					shot_cancelled = false
					return
				charge_bar.modulate = Color.WHITE # Restaurar color
				start_shooting()
		
		AimState.SHOOTING:
			if float(anim_tree.get(blend_path)) != 1.0:
				anim_tree.set(blend_path, 1.0)
				
			actualizar_rotacion_torso_pitch()
			
			state_timer += delta
			
			# Usar la duración que guardamos al iniciar el disparo
			# Ajustada por la velocidad de disparo
			var current_shoot_dur = shoot_anim_duration / multiplicador_velocidad_disparo
			
			if state_timer >= current_shoot_dur:
				current_aim_state = AimState.NONE
				anim_tree.set(upper_path, "none") # Volver explícitamente a none
				# Detener animación del arco
				stop_bow_animation()
				# Ocultar la flecha y trayectoria
				if arrow_node:
					arrow_node.visible = false


var shoot_anim_duration = 1.0 # Valor por defecto

func start_shooting():
	# Detener el sonido de tensar cuerda
	AudioManager.stop_bow_tension()
	
	current_aim_state = AimState.SHOOTING
	state_timer = 0.0 # Reset timer para contar duración del disparo
	
	anim_tree.set("parameters/UpperBody/transition_request", "shoot")
	charge_bar.visible = false
	
	# Reproducir animación de disparo del arco
	play_bow_animation("ARCO_DISPARO")
	
	# Ocultar la flecha visual (se "disparó")
	if arrow_node:
		arrow_node.visible = false
	
	# Obtener duración real de la animación
	if anim_player and anim_player.has_animation("Armature|DISPARAR"):
		shoot_anim_duration = anim_player.get_animation("Armature|DISPARAR").length
	
	# Calcular potencia del disparo (0.0 a 1.0)
	var adjusted_charge_dur = duracion_carga / multiplicador_velocidad_disparo
	var adjusted_draw_time = tiempo_tensar / multiplicador_velocidad_disparo
	
	# Si charge_time > 0, estamos en AIMING y usamos ese valor
	# Si charge_time = 0 (soltamos durante DRAWING), usamos state_timer como potencia proporcional al tiempo de tensado
	if charge_time > 0:
		last_charge_power = clamp(charge_time / adjusted_charge_dur, 0.0, 1.0)
	else:
		# Potencia mínima basada en cuánto tiempo tensamos (0% a ~20% máximo durante DRAWING)
		var draw_progress = clamp(state_timer / adjusted_draw_time, 0.0, 1.0)
		last_charge_power = draw_progress * 0.2 # Máximo 20% de potencia si sueltas durante DRAWING
	
	# Asegurar un mínimo de potencia para que la flecha siempre sea visible
	last_charge_power = max(last_charge_power, 0.1)
	
	# Disparar la flecha física
	spawn_arrow_projectile()
	
	# Reproducir sonido de disparo de la arquera
	AudioManager.play_sfx("player_shoot")
	
	charge_time = 0.0

func spawn_arrow_projectile():
	if not arrow_scene:
		return
	
	# Calcular datos de disparo
	var data = calculate_shoot_data()
	if not data["valid"]:
		return
	
	# Instanciar la flecha
	var arrow_instance = arrow_scene.instantiate()
	
	# Obtener dirección hacia el mouse
	var shoot_dir = data["velocity"].normalized()
	
	# Calcular velocidad basada en la carga (usando variables exportadas)
	var arrow_speed = lerp(velocidad_flecha_minima, velocidad_flecha_maxima, last_charge_power)
	
	# Inicializar la flecha con dirección y velocidad calculada
	arrow_instance.initialize(shoot_dir, arrow_speed)
	
	# Agregar al árbol PRIMERO (para que _ready se ejecute y sea válido en el tree)
	get_tree().root.add_child(arrow_instance)
	
	# Posicionar DESPUÉS de agregar (ahora global_position funciona correctamente)
	arrow_instance.global_position = data["origin"]
	
	# GAME FEEL: Screen shake al disparar
	if has_node("/root/GameFeel"):
		get_node("/root/GameFeel").on_player_shoot()
	
	# GAME FEEL: Partículas de disparo (DESACTIVADO)
	# VFXFactory.spawn_muzzle_flash(get_tree().root, data["origin"], shoot_dir)

func actualizar_rotacion_torso_pitch():
	if not skeleton or not self.has_meta("bone_idx"): return
	var idx = self.get_meta("bone_idx")
	if idx == -1: return
	
	var camera = get_viewport().get_camera_3d()
	if not camera: return

	skeleton.set_bone_global_pose_override(idx, Transform3D.IDENTITY, 0.0, false)
	var current_pose = skeleton.get_bone_global_pose(idx)
	var current_position = current_pose.origin
	
	var mouse_pos = get_viewport().get_mouse_position()
	var player_screen_pos = camera.unproject_position(global_position)
	var direction_to_mouse = (mouse_pos - player_screen_pos).normalized()
	
	var pitch_angle = - asin(direction_to_mouse.y)
	pitch_angle = clamp(pitch_angle, deg_to_rad(angulo_minimo), deg_to_rad(angulo_maximo))
	
	if invertir_angulo:
		pitch_angle = - pitch_angle
	
	var axis_vec = Vector3.FORWARD
	if eje_rotacion == 0: axis_vec = Vector3.LEFT
	elif eje_rotacion == 1: axis_vec = Vector3.UP
	elif eje_rotacion == 2: axis_vec = Vector3.FORWARD
	
	var pitch_rotation = Quaternion(axis_vec, pitch_angle)
	var new_basis = current_pose.basis * Basis(pitch_rotation)
	
	# Si estamos escalando, añadir rotación en Y para apuntar hacia la izquierda
	# e invertir el pitch para que el apuntado sea correcto
	if current_move_state == MoveState.CLIMBING:
		var yaw_rotation = Quaternion(Vector3.UP, deg_to_rad(rotacion_torso_escalera))
		# Invertir pitch si está habilitado
		if invertir_pitch_escalera:
			var inverted_pitch = Quaternion(axis_vec, -pitch_angle * multiplicador_inversion_pitch)
			new_basis = new_basis * Basis(yaw_rotation) * Basis(inverted_pitch)
		else:
			new_basis = new_basis * Basis(yaw_rotation)
	
	skeleton.set_bone_global_pose_override(idx, Transform3D(new_basis, current_position), 1.0, false)


func reset_torso_bone():
	if not skeleton or not self.has_meta("bone_idx"): return
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
		"Armature|" + anim_name
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
	var result = {
		"origin": Vector3.ZERO,
		"velocity": Vector3.ZERO,
		"valid": false
	}
	
	var camera = get_viewport().get_camera_3d()
	if not camera: return result
	
	# Origen
	var spawn_pos = global_position + Vector3(0, 1.2, 0)
	if arrow_node:
		spawn_pos = arrow_node.global_position
	result["origin"] = spawn_pos
	
	# === MÉTODO SIMPLE: Usar posición en pantalla ===
	# Convertir posición del personaje a coordenadas de pantalla
	var player_screen = camera.unproject_position(spawn_pos)
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Calcular dirección en pantalla (2D)
	var screen_dir = (mouse_pos - player_screen)
	
	# Convertir a dirección 3D: 
	# - X de pantalla -> X del mundo (derecha/izquierda)
	# - Y de pantalla -> -Y del mundo (pantalla Y baja = mundo Y sube)
	# - Z = 0 siempre (2.5D)
	var shoot_direction = Vector3(screen_dir.x, -screen_dir.y, 0)
	
	if shoot_direction.length_squared() > 0.01:
		shoot_direction = shoot_direction.normalized()
	else:
		# Dirección por defecto: IZQUIERDA (hacia donde mira el personaje)
		shoot_direction = Vector3.LEFT
	
	# Velocidad (usa los valores exportados)
	var adjusted_charge_dur = duracion_carga / multiplicador_velocidad_disparo
	var current_power = clamp(charge_time / adjusted_charge_dur, 0.0, 1.0)
	
	var speed = lerp(velocidad_flecha_minima, velocidad_flecha_maxima, current_power)
	result["velocity"] = shoot_direction * speed
	result["valid"] = true
	
	return result

# === SISTEMA DE DAÑO ===
## Alias de compatibilidad — las flechas enemigas llaman take_damage()
func take_damage(amount: float):
	recibir_dano(int(amount))

func _cancel_current_shot():
	# Cancelar cualquier estado de disparo actual
	if current_aim_state != AimState.NONE:
		# Marcar que el disparo fue cancelado (evita disparar al soltar clic)
		shot_cancelled = true
		
		# Detener el sonido de tensar cuerda si estaba sonando
		AudioManager.stop_bow_tension()
		
		current_aim_state = AimState.NONE
		charge_time = 0.0
		state_timer = 0.0
		
		if charge_bar:
			charge_bar.visible = false
		
		if arrow_node:
			arrow_node.visible = false
		
		if anim_tree:
			anim_tree.set("parameters/UpperBody/transition_request", "none")
			anim_tree.set("parameters/AimBlend/blend_amount", 0.0)
		

		reset_torso_bone()
		stop_bow_animation()

func _play_hit_animation():
	# Usar HitOneShot para permitir caminar mientras se recibe daño
	if not anim_tree:
		return
	
	# Disparar la animación HIT (OneShot)
	# Al tener filtros en el torso, las piernas seguirán caminando
	anim_tree.set("parameters/HitOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _flash_damage():
	# Crear un flash rojo temporal
	var mesh_instances = find_children("*", "MeshInstance3D", true, false)
	
	# Cambiar a rojo
	for mesh in mesh_instances:
		if mesh.material_override == null:
			var flash_mat = StandardMaterial3D.new()
			flash_mat.albedo_color = Color(1, 0.3, 0.3)
			mesh.material_override = flash_mat
	
	# Restaurar después de un tiempo
	await get_tree().create_timer(0.1).timeout
	for mesh in mesh_instances:
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
		get_tree().create_timer(invulnerability_duration).timeout.connect(func():
			if is_instance_valid(self) and is_inside_tree():
				is_invulnerable = false
		)
		get_tree().create_timer(shot_lock_duration).timeout.connect(func():
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
	velocity.x = 0.5 # Empujar ligeramente hacia la derecha (alejándose del muro)

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
	
	# Restaurar rotación del armature si estamos en escalera
	if current_move_state == MoveState.CLIMBING:
		_reset_armature_rotation()
	
	# Si estamos en el aire o en escalera, caer al suelo primero
	if current_move_state == MoveState.CLIMBING or current_move_state == MoveState.AIR or not is_on_floor():
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

func _wait_for_ground_death():
	# Esperar hasta tocar el suelo mientras cae con gravedad
	var timeout = 3.0
	while not is_on_floor() and timeout > 0:
		# Aplicar gravedad manualmente durante la caída
		velocity.y -= gravity * get_physics_process_delta_time()
		move_and_slide()
		await get_tree().process_frame
		timeout -= get_process_delta_time()

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
