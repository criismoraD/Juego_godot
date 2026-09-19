extends SceneTree

func _init():
	var escena = load("res://Levels/Rio en canoa con paralax.tscn")
	if not escena:
		print("ERROR al cargar escena")
		quit(1)
		return
	var root = escena.instantiate()
	get_root().add_child(root)
	
	print("--- INICIANDO SIMULACIÓN DE RÍO ---")
	
	# Simular 300 segundos (5 minutos de viaje) en pasos de delta = 0.1s
	var delta = 0.1
	var total_tiempo = 300.0
	var pasos = int(total_tiempo / delta)
	
	var camara = root.find_child("CamaraPrincipal", true, false)
	var canoa = root.find_child("CanoaProtagonistaRio", true, false)
	var fondo = root.find_child("ParallaxFondo", true, false)
	
	var pinos = []
	for c in root.get_children():
		if c is Pino2D:
			pinos.append(c)
	
	print("Pinos encontrados: ", pinos.size())
	
	# Monitorear cada 10 segundos
	for i in range(pasos):
		var t = i * delta
		# Ejecutar physics_process y process de los nodos relevantes
		if canoa:
			canoa._process(delta)
		if root.has_method("_process"):
			root._process(delta)
		if fondo and fondo.has_method("_process"):
			fondo._process(delta)
		for p in pinos:
			p._process(delta)
		
		if i % 100 == 0: # Cada 10 segundos
			var cam_x = camara.global_position.x if camara else 0.0
			var canoa_x = canoa.global_position.x if canoa else 0.0
			
			# Comprobar si hay pinos visibles en pantalla y su Y respecto al suelo
			var pinos_en_pantalla = 0
			var pinos_flotando = 0
			for p in pinos:
				var dist_x = p.global_position.x - cam_x
				if dist_x >= -20.0 and dist_x <= 20.0:
					pinos_en_pantalla += 1
					# Verificar si hay un piso debajo
					var tiene_piso_cerca = false
					var pisos = fondo.obtener_segmentos_piso_aliado()
					var min_dist_piso = 9999.0
					var piso_cercano = null
					for piso in pisos:
						var d = abs(piso.global_position.x - p.global_position.x)
						if d < min_dist_piso:
							min_dist_piso = d
							piso_cercano = piso
					if min_dist_piso < 3.0:
						tiene_piso_cerca = true
					else:
						pinos_flotando += 1
						# print("Pino flotando sin piso: t=", t, " pino=", p.name, " pino_x=", p.global_position.x, " cam_x=", cam_x, " min_dist_piso=", min_dist_piso)
			
			if pinos_flotando > 0:
				print("ALERTA t=%.1fs | Canoa X=%.1f | Cam X=%.1f | Pinos en pantalla: %d | PINOS FLOTANDO SIN PISO: %d" % [t, canoa_x, cam_x, pinos_en_pantalla, pinos_flotando])
			elif i % 500 == 0:
				print("OK t=%.1fs | Canoa X=%.1f | Cam X=%.1f | Pinos en pantalla: %d" % [t, canoa_x, cam_x, pinos_en_pantalla, pinos_flotando])
	
	print("--- SIMULACIÓN FINALIZADA ---")
	quit(0)
