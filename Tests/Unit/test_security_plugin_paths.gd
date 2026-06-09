extends "res://addons/gut/test.gd"

var ruta_segura_script = load("res://addons/arquera_godot_tools/ruta_segura.gd")


func test_es_ruta_segura_valida_solo_rutas_res_sin_traversal() -> void:
	var pruebas: Array[Dictionary] = [
		{"ruta": "res://Assets/Models/test.glb", "esperado": true},
		{"ruta": "res://test.png", "esperado": true},
		{"ruta": "user://config.cfg", "esperado": false},
		{"ruta": "/tmp/test_file", "esperado": false},
		{"ruta": "res://../fuera.txt", "esperado": false},
		{"ruta": "C:\\fake_system_path", "esperado": false},
		{"ruta": "res://subdir/../../evildat", "esperado": false},
	]

	for prueba in pruebas:
		assert_eq(
			ruta_segura_script.es_ruta_segura(prueba["ruta"]),
			prueba["esperado"],
			"La validacion de ruta debe coincidir para %s" % prueba["ruta"]
		)
