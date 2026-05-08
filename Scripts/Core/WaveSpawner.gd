class_name WaveSpawner
extends Node3D
# === CONFIGURACIÓN (Español) ===
signal oleada_iniciada(numero_oleada: int)
signal oleada_completada(numero_oleada: int)
signal goblin_spawneado(goblin: Node)
@export_category("Spawner")
@export var escena_goblin: PackedScene  # Escena del goblin a instanciar
@export var escena_goblin_girl: PackedScene  # Escena de la goblin girl
@export var escena_imp: PackedScene  # Escena del imp enemigo
@export var escena_canonero: PackedScene  # Nueva escena del cañonero
@export var intervalo_aparicion: float = 5.0  # Segundos entre spawns (más lento)
@export var enemigos_por_oleada: int = 6  # Cantidad de enemigos por oleada
@export var tiempo_entre_oleadas: float = 5.0  # Descanso entre oleadas
@export var altura_spawn: float = 0.0  # Altura extra para spawnar sobre el suelo
@export_range(0.0, 1.0, 0.05) var probabilidad_goblin_girl: float = 0.5  # Probabilidad de que aparezca una Goblin Girl
@export_range(0.0, 1.0, 0.05) var probabilidad_imp: float = 0.2  # Probabilidad de que aparezca un Imp
@export_range(0.0, 1.0, 0.05) var probabilidad_canonero: float = 0.15  # Probabilidad del canonero
@export var probabilidad_igual: bool = false  ## Todos los enemigos tienen la misma probabilidad (33.3%)
@export_category("Imp Escudo")
@export var escena_imp_escudo: PackedScene  ## Escena de la ImpShieldGirl
@export var max_imp_escudo_activos: int = 1  ## Máximo de ImpShieldGirl simultáneas
@export var enemigos_minimos_para_escudo: int = 1  ## Enemigos vivos necesarios para spawnear escudo
@export var intervalo_check_escudo: float = 8.0  ## Segundos entre checks de spawn de escudo
# === ESTADO ===
var forzar_tipo_enemigo: int = -1  ## -1=normal, 0=goblin, 1=goblin_girl, 2=imp, 3=canonero
var current_wave: int = 0
var goblins_spawned_in_wave: int = 0
var spawn_timer: float = 0.0
var wave_cooldown: float = 0.0
var is_wave_active: bool = false
var active_goblins: Array = []
var shield_imps_activos: Array = []  ## Lista de ImpShieldGirls activas
var shield_spawn_timer: float = 5.0  ## Timer para spawn de escudo
var enemigos_muertos_en_oleada: int = 0  ## Contador de muertos para la UI

var current_level_data: Resource = null
var is_data_driven: bool = false
var _queued_enemies: Array = []  ## Enemigos ordenados por tiempo para data-driven
var _elapsed_wave_time: float = 0.0

# === SEÑALES ===


func _ready():
	add_to_group("wave_spawners")
	# Cargar escenas si no están asignadas
	if not escena_goblin:
		escena_goblin = preload("res://Scenes/Characters/Goblin.tscn")
	if not escena_goblin_girl:
		escena_goblin_girl = preload("res://Scenes/Characters/GoblinGirl.tscn")
	if not escena_imp:
		escena_imp = preload("res://Scenes/Characters/ImpEnemy.tscn")
	if not escena_canonero:
		escena_canonero = preload("res://Scenes/Characters/Canonero.tscn")

	if not escena_imp_escudo:
		escena_imp_escudo = preload("res://Scenes/Characters/ImpShieldGirl.tscn")

	# Iniciar primera oleada después de un delay
	wave_cooldown = 2.0


func _process(delta):
	if not is_wave_active:
		wave_cooldown -= delta
		if wave_cooldown <= 0:
			_start_wave()
	else:
		if is_data_driven:
			_elapsed_wave_time += delta
			while _queued_enemies.size() > 0 and _elapsed_wave_time >= _queued_enemies[0].spawn_time:
				var enemy_data = _queued_enemies.pop_front()
				_spawn_from_data(enemy_data)
		else:
			spawn_timer -= delta
			if spawn_timer <= 0 and goblins_spawned_in_wave < enemigos_por_oleada:
				_spawn_goblin()
				spawn_timer = intervalo_aparicion

		# Verificar si la oleada terminó (OPT: solo si ya spawneamos todos)
		if goblins_spawned_in_wave >= enemigos_por_oleada:
			_check_wave_complete()

	# Check de spawn de ImpShieldGirl (independiente de oleadas)
	_check_shield_imp_spawn(delta)

func _spawn_from_data(enemy_data: Resource):
	var scene = load(enemy_data.escena_path)
	if not scene: return

	for i in range(enemy_data.quantity):
		var enemy = scene.instantiate()

		# Offset slightly if spawning multiple at exact same frame/pos
		var offset = Vector3(randf_range(-0.5, 0.5), randf_range(-0.2, 0.2), 0) if enemy_data.quantity > 1 else Vector3.ZERO

		get_tree().root.add_child(enemy)
		enemy.global_position = enemy_data.spawn_position + offset

		if enemy.has_signal("died"):
			enemy.died.connect(_on_goblin_died.bind(enemy))

		active_goblins.append(enemy)
		goblins_spawned_in_wave += 1

		goblin_spawneado.emit(enemy)


func _start_wave():
	current_wave += 1

	if is_data_driven and current_level_data:
		var w_idx = current_wave - 1
		if w_idx < current_level_data.oleadas.size():
			var oleada = current_level_data.oleadas[w_idx]
			_queued_enemies = oleada.enemigos.duplicate()
			_queued_enemies.sort_custom(func(a, b): return a.spawn_time < b.spawn_time)
			enemigos_por_oleada = _queued_enemies.size()
		else:
			is_wave_active = false
			return

	# Los enemigos ya presentes (pacíficos convertidos) cuentan como spawneados
	goblins_spawned_in_wave = active_goblins.size()
	enemigos_muertos_en_oleada = 0
	is_wave_active = true
	spawn_timer = 0.0  # Spawn inmediato al iniciar oleada
	_elapsed_wave_time = 0.0

	oleada_iniciada.emit(current_wave)


func _spawn_goblin():
	print(
		"[WaveSpawner] Spawning goblin. Total spawned so far in wave: ",
		goblins_spawned_in_wave,
		" / ",
		enemigos_por_oleada
	)
	# Elegir qué tipo de enemigo spawnear
	var scene_to_spawn: PackedScene

	# Modo forzado: solo un tipo de enemigo
	if forzar_tipo_enemigo == 0:
		scene_to_spawn = escena_goblin
	elif forzar_tipo_enemigo == 1:
		scene_to_spawn = escena_goblin_girl
	elif forzar_tipo_enemigo == 2:
		scene_to_spawn = escena_imp
	elif forzar_tipo_enemigo == 3:
		scene_to_spawn = escena_canonero
	elif probabilidad_igual:
		# Probabilidad igual: 25% cada tipo
		var roll = randf()
		if roll < 0.25:
			scene_to_spawn = escena_canonero
		elif roll < 0.50:
			scene_to_spawn = escena_imp
		elif roll < 0.75:
			scene_to_spawn = escena_goblin_girl
		else:
			scene_to_spawn = escena_goblin
	else:
		# Probabilidades configuradas
		var roll = randf()
		if roll < probabilidad_canonero and escena_canonero:
			scene_to_spawn = escena_canonero
		elif roll < probabilidad_canonero + probabilidad_imp and escena_imp:
			scene_to_spawn = escena_imp
		elif (
			roll < probabilidad_canonero + probabilidad_imp + probabilidad_goblin_girl
			and escena_goblin_girl
		):
			scene_to_spawn = escena_goblin_girl
		else:
			scene_to_spawn = escena_goblin

	if not scene_to_spawn:
		push_error("[WaveSpawner] No scene to spawn!")
		return

	var goblin = scene_to_spawn.instantiate()

	# Posicionar en el punto de spawn (este nodo)
	var spawn_pos = global_position
	spawn_pos.y += altura_spawn

	# Añadir variación vertical aleatoria
	spawn_pos.y += randf_range(-0.2, 0.2)

	# Añadir al mundo
	get_tree().root.add_child(goblin)
	goblin.global_position = spawn_pos

	# Conectar señal de muerte
	if goblin.has_signal("died"):
		goblin.died.connect(_on_goblin_died.bind(goblin))

	active_goblins.append(goblin)
	goblins_spawned_in_wave += 1

	goblin_spawneado.emit(goblin)


func _on_goblin_died(goblin):
	active_goblins.erase(goblin)
	enemigos_muertos_en_oleada += 1
	AudioManager.on_enemy_killed()


func _check_wave_complete():
	# La oleada termina cuando todos los goblins normales spawnearon Y todos murieron
	if goblins_spawned_in_wave >= enemigos_por_oleada:
		# Limpiar referencias inválidas
		# Opt: Iteración inversa in-place en lugar de Array.filter() para evitar allocations de memoria/GC en comprobaciones frecuentes
		for i in range(active_goblins.size() - 1, -1, -1):
			if not is_instance_valid(active_goblins[i]):
				active_goblins.remove_at(i)

		# Contar solo enemigos normales vivos (los escudos no bloquean la oleada)
		var enemigos_normales_vivos := 0
		for enemy in active_goblins:
			if is_instance_valid(enemy) and not shield_imps_activos.has(enemy):
				enemigos_normales_vivos += 1

		if enemigos_normales_vivos == 0:
			is_wave_active = false
			wave_cooldown = tiempo_entre_oleadas
			oleada_completada.emit(current_wave)


# === API PÚBLICA ===


func iniciar_desde_data(level_data: Resource):
	current_level_data = level_data
	if level_data and level_data.oleadas.size() > 0:
		is_data_driven = true
		current_wave = 0
		wave_cooldown = 0.5
		is_wave_active = false
	else:
		push_error("[WaveSpawner] Nivel data invalido o sin oleadas.")


func iniciar_spawning():
	wave_cooldown = 0.5


func toggle_pause_spawning():
	if is_wave_active:
		is_wave_active = false
		print("Spawning PAUSADO")
	else:
		is_wave_active = true
		print("Spawning REANUDADO")


func detener_spawning():
	is_wave_active = false
	wave_cooldown = 999999


func forzar_spawn():
	_spawn_goblin()


func obtener_goblins_activos() -> int:
	# Opt: Iteración inversa in-place en lugar de Array.filter()
	for i in range(active_goblins.size() - 1, -1, -1):
		if not is_instance_valid(active_goblins[i]):
			active_goblins.remove_at(i)
	return active_goblins.size()


func get_active_enemies() -> Array:
	# Opt: Iteración inversa in-place en lugar de Array.filter()
	for i in range(active_goblins.size() - 1, -1, -1):
		if not is_instance_valid(active_goblins[i]):
			active_goblins.remove_at(i)
	return active_goblins


func get_active_shield_imps() -> Array:
	# Opt: Iteración inversa in-place en lugar de Array.filter()
	for i in range(shield_imps_activos.size() - 1, -1, -1):
		if not is_instance_valid(shield_imps_activos[i]):
			shield_imps_activos.remove_at(i)
	return shield_imps_activos


# ═══════════════════════════════════════════════════════════════════════════════
# IMP SHIELD GIRL
# ═══════════════════════════════════════════════════════════════════════════════


func _check_shield_imp_spawn(delta):
	shield_spawn_timer -= delta
	if shield_spawn_timer > 0:
		return
	shield_spawn_timer = intervalo_check_escudo

	# Limpiar referencias inválidas
	# Opt: Iteración inversa in-place en lugar de Array.filter() para evitar GC
	for i in range(shield_imps_activos.size() - 1, -1, -1):
		if not is_instance_valid(shield_imps_activos[i]):
			shield_imps_activos.remove_at(i)

	# Verificar condiciones
	if shield_imps_activos.size() >= max_imp_escudo_activos:
		return

	var enemigos_vivos = obtener_goblins_activos()
	if enemigos_vivos < enemigos_minimos_para_escudo:
		return

	# Verificar que hay al menos 1 enemigo en SHOOTING (parado)
	var hay_enemigo_shooting = false
	for enemy in active_goblins:
		if is_instance_valid(enemy) and enemy is EnemyBase:
			if enemy.current_state == EnemyBase.State.SHOOTING:
				hay_enemigo_shooting = true
				break
	if not hay_enemigo_shooting:
		return

	if not escena_imp_escudo:
		return

	_spawn_shield_imp()


func _spawn_shield_imp():
	if not escena_imp_escudo:
		return

	var shield_imp = escena_imp_escudo.instantiate()

	# Posicionar en el punto de spawn
	var spawn_pos = global_position
	spawn_pos.y += altura_spawn

	get_tree().root.add_child(shield_imp)
	shield_imp.global_position = spawn_pos

	# Conectar señal de muerte
	if shield_imp.has_signal("died"):
		shield_imp.died.connect(_on_shield_imp_died.bind(shield_imp))

	shield_imps_activos.append(shield_imp)
	active_goblins.append(shield_imp)
	# NOTA: No incrementar goblins_spawned_in_wave — los escudos son spawns independientes


func _on_shield_imp_died(shield_imp):
	shield_imps_activos.erase(shield_imp)
	active_goblins.erase(shield_imp)
	enemigos_muertos_en_oleada += 1


func forzar_spawn_escudo():
	_spawn_shield_imp()


# ═══════════════════════════════════════════════════════════════════════════════
# MODO PACÍFICO (Nivel 0)
# ═══════════════════════════════════════════════════════════════════════════════


## Spawnea enemigos en modo pacífico (solo caminan, no atacan).
## El primero spawnea en la posición base, los siguientes más atrás.
## Todos reciben la misma velocidad para caminar sincronizados.
## Retorna el array de enemigos spawneados.
func spawn_pacificos(
	escenas: Array[PackedScene], velocidad_uniforme: float = 0.5, offset_entre: float = 0.4
) -> Array:
	var enemigos := []
	for i in range(escenas.size()):
		var escena = escenas[i]
		if not escena:
			continue
		var enemigo = escena.instantiate()
		enemigo.modo_pacifico = true
		enemigo.velocidad_caminar = velocidad_uniforme
		enemigo.distancia_maxima_caminar = 10.0

		var spawn_pos = global_position
		spawn_pos.y += altura_spawn
		# Offset escalonado: el primero en X base, los siguientes más atrás
		spawn_pos.x += i * offset_entre

		get_tree().root.add_child(enemigo)
		enemigo.global_position = spawn_pos

		if enemigo.has_signal("died"):
			enemigo.died.connect(_on_goblin_died.bind(enemigo))
		active_goblins.append(enemigo)
		enemigos.append(enemigo)
	return enemigos


## Configura el spawner para una oleada custom y la inicia.
func iniciar_oleada_custom(
	total_enemigos: int, prob_imp: float = 0.5, prob_girl: float = 0.5, _prob_goblin: float = 0.0
):
	enemigos_por_oleada = total_enemigos
	probabilidad_imp = prob_imp
	probabilidad_goblin_girl = prob_girl
	probabilidad_igual = false
	# Ajustar para que el spawner use la oleada configurada
	current_wave = 0
	wave_cooldown = 1.0
	is_wave_active = false
