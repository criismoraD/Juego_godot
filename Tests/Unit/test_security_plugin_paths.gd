extends SceneTree

func _init():
	print("--- Iniciando Pruebas de Seguridad: Path Traversal ---")

	var plugin_script = load("res://addons/arquera_godot_tools/plugin.gd")
	var plugin = plugin_script.new()

	var pruebas = [
		{"ruta": "res://Assets/Models/test.glb", "esperado": true, "desc": "Ruta valida en res://"},
		{"ruta": "res://test.png", "esperado": true, "desc": "Ruta raiz en res://"},
		{"ruta": "user://config.cfg", "esperado": false, "desc": "Ruta en user:// (debe fallar)"},
		{"ruta": "/etc/passwd", "esperado": false, "desc": "Ruta absoluta (debe fallar)"},
		{"ruta": "res://../fuera.txt", "esperado": false, "desc": "Path traversal con .. (debe fallar)"},
		{"ruta": "C:\\Windows\\system32", "esperado": false, "desc": "Ruta Windows (debe fallar)"},
		{"ruta": "res://subdir/../../evildat", "esperado": false, "desc": "Path traversal complejo (debe fallar)"}
	]

	var exitos = 0
	for p in pruebas:
		var resultado = plugin._es_ruta_segura(p.ruta)
		if resultado == p.esperado:
			print("[PASO] %s: %s" % [p.desc, p.ruta])
			exitos += 1
		else:
			print("[FALLO] %s: %s (Obtenido: %s, Esperado: %s)" % [p.desc, p.ruta, resultado, p.esperado])

	print("--- Resumen: %d/%d pruebas pasadas ---" % [exitos, pruebas.size()])

	if exitos == pruebas.size():
		print("Pruebas de seguridad completadas con exito.")
		quit(0)
	else:
		print("Algunas pruebas de seguridad fallaron.")
		quit(1)
