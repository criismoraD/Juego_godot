class_name CameraUtils
extends RefCounted
static var _cached_camera: Camera3D = null
static var _cached_scene: Node = null


static func obtener_camara_juego(contexto: Node) -> Camera3D:
	if contexto == null:
		return null

	# 1. Intentar obtener la cámara activa del Viewport (Rápido, O(1))
	var viewport := contexto.get_viewport()
	if viewport:
		var camara_activa := viewport.get_camera_3d()
		if camara_activa:
			return camara_activa

	# 2. Fallback: Buscar en la escena actual si no hay cámara activa en el viewport
	if contexto.get_tree() == null:
		return null

	var escena_actual := contexto.get_tree().current_scene
	if escena_actual == null:
		return null

	# Verificar si el cache es válido para la escena actual
	# is_instance_valid previene errores si la cámara fue liberada (queue_free)
	if is_instance_valid(_cached_camera) and _cached_scene == escena_actual:
		return _cached_camera

	# Si la escena cambió o no hay cache, buscar mediante tree traversal (Lento, O(N))
	_cached_scene = escena_actual

	var camara_frente := escena_actual.find_child("CamaraFrente", true, false)
	if camara_frente is Camera3D:
		_cached_camera = camara_frente
		return _cached_camera

	var camara_principal := escena_actual.find_child("PRESPECTIVA", true, false)
	if camara_principal is Camera3D:
		_cached_camera = camara_principal
		return _cached_camera

	_cached_camera = null
	return null
