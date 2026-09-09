extends GutTest

## Regresión: EnemyBase._buscar_jugador espera un frame y luego toca el
## árbol. Si el enemigo sale del árbol en ese frame (limpieza de oleada,
## botón debug de cinemática, transiciones) sin liberarse, get_tree() es
## nulo y saltaban errores "Cannot call method 'get_first_node_in_group'
## on a null value" (104 en el depurador). GUT falla solo con errores
## inesperados del motor, así que este test cubre la regresión.


func test_buscar_jugador_sin_error_si_enemigo_sale_del_arbol() -> void:
	# Arrange: 3 goblins reales (su _ready deja _buscar_jugador esperando).
	var escena: PackedScene = load("res://Entities/Enemigo_Goblin/Goblin.tscn")
	assert_not_null(escena, "Debe existir Goblin.tscn")
	var contenedor := Node.new()
	contenedor.name = "ContenedorEnemigos"
	add_child_autofree(contenedor)
	var victimas: Array = []
	for i in range(3):
		var e = escena.instantiate()
		contenedor.add_child(e)
		victimas.append(e)

	# Act: sacar 2 del árbol en el mismo frame, ANTES de que resuelva el
	# await (siguen vivos fuera del árbol: el await sí se reanuda, con
	# get_tree() nulo). Se liberan al final del test.
	contenedor.remove_child(victimas[0])
	contenedor.remove_child(victimas[1])
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: el que quedó sigue válido (los errores del motor, si los
	# hubiera, los marca GUT como fallos inesperados).
	assert_true(is_instance_valid(victimas[2]), "El que quedó sigue válido")
	victimas[0].queue_free()
	victimas[1].queue_free()


func test_buscar_jugador_resuelve_si_enemigo_vive() -> void:
	# Arrange
	var escena: PackedScene = load("res://Entities/Enemigo_Goblin/Goblin.tscn")
	var e = escena.instantiate()
	add_child_autofree(e)

	# Act
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: sin jugador en escena la referencia queda nula pero sin errores.
	assert_true(is_instance_valid(e), "El enemigo sigue válido")
	assert_null(e.get("player_ref"), "Sin player en escena no hay referencia")
