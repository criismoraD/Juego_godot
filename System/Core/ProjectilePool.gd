class_name ProjectilePool
extends RefCounted

const MAX_POOLED_PER_SCENE: int = 64
const META_SCENE_PATH: StringName = &"projectile_pool_scene_path"
const META_REUSED: StringName = &"projectile_pool_reused"

static var _available_by_scene: Dictionary = {}


static func acquire(scene: PackedScene) -> Node:
	if not scene:
		return null

	var scene_path := scene.resource_path
	if scene_path.is_empty():
		return scene.instantiate()

	var available := _get_available(scene_path)
	while not available.is_empty():
		var node: Node = available.pop_back()
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.set_meta(META_REUSED, true)
			return node

	var instance := scene.instantiate()
	instance.set_meta(META_SCENE_PATH, scene_path)
	instance.set_meta(META_REUSED, false)
	return instance


static func activate(node: Node, parent: Node, global_position: Vector3) -> void:
	if not is_instance_valid(node) or not is_instance_valid(parent):
		return

	var reused := bool(node.get_meta(META_REUSED, false))
	parent.add_child(node)
	if node is Node3D:
		node.global_position = global_position

	if reused and node.has_method("_activar_desde_pool"):
		node.call("_activar_desde_pool")

	node.set_meta(META_REUSED, false)


static func release(node: Node) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return

	if not node.has_meta(META_SCENE_PATH):
		_free_node(node)
		return

	if node.has_method("_desactivar_para_pool"):
		node.call("_desactivar_para_pool")

	var parent := node.get_parent()
	if parent:
		parent.remove_child(node)

	var scene_path := String(node.get_meta(META_SCENE_PATH))
	var available := _get_available(scene_path)
	if available.size() >= MAX_POOLED_PER_SCENE:
		_free_node(node)
		return

	available.append(node)


static func clear_all() -> void:
	for scene_path in _available_by_scene.keys():
		var available: Array = _available_by_scene[scene_path]
		for node in available:
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				_free_node(node)
		available.clear()

	_available_by_scene.clear()


static func get_available_count(scene: PackedScene) -> int:
	if not scene:
		return 0

	return _get_available(scene.resource_path).size()


static func _get_available(scene_path: String) -> Array:
	if not _available_by_scene.has(scene_path):
		_available_by_scene[scene_path] = []

	return _available_by_scene[scene_path]


static func _free_node(node: Node) -> void:
	if node.is_inside_tree():
		node.queue_free()
		return

	node.free()
