class_name CameraUtils
extends RefCounted
static var _cached_camera: Camera3D = null
static var _cached_scene: Node = null


static func obtener_camara_juego(contexto: Node) -> Camera3D:
	if contexto == null:
		return null

	if contexto.get_tree() == null:
		var vp := contexto.get_viewport()
		if vp:
			return vp.get_camera_3d()
		return null

	var escena_actual: Node = contexto.get_tree().current_scene
	if escena_actual == null:
		escena_actual = contexto.get_tree().root

	# Verificar si el cache es válido para la escena actual
	# is_instance_valid previene errores si la cámara fue liberada (queue_free)
	if is_instance_valid(_cached_camera) and _cached_scene == escena_actual:
		return _cached_camera

	# Si la escena cambió o no hay cache, buscar mediante tree traversal
	_cached_scene = escena_actual

	# 1. Priorizar cámaras específicas del juego (render 2.5D de juego)
	var camara_frente := escena_actual.find_child("CamaraFrente", true, false)
	if camara_frente is Camera3D:
		_cached_camera = camara_frente
		return _cached_camera

	var camara_rio := escena_actual.find_child("CamaraPrincipal", true, false)
	if camara_rio is Camera3D:
		_cached_camera = camara_rio
		return _cached_camera

	# 2. Intentar obtener la cámara activa del Viewport si no es PRESPECTIVA (cámara técnica de iluminación)
	var viewport := contexto.get_viewport()
	if viewport:
		var camara_activa := viewport.get_camera_3d()
		if camara_activa and camara_activa.name != "PRESPECTIVA":
			_cached_camera = camara_activa
			return _cached_camera

	# 3. Fallback: Buscar en la escena actual
	for cam in escena_actual.find_children("*", "Camera3D", true, false):
		if cam is Camera3D and (cam.current or cam.name == "CamaraPrincipal"):
			_cached_camera = cam
			return _cached_camera

	var camara_principal := escena_actual.find_child("PRESPECTIVA", true, false)
	if camara_principal is Camera3D:
		_cached_camera = camara_principal
		return _cached_camera

	_cached_camera = null
	return null
