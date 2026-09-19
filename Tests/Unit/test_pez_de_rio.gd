extends "res://addons/gut/test.gd"

## Tests unitarios para el pez de río 3D (PezDeRio) en el nivel del río.
## Valida instanciación, asignación de material con shader de deformación,
## activación tras el tiempo de espera, desplazamiento hacia la izquierda
## y desaparición al salir de pantalla.

const ESCENA_PEZ_DE_RIO_PATH: String = "res://Levels/Rio_En_Canoa_Con_Parallax/PezDeRio.tscn"
const MARGEN_FLOAT: float = 0.01


func test_instanciar_pez_de_rio_y_estructura() -> void:
	# Arrange & Act
	var packed := load(ESCENA_PEZ_DE_RIO_PATH) as PackedScene
	assert_not_null(packed, "La escena PezDeRio.tscn debe cargar correctamente")

	var pez: PezDeRio = packed.instantiate() as PezDeRio
	assert_not_null(pez, "Debe instanciarse como PezDeRio")
	add_child_autofree(pez)

	# Assert
	assert_not_null(pez.material_pez, "Debe tener un material_pez asignado")
	assert_true(pez.material_pez is ShaderMaterial, "material_pez debe ser un ShaderMaterial")
	var sm := pez.material_pez as ShaderMaterial
	assert_not_null(sm.shader, "El material debe tener un shader de deformación")
	assert_not_null(sm.get_shader_parameter("textura_pez"), "Debe tener asignada la textura del pez")


func test_orientacion_inicial_hacia_izquierda() -> void:
	# Arrange & Act
	var packed := load(ESCENA_PEZ_DE_RIO_PATH) as PackedScene
	var pez: PezDeRio = packed.instantiate() as PezDeRio
	add_child_autofree(pez)

	# Assert: La rotación Y debe ser -PI/2 (-90 grados) para que la cabeza (+Z) apunte a la izquierda (-X)
	assert_almost_eq(pez.rotation.y, -PI * 0.5, MARGEN_FLOAT, "El pez debe mirar hacia la izquierda (-X)")


func test_activacion_y_desplazamiento_hacia_izquierda() -> void:
	# Arrange
	var pez_scene := load(ESCENA_PEZ_DE_RIO_PATH) as PackedScene
	var pez: PezDeRio = pez_scene.instantiate() as PezDeRio
	pez.autoactivar = false
	add_child_autofree(pez)

	# Act 1: Antes de activar
	assert_false(pez.esta_activo(), "No debe estar activo antes de tiempo")
	assert_false(pez.visible, "Debe estar invisible antes de activarse")

	# Act 2: Activar
	pez.activar()
	assert_true(pez.esta_activo(), "Debe estar activo tras llamar activar()")
	assert_true(pez.visible, "Debe ser visible tras activarse")

	# Act 3: Simular avance de 1.0 segundo
	var x_inicial: float = pez.global_position.x
	pez._process(1.0)
	var x_final: float = pez.global_position.x

	# Assert: Debe desplazarse hacia la izquierda (X menor)
	assert_lt(x_final, x_inicial, "El pez debe avanzar hacia la izquierda")
	assert_almost_eq(x_inicial - x_final, pez.velocidad, MARGEN_FLOAT, "Debe avanzar según su velocidad")


func test_desaparicion_al_salir_de_escena() -> void:
	# Arrange
	var pez_scene := load(ESCENA_PEZ_DE_RIO_PATH) as PackedScene
	var pez: PezDeRio = pez_scene.instantiate() as PezDeRio
	pez.autoactivar = false
	pez.destruir_al_salir = false  ## Desactivar destrucción física en test para verificar estado
	add_child_autofree(pez)
	pez.activar()

	# Configuración por defecto: debe tener 4.0 segundos de nado adicional tras cruzar el margen
	assert_almost_eq(pez.tiempo_adicional_desaparicion, 4.0, MARGEN_FLOAT, "Debe tener 4.0s de tiempo adicional de desaparición")

	# Act 1: Forzar que quede a la izquierda de la cámara (fuera del margen)
	pez.global_position.x = -100.0
	pez._process(2.0)

	# Assert 1: A los 2 segundos (antes de 4s), NO debe desaparecer prematuramente
	assert_true(pez.esta_activo(), "Debe continuar activo durante los primeros 4 segundos de gracia")
	assert_true(pez.visible, "Debe continuar visible durante los primeros 4 segundos de gracia")
	assert_almost_eq(pez.obtener_tiempo_fuera_pantalla(), 2.0, MARGEN_FLOAT, "Debe acumular 2.0s fuera de margen")

	# Act 2: Avanzar 2.1 segundos adicionales (total 4.1s >= 4.0s)
	pez._process(2.1)

	# Assert 2: Al superar los 4 segundos adicionales, ahora sí debe desaparecer para ahorrar recursos
	assert_false(pez.esta_activo(), "Debe desactivarse 4 segundos después de cruzar el margen")
	assert_false(pez.visible, "Debe ocultarse 4 segundos después de cruzar el margen")


func test_peces_de_rio_en_escena_rio() -> void:
	# Arrange & Act: Usar SceneState para validar la presencia y configuración en la escena
	# sin instanciar componentes ajenos pesados (Player, Azulina, etc.) que emiten warnings en GUT
	var packed := load("res://Levels/Rio en canoa con paralax.tscn") as PackedScene
	assert_not_null(packed, "La escena del río debe cargar correctamente")
	var state: SceneState = packed.get_state()
	assert_not_null(state, "El estado de la escena debe existir")

	var pez1_idx: int = -1
	var pez2_idx: int = -1
	for i in range(state.get_node_count()):
		var n_name: String = state.get_node_name(i)
		if n_name == "PezDeRio":
			pez1_idx = i
		elif n_name == "PezDeRio2":
			pez2_idx = i

	assert_ne(pez1_idx, -1, "Debe existir PezDeRio en la escena del río")
	assert_ne(pez2_idx, -1, "Debe existir PezDeRio2 en la escena del río")

	var obtener_propiedad = func(node_idx: int, prop_name: String) -> Variant:
		for p in range(state.get_node_property_count(node_idx)):
			if state.get_node_property_name(node_idx, p) == prop_name:
				return state.get_node_property_value(node_idx, p)
		return null

	# Tiempo de espera configurado (1.0s para PezDeRio)
	var t_esp1: Variant = obtener_propiedad.call(pez1_idx, "tiempo_espera_activacion")
	var t_esp2: Variant = obtener_propiedad.call(pez2_idx, "tiempo_espera_activacion")
	var val_t1: float = float(t_esp1) if t_esp1 != null else 1.0
	var val_t2: float = float(t_esp2) if t_esp2 != null else 1.0
	assert_almost_eq(val_t1, 1.0, MARGEN_FLOAT, "PezDeRio debe activarse a 1 segundo")
	assert_gt(val_t2, 0.9, "PezDeRio2 debe tener tiempo de activación")

	# Orientación hacia la izquierda (-PI/2)
	var rot1: Variant = obtener_propiedad.call(pez1_idx, "rotation")
	var rot2: Variant = obtener_propiedad.call(pez2_idx, "rotation")
	var r1_y: float = (rot1 as Vector3).y if rot1 != null else -PI * 0.5
	var r2_y: float = (rot2 as Vector3).y if rot2 != null else -PI * 0.5
	assert_almost_eq(r1_y, -PI * 0.5, MARGEN_FLOAT, "PezDeRio debe mirar a la izquierda")
	assert_almost_eq(r2_y, -PI * 0.5, MARGEN_FLOAT, "PezDeRio2 debe mirar a la izquierda")

	# Altura bajo la superficie del agua (Y entre -1.0 y -0.15 para verse parcialmente sumergido)
	var pos1: Variant = obtener_propiedad.call(pez1_idx, "position")
	var pos2: Variant = obtener_propiedad.call(pez2_idx, "position")
	var p1_y: float = (pos1 as Vector3).y if pos1 != null else -0.32
	var p2_y: float = (pos2 as Vector3).y if pos2 != null else -0.38
	assert_between(p1_y, -1.0, -0.15, "PezDeRio debe estar en cota de agua para verse parcialmente")
	assert_between(p2_y, -1.0, -0.15, "PezDeRio2 debe estar en cota de agua para verse parcialmente")

