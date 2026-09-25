extends GutTest

## Regresión Parser Error en AzulinaPosando.gd:
## `const MATERIAL_AZULINA: Material` + `is StandardMaterial3D` no compila
## ("Expression is of type Material..."). La const va tipada StandardMaterial3D.
## Además: la copia decorativa sale sin outline pero el material compartido
## debe conservar su next_pass (si se mutara el original, todas las Azulinas
## perderían la línea negra).

var scene_root: Node3D


func before_each() -> void:
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func test_script_compila_y_copia_sin_outline() -> void:
	# Arrange
	var scr: Script = load("res://Levels/Rio_En_Canoa_Con_Parallax/AzulinaPosando.gd") as Script
	assert_not_null(scr, "AzulinaPosando.gd debe compilar sin Parser Error")
	if scr == null:
		return
	var nodo: Node3D = scr.new() as Node3D
	scene_root.add_child(nodo)
	await get_tree().process_frame

	# Act
	var mat: Material = nodo.call("_obtener_material_sin_outline") as Material

	# Assert: copia StandardMaterial3D sin outline para el adorno
	assert_not_null(mat, "Debe devolver un material")
	assert_true(mat is StandardMaterial3D, "La copia debe ser StandardMaterial3D")
	assert_null((mat as StandardMaterial3D).next_pass, "La copia decorativa no debe tener outline")


func test_material_compartido_conserva_outline() -> void:
	# Arrange
	var compartido := preload("res://Entities/Enemigo_Azulina/Azulina_MAT.tres") as StandardMaterial3D

	# Assert: el recurso compartido trae su next_pass de línea negra
	assert_not_null(compartido, "Azulina_MAT.tres debe cargar como StandardMaterial3D")
	assert_true(compartido.next_pass is ShaderMaterial, "El compartido conserva su next_pass con outline")
