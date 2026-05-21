extends "res://addons/gut/test.gd"

## Tests para PlayerStateMachine

var StateMachineScript = load("res://Scripts/Characters/PlayerStateMachine.gd")
var _state_machine = null

func before_each():
	_state_machine = StateMachineScript.new()
	get_tree().root.add_child(_state_machine)

func after_each():
	if is_instance_valid(_state_machine):
		_state_machine.get_parent().remove_child(_state_machine)
		_state_machine.free()

# ═══════════════════════════════════════════════════════════════════
# TESTS DE ESTADO INICIAL
# ═══════════════════════════════════════════════════════════════════

func test_initial_state_is_idle():
	assert_eq(_state_machine.current_state, _state_machine.State.IDLE, "Initial state should be IDLE")
	assert_eq(_state_machine.get_state_name(), "IDLE", "State name should be IDLE")

func test_previous_state_starts_as_idle():
	assert_eq(_state_machine.previous_state, _state_machine.State.IDLE, "Previous state should start as IDLE")

# ═══════════════════════════════════════════════════════════════════
# TESTS DE TRANSICIONES VÁLIDAS
# ═══════════════════════════════════════════════════════════════════

func test_transition_from_idle_to_walking():
	var result = _state_machine.transition_to(_state_machine.State.WALKING)
	assert_true(result, "Should transition from IDLE to WALKING")
	assert_eq(_state_machine.current_state, _state_machine.State.WALKING)

func test_transition_from_idle_to_jumping():
	_state_machine.transition_to(_state_machine.State.JUMPING)
	assert_eq(_state_machine.current_state, _state_machine.State.JUMPING)

func test_transition_from_jumping_to_falling():
	_state_machine.transition_to(_state_machine.State.JUMPING)
	var result = _state_machine.transition_to(_state_machine.State.FALLING)
	assert_true(result, "Should transition from JUMPING to FALLING")
	assert_eq(_state_machine.current_state, _state_machine.State.FALLING)

func test_transition_from_falling_to_landing():
	_state_machine.transition_to(_state_machine.State.JUMPING)
	_state_machine.transition_to(_state_machine.State.FALLING)
	var result = _state_machine.transition_to(_state_machine.State.LANDING)
	assert_true(result, "Should transition from FALLING to LANDING")
	assert_eq(_state_machine.current_state, _state_machine.State.LANDING)

func test_transition_from_idle_to_aiming():
	var result = _state_machine.transition_to(_state_machine.State.AIMING)
	assert_true(result, "Should transition from IDLE to AIMING")
	assert_eq(_state_machine.current_state, _state_machine.State.AIMING)

func test_transition_from_aiming_to_shooting():
	_state_machine.transition_to(_state_machine.State.AIMING)
	var result = _state_machine.transition_to(_state_machine.State.SHOOTING)
	assert_true(result, "Should transition from AIMING to SHOOTING")
	assert_eq(_state_machine.current_state, _state_machine.State.SHOOTING)

# ═══════════════════════════════════════════════════════════════════
# TESTS DE TRANSICIONES INVÁLIDAS
# ═══════════════════════════════════════════════════════════════════

func test_cannot_transition_from_jumping_to_idle():
	_state_machine.transition_to(_state_machine.State.JUMPING)
	var result = _state_machine.transition_to(_state_machine.State.IDLE)
	assert_false(result, "Should NOT transition from JUMPING to IDLE")
	assert_eq(_state_machine.current_state, _state_machine.State.JUMPING, "State should remain JUMPING")

func test_cannot_transition_from_falling_to_idle():
	_state_machine.transition_to(_state_machine.State.JUMPING)
	_state_machine.transition_to(_state_machine.State.FALLING)
	var result = _state_machine.transition_to(_state_machine.State.IDLE)
	assert_false(result, "Should NOT transition from FALLING to IDLE directly")
	assert_eq(_state_machine.current_state, _state_machine.State.FALLING)

func test_cannot_leave_dead_state():
	_state_machine.transition_to(_state_machine.State.HURT)
	_state_machine.transition_to(_state_machine.State.DEAD)
	var result = _state_machine.transition_to(_state_machine.State.IDLE)
	assert_false(result, "Should NOT transition from DEAD to any state")
	assert_eq(_state_machine.current_state, _state_machine.State.DEAD, "State should remain DEAD")

# ═══════════════════════════════════════════════════════════════════
# TESTS DE MÉTODOS DE CONSULTA
# ═══════════════════════════════════════════════════════════════════

func test_is_in_state_returns_true_for_current():
	_state_machine.transition_to(_state_machine.State.WALKING)
	assert_true(_state_machine.is_in_state(_state_machine.State.WALKING))

func test_is_in_state_returns_false_for_other():
	_state_machine.transition_to(_state_machine.State.WALKING)
	assert_false(_state_machine.is_in_state(_state_machine.State.JUMPING))

func test_is_in_any_state_with_matching():
	_state_machine.transition_to(_state_machine.State.WALKING)
	var states = [_state_machine.State.IDLE, _state_machine.State.WALKING, _state_machine.State.RUNNING]
	assert_true(_state_machine.is_in_any_state(states))

func test_is_in_any_state_without_matching():
	_state_machine.transition_to(_state_machine.State.WALKING)
	var states = [_state_machine.State.JUMPING, _state_machine.State.FALLING]
	assert_false(_state_machine.is_in_any_state(states))

func test_get_state_name_from_enum():
	var name = _state_machine.get_state_name_from_enum(_state_machine.State.CLIMBING)
	assert_eq(name, "CLIMBING")

# ═══════════════════════════════════════════════════════════════════
# TESTS DE SEÑAL DE CAMBIO DE ESTADO
# ═══════════════════════════════════════════════════════════════════

var _state_changed_called = false
var _new_state = -1
var _old_state = -1

func _on_state_changed(new_state, old_state):
	_state_changed_called = true
	_new_state = new_state
	_old_state = old_state

func test_state_changed_signal_emitted():
	_state_machine.state_changed.connect(_on_state_changed)
	
	_state_changed_called = false
	_state_machine.transition_to(_state_machine.State.WALKING)
	
	assert_true(_state_changed_called, "Signal should be emitted")
	assert_eq(_new_state, _state_machine.State.WALKING)
	assert_eq(_old_state, _state_machine.State.IDLE)

# ═══════════════════════════════════════════════════════════════════
# TESTS DE RESET Y FUERZA
# ═══════════════════════════════════════════════════════════════════

func test_reset_returns_to_idle():
	_state_machine.transition_to(_state_machine.State.WALKING)
	_state_machine.transition_to(_state_machine.State.JUMPING)
	
	_state_machine.reset()
	
	assert_eq(_state_machine.current_state, _state_machine.State.IDLE)

func test_force_transition_ignores_validation():
	_state_machine.transition_to(_state_machine.State.JUMPING)
	
	# Esta transición normalmente sería inválida
	_state_machine.force_transition_to(_state_machine.State.IDLE)
	
	assert_eq(_state_machine.current_state, _state_machine.State.IDLE, "Force transition should work")

# ═══════════════════════════════════════════════════════════════════
# TESTS DE ESTADÍSTICAS
# ═══════════════════════════════════════════════════════════════════

func test_get_stats_returns_correct_data():
	_state_machine.transition_to(_state_machine.State.WALKING)
	
	var stats = _state_machine.get_stats()
	
	assert_eq(stats["current"], "WALKING")
	assert_eq(stats["previous"], "IDLE")
	assert_false(stats["is_terminal"])

func test_get_stats_terminal_state():
	_state_machine.transition_to(_state_machine.State.HURT)
	_state_machine.transition_to(_state_machine.State.DEAD)
	
	var stats = _state_machine.get_stats()
	
	assert_eq(stats["current"], "DEAD")
	assert_true(stats["is_terminal"])

# ═══════════════════════════════════════════════════════════════════
# TESTS DE CONVERSIÓN STRING A ESTADO
# ═══════════════════════════════════════════════════════════════════

func test_string_to_state_valid():
	var state = _state_machine.string_to_state("JUMPING")
	assert_eq(state, _state_machine.State.JUMPING)

func test_string_to_state_invalid():
	var state = _state_machine.string_to_state("INVALID_STATE")
	assert_eq(state, _state_machine.State.IDLE, "Should return IDLE for invalid strings")
