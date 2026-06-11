@tool
extends SceneTree

func _init():
	var doc = GLTFDocument.new()
	var state = GLTFState.new()
	var err = doc.append_from_file("res://Assets/Environment/Escudo_enemigo/Escudonivel3.glb", state)
	if err == OK:
		print("Materiales: ", state.materials.size())
		for mat in state.materials:
			print("Mat name: ", mat.name, " class: ", mat.get_class())
	else:
		print("Error loading glb")
	quit()
