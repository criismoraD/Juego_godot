extends "res://addons/gut/test.gd"

## Tests de la batalla naval replicada en el río (cubos posicionables).

const ESCENA_RIO_PATH: String = "res://Levels/Rio en canoa con paralax.tscn"


func test_batalla_naval_rio_con_cubos_posicionables() -> void:
	# Arrange & Act
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	assert_not_null(packed, "La escena del río debe cargar")
	var nivel: Node3D = packed.instantiate() as Node3D
	assert_not_null(nivel, "La escena debe instanciarse")
	add_child_autofree(nivel)

	# Assert: controlador con sus 4 bloques posicionables
	var control := nivel.find_child("TrayectoriaEmbarcacionesRio", true, false) as ControladorTrayectoriaEmbarcaciones
	assert_not_null(control, "Debe existir la batalla naval en el río")
	for nombre in ["PuntoVerdeFuerte", "PuntoVerdeSuave", "PuntoRojoSuave", "PuntoRojoFuerte"]:
		assert_not_null(control.find_child(nombre, true, false), "Bloque posicionable: " + nombre)

	# Assert: sobre el agua tras la zona del barco y apagada por defecto
	assert_gt(control.global_position.x, 50.0, "La batalla queda pasada la zona del barco")
	assert_false(control.spawn_al_iniciar, "Apagada por defecto: se enciende desde el Inspector")


func test_batalla_naval_rio_arranca_por_camara() -> void:
	# Arrange: el nivel río no tiene oleadas; el nivel dispara por cercanía de cámara
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)
	assert_true(nivel.has_method("_procesar_activacion_batalla_naval"), "El nivel expone el arranque por cámara")
	assert_gt(float(nivel.get("distancia_activacion_batalla_naval")), 0.0, "Distancia de activación positiva")

	var control := nivel.find_child("TrayectoriaEmbarcacionesRio", true, false) as ControladorTrayectoriaEmbarcaciones
	var camara := nivel.find_child("CamaraPrincipal", true, false) as Camera3D
	assert_not_null(camara, "El nivel tiene cámara principal")
	assert_false(control.esta_activo(), "Apagada al inicio del nivel")

	# Act: acercar la cámara y procesar un frame de activación
	camara.global_position.x = control.global_position.x - 5.0
	nivel.call("_procesar_activacion_batalla_naval")

	# Assert: ambas embarcaciones en agua sin sistema de oleadas
	assert_true(control.esta_activo(), "La cámara cercana arranca la batalla")
	assert_true(control.tiene_embarcaciones_activas(), "Canoa y balsa navegando")
