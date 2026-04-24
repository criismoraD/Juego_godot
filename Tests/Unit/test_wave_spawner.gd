extends "res://addons/gut/test.gd"

var WaveSpawnerScript = load("res://Scripts/Core/WaveSpawner.gd")
var _spawner = null

func before_each():
	_spawner = WaveSpawnerScript.new()

func after_each():
	if is_instance_valid(_spawner):
		_spawner.free()

func test_get_active_enemies_with_freed_instances():
	var valid_node = Node3D.new()
	var freed_node = Node3D.new()

	_spawner.active_goblins = [valid_node, freed_node]

	# Free one node
	freed_node.free()

	var result = _spawner.get_active_enemies()

	assert_eq(result.size(), 1, "Should only return 1 active enemy")
	assert_eq(result[0], valid_node, "The remaining enemy should be the valid one")

	valid_node.free()

func test_obtener_goblins_activos_counts_correctly():
	var node1 = Node3D.new()
	var node2 = Node3D.new()

	_spawner.active_goblins = [node1, node2]

	node1.free()

	var count = _spawner.obtener_goblins_activos()

	assert_eq(count, 1, "Should count only 1 active goblin")
	assert_eq(_spawner.active_goblins.size(), 1, "Internal array should be cleaned up")

	node2.free()

func test_get_active_shield_imps_filtering():
	var valid_imp = Node3D.new()
	var freed_imp = Node3D.new()

	_spawner.shield_imps_activos = [valid_imp, freed_imp]

	freed_imp.free()

	var result = _spawner.get_active_shield_imps()

	assert_eq(result.size(), 1, "Should only return 1 active shield imp")
	assert_eq(result[0], valid_imp, "The remaining imp should be the valid one")

	valid_imp.free()

func test_filtering_all_freed_instances():
	var node1 = Node3D.new()
	var node2 = Node3D.new()

	_spawner.active_goblins = [node1, node2]

	node1.free()
	node2.free()

	var result = _spawner.get_active_enemies()

	assert_true(result.is_empty(), "Should return an empty array when all instances are freed")

func test_filtering_empty_array():
	_spawner.active_goblins = []
	var result = _spawner.get_active_enemies()
	assert_true(result.is_empty(), "Should handle empty array correctly")

func test_filtering_all_valid_instances():
	var node1 = Node3D.new()
	var node2 = Node3D.new()

	_spawner.active_goblins = [node1, node2]

	var result = _spawner.get_active_enemies()

	assert_eq(result.size(), 2, "Should return all valid instances")

	node1.free()
	node2.free()

func test_filtering_null_values():
	var node = Node3D.new()
	_spawner.active_goblins = [null, node, null]

	var result = _spawner.get_active_enemies()

	assert_eq(result.size(), 1, "Should only return 1 valid node, removing nulls")
	assert_eq(result[0], node, "The remaining node should be the valid one")

	node.free()
