extends SceneTree

func _init():
	var escena = load("res://Levels/Rio en canoa con paralax.tscn")
	var root = escena.instantiate()
	
	print("=== NODOS EN EL NIVEL RÍO AGRUPADOS POR X ===")
	
	# Revisar todos los nodos hijos directos y en ParallaxFondo
	var todos_los_nodos = []
	for c in root.get_children():
		if c is Node3D:
			todos_los_nodos.append(c)
			for c2 in c.get_children():
				if c2 is Node3D:
					todos_los_nodos.append(c2)
	
	# Analizar presencia de pisos, cordillera, bosque y pinos por tramos de X (de -30 a 200)
	for x_bloque in range(-30, 200, 20):
		var x_min = float(x_bloque)
		var x_max = x_min + 20.0
		
		var num_pisos = 0
		var num_pinos = 0
		var num_cordillera = 0
		var num_bosque = 0
		var num_arboles_prueba = 0
		var num_ruinas = 0
		
		for n in todos_los_nodos:
			var gx = n.global_position.x
			if gx >= x_min and gx < x_max:
				var n_name = n.name.to_lower()
				if n_name.begins_with("piso nueva version"):
					num_pisos += 1
				elif n_name.begins_with("pino2d"):
					num_pinos += 1
				elif n_name.begins_with("piedracordillera"):
					num_cordillera += 1
				elif n_name.begins_with("bosquerojo"):
					num_bosque += 1
				elif n_name.begins_with("arboles_"):
					num_arboles_prueba += 1
				elif n_name.begins_with("ruina"):
					num_ruinas += 1
		
		print("Tramo X [%3.0f, %3.0f]: Pisos=%2d | Pinos=%2d | Cordillera=%2d | BosqueRojo=%d | ArbolesPrueba=%d | Ruinas=%d" % [
			x_min, x_max, num_pisos, num_pinos, num_cordillera, num_bosque, num_arboles_prueba, num_ruinas
		])
	
	quit(0)
