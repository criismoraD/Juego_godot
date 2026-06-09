class_name ArqueraRutaSegura
extends RefCounted


static func es_ruta_segura(ruta: String) -> bool:
	if not ruta.begins_with("res://"):
		return false

	if ".." in ruta or "\\" in ruta:
		return false

	return true
