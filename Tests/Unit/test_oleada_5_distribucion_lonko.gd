extends "res://addons/gut/test.gd"

## Tests para la distribución balanceada de arqueras Lonko en la Oleada 5
## y la línea negra toon en escudos enemigos.

const ESCUDO_ENEMIGO_SCENE := preload("res://Entities/Ambiente_Escudo/Escudo_enemigo.tscn")
const WaveSpawnerScript := preload("res://System/Core/WaveSpawner.gd")
const SHADER_TOON_OUTLINE := preload("res://System/Shaders/TOON_LINEANEGRA.gdshader")

var _spawner: WaveSpawner = null


func before_each() -> void:
	_spawner = WaveSpawnerScript.new()
	_spawner.escena_goblin = _create_dummy_scene("GoblinNode")
	_spawner.escena_goblin_girl = _create_dummy_scene("GoblinGirlNode")
	_spawner.escena_imp = _create_dummy_scene("ImpNode")
	_spawner.escena_canonero = _create_dummy_scene("CanoneroNode")
	_spawner.escena_gargola = _create_dummy_scene("GargolaNode")
	_spawner.escena_lonko = _create_dummy_scene("LonkoNode")
	_spawner.escena_imp_escudo = _create_dummy_scene("ImpShieldNode")
	_spawner.escena_arquera_rosa = _create_dummy_scene("ArqueraRosaNode")
	add_child_autofree(_spawner)


func _create_dummy_scene(node_name: String) -> PackedScene:
	var scene := PackedScene.new()
	var node := Node3D.new()
	node.name = node_name
	scene.pack(node)
	node.free()
	return scene


func test_escudo_enemigo_tiene_outline_toon_y_grupo() -> void:
	# Arrange
	var escudo := ESCUDO_ENEMIGO_SCENE.instantiate() as EscudoDestruible
	add_child_autofree(escudo)
	await get_tree().process_frame

	# Act
	var mallas := escudo._recolectar_mallas()

	# Assert
	assert_gt(mallas.size(), 0, "El escudo enemigo debe poseer al menos una malla")
	for mi in mallas:
		assert_true(
			mi.is_in_group("outline_meshes"),
			"Cada malla del escudo enemigo debe estar registrada en el grupo outline_meshes"
		)

	assert_not_null(escudo.material_original, "El escudo debe tener material original")
	if escudo.material_original is StandardMaterial3D:
		var std_mat := escudo.material_original as StandardMaterial3D
		assert_not_null(std_mat.next_pass, "El material del escudo enemigo debe tener next_pass de contorno")
		if std_mat.next_pass is ShaderMaterial:
			var sm := std_mat.next_pass as ShaderMaterial
			assert_eq(sm.shader, SHADER_TOON_OUTLINE, "El shader de contorno debe ser TOON_LINEANEGRA")


func test_distribucion_lonko_oleada_5_sin_aglomeracion_final() -> void:
	# Arrange
	_spawner.oleada_combate = 5

	# Act
	_spawner._generar_cola_spawn()
	var cola: Array[PackedScene] = _spawner.cola_spawn

	# Assert: tamaño total y cantidad de lonkos
	assert_eq(cola.size(), 40, "La Oleada 5 debe contener 40 enemigos base")
	var lonkos_indices: Array[int] = []
	for i in range(cola.size()):
		if cola[i] == _spawner.escena_lonko:
			lonkos_indices.append(i)

	assert_eq(lonkos_indices.size(), 12, "Deben existir exactamente 12 arqueras Lonko en la Oleada 5")

	# Assert: Primer Lonko debe salir temprano (entre los 3 primeros)
	assert_lte(lonkos_indices[0], 2, "La primera arquera Lonko debe aparecer entre los 3 primeros spawns (índice <= 2)")

	# Assert: Ningún Lonko debe estar en la cola final (últimos 4 enemigos)
	for idx in range(cola.size() - 4, cola.size()):
		assert_ne(
			cola[idx],
			_spawner.escena_lonko,
			"El final de la oleada (índice %d) NO debe ser Lonko para no abrumar al jugador" % idx
		)

	# Assert: No debe haber Lonkos consecutivos y el espaciado debe ser de al menos 2 no-Lonkos
	for k in range(lonkos_indices.size() - 1):
		var diff: int = lonkos_indices[k + 1] - lonkos_indices[k]
		assert_gte(
			diff,
			3, # diff >= 3 significa al menos 2 enemigos entre medio (ej: idx 2 y 5 -> diff=3)
			"Las Lonkos en índices %d y %d deben tener al menos 2 enemigos de separación" % [lonkos_indices[k], lonkos_indices[k + 1]]
		)


func test_limite_lonkos_activos_desvia_spawns_adicionales() -> void:
	# Arrange
	_spawner.oleada_combate = 5
	_spawner.max_lonkos_activos = 2

	# Crear 2 lonkos activos simulados
	for i in range(2):
		var lonko_dummy := CharacterBody3D.new()
		lonko_dummy.name = "Lonko_%d" % i
		lonko_dummy.add_to_group("lonko")
		_spawner.active_goblins.append(lonko_dummy)
		add_child_autofree(lonko_dummy)

	# Configurar cola: [Lonko, Goblin, Goblin]
	_spawner.cola_spawn = [_spawner.escena_lonko, _spawner.escena_goblin, _spawner.escena_goblin]

	# Act: intentar spawnear con el límite de Lonkos alcanzado
	_spawner._spawn_goblin()

	# Assert: No debió spawnear Lonko, sino sacar al siguiente enemigo regular (Goblin)
	assert_eq(_spawner.cola_spawn.size(), 2, "La cola debe haber reducido su tamaño en 1")
	assert_eq(_spawner.cola_spawn[0], _spawner.escena_lonko, "El Lonko debe haber permanecido al frente de la cola")
	assert_true(
		_spawner.active_goblins.back().name.contains("GoblinNode"),
		"El spawner debió spawnear el Goblin alternativo y posponer a Lonko"
	)
