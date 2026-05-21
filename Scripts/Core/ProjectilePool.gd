class_name ProjectilePool
extends Node
## Object Pooling para proyectiles - Optimización de rendimiento
## 
## Evita crear/destruir nodos constantemente, reutilizando instancias.
## 
## Uso:
##   var arrow = ProjectilePool.get_projectile("Arrow")
##   arrow.shoot(direction, speed)
##   # Cuando el proyectil impacta:
##   ProjectilePool.return_projectile(arrow)

const MAX_PROJECTILES = 100

var _pools: Dictionary = {}  # {type: Array[Node]}
var _active_projectiles: Array[Node] = []
var _projectile_scenes: Dictionary = {}  # {type: PackedScene}

# Precarga de escenas comunes
@onready var _arrow_scene = preload("res://Scenes/Projectiles/Arrow.tscn")


func _ready():
	# Inicializar pool de flechas
	_initialize_pool("Arrow", _arrow_scene, 20)


func _initialize_pool(type: String, scene: PackedScene, initial_size: int):
	if not _pools.has(type):
		_pools[type] = []
		_projectile_scenes[type] = scene
	
	for i in range(initial_size):
		var projectile = scene.instantiate()
		projectile.set_process(false)  # Desactivar hasta que se use
		add_child(projectile)
		_pools[type].append(projectile)


## Obtiene un proyectil del pool o crea uno nuevo si es necesario
func get_projectile(type: String, spawn_position: Vector3 = Vector3.ZERO, rotation: Quaternion = Quaternion.IDENTITY) -> Node:
	if not _pools.has(type):
		if _projectile_scenes.has(type):
			_initialize_pool(type, _projectile_scenes[type], 10)
		else:
			push_error("[ProjectilePool] Tipo de proyectil no registrado: " + type)
			return null
	
	# Buscar proyectil disponible en el pool
	for projectile in _pools[type]:
		if not is_instance_valid(projectile):
			continue
		
		# Verificar si está activo (asumiendo que tiene una propiedad 'is_active')
		var is_active = false
		if projectile.has_meta("is_active"):
			is_active = projectile.get_meta("is_active")
		elif projectile.has_method("is_active"):
			is_active = projectile.is_active()
		elif "visible" in projectile:
			is_active = projectile.visible
		
		if not is_active:
			# Reactivar proyectil
			projectile.global_position = spawn_position
			if projectile is Node3D:
				projectile.quaternion = rotation
			
			if projectile.has_method("activate"):
				projectile.activate()
			else:
				projectile.set_process(true)
				if projectile.visible != null:
					projectile.visible = true
			
			projectile.set_meta("is_active", true)
			_active_projectiles.append(projectile)
			return projectile
	
	# No hay proyectiles disponibles, crear uno nuevo (expansión dinámica)
	var new_projectile = _projectile_scenes[type].instantiate()
	new_projectile.global_position = spawn_position
	if new_projectile is Node3D:
		new_projectile.quaternion = rotation
	add_child(new_projectile)
	_pools[type].append(new_projectile)
	_active_projectiles.append(new_projectile)
	new_projectile.set_meta("is_active", true)
	
	push_warning("[ProjectilePool] Pool expandido para tipo: %s (nuevo tamaño: %d)" % [type, _pools[type].size()])
	return new_projectile


## Devuelve un proyectil al pool para reutilización
func return_projectile(projectile: Node) -> void:
	if not is_instance_valid(projectile):
		return
	
	# Encontrar el tipo de proyectil
	var found_type = ""
	for type in _pools.keys():
		if projectile in _pools[type]:
			found_type = type
			break
	
	if found_type == "":
		push_warning("[ProjectilePool] Intento de retornar proyectil no registrado")
		return
	
	# Desactivar proyectil
	if projectile.has_method("deactivate"):
		projectile.deactivate()
	else:
		projectile.set_process(false)
		if projectile.has_method("stop_all"):
			projectile.stop_all()  # Detener partículas, sonidos, etc.
		if "visible" in projectile:
			projectile.visible = false
	
	projectile.set_meta("is_active", false)
	
	# Remover de activos
	var idx = _active_projectiles.find(projectile)
	if idx >= 0:
		_active_projectiles.remove_at(idx)


## Retorna todos los proyectiles activos de un tipo específico
func return_all_of_type(type: String) -> void:
	if not _pools.has(type):
		return
	
	for projectile in _pools[type]:
		if is_instance_valid(projectile):
			var is_active = projectile.get_meta("is_active") if projectile.has_meta("is_active") else false
			if is_active:
				return_projectile(projectile)


## Limpia todos los proyectiles activos
func clear_all_active() -> void:
	for projectile in _active_projectiles.duplicate():
		if is_instance_valid(projectile):
			return_projectile(projectile)
	_active_projectiles.clear()


## Obtiene estadísticas del pool (para debug/profiling)
func get_stats() -> Dictionary:
	var stats = {
		"total_pools": _pools.size(),
		"active_count": _active_projectiles.size(),
		"pools": {}
	}
	
	for type in _pools.keys():
		var pool_size = _pools[type].size()
		var active_in_pool = 0
		for proj in _pools[type]:
			if is_instance_valid(proj) and proj.get_meta("is_active") if proj.has_meta("is_active") else false:
				active_in_pool += 1
		
		stats["pools"][type] = {
			"total": pool_size,
			"active": active_in_pool,
			"available": pool_size - active_in_pool
		}
	
	return stats


## Pre-carga un tipo de proyectil con un tamaño inicial específico
func register_projectile_type(type: String, scene: PackedScene, initial_size: int = 10) -> void:
	if _pools.has(type):
		push_warning("[ProjectilePool] Tipo ya registrado: " + type)
		return
	
	_projectile_scenes[type] = scene
	_initialize_pool(type, scene, initial_size)
