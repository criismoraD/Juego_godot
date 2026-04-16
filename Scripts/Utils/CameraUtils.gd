class_name CameraUtils
extends RefCounted

static func obtener_camara_juego(contexto: Node) -> Camera3D:
	if contexto == null:
		return null

	var camara_activa := contexto.get_viewport().get_camera_3d()
	if camara_activa:
		return camara_activa

	if contexto.get_tree() == null:
		return null

	var escena_actual := contexto.get_tree().current_scene
	if escena_actual:
		var camara_frente := escena_actual.find_child("CamaraFrente", true, false)
		if camara_frente is Camera3D:
			return camara_frente

		var camara_principal := escena_actual.find_child("PRESPECTIVA", true, false)
		if camara_principal is Camera3D:
			return camara_principal

	return null
