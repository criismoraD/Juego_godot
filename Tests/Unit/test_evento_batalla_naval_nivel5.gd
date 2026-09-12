extends "res://addons/gut/test.gd"
## Tests unitarios para el evento de la batalla naval (embarcaciones de fondo).
## Verifica que solo se active durante el nivel 5 (oleada 5) y se desactive en otras oleadas.

const ESCENA_TRAYECTORIA := preload("res://System/Ambiente/TrayectoriaEmbarcaciones.tscn")
const SCRIPT_CONTROLADOR := preload("res://System/Ambiente/ControladorTrayectoriaEmbarcaciones.gd")


func test_controlador_no_spawnea_al_iniciar_por_defecto() -> void:
	# Arrange & Act
	var controlador := ESCENA_TRAYECTORIA.instantiate() as ControladorTrayectoriaEmbarcaciones
	add_child_autofree(controlador)

	# Assert
	assert_false(controlador.spawn_al_iniciar, "spawn_al_iniciar debe ser false por defecto")
	assert_false(controlador.esta_activo(), "No debe haber embarcaciones activas al inicio")
	assert_null(controlador.obtener_canoa(), "No debe existir canoa sin haber activado el evento")
	assert_null(controlador.obtener_balsa(), "No debe existir balsa sin haber activado el evento")


func test_spawnear_y_despawnear_ambas_embarcaciones() -> void:
	# Arrange
	var controlador := ESCENA_TRAYECTORIA.instantiate() as ControladorTrayectoriaEmbarcaciones
	add_child_autofree(controlador)

	# Act 1: Spawnear
	controlador.spawnear_ambas()

	# Assert 1
	assert_true(controlador.esta_activo(), "Debe reportar que el evento está activo tras spawnear")
	assert_not_null(controlador.obtener_canoa(), "La canoa debe existir")
	assert_not_null(controlador.obtener_balsa(), "La balsa debe existir")

	# Act 2: Despawnear
	controlador.despawnear_ambas()

	# Assert 2
	assert_false(controlador.esta_activo(), "Debe reportar que no está activo tras despawnear")
	assert_null(controlador.obtener_canoa(), "La referencia a canoa debe ser null")
	assert_null(controlador.obtener_balsa(), "La referencia a balsa debe ser null")


func test_despawnear_en_vacio_es_seguro() -> void:
	# Arrange
	var controlador := ESCENA_TRAYECTORIA.instantiate() as ControladorTrayectoriaEmbarcaciones
	add_child_autofree(controlador)

	# Act & Assert (Boundary/Edge case: despawnear sin haber spawneado)
	controlador.despawnear_ambas()
	assert_false(controlador.esta_activo(), "Despawnear en vacío no debe fallar y debe mantenerse inactivo")


func test_evento_batalla_naval_activacion_exclusiva_oleada_5() -> void:
	# Arrange
	var mock_nivel: Node3D = Node3D.new()
	add_child_autofree(mock_nivel)

	var controlador := ESCENA_TRAYECTORIA.instantiate() as ControladorTrayectoriaEmbarcaciones
	controlador.name = "TrayectoriaEmbarcaciones"
	mock_nivel.add_child(controlador)

	# Función simulada del contrato de activación de NIVEL01
	var simular_oleada := func(numero_oleada: int) -> void:
		if numero_oleada == 5:
			if not controlador.esta_activo():
				controlador.spawnear_ambas()
		else:
			controlador.despawnear_ambas()

	# Act & Assert: Oleadas 1 a 4 inactivas
	for oleada in [1, 2, 3, 4]:
		simular_oleada.call(oleada)
		assert_false(controlador.esta_activo(), "En oleada %d la batalla naval debe estar inactiva" % oleada)

	# Act & Assert: Oleada 5 activa
	simular_oleada.call(5)
	assert_true(controlador.esta_activo(), "En oleada 5 la batalla naval DEBE estar activa")
	assert_not_null(controlador.obtener_canoa(), "Canoa presente en oleada 5")
	assert_not_null(controlador.obtener_balsa(), "Balsa presente en oleada 5")

	# Act & Assert: Oleada 6 vuelve a desactivar
	simular_oleada.call(6)
	assert_false(controlador.esta_activo(), "Al pasar a oleada 6 la batalla naval debe desactivarse")
	assert_null(controlador.obtener_canoa(), "Canoa eliminada en oleada 6")
	assert_null(controlador.obtener_balsa(), "Balsa eliminada en oleada 6")


func test_fin_oleada_5_oculta_y_despawnea_canoa_aliada() -> void:
	# Arrange
	var controlador := ESCENA_TRAYECTORIA.instantiate() as ControladorTrayectoriaEmbarcaciones
	add_child_autofree(controlador)
	controlador.spawnear_ambas()
	var canoa := controlador.obtener_canoa()
	assert_not_null(canoa, "La canoa debe existir antes de finalizar la oleada 5")
	assert_true(canoa.is_in_group("canoas_aliadas"), "La canoa debe pertenecer al grupo canoas_aliadas")

	# Act: Al terminar la oleada 5, se oculta y despawnea la canoa aliada
	controlador.ocultar_o_despawnear_canoa()

	# Assert
	assert_null(controlador.obtener_canoa(), "La referencia en el controlador debe ser null")
	assert_false(canoa.visible, "La canoa no debe ser visible")
	assert_true(canoa.is_queued_for_deletion(), "La canoa debe estar en cola de destrucción")


func test_canoa_aliada_metodo_ocultar_y_desactivar() -> void:
	# Arrange
	var canoa: CanoaAliada = preload("res://Entities/Ambiente_Canoa_Aliada/CanoaAliada.tscn").instantiate() as CanoaAliada
	add_child_autofree(canoa)
	assert_true(canoa.visible, "Canoa visible inicialmente")

	# Act
	canoa.ocultar_y_desactivar()

	# Assert
	assert_false(canoa.visible, "La canoa debe volverse invisible")
	assert_false(canoa.esta_flotando(), "La flotación debe detenerse")
	assert_false(canoa.esta_navegando(), "La navegación debe detenerse")

