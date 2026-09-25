extends "res://addons/gut/test.gd"

## Tests unitarios para el EscombroMaderoVolador y su expulsión al destruir el Barco Combate Pirata.
## Cubren:
##   - Instanciación y asignación de mallas/materiales para las 6 piezas.
##   - Cinemática parabólica, gravedad y rotación 3D acrobática.
##   - Impacto con el agua, emisión de señal, generación de ondas (splash_vfx) y sumersión.
##   - Integración con BarcoCombatePirata (lanzamiento de los 6 escombros).

const SCRIPT_ESCOMBRO: Script = preload("res://Entities/Ambiente_Barco_Combate_Pirata/EscombroMaderoVolador.gd")
const BARCO_SCENE: PackedScene = preload("res://Entities/Ambiente_Barco_Combate_Pirata/BarcoCombatePirata.tscn")
const MARGEN_FLOAT: float = 0.001

var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestEscombro"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	for n: Node in get_tree().root.get_children():
		if n.get_script() == SCRIPT_ESCOMBRO or n is BarcoCombatePirata:
			n.free()


func _crear_escombro(indice: int = 0) -> Node3D:
	var escombro: Node3D = SCRIPT_ESCOMBRO.new() as Node3D
	escombro.set("indice_pieza", indice)
	_root_test.add_child(escombro)
	return escombro


# ==============================================================================
# TESTS DE INSTANCIACIÓN Y PIEZAS
# ==============================================================================

func test_escombro_instancia_las_6_piezas_con_mallas_validas() -> void:
	# Assert: Las 6 piezas del modelo cargado deben existir y tener malla
	assert_eq(SCRIPT_ESCOMBRO.MESHES_ESCOMBROS.size(), 6, "Deben existir exactamente 6 mallas de escombros")

	for i in range(6):
		var escombro: Node3D = _crear_escombro(i)
		assert_not_null(escombro, "Escombro %d debe instanciarse" % i)
		assert_eq(int(escombro.call("obtener_indice_pieza")), i, "El índice debe coincidir con la pieza solicitada")

		var mesh_instance := escombro.find_child("MeshEscombro_%d" % i, true, false) as MeshInstance3D
		assert_not_null(mesh_instance, "Debe existir MeshInstance3D para pieza %d" % i)
		assert_not_null(mesh_instance.mesh, "La pieza %d debe tener un Mesh válido asignado" % i)
		assert_gt(mesh_instance.mesh.get_surface_count(), 0, "La pieza %d debe tener al menos 1 superficie" % i)
		assert_eq(mesh_instance.material_override, SCRIPT_ESCOMBRO.MATERIAL_ESCOMBROS, "Debe tener asignado MATERIAL_ESCOMBROS")


func test_escombro_material_con_textura_difusa() -> void:
	# Arrange & Act
	var mat := SCRIPT_ESCOMBRO.MATERIAL_ESCOMBROS as StandardMaterial3D

	# Assert
	assert_not_null(mat, "MATERIAL_ESCOMBROS debe estar cargado")
	assert_not_null(mat.albedo_texture, "El material debe tener albedo_texture asignado")
	assert_true("maderos escombros_D" in mat.albedo_texture.resource_path, "Debe usar la textura maderos escombros_D.jpg")


# ==============================================================================
# TESTS DE CINEMÁTICA Y FÍSICA
# ==============================================================================

func test_escombro_lanzamiento_inicia_vuelo_y_movimiento() -> void:
	# Arrange
	var escombro: Node3D = _crear_escombro(0)
	var pos_inicial := Vector3(5.0, 3.0, -1.0)
	var impulso := Vector3(3.0, 9.0, 0.5)

	# Act
	escombro.call("lanzar", pos_inicial, impulso, -0.3, 1, 0)

	# Assert
	assert_true(bool(escombro.call("esta_volando")), "Debe encontrarse en estado volando")
	assert_false(bool(escombro.call("esta_sumergido")), "No debe estar sumergido al inicio")
	assert_eq(escombro.global_position, pos_inicial, "La posición debe ser la inicial")
	assert_eq(escombro.get("velocidad"), impulso, "La velocidad debe coincidir con el impulso")


func test_escombro_gravedad_y_trayectoria_parabolica() -> void:
	# Arrange
	var escombro: Node3D = _crear_escombro(2)
	var pos_inicial := Vector3(0.0, 5.0, 0.0)
	var impulso := Vector3(2.0, 8.0, 0.0)
	escombro.call("lanzar", pos_inicial, impulso, -10.0, 1, 2)

	# Act: Simular un paso de física de 0.5s
	var delta: float = 0.5
	escombro._physics_process(delta)

	# Assert
	var vel: Vector3 = escombro.get("velocidad") as Vector3
	# vy esperada = 8.0 - 12.0 * 0.5 = 2.0
	assert_almost_eq(vel.y, 2.0, MARGEN_FLOAT, "La gravedad debe restar velocidad vertical")
	# pos.x esperada = 0.0 + 2.0 * 0.5 = 1.0
	assert_almost_eq(escombro.global_position.x, 1.0, MARGEN_FLOAT, "La posición horizontal debe avanzar linealmente")
	# pos.y esperada = 5.0 + 2.0 * 0.5 = 6.0
	assert_almost_eq(escombro.global_position.y, 6.0, MARGEN_FLOAT, "La posición vertical debe seguir la parábola")


# ==============================================================================
# TESTS DE ENTRADA AL AGUA Y ONDAS
# ==============================================================================

func test_escombro_impacto_agua_emite_senal_y_cambia_a_sumergido() -> void:
	# Arrange
	var escombro: Node3D = _crear_escombro(3)
	watch_signals(escombro)
	var nivel_agua: float = -0.3
	escombro.call("lanzar", Vector3(1.0, 0.1, 0.0), Vector3(0.0, -3.0, 0.0), nivel_agua, 1, 3)

	# Act: Paso que cruza el agua
	escombro._physics_process(0.2)

	# Assert
	assert_signal_emitted(escombro, "cayo_al_agua", "Debe emitir la señal cayo_al_agua")
	assert_true(bool(escombro.call("esta_sumergido")), "Debe pasar al estado sumergido")
	assert_false(bool(escombro.call("esta_volando")), "Ya no debe estar volando")
	assert_almost_eq(escombro.global_position.y, nivel_agua, MARGEN_FLOAT, "Debe alinearse con la superficie del agua")


func test_escombro_impacto_agua_genera_ondas_splash() -> void:
	# Arrange
	var escombro: Node3D = _crear_escombro(4)
	var nivel_agua: float = -0.25
	escombro.call("lanzar", Vector3(0.0, 0.05, 0.0), Vector3(0.0, -2.0, 0.0), nivel_agua, 1, 4)

	# Act
	escombro._physics_process(0.1)

	# Assert: Debe instanciar splash_vfx en la escena
	var ondas_encontradas: int = 0
	for c in _root_test.find_children("*", "Node3D", true, false):
		var n := c as Node
		if n and "splash_vfx" in n.scene_file_path:
			ondas_encontradas += 1
			# Verificar que se configuró con escala pequeña y ondas activas
			var s := c as Node3D
			assert_almost_eq(s.scale.x, float(escombro.get("escala_splash")), MARGEN_FLOAT, "Escala de la onda debe coincidir con escala_splash")
			assert_almost_eq(s.global_position.y, nivel_agua, MARGEN_FLOAT, "La onda debe colocarse a nivel del agua")

	assert_gt(ondas_encontradas, 0, "Debe haberse instanciado el efecto de ondas en el agua")


# ==============================================================================
# TESTS DE INTEGRACIÓN CON BARCO COMBATE PIRATA
# ==============================================================================

func test_barco_combate_al_destruirse_expulsa_6_escombros() -> void:
	# Arrange
	var barco: BarcoCombatePirata = BARCO_SCENE.instantiate() as BarcoCombatePirata
	barco.position = Vector3(20.0, 0.0, -7.5)
	barco.activar_al_entrar_en_camara = false
	_root_test.add_child(barco)

	# Act: Destruir el barco
	barco.destruir_balsa()

	# Assert: Se deben haber lanzado exactamente 6 escombros
	var escombros: Array[Node3D] = barco.obtener_maderos_lanzados()
	assert_eq(escombros.size(), 6, "El barco de combate debe expulsar 6 piezas de escombros de madera")

	var indices_vistos := {}
	var cuenta_izquierda := 0
	var cuenta_derecha := 0

	for e in escombros:
		assert_not_null(e, "Cada instancia de escombro debe ser válida")
		assert_true(bool(e.call("esta_volando")), "Cada escombro debe iniciar en vuelo acrobático")
		var idx: int = int(e.call("obtener_indice_pieza"))
		indices_vistos[idx] = true

		var vel: Vector3 = e.get("velocidad") as Vector3
		if vel.x < 0.0:
			cuenta_izquierda += 1
		elif vel.x > 0.0:
			cuenta_derecha += 1

	# Verificar que salieron las 6 piezas diferentes (0 a 5)
	assert_eq(indices_vistos.size(), 6, "Deben haberse expulsado las 6 piezas distintas (0 a 5)")
	for i in range(6):
		assert_true(indices_vistos.has(i), "Debe incluir la pieza con índice %d" % i)

	# Verificar dispersión bidireccional (hacia la izquierda y hacia la derecha)
	assert_gt(cuenta_izquierda, 0, "Debe haber escombros saliendo hacia la izquierda")
	assert_gt(cuenta_derecha, 0, "Debe haber escombros saliendo hacia la derecha")
