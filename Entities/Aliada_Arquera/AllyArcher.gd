class_name AllyArcher
extends Node3D
static var active_allies_cache: Array[Node] = []
## NO rastrea enemigos — dispara en arco hacia la derecha.
## Empieza a disparar cuando hay 2+ enemigos en pantalla.
# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN
# ═══════════════════════════════════════════════════════════════════════════════
enum State { IDLE, AIMING, SHOOTING, RELOADING, DYING, DEAD, GETTING_UP }
@export_category("Activación")
@export var enemigos_minimos: int = 1  ## Cantidad mínima de enemigos vivos para empezar a disparar
@export_category("Disparo")
@export var tiempo_carga_min: float = 0.5  ## Carga mínima (potencia baja)
@export_category("Tiempo_carga_max")
@export var tiempo_carga_max: float = 1.0  ## Carga máxima (potencia alta)
@export var potencia_minima: float = 5.0
@export var potencia_maxima: float = 12.0
@export var altura_spawn_flecha: float = 1.2
@export_range(0.0, 30.0, 1.0) var angulo_disparo_min: float = 5.0  ## Ángulo mínimo de elevación (grados)
@export_range(0.0, 60.0, 1.0) var angulo_disparo_max: float = 35.0  ## Ángulo máximo de elevación (grados)
@export_range(1.0, 3.0, 0.05) var multiplicador_potencia_volador: float = 1.6  ## Fuerza extra al disparar a enemigos voladores (trayectoria más plana)
@export_category("Tiempos")
@export var idle_min: float = 0.4  ## Segundos mínimos en idle entre ciclos
@export var idle_max: float = 0.9  ## Segundos máximos en idle entre ciclos
@export_category("Vida")
@export var vida_maxima: int = 2
@export_category("Debug")
@export var debug_logs_enabled: bool = false
# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCIAS
# ═══════════════════════════════════════════════════════════════════════════════
var arrow_scene = preload("res://Entities/Proyectil_Flecha_Aliada/AllyArrow.tscn")
var dissolve_shader = preload("res://System/Shaders/dissolve.gdshader")
var anim_player: AnimationPlayer
var bow_anim_player: AnimationPlayer
var skeleton: Skeleton3D
var arrow_node: Node3D
var hitbox_body: StaticBody3D
var model_root: Node3D
var _original_model_y_rot: float = 0.0
var ultima_muerte_anim: String = ""
# ═══════════════════════════════════════════════════════════════════════════════
# ESTADO
# ═══════════════════════════════════════════════════════════════════════════════
var current_state: State = State.IDLE
var state_timer: float = 0.0
var _blink_timer: float = 0.0
var charge_duration: float = 0.0
var health: int = 1
var flechas_explosivas: int = 0  ## Contador interno de flechas explosivas
var is_dissolving: bool = false
var dissolve_materials: Array = []
static var _cached_wave_spawner: Node = null
var _spine_bone_idx: int = -1  ## Hueso del torso para el apuntado visual hacia arriba
# ═══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ═══════════════════════════════════════════════════════════════════════════════


func _ready():
	active_allies_cache.append(self)
	add_to_group("allies")
	health = vida_maxima
	set_physics_process(false)

	model_root = find_child("ArqueraModel", false, false)
	if model_root:
		_original_model_y_rot = model_root.rotation.y

	# Hueso del torso para el apuntado visual (mismo rig que la protagonista)
	skeleton = find_child("Skeleton3D", true, false)
	if skeleton:
		_spine_bone_idx = skeleton.find_bone("mixamorig_Spine1")
		if _spine_bone_idx == -1:
			_spine_bone_idx = skeleton.find_bone("mixamorig_Spine")

	_setup_animation_player()
	_buscar_arrow_node()
	_crear_hitbox()

	# Ocultar flecha visual
	if arrow_node and is_instance_valid(arrow_node):
		arrow_node.visible = false

	# Sombra procedural debajo del personaje
	var _sombra := SombraPersonaje.new()
	add_child(_sombra)

	call_deferred("_iniciar")


func _iniciar():
	_log_debug(["[AllyArcher] _iniciar() llamado"])
	_log_debug(["[AllyArcher] anim_player: ", anim_player])
	_log_debug(["[AllyArcher] bow_anim_player: ", bow_anim_player])
	if anim_player:
		anim_player.active = true
		_log_debug(["[AllyArcher] Animaciones disponibles: ", anim_player.get_animation_list()])
	else:
		_log_debug(["[AllyArcher] anim_player es NULL"])
	if bow_anim_player:
		bow_anim_player.active = true
		_log_debug(["[AllyArcher] Anims arco: ", bow_anim_player.get_animation_list()])
	_cambiar_estado(State.IDLE)
	set_process(true)


func _setup_animation_player():
	# 1. Desactivar cualquier AnimationTree
	var trees = find_children("*", "AnimationTree", true, false)
	for tree in trees:
		tree.active = false
		_log_debug(["[AllyArcher] AnimationTree desactivado: ", tree.name])

	# 2. Buscar AnimationPlayer principal (con IDLE, DISPARO, etc.)
	#    Acepta nombres con prefijo (Armature|Armature|IDLE) o sin prefijo (IDLE)
	var all_players = find_children("*", "AnimationPlayer", true, false)
	_log_debug(["[AllyArcher] AnimationPlayers encontrados: ", all_players.size()])

	# Primero imprimir TODOS los players para debug
	for player in all_players:
		_log_debug(
			[
				"[AllyArcher] Player '",
				player.name,
				"' path=",
				player.get_path(),
				" - Anims: ",
				player.get_animation_list()
			]
		)

	for player in all_players:
		var anims = player.get_animation_list()

		# Verificar que tenga animaciones de PERSONAJE
		# Excluir animaciones del arco (contienen "ARCO" o empiezan con "Recurve Bow")
		var is_character = false
		for a in anims:
			var is_bow_anim = a.begins_with("Recurve Bow") or "ARCO" in a
			if is_bow_anim:
				continue
			var has_idle = "IDLE" in a
			var has_shoot = "DISPARO" in a or "DISPARAR" in a
			if has_idle or has_shoot:
				is_character = true
				break

		if is_character:
			anim_player = player
			_log_debug(
				[
					"[AllyArcher] AnimationPlayer de PERSONAJE seleccionado: ",
					player.name,
					" path=",
					player.get_path()
				]
			)
			break

	if not anim_player:
		push_error("[AllyArcher] AnimationPlayer not found with IDLE/SHOOT animations")
		return

	_log_debug(["[AllyArcher] AnimationPlayer seleccionado: ", anim_player.name])

	# 3. Configurar loops en IDLE y APUNTAR
	for anim_name in anim_player.get_animation_list():
		if "IDLE" in anim_name or "APUNTAR" in anim_name:
			var anim = anim_player.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR

	# 4. Buscar AnimationPlayer del arco (separado)
	for player in all_players:
		if player == anim_player:
			continue
		var anims = player.get_animation_list()
		for a in anims:
			if "ARCO" in a:
				bow_anim_player = player
				break
		if bow_anim_player:
			break


func _buscar_arrow_node():
	arrow_node = find_child("FLECHA", true, false)
	if not arrow_node:
		arrow_node = find_child("BoneAttach_Flecha", true, false)


func _crear_hitbox():
	hitbox_body = StaticBody3D.new()
	hitbox_body.name = "HitboxBody"
	hitbox_body.add_to_group("allies")
	hitbox_body.collision_layer = 2  # Capa 2: el Player (capa 1) no colisiona, flechas enemigas (mask=3) sí
	hitbox_body.collision_mask = 0

	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.6
	col.shape = shape
	col.position = Vector3(0, 0.8, 0)

	hitbox_body.add_child(col)
	add_child(hitbox_body)


# ═══════════════════════════════════════════════════════════════════════════════
# PROCESO PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════════════


func _process(delta):
	if current_state == State.DYING or current_state == State.DEAD:
		_restaurar_torso()
		return

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.RELOADING:
			_process_reloading(delta)
		State.AIMING:
			_process_aiming(delta)
		State.SHOOTING:
			_process_shooting(delta)
		State.GETTING_UP:
			_process_getting_up(delta)

	# Apuntado visual del torso hacia la gárgola (como la protagonista)
	_actualizar_apuntado_torso()


## Inclina el torso hacia la gárgola objetivo mientras apunta/dispara, con la
## misma convención que la protagonista (pitch negativo sobre FORWARD, hueso
## mixamorig_Spine1, multiplicación local). Sin objetivo, restaura la pose.
func _actualizar_apuntado_torso() -> void:
	if not skeleton or _spine_bone_idx == -1:
		return

	var objetivo := _obtener_gargola_objetivo()
	var en_estados_disparo := (
		current_state == State.RELOADING
		or current_state == State.AIMING
		or current_state == State.SHOOTING
	)

	if objetivo == null or not en_estados_disparo:
		_restaurar_torso()
		return

	var my_pos: Vector3 = global_position + Vector3(0, 0.5, 0)
	var target_pos: Vector3 = objetivo.global_position + Vector3(0, 0.3, 0)
	var dy: float = target_pos.y - my_pos.y
	var dx: float = absf(target_pos.x - my_pos.x)
	# Pitch negativo = arco hacia arriba (misma convención que Player)
	var pitch: float = clampf(-atan2(maxf(dy, 0.0), maxf(dx, 0.1)), deg_to_rad(-70.0), 0.0)

	skeleton.set_bone_global_pose_override(_spine_bone_idx, Transform3D.IDENTITY, 0.0, false)
	var pose_actual: Transform3D = skeleton.get_bone_global_pose(_spine_bone_idx)
	var pitch_rotation := Quaternion(Vector3.FORWARD, pitch)
	var nueva_basis: Basis = pose_actual.basis * Basis(pitch_rotation)
	skeleton.set_bone_global_pose_override(
		_spine_bone_idx, Transform3D(nueva_basis, pose_actual.origin), 1.0, false
	)


func _restaurar_torso() -> void:
	if skeleton and _spine_bone_idx != -1:
		skeleton.set_bone_global_pose_override(_spine_bone_idx, Transform3D.IDENTITY, 0.0, false)


## IDLE: esperar 1-2s, luego ir a RELOADING (tomar flecha)
func _process_idle(delta):
	state_timer -= delta
	if state_timer <= 0:
		if _contar_enemigos_vivos() >= enemigos_minimos:
			_cambiar_estado(State.RELOADING)
		else:
			state_timer = 1.0


## RELOADING: animación TOMAR_FLECHA, luego ir a AIMING
func _process_reloading(delta):
	state_timer -= delta
	if state_timer <= 0:
		_cambiar_estado(State.AIMING)


## AIMING: animación APUNTAR_IDLE (carga), luego DISPARAR
func _process_aiming(delta):
	state_timer -= delta
	if state_timer <= 0:
		_disparar()
		_cambiar_estado(State.SHOOTING)


## SHOOTING: animación DISPARAR, luego volver a IDLE
func _process_shooting(delta):
	state_timer -= delta
	if state_timer <= 0:
		_cambiar_estado(State.IDLE)


## GETTING_UP: esperar a que termine de levantarse
func _process_getting_up(delta):
	state_timer -= delta
	
	# Parpadeo de invulnerabilidad
	_blink_timer += delta
	if _blink_timer >= 0.16:
		_blink_timer = 0.0
		if model_root:
			model_root.visible = not model_root.visible

	if state_timer <= 0:
		if model_root:
			model_root.visible = true
		_cambiar_estado(State.IDLE)


# ═══════════════════════════════════════════════════════════════════════════════
# CAMBIO DE ESTADO
# ═══════════════════════════════════════════════════════════════════════════════


func _cambiar_estado(nuevo: State):
	if nuevo != State.GETTING_UP and model_root:
		model_root.visible = true
		if model_root.rotation.y != _original_model_y_rot:
			if is_inside_tree():
				var tween = create_tween()
				tween.tween_property(model_root, "rotation:y", _original_model_y_rot, 0.3)\
					.set_trans(Tween.TRANS_SINE)\
					.set_ease(Tween.EASE_OUT)
			else:
				model_root.rotation.y = _original_model_y_rot

	current_state = nuevo
	match nuevo:
		State.IDLE:
			_play_anim("IDLE", 0.3)
			_play_bow_anim("ARCO_IDLE", 0.3)
			state_timer = randf_range(idle_min, idle_max)
			_ocultar_flecha()
		State.RELOADING:
			# Tomar flecha más rápido (1.6x)
			_play_anim("TOMAR_FLECHA", 0.2, 1.6)
			_play_bow_anim("ARCO_IDLE", 0.2, 1.6)
			var tomar_dur = _get_anim_length("TOMAR_FLECHA") / 1.6
			state_timer = tomar_dur + 0.05
			_mostrar_flecha()
			# Desfase: iniciar ARCO_TENSAR a mitad de TOMAR_FLECHA
			get_tree().create_timer(tomar_dur * 0.4).timeout.connect(
				func():
					if is_instance_valid(self) and current_state == State.RELOADING:
						_play_bow_anim("ARCO_TENSAR", 0.2, 1.6)
			)
		State.AIMING:
			# Apuntar — arco ya tenso, carga rápida
			_play_anim("APUNTAR_IDLE", 0.2, 1.4)
			charge_duration = randf_range(tiempo_carga_min, tiempo_carga_max)
			state_timer = charge_duration
			AudioManager.play_sfx("bow_tension", -6.0)
		State.SHOOTING:
			# Disparar con salida rápida (1.6x)
			_play_anim("DISPARO", 0.1, 1.6)
			_play_bow_anim("ARCO_DISPARO", 0.1, 1.6)
			state_timer = (_get_anim_length("DISPARO") / 1.6) + 0.1
			_ocultar_flecha()
		State.DYING:
			_on_dying()
		State.DEAD:
			pass
		State.GETTING_UP:
			_play_anim("LEVANTARSE", 0.0)
			_play_bow_anim("ARCO_IDLE", 0.0)
			state_timer = _get_anim_length("LEVANTARSE")
			_blink_timer = 0.0
			_ocultar_flecha()
			if ultima_muerte_anim == "MUERTE_01" and model_root:
				model_root.rotation.y = _original_model_y_rot + deg_to_rad(90)


# ═══════════════════════════════════════════════════════════════════════════════
# CONTEO DE ENEMIGOS
# ═══════════════════════════════════════════════════════════════════════════════


func _get_cached_wave_spawner() -> Node:
	if is_instance_valid(_cached_wave_spawner):
		return _cached_wave_spawner

	if get_tree() == null:
		return null

	_cached_wave_spawner = get_tree().get_first_node_in_group("wave_spawners")
	if _cached_wave_spawner:
		return _cached_wave_spawner

	var scene_root = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)

	var wave_spawner = scene_root.find_child("WaveSpawner", true, false)
	if wave_spawner:
		_cached_wave_spawner = wave_spawner
	return _cached_wave_spawner


func _contar_enemigos_vivos() -> int:
	var count = 0
	var enemies = []

	var wave_spawner = _get_cached_wave_spawner()
	if wave_spawner and wave_spawner.has_method("get_active_enemies"):
		enemies = wave_spawner.get_active_enemies()
	else:
		# Fallback: Usar arrays estáticos O(1) si no existe WaveSpawner
		enemies = EnemyBase.active_enemies_cache

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		if enemy.get("current_state") != null:
			if (
				enemy.current_state == EnemyBase.State.DYING
				or enemy.current_state == EnemyBase.State.DEAD
			):
				continue
		count += 1
	return count


## Busca la gárgola (enemigo volador) viva más cercana frente a la arquera.
## Las gárgolas vuelan alto (3.3-5.2 m): el arco a ciego nunca las alcanza,
## así que requieren apuntado directo.
func _obtener_gargola_objetivo() -> Node3D:
	var enemies = []

	var wave_spawner = _get_cached_wave_spawner()
	if wave_spawner and wave_spawner.has_method("get_active_enemies"):
		enemies = wave_spawner.get_active_enemies()
	else:
		enemies = EnemyBase.active_enemies_cache

	var mejor: Node3D = null
	var menor_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		if not (enemy is Gargola):
			continue
		if enemy.current_state == EnemyBase.State.DYING or enemy.current_state == EnemyBase.State.DEAD:
			continue
		# Solo enemigos delante (a la derecha de la arquera)
		if enemy.global_position.x <= global_position.x:
			continue
		var dist: float = absf(enemy.global_position.x - global_position.x)
		if dist < menor_dist:
			menor_dist = dist
			mejor = enemy
	return mejor


# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO (siempre hacia la derecha)
# ═══════════════════════════════════════════════════════════════════════════════


func agregar_flechas_explosivas(cantidad: int = 5) -> void:
	flechas_explosivas += cantidad


func _disparar():
	if not arrow_scene:
		return

	AudioManager.play_sfx("player_shoot", -6.0)

	# Posición de spawn
	var spawn_pos = global_position + Vector3(0, altura_spawn_flecha, 0)
	if arrow_node and is_instance_valid(arrow_node):
		spawn_pos = arrow_node.global_position

	# Potencia proporcional al tiempo de carga
	var power_ratio = clamp(charge_duration / tiempo_carga_max, 0.0, 1.0)
	var speed = lerp(potencia_minima, potencia_maxima, power_ratio)

	var direction: Vector3
	var objetivo_volador := _obtener_gargola_objetivo()
	if objetivo_volador:
		# Más fuerza contra enemigos voladores: trayectoria más plana y directa
		speed *= multiplicador_potencia_volador
		# Gárgola detectada: solución balística iterativa con predicción de
		# movimiento para que las flechas la alcancen con facilidad.
		var objetivo_pos: Vector3 = objetivo_volador.global_position + Vector3(0, 0.3, 0)
		var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")
		var vel_objetivo: Vector3 = Vector3.ZERO
		var v_obj = objetivo_volador.get("velocity")
		if v_obj is Vector3:
			vel_objetivo = Vector3(v_obj.x, 0.0, 0.0)  # La oscilación vertical es posicional

		# 3 pasadas: estimar tiempo de vuelo → predecir posición futura → recomputar
		var punto_apuntado: Vector3 = objetivo_pos
		var tiempo_vuelo: float = 0.0
		for _i in range(3):
			var delta_pos: Vector3 = punto_apuntado - spawn_pos
			var distancia: float = delta_pos.length()
			tiempo_vuelo = distancia / maxf(speed, 0.1)
			punto_apuntado = objetivo_pos + vel_objetivo * tiempo_vuelo

		var delta_final: Vector3 = punto_apuntado - spawn_pos
		var dist_final: float = maxf(delta_final.length(), 0.1)
		direction = delta_final.normalized()
		direction.y += 0.5 * gravedad * tiempo_vuelo * tiempo_vuelo / dist_final
		# Dispersión mínima natural
		direction.y += randf_range(-0.015, 0.015)
		direction.x += randf_range(-0.01, 0.01)
		direction = direction.normalized()
	else:
		# Sin gárgolas: arco a ciego hacia la derecha (comportamiento original)
		var angulo = deg_to_rad(randf_range(angulo_disparo_min, angulo_disparo_max))
		direction = Vector3(cos(angulo), sin(angulo), 0).normalized()

	# Crear flecha
	var arrow = arrow_scene.instantiate()
	if flechas_explosivas > 0:
		flechas_explosivas -= 1
		if "es_explosiva" in arrow:
			arrow.es_explosiva = true

	arrow.initialize(direction, speed)
	get_tree().root.add_child(arrow)
	arrow.global_position = spawn_pos


# ═══════════════════════════════════════════════════════════════════════════════
# FLECHA VISUAL
# ═══════════════════════════════════════════════════════════════════════════════


func _mostrar_flecha():
	if arrow_node and is_instance_valid(arrow_node):
		arrow_node.visible = true


func _ocultar_flecha():
	if arrow_node and is_instance_valid(arrow_node):
		arrow_node.visible = false


# ═══════════════════════════════════════════════════════════════════════════════
# DAÑO Y MUERTE
# ═══════════════════════════════════════════════════════════════════════════════

var last_hit_position: Vector3 = Vector3.ZERO
var last_hit_direction: Vector3 = Vector3.LEFT


func take_damage(amount: float):
	if current_state == State.DYING or current_state == State.DEAD or current_state == State.GETTING_UP:
		return

	health -= int(amount)

	# Reproducir animación de daño si sigue vivo (la sangre solo sale al morir)
	if health > 0:
		_play_anim("DAÑO_HIT", 0.05)
		AudioManager.play_sfx("player_hurt")
		# Volver al estado anterior tras la animación de daño
		var dur = _get_anim_length("DAÑO_HIT")
		get_tree().create_timer(dur).timeout.connect(
			func():
				if (
					is_instance_valid(self)
					and current_state != State.DYING
					and current_state != State.DEAD
				):
					_cambiar_estado(current_state)
		)

	if health <= 0:
		_cambiar_estado(State.DYING)


func recibir_dano(amount: int):
	take_damage(float(amount))


func revivir() -> void:
	if current_state != State.DEAD and current_state != State.DYING:
		return

	health = vida_maxima
	set_process(true)
	if hitbox_body:
		hitbox_body.collision_layer = 2

	_cambiar_estado(State.GETTING_UP)


func _crear_splash_sangre() -> void:
	var blood_scene: PackedScene = preload("res://VFX/Scenes/BloodSplashNormal.tscn")
	if not blood_scene:
		return
	var splash = blood_scene.instantiate() as BloodSplash2D
	if not splash:
		return

	var root := get_tree().current_scene
	if root:
		root.add_child(splash)
	elif get_parent():
		get_parent().add_child(splash)

	var spawn_pos := last_hit_position if not last_hit_position.is_zero_approx() else (global_position + Vector3(0.0, 0.8, 0.0))
	# Invertir dirección: el proyectil impacta viniendo de la derecha hacia la izquierda (-X)
	var dir := last_hit_direction if not last_hit_direction.is_zero_approx() else Vector3.LEFT
	splash.setup(spawn_pos, dir, Color.WHITE)


func _on_dying():
	set_process(false)
	_ocultar_flecha()
	_crear_splash_sangre()

	# Desactivar hitbox
	if hitbox_body:
		hitbox_body.collision_layer = 0

	# Sonido de muerte
	AudioManager.play_sfx("player_death")

	# Reproducir muerte (elegir aleatoriamente entre MUERTE_01 y MUERTE_02)
	var death_anim = ["MUERTE_01", "MUERTE_02"][randi() % 2]
	ultima_muerte_anim = death_anim
	_play_anim(death_anim)
	_play_bow_anim("ARCO_IDLE")

	var dur = _get_anim_length(death_anim)
	get_tree().create_timer(dur + 0.5).timeout.connect(
		func():
			if is_instance_valid(self) and current_state == State.DYING:
				_cambiar_estado(State.DEAD)
	)


func _start_dissolve():
	if is_dissolving:
		return
	is_dissolving = true

	var meshes = find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		if not is_instance_valid(mesh):
			continue
		var mat = ShaderMaterial.new()
		mat.shader = dissolve_shader
		mat.set_shader_parameter("dissolve_amount", 0.0)
		mat.set_shader_parameter("glow_color", Color(0.2, 0.6, 1.0))
		mat.set_shader_parameter("glow_intensity", 3.0)
		mat.set_shader_parameter("edge_thickness", 0.05)
		mat.set_shader_parameter("noise_scale", 20.0)

		var orig = mesh.material_override
		if orig == null and mesh.mesh:
			orig = mesh.mesh.surface_get_material(0)
		if orig and orig is StandardMaterial3D:
			var tex = orig.albedo_texture
			if tex:
				mat.set_shader_parameter("albedo_texture", tex)
			var col = orig.albedo_color
			mat.set_shader_parameter("albedo_tint", Vector3(col.r, col.g, col.b))

		mesh.material_override = mat
		dissolve_materials.append({"mesh": mesh, "material": mat})

	var tween = create_tween()
	tween.tween_method(_update_dissolve, 0.0, 1.0, 1.0)
	tween.tween_callback(_finish_dissolve)


func _update_dissolve(value: float):
	for item in dissolve_materials:
		if is_instance_valid(item["mesh"]):
			item["material"].set_shader_parameter("dissolve_amount", value)


func _finish_dissolve():
	for mesh in find_children("*", "MeshInstance3D", true, false):
		if is_instance_valid(mesh):
			mesh.material_override = null
			mesh.visible = false
	dissolve_materials.clear()
	current_state = State.DEAD
	queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMACIÓN
# ═══════════════════════════════════════════════════════════════════════════════


func _play_anim(anim_name: String, blend: float = -1.0, speed: float = 1.0):
	if not anim_player:
		_log_debug(["[AllyArcher] _play_anim('", anim_name, "') - anim_player es NULL"])
		return
	anim_player.active = true

	var full_name = "Armature|Armature|" + anim_name
	if anim_player.has_animation(full_name):
		_log_debug(["[AllyArcher] Reproduciendo: ", full_name])
		anim_player.play(full_name, blend, speed)
		return

	var alt_name = "Armature|" + anim_name
	if anim_player.has_animation(alt_name):
		_log_debug(["[AllyArcher] Reproduciendo: ", alt_name])
		anim_player.play(alt_name, blend, speed)
		return

	if anim_player.has_animation(anim_name):
		_log_debug(["[AllyArcher] Reproduciendo: ", anim_name])
		anim_player.play(anim_name, blend, speed)
	else:
		_log_debug(
			[
				"[AllyArcher] Animación NO encontrada: ",
				anim_name,
				" (intentado: ",
				full_name,
				", ",
				alt_name,
				", ",
				anim_name,
				")"
			]
		)


func _play_bow_anim(anim_name: String, blend: float = -1.0, speed: float = 1.0):
	if not bow_anim_player:
		return
	bow_anim_player.active = true
	var full_name = "Recurve Bow 2 Armature|" + anim_name
	if bow_anim_player.has_animation(full_name):
		bow_anim_player.play(full_name, blend, speed)
	elif bow_anim_player.has_animation(anim_name):
		bow_anim_player.play(anim_name, blend, speed)


func _get_bow_anim_length(anim_name: String) -> float:
	if not bow_anim_player:
		return 1.0
	var full_name = "Recurve Bow 2 Armature|" + anim_name
	if bow_anim_player.has_animation(full_name):
		return bow_anim_player.get_animation(full_name).length
	if bow_anim_player.has_animation(anim_name):
		return bow_anim_player.get_animation(anim_name).length
	return 1.0


func _get_anim_length(anim_name: String) -> float:
	if not anim_player:
		return 2.0
	for prefix in ["Armature|Armature|", "Armature|", ""]:
		var full = prefix + anim_name
		if anim_player.has_animation(full):
			return anim_player.get_animation(full).length
	return 2.0


func _log_debug(parts: Array) -> void:
	if not debug_logs_enabled:
		return

	var message := ""
	for part in parts:
		message += str(part)
	print(message)


func _exit_tree():
	active_allies_cache.erase(self)
