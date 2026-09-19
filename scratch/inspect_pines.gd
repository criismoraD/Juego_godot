extends SceneTree

func _init():
	var escena = load("res://Levels/Rio en canoa con paralax.tscn")
	if not escena:
		print("ERROR: No se pudo cargar la escena")
		quit(1)
		return
	var root = escena.instantiate()
	var pinos = []
	var pisos = []
	for child in root.get_children():
		if child is Pino2D or child.name.begins_with("Pino2D"):
			pinos.append(child)
		if child.name.to_lower().begins_with("piso"):
			pisos.append(child)
	
	print("Total pinos: ", pinos.size())
	print("Total pisos: ", pisos.size())
	
	# Check X range of pisos
	var min_piso_x = 999999.0
	var max_piso_x = -999999.0
	for p in pisos:
		print("Piso: ", p.name, " pos: ", p.position, " scale: ", p.scale)
		min_piso_x = min(min_piso_x, p.position.x)
		max_piso_x = max(max_piso_x, p.position.x)
	print("Rango X pisos: [", min_piso_x, ", ", max_piso_x, "]")
	
	var min_pino_x = 999999.0
	var max_pino_x = -999999.0
	var min_pino_y = 999999.0
	var max_pino_y = -999999.0
	for p in pinos:
		min_pino_x = min(min_pino_x, p.position.x)
		max_pino_x = max(max_pino_x, p.position.x)
		min_pino_y = min(min_pino_y, p.position.y)
		max_pino_y = max(max_pino_y, p.position.y)
		if p.position.y > 1.2 or p.position.y < 0.0:
			print("Pino altura notable: ", p.name, " pos: ", p.position)
	print("Rango X pinos: [", min_pino_x, ", ", max_pino_x, "]")
	print("Rango Y pinos: [", min_pino_y, ", ", max_pino_y, "]")
	quit(0)
