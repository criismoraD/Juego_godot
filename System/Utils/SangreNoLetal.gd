class_name SangreNoLetal
extends RefCounted

## Efecto de sangre NO LETAL compartido por la protagonista y las defensoras
## aliadas (arquera y ballestera). Spawnea el splash 2D en el punto de impacto
## usando la misma convención de EnemyBase: posición/dirección del último golpe.

const ESCENA_SANGRE_NO_LETAL: PackedScene = preload("res://VFX/Scenes/BloodSplashNoLetal.tscn")
const OFFSET_SANGRE_POR_DEFECTO: Vector3 = Vector3.ZERO
const ALTURA_FALLBACK_CUERPO: float = 0.8


static func spawn(host: Node, hit_position: Vector3 = Vector3.ZERO, hit_direction: Vector3 = Vector3.ZERO) -> void:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	if host is not Node3D:
		return

	var splash_node: Node = ESCENA_SANGRE_NO_LETAL.instantiate()
	if splash_node == null:
		return

	var target_parent: Node = host.get_tree().current_scene
	if target_parent == null:
		target_parent = host.get_parent()
	if target_parent == null:
		target_parent = host

	target_parent.add_child(splash_node)

	var splash_pos: Vector3 = hit_position
	if splash_pos == Vector3.ZERO:
		splash_pos = (host as Node3D).global_position + Vector3(0.0, ALTURA_FALLBACK_CUERPO, 0.0)
	splash_pos += OFFSET_SANGRE_POR_DEFECTO

	var splash_dir: Vector3 = hit_direction
	if splash_dir == Vector3.ZERO:
		splash_dir = Vector3.LEFT

	if splash_node.has_method("setup"):
		splash_node.setup(splash_pos, splash_dir, Color.WHITE)
	elif splash_node is Node3D:
		splash_node.global_position = splash_pos
