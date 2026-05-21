class_name EnemyPool
extends Node
## Object Pooling para enemigos con soporte para múltiples tipos
## Mejora el rendimiento evitando instanciar/destruir constantemente

signal pool_expanded(new_size: int)

@export var enemy_scenes: Dictionary  # {"enemy_type": PackedScene}
@export var initial_pool_size: int = 20
@export var max_pool_size: int = 100
@export var expand_step: int = 10

var _pools: Dictionary = {}  # {"enemy_type": [Node2D]}
var _active_enemies: Array[Node2D] = []
var _pool_enabled: bool = true

func _ready() -> void:
	_initialize_pools()


func _initialize_pools() -> void:
	for enemy_type in enemy_scenes.keys():
		var scene: PackedScene = enemy_scenes[enemy_type]
		if not scene:
			push_error("EnemyPool: Scene nula para tipo " + str(enemy_type))
			continue
		
		_pools[enemy_type] = []
		
		for i in range(initial_pool_size):
			var enemy: Node2D = scene.instantiate()
			enemy.set_process(false)
			enemy.set_physics_process(false)
			enemy.set_visible(false)
			add_child(enemy)
			_pools[enemy_type].append(enemy)


func spawn_enemy(enemy_type: String, position: Vector2, setup_callback: Callable = Callable()) -> Node2D:
	if not _pool_enabled or enemy_type not in _pools:
		return _spawn_direct(enemy_type, position, setup_callback)
	
	var pool: Array = _pools[enemy_type]
	var enemy: Node2D = _get_available_enemy(pool)
	
	if not enemy:
		if pool.size() < max_pool_size:
			_expand_pool(enemy_type)
			enemy = _get_available_enemy(pool)
		else:
			push_warning("EnemyPool: Pool lleno para " + enemy_type)
			return null
	
	_activate_enemy(enemy, position, setup_callback)
	return enemy


func despawn_enemy(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	
	_active_enemies.erase(enemy)
	
	var enemy_type: String = enemy.get_meta("enemy_type", "")
	if enemy_type and enemy_type in _pools:
		_deactivate_enemy(enemy)
	else:
		enemy.queue_free()


func despawn_all_enemies() -> void:
	for enemy in _active_enemies.duplicate():
		despawn_enemy(enemy)


func get_active_count() -> int:
	return _active_enemies.size()


func get_pool_stats() -> Dictionary:
	var stats: Dictionary = {}
	for enemy_type in _pools.keys():
		var pool: Array = _pools[enemy_type]
		var available: int = 0
		for enemy in pool:
			if not enemy.is_visible_in_tree():
				available += 1
		stats[enemy_type] = {
			"total": pool.size(),
			"available": available,
			"active": pool.size() - available
		}
	stats["total_active"] = _active_enemies.size()
	return stats


func enable_pooling(enable: bool) -> void:
	_pool_enabled = enable


func _get_available_enemy(pool: Array) -> Node2D:
	for enemy in pool:
		if not enemy.is_visible_in_tree():
			return enemy
	return null


func _activate_enemy(enemy: Node2D, position: Vector2, setup_callback: Callable) -> void:
	enemy.global_position = position
	enemy.set_process(true)
	enemy.set_physics_process(true)
	enemy.set_visible(true)
	enemy.show()
	
	if setup_callback.is_valid():
		setup_callback.call(enemy)
	
	_active_enemies.append(enemy)
	
	if enemy.has_method("on_spawned"):
		enemy.on_spawned()


func _deactivate_enemy(enemy: Node2D) -> void:
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.set_visible(false)
	enemy.hide()
	
	if enemy.has_method("on_despawned"):
		enemy.on_despawned()


func _expand_pool(enemy_type: String) -> void:
	var scene: PackedScene = enemy_scenes[enemy_type]
	if not scene:
		return
	
	var pool: Array = _pools[enemy_type]
	for i in range(expand_step):
		if pool.size() >= max_pool_size:
			break
		var enemy: Node2D = scene.instantiate()
		enemy.set_process(false)
		enemy.set_physics_process(false)
		enemy.set_visible(false)
		add_child(enemy)
		pool.append(enemy)
	
	pool_expanded.emit(pool.size())


func _spawn_direct(enemy_type: String, position: Vector2, setup_callback: Callable) -> Node2D:
	var scene: PackedScene = enemy_scenes.get(enemy_type)
	if not scene:
		push_error("EnemyPool: Scene no encontrada para " + enemy_type)
		return null
	
	var enemy: Node2D = scene.instantiate()
	enemy.global_position = position
	add_child(enemy)
	_active_enemies.append(enemy)
	
	if setup_callback.is_valid():
		setup_callback.call(enemy)
	
	return enemy


func clear_all_pools() -> void:
	for enemy in _active_enemies.duplicate():
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()
	
	for enemy_type in _pools.keys():
		for enemy in _pools[enemy_type]:
			if is_instance_valid(enemy):
				enemy.queue_free()
		_pools[enemy_type].clear()
