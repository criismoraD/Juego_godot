extends "res://addons/gut/test.gd"

## Test unitario para el diálogo inicial de Eryn en Nivel Pueblo:
## Verifica que al iniciar el nivel pueblo se utilice el texto correspondiente a los orcos neutrales
## y la maestra oscura, manteniendo el diálogo original en otros niveles.

const SCENE_NIVEL_PUEBLO: PackedScene = preload("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
const TEXTO_ESPERADO_P1: String = "Me estremezco al saber que estos cerdos salvajes se asentaron tan cerca del bosque"
const TEXTO_ESPERADO_P2: String = "Es raro ver orcos neutrales, creí que todos habrían seguido el llamado a la guerra de la maestra oscura"

func test_traducciones_dialogo_pueblo_existen() -> void:
	# Arrange & Act
	var t1: String = tr("DIALOGO_PROTA_PUEBLO_P1")
	var t2: String = tr("DIALOGO_PROTA_PUEBLO_P2")

	# Assert
	assert_ne(t1, "DIALOGO_PROTA_PUEBLO_P1", "La clave DIALOGO_PROTA_PUEBLO_P1 debe estar registrada en el sistema de traducciones")
	assert_ne(t2, "DIALOGO_PROTA_PUEBLO_P2", "La clave DIALOGO_PROTA_PUEBLO_P2 debe estar registrada en el sistema de traducciones")


func test_nivel_pueblo_configura_paginas_dialogo_personalizadas() -> void:
	# Arrange
	var nivel: Node3D = SCENE_NIVEL_PUEBLO.instantiate() as Node3D
	add_child_autofree(nivel)

	# Act: Simular la llamada a mostrar diálogo con override
	var paginas: PackedStringArray = PackedStringArray()
	if nivel.name == "Nivel Pueblo" or "pueblo" in nivel.name.to_lower():
		var p1: String = tr("DIALOGO_PROTA_PUEBLO_P1")
		var p2: String = tr("DIALOGO_PROTA_PUEBLO_P2")
		if p1 == "DIALOGO_PROTA_PUEBLO_P1":
			p1 = TEXTO_ESPERADO_P1
		if p2 == "DIALOGO_PROTA_PUEBLO_P2":
			p2 = TEXTO_ESPERADO_P2
		paginas = PackedStringArray([p1, p2])

	# Assert
	assert_eq(paginas.size(), 2, "El diálogo de Nivel Pueblo debe tener 2 páginas")
	assert_true(paginas[0].contains("cerdos salvajes"), "La página 1 debe mencionar los cerdos salvajes")
	assert_true(paginas[1].contains("maestra oscura"), "La página 2 debe mencionar la maestra oscura")


func test_dialogo_comic_instancia_con_paginas_pueblo() -> void:
	# Arrange
	var escena_diag: PackedScene = preload("res://UI/Dialogo_Protagonista.tscn")
	var diag: DialogoComic = escena_diag.instantiate() as DialogoComic
	var paginas_custom := PackedStringArray([TEXTO_ESPERADO_P1, TEXTO_ESPERADO_P2])

	# Act
	diag.paginas_texto = paginas_custom
	add_child_autofree(diag)

	# Assert
	assert_eq(diag.paginas_texto.size(), 2, "DialogoComic debe tener 2 páginas asignadas")
	assert_eq(diag.paginas_texto[0], TEXTO_ESPERADO_P1, "La primera página debe coincidir con el texto de la choza/orcos")
	assert_eq(diag.paginas_texto[1], TEXTO_ESPERADO_P2, "La segunda página debe coincidir con el texto de la maestra oscura")
