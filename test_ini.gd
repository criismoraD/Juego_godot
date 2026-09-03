@tool
extends SceneTree

func _init() -> void:
	var config = ConfigFile.new()
	config.load("c:/Juego_godot-main/Assets/Environment/Escudo_enemigo/Escudonivel3.glb.import")
	var subrecursos = config.get_value("params", "_subresources", {})
	var materiales = subrecursos.get("materials", {})
	materiales["Escudonivel3_M"] = {
		"use_external/enabled": true,
		"use_external/fallback_path": "res://Assets/Environment/Escudo_enemigo/Escudonivel3_MAT.tres",
		"use_external/path": "uid://test"
	}
	subrecursos["materials"] = materiales
	config.set_value("params", "_subresources", subrecursos)
	config.save("c:/Juego_godot-main/test_import.ini")
	quit()
