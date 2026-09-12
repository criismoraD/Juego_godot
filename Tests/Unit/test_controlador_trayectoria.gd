extends "res://addons/gut/test.gd"
## Tests unitarios del controlador de trayectorias de embarcaciones.
## Verifica orden de puntos X, sincronización en Y/Z, ocultamiento de cubos en juego y spawn dinámico.

const ESCENA_TRAYECTORIA := preload("res://System/Ambiente/TrayectoriaEmbarcaciones.tscn")
const SCRIPT_CONTROLADOR := preload("res://System/Ambiente/ControladorTrayectoriaEmbarcaciones.gd")
const MARGEN_FLOAT: float = 0.0001


func test_instanciar_escena_trayectoria() -> void:
	# Arrange & Act
	var controlador := ESCENA_TRAYECTORIA.instantiate() as ControladorTrayectoriaEmbarcaciones

	# Assert
	assert_not_null(controlador, "La escena debe instanciar un ControladorTrayectoriaEmbarcaciones")
	assert_not_null(controlador.punto_verde_fuerte, "Debe tener asignado el nodo verde fuerte")
	assert_not_null(controlador.punto_verde_suave, "Debe tener asignado el nodo verde suave")
	assert_not_null(controlador.punto_rojo_suave, "Debe tener asignado el nodo rojo suave")
	assert_not_null(controlador.punto_rojo_fuerte, "Debe tener asignado el nodo rojo fuerte")

	controlador.free()


func test_orden_puntos_de_izquierda_a_derecha() -> void:
	# Arrange
	var controlador := ESCENA_TRAYECTORIA.instantiate() as ControladorTrayectoriaEmbarcaciones

	# Act
	var x1: float = controlador.punto_verde_fuerte.position.x
	var x2: float = controlador.punto_verde_suave.position.x
	var x3: float = controlador.punto_rojo_suave.position.x
	var x4: float = controlador.punto_rojo_fuerte.position.x

	# Assert: Debe cumplirse orden estricto de izquierda a derecha
	assert_true(x1 < x2, "Verde fuerte (spawn canoa) debe estar a la izquierda de Verde suave (parada canoa)")
	assert_true(x2 < x3, "Verde suave debe estar a la izquierda de Rojo suave")
	assert_true(x3 < x4, "Rojo suave (parada balsa) debe estar a la izquierda de Rojo fuerte (spawn balsa)")

	controlador.free()


func test_mover_cualquier_cubo_en_y_o_z_sincroniza_todos_los_demas() -> void:
	# Arrange
	var controlador := ESCENA_TRAYECTORIA.instantiate() as ControladorTrayectoriaEmbarcaciones
	# Simular entorno de editor
	controlador._posiciones_iniciadas = true
	controlador._ultimo_y = 0.0
	controlador._ultimo_z = 0.0

	# Act: El usuario mueve el punto rojo fuerte en Y a 1.8 y en Z a 3.4
	controlador.punto_rojo_fuerte.position.y = 1.8
	controlador.punto_rojo_fuerte.position.z = 3.4
	controlador._process(0.016)

	# Assert: Todos los 4 cubos deben tener exactamente Y = 1.8 y Z = 3.4
	assert_almost_eq(controlador.punto_verde_fuerte.position.y, 1.8, MARGEN_FLOAT, "Verde fuerte debe seguir en Y")
	assert_almost_eq(controlador.punto_verde_suave.position.y, 1.8, MARGEN_FLOAT, "Verde suave debe seguir en Y")
	assert_almost_eq(controlador.punto_rojo_suave.position.y, 1.8, MARGEN_FLOAT, "Rojo suave debe seguir en Y")
	assert_almost_eq(controlador.punto_rojo_fuerte.position.y, 1.8, MARGEN_FLOAT, "Rojo fuerte debe mantener Y")

	assert_almost_eq(controlador.punto_verde_fuerte.position.z, 3.4, MARGEN_FLOAT, "Verde fuerte debe seguir en Z")
	assert_almost_eq(controlador.punto_verde_suave.position.z, 3.4, MARGEN_FLOAT, "Verde suave debe seguir en Z")
	assert_almost_eq(controlador.punto_rojo_suave.position.z, 3.4, MARGEN_FLOAT, "Rojo suave debe seguir en Z")
	assert_almost_eq(controlador.punto_rojo_fuerte.position.z, 3.4, MARGEN_FLOAT, "Rojo fuerte debe mantener Z")

	controlador.free()


func test_mover_cubo_en_x_no_afecta_la_x_de_los_demas() -> void:
	# Arrange
	var controlador := ESCENA_TRAYECTORIA.instantiate() as ControladorTrayectoriaEmbarcaciones
	var x_vf_original: float = controlador.punto_verde_fuerte.position.x
	var x_rs_original: float = controlador.punto_rojo_suave.position.x
	var x_rf_original: float = controlador.punto_rojo_fuerte.position.x

	# Act: Solo se mueve el punto verde suave en X
	controlador.punto_verde_suave.position.x = -4.5
	controlador._process(0.016)

	# Assert: El punto verde suave cambió, los otros conservan su X intacto
	assert_almost_eq(controlador.punto_verde_suave.position.x, -4.5, MARGEN_FLOAT)
	assert_almost_eq(controlador.punto_verde_fuerte.position.x, x_vf_original, MARGEN_FLOAT)
	assert_almost_eq(controlador.punto_rojo_suave.position.x, x_rs_original, MARGEN_FLOAT)
	assert_almost_eq(controlador.punto_rojo_fuerte.position.x, x_rf_original, MARGEN_FLOAT)

	controlador.free()


func test_cubos_se_ocultan_en_tiempo_de_juego() -> void:
	# Arrange
	var controlador := ESCENA_TRAYECTORIA.instantiate() as ControladorTrayectoriaEmbarcaciones
	controlador.mostrar_cubos_en_juego = false

	# Act
	controlador._ocultar_todos_los_cubos()

	# Assert: Los 4 puntos deben quedar con visible = false
	var puntos: Array[Node3D] = controlador._obtener_lista_puntos()
	for p in puntos:
		assert_false(p.visible, "Los cubos deben ser invisibles en juego")

	controlador.free()


func test_spawnear_canoa_nace_en_verde_fuerte_y_navega_a_verde_suave() -> void:
	# Arrange
	var controlador := ESCENA_TRAYECTORIA.instantiate() as ControladorTrayectoriaEmbarcaciones

	# Act
	var canoa: CanoaAliada = controlador.spawnear_canoa()

	# Assert
	assert_not_null(canoa, "Debe instanciar una CanoaAliada")
	assert_almost_eq(canoa.obtener_posicion_base().x, controlador.obtener_posicion_punto(controlador.punto_verde_fuerte).x, MARGEN_FLOAT, "Debe nacer en Verde Fuerte")
	assert_true(canoa.esta_navegando(), "Debe comenzar a navegar")

	controlador.free()


func test_spawnear_balsa_nace_en_rojo_fuerte_y_navega_a_rojo_suave() -> void:
	# Arrange
	var controlador := ESCENA_TRAYECTORIA.instantiate() as ControladorTrayectoriaEmbarcaciones

	# Act
	var balsa: BalsaPirata = controlador.spawnear_balsa()

	# Assert
	assert_not_null(balsa, "Debe instanciar una BalsaPirata")
	assert_almost_eq(balsa.obtener_posicion_base().x, controlador.obtener_posicion_punto(controlador.punto_rojo_fuerte).x, MARGEN_FLOAT, "Debe nacer en Rojo Fuerte")
	assert_true(balsa.esta_navegando(), "Debe comenzar a navegar")

	controlador.free()


func test_destruir_balsa_enemiga_destruye_la_balsa_instanciada() -> void:
	# Arrange
	var controlador := ESCENA_TRAYECTORIA.instantiate() as ControladorTrayectoriaEmbarcaciones
	add_child_autofree(controlador)
	var balsa: BalsaPirata = controlador.spawnear_balsa()
	assert_false(balsa.esta_destruida(), "La balsa debe nacer sin destruir")

	# Act
	controlador.destruir_balsa_enemiga()

	# Assert
	assert_true(balsa.esta_destruida(), "destruir_balsa_enemiga debe activar destruir_balsa en la balsa")


func test_destruir_balsa_enemiga_sin_balsa_es_seguro() -> void:
	# Arrange
	var controlador := ESCENA_TRAYECTORIA.instantiate() as ControladorTrayectoriaEmbarcaciones
	add_child_autofree(controlador)

	# Act & Assert (no debe arrojar errores si no hay balsa)
	controlador.destruir_balsa_enemiga()
	pass_test("Llamar a destruir_balsa_enemiga sin balsa es seguro")

