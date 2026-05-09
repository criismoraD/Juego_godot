class_name WaveSpawner
extends Node3D

## Spawner de enemigos data-driven. Lee oleadas de LevelData.

signal oleada_iniciada(numero_oleada: int)
signal oleada_completada(numero_oleada: int)
signal goblin_spawneado(goblin: Node)

@export_category("Spawner")
@export var escena_goblin: PackedScene
@export var escena_goblin_girl: PackedScene
@export var escena_imp: PackedScene
@export var escena_canonero: PackedScene
@export var escena_imp_escudo: PackedScene
@export var altura_spawn: float = 0.0
@export var max_imp_escudo_activos: int = 2
@export var intervalo_check_escudo: float = 8.0
@export var enemigos_minimos_para_escudo: int = 1

var current_level_data: LevelData = null
var current_wave: int = 0
var goblins_spawned_in_wave: int = 0
var enemigos_por_oleada: int = 0
var wave_cooldown: float = 0.0
var is_wave_active: bool = false
var active_goblins: Array = []
var shield_imps_activos: Array = []
var shield_spawn_timer: float = 5.0
var enemigos_muertos_en_oleada: int = 0

var _queued_enemies: Array = []
var _elapsed_wave_time: float = 0.0
var _paused: bool = false


func _ready() -> void:
	add_to_group("wave_spawners")
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


func _process(delta: float) -> void:
	if _paused:
		return

	if not is_wave_active:
		wave_cooldown -= delta
		if wave_cooldown <= 0:
			_start_wave()
	else:
		_elapsed_wave_time += delta
		while _queued_enemies.size() > 0 and _elapsed_wave_time >= _queued_enemies[0].spawn_time:
			var enemy_data: EnemigoData = _queued_enemies.pop_front()
			if enemy_data.es_escudo:
				_spawn_shield_imp_from_data(enemy_data)
			else:
				_spawn_from_data(enemy_data)

		if goblins_spawned_in_wave >= enemigos_por_oleada:
			_check_wave_complete()

	_check_shield_imp_spawn(delta)


func _start_wave() -> void:
	current_wave += 1

	if not current_level_data:
		push_error("[WaveSpawner] Sin LevelData configurado.")
		return

	var w_idx: int = current_wave - 1
	if w_idx >= current_level_data.oleadas.size():
		is_wave_active = false
		return

	var oleada: OleadaData = current_level_data.oleadas[w_idx]
	_queued_enemies = oleada.enemigos.duplicate()
	_queued_enemies.sort_custom(func(a: EnemigoData, b: EnemigoData) -> bool: return a.spawn_time < b.spawn_time)

	enemigos_por_oleada = 0
	for e: EnemigoData in oleada.enemigos:
		if not e.es_escudo:
			enemigos_por_oleada += e.quantity

	goblins_spawned_in_wave = active_goblins.size()
	enemigos_muertos_en_oleada = 0
	is_wave_active = true
	_elapsed_wave_time = 0.0

	oleada_iniciada.emit(current_wave)


func _spawn_from_data(enemy_data: EnemigoData) -> void:
	var scene: PackedScene = _resolver_escena(enemy_data.escena_path)
	if not scene:
		return

	for i: int in range(enemy_data.quantity):
		var offset: Vector3 = Vector3.ZERO
		if enemy_data.quantity > 1:
			offset = Vector3(randf_range(-0.5, 0.5), randf_range(-0.2, 0.2), 0)

		var enemy: Node = scene.instantiate()
		get_tree().root.add_child(enemy)
		enemy.global_position = enemy_data.spawn_position + offset

		if enemy.has_signal("died"):
			enemy.died.connect(_on_enemy_died.bind(enemy))

		active_goblins.append(enemy)
		goblins_spawned_in_wave += 1
		goblin_spawneado.emit(enemy)


func _spawn_shield_imp_from_data(enemy_data: EnemigoData) -> void:
	var scene: PackedScene = _resolver_escena(enemy_data.escena_path)
	if not scene:
		return

	for i: int in range(enemy_data.quantity):
		var enemy: Node = scene.instantiate()
		get_tree().root.add_child(enemy)
		enemy.global_position = enemy_data.spawn_position

		if enemy.has_signal("died"):
			enemy.died.connect(_on_shield_imp_died.bind(enemy))

		shield_imps_activos.append(enemy)
		active_goblins.append(enemy)
		goblin_spawneado.emit(enemy)


func _resolver_escena(path: String) -> PackedScene:
	if path == "":
		return null
	var scene: PackedScene = load(path) as PackedScene
	if not scene:
		push_error("[WaveSpawner] No se pudo cargar: %s" % path)
	return scene


func _on_enemy_died(enemy: Node) -> void:
	active_goblins.erase(enemy)
	enemigos_muertos_en_oleada += 1
	AudioManager.on_enemy_killed()


func _on_shield_imp_died(shield_imp: Node) -> void:
	shield_imps_activos.erase(shield_imp)
	active_goblins.erase(shield_imp)
	enemigos_muertos_en_oleada += 1


func _check_wave_complete() -> void:
	for i: int in range(active_goblins.size() - 1, -1, -1):
		if not is_instance_valid(active_goblins[i]):
			active_goblins.remove_at(i)

	var enemigos_normales_vivos: int = 0
	for enemy: Node in active_goblins:
		if is_instance_valid(enemy) and not shield_imps_activos.has(enemy):
			enemigos_normales_vivos += 1

	if enemigos_normales_vivos == 0:
		is_wave_active = false
		var cooldown: float = 5.0
		if current_level_data and current_wave - 1 < current_level_data.oleadas.size():
			cooldown = current_level_data.oleadas[current_wave - 1].tiempo_entre_oleadas
		wave_cooldown = cooldown
		oleada_completada.emit(current_wave)


func _check_shield_imp_spawn(delta: float) -> void:
	shield_spawn_timer -= delta
	if shield_spawn_timer > 0:
		return
	shield_spawn_timer = intervalo_check_escudo

	for i: int in range(shield_imps_activos.size() - 1, -1, -1):
		if not is_instance_valid(shield_imps_activos[i]):
			shield_imps_activos.remove_at(i)

	if shield_imps_activos.size() >= max_imp_escudo_activos:
		return

	if obtener_goblins_activos() < enemigos_minimos_para_escudo:
		return

	var hay_shooting: bool = false
	for enemy: Node in active_goblins:
		if is_instance_valid(enemy) and enemy is EnemyBase:
			if enemy.current_state == EnemyBase.State.SHOOTING:
				hay_shooting = true
				break

	if not hay_shooting:
		return

	_spawn_shield_imp_auto()


func _spawn_shield_imp_auto() -> void:
	if not escena_imp_escudo:
		return

	var shield_imp: Node = escena_imp_escudo.instantiate()
	var spawn_pos: Vector3 = global_position
	spawn_pos.y += altura_spawn

	get_tree().root.add_child(shield_imp)
	shield_imp.global_position = spawn_pos

	if shield_imp.has_signal("died"):
		shield_imp.died.connect(_on_shield_imp_died.bind(shield_imp))

	shield_imps_activos.append(shield_imp)
	active_goblins.append(shield_imp)


# ═══════════════════════════════════════════════════════════════════
# API PÚBLICA
# ═══════════════════════════════════════════════════════════════════


func iniciar_desde_data(level_data: LevelData) -> void:
	current_level_data = level_data
	if level_data and level_data.oleadas.size() > 0:
		current_wave = 0
		wave_cooldown = 0.5
		is_wave_active = false
		_paused = false
	else:
		push_error("[WaveSpawner] LevelData inválido o sin oleadas.")


func iniciar_spawning() -> void:
	_paused = false
	wave_cooldown = 0.5


func detener_spawning() -> void:
	is_wave_active = false
	_paused = true
	wave_cooldown = 999999.0


func toggle_pause_spawning() -> void:
	_paused = not _paused


func spawn_pacificos(
	escenas: Array[PackedScene], velocidad_uniforme: float = 0.5, offset_entre: float = 0.4
) -> Array:
	var enemigos: Array = []
	for i: int in range(escenas.size()):
		var escena: PackedScene = escenas[i]
		if not escena:
			continue
		var enemigo: Node = escena.instantiate()
		enemigo.modo_pacifico = true
		enemigo.velocidad_caminar = velocidad_uniforme
		enemigo.distancia_maxima_caminar = 10.0

		var spawn_pos: Vector3 = global_position
		spawn_pos.y += altura_spawn
		spawn_pos.x += i * offset_entre

		get_tree().root.add_child(enemigo)
		enemigo.global_position = spawn_pos

		if enemigo.has_signal("died"):
			enemigo.died.connect(_on_enemy_died.bind(enemigo))
		active_goblins.append(enemigo)
		enemigos.append(enemigo)
	return enemigos


func obtener_goblins_activos() -> int:
	for i: int in range(active_goblins.size() - 1, -1, -1):
		if not is_instance_valid(active_goblins[i]):
			active_goblins.remove_at(i)
	return active_goblins.size()


func get_active_enemies() -> Array:
	for i: int in range(active_goblins.size() - 1, -1, -1):
		if not is_instance_valid(active_goblins[i]):
			active_goblins.remove_at(i)
	return active_goblins


func get_active_shield_imps() -> Array:
	for i: int in range(shield_imps_activos.size() - 1, -1, -1):
		if not is_instance_valid(shield_imps_activos[i]):
			shield_imps_activos.remove_at(i)
	return shield_imps_activos


func forzar_spawn(escena_path: String = "") -> void:
	var scene: PackedScene
	if escena_path != "":
		scene = load(escena_path) as PackedScene
	else:
		scene = escena_goblin
	if not scene:
		return

	var enemy: Node = scene.instantiate()
	var spawn_pos: Vector3 = global_position
	spawn_pos.y += altura_spawn

	get_tree().root.add_child(enemy)
	enemy.global_position = spawn_pos

	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))

	active_goblins.append(enemy)
	goblins_spawned_in_wave += 1
	goblin_spawneado.emit(enemy)


func forzar_spawn_escudo() -> void:
	_spawn_shield_imp_auto()
