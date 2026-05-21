extends "res://addons/gut/test.gd"

## Tests para el sistema EventBus

var EventBusScript = load("res://Scripts/Core/EventBus.gd")
var _event_bus = null

func before_each():
	_event_bus = EventBusScript.new()
	get_tree().root.add_child(_event_bus)

func after_each():
	if is_instance_valid(_event_bus):
		_event_bus.get_parent().remove_child(_event_bus)
		_event_bus.free()

# ═══════════════════════════════════════════════════════════════════
# TESTS DE CONEXIÓN Y DESCONEXIÓN
# ═══════════════════════════════════════════════════════════════════

func test_connect_to_player_damaged():
	var callable = Callable(self, "_on_player_damaged")
	var result = _event_bus.connect("player_damaged", callable)
	assert_eq(result, OK, "Should connect successfully")
	assert_eq(_event_bus._listeners_count["player_damaged"], 1, "Listener count should be 1")

func test_connect_to_enemy_died():
	var callable = Callable(self, "_on_enemy_died")
	var result = _event_bus.connect("enemy_died", callable)
	assert_eq(result, OK, "Should connect successfully")
	assert_eq(_event_bus._listeners_count["enemy_died"], 1, "Listener count should be 1")

func test_connect_to_unknown_event():
	var callable = Callable(self, "_on_unknown")
	var result = _event_bus.connect("unknown_event", callable)
	assert_eq(result, ERR_DOES_NOT_EXIST, "Should return error for unknown event")

func test_disconnect_from_event():
	var callable = Callable(self, "_on_player_damaged")
	_event_bus.connect("player_damaged", callable)
	var result = _event_bus.disconnect("player_damaged", callable)
	assert_eq(result, OK, "Should disconnect successfully")
	assert_eq(_event_bus._listeners_count["player_damaged"], 0, "Listener count should be 0")

# ═══════════════════════════════════════════════════════════════════
# TESTS DE EMISIÓN DE EVENTOS
# ═══════════════════════════════════════════════════════════════════

var _player_damaged_received = false
var _player_damaged_value = 0

func _on_player_damaged(new_health: int):
	_player_damaged_received = true
	_player_damaged_value = new_health

func test_emit_player_damaged():
	var callable = Callable(self, "_on_player_damaged")
	_event_bus.connect("player_damaged", callable)
	
	_player_damaged_received = false
	_player_damaged_value = 0
	
	_event_bus.emit_event("player_damaged", [3])
	
	assert_true(_player_damaged_received, "Event should be received")
	assert_eq(_player_damaged_value, 3, "Health value should be 3")

var _enemy_died_received = false
var _enemy_died_data = {}

func _on_enemy_died(enemy_type: String, position: Vector3, score_value: int):
	_enemy_died_received = true
	_enemy_died_data = {"type": enemy_type, "pos": position, "score": score_value}

func test_emit_enemy_died():
	var callable = Callable(self, "_on_enemy_died")
	_event_bus.connect("enemy_died", callable)
	
	_enemy_died_received = false
	_enemy_died_data = {}
	
	var test_pos = Vector3(10, 5, 0)
	_event_bus.emit_event("enemy_died", ["Goblin", test_pos, 100])
	
	assert_true(_enemy_died_received, "Event should be received")
	assert_eq(_enemy_died_data["type"], "Goblin", "Enemy type should match")
	assert_eq(_enemy_died_data["pos"], test_pos, "Position should match")
	assert_eq(_enemy_died_data["score"], 100, "Score should match")

var _wave_started_received = false
var _wave_data = {}

func _on_wave_started(wave_number: int, total_waves: int):
	_wave_started_received = true
	_wave_data = {"wave": wave_number, "total": total_waves}

func test_emit_wave_started():
	var callable = Callable(self, "_on_wave_started")
	_event_bus.connect("wave_started", callable)
	
	_wave_started_received = false
	_wave_data = {}
	
	_event_bus.emit_event("wave_started", [2, 5])
	
	assert_true(_wave_started_received, "Event should be received")
	assert_eq(_wave_data["wave"], 2, "Wave number should be 2")
	assert_eq(_wave_data["total"], 5, "Total waves should be 5")

var _level_completed_received = false
var _level_data = {}

func _on_level_completed(level_number: int, is_pacifist: bool):
	_level_completed_received = true
	_level_data = {"level": level_number, "pacifist": is_pacifist}

func test_emit_level_completed_pacifist():
	var callable = Callable(self, "_on_level_completed")
	_event_bus.connect("level_completed", callable)
	
	_level_completed_received = false
	_level_data = {}
	
	_event_bus.emit_event("level_completed", [5, true])
	
	assert_true(_level_completed_received, "Event should be received")
	assert_eq(_level_data["level"], 5, "Level number should be 5")
	assert_true(_level_data["pacifist"], "Should be pacifist completion")

func test_emit_level_completed_normal():
	var callable = Callable(self, "_on_level_completed")
	_event_bus.connect("level_completed", callable)
	
	_level_completed_received = false
	_level_data = {}
	
	_event_bus.emit_event("level_completed", [5, false])
	
	assert_true(_level_completed_received, "Event should be received")
	assert_eq(_level_data["level"], 5, "Level number should be 5")
	assert_false(_level_data["pacifist"], "Should not be pacifist completion")

# ═══════════════════════════════════════════════════════════════════
# TESTS DE ESTADÍSTICAS Y UTILIDADES
# ═══════════════════════════════════════════════════════════════════

func test_get_listener_stats():
	var callable1 = Callable(self, "_on_player_damaged")
	var callable2 = Callable(self, "_on_enemy_died")
	
	_event_bus.connect("player_damaged", callable1)
	_event_bus.connect("player_damaged", callable1)  # Doble conexión (si es válido)
	_event_bus.connect("enemy_died", callable2)
	
	var stats = _event_bus.get_listener_stats()
	
	assert_true(stats.has("player_damaged"), "Stats should have player_damaged")
	assert_true(stats.has("enemy_died"), "Stats should have enemy_died")
	assert_ge(stats["player_damaged"], 1, "Should have at least 1 listener")
	assert_ge(stats["enemy_died"], 1, "Should have at least 1 listener")

# ═══════════════════════════════════════════════════════════════════
# TESTS DE MÚLTIPLES LISTENERS
# ═══════════════════════════════════════════════════════════════════

var _listener1_called = false
var _listener2_called = false

func _on_listener1(_data):
	_listener1_called = true

func _on_listener2(_data):
	_listener2_called = true

func test_multiple_listeners_same_event():
	var callable1 = Callable(self, "_on_listener1")
	var callable2 = Callable(self, "_on_listener2")
	
	_event_bus.connect("player_damaged", callable1)
	_event_bus.connect("player_damaged", callable2)
	
	_listener1_called = false
	_listener2_called = false
	
	_event_bus.emit_event("player_damaged", [5])
	
	assert_true(_listener1_called, "Listener 1 should be called")
	assert_true(_listener2_called, "Listener 2 should be called")
