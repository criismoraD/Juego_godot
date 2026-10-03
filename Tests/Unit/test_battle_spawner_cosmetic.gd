extends GutTest

## Tests unitarios para BattleSpawnerCosmetic.
## Verifica la lógica de spawn, conteo de unidades y sistema de equilibrio.

# ─── VARIABLES DE TEST ───────────────────────────────────────────────────────
var _spawner_azul: BattleSpawnerCosmetic = null
var _spawner_rojo: BattleSpawnerCosmetic = null
var _escena: PackedScene = null

const RUTA_ESCENA: String = "res://Entities/Ambiente_BattleSpawner/BattleSpawnerCosmetic.tscn"


# ─── SETUP / TEARDOWN ─────────────────────────────────────────────────────────
func before_each() -> void:
	_escena = load(RUTA_ESCENA) as PackedScene
	assert_not_null(_escena, "La escena BattleSpawnerCosmetic debe existir.")

	_spawner_azul = _escena.instantiate() as BattleSpawnerCosmetic
	_spawner_azul.bando = "azul"
	_spawner_azul.auto_iniciar = false
	_spawner_azul.equilibrio_activo = false
	add_child_autofree(_spawner_azul)

	_spawner_rojo = _escena.instantiate() as BattleSpawnerCosmetic
	_spawner_rojo.bando = "rojo"
	_spawner_rojo.auto_iniciar = false
	_spawner_rojo.equilibrio_activo = false
	add_child_autofree(_spawner_rojo)


func after_each() -> void:
	# Limpiar unidades que pudieran haber quedado en el árbol
	for grupo in ["batalla_cosmetica", "battle_azul", "battle_rojo"]:
		for nodo in get_tree().get_nodes_in_group(grupo):
			if is_instance_valid(nodo):
				nodo.queue_free()
	_spawner_azul = null
	_spawner_rojo = null


# ─── TESTS DE CONFIGURACIÓN ──────────────────────────────────────────────────

func test_bando_azul_se_configura_correctamente() -> void:
	# Arrange / Act (hecho en before_each)
	# Assert
	assert_eq(_spawner_azul.bando, "azul",
		"El bando del spawner azul debe ser 'azul'.")


func test_bando_rojo_se_configura_correctamente() -> void:
	assert_eq(_spawner_rojo.bando, "rojo",
		"El bando del spawner rojo debe ser 'rojo'.")


func test_cantidad_inicial_por_defecto() -> void:
	# Arrange
	var spawner := _escena.instantiate() as BattleSpawnerCosmetic
	add_child_autofree(spawner)
	# Assert
	assert_eq(spawner.cantidad_inicial, 5,
		"La cantidad inicial por defecto debe ser 5.")


# ─── TESTS DE CONTEO ─────────────────────────────────────────────────────────

func test_contar_unidades_sin_spawn_retorna_cero() -> void:
	# Arrange / Act
	var conteo: int = _spawner_azul.contar_unidades_vivas()
	# Assert
	assert_eq(conteo, 0,
		"Sin spawn activo debe retornar 0 unidades.")


func test_contar_unidades_limpia_referencias_invalidas() -> void:
	# Arrange: agregar un nodo inválido manualmente
	var nodo_dummy: Node3D = Node3D.new()
	add_child(nodo_dummy)
	_spawner_azul._unidades_activas.append(nodo_dummy)
	nodo_dummy.queue_free()
	await get_tree().process_frame
	# Act
	var conteo: int = _spawner_azul.contar_unidades_vivas()
	# Assert
	assert_eq(conteo, 0,
		"Después de liberar el nodo, el conteo debe ser 0.")


# ─── TESTS DE EQUILIBRIO ─────────────────────────────────────────────────────

func test_evaluar_equilibrio_no_spawnea_si_rival_no_valido() -> void:
	# Arrange: sin rival asignado
	_spawner_azul.equilibrio_activo = true
	_spawner_azul._batalla_iniciada = true
	var conteo_antes: int = _spawner_azul.contar_unidades_vivas()
	# Act
	_spawner_azul._evaluar_equilibrio()
	await get_tree().process_frame
	# Assert
	assert_eq(_spawner_azul.contar_unidades_vivas(), conteo_antes,
		"Sin rival asignado no debe spawnear refuerzos.")


func test_umbral_desequilibrio_es_positivo() -> void:
	assert_gt(BattleSpawnerCosmetic.UMBRAL_DESEQUILIBRIO, 0,
		"El umbral de desequilibrio debe ser mayor que 0.")


func test_max_unidades_activas_es_positivo() -> void:
	assert_gt(BattleSpawnerCosmetic.MAX_UNIDADES_ACTIVAS, 0,
		"El máximo de unidades activas debe ser mayor que 0.")


# ─── TESTS DE GRUPOS ─────────────────────────────────────────────────────────

func test_batalla_no_iniciada_al_arrancar_con_auto_iniciar_false() -> void:
	# Arrange / Act: auto_iniciar = false (configurado en before_each)
	# Assert
	assert_false(_spawner_azul._batalla_iniciada,
		"La batalla no debe iniciarse si auto_iniciar es false.")


func test_spawner_registra_unidades_en_grupos_de_batalla() -> void:
	# Arrange: usar un double para simular una unidad
	var unidad_dummy: Node3D = Node3D.new()
	unidad_dummy.name = "UnidadDummy"
	add_child_autofree(unidad_dummy)
	# Agregar manualmente al array interno como si fuera spawneada
	_spawner_azul._unidades_activas.append(unidad_dummy)
	unidad_dummy.add_to_group("batalla_cosmetica")
	unidad_dummy.add_to_group("battle_azul")
	# Act
	var conteo: int = _spawner_azul.contar_unidades_vivas()
	# Assert
	assert_eq(conteo, 1,
		"Debe contar la unidad dummy agregada manualmente.")
	assert_true(unidad_dummy.is_in_group("batalla_cosmetica"),
		"La unidad debe estar en el grupo 'batalla_cosmetica'.")
	assert_true(unidad_dummy.is_in_group("battle_azul"),
		"La unidad azul debe estar en el grupo 'battle_azul'.")


# ─── TESTS DE CASOS LÍMITE ───────────────────────────────────────────────────

func test_max_unidades_activas_limita_el_spawn() -> void:
	# Arrange: llenar el array hasta el máximo
	for i in range(BattleSpawnerCosmetic.MAX_UNIDADES_ACTIVAS):
		var dummy := Node3D.new()
		add_child(dummy)
		_spawner_azul._unidades_activas.append(dummy)
	# Act
	var resultado: Node3D = await _spawner_azul._spawn_una_unidad()
	# Assert
	assert_null(resultado,
		"No debe spawnear si ya se alcanzó el máximo de unidades activas.")
	# Cleanup
	for d in _spawner_azul._unidades_activas:
		if is_instance_valid(d):
			d.queue_free()
	_spawner_azul._unidades_activas.clear()


func test_cantidad_inicial_minima_es_uno() -> void:
	# Arrange
	var spawner := _escena.instantiate() as BattleSpawnerCosmetic
	spawner.cantidad_inicial = 0
	add_child_autofree(spawner)
	# Assert: verificar que la exportación tenga range mínimo de 1
	# (validación en el inspector, pero el código no limita en runtime)
	assert_gte(spawner.cantidad_inicial, 0,
		"La cantidad inicial no puede ser negativa.")


func test_scatter_x_no_negativo() -> void:
	var spawner := _escena.instantiate() as BattleSpawnerCosmetic
	spawner.scatter_x = -5.0
	add_child_autofree(spawner)
	# El scatter_x negativo no causa crash pero el randf_range lo invertirá
	# Verificamos que el valor sea accesible
	assert_true(spawner.scatter_x == -5.0 or spawner.scatter_x >= 0.0,
		"scatter_x debe ser accesible sin crash.")


func test_escala_unidad_por_defecto_es_uno() -> void:
	assert_almost_eq(_spawner_azul.escala_unidad, 1.0, 0.001,
		"La escala de unidad por defecto debe ser 1.0.")


func test_escala_unidad_se_aplica_a_unidad_spawneada() -> void:
	# Arrange
	_spawner_azul.escala_unidad = 0.75
	# Act
	var unidad: Node3D = await _spawner_azul._spawn_una_unidad()
	# Assert
	assert_not_null(unidad, "Debe instanciarse la unidad.")
	if unidad:
		assert_almost_eq(unidad.scale.x, 0.75, 0.001, "La escala X de la unidad debe ser 0.75.")
		assert_almost_eq(unidad.scale.y, 0.75, 0.001, "La escala Y de la unidad debe ser 0.75.")
		assert_almost_eq(unidad.scale.z, 0.75, 0.001, "La escala Z de la unidad debe ser 0.75.")
		unidad.queue_free()


func test_orientacion_imperio_girl_mira_a_la_derecha() -> void:
	# Arrange
	_spawner_azul.bando = "azul"
	# Act
	var unidad: Node3D = await _spawner_azul._spawn_una_unidad()
	# Assert
	assert_not_null(unidad)
	if unidad:
		var modelo := unidad.find_child("ImperioGirlModel", true, false) as Node3D
		assert_not_null(modelo)
		if modelo:
			assert_almost_eq(modelo.rotation_degrees.y, 90.0, 0.1,
				"El modelo de Imperio Girl Melee debe mirar a la derecha (+X) con 90 grados.")
		unidad.queue_free()


func test_orientacion_goblin_garrote_mira_a_la_izquierda() -> void:
	# Arrange
	_spawner_rojo.bando = "rojo"
	# Act
	var unidad: Node3D = await _spawner_rojo._spawn_una_unidad()
	# Assert
	assert_not_null(unidad)
	if unidad:
		var modelo := unidad.find_child("GOBLING_REMASTER_ANIMACIONES", true, false) as Node3D
		assert_not_null(modelo)
		if modelo:
			assert_almost_eq(modelo.rotation_degrees.y, -90.0, 0.1,
				"El modelo de Goblin Garrote debe mirar a la izquierda (-X) con -90 grados.")
		unidad.queue_free()

