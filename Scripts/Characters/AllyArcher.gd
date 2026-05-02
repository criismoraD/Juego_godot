class_name AllyArcher
extends Node3D
static var active_allies_cache: Array[Node] = []
## NO rastrea enemigos — dispara en arco hacia la derecha.
## Empieza a disparar cuando hay 2+ enemigos en pantalla.
# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN
# ═══════════════════════════════════════════════════════════════════════════════
enum State { IDLE, AIMING, SHOOTING, RELOADING, DYING, DEAD }
@export_category("Activación")
@export var enemigos_minimos: int = 2  ## Cantidad mínima de enemigos vivos para empezar a disparar
@export_category("Disparo")
@export var tiempo_carga_min: float = 1.0  ## Carga mínima (potencia baja)
@export var tiempo_carga_max: float = 2.0  ## Carga máxima (potencia alta)
@export var potencia_minima: float = 5.0
@export var potencia_maxima: float = 12.0
@export var altura_spawn_flecha: float = 1.2
@export_range(0.0, 30.0, 1.0) var angulo_disparo_min: float = 5.0  ## Ángulo mínimo de elevación (grados)
@export_range(0.0, 60.0, 1.0) var angulo_disparo_max: float = 35.0  ## Ángulo máximo de elevación (grados)
@export_category("Tiempos")
@export var idle_min: float = 1.0  ## Segundos mínimos en idle entre ciclos
@export var idle_max: float = 2.0  ## Segundos máximos en idle entre ciclos
@export_category("Vida")
@export var vida_maxima: int = 1
# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCIAS
# ═══════════════════════════════════════════════════════════════════════════════
var arrow_scene = preload("res://Scenes/Projectiles/Arrow.tscn")
var dissolve_shader = preload("res://Assets/Shaders/dissolve.gdshader")
var anim_player: AnimationPlayer
var bow_anim_player: AnimationPlayer
var skeleton: Skeleton3D
var arrow_node: Node3D
var hitbox_body: StaticBody3D
var model_root: Node3D
# ═══════════════════════════════════════════════════════════════════════════════
# ESTADO
# ═══════════════════════════════════════════════════════════════════════════════
var current_state: State = State.IDLE
var state_timer: float = 0.0
var charge_duration: float = 0.0
var health: int = 1
var is_dissolving: bool = false
var dissolve_materials: Array = []
static var _cached_wave_spawner: Node = null
# ═══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ═══════════════════════════════════════════════════════════════════════════════


func _ready():
	active_allies_cache.append(self)
	add_to_group("allies")
	health = vida_maxima
	set_physics_process(false)

	model_root = find_child("ArqueraModel", false, false)

	_setup_animation_player()
	_buscar_arrow_node()
	_crear_hitbox()

	# Ocultar flecha visual
	if arrow_node and is_instance_valid(arrow_node):
		arrow_node.visible = false

	call_deferred("_iniciar")


func _iniciar():
	print("[AllyArcher] _iniciar() llamado")
	print("[AllyArcher] anim_player: ", anim_player)
	print("[AllyArcher] bow_anim_player: ", bow_anim_player)
	if anim_player:
		anim_player.active = true
		print("[AllyArcher] Animaciones disponibles: ", anim_player.get_animation_list())
	else:
		print("[AllyArcher] ⚠️ anim_player es NULL!")
	if bow_anim_player:
		bow_anim_player.active = true
		print("[AllyArcher] Anims arco: ", bow_anim_player.get_animation_list())
	_cambiar_estado(State.IDLE)
	set_process(true)


func _setup_animation_player():
	# 1. Desactivar cualquier AnimationTree
	var trees = find_children("*", "AnimationTree", true, false)
	for tree in trees:
		tree.active = false
		print("[AllyArcher] AnimationTree desactivado: ", tree.name)

	# 2. Buscar AnimationPlayer principal (con IDLE, DISPARO, etc.)
	#    Acepta nombres con prefijo (Armature|Armature|IDLE) o sin prefijo (IDLE)
	var all_players = find_children("*", "AnimationPlayer", true, false)
	print("[AllyArcher] AnimationPlayers encontrados: ", all_players.size())

	# Primero imprimir TODOS los players para debug
	for player in all_players:
		print(
			"[AllyArcher] Player '",
			player.name,
			"' path=",
			player.get_path(),
			" - Anims: ",
			player.get_animation_list()
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
			print(
				"[AllyArcher] ✅ AnimationPlayer de PERSONAJE seleccionado: ",
				player.name,
				" path=",
				player.get_path()
			)
			break

	if not anim_player:
		push_error("[AllyArcher] AnimationPlayer not found with IDLE/SHOOT animations")
		return

	print("[AllyArcher] ✅ AnimationPlayer seleccionado: ", anim_player.name)

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


# ═══════════════════════════════════════════════════════════════════════════════
# CAMBIO DE ESTADO
# ═══════════════════════════════════════════════════════════════════════════════


func _cambiar_estado(nuevo: State):
	current_state = nuevo
	match nuevo:
		State.IDLE:
			_play_anim("IDLE")
			_play_bow_anim("ARCO_IDLE")
			state_timer = randf_range(idle_min, idle_max)
			_ocultar_flecha()
		State.RELOADING:
			# Tomar flecha — el arco empieza a tensarse tras un desfase
			_play_anim("TOMAR_FLECHA", 0.1)
			_play_bow_anim("ARCO_IDLE")
			var tomar_dur = _get_anim_length("TOMAR_FLECHA")
			state_timer = tomar_dur + 0.1
			_mostrar_flecha()
			# Desfase: iniciar ARCO_TENSAR a mitad de TOMAR_FLECHA
			get_tree().create_timer(tomar_dur * 0.4).timeout.connect(
				func():
					if is_instance_valid(self) and current_state == State.RELOADING:
						_play_bow_anim("ARCO_TENSAR")
			)
		State.AIMING:
			# Apuntar — arco ya tenso, solo mantener pose
			_play_anim("APUNTAR_IDLE")
			charge_duration = randf_range(tiempo_carga_min, tiempo_carga_max)
			state_timer = charge_duration
			AudioManager.play_sfx("bow_tension")
		State.SHOOTING:
			# Disparar
			_play_anim("DISPARO", 0.05)
			_play_bow_anim("ARCO_DISPARO")
			state_timer = _get_anim_length("DISPARO") + 0.2
			_ocultar_flecha()
		State.DYING:
			_on_dying()
		State.DEAD:
			pass


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


# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO (siempre hacia la derecha)
# ═══════════════════════════════════════════════════════════════════════════════


func _disparar():
	if not arrow_scene:
		return

	AudioManager.play_sfx("player_shoot")

	# Posición de spawn
	var spawn_pos = global_position + Vector3(0, altura_spawn_flecha, 0)
	if arrow_node and is_instance_valid(arrow_node):
		spawn_pos = arrow_node.global_position

	# Dirección: siempre a la DERECHA con ángulo aleatorio hacia arriba
	var angulo = deg_to_rad(randf_range(angulo_disparo_min, angulo_disparo_max))
	var direction = Vector3(cos(angulo), sin(angulo), 0).normalized()

	# Potencia proporcional al tiempo de carga
	var power_ratio = clamp(charge_duration / tiempo_carga_max, 0.0, 1.0)
	var speed = lerp(potencia_minima, potencia_maxima, power_ratio)

	# Crear flecha
	var arrow = arrow_scene.instantiate()
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


func take_damage(amount: float):
	if current_state == State.DYING or current_state == State.DEAD:
		return

	health -= int(amount)

	# Reproducir animación de daño si sigue vivo
	if health > 0:
		_play_anim("DAÑO_HIT", 0.05)
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


func _on_dying():
	set_process(false)
	_ocultar_flecha()

	# Desactivar hitbox
	if hitbox_body:
		hitbox_body.collision_layer = 0

	# Sonido de muerte
	AudioManager.play_sfx("player_death")

	# Reproducir muerte (elegir aleatoriamente entre MUERTE_01 y MUERTE_02)
	var death_anim = ["MUERTE_01", "MUERTE_02"][randi() % 2]
	_play_anim(death_anim)
	_play_bow_anim("ARCO_IDLE")

	var dur = _get_anim_length(death_anim)
	get_tree().create_timer(dur + 0.5).timeout.connect(
		func():
			if is_instance_valid(self):
				_start_dissolve()
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
		print("[AllyArcher] _play_anim('", anim_name, "') - anim_player es NULL")
		return
	anim_player.active = true

	var full_name = "Armature|Armature|" + anim_name
	if anim_player.has_animation(full_name):
		print("[AllyArcher] ▶ Reproduciendo: ", full_name)
		anim_player.play(full_name, blend, speed)
		return

	var alt_name = "Armature|" + anim_name
	if anim_player.has_animation(alt_name):
		print("[AllyArcher] ▶ Reproduciendo: ", alt_name)
		anim_player.play(alt_name, blend, speed)
		return

	if anim_player.has_animation(anim_name):
		print("[AllyArcher] ▶ Reproduciendo: ", anim_name)
		anim_player.play(anim_name, blend, speed)
	else:
		print(
			"[AllyArcher] ❌ Animación NO encontrada: ",
			anim_name,
			" (intentado: ",
			full_name,
			", ",
			alt_name,
			", ",
			anim_name,
			")"
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


func _exit_tree():
	active_allies_cache.erase(self)
