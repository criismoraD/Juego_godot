extends "res://addons/gut/test.gd"

## Tests unitarios para el cañón destruido volador y la detonación de debug con tecla X:
## - Instanciación con modelo GLB y material texturizado propio.
## - Físicas de vuelo acrobático 3D (gravedad, desplazamiento y rotación multiaxial).
## - Detección de impacto en agua, emisión de señal, detención y hundimiento.
## - Lanzamiento al sustituir por modelo destruido en JefeSubmarinoRio.
## - Activación inmediata de la destrucción mediante la función explotar_debug() y la tecla X.

const SCRIPT_CANON_VOLADOR: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/CanonDestruidoVolador.gd")
const SCRIPT_JEFE_SUBMARINO: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/JefeSubmarinoRio.gd")

var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestCanonVolador"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	for n: Node in get_tree().root.get_children():
		if n.get_script() == SCRIPT_CANON_VOLADOR or n.get_script() == SCRIPT_JEFE_SUBMARINO:
			n.free()


# ==============================================================================
# TESTS DE CANON DESTRUIDO VOLADOR
# ==============================================================================

func test_canon_destruido_volador_instancia_con_modelo_y_material() -> void:
	# Arrange & Act
	var canon: Node3D = SCRIPT_CANON_VOLADOR.new() as Node3D
	_root_test.add_child(canon)

	# Assert
	assert_not_null(canon, "Debe instanciar CanonDestruidoVolador")
	var modelo: Node3D = canon.call("obtener_modelo_instancia") as Node3D
	assert_not_null(modelo, "Debe instanciar el modelo 3D del cañón destruido")

	var mallas: Array = modelo.find_children("*", "MeshInstance3D", true, false)
	assert_gt(mallas.size(), 0, "Debe contener al menos una MeshInstance3D")
	var mi := mallas[0] as MeshInstance3D
	assert_not_null(mi.material_override, "La malla debe tener material_override asignado")
	var mat := mi.material_override as StandardMaterial3D
	assert_not_null(mat, "El material debe ser StandardMaterial3D")
	assert_not_null(mat.albedo_texture, "El material debe tener albedo_texture asignada")
	assert_true("Cañon destruido(3K)_D" in mat.albedo_texture.resource_path, "Debe usar la textura del cañón destruido")


func test_tuerca_destruida_volador_instancia_con_malla_y_material() -> void:
	# Arrange & Act
	var tuerca: Node3D = SCRIPT_CANON_VOLADOR.new() as Node3D
	tuerca.set("tipo_pieza", 1)  # TipoPieza.TUERCA
	_root_test.add_child(tuerca)

	# Assert
	assert_not_null(tuerca, "Debe instanciar la tuerca voladora")
	var modelo: Node3D = tuerca.call("obtener_modelo_instancia") as Node3D
	assert_not_null(modelo, "Debe poseer nodo modelo para la tuerca")
	assert_true(modelo is MeshInstance3D, "El modelo de la tuerca debe ser un MeshInstance3D")
	var mi := modelo as MeshInstance3D
	assert_not_null(mi.mesh, "Debe poseer una malla asignada")
	assert_not_null(mi.material_override, "Debe poseer material asignado")
	var mat := mi.material_override as StandardMaterial3D
	assert_not_null(mat.albedo_texture, "Debe tener textura asignada")
	assert_true("Cañon destruido" in mat.albedo_texture.resource_path, "Debe compartir la textura del cañón")


func test_canon_destruido_lanzar_inicia_vuelo_y_rotacion() -> void:
	# Arrange
	var canon: Node3D = SCRIPT_CANON_VOLADOR.new() as Node3D
	_root_test.add_child(canon)
	var pos_ini := Vector3(5.0, 2.0, -1.0)
	var impulso := Vector3(-3.0, 11.0, 1.5)

	# Act
	canon.call("lanzar", pos_ini, impulso, -0.3)

	# Assert
	assert_true(bool(canon.call("esta_volando")), "Debe estar en estado de vuelo")
	assert_false(bool(canon.call("esta_sumergido")), "No debe estar sumergido inicialmente")
	assert_eq(canon.global_position, pos_ini, "Debe colocarse en la posición inicial")
	var vel := canon.get("velocidad") as Vector3
	assert_eq(vel, impulso, "La velocidad debe coincidir con el impulso inicial")
	var vel_rot := canon.get("velocidad_rotacion") as Vector3
	assert_gt(vel_rot.length(), 0.0, "Debe poseer velocidad de rotación acrobática")


func test_canon_destruido_procesar_vuelo_aplica_gravedad_y_desplaza() -> void:
	# Arrange
	var canon: Node3D = SCRIPT_CANON_VOLADOR.new() as Node3D
	_root_test.add_child(canon)
	var pos_ini := Vector3(0.0, 10.0, 0.0)
	var impulso := Vector3(2.0, 8.0, 0.0)
	canon.call("lanzar", pos_ini, impulso, -0.3)

	# Act: Simular un paso de física
	var dt: float = 0.1
	canon.call("_physics_process", dt)

	# Assert
	var vel := canon.get("velocidad") as Vector3
	var grav: float = float(canon.get("gravedad"))
	assert_almost_eq(vel.y, impulso.y - grav * dt, 0.01, "La gravedad debe reducir la velocidad Y")
	assert_gt(canon.global_position.x, pos_ini.x, "La posición X debe haber avanzado")


func test_canon_destruido_impacto_en_agua_activa_sumergido_y_emite_senal() -> void:
	# Arrange
	var canon: Node3D = SCRIPT_CANON_VOLADOR.new() as Node3D
	_root_test.add_child(canon)
	var cota_agua: float = -0.3
	canon.call("lanzar", Vector3(0.0, 0.0, 0.0), Vector3(0.0, -5.0, 0.0), cota_agua)

	watch_signals(canon)

	# Act: Ejecutar física con posición que cruza o toca el agua
	canon.global_position.y = cota_agua - 0.05
	canon.call("_physics_process", 0.01)

	# Assert
	assert_true(bool(canon.call("esta_sumergido")), "Debe pasar al estado sumergido")
	assert_false(bool(canon.call("esta_volando")), "Ya no debe estar volando")
	assert_signal_emitted(canon, "cayo_al_agua", "Debe emitir la señal cayo_al_agua")
	assert_almost_eq(canon.global_position.y, cota_agua, 0.001, "La posición Y debe fijarse en la superficie del agua")


# ==============================================================================
# TESTS DE INTEGRACIÓN CON JEFE SUBMARINO
# ==============================================================================

func test_jefe_submarino_lanzar_canon_al_destruirse() -> void:
	# Arrange
	var jefe: Node3D = SCRIPT_JEFE_SUBMARINO.new() as Node3D
	_root_test.add_child(jefe)
	assert_false(bool(jefe.get("_canon_destruido_lanzado")), "Inicialmente no se ha lanzado")

	# Act: Ejecutar sustitución de modelo destruido (lo que ocurre en la primera explosión)
	jefe.call("_sustituir_por_modelo_destruido")

	# Assert
	assert_true(bool(jefe.get("_canon_destruido_lanzado")), "Debe marcarse como lanzado")
	var canones: Array = _root_test.find_children("*", "CanonDestruidoVolador", true, false)
	assert_eq(canones.size(), 2, "Deben haberse instanciado exactamente 2 piezas voladoras (cañón y tuerca) en la escena")

	var tiene_canon: bool = false
	var tiene_tuerca: bool = false
	for p in canones:
		var tipo: int = int(p.get("tipo_pieza"))
		if tipo == 0:
			tiene_canon = true
		elif tipo == 1:
			tiene_tuerca = true
	assert_true(tiene_canon, "Una de las piezas debe ser el cañón (TipoPieza.CANON)")
	assert_true(tiene_tuerca, "Una de las piezas debe ser la tuerca/rueda (TipoPieza.TUERCA)")


func test_jefe_submarino_explotar_debug_ejecuta_destruccion() -> void:
	# Arrange
	var jefe: Node3D = SCRIPT_JEFE_SUBMARINO.new() as Node3D
	_root_test.add_child(jefe)
	# Submarino sumergido inicialmente
	jefe.set("current_state", 0)  # State.SUMERGIDO

	# Act: Disparar detonación de depuración
	jefe.call("explotar_debug")

	# Assert
	assert_eq(int(jefe.get("vida_actual_jefe")), 0, "La vida del jefe debe quedar en 0")
	assert_true(bool(jefe.get("_jefe_muerto")), "El jefe debe estar marcado como muerto")
	assert_eq(int(jefe.get("current_state")), 5, "Debe pasar al estado SUMERGIENDOSE (5)")


func test_jefe_submarino_tecla_x_activa_explotar_debug() -> void:
	# Arrange
	var jefe: Node3D = SCRIPT_JEFE_SUBMARINO.new() as Node3D
	_root_test.add_child(jefe)
	assert_false(bool(jefe.get("_jefe_muerto")), "Inicialmente no está muerto")

	# Act: Simular pulsación de tecla X
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_X
	event.physical_keycode = KEY_X
	jefe.call("_unhandled_input", event)

	# Assert
	assert_true(bool(jefe.get("_jefe_muerto")), "La tecla X debe detonar la muerte del jefe")
	assert_eq(int(jefe.get("vida_actual_jefe")), 0, "La vida debe ser 0")


# ==============================================================================
# TESTS DE SPLASH AZULINA COMPLETO (CAÑÓN Y TUERCA UN POCO MENORES)
# ==============================================================================

func test_canon_splash_azulina_completo_un_poco_menor() -> void:
	# Arrange: cañón con valores por defecto
	var canon: Node3D = SCRIPT_CANON_VOLADOR.new() as Node3D
	_root_test.add_child(canon)

	# Act: generar el splash de impacto en agua
	var splash: Node3D = canon.call("_generar_ondas_agua") as Node3D

	# Assert: existe y es un poco menor que el anterior (0.65)
	assert_not_null(splash, "Debe generarse el splash del cañón")
	assert_almost_eq(splash.scale.x, 0.5, 0.001, "El splash del cañón debe ser 0.5 (un poco menor)")
	assert_almost_eq(splash.scale.y, 0.5, 0.001, "Escala uniforme en Y")
	assert_almost_eq(splash.scale.z, 0.5, 0.001, "Escala uniforme en Z")

	# Assert: efecto completo estilo Azulina (todas las capas visibles, sin recortes)
	var capas: Array = splash.get("vfx_layers") as Array
	assert_gt(capas.size(), 2, "El splash completo debe tener más de 2 capas")
	for capa in capas:
		assert_true((capa as Node3D).visible, "Todas las capas del splash deben estar visibles")


func test_tuerca_splash_menor_que_canon_y_completo() -> void:
	# Arrange: tuerca con valores por defecto
	var tuerca: Node3D = SCRIPT_CANON_VOLADOR.new() as Node3D
	tuerca.set("tipo_pieza", 1)  # TipoPieza.TUERCA
	_root_test.add_child(tuerca)

	# Act: generar el splash de impacto en agua
	var splash: Node3D = tuerca.call("_generar_ondas_agua") as Node3D

	# Assert: más pequeño que el del cañón y completo
	assert_not_null(splash, "Debe generarse el splash de la tuerca")
	assert_almost_eq(splash.scale.x, 0.3, 0.001, "El splash de la tuerca debe ser 0.3")
	assert_lt(splash.scale.x, 0.5, "La tuerca debe salpicar menos que el cañón")
	var capas: Array = splash.get("vfx_layers") as Array
	assert_gt(capas.size(), 2, "El splash completo debe tener más de 2 capas")
	for capa in capas:
		assert_true((capa as Node3D).visible, "Todas las capas del splash deben estar visibles")
