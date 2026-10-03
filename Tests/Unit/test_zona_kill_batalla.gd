extends GutTest
## Tests unitarios para el sistema de ZonaKillBatalla y el respawn continuo de BattleSpawnerCosmetic.
##
## Verifica:
## - Que ZonaKillBatalla elimina unidades del grupo "batalla_cosmetica"
## - Que ignora unidades que no pertenecen a ese grupo
## - Que el filtro por bando funciona correctamente
## - Que BattleSpawnerCosmetic activa _respawnear_con_delay al morir una unidad
## - Límites: MAX_UNIDADES_ACTIVAS se respeta incluso al respawnear

const ZONA_KILL_SCRIPT: GDScript = preload("res://Entities/Ambiente_BattleSpawner/ZonaKillBatalla.gd")


# ─────────────────────────────────────────────────────────────────────────────
# ZONA KILL BATALLA — Tests
# ─────────────────────────────────────────────────────────────────────────────

class TestZonaKillBatalla extends GutTest:
	var _zona: ZonaKillBatalla

	func before_each() -> void:
		_zona = ZonaKillBatalla.new()
		_zona.eliminar_todos_los_bandos = true
		add_child_autofree(_zona)

	# ── Happy Path ────────────────────────────────────────────────────────────

	func test_zona_elimina_unidad_de_batalla_cosmetica() -> void:
		# Arrange
		var unidad: Node3D = Node3D.new()
		unidad.add_to_group("batalla_cosmetica")
		add_child_autofree(unidad)

		# Act
		_zona._procesar_colision(unidad)
		await get_tree().process_frame

		# Assert
		assert_true(unidad.is_queued_for_deletion(),
			"La unidad de batalla_cosmetica debe quedar en cola de borrado")

	func test_zona_ignora_nodos_fuera_del_grupo() -> void:
		# Arrange
		var nodo_ajeno: Node3D = Node3D.new()
		add_child_autofree(nodo_ajeno)

		# Act
		_zona._procesar_colision(nodo_ajeno)
		await get_tree().process_frame

		# Assert
		assert_false(nodo_ajeno.is_queued_for_deletion(),
			"Los nodos ajenos NO deben ser eliminados por la zona kill")

	# ── Filtro de bando ────────────────────────────────────────────────────────

	func test_filtro_bando_elimina_solo_el_bando_correcto() -> void:
		# Arrange
		_zona.eliminar_todos_los_bandos = false
		_zona.bando_objetivo = "azul"

		var unidad_azul: Node3D = Node3D.new()
		unidad_azul.add_to_group("batalla_cosmetica")
		unidad_azul.add_to_group("battle_azul")
		add_child_autofree(unidad_azul)

		var unidad_roja: Node3D = Node3D.new()
		unidad_roja.add_to_group("batalla_cosmetica")
		unidad_roja.add_to_group("battle_rojo")
		add_child_autofree(unidad_roja)

		# Act
		_zona._procesar_colision(unidad_azul)
		_zona._procesar_colision(unidad_roja)
		await get_tree().process_frame

		# Assert
		assert_true(unidad_azul.is_queued_for_deletion(),
			"La unidad del bando objetivo (azul) debe eliminarse")
		assert_false(unidad_roja.is_queued_for_deletion(),
			"La unidad del bando no objetivo (rojo) NO debe eliminarse")

	# ── Edge cases ────────────────────────────────────────────────────────────

	func test_zona_ignora_nodo_nulo() -> void:
		# Arrange / Act / Assert — no debe arrojar error
		_zona._procesar_colision(null)
		pass

	func test_zona_ignora_nodo_ya_en_cola_de_borrado() -> void:
		# Arrange
		var unidad: Node3D = Node3D.new()
		unidad.add_to_group("batalla_cosmetica")
		add_child_autofree(unidad)
		unidad.queue_free()

		# Act — no debe arrojar error aunque ya está siendo borrado
		_zona._procesar_colision(unidad)
		pass


# ─────────────────────────────────────────────────────────────────────────────
# BATTLE SPAWNER COSMETIC — Tests de respawn continuo
# ─────────────────────────────────────────────────────────────────────────────

class TestBattleSpawnerRespawn extends GutTest:
	var _spawner: BattleSpawnerCosmetic

	func before_each() -> void:
		_spawner = BattleSpawnerCosmetic.new()
		_spawner.auto_iniciar = false
		_spawner.respawn_al_morir = true
		_spawner.delay_respawn = 0.0
		_spawner.minimo_unidades_vivas = 1
		_spawner.cantidad_inicial = 0
		add_child_autofree(_spawner)

	# ── Happy Path ────────────────────────────────────────────────────────────

	func test_respawn_no_se_activa_antes_de_iniciar_batalla() -> void:
		# Arrange — batalla NO iniciada
		_spawner._batalla_iniciada = false
		var conteo_antes: int = _spawner._unidades_activas.size()

		# Act
		_spawner._respawnear_con_delay()
		await get_tree().process_frame

		# Assert
		assert_eq(_spawner._unidades_activas.size(), conteo_antes,
			"No debe spawnear si la batalla no ha comenzado")

	func test_respawn_no_se_activa_si_esta_deshabilitado() -> void:
		# Arrange
		_spawner._batalla_iniciada = true
		_spawner.respawn_al_morir = false
		var conteo_antes: int = _spawner._unidades_activas.size()

		# Act
		_spawner._respawnear_con_delay()
		await get_tree().process_frame

		# Assert
		assert_eq(_spawner._unidades_activas.size(), conteo_antes,
			"No debe spawnear si respawn_al_morir es false")

	# ── Límites ────────────────────────────────────────────────────────────────

	func test_respawn_respeta_max_unidades_activas() -> void:
		# Arrange — llenar hasta el máximo
		_spawner._batalla_iniciada = true
		for i in range(BattleSpawnerCosmetic.MAX_UNIDADES_ACTIVAS):
			var dummy: Node3D = Node3D.new()
			add_child_autofree(dummy)
			_spawner._unidades_activas.append(dummy)

		var conteo_antes: int = _spawner._unidades_activas.size()

		# Act
		_spawner._respawnear_con_delay()
		await get_tree().process_frame

		# Assert
		assert_eq(_spawner._unidades_activas.size(), conteo_antes,
			"No debe spawnear si ya se alcanzó MAX_UNIDADES_ACTIVAS (%d)" \
			% BattleSpawnerCosmetic.MAX_UNIDADES_ACTIVAS)


# ─────────────────────────────────────────────────────────────────────────────
# BATTLE SPAWNER COSMETIC — Tests de límite de cadáveres (max 8 por bando)
# ─────────────────────────────────────────────────────────────────────────────

class TestBattleSpawnerCadaveres extends GutTest:
	var _spawner: BattleSpawnerCosmetic

	class DummyCadaverConMetodo extends Node3D:
		var desvanecido: bool = false
		func desvanecer_y_liberar() -> void:
			desvanecido = true
			queue_free()

	func before_each() -> void:
		_spawner = BattleSpawnerCosmetic.new()
		_spawner.auto_iniciar = false
		_spawner.max_cadaveres = 8
		add_child_autofree(_spawner)

	# ── Happy Path ────────────────────────────────────────────────────────────

	func test_registrar_cadaveres_dentro_del_limite() -> void:
		# Arrange: Registrar 8 cadáveres (exactamente el límite)
		var lista: Array[Node3D] = []
		for i in range(8):
			var c: Node3D = Node3D.new()
			add_child_autofree(c)
			lista.append(c)

		# Act
		for c: Node3D in lista:
			_spawner._registrar_cadaver(c)

		# Assert
		assert_eq(_spawner.contar_cadaveres(), 8,
			"Debe mantener exactamente 8 cadáveres registrados")

	# ── Límites: Superar max_cadaveres (8) elimina el más antiguo ─────────────

	func test_superar_max_cadaveres_desvanece_el_mas_antiguo() -> void:
		# Arrange: Registrar 8 cadáveres con el primero rastreable
		var primer_cadaver: DummyCadaverConMetodo = DummyCadaverConMetodo.new()
		add_child_autofree(primer_cadaver)
		_spawner._registrar_cadaver(primer_cadaver)

		for i in range(7):
			var c: Node3D = Node3D.new()
			add_child_autofree(c)
			_spawner._registrar_cadaver(c)

		assert_eq(_spawner.contar_cadaveres(), 8, "Debe tener 8 cadáveres antes del 9no")

		# Act: Registrar el 9no cadáver (supera el límite de 8)
		var noveno_cadaver: Node3D = Node3D.new()
		add_child_autofree(noveno_cadaver)
		_spawner._registrar_cadaver(noveno_cadaver)
		await get_tree().process_frame

		# Assert: El primero debe haber sido desvanecido y el conteo seguir en 8
		assert_true(primer_cadaver.desvanecido,
			"El cadáver más antiguo debe llamar a desvanecer_y_liberar()")
		assert_eq(_spawner.contar_cadaveres(), 8,
			"El total de cadáveres activos no debe superar max_cadaveres (8)")

	# ── Edge Cases ────────────────────────────────────────────────────────────

	func test_registrar_cadaver_invalido_o_nulo_no_rompe() -> void:
		# Arrange / Act / Assert
		_spawner._registrar_cadaver(null)
		assert_eq(_spawner.contar_cadaveres(), 0, "No debe registrar cadáver nulo")

	func test_limpiar_cadaveres_remueve_instancias_liberadas() -> void:
		# Arrange
		var c1: Node3D = Node3D.new()
		var c2: Node3D = Node3D.new()
		add_child_autofree(c1)
		add_child_autofree(c2)
		_spawner._registrar_cadaver(c1)
		_spawner._registrar_cadaver(c2)
		assert_eq(_spawner.contar_cadaveres(), 2)

		# Act: Liberar c1 externamente
		c1.queue_free()
		await get_tree().process_frame

		# Assert
		assert_eq(_spawner.contar_cadaveres(), 1,
			"Debe limpiar instancias liberadas de la lista de cadáveres")

