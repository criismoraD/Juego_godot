extends "res://addons/gut/test.gd"

## Tests unitarios para validar que Pino2D respeta la altura manual
## configurada en el editor para evitar que se vea plano y uniforme.

const ESCENA_PINO_PATH: String = "res://Levels/Rio_En_Canoa_Con_Parallax/Pino2D.tscn"
const SCRIPT_PINO: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/Pino2D.gd")
const MARGEN_FLOAT: float = 0.01


func test_pino_2d_respeta_altura_manual_al_iniciar() -> void:
	# Arrange
	var packed := load(ESCENA_PINO_PATH) as PackedScene
	assert_not_null(packed, "La escena Pino2D.tscn debe cargar correctamente")

	var pino: Node3D = packed.instantiate() as Node3D
	pino.position.y = 1.453
	pino.position.z = -80.0

	# Act: Iniciar en el árbol de escena
	add_child_autofree(pino)

	# Assert: No debe ser aplanado por _asentar()
	assert_almost_eq(pino.position.y, 1.453, MARGEN_FLOAT, "Debe respetar la altura Y manual en _ready()")
	assert_almost_eq(pino.call("obtener_altura_original"), 1.453, MARGEN_FLOAT, "Debe registrar la altura original")


func test_pino_2d_diferentes_alturas_no_se_aplanan() -> void:
	# Arrange: Dos pinos ordenados manualmente a diferentes cotas Y
	var packed := load(ESCENA_PINO_PATH) as PackedScene
	var pino_alto: Node3D = packed.instantiate() as Node3D
	var pino_bajo: Node3D = packed.instantiate() as Node3D

	pino_alto.position.y = 1.405
	pino_bajo.position.y = 0.550

	# Act
	add_child_autofree(pino_alto)
	add_child_autofree(pino_bajo)

	# Assert: Cada uno debe conservar su cota manual respectiva
	assert_almost_eq(pino_alto.position.y, 1.405, MARGEN_FLOAT, "Pino alto debe conservar 1.405m")
	assert_almost_eq(pino_bajo.position.y, 0.550, MARGEN_FLOAT, "Pino bajo debe conservar 0.550m")
	assert_gt(pino_alto.position.y - pino_bajo.position.y, 0.5, "Los pinos no deben aplanarse a la misma altura")


func test_pino_2d_conserva_altura_manual_al_reciclar() -> void:
	# Arrange
	var packed := load(ESCENA_PINO_PATH) as PackedScene
	var pino: Node3D = packed.instantiate() as Node3D
	var altura_deseada: float = 1.256
	pino.position = Vector3(0.0, altura_deseada, -80.0)
	add_child_autofree(pino)

	# Act: Forzar que quede detrás de la cámara y llamar a reciclaje
	pino.global_position.x = -150.0
	pino.call("_reciclar_si_detras")

	# Assert: Al reaparecer delante, su cota Y debe seguir siendo la manual original
	assert_almost_eq(pino.global_position.y, altura_deseada, MARGEN_FLOAT, "Debe conservar la altura original tras reciclar")


func test_pinos_en_escena_rio_tienen_alturas_variadas() -> void:
	# Arrange & Act: Usar SceneState para comprobar las alturas guardadas por el usuario
	var packed := load("res://Levels/Rio en canoa con paralax.tscn") as PackedScene
	assert_not_null(packed, "La escena del río debe cargar correctamente")
	var state: SceneState = packed.get_state()
	assert_not_null(state, "El estado de la escena debe existir")

	var alturas_y: Array[float] = []
	for i in range(state.get_node_count()):
		var n_name: String = state.get_node_name(i)
		if n_name.begins_with("Pino2D"):
			for p in range(state.get_node_property_count(i)):
				var prop_name: String = state.get_node_property_name(i, p)
				if prop_name == "transform":
					var transf: Transform3D = state.get_node_property_value(i, p) as Transform3D
					alturas_y.append(transf.origin.y)
				elif prop_name == "position":
					var pos: Vector3 = state.get_node_property_value(i, p) as Vector3
					alturas_y.append(pos.y)

	assert_gt(alturas_y.size(), 5, "Deben existir múltiples pinos en la escena del río")

	var min_y: float = INF
	var max_y: float = -INF
	for y in alturas_y:
		if y < min_y:
			min_y = y
		if y > max_y:
			max_y = y

	# Assert: La separación entre el pino más bajo y el más alto debe ser orgánica (> 0.5m)
	assert_gt(max_y - min_y, 0.5, "Los pinos en la escena tienen alturas variadas configuradas por el usuario")
