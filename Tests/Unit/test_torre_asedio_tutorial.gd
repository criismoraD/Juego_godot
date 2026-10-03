extends "res://addons/gut/test.gd"

## Torre de asedio de fondo del tutorial: decorativa, visible y estática,
## sin spawnear enemigos que interfieran con las oleadas del nivel.

const ESCENA_TUTORIAL: String = "res://Levels/NIVEL_TUTORIAL/NIVEL_TUTORIAL.tscn"

var _nivel: Node = null


func after_each() -> void:
	if is_instance_valid(_nivel):
		_nivel.free()
		_nivel = null


func _cargar_nivel() -> Node:
	var escena := load(ESCENA_TUTORIAL) as PackedScene
	assert_not_null(escena, "NIVEL_TUTORIAL.tscn debe cargar sin errores")
	_nivel = escena.instantiate()
	get_tree().root.add_child(_nivel)
	return _nivel


## 1. La torre existe, queda activa y visible al iniciar el nivel.
func test_torre_asedio_visible_y_activa_en_tutorial() -> void:
	# Arrange & Act
	var nivel := _cargar_nivel()

	# Assert
	var torre := nivel.get_node_or_null("TorreAsedioTutorial")
	assert_not_null(torre, "Debe existir TorreAsedioTutorial")
	assert_true(torre.visible, "Debe estar visible como fondo")
	assert_true(bool(torre.get("torre_activa")), "Debe quedar activada")


## 2. Tiene selector de capas y queda visible en frente/medio/fondo.
func test_torre_asedio_selector_capas_en_tutorial() -> void:
	# Arrange & Act
	var nivel := _cargar_nivel()

	# Assert
	var torre := nivel.get_node_or_null("TorreAsedioTutorial")
	assert_not_null(torre, "Debe existir TorreAsedioTutorial")
	assert_eq(int(torre.get("capa_visual")), 7, "Capa 7: visible en frente, medio y fondo")
	var malla: MeshInstance3D = null
	for m in torre.find_children("*", "MeshInstance3D", true, false):
		malla = m as MeshInstance3D
		if malla != null:
			break
	assert_not_null(malla, "Debe tener malla del modelo")
	assert_eq(malla.layers, 7, "La capa debe aplicarse a las mallas")


## 3. Es decorativa: no se desplaza ni spawnea enemigos.
func test_torre_asedio_estatica_sin_spawns_en_tutorial() -> void:
	# Arrange
	var nivel := _cargar_nivel()
	var torre := nivel.get_node_or_null("TorreAsedioTutorial")
	assert_not_null(torre, "Debe existir TorreAsedioTutorial")
	var x_inicial: float = (torre as Node3D).global_position.x

	# Act: avanzar 2 segundos
	await get_tree().create_timer(2.0).timeout

	# Assert: quieta y sin hijos enemigos
	assert_almost_eq((torre as Node3D).global_position.x, x_inicial, 0.01, "No debe desplazarse")
	assert_eq(int(torre.get("max_enemigos_rampa")), 0, "Sin spawns para no interferir")
