extends "res://addons/gut/test.gd"

## Tests unitarios para la presencia y configuración de los props decorativos
## (Espada Oxidada, Mandoble y Pechera Oxidada / Metálica) en NIVEL_TUTORIAL.

const ESCENA_TUTORIAL_PATH: String = "res://Levels/NIVEL_TUTORIAL/NIVEL_TUTORIAL.tscn"


func test_props_armas_y_armadura_tutorial_existen() -> void:
	# Arrange
	var packed: PackedScene = load(ESCENA_TUTORIAL_PATH) as PackedScene
	assert_not_null(packed, "La escena tutorial debe cargar correctamente")
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	# Act
	var pechera: Node3D = nivel.find_child("PecheraMetalica", true, false) as Node3D
	var espada: Sprite3D = nivel.find_child("EspadaOxidada", true, false) as Sprite3D
	var mandoble: Sprite3D = nivel.find_child("Mandoble", true, false) as Sprite3D

	# Assert (AAA)
	assert_not_null(pechera, "El nodo PecheraMetalica debe existir en NIVEL_TUTORIAL")
	assert_not_null(espada, "El nodo EspadaOxidada debe existir en NIVEL_TUTORIAL")
	assert_not_null(mandoble, "El nodo Mandoble debe existir en NIVEL_TUTORIAL")

	if espada != null:
		assert_not_null(espada.texture, "EspadaOxidada debe poseer textura asignada")
		assert_true((espada.layers & 1) != 0 or (espada.layers & 2) != 0, "EspadaOxidada debe tener capas visuales configuradas")

	if mandoble != null:
		assert_not_null(mandoble.texture, "Mandoble debe poseer textura asignada")
		assert_true((mandoble.layers & 1) != 0 or (mandoble.layers & 2) != 0, "Mandoble debe tener capas visuales configuradas")
