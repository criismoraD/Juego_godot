class_name ProjectileBase
extends Area3D

func _check_off_screen_base(camera: Camera3D, global_pos: Vector3, margin_x: float = 400.0, min_y: float = -20.0, margin_top: float = 2000.0, margin_bottom: float = 300.0) -> bool:
	if not camera: return false
	var screen_pos = camera.unproject_position(global_pos)
	var viewport_size = get_viewport().get_visible_rect().size
	if screen_pos.x < -margin_x or screen_pos.x > viewport_size.x + margin_x: return true
	elif screen_pos.y < -margin_top: return true
	elif screen_pos.y > viewport_size.y + margin_bottom: return true
	elif global_pos.y < min_y: return true
	return false

func _cleanup_materials_base(cached_meshes: Array, cached_particles: Array = []):
	for mesh in cached_meshes:
		if is_instance_valid(mesh):
			mesh.material_override = null
			if mesh.mesh:
				for si in range(mesh.mesh.get_surface_count()):
					mesh.set_surface_override_material(si, null)
			mesh.visible = false
	for p in cached_particles:
		if is_instance_valid(p):
			p.emitting = false
			if p.get("draw_pass_1") and p.draw_pass_1 is Mesh:
				p.draw_pass_1.material = null

func _reparent_to_shield_base(node: Node3D, shield: Node3D, saved_transform: Transform3D, cleanup_func: Callable):
	if not is_instance_valid(shield):
		cleanup_func.call()
		node.queue_free()
		return
	var current_parent = node.get_parent()
	if current_parent: current_parent.remove_child(node)
	shield.add_child(node)
	node.global_transform = saved_transform
	if shield.has_signal("destruido"):
		shield.destruido.connect(func():
			if is_instance_valid(node) and node.is_inside_tree():
				cleanup_func.call()
				node.queue_free()
		)
